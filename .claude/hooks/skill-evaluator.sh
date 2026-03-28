#!/usr/bin/env bash
# タスクの成否を軽量シグナルで評価し task-log に reward を追記する
# session-boundary.sh または /company-evolve から source して使う

evaluate_session() {
  local org_slug="$1"
  local today="$2"
  local task_log_dir=".companies/${org_slug}/.task-log"

  [[ ! -d "$task_log_dir" ]] && return 0

  for task_file in "${task_log_dir}"/*.md; do
    [[ -f "$task_file" ]] || continue

    # started が today かチェック（クォートあり/なし両対応）
    local started
    started=$(grep '^started:' "$task_file" 2>/dev/null | head -1 \
      | sed 's/^started: *//; s/^"//; s/"$//' | cut -c1-10)
    [[ "$started" != "$today" ]] && continue

    # すでに reward があればスキップ（べき等）
    grep -q '^## reward' "$task_file" 2>/dev/null && continue

    local status
    status=$(grep '^status:' "$task_file" 2>/dev/null | head -1 | awk '{print $2}')

    local score=0
    local signals=()

    # シグナル1: completed（60点）
    if [[ "$status" == "completed" ]]; then
      signals+=("completed: true"); score=60
    else
      signals+=("completed: false")
    fi

    # シグナル2: 成果物が実在する（+20点）
    # 3形式で検出: バッククォート / テーブル / チェックボックス
    local artifacts_exist=false
    local artifact_paths=""

    # 形式1: `path` (バッククォート囲み — .companies/ または docs/ 始まり)
    local bt_paths
    bt_paths=$(grep -oE '`(\.companies/|docs/)[^`]+`' "$task_file" 2>/dev/null | tr -d '`')
    [[ -n "$bt_paths" ]] && artifact_paths+="$bt_paths"$'\n'

    # 形式2: テーブル行のパス (.companies/ を含む列)
    local tbl_paths
    tbl_paths=$(grep '|.*\.companies/' "$task_file" 2>/dev/null \
      | grep -oE '\.companies/[^ |]+' | sed 's/[[:space:]]*$//')
    [[ -n "$tbl_paths" ]] && artifact_paths+="$tbl_paths"$'\n'

    # 形式3: チェックボックス (- [x] path / - [ ] path)
    local cb_paths
    cb_paths=$(grep -E '^\- \[.\] ' "$task_file" 2>/dev/null \
      | sed 's/^- \[.\] //' | sed 's/（.*$//' | sed 's/[[:space:]]*$//')
    [[ -n "$cb_paths" ]] && artifact_paths+="$cb_paths"$'\n'

    # 検出したパスの実在チェック
    local found_any=false
    while IFS= read -r path; do
      [[ -z "$path" ]] && continue
      # docs/ 始まりの場合はリポジトリルートからの相対パス
      if [[ -f "$path" ]]; then
        found_any=true
      fi
    done <<< "$artifact_paths"

    if $found_any; then
      artifacts_exist=true
      signals+=("artifacts_exist: true"); score=$(( score + 20 ))
    else
      signals+=("artifacts_exist: false")
    fi

    # シグナル3: 過剰編集なし（+20点）
    local log=".companies/${org_slug}/.interaction-log/${today}.md"
    local excessive_edits=false
    if [[ -f "$log" ]]; then
      local max_edits
      max_edits=$(grep -oE 'path: `[^`]+`' "$log" 2>/dev/null \
        | sort | uniq -c | sort -rn | head -1 | awk '{print $1}')
      [[ "${max_edits:-0}" -gt 5 ]] && excessive_edits=true
    fi
    if ! $excessive_edits; then
      signals+=("excessive_edits: false"); score=$(( score + 20 ))
    else
      signals+=("excessive_edits: true")
    fi

    # シグナル4: やり直し発生なし（加点なし・マイナス-10点）
    local retry_detected=false
    if [[ -f "$log" ]]; then
      grep -qE '(やり直し|違う|もう一度)' "$log" 2>/dev/null && retry_detected=true
    fi
    if $retry_detected; then
      signals+=("retry_detected: true"); score=$(( score - 10 ))
    else
      signals+=("retry_detected: false")
    fi

    [[ $score -lt 0 ]] && score=0
    local process_score=$score

    # judge.total が存在する場合、プロセス評価と成果物評価を統合
    # 統合スコア = process(40%) + judge(60%) でより精密なスコアを算出
    local judge_total=""
    judge_total=$(grep -A10 '^## judge' "$task_file" 2>/dev/null \
      | grep -E '^total:' | head -1 | awk '{print $2}')

    local normalized
    if [[ -n "$judge_total" && "$judge_total" != "0" ]]; then
      normalized=$(python3 -c "
process = $process_score / 100
judge = float('$judge_total')
combined = process * 0.4 + judge * 0.6
print(round(combined, 3))
" 2>/dev/null || echo "0.$score")
    else
      normalized=$(python3 -c "print(round($process_score/100, 2))" 2>/dev/null || echo "0.$score")
    fi

    local signals_yaml=""
    for sig in "${signals[@]}"; do
      signals_yaml+="    ${sig}"$'\n'
    done

    cat >> "$task_file" <<REWARD_EOF

## reward
\`\`\`yaml
score: ${normalized}
signals:
${signals_yaml}evaluated_at: "$(date '+%Y-%m-%dT%H:%M:%S')"
\`\`\`
REWARD_EOF

  done
}
