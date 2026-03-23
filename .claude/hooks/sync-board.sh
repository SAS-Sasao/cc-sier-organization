#!/usr/bin/env bash
# sync-board.sh — タスクボードをタスクログとWBSから自動同期する
# Usage: bash .claude/hooks/sync-board.sh [org-slug]

set -euo pipefail

# ---------------------------------------------------------------------------
# 1. 引数処理 & パス設定
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

if [[ -n "${1:-}" ]]; then
  ORG_SLUG="$1"
else
  ACTIVE_FILE="$REPO_ROOT/.companies/.active"
  if [[ ! -f "$ACTIVE_FILE" ]]; then
    echo "ERROR: 引数なし & .companies/.active が見つかりません" >&2
    exit 1
  fi
  ORG_SLUG="$(tr -d '[:space:]' < "$ACTIVE_FILE")"
fi

ORG_DIR="$REPO_ROOT/.companies/$ORG_SLUG"
TASK_LOG_DIR="$ORG_DIR/.task-log"
SEC_DIR="$ORG_DIR/docs/secretary"
BOARD_FILE="$SEC_DIR/board.md"
TODAY="$(date '+%Y-%m-%d')"
NOW="$(date '+%Y-%m-%d %H:%M')"

if [[ ! -d "$ORG_DIR" ]]; then
  echo "ERROR: 組織ディレクトリが見つかりません: $ORG_DIR" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# 2. データ構造 (連想配列)
# キー = タスクID
# 値   = "<status>|<content>|<assignee>|<date>|<artifact>|<deadline>"
# ---------------------------------------------------------------------------
declare -A TASKS          # タスクログ由来（優先）
declare -A WBS_TASKS      # WBS由来
declare -A TASKLOG_WBS_IDS  # タスクログのrequestから検出したWBS ID → status

# ---------------------------------------------------------------------------
# ヘルパー: 文字列トリム
# ---------------------------------------------------------------------------
trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  echo "$s"
}

# ---------------------------------------------------------------------------
# ヘルパー: バッククォートを除去し basename を返す
# ---------------------------------------------------------------------------
artifact_basename() {
  local s="$1"
  # バッククォートを除去
  s="${s//\`/}"
  # 前後トリム
  s="$(trim "$s")"
  # パスが含まれる場合はbasename
  if [[ "$s" == *"/"* ]]; then
    s="$(basename "$s")"
  fi
  echo "$s"
}

# ---------------------------------------------------------------------------
# ヘルパー: 文字列を60文字で截断
# ---------------------------------------------------------------------------
truncate_str() {
  local s="$1"
  local max="${2:-40}"
  if [[ ${#s} -gt $max ]]; then
    echo "${s:0:$max}..."
  else
    echo "$s"
  fi
}

# ---------------------------------------------------------------------------
# 3. タスクログのパース
# ---------------------------------------------------------------------------
parse_task_logs() {
  local log_file
  [[ ! -d "$TASK_LOG_DIR" ]] && return 0

  for log_file in "$TASK_LOG_DIR"/*.md; do
    [[ -f "$log_file" ]] || continue

    local task_id="" status="" content="" mode="" started="" completed="" artifact=""

    # ファイル全体を読んで frontmatter と本文に分ける
    # frontmatter はファイルの先頭行が "---" の場合のみ有効
    local in_fm=0 fm_done=0 fm_line_count=0
    local in_artifacts=0 in_request_section=0
    local first_line=1

    while IFS= read -r line; do
      # --- frontmatter 境界 ---
      if [[ "$line" == "---" ]]; then
        if [[ $fm_done -eq 0 && $in_fm -eq 0 && $first_line -eq 1 ]]; then
          # ファイル先頭の --- のみ frontmatter 開始とみなす
          in_fm=1; first_line=0; continue
        elif [[ $in_fm -eq 1 ]]; then
          in_fm=0; fm_done=1; continue
        fi
        # それ以外の --- は本文内のセクション区切りとして無視
        first_line=0; continue
      fi
      first_line=0

      # === YAML frontmatter パース ===
      if [[ $in_fm -eq 1 ]]; then
        if [[ "$line" =~ ^task_id:[[:space:]]*\"?([^\"[:space:]]+)\"? ]]; then
          task_id="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^status:[[:space:]]*\"?([^\"[:space:]]+)\"? ]]; then
          status="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^request:[[:space:]]*\"(.+)\"$ ]]; then
          content="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^request:[[:space:]]*(.+)$ && -z "$content" ]]; then
          content="${BASH_REMATCH[1]}"
          content="${content%\"}"
          content="${content#\"}"
        elif [[ "$line" =~ ^mode:[[:space:]]*\"?([^\"[:space:]]+)\"? ]]; then
          mode="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^started:[[:space:]]*\"?([0-9]{4}-[0-9]{2}-[0-9]{2}) ]]; then
          started="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^completed:[[:space:]]*\"?([0-9]{4}-[0-9]{2}-[0-9]{2}) ]]; then
          completed="${BASH_REMATCH[1]}"
        fi
        continue
      fi

      # === 箇条書き形式フォールバック (frontmatter なし or 補完) ===
      # task-id / task_id
      if [[ -z "$task_id" ]]; then
        if [[ "$line" =~ \*\*task[-_]id\*\*:[[:space:]]*(.+) ]]; then
          task_id="$(trim "${BASH_REMATCH[1]}")"
        fi
      fi
      # ステータス
      if [[ -z "$status" || "$status" == "unknown" ]]; then
        if [[ "$line" =~ \*\*ステータス\*\*:[[:space:]]*(.+) ]]; then
          local raw_s="${BASH_REMATCH[1]}"
          if [[ "$raw_s" =~ 完了|completed ]]; then
            status="completed"
          elif [[ "$raw_s" =~ 進行中|in-progress ]]; then
            status="in-progress"
          fi
        elif [[ "$line" =~ \*\*status\*\*:[[:space:]]*(.+) ]]; then
          status="$(trim "${BASH_REMATCH[1]}")"
        fi
      fi
      # mode
      if [[ -z "$mode" ]]; then
        if [[ "$line" =~ \*\*実行モード\*\*:[[:space:]]*(.+) ]]; then
          local raw_mode="${BASH_REMATCH[1]}"
          if [[ "$raw_mode" =~ direct|Direct ]]; then
            mode="direct"
          elif [[ "$raw_mode" =~ [Ss]ubagent ]]; then
            mode="subagent"
          fi
        fi
      fi
      # 日付
      if [[ -z "$started" ]]; then
        if [[ "$line" =~ \*\*開始時刻\*\*:[[:space:]]*([0-9]{4}-[0-9]{2}-[0-9]{2}) ]]; then
          started="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ \*\*実行日時\*\*:[[:space:]]*([0-9]{4}-[0-9]{2}-[0-9]{2}) ]]; then
          started="${BASH_REMATCH[1]}"
        fi
      fi
      if [[ -z "$completed" ]]; then
        if [[ "$line" =~ \*\*完了時刻\*\*:[[:space:]]*([0-9]{4}-[0-9]{2}-[0-9]{2}) ]]; then
          completed="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ \*\*completed_at\*\*:[[:space:]]*([0-9]{4}-[0-9]{2}-[0-9]{2}) ]]; then
          completed="${BASH_REMATCH[1]}"
        fi
      fi

      # === 依頼内容セクションから content を取得 (request がない場合のフォールバック) ===
      if [[ "$line" =~ ^##[[:space:]]*(依頼内容|概要) ]]; then
        in_request_section=1
        continue
      fi
      if [[ ${in_request_section:-0} -eq 1 ]]; then
        if [[ "$line" =~ ^## ]]; then
          in_request_section=0
        elif [[ -z "$content" && -n "$(trim "$line")" && ! "$line" =~ ^# ]]; then
          content="$(trim "$line")"
          in_request_section=0
        fi
      fi

      # === 成果物テーブル行から artifact を抽出 ===
      # "| 成果物名 | 作者 | `path/to/file.md` |" 形式 (バッククォートあり)
      if [[ -z "$artifact" && "$line" =~ \`[^\`]+\`[[:space:]]*\| ]]; then
        local raw_art
        raw_art="$(echo "$line" | grep -oP '`[^`]+`' | head -1 || true)"
        if [[ -n "$raw_art" ]]; then
          artifact="$(artifact_basename "$raw_art")"
        fi
      fi
      # "| ファイル名 | 説明 |" 形式 (バッククォートなし、docs/ を含むパス)
      if [[ -z "$artifact" && "$line" =~ \|[[:space:]]*(docs/[^[:space:]|]+)[[:space:]]*\| ]]; then
        artifact="$(artifact_basename "${BASH_REMATCH[1]}")"
      fi

    done < "$log_file"

    [[ -z "$task_id" ]] && continue

    # content が空の場合はタスクIDをそのまま使う（ファイル名 slug から推測）
    if [[ -z "$content" ]]; then
      content="$task_id"
    fi
    content="$(truncate_str "$content")"

    # ステータスが空の場合はフォールバック: completed フィールドがあれば done
    if [[ -z "$status" ]]; then
      if [[ -n "$completed" ]]; then
        status="completed"
      else
        status="in-progress"
      fi
    fi

    # モードから担当表示
    local assignee
    case "${mode:-}" in
      subagent|[Ss]ubagent) assignee="サブエージェント" ;;
      direct|[Dd]irect)     assignee="秘書" ;;
      "")                   assignee="秘書" ;;
      *)                    assignee="${mode}" ;;
    esac

    # ステータス正規化
    local norm_status
    case "$status" in
      completed|完了) norm_status="done" ;;
      in-progress|進行中) norm_status="in-progress" ;;
      *) norm_status="in-progress" ;;
    esac

    local date_val
    if [[ "$norm_status" == "done" ]]; then
      date_val="${completed:-${started:-$TODAY}}"
    else
      date_val="${started:-$TODAY}"
    fi

    TASKS["$task_id"]="${norm_status}|${content}|${assignee}|${date_val}|${artifact:-—}|—"

    # requestからWBS IDパターンを検出して記録（WBS側のステータス上書き用）
    # また、WBS IDが見つかった場合はTASKS側のエントリを削除（WBS側で統合表示する）
    local full_content="${content}"
    local wbs_pattern
    if [[ "$full_content" =~ ([0-9]+\.[0-9]+\.R?[0-9]+) ]]; then
      wbs_pattern="${BASH_REMATCH[1]}"
      TASKLOG_WBS_IDS["$wbs_pattern"]="$norm_status"
      # WBS IDが検出されたタスクログエントリは除外（WBS側に統合）
      unset "TASKS[$task_id]"
      continue
    fi
  done
}

# ---------------------------------------------------------------------------
# 4. WBS ファイルのパース
# ---------------------------------------------------------------------------
parse_wbs() {
  local wbs_file
  [[ ! -d "$SEC_DIR" ]] && return 0

  local found_any=0
  for wbs_file in "$SEC_DIR"/*[wW][bB][sS]*.md "$SEC_DIR"/*[wW][bB][sS]*.MD; do
    [[ -f "$wbs_file" ]] || continue
    found_any=1

    while IFS= read -r line; do
      # セパレータ行はスキップ
      [[ "$line" =~ ^\|[[:space:]]*-+ ]] && continue
      # テーブル行のみ
      [[ "$line" =~ ^\| ]] || continue

      # パイプ区切りでフィールドに分割
      local raw_fields="${line#|}"
      raw_fields="${raw_fields%|}"

      local -a trimmed=()
      local f
      local IFS_SAVE="$IFS"
      IFS='|'
      read -ra fields_raw <<< "$raw_fields"
      IFS="$IFS_SAVE"

      for f in "${fields_raw[@]}"; do
        trimmed+=("$(trim "$f")")
      done

      [[ ${#trimmed[@]} -lt 3 ]] && continue

      # WBS ID の判定 (数字と . と R で構成されるパターン)
      local wbs_id="${trimmed[0]}"
      if ! [[ "$wbs_id" =~ ^[0-9]+(\.[0-9Rr]+)+$ || "$wbs_id" =~ ^[0-9]+\.[Rr][0-9]+$ ]]; then
        continue
      fi
      # ヘッダ行 ("WBS", "No" など) をスキップ
      [[ "$wbs_id" =~ ^[A-Za-z] ]] && continue

      # ステータスは最後のフィールド
      local last_idx=$(( ${#trimmed[@]} - 1 ))
      local status_cell="${trimmed[$last_idx]}"

      local norm_status
      if [[ "$status_cell" == "[x]" ]]; then
        norm_status="done"
      elif [[ "$status_cell" == "[~]" ]]; then
        norm_status="in-progress"
      elif [[ "$status_cell" == "[ ]" ]]; then
        norm_status="todo"
      else
        # ステータスカラムが想定外 → スキップ
        continue
      fi

      # タスク名 (2番目フィールド)
      local task_name
      task_name="$(truncate_str "${trimmed[1]:-$wbs_id}" 60)"

      # 担当 (3番目フィールド)
      local assignee="${trimmed[2]:-—}"

      # カラム数によってフィールド位置が変わる
      # パターン A: WBS|タスク|担当|期間|成果物|ステータス              (6列)
      # パターン B: WBS|タスク|担当|期間|時間|リソース|成果物|ステータス  (8列)
      # パターン C: WBS|タスク|担当|期間|時間|リソース|成果物パス|ステータス (8列・5.x系)
      # パターン D: WBS|資格|目標時期|優先度|ステータス                  (5列・6.x系)
      local num_cols=${#trimmed[@]}
      local period="" artifact_raw=""

      if [[ $num_cols -ge 4 ]]; then
        period="${trimmed[3]:-}"
      fi

      # パターン D (5列: WBS|タスク|目標時期|優先度|ステータス) の判定
      # ステータスの1つ手前が優先度（高/中/低/最優先など）の場合は成果物なし
      local art_base="—"
      if [[ $num_cols -eq 5 ]]; then
        local pre_status="${trimmed[3]:-}"
        if [[ "$pre_status" =~ ^(高|中|低|最優先|[Hh]igh|[Mm]edium|[Ll]ow)$ ]]; then
          # 資格/目標時期型 → 成果物なし、担当は3番目フィールド(目標時期)を期限扱い
          period="${trimmed[2]:-}"
          assignee="自学"
          art_base="—"
        else
          artifact_raw="${trimmed[3]:-—}"
        fi
      elif [[ $num_cols -ge 6 ]]; then
        # 成果物: ステータスの1つ手前 (num_cols - 2) のカラム
        local artifact_idx=$(( num_cols - 2 ))
        artifact_raw="${trimmed[$artifact_idx]:-—}"
      fi

      # artifact の basename 変換 (artifact_raw が設定されている場合のみ)
      if [[ -n "${artifact_raw:-}" && "$artifact_raw" != "—" ]]; then
        if [[ "$artifact_raw" =~ \`([^\`]+)\` ]]; then
          art_base="$(artifact_basename "${BASH_REMATCH[1]}")"
        else
          art_base="$(artifact_basename "$artifact_raw")"
        fi
        [[ -z "$art_base" ]] && art_base="—"
      fi

      # 既にタスクログにある場合はスキップ（タスクログ優先）
      if [[ -n "${TASKS[$wbs_id]+x}" ]]; then
        continue
      fi

      # タスクログのrequestにこのWBS IDが含まれていた場合、そのステータスで上書き
      if [[ -n "${TASKLOG_WBS_IDS[$wbs_id]+x}" ]]; then
        norm_status="${TASKLOG_WBS_IDS[$wbs_id]}"
      fi

      WBS_TASKS["$wbs_id"]="${norm_status}|${task_name}|${assignee}|${period}|${art_base}|${period}"
    done < "$wbs_file"
  done

  if [[ $found_any -eq 0 ]]; then
    echo "INFO: WBSファイルが見つかりません（WBS連動スキップ）" >&2
  fi
}

# ---------------------------------------------------------------------------
# 5. 全タスクをステータス別に仕分け
# ---------------------------------------------------------------------------
collect_by_status() {
  local -n _todo=$1
  local -n _inprogress=$2
  local -n _done=$3

  local task_id val status content assignee date artifact deadline

  for task_id in "${!TASKS[@]}"; do
    val="${TASKS[$task_id]}"
    IFS='|' read -r status content assignee date artifact deadline <<< "$val"
    case "$status" in
      todo)        _todo+=("${task_id}|${content}|${assignee}|${deadline}|${artifact}") ;;
      in-progress) _inprogress+=("${task_id}|${content}|${assignee}|${date}|${artifact}") ;;
      done)        _done+=("${task_id}|${content}|${assignee}|${date}|${artifact}") ;;
    esac
  done

  for task_id in "${!WBS_TASKS[@]}"; do
    val="${WBS_TASKS[$task_id]}"
    IFS='|' read -r status content assignee date artifact deadline <<< "$val"
    case "$status" in
      todo)        _todo+=("${task_id}|${content}|${assignee}|${deadline}|${artifact}") ;;
      in-progress) _inprogress+=("${task_id}|${content}|${assignee}|${date}|${artifact}") ;;
      done)        _done+=("${task_id}|${content}|${assignee}|${date}|${artifact}") ;;
    esac
  done

  # タスクID 自然順ソート
  local IFS_SAVE="$IFS"
  IFS=$'\n'
  if [[ ${#_todo[@]} -gt 0 ]]; then
    _todo=($(printf '%s\n' "${_todo[@]}" | sort -t'|' -k1,1 -V 2>/dev/null || printf '%s\n' "${_todo[@]}" | sort -t'|' -k1,1))
  fi
  if [[ ${#_inprogress[@]} -gt 0 ]]; then
    _inprogress=($(printf '%s\n' "${_inprogress[@]}" | sort -t'|' -k1,1 -V 2>/dev/null || printf '%s\n' "${_inprogress[@]}" | sort -t'|' -k1,1))
  fi
  if [[ ${#_done[@]} -gt 0 ]]; then
    _done=($(printf '%s\n' "${_done[@]}" | sort -t'|' -k1,1 -V 2>/dev/null || printf '%s\n' "${_done[@]}" | sort -t'|' -k1,1))
  fi
  IFS="$IFS_SAVE"
}

# ---------------------------------------------------------------------------
# 6. テーブル行生成ヘルパー
# ---------------------------------------------------------------------------
make_rows_todo() {
  local -n _arr=$1
  if [[ ${#_arr[@]} -eq 0 ]]; then
    echo "| — | — | — | — | — |"
    return
  fi
  local entry task_id content assignee deadline artifact
  for entry in "${_arr[@]}"; do
    IFS='|' read -r task_id content assignee deadline artifact <<< "$entry"
    [[ -z "$deadline" || "$deadline" == "—" ]] && deadline="—"
    [[ -z "$artifact" || "$artifact" == "—" ]] && artifact="—"
    echo "| ${task_id} | ${content} | ${assignee} | ${deadline} | ${artifact} |"
  done
}

make_rows_inprogress() {
  local -n _arr=$1
  if [[ ${#_arr[@]} -eq 0 ]]; then
    echo "| — | — | — | — | — |"
    return
  fi
  local entry task_id content assignee date artifact
  for entry in "${_arr[@]}"; do
    IFS='|' read -r task_id content assignee date artifact <<< "$entry"
    [[ -z "$date" || "$date" == "—" ]] && date="—"
    [[ -z "$artifact" || "$artifact" == "—" ]] && artifact="—"
    echo "| ${task_id} | ${content} | ${assignee} | ${date} | ${artifact} |"
  done
}

make_rows_done() {
  local -n _arr=$1
  if [[ ${#_arr[@]} -eq 0 ]]; then
    echo "| — | — | — | — | — |"
    return
  fi
  local entry task_id content assignee date artifact
  for entry in "${_arr[@]}"; do
    IFS='|' read -r task_id content assignee date artifact <<< "$entry"
    [[ -z "$date" || "$date" == "—" ]] && date="—"
    [[ -z "$artifact" || "$artifact" == "—" ]] && artifact="—"
    echo "| ${task_id} | ${content} | ${assignee} | ${date} | ${artifact} |"
  done
}

# ---------------------------------------------------------------------------
# 7. board.md を全体上書き生成
# ---------------------------------------------------------------------------
write_board() {
  local -n _todo=$1
  local -n _inprogress=$2
  local -n _done=$3

  mkdir -p "$SEC_DIR"

  local todo_rows inprogress_rows done_rows
  todo_rows="$(make_rows_todo _todo)"
  inprogress_rows="$(make_rows_inprogress _inprogress)"
  done_rows="$(make_rows_done _done)"

  cat > "$BOARD_FILE" <<BOARD
---
updated_at: "${TODAY}"
org: ${ORG_SLUG}
---

# タスクボード

> 自動更新: sync-board.sh による同期（最終実行: ${NOW}）

---

## 🔵 Todo（未着手）

| タスクID | 内容 | 担当 | 期限 | 成果物 |
|---------|------|------|------|--------|
${todo_rows}

---

## 🟡 In Progress（進行中）

| タスクID | 内容 | 担当 | 開始日 | 成果物 |
|---------|------|------|--------|--------|
${inprogress_rows}

---

## 🔴 Review（品質ゲートNG・要修正）

| タスクID | 内容 | 担当 | NG日時 | 問題ファイル | Issue |
|---------|------|------|--------|------------|-------|
| — | — | — | — | — | — |

---

## ✅ Done（完了）

| タスクID | 内容 | 担当 | 完了日 | 成果物 |
|---------|------|------|--------|--------|
${done_rows}
BOARD
}

# ---------------------------------------------------------------------------
# 8. メイン処理
# ---------------------------------------------------------------------------
declare -a TODO_LIST=()
declare -a INPROGRESS_LIST=()
declare -a DONE_LIST=()

parse_task_logs
parse_wbs
collect_by_status TODO_LIST INPROGRESS_LIST DONE_LIST
write_board TODO_LIST INPROGRESS_LIST DONE_LIST

echo "board.md を同期しました（Todo: ${#TODO_LIST[@]} / In Progress: ${#INPROGRESS_LIST[@]} / Done: ${#DONE_LIST[@]}）"
