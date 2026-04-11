#!/usr/bin/env python3
"""daily-insights-sync.py — TodoInsights (Project 4) にクローズ済み Issues/PRs を同期

Usage:
    python3 .claude/hooks/daily-insights-sync.py --mode sync
    python3 .claude/hooks/daily-insights-sync.py --mode backfill --since 2026-03-21
    python3 .claude/hooks/daily-insights-sync.py --mode dry-run

Environment:
    PROJECTS_PAT  (required)   — Classic PAT with project + read:org + read:discussion
    GITHUB_TOKEN  (optional)   — Issue/PR 読取 (無ければ PROJECTS_PAT 流用)

Modes:
    sync (default)  — 過去 24h の closed items を追加 (rolling window)
    backfill        — --since 以降の全 closed items を一括インポート
    dry-run         — 計画のみ出力、実変更なし

動作:
    1. GitHub Search API で cc-sier-organization の closed Issues/PRs を取得
    2. Project 4 の既存 items と突合 (Issue URL で dedup)
    3. 新規 items を Project v2 に追加
    4. カスタムフィールド (Closed date / Type / Org / Category) を設定
"""

import argparse
import json
import os
import re
import subprocess
import sys
from datetime import date, datetime, timedelta, timezone
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
OWNER = "SAS-Sasao"
PROJECT_NUMBER = 4  # TodoInsights
REPO_FULL = "SAS-Sasao/cc-sier-organization"

# Category 判定テーブル (label 優先)
CATEGORY_LABEL_MAP: dict[str, str] = {
    "todo:wbs": "wbs",
    "type:daily-digest": "digest",
    "daily-kanban-sync": "automation",
    "daily-todo-sync-tracker": "automation",
    "daily-todo-sync": "automation",
    "daily-kanban-sync-tracker": "automation",
    "nightly-claude-md-update": "automation",
    "nightly-claude-md-tracker": "automation",
    "daily-cycle-supplement-tracker": "automation",
    "daily-digest-automation-tracker": "automation",
    "daily-digest-automation": "automation",
    "daily-insights-sync-tracker": "automation",
    "daily-insights-sync": "automation",
    "cycle-tracker": "automation",
    "cycle-supplement-tracker": "automation",
    "needs-human-review": "automation",
}

# タイトル prefix による category 判定 (fallback)
CATEGORY_TITLE_PATTERNS = [
    (re.compile(r"^feat[:\(]"), "feat"),
    (re.compile(r"^fix[:\(]"), "fix"),
    (re.compile(r"^docs[:\(]"), "docs"),
    (re.compile(r"^chore[:\(]"), "chore"),
    (re.compile(r"^ci[:\(]"), "chore"),
    (re.compile(r"^refactor[:\(]"), "other"),
    (re.compile(r"^test[:\(]"), "other"),
    (re.compile(r"^perf[:\(]"), "other"),
    (re.compile(r"^admin[:\(]"), "chore"),
]

# ----------------------------------------------------------------------------
# Automation filter (include/exclude 判定)
# ----------------------------------------------------------------------------
# 目的: Project 4 には "PR + WBS Issue" のみを残す。
# cc-sier-bot 由来の自動 merge PR、tracker Issue、nightly PR 等を除外する。

# 自動化由来を示すラベル (ラベルが 1 つでもあれば automation と判定)
AUTOMATION_LABELS: set[str] = {
    # workflow 実行ラベル
    "daily-digest-automation",
    "daily-todo-sync",
    "daily-kanban-sync",
    "daily-insights-sync",
    "nightly-claude-md-update",
    "daily-cycle-supplement",
    # tracker Issue ラベル
    "daily-digest-automation-tracker",
    "daily-todo-sync-tracker",
    "daily-kanban-sync-tracker",
    "daily-insights-sync-tracker",
    "nightly-claude-md-tracker",
    "cycle-tracker",
    "cycle-supplement-tracker",
    # その他自動生成
    "interaction-log",
    "needs-human-review",  # nightly-claude-md PR に付く
}

# タイトル pattern (label が無くても automation と判定)
AUTOMATION_TITLE_PATTERNS: list[re.Pattern] = [
    re.compile(r"^chore: ダッシュボード更新"),
    re.compile(r"^chore: TodoInsights HTML"),
    re.compile(r"^chore: post-merge"),
    re.compile(r"^chore: WBS.*自動同期"),
    re.compile(r"^chore: cycle"),
    re.compile(r"^chore: 日次ダイジェスト"),
    re.compile(r"^nightly:", re.IGNORECASE),
    re.compile(r"^daily-\w+:", re.IGNORECASE),
    re.compile(r"^docs: nightly", re.IGNORECASE),
    re.compile(r"^docs: CLAUDE\.md.*nightly", re.IGNORECASE),
    re.compile(r"^ci: daily-"),
    re.compile(r"^feat: 日次ダイジェスト"),  # daily-digest-automation PR
]


def is_automation(labels: list[str], title: str) -> bool:
    """label 優先、title pattern fallback で automation 判定する。"""
    # Label check
    for lbl in labels:
        if lbl in AUTOMATION_LABELS:
            return True
    # Title pattern check
    for pat in AUTOMATION_TITLE_PATTERNS:
        if pat.match(title):
            return True
    return False


def pr_closes_wbs_issue(item: dict) -> bool:
    """PR が閉じる Issue のいずれかに todo:wbs ラベルがあるか判定する。

    GraphQL search クエリで PullRequest.closingIssuesReferences を取得しておく必要がある。
    もし fetch 時にこのフィールドが取得されていなければ False を返す。
    """
    if item.get("__typename") != "PullRequest":
        return False
    closing_refs = item.get("closingIssuesReferences") or {}
    refs = closing_refs.get("nodes") or []
    for ref in refs:
        if not ref:
            continue
        ref_labels = (ref.get("labels") or {}).get("nodes") or []
        for lbl in ref_labels:
            if (lbl or {}).get("name") == "todo:wbs":
                return True
    return False


def should_include(item: dict) -> tuple[bool, str]:
    """TodoInsights に含めるべきか判定。(include, reason) を返す。

    ルール (さらに厳しく):
        - Issue:  todo:wbs ラベル付きのみ (= WBS 用 Issue)
        - PR:     closingIssuesReferences のいずれかに todo:wbs ラベル付き Issue があるもののみ
                  (= WBS Issue を close する PR = WBS 起因 PR)
        - automation は問答無用で除外
    """
    labels = [l.get("name", "") for l in ((item.get("labels") or {}).get("nodes") or [])]
    title = item.get("title", "")
    item_type = "PR" if item.get("__typename") == "PullRequest" else "Issue"

    # まず automation 除外
    if is_automation(labels, title):
        return False, "automation"

    if item_type == "Issue":
        if "todo:wbs" in labels:
            return True, "wbs-issue"
        return False, "non-wbs-issue"

    # PR: closingIssuesReferences で WBS Issue を close しているか
    if pr_closes_wbs_issue(item):
        return True, "wbs-pr"
    return False, "non-wbs-pr"


# ----------------------------------------------------------------------------
# gh / GraphQL helpers
# ----------------------------------------------------------------------------

def run_gh(args: list[str], token: str | None = None, check: bool = True) -> subprocess.CompletedProcess:
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
    cmd = ["api", "graphql", "-f", f"query={query}"]
    if variables:
        for k, v in variables.items():
            if v is None:
                continue
            if isinstance(v, int):
                cmd += ["-F", f"{k}={v}"]
            else:
                cmd += ["-f", f"{k}={v}"]
    try:
        result = run_gh(cmd, token=token)
    except subprocess.CalledProcessError as e:
        print(f"::error::gh graphql failed:", file=sys.stderr)
        print(f"::error::  stderr: {e.stderr}", file=sys.stderr)
        raise
    data = json.loads(result.stdout)
    if data.get("errors"):
        print(f"::warning::GraphQL errors: {data['errors']}", file=sys.stderr)
    return data


# ----------------------------------------------------------------------------
# Closed items search (GitHub Search API)
# ----------------------------------------------------------------------------

def fetch_closed_items(search_query: str, token: str) -> list[dict]:
    """GitHub Search API でクローズ済み Issues/PRs を取得 (cursor pagination)。

    注意: search API は 1000 件上限。backfill で超える場合は呼び出し側で分割する。
    """
    all_items: list[dict] = []
    cursor: str | None = None
    page = 0
    query = """
    query($q: String!, $cursor: String) {
      search(query: $q, type: ISSUE, first: 100, after: $cursor) {
        issueCount
        pageInfo { hasNextPage endCursor }
        nodes {
          __typename
          ... on Issue {
            id
            number
            url
            title
            state
            closedAt
            labels(first: 30) { nodes { name } }
          }
          ... on PullRequest {
            id
            number
            url
            title
            state
            closedAt
            mergedAt
            labels(first: 30) { nodes { name } }
            closingIssuesReferences(first: 10, userLinkedOnly: false) {
              nodes {
                number
                labels(first: 20) { nodes { name } }
              }
            }
          }
        }
      }
    }
    """
    while True:
        page += 1
        resp = gh_graphql(query, token=token, variables={"q": search_query, "cursor": cursor})
        search = resp["data"]["search"]
        total = search.get("issueCount", 0)
        nodes = [n for n in (search.get("nodes") or []) if n]
        all_items.extend(nodes)
        print(
            f"  Fetched page {page}: {len(nodes)} items (cumulative: {len(all_items)} / totalCount: {total})",
            file=sys.stderr,
        )
        page_info = search.get("pageInfo") or {}
        if not page_info.get("hasNextPage"):
            break
        cursor = page_info.get("endCursor")
        if not cursor:
            break
    return all_items


# ----------------------------------------------------------------------------
# Project v2 ops
# ----------------------------------------------------------------------------

def fetch_project_info(token: str) -> dict:
    """Project 4 の id / fields / items を取得する (items は pagination)。"""
    query = """
    query($cursor: String) {
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
          items(first: 100, after: $cursor) {
            pageInfo { hasNextPage endCursor }
            nodes {
              id
              content {
                __typename
                ... on Issue { number url }
                ... on PullRequest { number url }
              }
            }
          }
        }
      }
    }
    """ % (OWNER, PROJECT_NUMBER)

    all_items: list[dict] = []
    project_id = None
    title = None
    fields_nodes = None
    cursor: str | None = None
    page = 0

    while True:
        page += 1
        resp = gh_graphql(query, token=token, variables={"cursor": cursor})
        pv2 = resp["data"]["user"]["projectV2"]
        if pv2 is None:
            print("::error::Project 4 not found or not accessible", file=sys.stderr)
            break

        if project_id is None:
            project_id = pv2["id"]
            title = pv2["title"]
            fields_nodes = pv2["fields"]

        items_conn = pv2.get("items", {})
        page_nodes = items_conn.get("nodes") or []
        all_items.extend(page_nodes)

        page_info = items_conn.get("pageInfo") or {}
        if not page_info.get("hasNextPage"):
            break
        cursor = page_info.get("endCursor")
        if not cursor:
            break

    print(f"  Project {title}: {len(all_items)} existing items", file=sys.stderr)

    return {
        "id": project_id,
        "title": title,
        "fields": fields_nodes or {"nodes": []},
        "items": {"nodes": all_items},
    }


def find_field_id(project_info: dict, field_name: str) -> str | None:
    for f in project_info.get("fields", {}).get("nodes", []):
        if f.get("name") == field_name:
            return f.get("id")
    return None


def find_option_id(project_info: dict, field_name: str, option_name: str) -> str | None:
    for f in project_info.get("fields", {}).get("nodes", []):
        if f.get("name") != field_name:
            continue
        for opt in f.get("options", []) or []:
            if opt.get("name") == option_name:
                return opt.get("id")
    return None


def add_item(project_id: str, content_node_id: str, token: str) -> str | None:
    query = """
    mutation($projectId: ID!, $contentId: ID!) {
      addProjectV2ItemById(input: {projectId: $projectId, contentId: $contentId}) {
        item { id }
      }
    }
    """
    resp = gh_graphql(query, token=token, variables={"projectId": project_id, "contentId": content_node_id})
    try:
        return resp["data"]["addProjectV2ItemById"]["item"]["id"]
    except (KeyError, TypeError):
        return None


def set_date_field(project_id: str, item_id: str, field_id: str, date_str: str, token: str) -> None:
    query = """
    mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $date: Date!) {
      updateProjectV2ItemFieldValue(input: {
        projectId: $projectId
        itemId: $itemId
        fieldId: $fieldId
        value: { date: $date }
      }) { projectV2Item { id } }
    }
    """
    gh_graphql(query, token=token, variables={
        "projectId": project_id,
        "itemId": item_id,
        "fieldId": field_id,
        "date": date_str,
    })


def set_single_select_field(project_id: str, item_id: str, field_id: str, option_id: str, token: str) -> None:
    query = """
    mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $optionId: String!) {
      updateProjectV2ItemFieldValue(input: {
        projectId: $projectId
        itemId: $itemId
        fieldId: $fieldId
        value: { singleSelectOptionId: $optionId }
      }) { projectV2Item { id } }
    }
    """
    gh_graphql(query, token=token, variables={
        "projectId": project_id,
        "itemId": item_id,
        "fieldId": field_id,
        "optionId": option_id,
    })


def delete_project_item(project_id: str, item_id: str, token: str) -> None:
    """Project v2 から item を削除する。"""
    query = """
    mutation($projectId: ID!, $itemId: ID!) {
      deleteProjectV2Item(input: {projectId: $projectId, itemId: $itemId}) {
        deletedItemId
      }
    }
    """
    gh_graphql(query, token=token, variables={"projectId": project_id, "itemId": item_id})


def fetch_project_items_for_filter(token: str) -> tuple[str, list[dict]]:
    """cleanup-filter 用に Project 4 の全 items を取得する (content + labels + closingIssues)。"""
    query = """
    query($cursor: String) {
      user(login: "%s") {
        projectV2(number: %d) {
          id
          items(first: 100, after: $cursor) {
            pageInfo { hasNextPage endCursor }
            nodes {
              id
              content {
                __typename
                ... on Issue {
                  number url title
                  labels(first: 30) { nodes { name } }
                }
                ... on PullRequest {
                  number url title
                  labels(first: 30) { nodes { name } }
                  closingIssuesReferences(first: 10, userLinkedOnly: false) {
                    nodes {
                      number
                      labels(first: 20) { nodes { name } }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
    """ % (OWNER, PROJECT_NUMBER)

    all_nodes: list[dict] = []
    project_id = None
    cursor: str | None = None
    page = 0
    while True:
        page += 1
        resp = gh_graphql(query, token=token, variables={"cursor": cursor})
        pv2 = resp["data"]["user"]["projectV2"]
        if pv2 is None:
            break
        if project_id is None:
            project_id = pv2["id"]
        items_conn = pv2.get("items", {}) or {}
        page_nodes = items_conn.get("nodes") or []
        all_nodes.extend(page_nodes)
        page_info = items_conn.get("pageInfo") or {}
        if not page_info.get("hasNextPage"):
            break
        cursor = page_info.get("endCursor")
        if not cursor:
            break
    return project_id, all_nodes


def run_cleanup_filter(token: str) -> int:
    """cleanup-filter mode: Project 4 の全 items を filter で再評価し、非マッチを削除する。"""
    print("=== cleanup-filter mode ===")
    print("Fetch all Project 4 items...")
    project_id, items = fetch_project_items_for_filter(token)
    if project_id is None:
        print("::error::Project 4 not accessible", file=sys.stderr)
        return 1

    print(f"  Current items: {len(items)}")
    print()

    keep: list[dict] = []
    remove: list[tuple[dict, str]] = []  # (item, reason)

    for node in items:
        content = node.get("content") or {}
        if not content:
            remove.append((node, "no-content"))
            continue
        include, reason = should_include(content)
        if include:
            keep.append(node)
        else:
            remove.append((node, reason))

    # Reason 別集計
    reason_counts: dict[str, int] = {}
    for _, reason in remove:
        reason_counts[reason] = reason_counts.get(reason, 0) + 1

    print(f"Keep: {len(keep)} items (WBS-origin)")
    print(f"Remove: {len(remove)} items")
    print(f"  Reason breakdown: {reason_counts}")
    print()

    # 削除実行
    print(f"Deleting {len(remove)} items...")
    deleted = 0
    failed = 0
    for i, (node, reason) in enumerate(remove, 1):
        try:
            delete_project_item(project_id, node["id"], token)
            deleted += 1
            if i % 25 == 0 or i == len(remove):
                print(f"  progress: {i}/{len(remove)}")
        except Exception as e:
            print(f"  FAILED to delete {node.get('id')}: {e}", file=sys.stderr)
            failed += 1

    print()
    print(f"=== Summary (cleanup-filter) ===")
    print(f"  Before: {len(items)}")
    print(f"  Kept: {len(keep)}")
    print(f"  Deleted: {deleted}")
    print(f"  Failed: {failed}")
    return 0


# ----------------------------------------------------------------------------
# Classification helpers
# ----------------------------------------------------------------------------

def detect_type(item: dict) -> str:
    return "PR" if item.get("__typename") == "PullRequest" else "Issue"


def detect_org(labels: list[str]) -> str:
    for lbl in labels:
        if lbl.startswith("org:"):
            candidate = lbl[len("org:"):]
            if candidate in ("domain-tech-collection", "standardization-initiative", "jutaku-dev-team"):
                return candidate
    return "none"


def detect_category(labels: list[str], title: str) -> str:
    # Label 優先
    for lbl in labels:
        if lbl in CATEGORY_LABEL_MAP:
            return CATEGORY_LABEL_MAP[lbl]
    # Title prefix fallback
    for pattern, cat in CATEGORY_TITLE_PATTERNS:
        if pattern.match(title):
            return cat
    return "other"


def jst_date_from_utc(utc_iso: str | None) -> str | None:
    if not utc_iso:
        return None
    try:
        dt = datetime.fromisoformat(utc_iso.replace("Z", "+00:00"))
        jst_dt = dt.astimezone(timezone(timedelta(hours=9)))
        return jst_dt.date().isoformat()
    except Exception:
        return None


# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------

def main() -> int:
    ap = argparse.ArgumentParser(description="TodoInsights daily sync")
    ap.add_argument(
        "--mode",
        choices=["sync", "backfill", "dry-run", "cleanup-filter"],
        default="sync",
    )
    ap.add_argument("--since", type=str, default="", help="backfill start date YYYY-MM-DD (default: 2026-03-21)")
    ap.add_argument("--until", type=str, default="", help="backfill end date YYYY-MM-DD (default: today)")
    ap.add_argument("--window-hours", type=int, default=24, help="sync mode rolling window (default: 24)")
    args = ap.parse_args()

    token = os.environ.get("PROJECTS_PAT", "")
    if not token and args.mode != "dry-run":
        print("::error::PROJECTS_PAT required (Classic PAT with project + read:org + read:discussion)", file=sys.stderr)
        return 1

    issue_token = os.environ.get("GITHUB_TOKEN") or token

    # JST 時刻計算
    try:
        import zoneinfo
        tz_jst = zoneinfo.ZoneInfo("Asia/Tokyo")
    except Exception:
        tz_jst = timezone(timedelta(hours=9))

    now_jst = datetime.now(tz_jst)
    now_utc = now_jst.astimezone(timezone.utc)

    # Search query 構築
    if args.mode == "backfill":
        since = args.since or "2026-03-21"
        if args.until:
            search_query = f"repo:{REPO_FULL} is:closed closed:{since}..{args.until}"
        else:
            search_query = f"repo:{REPO_FULL} is:closed closed:>={since}"
    else:
        # sync / dry-run: rolling window
        since_utc = now_utc - timedelta(hours=args.window_hours)
        since_iso = since_utc.strftime("%Y-%m-%dT%H:%M:%SZ")
        now_iso = now_utc.strftime("%Y-%m-%dT%H:%M:%SZ")
        search_query = f"repo:{REPO_FULL} is:closed closed:{since_iso}..{now_iso}"

    print(f"=== TodoInsights Sync ===")
    print(f"Mode: {args.mode}")
    print(f"JST now: {now_jst.isoformat()}")
    print()

    # ---------------------------------------------------------------
    # cleanup-filter mode: 既存 Project 4 items を filter で再評価して削除
    # ---------------------------------------------------------------
    if args.mode == "cleanup-filter":
        return run_cleanup_filter(token)

    print(f"Search query: {search_query}")
    print()

    # Step 1: Fetch closed items
    print("Step 1: Fetch closed Issues/PRs from GitHub Search API")
    closed_items = fetch_closed_items(search_query, token=issue_token)
    print(f"  {len(closed_items)} items matched")
    print()

    if not closed_items:
        print("No closed items in this window. Nothing to do.")
        return 0

    # Step 1.5: Filter (include only WBS-origin PRs and WBS Issues)
    print("Step 1.5: Apply filter (only WBS-origin PR/Issue)")
    filter_stats: dict[str, int] = {}
    filtered_items: list[dict] = []
    for it in closed_items:
        include, reason = should_include(it)
        filter_stats[reason] = filter_stats.get(reason, 0) + 1
        if include:
            filtered_items.append(it)
    print(f"  Filter result: {filter_stats}")
    print(f"  Kept: {len(filtered_items)} / {len(closed_items)}")
    closed_items = filtered_items
    print()

    if not closed_items:
        print("Nothing to add after filter.")
        return 0

    # Step 2: Fetch project state
    print("Step 2: Fetch Project 4 (TodoInsights) state")
    if args.mode == "dry-run" and not token:
        print("  [DRY] skipping GraphQL fetch")
        project_info = {"id": "DRY-RUN", "fields": {"nodes": []}, "items": {"nodes": []}}
    else:
        project_info = fetch_project_info(token)

    project_id = project_info["id"]
    existing_items = project_info.get("items", {}).get("nodes", [])
    existing_urls: set[str] = set()
    for item in existing_items:
        url = (item.get("content") or {}).get("url")
        if url:
            existing_urls.add(url)
    print(f"  existing: {len(existing_items)} items, {len(existing_urls)} unique URLs")
    print()

    # Step 3: Field lookup
    closed_date_field_id = find_field_id(project_info, "Closed date")
    type_field_id = find_field_id(project_info, "Type")
    org_field_id = find_field_id(project_info, "Org")
    category_field_id = find_field_id(project_info, "Category")

    if args.mode != "dry-run":
        missing_fields = [name for name, fid in [
            ("Closed date", closed_date_field_id),
            ("Type", type_field_id),
            ("Org", org_field_id),
            ("Category", category_field_id),
        ] if fid is None]
        if missing_fields:
            print(f"::warning::Missing custom fields: {missing_fields}")
            print(f"::warning::Run 'gh project field-create' to add them before sync")

    # Step 4: Categorize and add
    print("Step 4: Classify and add items")
    added = 0
    skipped = 0
    failed = 0
    by_date: dict[str, int] = {}
    by_type: dict[str, int] = {}
    by_org: dict[str, int] = {}
    by_category: dict[str, int] = {}

    for item in closed_items:
        url = item.get("url")
        if not url:
            continue

        labels = [l["name"] for l in (item.get("labels") or {}).get("nodes", [])]
        title = item.get("title", "")
        node_id = item.get("id")
        itype = detect_type(item)
        org = detect_org(labels)
        category = detect_category(labels, title)
        closed_iso = item.get("closedAt") or ""
        closed_date = jst_date_from_utc(closed_iso)

        # 統計集計
        if closed_date:
            by_date[closed_date] = by_date.get(closed_date, 0) + 1
        by_type[itype] = by_type.get(itype, 0) + 1
        by_org[org] = by_org.get(org, 0) + 1
        by_category[category] = by_category.get(category, 0) + 1

        if url in existing_urls:
            skipped += 1
            continue

        if args.mode == "dry-run":
            print(f"  [DRY] +#{item.get('number')} {title[:50]}")
            print(f"         type={itype} org={org} category={category} closed={closed_date}")
            continue

        if not node_id:
            print(f"  WARN: no node id for {url}", file=sys.stderr)
            failed += 1
            continue

        try:
            new_item_id = add_item(project_id, node_id, token)
            if not new_item_id:
                failed += 1
                continue
            added += 1

            # Set custom fields
            if closed_date_field_id and closed_date:
                try:
                    set_date_field(project_id, new_item_id, closed_date_field_id, closed_date, token)
                except Exception as e:
                    print(f"    WARN Closed date: {e}", file=sys.stderr)

            if type_field_id:
                opt_id = find_option_id(project_info, "Type", itype)
                if opt_id:
                    try:
                        set_single_select_field(project_id, new_item_id, type_field_id, opt_id, token)
                    except Exception as e:
                        print(f"    WARN Type: {e}", file=sys.stderr)

            if org_field_id:
                opt_id = find_option_id(project_info, "Org", org)
                if opt_id:
                    try:
                        set_single_select_field(project_id, new_item_id, org_field_id, opt_id, token)
                    except Exception as e:
                        print(f"    WARN Org: {e}", file=sys.stderr)

            if category_field_id:
                opt_id = find_option_id(project_info, "Category", category)
                if opt_id:
                    try:
                        set_single_select_field(project_id, new_item_id, category_field_id, opt_id, token)
                    except Exception as e:
                        print(f"    WARN Category: {e}", file=sys.stderr)

            if added % 25 == 0:
                print(f"  progress: {added} added...")

        except Exception as e:
            print(f"  FAILED #{item.get('number')}: {e}", file=sys.stderr)
            failed += 1

    # Summary
    print()
    print(f"=== Summary ===")
    print(f"  Mode: {args.mode}")
    print(f"  Fetched (matching search): {len(closed_items)}")
    print(f"  Added: {added}")
    print(f"  Skipped (already in project): {skipped}")
    print(f"  Failed: {failed}")
    print()
    print(f"  By type: {dict(sorted(by_type.items()))}")
    print(f"  By org: {dict(sorted(by_org.items()))}")
    print(f"  By category: {dict(sorted(by_category.items()))}")
    print(f"  By date (top 10):")
    for d in sorted(by_date.keys(), reverse=True)[:10]:
        print(f"    {d}: {by_date[d]}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
