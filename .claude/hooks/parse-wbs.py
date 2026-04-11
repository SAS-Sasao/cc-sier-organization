#!/usr/bin/env python3
"""parse-wbs.py — 組織横断で WBS markdown を header-aware に parse する

使用例:
    python3 .claude/hooks/parse-wbs.py                          # 全組織を JSON で出力
    python3 .claude/hooks/parse-wbs.py --org domain-tech-collection
    python3 .claude/hooks/parse-wbs.py --file path/to/wbs.md
    python3 .claude/hooks/parse-wbs.py --format=tsv             # TSV 形式で出力

対応スキーマ:
    - 8 cols (storcon-preparation-wbs.md 元形式)
    - 12 cols (storcon 拡張後, 末尾 Iter/Pri/Type/Issue/ステータス)
    - 4 cols (standardization-project-wbs.md 元形式)
    - 9 cols (standardization 拡張後, 末尾 Iter/Pri/Type/Issue/ステータス)
    - その他のゆらぎ（列名変更、列数増減）に header row から動的対応

出力フィールド:
    - wbs_id (str): "3.1.1", "1.0.12", "2.1.R1" など
    - task (str): タスク名
    - assignee (str|None): 担当
    - period (str|None): 期間
    - artifact (str|None): 成果物
    - iteration (str|None): W1 / W2-4 など
    - priority (int|None): 1-4
    - type (str|None): learning / diagram / research / delivery / operational
    - issue_number (int|None): 紐付く GitHub Issue 番号
    - status (str): "todo" | "in-progress" | "done"
    - org (str): 組織 slug
    - wbs_file (str): 元ファイルパス（repo root からの相対）
    - section (str|None): 直前の ## 見出し
    - subsection (str|None): 直前の ### 見出し
"""

import argparse
import json
import os
import re
import sys
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[2]

# 対応するヘッダー名のゆらぎ辞書 (canonical -> list of aliases)
HEADER_ALIASES: dict[str, list[str]] = {
    "wbs_id": ["WBS", "WBS#", "WBS No", "No", "#"],
    "task": ["タスク", "作業項目", "Task", "Item"],
    "assignee": ["担当", "Assignee"],
    "period": ["期間", "期限", "Period", "Due"],
    "artifact": ["成果物", "Deliverable", "Output"],
    "iteration": ["Iter", "Iteration", "Sprint"],
    "priority": ["Pri", "Priority", "優先度"],
    "type": ["Type", "種別", "Kind"],
    "issue_number": ["Issue", "Issue#", "IssueNumber"],
    "status": ["ステータス", "Status", "状態"],
}

# WBS ID パターン（ヘッダー検出後の row フィルタ）
WBS_ID_PATTERN = re.compile(r"^\d+(\.\d+)*(\.R?\d+)?$|^\d+\.\d+\.R?\d+$")

# ステータスセル → 正規化
STATUS_MAP = {
    "[x]": "done",
    "[X]": "done",
    "[~]": "in-progress",
    "[ ]": "todo",
    "[]": "todo",
}


def find_wbs_files(org_filter: str | None = None) -> list[tuple[str, Path]]:
    """全組織の WBS ファイルを列挙する。(org_slug, path) のリスト。"""
    companies_dir = REPO_ROOT / ".companies"
    if not companies_dir.is_dir():
        return []

    result: list[tuple[str, Path]] = []
    for org_dir in sorted(companies_dir.iterdir()):
        if not org_dir.is_dir() or org_dir.name.startswith("."):
            continue
        org_slug = org_dir.name
        if org_filter and org_slug != org_filter:
            continue

        # 探索パス: secretary/*wbs*.md, pm/projects/**/*wbs*.md
        patterns = [
            "docs/secretary/*wbs*.md",
            "docs/secretary/**/*wbs*.md",
            "docs/pm/**/*wbs*.md",
            "docs/pm/projects/*/wbs.md",
        ]
        seen: set[Path] = set()
        for pat in patterns:
            for p in org_dir.glob(pat):
                if not p.is_file():
                    continue
                # learning-notes/wbs-* のような個別メモは除外（ファイル名が "wbs-数字" で始まる）
                if re.match(r"^wbs-\d", p.name):
                    continue
                if p in seen:
                    continue
                seen.add(p)
                result.append((org_slug, p))
    return result


def split_table_row(line: str) -> list[str]:
    """markdown テーブル行を cell list に分解する。"""
    s = line.strip()
    if s.startswith("|"):
        s = s[1:]
    if s.endswith("|"):
        s = s[:-1]
    return [c.strip() for c in s.split("|")]


def is_separator_row(cells: list[str]) -> bool:
    """テーブルセパレータ行（---）判定。"""
    return all(re.match(r"^:?-+:?$", c) for c in cells if c)


def detect_header_map(cells: list[str]) -> dict[str, int] | None:
    """ヘッダー行のセルから canonical name -> index マップを作る。
    ヘッダーっぽくないなら None を返す。
    """
    mapping: dict[str, int] = {}
    matched_any = False
    for idx, cell in enumerate(cells):
        for canonical, aliases in HEADER_ALIASES.items():
            if cell in aliases:
                mapping[canonical] = idx
                matched_any = True
                break
    # 「WBS」と「タスク (or 作業項目)」の両方があればヘッダー確定
    if "wbs_id" in mapping and "task" in mapping:
        return mapping
    return None


def normalize_status(cell: str) -> str:
    """ステータスセルを "todo" / "in-progress" / "done" に正規化。"""
    cell_clean = cell.strip()
    if cell_clean in STATUS_MAP:
        return STATUS_MAP[cell_clean]
    if "完了" in cell_clean:
        return "done"
    if "進行中" in cell_clean or "in-progress" in cell_clean.lower():
        return "in-progress"
    return "todo"


def parse_priority(cell: str | None) -> int | None:
    """Pri セルを int に変換。"""
    if cell is None:
        return None
    c = cell.strip()
    if not c or c == "—":
        return None
    try:
        return int(c)
    except ValueError:
        # 優先度文字列のフォールバック
        mapping = {"最優先": 1, "高": 2, "中": 3, "低": 4, "high": 2, "medium": 3, "low": 4}
        return mapping.get(c.lower(), None)


def parse_issue_number(cell: str | None) -> int | None:
    """Issue セル (#123 or 123) を int に変換。"""
    if cell is None:
        return None
    c = cell.strip()
    if not c or c == "—":
        return None
    m = re.search(r"#?(\d+)", c)
    if m:
        return int(m.group(1))
    return None


def infer_iteration_from_period(period: str | None) -> str | None:
    """期間列から iteration を推測する。"""
    if not period:
        return None
    p = period.strip()
    # "W1" / "W1-3" / "Week 1" / "Week 1-2" / "W1-10（毎週末）"
    m = re.search(r"[Ww](?:eek\s*)?(\d+)(?:\s*[-–～]\s*(\d+))?", p)
    if m:
        start = int(m.group(1))
        end = m.group(2)
        if end:
            return f"W{start}-{end}"
        return f"W{start}"
    return None


def infer_type_from_task(task: str, wbs_id: str, section: str | None) -> str:
    """タスク名・WBS ID・セクションから type を推測する。"""
    task_lower = task.lower()
    sec_lower = (section or "").lower()

    # 明示キーワード優先
    if "図解" in task or "diagram" in task_lower or "drawio" in task_lower or "構成図" in task:
        return "diagram"
    if "調査" in task or "research" in task_lower or "リサーチ" in task:
        return "research"
    if "作成" in task or "納品" in task or "テンプレ" in task or "作業" in task or "deliverable" in task_lower:
        return "delivery"
    if "ダイジェスト" in task or "巡回" in task or "継続" in task or "振り返り" in task or "月次" in task:
        return "operational"

    # WBS 番号によるフォールバック
    if wbs_id.startswith("5."):
        return "research"
    if wbs_id.startswith("6."):
        return "learning"
    if "リサーチ" in sec_lower:
        return "research"

    return "learning"


def infer_priority_from_context(section: str | None, subsection: str | None, wbs_id: str) -> int:
    """セクション・サブセクション・WBS 番号から優先度を推測する。"""
    sub = (subsection or "").lower()
    sec = (section or "").lower()

    if "phase 1" in sub or "基礎" in sub:
        return 1
    if "phase 2" in sub or "案件直結" in sub or "直結" in sub:
        return 2
    if "phase 3" in sub or "移行" in sub or "統合" in sub:
        return 2
    if "phase 4" in sub or "仕上げ" in sub:
        return 3
    if "リサーチ" in sec:
        return 3

    # WBS の桁数から推測（浅いほど重要、深いほど個別）
    depth = wbs_id.count(".")
    if depth == 0:
        return 1
    if depth == 1:
        return 2
    return 3


def parse_wbs_file(org: str, path: Path) -> list[dict[str, Any]]:
    """WBS markdown ファイルを parse してタスク dict のリストを返す。"""
    rel_path = str(path.relative_to(REPO_ROOT))
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except Exception as e:
        print(f"WARN: failed to read {path}: {e}", file=sys.stderr)
        return []

    tasks: list[dict[str, Any]] = []
    current_section: str | None = None
    current_subsection: str | None = None
    header_map: dict[str, int] | None = None
    prev_was_header = False

    for line in lines:
        stripped = line.strip()

        # 見出し検出
        m = re.match(r"^##\s+(.+)$", stripped)
        if m:
            current_section = m.group(1).strip()
            current_subsection = None
            header_map = None  # 新セクションでヘッダー再検出
            continue
        m = re.match(r"^###\s+(.+)$", stripped)
        if m:
            current_subsection = m.group(1).strip()
            header_map = None
            continue

        # テーブル行のみ
        if not stripped.startswith("|"):
            prev_was_header = False
            continue

        cells = split_table_row(line)

        # セパレータ行スキップ
        if is_separator_row(cells):
            prev_was_header = False
            continue

        # ヘッダー行検出
        new_header = detect_header_map(cells)
        if new_header is not None:
            header_map = new_header
            prev_was_header = True
            continue

        if header_map is None:
            # ヘッダー未検出の表はスキップ
            continue

        # データ行: cells[wbs_id_idx] が WBS ID パターンかチェック
        wbs_idx = header_map.get("wbs_id")
        if wbs_idx is None or wbs_idx >= len(cells):
            continue

        wbs_id = cells[wbs_idx]
        if not WBS_ID_PATTERN.match(wbs_id):
            continue

        def get(key: str) -> str | None:
            idx = header_map.get(key) if header_map else None
            if idx is None or idx >= len(cells):
                return None
            val = cells[idx]
            return val if val else None

        task = get("task") or wbs_id
        assignee = get("assignee")
        period = get("period")
        artifact = get("artifact")
        iteration_cell = get("iteration")
        priority_cell = get("priority")
        type_cell = get("type")
        issue_cell = get("issue_number")
        status_cell = get("status")

        # 推測
        iteration = iteration_cell or infer_iteration_from_period(period)
        priority = parse_priority(priority_cell)
        if priority is None:
            priority = infer_priority_from_context(current_section, current_subsection, wbs_id)
        type_val = type_cell or infer_type_from_task(task, wbs_id, current_section)
        issue_num = parse_issue_number(issue_cell)
        status = normalize_status(status_cell or "[ ]")

        tasks.append({
            "wbs_id": wbs_id,
            "task": task,
            "assignee": assignee,
            "period": period,
            "artifact": artifact,
            "iteration": iteration,
            "priority": priority,
            "type": type_val,
            "issue_number": issue_num,
            "status": status,
            "org": org,
            "wbs_file": rel_path,
            "section": current_section,
            "subsection": current_subsection,
        })

    return tasks


def main() -> int:
    parser = argparse.ArgumentParser(description="Parse WBS markdown files")
    parser.add_argument("--org", help="組織 slug で絞り込み")
    parser.add_argument("--file", help="単一ファイルを指定")
    parser.add_argument("--format", choices=["json", "tsv"], default="json")
    parser.add_argument("--status", help='ステータスで絞り込み (todo/in-progress/done)')
    args = parser.parse_args()

    all_tasks: list[dict[str, Any]] = []

    if args.file:
        p = Path(args.file).resolve()
        if not p.is_file():
            print(f"ERROR: {p} not found", file=sys.stderr)
            return 1
        # org slug を path から推測
        try:
            rel = p.relative_to(REPO_ROOT)
            parts = rel.parts
            org = parts[1] if parts[0] == ".companies" and len(parts) > 1 else "unknown"
        except ValueError:
            org = "unknown"
        all_tasks.extend(parse_wbs_file(org, p))
    else:
        for org, path in find_wbs_files(args.org):
            all_tasks.extend(parse_wbs_file(org, path))

    if args.status:
        all_tasks = [t for t in all_tasks if t["status"] == args.status]

    if args.format == "json":
        json.dump(all_tasks, sys.stdout, ensure_ascii=False, indent=2)
        print()
    else:
        # TSV
        if not all_tasks:
            return 0
        headers = list(all_tasks[0].keys())
        print("\t".join(headers))
        for t in all_tasks:
            print("\t".join(str(t.get(h, "") or "") for h in headers))

    print(f"\n# {len(all_tasks)} tasks parsed", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
