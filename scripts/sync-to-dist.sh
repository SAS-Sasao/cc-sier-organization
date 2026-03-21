#!/usr/bin/env bash
# sync-to-dist.sh — plugins/cc-sier/ の内容を dist/cc-sier/ に同期する
# 配布用パッケージを生成するスクリプト
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC_DIR="$ROOT_DIR/plugins/cc-sier"
DIST_DIR="$ROOT_DIR/dist/cc-sier"

echo "=== CC-SIer dist 同期スクリプト ==="
echo "ソース:  $SRC_DIR"
echo "出力先:  $DIST_DIR"
echo ""

# dist/ をクリーンアップ
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

# Skills をコピー
echo "[1/4] Skills をコピー..."
mkdir -p "$DIST_DIR/skills"
cp -r "$SRC_DIR/skills/company" "$DIST_DIR/skills/"
cp -r "$SRC_DIR/skills/company-admin" "$DIST_DIR/skills/"
cp -r "$SRC_DIR/skills/company-spawn" "$DIST_DIR/skills/"

# Agents をコピー（plugins/cc-sier/agents/ の初期同梱ファイルのみ）
echo "[2/4] Agents をコピー..."
mkdir -p "$DIST_DIR/agents"
cp "$SRC_DIR/agents/"*.md "$DIST_DIR/agents/"

# .claude-plugin/ をコピー
echo "[3/4] .claude-plugin/ をコピー..."
cp -r "$ROOT_DIR/.claude-plugin" "$DIST_DIR/.claude-plugin"

# README と LICENSE をコピー
echo "[4/4] README.md, LICENSE をコピー..."
[ -f "$ROOT_DIR/README.md" ] && cp "$ROOT_DIR/README.md" "$DIST_DIR/"
[ -f "$ROOT_DIR/LICENSE" ] && cp "$ROOT_DIR/LICENSE" "$DIST_DIR/"

echo ""
echo "=== 同期完了 ==="
echo ""

# 結果の確認
echo "--- dist/cc-sier/ 構成 ---"
find "$DIST_DIR" -type f | sed "s|$ROOT_DIR/||" | sort

echo ""
SKILL_COUNT=$(find "$DIST_DIR/skills" -name "SKILL.md" | wc -l)
AGENT_COUNT=$(find "$DIST_DIR/agents" -name "*.md" | wc -l)
REF_COUNT=$(find "$DIST_DIR/skills" -path "*/references/*" -type f | wc -l)

echo "Skills: $SKILL_COUNT"
echo "Agents: $AGENT_COUNT"
echo "References: $REF_COUNT"
