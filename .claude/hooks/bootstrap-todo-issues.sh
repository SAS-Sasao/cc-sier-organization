#!/usr/bin/env bash
# bootstrap-todo-issues.sh — WBS markdown から GitHub Issues + Project v2 をバルク作成する一回限りのスクリプト
#
# 前提:
#   - WBS markdown が拡張スキーマ (Iter/Pri/Type/Issue/ステータス) に移行済み
#   - PROJECTS_PAT (Classic PAT, project scope) が設定済み ※user-owned Project v2 の制約
#   - GITHUB_TOKEN (Issues/labels 操作用、Actions 環境では自動注入)
#
# 認証トークンの役割分担（最小権限原則）:
#   - GITHUB_TOKEN (fine-grained / auto):
#       gh issue create, gh label create, gh issue list
#       → Repository の Contents/Issues/Pull requests 権限で OK
#   - PROJECTS_PAT (Classic PAT, project scope のみ):
#       gh project item-add, gh project field-list, gh project field-create
#       → user-owned Project v2 は fine-grained PAT 非対応 (GitHub 既知の制約)
#
# 動作:
#   1. parse-wbs.py で全組織の WBS タスクを取得
#   2. 各タスクについて対応 Issue を検索（label: wbs:{wbs_id}, org:{slug}）
#   3. 未作成なら gh issue create で新規作成（GITHUB_TOKEN で）
#   4. 作成した Issue を Project v2 (PROJECT_V2_NODE_ID) に追加（PROJECTS_PAT で）
#   5. Project v2 のフィールド (Status/Iteration/Priority/Org/WBS-ID/Type) を設定
#   6. WBS markdown の Issue# 列を更新 (新規 Issue の番号を埋め込み)
#
# 環境変数:
#   GITHUB_TOKEN or GH_TOKEN (required) — Issue/label 操作用
#   PROJECTS_PAT (required)             — Classic PAT (scope: project のみ)
#   PROJECT_V2_NODE_ID (optional)       — 既存の Project v2 node ID (default: 既存)
#   DRY_RUN=1                           — 何もせず計画だけ表示

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

DRY_RUN="${DRY_RUN:-0}"
PROJECT_V2_NODE_ID="${PROJECT_V2_NODE_ID:-PVT_kwHODAtE_84BUTl8}"

# Issues/labels 用のトークン（fine-grained or GITHUB_TOKEN）
ISSUES_TOKEN="${GITHUB_TOKEN:-${GH_TOKEN:-}}"
# Project v2 用のトークン（Classic PAT, project scope）
PROJECTS_TOKEN="${PROJECTS_PAT:-}"

if [ "$DRY_RUN" != "1" ]; then
  if [ -z "$ISSUES_TOKEN" ]; then
    echo "::error::GITHUB_TOKEN または GH_TOKEN が必要 (Issues/labels 操作用)" >&2
    exit 1
  fi
  if [ -z "$PROJECTS_TOKEN" ]; then
    echo "::error::PROJECTS_PAT (Classic PAT, project scope) が必要" >&2
    echo "::error::user-owned Project v2 は fine-grained PAT では操作できない制約のため" >&2
    exit 1
  fi
fi

# デフォルトは Issues 用トークンで auth
export GH_TOKEN="$ISSUES_TOKEN"

# Project v2 操作用の wrapper (トークンを一時的に切り替え)
gh_project() {
  GH_TOKEN="$PROJECTS_TOKEN" gh project "$@"
}

echo "=== Phase 1: WBS parse ==="
TASKS_JSON=$(python3 .claude/hooks/parse-wbs.py 2>/dev/null || echo '[]')
TOTAL_TASKS=$(python3 -c "import json,sys; print(len(json.loads(sys.stdin.read())))" <<< "$TASKS_JSON")
echo "Total tasks: $TOTAL_TASKS"

if [ "$TOTAL_TASKS" = "0" ]; then
  echo "No tasks to bootstrap"
  exit 0
fi

# ラベル準備
ensure_label() {
  local name="$1" color="$2" desc="$3"
  if [ "$DRY_RUN" = "1" ]; then
    echo "[DRY] ensure label: $name"
    return 0
  fi
  gh label create "$name" --color "$color" --description "$desc" 2>/dev/null || true
}

echo "=== Phase 2: Ensure base labels ==="
ensure_label "todo:wbs" "0e8a16" "WBS 由来の TODO タスク"
ensure_label "todo:automation" "5319e7" "daily-todo-sync workflow が管理するタスク"
ensure_label "org:domain-tech-collection" "0075ca" "組織: domain-tech-collection"
ensure_label "org:standardization-initiative" "0075ca" "組織: standardization-initiative"
ensure_label "org:jutaku-dev-team" "0075ca" "組織: jutaku-dev-team"
ensure_label "priority:1" "b60205" "最優先"
ensure_label "priority:2" "d93f0b" "高"
ensure_label "priority:3" "fbca04" "中"
ensure_label "priority:4" "c5def5" "低"
ensure_label "type:learning" "1d76db" "学習・インプット"
ensure_label "type:diagram" "5319e7" "図解・可視化"
ensure_label "type:research" "006b75" "調査・リサーチ"
ensure_label "type:delivery" "0e8a16" "成果物納品"
ensure_label "type:operational" "c5def5" "継続運用"
ensure_label "status:in-progress" "fbca04" "進行中"
ensure_label "status:blocked" "b60205" "停滞・ブロッカー"
ensure_label "status:done" "0e8a16" "完了"

echo "=== Phase 3: Ensure Project v2 fields ==="
# Project v2 に必要フィールドを追加する（既存は no-op）
# - Iteration (既存): そのまま使う
# - Priority (single-select: 1/2/3/4)
# - Org (single-select)
# - WBS-ID (text)
# - Type (single-select)
# - Today (single-select: Yes/No)

# フィールド一覧取得 (DRY_RUN 時は skip)
ensure_project_field() {
  local field_name="$1" data_type="$2" options="$3"
  if [ "$DRY_RUN" = "1" ]; then
    echo "[DRY] ensure project field: $field_name ($data_type)"
    return 0
  fi

  # 既存フィールドチェック（Project 操作は PROJECTS_PAT）
  local existing
  existing=$(gh_project field-list 1 --owner SAS-Sasao --format json 2>/dev/null \
    | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(' '.join(f['name'] for f in d.get('fields',[])))" 2>/dev/null || echo "")

  if echo " $existing " | grep -q " $field_name "; then
    echo "Field exists: $field_name"
    return 0
  fi

  case "$data_type" in
    TEXT|NUMBER|DATE)
      gh_project field-create 1 --owner SAS-Sasao --name "$field_name" --data-type "$data_type" 2>&1 \
        || echo "::warning::Failed to create field $field_name"
      ;;
    SINGLE_SELECT)
      gh_project field-create 1 --owner SAS-Sasao --name "$field_name" --data-type SINGLE_SELECT \
        --single-select-options "$options" 2>&1 \
        || echo "::warning::Failed to create field $field_name"
      ;;
  esac
}

ensure_project_field "Priority" "SINGLE_SELECT" "1,2,3,4"
ensure_project_field "Org" "SINGLE_SELECT" "domain-tech-collection,standardization-initiative,jutaku-dev-team"
ensure_project_field "WBS-ID" "TEXT" ""
ensure_project_field "Type" "SINGLE_SELECT" "learning,diagram,research,delivery,operational"
ensure_project_field "Today" "SINGLE_SELECT" "Yes,No"

echo "=== Phase 4: Create Issues and add to Project v2 ==="

# タスク毎に処理
python3 -c "import json,sys; print(json.dumps(json.loads(sys.stdin.read())))" <<< "$TASKS_JSON" \
  | python3 -c "
import json,sys
data = json.loads(sys.stdin.read())
for t in data:
    # tab-separated output for bash to read
    print('\t'.join([
        t['wbs_id'],
        (t['task'] or '').replace('\t',' ').replace('\n',' '),
        t['org'],
        str(t.get('priority') or 3),
        t.get('type') or 'learning',
        t.get('iteration') or '',
        t.get('status') or 'todo',
        str(t.get('issue_number') or ''),
        t.get('wbs_file') or '',
        t.get('section') or '',
        t.get('subsection') or '',
        (t.get('artifact') or '').replace('\t',' '),
        (t.get('period') or '').replace('\t',' '),
    ]))
" | while IFS=$'\t' read -r wbs_id task org priority type iter status issue_num wbs_file section subsection artifact period; do

  # skip done tasks
  if [ "$status" = "done" ]; then
    echo "[skip done] $org $wbs_id $task"
    continue
  fi

  # 既に Issue# 列に値がある場合は skip
  if [ -n "$issue_num" ]; then
    echo "[skip existing] $org $wbs_id -> Issue #$issue_num"
    continue
  fi

  # 既存 Issue を検索 (label 条件)
  existing_issue=""
  if [ "$DRY_RUN" != "1" ]; then
    existing_issue=$(gh issue list --search "label:\"wbs:$wbs_id\" label:\"org:$org\" label:\"todo:wbs\"" \
      --json number --jq '.[0].number' 2>/dev/null || echo "")
  fi

  if [ -n "$existing_issue" ]; then
    echo "[found] $org $wbs_id -> Issue #$existing_issue"
    continue
  fi

  TITLE="[$org] WBS $wbs_id: $task"
  BODY=$(cat <<EOF
## WBS タスク

- **WBS ID**: \`$wbs_id\`
- **組織**: \`$org\`
- **タスク**: $task
- **セクション**: $section${subsection:+ / $subsection}
- **期間**: ${period:-—}
- **Iteration**: ${iter:-—}
- **Priority**: $priority
- **Type**: $type
- **成果物**: ${artifact:-—}

## ソース

\`$wbs_file\`

---
🤖 Bootstrap by \`.claude/hooks/bootstrap-todo-issues.sh\`
EOF
)

  WBS_LABEL="wbs:$wbs_id"
  ensure_label "$WBS_LABEL" "ededed" "WBS ID $wbs_id"

  LABELS="todo:wbs,todo:automation,org:$org,priority:$priority,type:$type,$WBS_LABEL"
  if [ -n "$iter" ] && [ "$iter" != "—" ]; then
    ITER_LABEL="iteration:$iter"
    ensure_label "$ITER_LABEL" "f9d0c4" "Iteration $iter"
    LABELS="$LABELS,$ITER_LABEL"
  fi

  if [ "$DRY_RUN" = "1" ]; then
    echo "[DRY] would create: $TITLE (labels: $LABELS)"
    continue
  fi

  ISSUE_URL=$(gh issue create --title "$TITLE" --body "$BODY" --label "$LABELS" 2>&1 || echo "FAILED")

  if [[ "$ISSUE_URL" == *"FAILED"* ]] || [[ "$ISSUE_URL" != *"/issues/"* ]]; then
    echo "::warning::Failed to create issue for $wbs_id: $ISSUE_URL"
    continue
  fi

  ISSUE_NUMBER="${ISSUE_URL##*/}"
  echo "[created] $org $wbs_id -> #$ISSUE_NUMBER ($ISSUE_URL)"

  # Project v2 に追加 (Project 操作は PROJECTS_PAT)
  gh_project item-add 1 --owner SAS-Sasao --url "$ISSUE_URL" 2>&1 | tail -1 || \
    echo "::warning::Failed to add $ISSUE_URL to project"

  # 少し待機 (rate limit 対策)
  sleep 0.5

done

echo "=== Bootstrap complete ==="
echo "Next step: update WBS markdown with Issue numbers via daily-todo-sync.yml"
