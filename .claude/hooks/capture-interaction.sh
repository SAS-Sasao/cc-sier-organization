#!/usr/bin/env bash
# PostToolUse hook: すべてのツール実行を .interaction-log/{YYYY-MM-DD}.md に自動追記する
set -uo pipefail

INPUT=$(cat 2>/dev/null) || exit 0
[[ -z "$INPUT" ]] && exit 0

if command -v jq &>/dev/null; then
  TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // "unknown"' 2>/dev/null)
  SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // ""' 2>/dev/null)
  TOOL_INPUT=$(echo "$INPUT" | jq -c '.tool_input // {}' 2>/dev/null)
elif command -v python3 &>/dev/null; then
  TOOL_NAME=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_name','unknown'))" 2>/dev/null)
  SESSION_ID=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('session_id',''))" 2>/dev/null)
  TOOL_INPUT=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(json.dumps(d.get('tool_input',{})))" 2>/dev/null)
else
  exit 0
fi

TOOL_NAME=${TOOL_NAME:-unknown}
SESSION_ID=${SESSION_ID:-}
TOOL_INPUT=${TOOL_INPUT:-{}}
TIMESTAMP=$(date '+%H:%M:%S')
TODAY=$(date '+%Y-%m-%d')

ACTIVE_FILE=".companies/.active"
[[ ! -f "$ACTIVE_FILE" ]] && exit 0
ORG_SLUG=$(tr -d '[:space:]' < "$ACTIVE_FILE")
[[ -z "$ORG_SLUG" ]] && exit 0

LOG_DIR=".companies/${ORG_SLUG}/.interaction-log"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/${TODAY}.md"

if [[ ! -f "$LOG_FILE" ]]; then
  printf '# インタラクションログ: %s\n\n' "$TODAY" > "$LOG_FILE"
  printf '> 自動記録（Hooks）— 手動編集不要\n\n' >> "$LOG_FILE"
fi

get_detail() {
  local tool="$1"
  local input="$2"
  if command -v jq &>/dev/null; then
    case "$tool" in
      Write|Create|create_file)
        file_path=$(echo "$input" | jq -r '.file_path // .path // ""' 2>/dev/null)
        [[ -n "$file_path" ]] && echo "path: \`${file_path}\`" || echo "(path 不明)"
        ;;
      Edit|str_replace_based_edit_tool)
        file_path=$(echo "$input" | jq -r '.file_path // .path // ""' 2>/dev/null)
        [[ -n "$file_path" ]] && echo "path: \`${file_path}\`" || echo "(path 不明)"
        ;;
      Read|View)
        file_path=$(echo "$input" | jq -r '.file_path // .path // ""' 2>/dev/null)
        [[ -n "$file_path" ]] && echo "path: \`${file_path}\`" || echo "(path 不明)"
        ;;
      Bash|bash_tool)
        cmd=$(echo "$input" | jq -r '.command // ""' 2>/dev/null | head -c 200 | tr '\n' ' ')
        [[ -n "$cmd" ]] && echo "cmd: \`${cmd}\`" || echo "(cmd 不明)"
        ;;
      Glob|Grep)
        pattern=$(echo "$input" | jq -r '.pattern // .query // ""' 2>/dev/null)
        [[ -n "$pattern" ]] && echo "pattern: \`${pattern}\`" || echo "(pattern 不明)"
        ;;
      web_search)
        key=$(echo "$input" | jq -r '.query // ""' 2>/dev/null)
        [[ -n "$key" ]] && echo "query: \`${key}\`" || echo "(query 不明)"
        ;;
      *)
        echo "input: \`$(echo "$input" | head -c 120 | tr '\n' ' ')\`"
        ;;
    esac
  else
    echo "tool: ${tool}"
  fi
}

DETAIL=$(get_detail "$TOOL_NAME" "$TOOL_INPUT")
SESSION_SHORT="${SESSION_ID:0:8}"
[[ -n "$SESSION_SHORT" ]] && SESSION_TAG=" \`${SESSION_SHORT}\`" || SESSION_TAG=""

printf '### %s — **%s**%s\n' "$TIMESTAMP" "$TOOL_NAME" "$SESSION_TAG" >> "$LOG_FILE"
printf '- %s\n\n' "$DETAIL" >> "$LOG_FILE"

exit 0
