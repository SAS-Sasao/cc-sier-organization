#!/usr/bin/env bash
# .claude/hooks/quality-gate.sh
# PostToolUse Hook: docs/ 配下へのWriteが完了したときに品質チェックを実行

set -uo pipefail

INPUT=$(cat 2>/dev/null) || INPUT=""

# 書き込まれたファイルパスを取得
FILE_PATH=""
if command -v python3 &>/dev/null && [[ -n "$INPUT" ]]; then
  FILE_PATH=$(echo "$INPUT" | python3 -c "
import sys, json
try:
  d = json.load(sys.stdin)
  path = d.get('tool_input', {}).get('path', '') or d.get('tool_input', {}).get('file_path', '')
  print(path)
except: pass
" 2>/dev/null)
fi

# docs/.md のみ対象
[[ -z "$FILE_PATH" ]] && exit 0
[[ "$FILE_PATH" != *"/docs/"* ]] && exit 0
[[ "$FILE_PATH" != *.md ]] && exit 0

# 組織情報取得
ACTIVE_FILE=".companies/.active"
[[ ! -f "$ACTIVE_FILE" ]] && exit 0
ORG_SLUG=$(tr -d '[:space:]' < "$ACTIVE_FILE")
[[ -z "$ORG_SLUG" ]] && exit 0

GATE_DIR=".companies/${ORG_SLUG}/masters/quality-gates"
[[ ! -d "$GATE_DIR" ]] && exit 0

TODAY=$(date '+%Y-%m-%d')
DATETIME=$(date '+%Y-%m-%d %H:%M:%S')

# 適用チェックリストを決定
CHECKLIST_FILES=()
[[ -f "${GATE_DIR}/_default.md" ]] && CHECKLIST_FILES+=("${GATE_DIR}/_default.md")

if   [[ "$FILE_PATH" == */requirements* ]]; then CHECKLIST_FILES+=("${GATE_DIR}/by-type/requirements.md")
elif [[ "$FILE_PATH" == */design* ]] || [[ "$FILE_PATH" == */architecture* ]]; then CHECKLIST_FILES+=("${GATE_DIR}/by-type/design.md")
elif [[ "$FILE_PATH" == */proposals* ]]; then CHECKLIST_FILES+=("${GATE_DIR}/by-type/proposal.md")
elif [[ "$FILE_PATH" == */reports* ]]; then CHECKLIST_FILES+=("${GATE_DIR}/by-type/report.md")
elif [[ "$FILE_PATH" == */adrs* ]]; then CHECKLIST_FILES+=("${GATE_DIR}/by-type/adr.md")
fi

for customer_gate in "${GATE_DIR}/by-customer/"*.md; do
  [[ -f "$customer_gate" ]] || continue
  [[ "$customer_gate" == *"_template.md" ]] && continue
  CUSTOMER_SLUG=$(basename "$customer_gate" .md)
  [[ "$FILE_PATH" == *"$CUSTOMER_SLUG"* ]] && CHECKLIST_FILES+=("$customer_gate")
done

[[ ${#CHECKLIST_FILES[@]} -eq 0 ]] && exit 0

# チェック実行
GATE_RESULT_RAW=$(python3 - "$FILE_PATH" "${CHECKLIST_FILES[@]}" <<'PYEOF'
import sys, re, json
from pathlib import Path

target_path = Path(sys.argv[1])
checklist_paths = [Path(p) for p in sys.argv[2:] if Path(p).exists()]

if not target_path.exists():
    print(json.dumps({"status": "skip"})); sys.exit(0)

target_text = target_path.read_text(encoding="utf-8", errors="ignore")
errors, warnings = [], []

for cl_path in checklist_paths:
    cl_text = cl_path.read_text(encoding="utf-8", errors="ignore")
    fm = re.search(r'^---\n(.*?)\n---', cl_text, re.DOTALL)
    severity = "error"
    if fm:
        for line in fm.group(1).splitlines():
            if line.startswith("severity_on_fail:"):
                severity = line.split(":", 1)[1].strip()

    for check in re.findall(r'- \[ \] (.+)', cl_text):
        kws = re.findall(r'[\w\u3040-\u9fff\u4e00-\u9faf]{3,}', check)
        hit = any(kw in target_text for kw in kws[:4] if len(kw) >= 3)
        if not hit:
            item = {"check": check.strip(), "cl": cl_path.name}
            (errors if severity == "error" else warnings).append(item)

result = {
    "status": "fail" if errors else "pass",
    "error_count": len(errors), "warning_count": len(warnings),
    "errors": errors[:10], "warnings": warnings[:5],
    "target": str(target_path),
    "checklists": [p.name for p in checklist_paths],
}
print(json.dumps(result, ensure_ascii=False))
PYEOF
)

[[ -z "$GATE_RESULT_RAW" ]] && exit 0

STATUS=$(echo "$GATE_RESULT_RAW" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status','skip'))" 2>/dev/null)
[[ "$STATUS" == "skip" ]] && exit 0

# ログ保存
GATE_LOG_DIR=".companies/${ORG_SLUG}/.quality-gate-log"
mkdir -p "$GATE_LOG_DIR"
echo "$GATE_RESULT_RAW" >> "${GATE_LOG_DIR}/${TODAY}.jsonl"

# タスクボード更新
if [[ -f ".claude/hooks/update-board.sh" ]]; then
  source ".claude/hooks/update-board.sh"
  if [[ "$STATUS" == "fail" ]]; then
    board_set_review_fail "$ORG_SLUG" "$(basename $FILE_PATH .md)" "$(basename $FILE_PATH)" ""
  fi
fi

# Fail → GitHub Issue
if [[ "$STATUS" == "fail" ]]; then
  command -v gh &>/dev/null || { printf '\n⚠️ 品質NG（gh未認証）: %s\n' "$FILE_PATH" >&2; exit 0; }
  gh auth status &>/dev/null 2>&1 || { printf '\n⚠️ 品質NG: %s\n' "$FILE_PATH" >&2; exit 0; }

  ERROR_COUNT=$(echo "$GATE_RESULT_RAW" | python3 -c "import sys,json; print(json.load(sys.stdin).get('error_count',0))" 2>/dev/null)
  ERRORS_TEXT=$(echo "$GATE_RESULT_RAW" | python3 -c "
import sys,json
for e in json.load(sys.stdin).get('errors',[]): print(f\"- [ ] {e['check']}\")
" 2>/dev/null)

  gh label create "quality-gate-fail" --color "d73a4a" --description "品質ゲート不合格" --force 2>/dev/null || true
  gh label create "org:${ORG_SLUG}" --color "7057ff" --description "組織: ${ORG_SLUG}" --force 2>/dev/null || true

  ISSUE_URL=$(gh issue create \
    --title "🔴 品質NG: $(basename $FILE_PATH) [${ORG_SLUG}]" \
    --body "## 品質チェック結果

**ファイル:** \`${FILE_PATH}\`
**判定:** ❌ Fail (${ERROR_COUNT}件)
**日時:** ${DATETIME}

## 不合格項目

${ERRORS_TEXT}

---
_Quality Gate Hook による自動生成_" \
    --label "quality-gate-fail" \
    --label "org:${ORG_SLUG}" 2>/dev/null)

  printf '\n❌ 品質ゲートNG (%d件) → %s\n' "$ERROR_COUNT" "${ISSUE_URL:-Issue作成済み}" >&2
else
  printf '\n✅ 品質ゲートPass: %s\n' "$FILE_PATH" >&2
fi

exit 0
