#!/usr/bin/env python3
"""daily-kanban-sync.py — Project 2 (TODOKANBAN) に今日の WBS タスクを同期

Usage:
    python3 .claude/hooks/daily-kanban-sync.py [--mode sync|cleanup|dry-run] [--top-n N] [--time-budget H]

Environment variables:
    PROJECTS_PAT (required)  — Classic PAT with project, read:org, read:discussion scopes
    GITHUB_REPOSITORY        — owner/repo (default: SAS-Sasao/cc-sier-organization)

Modes:
    sync (default) — 昨日の WBS items を削除 + 今日の top N WBS tasks を追加
    cleanup        — Project 2 から非 WBS items (todo:wbs ラベルなし) を全削除
    dry-run        — 実際の変更なし、計画のみ stdout 出力

Logic:
    1. parse-wbs.py で全組織の WBS tasks 取得
    2. 現在の iteration (W1 start = 2026-03-24) 計算
    3. フィルタ: status∈{todo,in-progress}, issue_number あり, iteration が今週を含む
    4. ソート: priority ASC, type priority, wbs_id
    5. 上限: top_n 件 + 時間予算 (type から概算)
    6. GraphQL 経由で Project 2 操作:
       - WBS item (todo:wbs ラベル) かつ Target date != today → 削除
       - 選定した tasks → item-add + Target date=today 設定
       - 非 WBS items は sync モードでは触らない (cleanup モードのみ削除)
"""

import argparse
import json
import os
import re
import subprocess
import sys
from datetime import date, timedelta
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
W1_START = date(2026, 3, 24)
OWNER = "SAS-Sasao"
PROJECT_NUMBER = 2

TYPE_PRIORITY = {
    "delivery": 0,
    "learning": 1,
    "diagram": 2,
    "operational": 3,
    "research": 4,
}

# type ごとの時間見積もり (hours)
TYPE_HOURS = {
    "delivery": 4,
    "learning": 3,
    "diagram": 2,
    "research": 2,
    "operational": 1,
}


# ----------------------------------------------------------------------------
# gh / GraphQL helpers
# ----------------------------------------------------------------------------

def run_gh(args: list[str], token: str | None = None, check: bool = True) -> subprocess.CompletedProcess:
    """gh CLI を指定 token で実行する。"""
    env = os.environ.copy()
    if token:
        env["GH_TOKEN"] = token
    return subprocess.run(
        ["gh"] + args,
        env=env,
        capture_output=True,
        text=True,
        check=check,
    )


def gh_graphql(query: str, token: str, variables: dict | None = None) -> dict:
    """gh api graphql を実行して JSON 応答を返す。"""
    cmd = ["api", "graphql", "-f", f"query={query}"]
    if variables:
        for k, v in variables.items():
            if isinstance(v, int):
                cmd += ["-F", f"{k}={v}"]
            else:
                cmd += ["-f", f"{k}={v}"]
    result = run_gh(cmd, token=token)
    return json.loads(result.stdout)


# ----------------------------------------------------------------------------
# WBS parse + selection
# ----------------------------------------------------------------------------

def parse_wbs() -> list[dict]:
    """parse-wbs.py を実行して全 WBS tasks を取得する。"""
    result = subprocess.run(
        ["python3", str(REPO_ROOT / ".claude/hooks/parse-wbs.py")],
        capture_output=True,
        text=True,
        check=True,
    )
    return json.loads(result.stdout)


def current_week(today: date) -> int:
    """今日の iteration 番号を計算 (W1=2026-03-24 起点)。"""
    delta = (today - W1_START).days
    return max(1, delta // 7 + 1)


def iteration_contains(task_iter: str | None, week: int) -> bool:
    """タスクの iteration が現在の週を含むか判定する。"""
    if not task_iter or task_iter == "—":
        return False

    # W5 (単一週)
    m = re.fullmatch(r"W(\d+)", task_iter.strip())
    if m:
        return int(m.group(1)) == week

    # W2-4 or W1-10 (範囲)
    m = re.fullmatch(r"W(\d+)-(\d+)", task_iter.strip())
    if m:
        start, end = int(m.group(1)), int(m.group(2))
        return start <= week <= end

    # W5,W9 (カンマ区切り)
    for p in task_iter.split(","):
        p = p.strip()
        if p == f"W{week}":
            return True

    return False


def estimate_hours(task: dict) -> int:
    """タスクの時間見積もり (type から推定)。"""
    return TYPE_HOURS.get(task.get("type"), 2)


def select_today_tasks(
    tasks: list[dict],
    week: int,
    top_n: int = 5,
    time_budget: int = 4,
) -> list[dict]:
    """今日の top N タスクを **組織バランス** で選定する (案 B: org diversification)。

    選定アルゴリズム:
    1. フィルタ: status ∈ {todo, in-progress}, iteration が今週を含む
    2. 優先度順にグループ分け (priority 1, 2, 3, 4)
    3. 各優先度 tier 内で組織ごとに round-robin で拾う
       → 結果: priority 1 内で org 間バランス、足りなければ priority 2 へ進む
    4. top_n 件で打ち切り
    """
    from collections import defaultdict

    # Step 1: フィルタ
    candidates = [
        t for t in tasks
        if t.get("status") in ("todo", "in-progress")
        and iteration_contains(t.get("iteration"), week)
    ]

    if not candidates:
        return []

    # Step 2: 優先度別にバケット化し、各バケット内を (type_priority, wbs_id) でソート
    by_priority: dict[int, list[dict]] = defaultdict(list)
    for t in candidates:
        by_priority[t.get("priority") or 99].append(t)
    for p in by_priority:
        by_priority[p].sort(key=lambda t: (
            TYPE_PRIORITY.get(t.get("type"), 99),
            t["wbs_id"],
        ))

    # Step 3: 優先度 tier ごとに round-robin で選定
    selected: list[dict] = []
    for priority in sorted(by_priority.keys()):
        if len(selected) >= top_n:
            break

        tier_tasks = by_priority[priority]
        # この tier 内で org 別にバケット化 (ソート済み順序を保持)
        tier_by_org: dict[str, list[dict]] = defaultdict(list)
        for t in tier_tasks:
            tier_by_org[t["org"]].append(t)

        # org キー順 (安定性のため sorted)
        org_order = sorted(tier_by_org.keys())

        # round-robin で org をまわす
        while len(selected) < top_n:
            added_any = False
            for org in org_order:
                if len(selected) >= top_n:
                    break
                if tier_by_org[org]:
                    selected.append(tier_by_org[org].pop(0))
                    added_any = True
            if not added_any:
                break  # この tier は枯渇

    return selected


# ----------------------------------------------------------------------------
# Project v2 GraphQL operations
# ----------------------------------------------------------------------------

def fetch_project_info(token: str) -> dict:
    """Project 2 の id / fields / items を全部取得する。"""
    query = """
    query {
      user(login: "%s") {
        projectV2(number: %d) {
          id
          title
          fields(first: 30) {
            nodes {
              __typename
              ... on ProjectV2Field { id name }
              ... on ProjectV2IterationField { id name }
              ... on ProjectV2SingleSelectField {
                id
                name
                options { id name }
              }
            }
          }
          items(first: 500) {
            nodes {
              id
              content {
                __typename
                ... on Issue {
                  number
                  url
                  title
                  state
                  labels(first: 30) { nodes { name } }
                }
                ... on DraftIssue { title }
                ... on PullRequest { number url title }
              }
              fieldValues(first: 20) {
                nodes {
                  __typename
                  ... on ProjectV2ItemFieldDateValue {
                    field {
                      ... on ProjectV2FieldCommon { name }
                    }
                    date
                  }
                  ... on ProjectV2ItemFieldSingleSelectValue {
                    field {
                      ... on ProjectV2FieldCommon { name }
                    }
                    name
                    optionId
                  }
                  ... on ProjectV2ItemFieldTextValue {
                    field {
                      ... on ProjectV2FieldCommon { name }
                    }
                    text
                  }
                }
              }
            }
          }
        }
      }
    }
    """ % (OWNER, PROJECT_NUMBER)

    resp = gh_graphql(query, token=token)
    return resp["data"]["user"]["projectV2"]


def item_get_target_date(item: dict) -> str | None:
    """ item の Target date フィールド値を取得する。"""
    for fv in item.get("fieldValues", {}).get("nodes", []):
        if fv.get("__typename") != "ProjectV2ItemFieldDateValue":
            continue
        field_name = fv.get("field", {}).get("name")
        if field_name == "Target date":
            return fv.get("date")
    return None


def item_has_wbs_label(item: dict) -> bool:
    """item の Issue に todo:wbs ラベルがあるか。"""
    content = item.get("content") or {}
    if content.get("__typename") != "Issue":
        return False
    labels = content.get("labels", {}).get("nodes", [])
    return any(l.get("name") == "todo:wbs" for l in labels)


def item_issue_is_open(item: dict) -> bool:
    """item の Issue が OPEN 状態か (closed な Issue や非 Issue は False)。"""
    content = item.get("content") or {}
    if content.get("__typename") != "Issue":
        return False
    return content.get("state") == "OPEN"


def item_get_status(item: dict) -> str | None:
    """item の Project 2 Status フィールド値を取得する。"""
    for fv in item.get("fieldValues", {}).get("nodes", []):
        if fv.get("__typename") != "ProjectV2ItemFieldSingleSelectValue":
            continue
        field_name = fv.get("field", {}).get("name")
        if field_name == "Status":
            return fv.get("name")
    return None


def item_is_completed(item: dict) -> bool:
    """item が完了扱いか (Issue closed または Project 2 Status=Done)。"""
    if not item_issue_is_open(item):
        return True
    status = item_get_status(item)
    if status and status.lower() in ("done", "completed", "完了"):
        return True
    return False


def find_field_id(project_info: dict, field_name: str) -> str | None:
    """field 名から field ID を取得する。"""
    for f in project_info.get("fields", {}).get("nodes", []):
        if f.get("name") == field_name:
            return f.get("id")
    return None


def delete_item(project_id: str, item_id: str, token: str) -> None:
    """Project 2 からアイテムを削除する。"""
    query = """
    mutation($projectId: ID!, $itemId: ID!) {
      deleteProjectV2Item(input: {projectId: $projectId, itemId: $itemId}) {
        deletedItemId
      }
    }
    """
    gh_graphql(query, token=token, variables={"projectId": project_id, "itemId": item_id})


def add_item_by_issue(project_id: str, issue_url: str, token: str) -> str | None:
    """Issue URL を指定して Project 2 にアイテムを追加し、新しい item ID を返す。"""
    # まず Issue の node ID を取得する
    # URL 形式: https://github.com/owner/repo/issues/NNN
    m = re.match(r"https://github\.com/([^/]+)/([^/]+)/issues/(\d+)", issue_url)
    if not m:
        print(f"  ERROR: invalid issue URL: {issue_url}", file=sys.stderr)
        return None
    owner, repo, number = m.group(1), m.group(2), int(m.group(3))

    node_query = """
    query {
      repository(owner: "%s", name: "%s") {
        issue(number: %d) { id }
      }
    }
    """ % (owner, repo, number)
    node_resp = gh_graphql(node_query, token=token)
    issue_node_id = node_resp["data"]["repository"]["issue"]["id"]

    # addProjectV2ItemById で追加
    add_query = """
    mutation($projectId: ID!, $contentId: ID!) {
      addProjectV2ItemById(input: {projectId: $projectId, contentId: $contentId}) {
        item { id }
      }
    }
    """
    resp = gh_graphql(add_query, token=token, variables={"projectId": project_id, "contentId": issue_node_id})
    return resp["data"]["addProjectV2ItemById"]["item"]["id"]


def set_date_field(project_id: str, item_id: str, field_id: str, date_str: str, token: str) -> None:
    """item の DATE フィールドを設定する。"""
    query = """
    mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $date: Date!) {
      updateProjectV2ItemFieldValue(input: {
        projectId: $projectId
        itemId: $itemId
        fieldId: $fieldId
        value: { date: $date }
      }) {
        projectV2Item { id }
      }
    }
    """
    gh_graphql(query, token=token, variables={
        "projectId": project_id,
        "itemId": item_id,
        "fieldId": field_id,
        "date": date_str,
    })


def set_text_field(project_id: str, item_id: str, field_id: str, text: str, token: str) -> None:
    """item の TEXT フィールドを設定する。"""
    query = """
    mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $text: String!) {
      updateProjectV2ItemFieldValue(input: {
        projectId: $projectId
        itemId: $itemId
        fieldId: $fieldId
        value: { text: $text }
      }) {
        projectV2Item { id }
      }
    }
    """
    gh_graphql(query, token=token, variables={
        "projectId": project_id,
        "itemId": item_id,
        "fieldId": field_id,
        "text": text,
    })


def set_single_select_field(project_id: str, item_id: str, field_id: str, option_id: str, token: str) -> None:
    """item の SINGLE_SELECT フィールドを option ID で設定する。"""
    query = """
    mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $optionId: String!) {
      updateProjectV2ItemFieldValue(input: {
        projectId: $projectId
        itemId: $itemId
        fieldId: $fieldId
        value: { singleSelectOptionId: $optionId }
      }) {
        projectV2Item { id }
      }
    }
    """
    gh_graphql(query, token=token, variables={
        "projectId": project_id,
        "itemId": item_id,
        "fieldId": field_id,
        "optionId": option_id,
    })


def find_option_id(project_info: dict, field_name: str, option_name: str) -> str | None:
    """SINGLE_SELECT field の option 名から option ID を取得する。"""
    for f in project_info.get("fields", {}).get("nodes", []):
        if f.get("name") != field_name:
            continue
        for opt in f.get("options", []) or []:
            if opt.get("name") == option_name:
                return opt.get("id")
    return None


# ----------------------------------------------------------------------------
# WBS ID → GitHub Issue lookup
# ----------------------------------------------------------------------------

def lookup_issues_by_wbs_labels(wbs_ids: list[str], org: str, repo: str, token: str | None = None) -> dict[str, dict]:
    """wbs:<id> ラベル + org:<slug> ラベルで Issue を検索して {wbs_id: {number, url}} を返す。

    gh api で一括取得（GraphQL search）。token は GITHUB_TOKEN 系で可（Issue 読み取りのみ）。
    """
    result: dict[str, dict] = {}
    if not wbs_ids:
        return result

    # GraphQL search は一度に 1 query しか受け取れないので、個別に issue list を実行
    # repo は "owner/name" 形式
    for wbs_id in wbs_ids:
        # gh issue list with multiple label filters (AND)
        args = [
            "issue", "list",
            "-R", repo,
            "--label", f"wbs:{wbs_id}",
            "--label", f"org:{org}",
            "--label", "todo:wbs",
            "--state", "open",
            "--json", "number,url",
            "--limit", "1",
        ]
        try:
            r = run_gh(args, token=token)
            data = json.loads(r.stdout or "[]")
            if data:
                result[wbs_id] = {
                    "number": data[0]["number"],
                    "url": data[0]["url"],
                }
        except subprocess.CalledProcessError as e:
            print(f"  WARN: lookup failed for wbs:{wbs_id}: {e.stderr}", file=sys.stderr)

    return result


# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------

def main() -> int:
    ap = argparse.ArgumentParser(description="Daily kanban sync to Project 2")
    ap.add_argument("--mode", choices=["sync", "cleanup", "dry-run"], default="sync")
    ap.add_argument("--top-n", type=int, default=5)
    ap.add_argument("--time-budget", type=int, default=4, help="hours")
    ap.add_argument("--date", type=str, default="", help="YYYY-MM-DD (testing only)")
    args = ap.parse_args()

    token = os.environ.get("PROJECTS_PAT", "")
    if not token and args.mode != "dry-run":
        print("::error::PROJECTS_PAT required (Classic PAT with project scope)", file=sys.stderr)
        return 1

    repo = os.environ.get("GITHUB_REPOSITORY", "SAS-Sasao/cc-sier-organization")

    # 現在日付
    if args.date:
        today = date.fromisoformat(args.date)
    else:
        # JST
        import zoneinfo
        try:
            tz = zoneinfo.ZoneInfo("Asia/Tokyo")
        except Exception:
            tz = None
        if tz:
            from datetime import datetime
            today = datetime.now(tz).date()
        else:
            today = date.today()

    today_str = today.isoformat()
    week = current_week(today)

    print(f"=== Daily Kanban Sync ===")
    print(f"Mode: {args.mode}")
    print(f"Today: {today_str} (W{week})")
    print(f"Top N: {args.top_n}, Time budget: {args.time_budget}h")
    print()

    # Step 1: WBS parse
    print("Step 1: Parse WBS")
    tasks = parse_wbs()
    print(f"  {len(tasks)} tasks loaded")
    print()

    # Step 2: Project 2 の情報取得
    print("Step 2: Fetch Project 2 state")
    if args.mode == "dry-run" and not token:
        print("  [DRY] skipping GraphQL fetch")
        project_info = {"id": "DRY-RUN", "fields": {"nodes": []}, "items": {"nodes": []}}
    else:
        project_info = fetch_project_info(token)

    project_id = project_info["id"]
    items = project_info.get("items", {}).get("nodes", [])
    print(f"  Project 2: id={project_id} items={len(items)}")

    target_date_field_id = find_field_id(project_info, "Target date")
    wbs_id_field_id = find_field_id(project_info, "WBS-ID")
    priority_field_id = find_field_id(project_info, "Priority")
    print(f"  Fields: Target date={target_date_field_id}, WBS-ID={wbs_id_field_id}, Priority={priority_field_id}")
    print()

    # Step 3: 現在の items を分類
    #   keepers:    WBS items + Issue OPEN + Status != Done (= 未完了繰越し)
    #   disposables: それ以外 (非 WBS, Issue closed, Status = Done)
    keepers: list[dict] = []
    disposables: list[dict] = []
    for item in items:
        if not item_has_wbs_label(item):
            disposables.append(item)
            continue
        if item_is_completed(item):
            disposables.append(item)
            continue
        keepers.append(item)

    keeper_urls = {(i.get("content") or {}).get("url") for i in keepers}
    keeper_urls.discard(None)

    print(f"Step 3: Categorize {len(items)} current items")
    print(f"  Keepers (WBS, open, not done): {len(keepers)}")
    print(f"  Disposables (non-WBS or completed): {len(disposables)}")
    print()

    # Step 4: Cleanup mode → disposables のみ削除して終了
    if args.mode == "cleanup":
        print("Step 4: Cleanup mode — deleting disposables only")
        for i, item in enumerate(disposables, 1):
            content = item.get("content") or {}
            title = content.get("title", "—")[:50]
            try:
                delete_item(project_id, item["id"], token)
                print(f"    [{i}/{len(disposables)}] Deleted: {title}")
            except Exception as e:
                print(f"    [{i}/{len(disposables)}] FAILED: {title}: {e}", file=sys.stderr)
        print()
        print(f"=== Summary (cleanup) ===")
        print(f"  Deleted: {len(disposables)}")
        print(f"  Kept: {len(keepers)}")
        return 0

    # Step 5: 新規選定枠の計算
    remaining_slots = max(0, args.top_n - len(keepers))
    print(f"Step 5: Remaining slots for new tasks: {remaining_slots} (top_n={args.top_n} - keepers={len(keepers)})")
    print()

    # Step 6: 新規選定 (十分な候補があるよう overshoot → keepers と重複除外 → cap)
    print("Step 6: Select new today's tasks")
    candidates = select_today_tasks(tasks, week, top_n=args.top_n + len(keepers) + 10, time_budget=args.time_budget)
    print(f"  Candidates (top {len(candidates)}): {len(candidates)} tasks for W{week}")

    # Step 7: Issue lookup
    print("Step 7: Lookup GitHub Issues by label")
    by_org: dict[str, list[str]] = {}
    for t in candidates:
        by_org.setdefault(t["org"], []).append(t["wbs_id"])

    issue_map: dict[tuple[str, str], dict] = {}
    issue_lookup_token = os.environ.get("GITHUB_TOKEN") or token
    for org, wbs_ids in by_org.items():
        found = lookup_issues_by_wbs_labels(wbs_ids, org, repo, token=issue_lookup_token)
        for wbs_id, info in found.items():
            issue_map[(org, wbs_id)] = info

    for t in candidates:
        info = issue_map.get((t["org"], t["wbs_id"]))
        if info:
            t["issue_number"] = info["number"]
            t["issue_url"] = info["url"]

    # Step 8: keepers 重複除外 + 枠数 cap
    new_selected: list[dict] = []
    for t in candidates:
        if len(new_selected) >= remaining_slots:
            break
        if not t.get("issue_url"):
            continue
        if t["issue_url"] in keeper_urls:
            continue  # keeper に含まれている
        new_selected.append(t)

    print(f"  Filtered new selection: {len(new_selected)} tasks")
    for i, t in enumerate(new_selected, 1):
        print(f"    {i}. [{t['org']}] {t['wbs_id']}: {t['task']}  #{t['issue_number']}")
    print()

    # Step 9: keepers の一覧表示
    if keepers:
        print(f"Step 9: Keepers (carry over from previous days): {len(keepers)}")
        for i, item in enumerate(keepers, 1):
            content = item.get("content") or {}
            title = content.get("title", "—")[:60]
            td = item_get_target_date(item) or "—"
            print(f"    {i}. {title}  (original Target date={td})")
        print()

    # Step 10: Delete disposables
    print(f"Step 10: Delete disposables ({len(disposables)} items)")
    deleted_count = 0
    if args.mode == "dry-run":
        print(f"  [DRY] would delete {len(disposables)} items")
    else:
        for i, item in enumerate(disposables, 1):
            content = item.get("content") or {}
            title = content.get("title", "—")[:50]
            try:
                delete_item(project_id, item["id"], token)
                deleted_count += 1
                if i % 20 == 0 or i == len(disposables):
                    print(f"    [{i}/{len(disposables)}] progress...")
            except Exception as e:
                print(f"    [{i}/{len(disposables)}] FAILED: {title}: {e}", file=sys.stderr)
    print()

    # Step 11: Update keepers の Target date を今日に (rolling target)
    print(f"Step 11: Update keepers' Target date to {today_str}")
    updated_keepers = 0
    if args.mode == "dry-run":
        print(f"  [DRY] would update {len(keepers)} keepers")
    else:
        for item in keepers:
            if target_date_field_id:
                try:
                    set_date_field(project_id, item["id"], target_date_field_id, today_str, token)
                    updated_keepers += 1
                except Exception as e:
                    print(f"    WARN: Update failed: {e}", file=sys.stderr)
    print()

    # Step 12: Add new selected tasks
    print(f"Step 12: Add {len(new_selected)} new tasks to Project 2")
    added_count = 0
    for t in new_selected:
        issue_url = t.get("issue_url") or f"https://github.com/{repo}/issues/{t['issue_number']}"

        if args.mode == "dry-run":
            print(f"  [DRY] would add: {t['wbs_id']} {issue_url}")
            continue

        try:
            item_id = add_item_by_issue(project_id, issue_url, token)
            if not item_id:
                continue
            print(f"  Added: {t['wbs_id']} -> item {item_id}")
            added_count += 1

            # Target date 設定
            if target_date_field_id:
                try:
                    set_date_field(project_id, item_id, target_date_field_id, today_str, token)
                except Exception as e:
                    print(f"    WARN: Target date failed: {e}", file=sys.stderr)

            # WBS-ID 設定
            if wbs_id_field_id:
                try:
                    set_text_field(project_id, item_id, wbs_id_field_id, t["wbs_id"], token)
                except Exception as e:
                    print(f"    WARN: WBS-ID failed: {e}", file=sys.stderr)

            # Priority 設定 (SINGLE_SELECT)
            if priority_field_id and t.get("priority"):
                option_id = find_option_id(project_info, "Priority", f"P{t['priority']}")
                if not option_id:
                    option_id = find_option_id(project_info, "Priority", str(t["priority"]))
                if option_id:
                    try:
                        set_single_select_field(project_id, item_id, priority_field_id, option_id, token)
                    except Exception as e:
                        print(f"    WARN: Priority failed: {e}", file=sys.stderr)

        except Exception as e:
            print(f"  FAILED: {t['wbs_id']}: {e}", file=sys.stderr)

    print()
    print(f"=== Summary ===")
    print(f"  Mode: {args.mode}")
    print(f"  Before: {len(items)} items (WBS={len(items)-len(disposables) if len(items)>=len(disposables) else 0}, disposables={len(disposables)})")
    print(f"  Keepers (carry over): {len(keepers)}")
    print(f"  Deleted (disposables): {deleted_count}")
    print(f"  Keepers Target date updated: {updated_keepers}")
    print(f"  New tasks added: {added_count}")
    print(f"  Expected final count: {len(keepers) + added_count}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
