#!/usr/bin/env python3
"""コメント密度を測定する。ルール追加後に「実際に効いたか」を測るための道具。

体感では効いた/効かないを取り違えるため、同じ指標で前後を比較する
（根拠: docs/research/comment-density-analysis.md）。

比率だけでなく「4 行以上の連続ブロック」を必ず見ること。読み手が負担に
感じるのは全体の比率ではなくスクロール中に現れる塊であり、比率が下がっても
ブロックが減らない事例が報告されている（52 個 → 50 個）。

使い方:
    python3 .claude/hooks/measure-comment-density.py .claude/hooks/*.sh
    python3 .claude/hooks/measure-comment-density.py --json <files>
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

# 拡張子 → 行コメントの接頭辞
COMMENT_PREFIX = {
    ".sh": "#", ".bash": "#", ".py": "#", ".rb": "#", ".yml": "#", ".yaml": "#",
    ".js": "//", ".ts": "//", ".go": "//", ".java": "//", ".c": "//", ".cpp": "//",
}

BLOCK_THRESHOLD = 4  # 「長いブロック」とみなす連続行数


def analyze(paths: list[Path]) -> dict:
    total_lines = total_comments = 0
    blocks: list[int] = []
    per_file: list[dict] = []

    for p in paths:
        prefix = COMMENT_PREFIX.get(p.suffix)
        if prefix is None:
            continue
        try:
            lines = p.read_text(encoding="utf-8", errors="ignore").split("\n")
        except OSError:
            continue

        f_lines = f_comments = 0
        f_blocks: list[int] = []
        run = 0
        for line in lines:
            s = line.strip()
            if not s:
                continue  # 空行は分母に入れない（コメント比率が空行で薄まらないように）
            f_lines += 1
            if s.startswith(prefix):
                f_comments += 1
                run += 1
            else:
                if run >= BLOCK_THRESHOLD:
                    f_blocks.append(run)
                run = 0
        if run >= BLOCK_THRESHOLD:
            f_blocks.append(run)

        total_lines += f_lines
        total_comments += f_comments
        blocks.extend(f_blocks)
        per_file.append({
            "path": str(p),
            "lines": f_lines,
            "comments": f_comments,
            "ratio": round(f_comments / f_lines, 4) if f_lines else 0.0,
            "blocks": len(f_blocks),
            "max_block": max(f_blocks) if f_blocks else 0,
        })

    return {
        "files": len(per_file),
        "lines": total_lines,
        "comments": total_comments,
        "ratio": round(total_comments / total_lines, 4) if total_lines else 0.0,
        "block_threshold": BLOCK_THRESHOLD,
        "blocks": len(blocks),
        "max_block": max(blocks) if blocks else 0,
        "avg_block": round(sum(blocks) / len(blocks), 1) if blocks else 0.0,
        "per_file": sorted(per_file, key=lambda x: -x["max_block"]),
    }


def main() -> int:
    args = sys.argv[1:]
    as_json = "--json" in args
    targets = [Path(a) for a in args if a != "--json"]
    if not targets:
        print(__doc__)
        return 2

    files = [p for p in targets if p.is_file()]
    if not files:
        print("対象ファイルがありません", file=sys.stderr)
        return 1

    r = analyze(files)
    if as_json:
        print(json.dumps(r, ensure_ascii=False, indent=2))
        return 0

    print(f"ファイル {r['files']} / 実行行 {r['lines']} / コメント {r['comments']} / 比率 {r['ratio'] * 100:.1f}%")
    print(f"{r['block_threshold']} 行以上のブロック: {r['blocks']} 個 / 最大 {r['max_block']} 行 / 平均 {r['avg_block']} 行")
    top = [f for f in r["per_file"] if f["max_block"] > 0][:5]
    if top:
        print("\n最大ブロックが大きいファイル:")
        for f in top:
            print(f"  {f['max_block']:3d} 行  {f['path']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
