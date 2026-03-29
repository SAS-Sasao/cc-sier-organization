#!/usr/bin/env bash
# generate-handover-html.sh — ナレッジポータルHTML生成
set -uo pipefail

ORG_SLUG="${1:-}"
if [[ -z "$ORG_SLUG" ]]; then
  [[ -f ".companies/.active" ]] || { echo "No active org" >&2; exit 1; }
  ORG_SLUG=$(tr -d '[:space:]' < ".companies/.active")
fi

DATA_JSON="docs/handover/data.json"
[[ -f "$DATA_JSON" ]] || { echo "data.json not found. Run generate-handover-data.sh first." >&2; exit 1; }

OUTPUT_DIR="docs/handover"
mkdir -p "$OUTPUT_DIR"
OUTPUT="${OUTPUT_DIR}/index.html"

echo "Generating handover HTML for ${ORG_SLUG}..."

python3 - "$DATA_JSON" "$ORG_SLUG" "$OUTPUT" <<'PYEOF'
import sys, json
from pathlib import Path
from datetime import datetime

data_path = Path(sys.argv[1])
org_slug = sys.argv[2]
output_path = Path(sys.argv[3])
now = datetime.now().strftime("%Y-%m-%d %H:%M")

data = json.loads(data_path.read_text(encoding="utf-8", errors="ignore"))
summary = data.get("summary", {})
entries = data.get("entries", [])
decisions_data = data.get("decisions", [])
tips_data = data.get("tips", [])
by_cat = summary.get("by_category", {})

# Collect months for filter
months = sorted(set(e["date"][:7] for e in entries if e.get("date") and len(e["date"]) >= 7), reverse=True)

# Category labels and colors
cat_config = {
    "project": {"label": "PJ業務", "color": "#3b82f6", "icon": "briefcase"},
    "platform": {"label": "基盤構築", "color": "#8b5cf6", "icon": "wrench"},
    "organization": {"label": "組織管理", "color": "#f59e0b", "icon": "building"},
    "learning": {"label": "品質・学習", "color": "#10b981", "icon": "graduation-cap"},
    "discussion": {"label": "壁打ち", "color": "#6b7280", "icon": "comments"},
}

# Build entries JSON for embedding (inline, no external fetch needed)
entries_json = json.dumps(entries, ensure_ascii=False)
decisions_json = json.dumps(decisions_data, ensure_ascii=False)
tips_json = json.dumps(tips_data, ensure_ascii=False)

# Build month options
month_options = "\n".join(f'<option value="{m}">{m}</option>' for m in months)

# Stats cards
total = summary.get("total_entries", 0)
cat_cards = ""
for cat_id, cfg in cat_config.items():
    count = by_cat.get(cat_id, 0)
    cat_cards += f'''<div class="stat-card" style="border-left:4px solid {cfg['color']}">
<div class="stat-num">{count}</div>
<div class="stat-label">{cfg['label']}</div>
</div>
'''

html = f'''<!DOCTYPE html>
<html lang="ja">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Knowledge Portal - {org_slug}</title>
<style>
:root {{
  --bg: #f8f9fa; --bg2: #fff; --bg3: #e9ecef;
  --text: #1a1a2e; --text2: #6c757d; --text3: #adb5bd;
  --accent: #4361ee; --border: rgba(0,0,0,.08);
  --project: #3b82f6; --platform: #8b5cf6; --organization: #f59e0b;
  --learning: #10b981; --discussion: #6b7280;
}}
@media (prefers-color-scheme: dark) {{
  :root {{
    --bg: #0d1117; --bg2: #161b22; --bg3: #21262d;
    --text: #e6edf3; --text2: #8b949e; --text3: #484f58;
    --accent: #58a6ff; --border: rgba(255,255,255,.08);
  }}
}}
* {{ margin:0; padding:0; box-sizing:border-box; }}
body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: var(--bg); color: var(--text); min-height:100vh; }}
.back-btn {{ display:inline-block; color:var(--accent); text-decoration:none; font-size:.88rem; margin:16px 0 0 24px; }}
.back-btn:hover {{ text-decoration:underline; }}
.header {{ background: var(--bg2); border-bottom: 1px solid var(--border); padding: 20px 24px; }}
.header h1 {{ font-size: 1.4rem; font-weight: 600; }}
.header .subtitle {{ color: var(--text2); font-size: 0.85rem; margin-top: 4px; }}
.controls {{ display:flex; gap:12px; align-items:center; flex-wrap:wrap; padding:16px 24px; background:var(--bg2); border-bottom:1px solid var(--border); }}
.search-box {{ flex:1; min-width:200px; padding:8px 12px; border-radius:6px; border:1px solid var(--border); background:var(--bg3); color:var(--text); font-size:0.9rem; }}
.search-box:focus {{ outline:none; border-color:var(--accent); }}
select {{ padding:8px 12px; border-radius:6px; border:1px solid var(--border); background:var(--bg3); color:var(--text); font-size:0.9rem; cursor:pointer; }}
.stats {{ display:flex; gap:12px; padding:16px 24px; flex-wrap:wrap; }}
.stat-card {{ background:var(--bg2); border:1px solid var(--border); border-radius:8px; padding:12px 16px; min-width:120px; }}
.stat-num {{ font-size:1.5rem; font-weight:700; }}
.stat-label {{ font-size:0.8rem; color:var(--text2); margin-top:2px; }}
.tabs {{ display:flex; gap:0; padding:0 24px; background:var(--bg2); border-bottom:1px solid var(--border); overflow-x:auto; }}
.tab {{ padding:12px 20px; cursor:pointer; font-size:0.9rem; color:var(--text2); border-bottom:2px solid transparent; white-space:nowrap; transition:all 0.2s; }}
.tab:hover {{ color:var(--text); background:var(--bg3); }}
.tab.active {{ color:var(--accent); border-bottom-color:var(--accent); }}
.content {{ padding:24px; max-width:1200px; margin:0 auto; }}
.entry {{ background:var(--bg2); border:1px solid var(--border); border-radius:8px; padding:16px; margin-bottom:12px; border-left:4px solid var(--border); transition:transform 0.1s; cursor:pointer; }}
.entry:hover {{ transform:translateX(4px); }}
.entry-toggle {{ font-size:0.75rem; color:var(--text3); margin-left:8px; transition:transform 0.2s; display:inline-block; }}
.entry.open .entry-toggle {{ transform:rotate(90deg); }}
.entry-detail {{ display:none; margin-top:12px; padding:12px; background:var(--bg); border-radius:6px; border:1px solid var(--border); font-size:0.82rem; color:var(--text2); line-height:1.7; white-space:pre-wrap; word-break:break-word; max-height:400px; overflow-y:auto; }}
.entry.open .entry-detail {{ display:block; }}
.entry[data-cat="project"] {{ border-left-color:var(--project); }}
.entry[data-cat="platform"] {{ border-left-color:var(--platform); }}
.entry[data-cat="organization"] {{ border-left-color:var(--organization); }}
.entry[data-cat="learning"] {{ border-left-color:var(--learning); }}
.entry[data-cat="discussion"] {{ border-left-color:var(--discussion); }}
.entry-header {{ display:flex; justify-content:space-between; align-items:flex-start; gap:12px; }}
.entry-title {{ font-size:0.95rem; font-weight:500; flex:1; }}
.entry-date {{ font-size:0.8rem; color:var(--text3); white-space:nowrap; }}
.entry-meta {{ display:flex; gap:8px; margin-top:8px; flex-wrap:wrap; }}
.badge {{ font-size:0.7rem; padding:2px 8px; border-radius:10px; background:var(--bg3); color:var(--text2); }}
.badge.source {{ background:#e0e7ff; color:#3730a3; }}
@media (prefers-color-scheme: dark) {{
  .badge.source {{ background:#1e3a5f; color:#60a5fa; }}
}}
.badge.cat {{ color:#fff; font-weight:500; }}
.badge.cat-project {{ background:var(--project); }}
.badge.cat-platform {{ background:var(--platform); }}
.badge.cat-organization {{ background:var(--organization); }}
.badge.cat-learning {{ background:var(--learning); }}
.badge.cat-discussion {{ background:var(--discussion); }}
.entry-files {{ margin-top:8px; font-size:0.8rem; color:var(--text3); }}
.entry-files code {{ background:var(--bg3); padding:1px 4px; border-radius:3px; font-size:0.75rem; }}
.decision {{ background:var(--bg2); border:1px solid var(--border); border-radius:8px; padding:16px; margin-bottom:12px; border-left:4px solid #f59e0b; }}
.decision-title {{ font-weight:600; font-size:0.95rem; }}
.decision-rule {{ margin-top:8px; font-size:0.85rem; color:var(--text); line-height:1.6; white-space:pre-wrap; }}
.decision-reason {{ margin-top:8px; font-size:0.8rem; color:var(--text2); font-style:italic; }}
.decision-source {{ margin-top:6px; font-size:0.75rem; color:var(--text3); }}
.tip {{ background:var(--bg2); border:1px solid var(--border); border-radius:8px; padding:16px; margin-bottom:12px; border-left:4px solid var(--learning); }}
.tip-title {{ font-weight:600; font-size:0.95rem; }}
.tip-content {{ margin-top:8px; font-size:0.85rem; color:var(--text); line-height:1.6; }}
.tip-meta {{ display:flex; gap:8px; margin-top:8px; }}
.reward-badge {{ font-size:0.75rem; padding:2px 8px; border-radius:10px; background:#d1fae5; color:#065f46; font-weight:600; }}
@media (prefers-color-scheme: dark) {{
  .reward-badge {{ background:#065f46; color:#6ee7b7; }}
}}
.month-group {{ margin-top:24px; }}
.month-label {{ font-size:1.1rem; font-weight:600; color:var(--accent); margin-bottom:12px; padding-bottom:8px; border-bottom:1px solid var(--border); }}
.empty {{ text-align:center; color:var(--text3); padding:60px 24px; font-size:0.95rem; }}
table {{ width:100%; border-collapse:collapse; margin-top:12px; }}
th {{ text-align:left; padding:10px 12px; background:var(--bg3); color:var(--text2); font-size:0.8rem; font-weight:600; border-bottom:1px solid var(--border); }}
td {{ padding:10px 12px; border-bottom:1px solid var(--border); font-size:0.85rem; }}
tr:hover {{ background:var(--bg3); }}
.footer {{ text-align:center; padding:24px; color:var(--text3); font-size:0.75rem; border-top:1px solid var(--border); margin-top:40px; }}
</style>
</head>
<body>

<a href="../" class="back-btn">&larr; トップに戻る</a>
<div class="header">
  <h1>Knowledge Portal</h1>
  <div class="subtitle">{org_slug} | Generated: {now} | {total} entries</div>
</div>

<div class="stats">
  <div class="stat-card" style="border-left:4px solid var(--accent)">
    <div class="stat-num">{total}</div>
    <div class="stat-label">Total</div>
  </div>
  {cat_cards}
</div>

<div class="controls">
  <input type="text" class="search-box" id="searchBox" placeholder="Search keywords...">
  <select id="catFilter">
    <option value="all">All Categories</option>
    <option value="project">PJ業務</option>
    <option value="platform">基盤構築</option>
    <option value="organization">組織管理</option>
    <option value="learning">品質・学習</option>
    <option value="discussion">壁打ち</option>
  </select>
  <select id="monthFilter">
    <option value="all">All Months</option>
    {month_options}
  </select>
</div>

<div class="tabs">
  <div class="tab active" data-tab="timeline">全体年表</div>
  <div class="tab" data-tab="project">PJ業務</div>
  <div class="tab" data-tab="platform">基盤構築</div>
  <div class="tab" data-tab="decisions">判断履歴</div>
  <div class="tab" data-tab="tips">Tips</div>
</div>

<div class="content" id="content">
</div>

<div class="footer">
  Generated by /company-handover | cc-sier-organization | Auto-refresh: 5min
</div>

<script>
const ENTRIES = {entries_json};
const DECISIONS = {decisions_json};
const TIPS = {tips_json};

const CAT_LABELS = {{
  project: "PJ業務", platform: "基盤構築", organization: "組織管理",
  learning: "品質・学習", discussion: "壁打ち"
}};

const SOURCE_LABELS = {{
  "git-log": "Git", "task-log": "TaskLog", "conversation-log": "ConvLog",
  "case-bank": "CaseBank", "session-summary": "Session",
  "github-issue": "Issue", "github-pr": "PR", "feedback_memory": "Memory"
}};

let currentTab = "timeline";
let searchQuery = "";
let catFilter = "all";
let monthFilter = "all";

function filterEntries() {{
  let filtered = ENTRIES;
  if (currentTab !== "timeline" && currentTab !== "decisions" && currentTab !== "tips") {{
    filtered = filtered.filter(e => e.category === currentTab);
  }}
  if (catFilter !== "all" && currentTab === "timeline") {{
    filtered = filtered.filter(e => e.category === catFilter);
  }}
  if (monthFilter !== "all") {{
    filtered = filtered.filter(e => e.date && e.date.startsWith(monthFilter));
  }}
  if (searchQuery) {{
    const q = searchQuery.toLowerCase();
    filtered = filtered.filter(e =>
      (e.title || "").toLowerCase().includes(q) ||
      (e.description || "").toLowerCase().includes(q) ||
      (e.tags || []).some(t => t.toLowerCase().includes(q)) ||
      (e.related_files || []).some(f => f.toLowerCase().includes(q))
    );
  }}
  return filtered;
}}

function renderEntry(e) {{
  const catClass = "cat-" + (e.category || "project");
  const sourceLabel = SOURCE_LABELS[e.source] || e.source;
  let files = "";
  if (e.related_files && e.related_files.length > 0) {{
    const fileList = e.related_files.slice(0, 3).map(f => "<code>" + escHtml(f) + "</code>").join(" ");
    files = '<div class="entry-files">' + fileList + '</div>';
  }}
  let metaBadges = '<span class="badge cat ' + catClass + '">' + (CAT_LABELS[e.category] || e.category) + '</span>';
  metaBadges += '<span class="badge source">' + escHtml(sourceLabel) + '</span>';
  if (e.metadata) {{
    if (e.metadata.subagent) metaBadges += '<span class="badge">' + escHtml(e.metadata.subagent) + '</span>';
    if (e.metadata.reward != null) metaBadges += '<span class="badge" style="background:#d1fae5;color:#065f46">reward: ' + e.metadata.reward.toFixed(2) + '</span>';
    if (e.metadata.commit_type) metaBadges += '<span class="badge">' + escHtml(e.metadata.commit_type) + '</span>';
  }}
  const hasDetail = e.description && e.description.trim().length > 0;
  const toggleIcon = hasDetail ? '<span class="entry-toggle">&#9654;</span> ' : '';
  const detailDiv = hasDetail ? '<div class="entry-detail">' + escHtml(e.description) + '</div>' : '';
  const expandClass = hasDetail ? ' expandable' : '';
  return '<div class="entry' + expandClass + '" data-cat="' + (e.category || "") + '">' +
    '<div class="entry-header">' +
      '<div class="entry-title">' + toggleIcon + escHtml(e.title || "") + '</div>' +
      '<div class="entry-date">' + escHtml(e.date || "") + '</div>' +
    '</div>' +
    '<div class="entry-meta">' + metaBadges + '</div>' +
    files +
    detailDiv +
  '</div>';
}}

function renderTimeline(filtered) {{
  if (filtered.length === 0) return '<div class="empty">No entries found</div>';
  const grouped = {{}};
  filtered.forEach(e => {{
    const m = (e.date || "").substring(0, 7) || "unknown";
    if (!grouped[m]) grouped[m] = [];
    grouped[m].push(e);
  }});
  const months = Object.keys(grouped).sort().reverse();
  return months.map(m =>
    '<div class="month-group">' +
      '<div class="month-label">' + escHtml(m) + ' (' + grouped[m].length + ')</div>' +
      grouped[m].map(renderEntry).join("") +
    '</div>'
  ).join("");
}}

function renderPlatformTable(filtered) {{
  if (filtered.length === 0) return '<div class="empty">No platform entries found</div>';
  const subCats = {{}};
  filtered.forEach(e => {{
    const sc = (e.subcategory || "other");
    if (!subCats[sc]) subCats[sc] = [];
    subCats[sc].push(e);
  }});
  const scLabels = {{ skill: "Skill", mcp: "MCP", hook: "Hook", agent: "Agent", config: "Config", other: "Other" }};
  let html = "";
  for (const [sc, items] of Object.entries(subCats).sort()) {{
    html += '<h3 style="margin:24px 0 8px;color:var(--platform)">' + (scLabels[sc] || sc) + ' (' + items.length + ')</h3>';
    html += '<table><thead><tr><th>Date</th><th>Title</th><th>Source</th></tr></thead><tbody>';
    items.forEach(e => {{
      html += '<tr><td>' + escHtml(e.date || "") + '</td><td>' + escHtml(e.title || "") + '</td><td>' + escHtml(SOURCE_LABELS[e.source] || e.source) + '</td></tr>';
    }});
    html += '</tbody></table>';
  }}
  return html;
}}

function renderDecisions() {{
  let filtered = DECISIONS;
  if (searchQuery) {{
    const q = searchQuery.toLowerCase();
    filtered = filtered.filter(d =>
      (d.title || "").toLowerCase().includes(q) ||
      (d.rule || "").toLowerCase().includes(q) ||
      (d.reason || "").toLowerCase().includes(q)
    );
  }}
  if (filtered.length === 0) return '<div class="empty">No decisions found</div>';
  return filtered.map(d =>
    '<div class="decision">' +
      '<div class="decision-title">' + escHtml(d.title || "") + '</div>' +
      '<div class="decision-rule">' + escHtml(d.rule || "") + '</div>' +
      (d.reason ? '<div class="decision-reason">Reason: ' + escHtml(d.reason) + '</div>' : '') +
      '<div class="decision-source">Source: ' + escHtml(d.source || "") + ' / ' + escHtml(d.source_ref || "") + '</div>' +
    '</div>'
  ).join("");
}}

function renderTips() {{
  let filtered = TIPS;
  if (searchQuery) {{
    const q = searchQuery.toLowerCase();
    filtered = filtered.filter(t =>
      (t.title || "").toLowerCase().includes(q) ||
      (t.content || "").toLowerCase().includes(q)
    );
  }}
  if (filtered.length === 0) return '<div class="empty">No tips found</div>';
  return filtered.map(t =>
    '<div class="tip">' +
      '<div class="tip-title">' + escHtml(t.title || "") + '</div>' +
      '<div class="tip-content">' + escHtml(t.content || "") + '</div>' +
      '<div class="tip-meta">' +
        (t.reward != null ? '<span class="reward-badge">reward: ' + t.reward.toFixed(2) + '</span>' : '') +
        (t.subagent ? '<span class="badge">' + escHtml(t.subagent) + '</span>' : '') +
        '<span class="badge source">' + escHtml(t.source || "") + '</span>' +
      '</div>' +
    '</div>'
  ).join("");
}}

function render() {{
  const content = document.getElementById("content");
  if (currentTab === "decisions") {{
    content.innerHTML = renderDecisions();
  }} else if (currentTab === "tips") {{
    content.innerHTML = renderTips();
  }} else if (currentTab === "platform") {{
    content.innerHTML = renderPlatformTable(filterEntries());
  }} else {{
    content.innerHTML = renderTimeline(filterEntries());
  }}
}}

function escHtml(s) {{
  const d = document.createElement("div");
  d.textContent = s;
  return d.innerHTML;
}}

// Event listeners
document.querySelectorAll(".tab").forEach(tab => {{
  tab.addEventListener("click", () => {{
    document.querySelectorAll(".tab").forEach(t => t.classList.remove("active"));
    tab.classList.add("active");
    currentTab = tab.dataset.tab;
    window.location.hash = currentTab;
    render();
  }});
}});

document.getElementById("searchBox").addEventListener("input", (e) => {{
  searchQuery = e.target.value;
  render();
}});

document.getElementById("catFilter").addEventListener("change", (e) => {{
  catFilter = e.target.value;
  render();
}});

document.getElementById("monthFilter").addEventListener("change", (e) => {{
  monthFilter = e.target.value;
  render();
}});

// Hash routing
function applyHash() {{
  const hash = window.location.hash.replace("#", "");
  if (hash && ["timeline","project","platform","decisions","tips"].includes(hash)) {{
    currentTab = hash;
    document.querySelectorAll(".tab").forEach(t => {{
      t.classList.toggle("active", t.dataset.tab === currentTab);
    }});
    render();
  }}
}}
window.addEventListener("hashchange", applyHash);

// Entry click-to-expand delegation
document.getElementById("content").addEventListener("click", (ev) => {{
  const entry = ev.target.closest(".entry.expandable");
  if (entry) entry.classList.toggle("open");
}});

// Auto-refresh every 5 minutes
setTimeout(() => location.reload(), 5 * 60 * 1000);

// Initial render
applyHash();
if (!window.location.hash) render();
</script>
</body>
</html>'''

output_path.parent.mkdir(parents=True, exist_ok=True)
output_path.write_text(html, encoding="utf-8")

size_kb = len(html.encode("utf-8")) / 1024
print(f"Generated {output_path}: {size_kb:.1f} KB")
PYEOF

echo "Done: ${OUTPUT}"
