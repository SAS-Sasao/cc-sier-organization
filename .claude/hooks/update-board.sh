#!/usr/bin/env bash
# タスクボード操作ユーティリティ（secretary.md から source して使う）

board_path() { echo ".companies/$1/docs/secretary/board.md"; }

board_add_task() {
  local org="$1" id="$2" content="$3" op="${4:-—}" due="${5:-—}"
  local board; board=$(board_path "$org")
  [[ ! -f "$board" ]] && return 0
  python3 - "$board" "$id" "$content" "$op" "$due" <<'PY'
import sys, re
board, id, content, op, due = sys.argv[1:]
text = open(board).read()
new_row = f'| {id} | {content} | {op} | {due} | — |\n'
text = re.sub(r'(## 🔵 Todo.*?\n\|---[^\n]*\n)', r'\1' + new_row, text, count=1, flags=re.DOTALL)
open(board, 'w').write(text)
PY
}

board_start_task() {
  local org="$1" id="$2" op="${3:-—}"
  local board; board=$(board_path "$org")
  [[ ! -f "$board" ]] && return 0
  local today; today=$(date '+%Y-%m-%d')
  python3 - "$board" "$id" "$op" "$today" <<'PY'
import sys, re
board, id, op, today = sys.argv[1:]
text = open(board).read()
m = re.search(r'\| ' + re.escape(id) + r' \|([^\n]+)\n', text)
if not m: sys.exit(0)
cols = [c.strip() for c in m.group(0).split('|')]
content = cols[2] if len(cols) > 2 else id
text = text.replace(m.group(0), '')
new_row = f'| {id} | {content} | {op} | {today} | — |\n'
text = re.sub(r'(## 🟡 In Progress.*?\n\|---[^\n]*\n)', r'\1' + new_row, text, count=1, flags=re.DOTALL)
text = re.sub(r'updated_at: ".*?"', f'updated_at: "{today}"', text)
open(board, 'w').write(text)
PY
}

board_complete_task() {
  local org="$1" id="$2" artifact="${3:-—}"
  local board; board=$(board_path "$org")
  [[ ! -f "$board" ]] && return 0
  local today; today=$(date '+%Y-%m-%d')
  local op; op=$(git config user.name 2>/dev/null || echo "—")
  python3 - "$board" "$id" "$op" "$today" "$artifact" <<'PY'
import sys, re
board, id, op, today, artifact = sys.argv[1:]
text = open(board).read()
m = re.search(r'\| ' + re.escape(id) + r'[^\n]*\n', text)
cols = [c.strip() for c in m.group(0).split('|')] if m else []
content = cols[2] if len(cols) > 2 else id
if m: text = text.replace(m.group(0), '')
art = f'`{artifact}`' if artifact != '—' else '—'
new_row = f'| {id} | {content} | {op} | {today} | {art} |\n'
text = re.sub(r'(## ✅ Done.*?\n\|---[^\n]*\n)', r'\1' + new_row, text, count=1, flags=re.DOTALL)
text = re.sub(r'updated_at: ".*?"', f'updated_at: "{today}"', text)
open(board, 'w').write(text)
PY
}

board_set_review_fail() {
  local org="$1" id="$2" file="${3:-—}" issue="${4:-—}"
  local board; board=$(board_path "$org")
  [[ ! -f "$board" ]] && return 0
  local now; now=$(date '+%Y-%m-%d %H:%M')
  local op; op=$(git config user.name 2>/dev/null || echo "—")
  python3 - "$board" "$id" "$op" "$now" "$file" "$issue" <<'PY'
import sys, re
board, id, op, now, file, issue = sys.argv[1:]
text = open(board).read()
m = re.search(r'\| ' + re.escape(id) + r'[^\n]*\n', text)
cols = [c.strip() for c in m.group(0).split('|')] if m else []
content = cols[2] if len(cols) > 2 else id
if m: text = text.replace(m.group(0), '')
iss = f'[Issue]({issue})' if issue and issue != '—' else '—'
new_row = f'| {id} | {content} | {op} | {now} | `{file}` | {iss} |\n'
text = re.sub(r'(## 🔴 Review.*?\n\|---[^\n]*\n)', r'\1' + new_row, text, count=1, flags=re.DOTALL)
open(board, 'w').write(text)
PY
}
