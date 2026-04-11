#!/usr/bin/env python3
"""generate-insights-html.py — TodoInsights (Project 4) の HTML dashboard を生成する

Reads:
    Project v2 TodoInsights (number=4) の全 items + field values

Writes:
    docs/insights/index.html         — メイン dashboard
    docs/index.html                   — トップページに TodoInsights カード追記

Environment:
    PROJECTS_PAT (required)           — Classic PAT with project scope

Features:
    - 累計 / 今週 / 今日 / 直近30日平均の サマリーカード
    - 日別完了件数 棒グラフ (直近 30 日, Issue/PR stack)
    - 週次トレンド 折れ線 (直近 12 週)
    - カテゴリ分布 doughnut chart
    - 組織分布 horizontal bar
    - 累計完了 area line
    - 最新クローズ 20 件 テーブル
    - Dark / Light mode 自動切替
    - Chart.js CDN (オフライン時はグレースフル劣化)
"""

import json
import os
import re
import subprocess
import sys
from collections import Counter, defaultdict
from datetime import date, datetime, timedelta, timezone
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
OWNER = "SAS-Sasao"
PROJECT_NUMBER = 4  # TodoInsights
REPO_URL_BASE = "https://github.com/SAS-Sasao/cc-sier-organization"


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
        print(f"::error::gh graphql failed: {e.stderr}", file=sys.stderr)
        raise
    data = json.loads(result.stdout)
    if data.get("errors"):
        print(f"::warning::GraphQL errors: {data['errors']}", file=sys.stderr)
    return data


# ----------------------------------------------------------------------------
# Fetch Project 4 items with field values
# ----------------------------------------------------------------------------

def fetch_all_items(token: str) -> tuple[list[dict], str]:
    """Project 4 の items を全ページ取得してフラット dict のリストに変換する。

    各 dict には以下のキーが入る:
        url, number, title, state, type (Issue|PR), closed_date, org, category, labels
    """
    query = """
    query($cursor: String) {
      user(login: "%s") {
        projectV2(number: %d) {
          id
          title
          items(first: 100, after: $cursor) {
            pageInfo { hasNextPage endCursor }
            nodes {
              id
              content {
                __typename
                ... on Issue {
                  number url title state
                  labels(first: 30) { nodes { name } }
                }
                ... on PullRequest {
                  number url title state
                  labels(first: 30) { nodes { name } }
                }
              }
              fieldValues(first: 20) {
                nodes {
                  __typename
                  ... on ProjectV2ItemFieldDateValue {
                    field { ... on ProjectV2FieldCommon { name } }
                    date
                  }
                  ... on ProjectV2ItemFieldSingleSelectValue {
                    field { ... on ProjectV2FieldCommon { name } }
                    name
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
    project_title = ""
    cursor: str | None = None
    page = 0
    while True:
        page += 1
        resp = gh_graphql(query, token=token, variables={"cursor": cursor})
        pv2 = resp["data"]["user"]["projectV2"]
        if pv2 is None:
            print("::error::Project 4 not found", file=sys.stderr)
            break
        if not project_title:
            project_title = pv2.get("title", "TodoInsights")
        items_conn = pv2.get("items", {}) or {}
        nodes = items_conn.get("nodes") or []
        all_nodes.extend(nodes)
        page_info = items_conn.get("pageInfo") or {}
        if not page_info.get("hasNextPage"):
            break
        cursor = page_info.get("endCursor")
        if not cursor:
            break

    print(f"  Fetched {len(all_nodes)} items from {project_title}", file=sys.stderr)

    # フラット化
    items: list[dict] = []
    for node in all_nodes:
        content = node.get("content") or {}
        if not content:
            continue
        tname = content.get("__typename", "")
        if tname not in ("Issue", "PullRequest"):
            continue

        # Field values の抽出
        fv_nodes = (node.get("fieldValues") or {}).get("nodes") or []
        fv_map: dict[str, str] = {}
        for fv in fv_nodes:
            if not fv:
                continue
            field_name = ((fv.get("field") or {}) or {}).get("name")
            if not field_name:
                continue
            if fv.get("__typename") == "ProjectV2ItemFieldDateValue":
                fv_map[field_name] = fv.get("date") or ""
            elif fv.get("__typename") == "ProjectV2ItemFieldSingleSelectValue":
                fv_map[field_name] = fv.get("name") or ""

        labels = [l.get("name", "") for l in ((content.get("labels") or {}).get("nodes") or [])]

        items.append({
            "number": content.get("number"),
            "url": content.get("url"),
            "title": content.get("title", ""),
            "state": content.get("state", ""),
            "type": "PR" if tname == "PullRequest" else "Issue",
            "closed_date": fv_map.get("Closed date") or "",
            "org": fv_map.get("Org") or "none",
            "category": fv_map.get("Category") or "other",
            "labels": labels,
        })

    return items, project_title


# ----------------------------------------------------------------------------
# Aggregation
# ----------------------------------------------------------------------------

def compute_aggregates(items: list[dict], now_jst: date) -> dict:
    """HTML 描画に使う集計結果を dict で返す。"""
    # 有効 item のみ (Closed date セット済)
    valid = [i for i in items if i.get("closed_date")]
    total = len(valid)

    # 日付範囲
    all_dates = sorted({i["closed_date"] for i in valid})
    first_date = all_dates[0] if all_dates else now_jst.isoformat()
    last_date = all_dates[-1] if all_dates else now_jst.isoformat()

    # Daily counts (全期間)
    by_date: dict[str, int] = Counter(i["closed_date"] for i in valid)
    # Daily by type (直近 30 日)
    last30_start = now_jst - timedelta(days=29)
    daily30_labels: list[str] = []
    daily30_issue: list[int] = []
    daily30_pr: list[int] = []
    for i in range(30):
        d = (last30_start + timedelta(days=i)).isoformat()
        daily30_labels.append(d)
        daily30_issue.append(sum(1 for x in valid if x["closed_date"] == d and x["type"] == "Issue"))
        daily30_pr.append(sum(1 for x in valid if x["closed_date"] == d and x["type"] == "PR"))

    # Weekly counts (直近 12 週)
    # 週の起点は月曜 (ISO week start)
    weekly_labels: list[str] = []
    weekly_values: list[int] = []
    # 今週の月曜を起点にする
    today_weekday = now_jst.weekday()  # Mon=0
    this_monday = now_jst - timedelta(days=today_weekday)
    for wk in range(11, -1, -1):
        week_start = this_monday - timedelta(days=wk * 7)
        week_end = week_start + timedelta(days=7)
        count = sum(
            1 for x in valid
            if week_start.isoformat() <= x["closed_date"] < week_end.isoformat()
        )
        weekly_labels.append(week_start.isoformat())
        weekly_values.append(count)

    # Category breakdown
    by_category = Counter(i["category"] for i in valid)
    # Org breakdown
    by_org = Counter(i["org"] for i in valid)
    # Type breakdown
    by_type = Counter(i["type"] for i in valid)

    # Cumulative (全期間)
    cumulative_labels: list[str] = []
    cumulative_values: list[int] = []
    running = 0
    if all_dates:
        start = date.fromisoformat(all_dates[0])
        end = now_jst
        # 日付を連続生成
        d = start
        while d <= end:
            running += by_date.get(d.isoformat(), 0)
            cumulative_labels.append(d.isoformat())
            cumulative_values.append(running)
            d += timedelta(days=1)

    # 週次 / 今日 / 今週 / 先週 の比較
    today_iso = now_jst.isoformat()
    today_count = by_date.get(today_iso, 0)

    this_week_count = 0
    last_week_count = 0
    for x in valid:
        try:
            xd = date.fromisoformat(x["closed_date"])
        except ValueError:
            continue
        if this_monday <= xd < this_monday + timedelta(days=7):
            this_week_count += 1
        elif this_monday - timedelta(days=7) <= xd < this_monday:
            last_week_count += 1

    # 直近 30 日平均
    last30_total = sum(daily30_issue) + sum(daily30_pr)
    avg_30d = round(last30_total / 30, 1)

    # 前週比
    if last_week_count > 0:
        week_delta_pct = round((this_week_count - last_week_count) / last_week_count * 100, 1)
    elif this_week_count > 0:
        week_delta_pct = 100.0
    else:
        week_delta_pct = 0.0

    # 最新クローズ 20 件
    recent = sorted(valid, key=lambda i: i.get("closed_date", ""), reverse=True)[:20]

    return {
        "total": total,
        "today": today_count,
        "this_week": this_week_count,
        "last_week": last_week_count,
        "week_delta_pct": week_delta_pct,
        "avg_30d": avg_30d,
        "first_date": first_date,
        "last_date": last_date,
        "daily30": {
            "labels": daily30_labels,
            "issue": daily30_issue,
            "pr": daily30_pr,
        },
        "weekly": {
            "labels": weekly_labels,
            "values": weekly_values,
        },
        "category": dict(by_category.most_common()),
        "org": dict(by_org.most_common()),
        "type": dict(by_type),
        "cumulative": {
            "labels": cumulative_labels,
            "values": cumulative_values,
        },
        "recent": [
            {
                "number": r["number"],
                "title": r["title"],
                "url": r["url"],
                "type": r["type"],
                "org": r["org"],
                "category": r["category"],
                "closed_date": r["closed_date"],
            }
            for r in recent
        ],
    }


# ----------------------------------------------------------------------------
# HTML rendering
# ----------------------------------------------------------------------------

HTML_TEMPLATE = """<!DOCTYPE html>
<html lang="ja">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>TodoInsights — 活動インサイト</title>
<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js"></script>
<style>
:root {
  --bg: #f8f9fa; --card-bg: #fff; --text: #212529; --muted: #6c757d;
  --border: #dee2e6; --shadow: rgba(0,0,0,0.08);
  --blue: #0d6efd; --yellow: #ffc107; --red: #dc3545; --green: #198754;
  --purple: #6f42c1; --teal: #20c997; --orange: #fd7e14; --pink: #d63384;
  --accent: #4361ee; --chart-grid: rgba(0,0,0,0.06);
}
@media (prefers-color-scheme: dark) {
  :root {
    --bg: #1a1a2e; --card-bg: #16213e; --text: #e0e0e0; --muted: #9e9e9e;
    --border: #2a2a4a; --shadow: rgba(0,0,0,0.3);
    --blue: #4dabf7; --yellow: #ffd43b; --red: #ff6b6b; --green: #51cf66;
    --purple: #9775fa; --teal: #4ecdc4; --orange: #ff922b; --pink: #f783ac;
    --accent: #748ffc; --chart-grid: rgba(255,255,255,0.08);
  }
}
* { margin: 0; padding: 0; box-sizing: border-box; }
body {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Yu Gothic UI', sans-serif;
  background: var(--bg); color: var(--text);
  padding: 24px; max-width: 1400px; margin: 0 auto;
  line-height: 1.5;
}

.nav {
  display: flex; gap: 16px; margin-bottom: 16px;
  font-size: 0.85rem;
}
.nav a {
  color: var(--blue); text-decoration: none;
  padding: 4px 0; border-bottom: 1px solid transparent;
}
.nav a:hover { border-bottom-color: var(--blue); }

.hero {
  margin-bottom: 28px;
}
h1 {
  font-size: 1.8rem; margin-bottom: 4px;
  background: linear-gradient(135deg, var(--accent), var(--teal));
  -webkit-background-clip: text; background-clip: text;
  -webkit-text-fill-color: transparent;
}
.subtitle { color: var(--muted); font-size: 0.9rem; }

/* Summary cards */
.summary-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
  gap: 16px; margin-bottom: 28px;
}
.summary-card {
  background: var(--card-bg); border: 1px solid var(--border);
  border-radius: 14px; padding: 20px;
  box-shadow: 0 2px 12px var(--shadow);
  transition: transform 0.2s, box-shadow 0.2s;
}
.summary-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 6px 20px var(--shadow);
}
.summary-label {
  font-size: 0.75rem; color: var(--muted);
  text-transform: uppercase; letter-spacing: 0.8px;
  margin-bottom: 6px;
}
.summary-value {
  font-size: 2rem; font-weight: 700;
  display: flex; align-items: baseline; gap: 8px;
}
.summary-value.blue { color: var(--blue); }
.summary-value.green { color: var(--green); }
.summary-value.orange { color: var(--orange); }
.summary-value.purple { color: var(--purple); }
.summary-delta {
  font-size: 0.8rem; font-weight: 600;
  padding: 2px 8px; border-radius: 999px;
}
.summary-delta.up { background: rgba(25,135,84,0.12); color: var(--green); }
.summary-delta.down { background: rgba(220,53,69,0.12); color: var(--red); }
.summary-delta.flat { background: rgba(108,117,125,0.12); color: var(--muted); }

/* Charts */
.chart-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(420px, 1fr));
  gap: 20px; margin-bottom: 28px;
}
.chart-card {
  background: var(--card-bg); border: 1px solid var(--border);
  border-radius: 14px; padding: 20px;
  box-shadow: 0 2px 12px var(--shadow);
}
.chart-card.full { grid-column: 1 / -1; }
.chart-card h2 {
  font-size: 1rem; margin-bottom: 14px;
  display: flex; align-items: center; gap: 8px;
  color: var(--text);
}
.chart-card .accent-bar {
  width: 4px; height: 18px; border-radius: 2px;
  background: var(--accent);
}
.chart-container {
  position: relative;
  height: 280px;
}
.chart-card.full .chart-container { height: 320px; }

/* Recent table */
.recent-card {
  background: var(--card-bg); border: 1px solid var(--border);
  border-radius: 14px; padding: 20px; margin-bottom: 28px;
  box-shadow: 0 2px 12px var(--shadow);
}
.recent-card h2 {
  font-size: 1rem; margin-bottom: 14px;
  display: flex; align-items: center; gap: 8px;
}
.table-wrap { overflow-x: auto; }
.recent-table {
  width: 100%; border-collapse: collapse; font-size: 0.85rem;
}
.recent-table th {
  text-align: left; padding: 10px 12px;
  background: var(--border); font-weight: 600;
  position: sticky; top: 0;
}
.recent-table td {
  padding: 10px 12px; border-bottom: 1px solid var(--border);
  vertical-align: top;
}
.recent-table tr:hover td { background: rgba(67, 97, 238, 0.04); }
.recent-table a { color: var(--blue); text-decoration: none; }
.recent-table a:hover { text-decoration: underline; }

.badge {
  display: inline-block; font-size: 0.7rem; font-weight: 600;
  padding: 2px 8px; border-radius: 999px;
  text-transform: uppercase; letter-spacing: 0.4px;
}
.badge-issue { background: rgba(13,110,253,0.12); color: var(--blue); }
.badge-pr { background: rgba(111,66,193,0.12); color: var(--purple); }
.badge-wbs { background: rgba(25,135,84,0.12); color: var(--green); }
.badge-digest { background: rgba(253,126,20,0.12); color: var(--orange); }
.badge-automation { background: rgba(32,201,151,0.12); color: var(--teal); }
.badge-feat { background: rgba(13,110,253,0.12); color: var(--blue); }
.badge-fix { background: rgba(220,53,69,0.12); color: var(--red); }
.badge-docs { background: rgba(255,193,7,0.18); color: #a06800; }
.badge-chore { background: rgba(108,117,125,0.12); color: var(--muted); }
.badge-other { background: rgba(108,117,125,0.08); color: var(--muted); }
.badge-org { background: rgba(67,97,238,0.08); color: var(--accent); }

.footer {
  margin-top: 40px; text-align: center;
  font-size: 0.78rem; color: var(--muted);
}

/* Responsive */
@media (max-width: 720px) {
  body { padding: 16px; }
  h1 { font-size: 1.4rem; }
  .summary-value { font-size: 1.6rem; }
  .chart-grid { grid-template-columns: 1fr; }
  .summary-grid { grid-template-columns: repeat(2, 1fr); }
}
</style>
</head>
<body>

<div class="nav">
  <a href="../">← トップに戻る</a>
  <a href="https://github.com/users/SAS-Sasao/projects/4" target="_blank">Project 4 (TodoInsights) →</a>
</div>

<div class="hero">
  <h1>TodoInsights</h1>
  <p class="subtitle">cc-sier-organization の活動インサイト｜最終更新: __LAST_UPDATED__｜収集期間: __FIRST_DATE__ 〜 __LAST_DATE__</p>
</div>

<div class="summary-grid">
  <div class="summary-card">
    <div class="summary-label">累計クローズ</div>
    <div class="summary-value blue">__TOTAL__</div>
  </div>
  <div class="summary-card">
    <div class="summary-label">今週の完了</div>
    <div class="summary-value green">
      __THIS_WEEK__
      <span class="summary-delta __DELTA_CLASS__">__DELTA_LABEL__</span>
    </div>
  </div>
  <div class="summary-card">
    <div class="summary-label">本日の完了</div>
    <div class="summary-value orange">__TODAY__</div>
  </div>
  <div class="summary-card">
    <div class="summary-label">直近30日平均/日</div>
    <div class="summary-value purple">__AVG_30D__</div>
  </div>
</div>

<div class="chart-grid">
  <div class="chart-card full">
    <h2><span class="accent-bar"></span>直近 30 日の完了件数 (Issue / PR)</h2>
    <div class="chart-container"><canvas id="dailyChart"></canvas></div>
  </div>

  <div class="chart-card">
    <h2><span class="accent-bar"></span>週次トレンド (直近 12 週)</h2>
    <div class="chart-container"><canvas id="weeklyChart"></canvas></div>
  </div>

  <div class="chart-card">
    <h2><span class="accent-bar"></span>累計完了</h2>
    <div class="chart-container"><canvas id="cumulativeChart"></canvas></div>
  </div>

  <div class="chart-card">
    <h2><span class="accent-bar"></span>カテゴリ分布</h2>
    <div class="chart-container"><canvas id="categoryChart"></canvas></div>
  </div>

  <div class="chart-card">
    <h2><span class="accent-bar"></span>組織分布</h2>
    <div class="chart-container"><canvas id="orgChart"></canvas></div>
  </div>
</div>

<div class="recent-card">
  <h2><span class="accent-bar"></span>最新クローズ 20 件</h2>
  <div class="table-wrap">
    <table class="recent-table">
      <thead>
        <tr>
          <th>クローズ日</th>
          <th>Type</th>
          <th>タイトル</th>
          <th>組織</th>
          <th>カテゴリ</th>
        </tr>
      </thead>
      <tbody>
__RECENT_ROWS__
      </tbody>
    </table>
  </div>
</div>

<div class="footer">
  Generated by <code>generate-insights-html.py</code> ｜ Data source: GitHub Projects v2 #4 TodoInsights
</div>

<script>
const DATA = __DATA_JSON__;

// Chart.js 共通設定
const darkMode = window.matchMedia('(prefers-color-scheme: dark)').matches;
const textColor = darkMode ? '#e0e0e0' : '#212529';
const gridColor = darkMode ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.06)';
const mutedColor = darkMode ? '#9e9e9e' : '#6c757d';
Chart.defaults.color = mutedColor;
Chart.defaults.borderColor = gridColor;
Chart.defaults.font.family = "-apple-system, BlinkMacSystemFont, 'Segoe UI', 'Yu Gothic UI', sans-serif";

// Color palette
const C = {
  blue: darkMode ? '#4dabf7' : '#0d6efd',
  green: darkMode ? '#51cf66' : '#198754',
  red: darkMode ? '#ff6b6b' : '#dc3545',
  yellow: darkMode ? '#ffd43b' : '#ffc107',
  purple: darkMode ? '#9775fa' : '#6f42c1',
  teal: darkMode ? '#4ecdc4' : '#20c997',
  orange: darkMode ? '#ff922b' : '#fd7e14',
  pink: darkMode ? '#f783ac' : '#d63384',
  gray: mutedColor,
};

// 1. Daily chart (Issue + PR stack)
new Chart(document.getElementById('dailyChart'), {
  type: 'bar',
  data: {
    labels: DATA.daily30.labels.map(d => d.slice(5)),
    datasets: [
      {
        label: 'Issue',
        data: DATA.daily30.issue,
        backgroundColor: C.blue,
        borderRadius: 4,
      },
      {
        label: 'PR',
        data: DATA.daily30.pr,
        backgroundColor: C.purple,
        borderRadius: 4,
      }
    ]
  },
  options: {
    responsive: true,
    maintainAspectRatio: false,
    interaction: { mode: 'index', intersect: false },
    scales: {
      x: { stacked: true, grid: { display: false } },
      y: { stacked: true, beginAtZero: true, ticks: { precision: 0 }, grid: { color: gridColor } }
    },
    plugins: {
      legend: { position: 'top', labels: { usePointStyle: true, boxWidth: 10 } },
      tooltip: { mode: 'index', intersect: false }
    }
  }
});

// 2. Weekly trend (line)
new Chart(document.getElementById('weeklyChart'), {
  type: 'line',
  data: {
    labels: DATA.weekly.labels.map(d => d.slice(5)),
    datasets: [{
      label: '週次完了数',
      data: DATA.weekly.values,
      borderColor: C.teal,
      backgroundColor: 'transparent',
      tension: 0.35,
      pointRadius: 4,
      pointBackgroundColor: C.teal,
      pointBorderColor: darkMode ? '#16213e' : '#fff',
      pointBorderWidth: 2,
      fill: false,
    }]
  },
  options: {
    responsive: true,
    maintainAspectRatio: false,
    scales: {
      x: { grid: { display: false } },
      y: { beginAtZero: true, ticks: { precision: 0 }, grid: { color: gridColor } }
    },
    plugins: { legend: { display: false } }
  }
});

// 3. Cumulative (area)
new Chart(document.getElementById('cumulativeChart'), {
  type: 'line',
  data: {
    labels: DATA.cumulative.labels.map(d => d.slice(5)),
    datasets: [{
      label: '累計',
      data: DATA.cumulative.values,
      borderColor: C.blue,
      backgroundColor: darkMode ? 'rgba(77,171,247,0.15)' : 'rgba(13,110,253,0.12)',
      tension: 0.2,
      pointRadius: 0,
      fill: true,
    }]
  },
  options: {
    responsive: true,
    maintainAspectRatio: false,
    scales: {
      x: { grid: { display: false }, ticks: { maxTicksLimit: 10 } },
      y: { beginAtZero: true, grid: { color: gridColor } }
    },
    plugins: { legend: { display: false } }
  }
});

// 4. Category (doughnut)
const categoryColors = {
  'wbs': C.green,
  'digest': C.orange,
  'automation': C.teal,
  'feat': C.blue,
  'fix': C.red,
  'docs': C.yellow,
  'chore': C.gray,
  'other': C.pink,
};
const catLabels = Object.keys(DATA.category);
const catValues = Object.values(DATA.category);
const catBgs = catLabels.map(l => categoryColors[l] || C.gray);
new Chart(document.getElementById('categoryChart'), {
  type: 'doughnut',
  data: {
    labels: catLabels,
    datasets: [{
      data: catValues,
      backgroundColor: catBgs,
      borderColor: darkMode ? '#16213e' : '#fff',
      borderWidth: 2,
    }]
  },
  options: {
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
      legend: { position: 'right', labels: { usePointStyle: true, boxWidth: 10 } }
    }
  }
});

// 5. Org (horizontal bar)
const orgLabels = Object.keys(DATA.org);
const orgValues = Object.values(DATA.org);
const orgColors = [C.blue, C.purple, C.teal, C.gray];
new Chart(document.getElementById('orgChart'), {
  type: 'bar',
  data: {
    labels: orgLabels,
    datasets: [{
      label: '件数',
      data: orgValues,
      backgroundColor: orgLabels.map((_, i) => orgColors[i % orgColors.length]),
      borderRadius: 4,
    }]
  },
  options: {
    indexAxis: 'y',
    responsive: true,
    maintainAspectRatio: false,
    scales: {
      x: { beginAtZero: true, grid: { color: gridColor } },
      y: { grid: { display: false } }
    },
    plugins: { legend: { display: false } }
  }
});
</script>

</body>
</html>
"""


def render_html(items: list[dict], aggregates: dict, now_jst: datetime) -> str:
    """HTML を組み立てる。"""
    delta_pct = aggregates["week_delta_pct"]
    if delta_pct > 0:
        delta_class = "up"
        delta_label = f"▲ {delta_pct}%"
    elif delta_pct < 0:
        delta_class = "down"
        delta_label = f"▼ {abs(delta_pct)}%"
    else:
        delta_class = "flat"
        delta_label = "→ 0%"

    # Recent rows
    recent_rows_html: list[str] = []
    for r in aggregates["recent"]:
        type_badge = f'<span class="badge badge-{r["type"].lower()}">{r["type"]}</span>'
        cat_badge = f'<span class="badge badge-{r["category"]}">{r["category"]}</span>'
        org_badge = f'<span class="badge badge-org">{r["org"]}</span>'
        title_html = f'<a href="{r["url"]}" target="_blank" rel="noopener">#{r["number"]} {escape_html(r["title"])}</a>'
        recent_rows_html.append(
            f'        <tr>'
            f'<td>{r["closed_date"]}</td>'
            f'<td>{type_badge}</td>'
            f'<td>{title_html}</td>'
            f'<td>{org_badge}</td>'
            f'<td>{cat_badge}</td>'
            f'</tr>'
        )

    # Data JSON for charts
    data_for_js = {
        "daily30": aggregates["daily30"],
        "weekly": aggregates["weekly"],
        "cumulative": aggregates["cumulative"],
        "category": aggregates["category"],
        "org": aggregates["org"],
        "type": aggregates["type"],
    }
    data_json = json.dumps(data_for_js, ensure_ascii=False)

    html = HTML_TEMPLATE
    html = html.replace("__LAST_UPDATED__", now_jst.strftime("%Y-%m-%d %H:%M JST"))
    html = html.replace("__FIRST_DATE__", aggregates["first_date"])
    html = html.replace("__LAST_DATE__", aggregates["last_date"])
    html = html.replace("__TOTAL__", f"{aggregates['total']:,}")
    html = html.replace("__THIS_WEEK__", str(aggregates["this_week"]))
    html = html.replace("__TODAY__", str(aggregates["today"]))
    html = html.replace("__AVG_30D__", str(aggregates["avg_30d"]))
    html = html.replace("__DELTA_CLASS__", delta_class)
    html = html.replace("__DELTA_LABEL__", delta_label)
    html = html.replace("__RECENT_ROWS__", "\n".join(recent_rows_html))
    html = html.replace("__DATA_JSON__", data_json)
    return html


def escape_html(s: str) -> str:
    return (
        s.replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace('"', "&quot;")
    )


# ----------------------------------------------------------------------------
# Top page card update
# ----------------------------------------------------------------------------

def update_top_index(repo_root: Path) -> None:
    """docs/index.html に TodoInsights カードを追加 (既存なら置換)。"""
    index_path = repo_root / "docs" / "index.html"
    if not index_path.exists():
        print(f"  docs/index.html not found, skipping top page update", file=sys.stderr)
        return

    html = index_path.read_text(encoding="utf-8")

    # 既存の insights カードを削除
    html = re.sub(
        r'\s*<a href="\./insights/[^"]*"[^>]*class="card"[^>]*>.*?</a>',
        "",
        html,
        flags=re.DOTALL,
    )

    insights_card = '''
    <a href="./insights/index.html" class="card" style="border:2px solid #4361ee;">
      <div class="org-name">TodoInsights</div>
      <div class="org-label">活動インサイト・完了グラフ →</div>
    </a>'''

    html = re.sub(
        r'(</div>\s*<p class="updated")',
        f"{insights_card}\n\\1",
        html,
        count=1,
    )

    index_path.write_text(html, encoding="utf-8")
    print(f"  Updated: {index_path}", file=sys.stderr)


# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------

def main() -> int:
    token = os.environ.get("PROJECTS_PAT", "")
    if not token:
        print("::error::PROJECTS_PAT required", file=sys.stderr)
        return 1

    try:
        import zoneinfo
        tz_jst = zoneinfo.ZoneInfo("Asia/Tokyo")
    except Exception:
        tz_jst = timezone(timedelta(hours=9))

    now_jst = datetime.now(tz_jst)

    print("=== Generate TodoInsights HTML ===")
    print(f"JST: {now_jst.isoformat()}")
    print()

    # Step 1: Fetch project items
    print("Step 1: Fetch Project 4 items")
    items, project_title = fetch_all_items(token)
    print(f"  {len(items)} items")
    print()

    # Step 2: Aggregate
    print("Step 2: Compute aggregates")
    aggregates = compute_aggregates(items, now_jst.date())
    print(f"  total: {aggregates['total']}")
    print(f"  today: {aggregates['today']}")
    print(f"  this_week: {aggregates['this_week']} (last week: {aggregates['last_week']}, delta: {aggregates['week_delta_pct']}%)")
    print(f"  avg_30d: {aggregates['avg_30d']}")
    print(f"  category breakdown: {aggregates['category']}")
    print(f"  org breakdown: {aggregates['org']}")
    print()

    # Step 3: Render HTML
    print("Step 3: Render HTML")
    html = render_html(items, aggregates, now_jst)

    output_dir = REPO_ROOT / "docs" / "insights"
    output_dir.mkdir(parents=True, exist_ok=True)
    output_path = output_dir / "index.html"
    output_path.write_text(html, encoding="utf-8")
    size_kb = round(output_path.stat().st_size / 1024, 1)
    print(f"  Written: {output_path} ({size_kb} KB)")

    # Step 4: Update top page
    print("Step 4: Update docs/index.html")
    update_top_index(REPO_ROOT)
    print()

    print("Done.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
