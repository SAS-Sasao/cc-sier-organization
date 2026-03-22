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

    # started が today かチェック
    local started
    started=$(grep '^started:' "$task_file" 2>/dev/null | head -1 \
      | sed 's/started: *"//' | cut -c1-10)
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
    local artifacts_exist=true
    local artifact_paths
    artifact_paths=$(grep -oE '`\.companies/[^`]+`' "$task_file" 2>/dev/null \
      | tr -d '`')
    while IFS= read -r path; do
      [[ -z "$path" ]] && continue
      [[ ! -f "$path" ]] && { artifacts_exist=false; break; }
    done <<< "$artifact_paths"
    if $artifacts_exist && [[ -n "$artifact_paths" ]]; then
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
    local normalized
    normalized=$(python3 -c "print(round($score/100, 2))" 2>/dev/null || echo "0.$score")

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
