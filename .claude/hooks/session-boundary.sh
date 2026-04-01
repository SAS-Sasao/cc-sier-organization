#!/usr/bin/env bash
# .claude/hooks/session-boundary.sh
#
# Stop hook: セッション終了時に以下を実行
#   1. ログファイルに区切り線を追記
#   2. セッション統計 JSON を .session-summaries/ に保存（AIなし・軽量）
#   3. GitHub Issue にミニサマリー付きコメントを投稿

set -uo pipefail

# ================================================================
# 0. stdin から session_id を取得
# ================================================================
INPUT=$(cat 2>/dev/null) || INPUT=""

SESSION_ID=""
if [[ -n "$INPUT" ]]; then
  if command -v jq &>/dev/null; then
    SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // ""' 2>/dev/null)
  elif command -v python3 &>/dev/null; then
    SESSION_ID=$(echo "$INPUT" | python3 -c \
      "import sys,json; d=json.load(sys.stdin); print(d.get('session_id',''))" 2>/dev/null)
  fi
fi

SESSION_SHORT="${SESSION_ID:0:8}"
TODAY=$(date '+%Y-%m-%d')
TIMESTAMP=$(date '+%Y%m%d-%H%M%S')
DATETIME=$(date '+%Y-%m-%d %H:%M:%S')

# ================================================================
# 1. アクティブ組織の取得
# ================================================================
ACTIVE_FILE=".companies/.active"
[[ ! -f "$ACTIVE_FILE" ]] && exit 0

ORG_SLUG=$(tr -d '[:space:]' < "$ACTIVE_FILE")
[[ -z "$ORG_SLUG" ]] && exit 0

LOG_DIR=".companies/${ORG_SLUG}/.interaction-log"
LOG_FILE="${LOG_DIR}/${TODAY}.md"

[[ ! -f "$LOG_FILE" ]] && exit 0

# ================================================================
# 2. 区切り線を追記
# ================================================================
printf '\n---\n\n_セッション終了: %s_\n\n' "$DATETIME" >> "$LOG_FILE"

# ================================================================
# 3. セッション統計を抽出（bashのみ・AIなし）
# ================================================================
ENTRY_COUNT=$(grep -c '^### ' "$LOG_FILE" 2>/dev/null) || ENTRY_COUNT=0

WRITE_COUNT=$(grep -cE '^### .* — \*\*(Write|Edit|Create|create_file|str_replace_based_edit_tool)\*\*' \
  "$LOG_FILE" 2>/dev/null) || WRITE_COUNT=0
READ_COUNT=$(grep -cE '^### .* — \*\*(Read|View)\*\*' \
  "$LOG_FILE" 2>/dev/null) || READ_COUNT=0
BASH_COUNT=$(grep -cE '^### .* — \*\*(Bash|bash_tool)\*\*' \
  "$LOG_FILE" 2>/dev/null) || BASH_COUNT=0
OTHER_COUNT=$(( ENTRY_COUNT - WRITE_COUNT - READ_COUNT - BASH_COUNT ))
[[ $OTHER_COUNT -lt 0 ]] && OTHER_COUNT=0

WRITTEN_FILES=""
if command -v python3 &>/dev/null; then
  WRITTEN_FILES=$(python3 - "$LOG_FILE" <<'PYEOF'
import sys, re

log_path = sys.argv[1]
try:
    with open(log_path) as f:
        content = f.read()
except Exception:
    sys.exit(0)

write_tools = {
    'Write', 'Edit', 'Create', 'create_file',
    'str_replace_based_edit_tool', 'str_replace'
}
entries = re.split(r'\n(?=### )', content)
seen = []
for entry in entries:
    m = re.search(r'— \*\*([^*]+)\*\*', entry)
    if not m:
        continue
    tool = m.group(1).strip()
    if tool in write_tools:
        pm = re.search(r'path: `([^`]+)`', entry)
        if pm and pm.group(1) not in seen:
            seen.append(pm.group(1))

for p in seen[:8]:
    print(f'- `{p}`')
PYEOF
  )
fi

# ================================================================
# 4. セッション統計 JSON を .session-summaries/ に保存
# ================================================================
SUMMARY_DIR=".companies/${ORG_SLUG}/.session-summaries"
mkdir -p "$SUMMARY_DIR"

JSON_FILE="${SUMMARY_DIR}/${TIMESTAMP}-${SESSION_SHORT}.json"

WRITTEN_JSON="[]"
if command -v python3 &>/dev/null && [[ -n "$WRITTEN_FILES" ]]; then
  WRITTEN_JSON=$(echo "$WRITTEN_FILES" | python3 -c "
import sys, json
lines = [l.strip().lstrip('- ').strip('\`') for l in sys.stdin if l.strip().startswith('-')]
print(json.dumps(lines))
" 2>/dev/null || echo "[]")
fi

cat > "$JSON_FILE" <<JSONEOF
{
  "session_id": "${SESSION_ID:-}",
  "org_slug": "${ORG_SLUG}",
  "date": "${TODAY}",
  "datetime": "${DATETIME}",
  "tool_count": ${ENTRY_COUNT},
  "by_type": {
    "write": ${WRITE_COUNT},
    "read": ${READ_COUNT},
    "bash": ${BASH_COUNT},
    "other": ${OTHER_COUNT}
  },
  "files_written": ${WRITTEN_JSON},
  "log_file": ".companies/${ORG_SLUG}/.interaction-log/${TODAY}.md"
}
JSONEOF

# ================================================================
# 5. GitHub Issue 投稿（gh CLI がある場合のみ）
# ================================================================
command -v gh &>/dev/null       || exit 0
gh auth status &>/dev/null 2>&1 || exit 0

[[ "$ENTRY_COUNT" -eq 0 ]] && exit 0

# ================================================================
# 5.5 会話ログのキャプチャ
# ================================================================
if [[ -f ".claude/hooks/capture-conversation.sh" ]]; then
  bash .claude/hooks/capture-conversation.sh <<< "$INPUT" 2>/dev/null || true
fi

# 会話サマリーを読み込む（capture-conversation.sh が生成）
CONV_SUMMARY=""
CONV_SUMMARY_FILE="/tmp/conv-summary-${SESSION_SHORT}.txt"
if [[ -f "$CONV_SUMMARY_FILE" ]]; then
  CONV_SUMMARY=$(cat "$CONV_SUMMARY_FILE")
  rm -f "$CONV_SUMMARY_FILE"
fi

ensure_label() {
  gh label create "$1" --color "$2" --description "$3" --force 2>/dev/null || true
}
ensure_label "interaction-log" "0075ca" "自動生成インタラクションログ"
ensure_label "org:${ORG_SLUG}"  "7057ff" "組織: ${ORG_SLUG}"

EXISTING_ISSUE_NUMBER=$(gh issue list \
  --label "interaction-log" \
  --label "org:${ORG_SLUG}" \
  --state open \
  --json number,title \
  --jq ".[] | select(.title | startswith(\"[${ORG_SLUG}] インタラクションログ ${TODAY}\")) | .number" \
  2>/dev/null | head -1)

LOG_CONTENT=$(cat "$LOG_FILE")
MAX_CHARS=60000
if [[ ${#LOG_CONTENT} -gt $MAX_CHARS ]]; then
  LOG_CONTENT="${LOG_CONTENT:0:$MAX_CHARS}"$'\n\n_（文字数制限により末尾を省略）_'
fi

SESSION_LABEL=""
[[ -n "$SESSION_SHORT" ]] && SESSION_LABEL=" \`(${SESSION_SHORT})\`"

WRITTEN_SECTION=""
if [[ -n "$WRITTEN_FILES" ]]; then
  WRITTEN_SECTION=$(printf '\n**書き込みファイル (%d件):**\n%s\n' "$WRITE_COUNT" "$WRITTEN_FILES")
fi

SESSION_BODY=$(cat <<EOF
## セッション統計${SESSION_LABEL}

| 項目 | 値 |
|------|-----|
| 終了時刻 | ${DATETIME} |
| ツール実行数（累計） | ${ENTRY_COUNT} 回 |
| Write / Edit | ${WRITE_COUNT} 回 |
| Read / View | ${READ_COUNT} 回 |
| Bash | ${BASH_COUNT} 回 |
| その他 | ${OTHER_COUNT} 回 |
${WRITTEN_SECTION}
<details>
<summary>全ログを展開する</summary>

${LOG_CONTENT}

</details>
${CONV_SUMMARY:+

---

${CONV_SUMMARY}
}
EOF
)

TITLE="[${ORG_SLUG}] インタラクションログ ${TODAY}"

if [[ -n "$EXISTING_ISSUE_NUMBER" ]]; then
  ISSUE_URL=$(gh issue comment "$EXISTING_ISSUE_NUMBER" \
    --body "$SESSION_BODY" 2>/dev/null && \
    gh issue view "$EXISTING_ISSUE_NUMBER" --json url --jq '.url' 2>/dev/null)
else
  FIRST_BODY=$(cat <<EOF
## 概要

| 項目 | 値 |
|------|-----|
| 組織 | \`${ORG_SLUG}\` |
| 日付 | ${TODAY} |
| 記録ファイル | \`.companies/${ORG_SLUG}/.interaction-log/${TODAY}.md\` |

_1日1件作成。追加セッションはコメントに追記されます。_

${SESSION_BODY}
EOF
)
  ISSUE_URL=$(gh issue create \
    --title "$TITLE" \
    --body "$FIRST_BODY" \
    --label "interaction-log" \
    --label "org:${ORG_SLUG}" \
    2>/dev/null)
fi

[[ -n "${ISSUE_URL:-}" ]] && printf '\n> GitHub Issue: %s\n' "$ISSUE_URL" >> "$LOG_FILE"

# ================================================================
# 6. Skill Evaluator + Case Bank 再構築（Memento-Skills Write フェーズ）
# ================================================================
EVALUATOR=".claude/hooks/skill-evaluator.sh"
REBUILDER=".claude/hooks/rebuild-case-bank.sh"

if [[ -f "$EVALUATOR" ]] && [[ -f "$REBUILDER" ]]; then
  source "$EVALUATOR"
  source "$REBUILDER"
  evaluate_session "$ORG_SLUG" "$TODAY"
  rebuild_case_bank "$ORG_SLUG"
fi

# ================================================================
# 7. Phase 3: Skill Synthesizer + Subagent Refiner（自律進化）
# ================================================================
SYNTHESIZER=".claude/hooks/skill-synthesizer.sh"
REFINER=".claude/hooks/subagent-refiner.sh"
OPERATOR=$(git config user.name 2>/dev/null || echo "anonymous")

if [[ -f "$SYNTHESIZER" ]] && [[ -f "$REFINER" ]]; then
  source "$SYNTHESIZER"
  source "$REFINER"
  synthesize_skills "$ORG_SLUG" "$OPERATOR"
  refine_subagents  "$ORG_SLUG" "$OPERATOR"
fi

exit 0
