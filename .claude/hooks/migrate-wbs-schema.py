#!/usr/bin/env python3
"""migrate-wbs-schema.py — 既存 WBS markdown に拡張カラムを追加する一括移行ツール

使用例:
    python3 .claude/hooks/migrate-wbs-schema.py --all          # 全組織の WBS を一括移行
    python3 .claude/hooks/migrate-wbs-schema.py --file path.md # 単一ファイル
    python3 .claude/hooks/migrate-wbs-schema.py --dry-run      # 変更内容を表示するだけ

動作:
    1. WBS markdown のテーブルを検出
    2. ヘッダー行の末尾に `| Iter | Pri | Type | Issue | ステータス |` を挿入
       （既にステータス列があれば、ステータス列の手前に Iter/Pri/Type/Issue を挿入）
    3. セパレータ行も同じ列数に拡張
    4. データ行には parse-wbs.py と同じロジックで推測値を埋める
    5. 冪等: 既に拡張済みなら何もしない

注意:
    - 4 列のみのテーブル（standardization-project-wbs.md）は **ステータス列を新設**
    - 既存の 8 列（storcon-preparation-wbs.md）は **末尾（ステータス手前）に 4 列追加**
"""

import argparse
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]

# parse-wbs.py と同じ定数をインポートするため sys.path を調整
sys.path.insert(0, str(REPO_ROOT / ".claude" / "hooks"))

import importlib.util

spec = importlib.util.spec_from_file_location(
    "parse_wbs", REPO_ROOT / ".claude" / "hooks" / "parse-wbs.py"
)
parse_wbs = importlib.util.module_from_spec(spec)
spec.loader.exec_module(parse_wbs)

WBS_ID_PATTERN = parse_wbs.WBS_ID_PATTERN
HEADER_ALIASES = parse_wbs.HEADER_ALIASES
split_table_row = parse_wbs.split_table_row
is_separator_row = parse_wbs.is_separator_row
detect_header_map = parse_wbs.detect_header_map
infer_iteration_from_period = parse_wbs.infer_iteration_from_period
infer_type_from_task = parse_wbs.infer_type_from_task
infer_priority_from_context = parse_wbs.infer_priority_from_context
find_wbs_files = parse_wbs.find_wbs_files

NEW_COLS = ["Iter", "Pri", "Type", "Issue"]


def build_row(cells: list[str]) -> str:
    return "| " + " | ".join(cells) + " |"


def build_separator(n: int) -> str:
    return "|" + "|".join(["-----"] * n) + "|"


def migrate_file(path: Path, dry_run: bool = False) -> bool:
    """WBS ファイルを拡張する。変更があれば True を返す。"""
    try:
        content = path.read_text(encoding="utf-8")
    except Exception as e:
        print(f"ERROR: read failed: {path}: {e}", file=sys.stderr)
        return False

    lines = content.splitlines()
    new_lines: list[str] = []

    current_section: str | None = None
    current_subsection: str | None = None
    header_map: dict[str, int] | None = None
    in_table = False
    header_line_idx_in_new: int | None = None
    header_needs_status = False  # 4 列 WBS でステータス新設が必要

    i = 0
    modified = False

    while i < len(lines):
        line = lines[i]
        stripped = line.strip()

        # 見出し
        m = re.match(r"^##\s+(.+)$", stripped)
        if m:
            current_section = m.group(1).strip()
            current_subsection = None
            header_map = None
            in_table = False
            new_lines.append(line)
            i += 1
            continue
        m = re.match(r"^###\s+(.+)$", stripped)
        if m:
            current_subsection = m.group(1).strip()
            header_map = None
            in_table = False
            new_lines.append(line)
            i += 1
            continue

        if not stripped.startswith("|"):
            new_lines.append(line)
            in_table = False
            header_map = None
            i += 1
            continue

        cells = split_table_row(line)

        # ヘッダー行検出
        new_header = detect_header_map(cells)
        if new_header is not None and not in_table:
            header_map = new_header
            in_table = True

            # 既に拡張済みか判定（Iter/Pri/Type/Issue が揃っているか）
            already_extended = all(k in header_map for k in ["iteration", "priority", "type", "issue_number"])
            if already_extended:
                # 何もしない
                new_lines.append(line)
                i += 1
                continue

            # ステータス列の有無
            has_status = "status" in header_map

            # 新ヘッダーを構築
            new_header_cells = list(cells)
            if has_status:
                status_idx = header_map["status"]
                # ステータス列の直前に Iter/Pri/Type/Issue を挿入
                for j, col in enumerate(NEW_COLS):
                    new_header_cells.insert(status_idx + j, col)
            else:
                # 末尾に Iter/Pri/Type/Issue/ステータス を追加
                new_header_cells.extend(NEW_COLS + ["ステータス"])
                header_needs_status = True

            new_lines.append(build_row(new_header_cells))
            modified = True

            # 次の行はセパレータのはず
            if i + 1 < len(lines):
                sep_line = lines[i + 1]
                sep_cells = split_table_row(sep_line)
                if is_separator_row(sep_cells):
                    # セパレータを新カラム数に合わせる
                    new_lines.append(build_separator(len(new_header_cells)))
                    i += 2
                    continue
            i += 1
            continue

        # データ行処理
        if header_map is not None and in_table:
            if is_separator_row(cells):
                new_lines.append(line)
                i += 1
                continue

            wbs_idx = header_map.get("wbs_id", 0)
            if wbs_idx >= len(cells):
                new_lines.append(line)
                i += 1
                continue

            wbs_id = cells[wbs_idx]
            if not WBS_ID_PATTERN.match(wbs_id):
                # WBS ID でないデータ行（サブヘッダー等）はそのまま通す
                new_lines.append(line)
                i += 1
                continue

            # 推測値を生成
            def get_cell(key: str) -> str | None:
                idx = header_map.get(key) if header_map else None
                if idx is None or idx >= len(cells):
                    return None
                return cells[idx] or None

            task = get_cell("task") or wbs_id
            period = get_cell("period")
            iteration = infer_iteration_from_period(period) or "—"
            priority = infer_priority_from_context(current_section, current_subsection, wbs_id)
            type_val = infer_type_from_task(task, wbs_id, current_section)
            issue_val = "—"

            new_cells = list(cells)

            # ヘッダーと同じ位置に挿入する
            if "status" in header_map:
                status_idx = header_map["status"]
                insert_values = [iteration, str(priority), type_val, issue_val]
                for j, val in enumerate(insert_values):
                    new_cells.insert(status_idx + j, val)
            else:
                # ステータス列を新設
                new_cells.extend([iteration, str(priority), type_val, issue_val, "[ ]"])

            new_lines.append(build_row(new_cells))
            modified = True
            i += 1
            continue

        # その他のテーブル行（ヘッダー未検出）
        new_lines.append(line)
        i += 1

    if not modified:
        return False

    if dry_run:
        print(f"--- {path} ---")
        import difflib
        diff = difflib.unified_diff(lines, new_lines, lineterm="")
        for ln in diff:
            print(ln)
        return True

    path.write_text("\n".join(new_lines) + ("\n" if content.endswith("\n") else ""), encoding="utf-8")
    return True


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--all", action="store_true", help="全組織の WBS を一括移行")
    ap.add_argument("--file", help="単一ファイルを指定")
    ap.add_argument("--dry-run", action="store_true", help="変更内容を表示のみ")
    args = ap.parse_args()

    targets: list[Path] = []
    if args.file:
        targets = [Path(args.file).resolve()]
    elif args.all:
        targets = [p for _, p in find_wbs_files()]
    else:
        ap.print_help()
        return 1

    changed = 0
    for p in targets:
        if migrate_file(p, dry_run=args.dry_run):
            action = "[DRY-RUN]" if args.dry_run else "[MIGRATED]"
            print(f"{action} {p}")
            changed += 1
        else:
            print(f"[SKIP]     {p} (already extended)")

    print(f"\n{changed}/{len(targets)} files migrated")
    return 0


if __name__ == "__main__":
    sys.exit(main())
