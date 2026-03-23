#!/usr/bin/env bash
# .claude/hooks/capture-conversation.sh
#
# Stop Hook: セッション終了時に会話ログを取得・マスキング・MD保存する
#
# 処理フロー:
#   1. session_id を stdin から取得
#   2. ~/.claude/projects/{hash}/{session_id}.jsonl を読み込む
#   3. masters/customers/ から固有名詞リストを収集
#   4. マスキング処理（顧客名・担当者名・金額・連絡先）
#   5. Markdown形式に整形して .conversation-log/ に保存
#   6. セッションサマリーを抽出して返す（session-boundary.sh で使用）

set -uo pipefail

# ================================================================
# 0. 入力取得
# ================================================================
INPUT=$(cat 2>/dev/null) || INPUT=""

SESSION_ID=""
if [[ -n "$INPUT" ]] && command -v python3 &>/dev/null; then
  SESSION_ID=$(echo "$INPUT" | python3 -c "
import sys, json
try:
  d = json.load(sys.stdin)
  print(d.get('session_id', ''))
except: pass
" 2>/dev/null)
fi

[[ -z "$SESSION_ID" ]] && exit 0

# ================================================================
# 1. 組織情報取得
# ================================================================
ACTIVE_FILE=".companies/.active"
[[ ! -f "$ACTIVE_FILE" ]] && exit 0
ORG_SLUG=$(tr -d '[:space:]' < "$ACTIVE_FILE")
[[ -z "$ORG_SLUG" ]] && exit 0

TODAY=$(date '+%Y-%m-%d')
DATETIME=$(date '+%Y-%m-%d %H:%M:%S')
OPERATOR=$(git config user.name 2>/dev/null || echo "anonymous")

# ================================================================
# 2. 会話ログファイルの特定
# ================================================================
PROJECT_PATH=$(pwd)
# Claude Code のプロジェクトディレクトリ名: パスのスラッシュをハイフンに置換
PROJECT_DIR_NAME=$(echo "$PROJECT_PATH" | sed 's|/|-|g')
CONV_FILE="$HOME/.claude/projects/${PROJECT_DIR_NAME}/${SESSION_ID}.jsonl"

if [[ ! -f "$CONV_FILE" ]]; then
  # フォールバック: session_id でディレクトリを検索
  CONV_FILE=$(find "$HOME/.claude/projects/" -name "${SESSION_ID}.jsonl" 2>/dev/null | head -1)
fi

[[ ! -f "$CONV_FILE" ]] && exit 0

# ================================================================
# 3. マスキング処理 + MD変換
# ================================================================
python3 - "$CONV_FILE" "$ORG_SLUG" "$TODAY" "$DATETIME" "$SESSION_ID" "$OPERATOR" \
  ".companies/${ORG_SLUG}/masters/customers" \
  ".companies/${ORG_SLUG}/.conversation-log" <<'PYEOF'
import sys, json, re, os
from pathlib import Path
from datetime import datetime

conv_file    = Path(sys.argv[1])
org_slug     = sys.argv[2]
today        = sys.argv[3]
datetime_str = sys.argv[4]
session_id   = sys.argv[5]
operator     = sys.argv[6]
customers_dir = Path(sys.argv[7])
output_dir   = Path(sys.argv[8])

# ================================================================
# マスキング辞書の構築
# ================================================================
mask_map = {}
client_counter = 0
person_counter = 0

if customers_dir.exists():
    for customer_file in customers_dir.glob("*.md"):
        text = customer_file.read_text(encoding="utf-8", errors="ignore")
        # 顧客名（ファイル名 + 本文の名前パターン）
        slug = customer_file.stem
        name_match = re.search(r'^#\s+(.+)', text, re.MULTILINE)
        if name_match:
            name = name_match.group(1).strip()
            if name and name not in mask_map:
                client_counter += 1
                mask_map[name] = f"[CLIENT-{client_counter:02d}]"

        # 担当者名（「担当者:」「担当:」などの後の名前）
        persons = re.findall(r'担当[者:]?\s*[:：]\s*([^\n、,]+)', text)
        for person in persons:
            person = person.strip().split('（')[0].split('様')[0].strip()
            if person and len(person) >= 2 and person not in mask_map:
                person_counter += 1
                mask_map[person] = f"[PERSON-{person_counter:02d}]"

def mask_text(text):
    """テキストに対してマスキングを適用する"""
    # 固有名詞マスキング（長い順に処理して部分一致を防ぐ）
    for original, masked in sorted(mask_map.items(), key=lambda x: -len(x[0])):
        text = text.replace(original, masked)

    # 電話番号 → [PHONE]
    text = re.sub(r'\d{2,4}[-\s]?\d{2,4}[-\s]?\d{3,4}', '[PHONE]', text)

    # メールアドレス → [EMAIL]
    text = re.sub(r'[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}', '[EMAIL]', text)

    # 金額っぽい数字（5桁以上） → [NUMBER]
    text = re.sub(r'¥[\d,]+|[\d,]{5,}円', '[NUMBER]', text)

    return text

# ================================================================
# JSONL のパース
# ================================================================
turns = []
try:
    for line in conv_file.read_text(encoding="utf-8", errors="ignore").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            entry = json.loads(line)
            turns.append(entry)
        except json.JSONDecodeError:
            continue
except Exception:
    sys.exit(0)

if not turns:
    sys.exit(0)

# ================================================================
# Markdown 生成
# ================================================================
output_dir.mkdir(parents=True, exist_ok=True)

session_short = session_id[:8]
md_filename = f"{today}-{session_short}.md"
md_path = output_dir / md_filename

lines = []
lines.append(f"---")
lines.append(f"session_id: \"{session_id}\"")
lines.append(f"date: \"{today}\"")
lines.append(f"datetime: \"{datetime_str}\"")
lines.append(f"operator: \"{operator}\"")
lines.append(f"org: \"{org_slug}\"")
lines.append(f"masked: true")
lines.append(f"---")
lines.append(f"")
lines.append(f"# 会話ログ — {today} `{session_short}`")
lines.append(f"")
lines.append(f"> 組織: {org_slug} ／ オペレーター: {operator} ／ 生成: {datetime_str}")
lines.append(f"")
lines.append(f"---")
lines.append(f"")

human_count = 0
assistant_count = 0
tool_count = 0
human_messages = []  # サマリー用

for entry in turns:
    # JSONL structure: entry.message.role / entry.message.content
    message = entry.get("message")
    if not isinstance(message, dict):
        continue
    role = message.get("role", "")
    content = message.get("content", "")

    if role == "user":
        human_count += 1
        if isinstance(content, str):
            masked = mask_text(content)
            lines.append(f"## 👤 Human")
            lines.append(f"")
            lines.append(masked)
            lines.append(f"")
            lines.append(f"---")
            lines.append(f"")
            if len(masked) > 10:
                human_messages.append(masked[:100])

        elif isinstance(content, list):
            lines.append(f"## 👤 Human")
            lines.append(f"")
            for block in content:
                if isinstance(block, dict):
                    if block.get("type") == "text":
                        masked = mask_text(block.get("text", ""))
                        lines.append(masked)
                        if len(masked) > 10:
                            human_messages.append(masked[:100])
                    elif block.get("type") == "tool_result":
                        tool_count += 1
                        lines.append(f"```tool_result")
                        result_content = block.get("content", "")
                        if isinstance(result_content, list):
                            for rc in result_content:
                                if isinstance(rc, dict) and rc.get("type") == "text":
                                    lines.append(mask_text(rc.get("text", ""))[:500])
                        elif isinstance(result_content, str):
                            lines.append(mask_text(result_content)[:500])
                        lines.append(f"```")
            lines.append(f"")
            lines.append(f"---")
            lines.append(f"")

    elif role == "assistant":
        assistant_count += 1
        lines.append(f"## 🤖 Claude")
        lines.append(f"")

        if isinstance(content, str):
            lines.append(mask_text(content))

        elif isinstance(content, list):
            for block in content:
                if isinstance(block, dict):
                    btype = block.get("type", "")
                    if btype == "text":
                        masked = mask_text(block.get("text", ""))
                        lines.append(masked)
                    elif btype == "tool_use":
                        tool_count += 1
                        tool_name = block.get("name", "unknown")
                        tool_input = block.get("input", {})
                        lines.append(f"")
                        lines.append(f"```tool_use:{tool_name}")
                        if isinstance(tool_input, dict):
                            for k, v in list(tool_input.items())[:5]:
                                v_str = str(v)[:200] if v else ""
                                lines.append(f"{k}: {mask_text(v_str)}")
                        lines.append(f"```")

        lines.append(f"")
        lines.append(f"---")
        lines.append(f"")

# 統計セクション
lines.append(f"## 統計")
lines.append(f"")
lines.append(f"| 項目 | 値 |")
lines.append(f"|---|---|")
lines.append(f"| 人間の発言数 | {human_count} |")
lines.append(f"| Claudeの応答数 | {assistant_count} |")
lines.append(f"| ツール実行数 | {tool_count} |")
lines.append(f"| マスキング適用 | {len(mask_map)} 種類 |")
lines.append(f"")
lines.append(f"---")
lines.append(f"_このログは capture-conversation.sh によって自動生成されました_")

md_path.write_text("\n".join(lines), encoding="utf-8")

# ================================================================
# サマリー（session-boundary.sh に渡す用）
# ================================================================
summary_lines = []
summary_lines.append(f"## 会話ログ")
summary_lines.append(f"")
summary_lines.append(f"| 項目 | 値 |")
summary_lines.append(f"|---|---|")
summary_lines.append(f"| 人間の発言 | {human_count} 回 |")
summary_lines.append(f"| Claudeの応答 | {assistant_count} 回 |")
summary_lines.append(f"| ツール実行 | {tool_count} 回 |")
summary_lines.append(f"")

if human_messages:
    summary_lines.append(f"**主な依頼内容（{len(human_messages)}件）:**")
    for msg in human_messages:
        first_line = msg.split('\n')[0][:80]
        summary_lines.append(f"- {first_line}")
    summary_lines.append(f"")

summary_lines.append(f"ログファイル: `.companies/{org_slug}/.conversation-log/{md_filename}`")

# サマリーを一時ファイルに書き出す（session-boundary.sh が読む）
summary_path = Path(f"/tmp/conv-summary-{session_id[:8]}.txt")
summary_path.write_text("\n".join(summary_lines), encoding="utf-8")

print(f"✅ 会話ログを保存: {md_path}")
print(f"   turns: {human_count}H + {assistant_count}A + {tool_count}T")

PYEOF

exit 0
