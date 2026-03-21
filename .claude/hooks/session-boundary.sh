#!/usr/bin/env bash
# Stop hook: セッション終了時に区切り線追記 + GitHub Issue 作成 or コメント追記
set -uo pipefail

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
DATETIME=$(date '+%Y-%m-%d %H:%M:%S')

ACTIVE_FILE=".companies/.active"
[[ ! -f "$ACTIVE_FILE" ]] && exit 0
ORG_SLUG=$(tr -d '[:space:]' < "$ACTIVE_FILE")
[[ -z "$ORG_SLUG" ]] && exit 0

LOG_DIR=".companies/${ORG_SLUG}/.interaction-log"
LOG_FILE="${LOG_DIR}/${TODAY}.md"
[[ ! -f "$LOG_FILE" ]] && exit 0

# 1. 区切り線を追記
printf '\n---\n\n_セッション終了: %s_\n\n' "$DATETIME" >> "$LOG_FILE"

# 2. GitHub Issue 作成 / コメント追記
command -v gh &>/dev/null || exit 0
gh auth status &>/dev/null 2>&1 || exit 0

ENTRY_COUNT=$(grep -c '^### ' "$LOG_FILE" 2>/dev/null || echo "0")
[[ "$ENTRY_COUNT" -eq 0 ]] && exit 0

TITLE="[${ORG_SLUG}] インタラクションログ ${TODAY}"
[[ -n "$SESSION_SHORT" ]] && TITLE="${TITLE} (${SESSION_SHORT})"

LOG_CONTENT=$(cat "$LOG_FILE")
MAX_CHARS=60000
if [[ ${#LOG_CONTENT} -gt $MAX_CHARS ]]; then
  LOG_CONTENT="${LOG_CONTENT:0:$MAX_CHARS}"$'\n\n_（文字数制限により末尾を省略）_'
fi

ensure_label() {
  gh label create "$1" --color "$2" --description "$3" --force 2>/dev/null || true
}
ensure_label "interaction-log" "0075ca" "自動生成インタラクションログ"
ensure_label "org:${ORG_SLUG}"  "7057ff" "組織: ${ORG_SLUG}"

# 同日の既存 Issue を検索
EXISTING_ISSUE_NUMBER=$(gh issue list \
  --label "interaction-log" \
  --label "org:${ORG_SLUG}" \
  --state open \
  --json number,title \
  --jq ".[] | select(.title | startswith(\"[${ORG_SLUG}] インタラクションログ ${TODAY}\")) | .number" \
  2>/dev/null | head -1)

SESSION_LABEL=""
[[ -n "$SESSION_SHORT" ]] && SESSION_LABEL=" \`(${SESSION_SHORT})\`"

COMMENT_BODY=$(cat <<EOF
## セッション追記${SESSION_LABEL}

| 項目 | 値 |
|------|-----|
| セッションID | \`${SESSION_ID:-不明}\` |
| 終了時刻 | ${DATETIME} |
| ツール実行数 | ${ENTRY_COUNT} 回 |

<details>
<summary>ログを展開する</summary>

${LOG_CONTENT}

</details>
EOF
)

if [[ -n "$EXISTING_ISSUE_NUMBER" ]]; then
  # 既存 Issue にコメント追記
  ISSUE_URL=$(gh issue comment "$EXISTING_ISSUE_NUMBER" \
    --body "$COMMENT_BODY" \
    2>/dev/null && \
    gh issue view "$EXISTING_ISSUE_NUMBER" --json url --jq '.url' 2>/dev/null)
else
  # 当日初回: 新規 Issue を作成
  ISSUE_BODY=$(cat <<EOF
## セッション情報

| 項目 | 値 |
|------|-----|
| 組織 | \`${ORG_SLUG}\` |
| 日付 | ${TODAY} |
| 記録ファイル | \`.companies/${ORG_SLUG}/.interaction-log/${TODAY}.md\` |

---

_このIssueは1日1件作成されます。同日の追加セッションはコメントに追記されます。_

## 初回セッション${SESSION_LABEL}

| 項目 | 値 |
|------|-----|
| セッションID | \`${SESSION_ID:-不明}\` |
| 終了時刻 | ${DATETIME} |
| ツール実行数 | ${ENTRY_COUNT} 回 |

<details>
<summary>ログを展開する</summary>

${LOG_CONTENT}

</details>
EOF
)
  ISSUE_URL=$(gh issue create \
    --title "$TITLE" \
    --body "$ISSUE_BODY" \
    --label "interaction-log" \
    --label "org:${ORG_SLUG}" \
    2>/dev/null)
fi

[[ -n "$ISSUE_URL" ]] && printf '\n> GitHub Issue: %s\n' "$ISSUE_URL" >> "$LOG_FILE"

exit 0
