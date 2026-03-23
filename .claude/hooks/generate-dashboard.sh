#!/usr/bin/env bash
# generate-dashboard.sh — 組織ダッシュボードHTML生成
set -uo pipefail

ORG_SLUG="${1:-}"
if [[ -z "$ORG_SLUG" ]]; then
  [[ -f ".companies/.active" ]] || { echo "No active org" >&2; exit 1; }
  ORG_SLUG=$(tr -d '[:space:]' < ".companies/.active")
fi

ORG_DIR=".companies/${ORG_SLUG}"
[[ -d "$ORG_DIR" ]] || { echo "Org not found: ${ORG_SLUG}" >&2; exit 1; }

OUTPUT_DIR="${ORG_DIR}/docs/secretary"
mkdir -p "$OUTPUT_DIR"
OUTPUT="${OUTPUT_DIR}/dashboard.html"

python3 - "$ORG_DIR" "$ORG_SLUG" "$OUTPUT" <<'PYEOF'
import sys, json, re, glob, os
from pathlib import Path
from datetime import datetime

org_dir = Path(sys.argv[1])
org_slug = sys.argv[2]
output = Path(sys.argv[3])
now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

# --- Data collection ---

# 1. Board stats
board_path = org_dir / "docs" / "secretary" / "board.md"
board = {"todo": 0, "in_progress": 0, "review": 0, "done": 0}
if board_path.exists():
    text = board_path.read_text(encoding="utf-8", errors="ignore")
    sections = re.split(r'^## ', text, flags=re.MULTILINE)
    for sec in sections:
        rows = [l for l in sec.splitlines() if l.startswith('|') and not l.startswith('|--') and '—' not in l.split('|')[1:3]]
        count = len([r for r in rows if r.strip() and not r.startswith('| タスクID')])
        if '🔵' in sec: board["todo"] = count
        elif '🟡' in sec: board["in_progress"] = count
        elif '🔴' in sec: board["review"] = count
        elif '✅' in sec: board["done"] = count

# 2. Quality gate pass rate
qg_dir = org_dir / ".quality-gate-log"
qg_pass, qg_fail = 0, 0
if qg_dir.exists():
    for f in sorted(qg_dir.glob("*.jsonl")):
        for line in f.read_text(encoding="utf-8", errors="ignore").splitlines():
            try:
                d = json.loads(line)
                if d.get("status") == "pass": qg_pass += 1
                elif d.get("status") == "fail": qg_fail += 1
            except: pass
qg_total = qg_pass + qg_fail
qg_rate = round(qg_pass / qg_total * 100) if qg_total > 0 else 100

# 3. Subagent usage — Case Bank (primary) + task-log (fallback)
agent_counts = {}

# Primary: Case Bank action.subagent
cb_agent_path = org_dir / ".case-bank" / "index.json"
if cb_agent_path.exists():
    try:
        cb_agent_data = json.loads(cb_agent_path.read_text(encoding="utf-8", errors="ignore"))
        for c in cb_agent_data.get("cases", []):
            agent_str = c.get("action", {}).get("subagent", "")
            if agent_str:
                for name in agent_str.split(","):
                    name = name.strip()
                    if name:
                        agent_counts[name] = agent_counts.get(name, 0) + 1
    except: pass

# Fallback: task-log free text (if Case Bank is empty)
if not agent_counts:
    tl_dir = org_dir / ".task-log"
    if tl_dir.exists():
        for f in tl_dir.glob("*.md"):
            text = f.read_text(encoding="utf-8", errors="ignore")
            for m in re.findall(r'(?:subagent|agent|担当)[：:]\s*(\S+)', text, re.IGNORECASE):
                agent_counts[m] = agent_counts.get(m, 0) + 1

# Also check session summaries (JSON files)
ss_dir = org_dir / ".session-summaries"
session_count = 0
total_tools = 0
if ss_dir.exists():
    for f in ss_dir.glob("*.json"):
        try:
            sd = json.loads(f.read_text(encoding="utf-8", errors="ignore"))
            session_count += 1
            total_tools += sd.get("tool_count", 0)
        except: pass

# Sort by count descending
agent_labels = list(agent_counts.keys())[:10]
agent_values = [agent_counts[k] for k in agent_labels]

# 4. Score trend from case-bank
cb_path = org_dir / ".case-bank" / "index.json"
score_dates, score_values = [], []
if cb_path.exists():
    try:
        cb_data = json.loads(cb_path.read_text(encoding="utf-8", errors="ignore"))
        cases_list = cb_data.get("cases", []) if isinstance(cb_data, dict) else cb_data
        for c in cases_list[-30:]:
            d = c.get("outcome", {}).get("started", "")[:10]
            s = c.get("reward")
            if d and isinstance(s, (int, float)):
                score_dates.append(d)
                score_values.append(s)
    except: pass

# 5. Conversation log stats
conv_dir = org_dir / ".conversation-log"
conv_sessions = 0
conv_human_total = 0
conv_topics = []
if conv_dir.exists():
    for f in sorted(conv_dir.glob("*.md")):
        try:
            text = f.read_text(encoding="utf-8", errors="ignore")
            conv_sessions += 1
            human_sections = re.findall(r'## 👤 Human\n\n(.*?)(?=\n---|\Z)', text, re.DOTALL)
            conv_human_total += len(human_sections)
            for sec in human_sections[:3]:
                first_line = sec.strip().split('\n')[0][:60]
                if len(first_line) > 10 and not first_line.startswith('```'):
                    conv_topics.append(first_line)
        except: pass

# Build conversation topics HTML
conv_topics_html = ""
if conv_topics:
    items = "".join(f"<li>{t}</li>" for t in conv_topics[-10:])
    conv_topics_html = f'<div class="conv-topics"><h3>最近の会話トピック</h3><ul>{items}</ul></div>'

# ================================================================
# 6. TODO progress — docs/secretary/todos/*.md or docs/**/todos/*.md
# ================================================================
todo_checked = 0
todo_unchecked = 0
todo_items_upcoming = []  # unchecked items (first 5)
todo_source = ""

# Search for todo files in any dept's todos/ directory
todo_dirs = list(org_dir.glob("docs/**/todos"))
for td in todo_dirs:
    for tf in sorted(td.glob("*.md"), reverse=True):
        text = tf.read_text(encoding="utf-8", errors="ignore")
        checked = re.findall(r'^- \[x\]', text, re.MULTILINE)
        unchecked = re.findall(r'^- \[ \]', text, re.MULTILINE)
        todo_checked += len(checked)
        todo_unchecked += len(unchecked)
        if not todo_source:
            todo_source = str(tf.relative_to(org_dir))
        # Extract unchecked items text (first 5 across all files)
        if len(todo_items_upcoming) < 5:
            for m in re.finditer(r'^- \[ \] (.+)$', text, re.MULTILINE):
                item_text = m.group(1).strip()[:80]
                if item_text and len(todo_items_upcoming) < 5:
                    todo_items_upcoming.append(item_text)

todo_total = todo_checked + todo_unchecked
todo_pct = round(todo_checked / todo_total * 100) if todo_total > 0 else 0

# ================================================================
# 7. WBS milestones — docs/secretary/*wbs*.md or docs/**/*wbs*.md
# ================================================================
milestones = []  # [{name, target_date, status}]
wbs_checked = 0
wbs_in_progress = 0
wbs_unchecked = 0
wbs_source = ""

wbs_files = list(org_dir.glob("docs/**/*wbs*.md")) + list(org_dir.glob("docs/**/*schedule*.md"))
# Deduplicate
wbs_files = list(dict.fromkeys(wbs_files))

for wf in wbs_files[:3]:  # max 3 files
    text = wf.read_text(encoding="utf-8", errors="ignore")
    if not wbs_source:
        wbs_source = str(wf.relative_to(org_dir))

    # Parse milestone table: | M{n} | name | date | criteria |
    for m in re.finditer(
        r'\|\s*M(\d+)\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*([^|]*?)\s*\|',
        text
    ):
        ms_num = m.group(1)
        ms_name = m.group(2).strip()
        ms_date = m.group(3).strip()
        if ms_name and not ms_name.startswith('マイルストーン') and not ms_name.startswith('---'):
            milestones.append({
                "num": ms_num,
                "name": ms_name,
                "date": ms_date,
            })

    # Count WBS task statuses
    wbs_checked += len(re.findall(r'\[x\]', text))
    wbs_in_progress += len(re.findall(r'\[~\]', text))
    wbs_unchecked += len(re.findall(r'\[ \]', text))

wbs_total = wbs_checked + wbs_in_progress + wbs_unchecked
wbs_pct = round(wbs_checked / wbs_total * 100) if wbs_total > 0 else 0

# ================================================================
# 8. Next Actions — aggregate from TODO + WBS + open Issues
# ================================================================
next_actions = []

# From unchecked TODOs
for item in todo_items_upcoming[:3]:
    next_actions.append({"source": "TODO", "text": item})

# From WBS: in-progress items
for wf in wbs_files[:1]:
    text = wf.read_text(encoding="utf-8", errors="ignore")
    for m in re.finditer(r'\[~\]\s*(.+?)(?:\s*\||\s*$)', text, re.MULTILINE):
        t = m.group(1).strip().rstrip('|').strip()
        if t and len(next_actions) < 8:
            next_actions.append({"source": "WBS", "text": t[:60]})

# Build HTML fragments
# --- TODO card ---
todo_html = ""
if todo_total > 0:
    items_html = "".join(
        f'<li><span class="check-box">&#9744;</span> {i}</li>'
        for i in todo_items_upcoming
    )
    todo_html = f'''<div class="plan-card">
  <h3>TODO 進捗</h3>
  <div class="progress-row">
    <div class="progress-bar"><div class="progress-fill" style="width:{todo_pct}%"></div></div>
    <span class="progress-text">{todo_checked}/{todo_total} ({todo_pct}%)</span>
  </div>
  <ul class="action-list">{items_html}</ul>
  <div class="source-hint">{todo_source}</div>
</div>'''

# --- WBS / Milestone card ---
wbs_html = ""
if milestones or wbs_total > 0:
    ms_items = ""
    today_str = datetime.now().strftime("%m/%d")
    for ms in milestones:
        ms_items += f'<div class="ms-item"><span class="ms-badge">M{ms["num"]}</span><span class="ms-name">{ms["name"]}</span><span class="ms-date">{ms["date"]}</span></div>'

    wbs_progress = ""
    if wbs_total > 0:
        wbs_progress = f'''<div class="progress-row">
    <div class="progress-bar"><div class="progress-fill green" style="width:{wbs_pct}%"></div></div>
    <span class="progress-text">完了{wbs_checked} / 進行中{wbs_in_progress} / 未着手{wbs_unchecked}</span>
  </div>'''

    wbs_html = f'''<div class="plan-card">
  <h3>WBS / マイルストーン</h3>
  {wbs_progress}
  <div class="ms-timeline">{ms_items}</div>
  <div class="source-hint">{wbs_source}</div>
</div>'''

# --- Next Actions card ---
actions_html = ""
if next_actions:
    items_html = "".join(
        f'<li><span class="action-badge {a["source"].lower()}">{a["source"]}</span> {a["text"]}</li>'
        for a in next_actions[:5]
    )
    actions_html = f'''<div class="plan-card full-width">
  <h3>直近アクション</h3>
  <ul class="action-list">{items_html}</ul>
</div>'''

plan_section_html = ""
if todo_html or wbs_html or actions_html:
    plan_section_html = f'''<div class="plan-grid">
{todo_html}
{wbs_html}
</div>
{actions_html}'''

# --- HTML generation ---
html = f"""<!DOCTYPE html>
<html lang="ja">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<meta http-equiv="refresh" content="300">
<title>Dashboard — {org_slug}</title>
<script src="https://cdnjs.cloudflare.com/ajax/libs/Chart.js/4.4.1/chart.umd.min.js"></script>
<style>
  :root {{
    --bg: #f8f9fa; --card-bg: #fff; --text: #212529; --muted: #6c757d;
    --border: #dee2e6; --shadow: rgba(0,0,0,0.08);
    --blue: #0d6efd; --yellow: #ffc107; --red: #dc3545; --green: #198754;
  }}
  @media (prefers-color-scheme: dark) {{
    :root {{
      --bg: #1a1a2e; --card-bg: #16213e; --text: #e0e0e0; --muted: #9e9e9e;
      --border: #2a2a4a; --shadow: rgba(0,0,0,0.3);
      --blue: #4dabf7; --yellow: #ffd43b; --red: #ff6b6b; --green: #51cf66;
    }}
  }}
  * {{ margin:0; padding:0; box-sizing:border-box; }}
  body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
         background: var(--bg); color: var(--text); padding: 24px; }}
  h1 {{ font-size: 1.5rem; margin-bottom: 4px; }}
  .subtitle {{ color: var(--muted); font-size: 0.85rem; margin-bottom: 24px; }}
  .grid {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 16px; margin-bottom: 24px; }}
  .card {{ background: var(--card-bg); border: 1px solid var(--border);
           border-radius: 12px; padding: 20px; box-shadow: 0 2px 8px var(--shadow); }}
  .card-label {{ font-size: 0.8rem; color: var(--muted); text-transform: uppercase; letter-spacing: 0.5px; }}
  .card-value {{ font-size: 2.2rem; font-weight: 700; margin-top: 4px; }}
  .card-value.blue {{ color: var(--blue); }}
  .card-value.yellow {{ color: var(--yellow); }}
  .card-value.red {{ color: var(--red); }}
  .card-value.green {{ color: var(--green); }}
  .stats-row {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(160px, 1fr)); gap: 16px; margin-bottom: 24px; }}
  .stat-card {{ background: var(--card-bg); border: 1px solid var(--border);
               border-radius: 12px; padding: 16px; box-shadow: 0 2px 8px var(--shadow); }}
  .stat-label {{ font-size: 0.75rem; color: var(--muted); }}
  .stat-value {{ font-size: 1.5rem; font-weight: 600; margin-top: 2px; }}
  .conv-topics {{ background: var(--card-bg); border: 1px solid var(--border);
                  border-radius: 12px; padding: 20px; margin-bottom: 24px;
                  box-shadow: 0 2px 8px var(--shadow); }}
  .conv-topics h3 {{ font-size: 0.95rem; margin-bottom: 12px; }}
  .conv-topics ul {{ list-style: none; padding: 0; }}
  .conv-topics li {{ padding: 6px 0; border-bottom: 1px solid var(--border); font-size: 0.85rem; }}
  .conv-topics li:last-child {{ border-bottom: none; }}
  .plan-grid {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(340px, 1fr)); gap: 16px; margin-bottom: 24px; }}
  .plan-card {{ background: var(--card-bg); border: 1px solid var(--border);
               border-radius: 12px; padding: 20px; box-shadow: 0 2px 8px var(--shadow); }}
  .plan-card.full-width {{ margin-bottom: 24px; }}
  .plan-card h3 {{ font-size: 0.95rem; margin-bottom: 12px; }}
  .progress-row {{ display: flex; align-items: center; gap: 12px; margin-bottom: 12px; }}
  .progress-bar {{ flex: 1; height: 10px; background: var(--border); border-radius: 5px; overflow: hidden; }}
  .progress-fill {{ height: 100%; background: var(--blue); border-radius: 5px; transition: width 1s ease; }}
  .progress-fill.green {{ background: var(--green); }}
  .progress-text {{ font-size: 0.8rem; color: var(--muted); white-space: nowrap; }}
  .ms-timeline {{ display: flex; flex-direction: column; gap: 8px; margin-top: 8px; }}
  .ms-item {{ display: flex; align-items: center; gap: 8px; font-size: 0.85rem; }}
  .ms-badge {{ background: var(--blue); color: #fff; border-radius: 4px; padding: 2px 8px;
              font-size: 0.75rem; font-weight: 600; flex-shrink: 0; }}
  .ms-name {{ flex: 1; }}
  .ms-date {{ color: var(--muted); font-size: 0.8rem; flex-shrink: 0; }}
  .action-list {{ list-style: none; padding: 0; }}
  .action-list li {{ padding: 6px 0; border-bottom: 1px solid var(--border); font-size: 0.85rem;
                    display: flex; align-items: center; gap: 8px; }}
  .action-list li:last-child {{ border-bottom: none; }}
  .action-badge {{ font-size: 0.65rem; padding: 2px 6px; border-radius: 3px; font-weight: 600; flex-shrink: 0; }}
  .action-badge.todo {{ background: var(--blue); color: #fff; }}
  .action-badge.wbs {{ background: var(--yellow); color: #000; }}
  .action-badge.issue {{ background: var(--green); color: #fff; }}
  .check-box {{ color: var(--muted); }}
  .source-hint {{ font-size: 0.7rem; color: var(--muted); margin-top: 8px; font-style: italic; }}
  .charts {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(380px, 1fr)); gap: 16px; }}
  .chart-box {{ background: var(--card-bg); border: 1px solid var(--border);
                border-radius: 12px; padding: 20px; box-shadow: 0 2px 8px var(--shadow); }}
  .chart-box h3 {{ font-size: 0.95rem; margin-bottom: 12px; }}
  canvas {{ max-height: 280px; }}
  .footer {{ margin-top: 24px; text-align: center; color: var(--muted); font-size: 0.75rem; }}
</style>
</head>
<body>
<h1>📊 {org_slug}</h1>
<p class="subtitle">最終更新: {now} ｜ 5分ごとに自動リフレッシュ</p>

<div class="grid">
  <div class="card">
    <div class="card-label">Todo</div>
    <div class="card-value blue" data-count="{board['todo']}">0</div>
  </div>
  <div class="card">
    <div class="card-label">In Progress</div>
    <div class="card-value yellow" data-count="{board['in_progress']}">0</div>
  </div>
  <div class="card">
    <div class="card-label">Review (NG)</div>
    <div class="card-value red" data-count="{board['review']}">0</div>
  </div>
  <div class="card">
    <div class="card-label">Done</div>
    <div class="card-value green" data-count="{board['done']}">0</div>
  </div>
</div>

<div class="stats-row">
  <div class="stat-card">
    <div class="stat-label">セッション数</div>
    <div class="stat-value">{session_count}</div>
  </div>
  <div class="stat-card">
    <div class="stat-label">ツール実行数</div>
    <div class="stat-value">{total_tools}</div>
  </div>
  <div class="stat-card">
    <div class="stat-label">会話セッション</div>
    <div class="stat-value">{conv_sessions}</div>
  </div>
  <div class="stat-card">
    <div class="stat-label">Human 発言数</div>
    <div class="stat-value">{conv_human_total}</div>
  </div>
</div>

{conv_topics_html}

{plan_section_html}

<div class="charts">
  <div class="chart-box">
    <h3>品質ゲート合格率</h3>
    <canvas id="qgChart"></canvas>
  </div>
  <div class="chart-box">
    <h3>Subagent 使用頻度</h3>
    <canvas id="agentChart"></canvas>
  </div>
  <div class="chart-box" style="grid-column: 1 / -1;">
    <h3>スコア推移</h3>
    <canvas id="scoreChart"></canvas>
  </div>
</div>

<div class="footer">Generated by cc-sier company-dashboard</div>

<script>
// Count-up animation
document.querySelectorAll('[data-count]').forEach(el => {{
  const target = parseInt(el.dataset.count);
  if (target === 0) {{ el.textContent = '0'; return; }}
  const duration = 800, step = duration / target;
  let current = 0;
  const timer = setInterval(() => {{
    current++;
    el.textContent = current;
    if (current >= target) clearInterval(timer);
  }}, step);
}});

const isDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
const gridColor = isDark ? 'rgba(255,255,255,0.1)' : 'rgba(0,0,0,0.1)';
const textColor = isDark ? '#e0e0e0' : '#212529';
Chart.defaults.color = textColor;

// Donut: Quality gate pass rate
new Chart(document.getElementById('qgChart'), {{
  type: 'doughnut',
  data: {{
    labels: ['合格', '不合格'],
    datasets: [{{ data: [{qg_pass}, {qg_fail}], backgroundColor: ['#198754','#dc3545'], borderWidth: 0 }}]
  }},
  options: {{
    cutout: '70%',
    plugins: {{
      legend: {{ position: 'bottom' }},
      tooltip: {{ enabled: true }},
      // center text via plugin
    }},
    animation: {{ animateRotate: true, duration: 1200 }}
  }},
  plugins: [{{
    id: 'centerText',
    afterDraw(chart) {{
      const {{ ctx, chartArea: {{ width, height, top, left }} }} = chart;
      ctx.save();
      ctx.font = 'bold 2rem -apple-system, sans-serif';
      ctx.fillStyle = textColor;
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText('{qg_rate}%', left + width/2, top + height/2);
      ctx.restore();
    }}
  }}]
}});

// Horizontal bar: Subagent usage
new Chart(document.getElementById('agentChart'), {{
  type: 'bar',
  data: {{
    labels: {json.dumps(agent_labels, ensure_ascii=False)},
    datasets: [{{
      data: {json.dumps(agent_values)},
      backgroundColor: '#4dabf7',
      borderRadius: 4,
    }}]
  }},
  options: {{
    indexAxis: 'y',
    plugins: {{ legend: {{ display: false }} }},
    scales: {{
      x: {{ grid: {{ color: gridColor }}, beginAtZero: true, ticks: {{ stepSize: 1 }} }},
      y: {{ grid: {{ display: false }} }}
    }},
    animation: {{ delay(ctx) {{ return ctx.dataIndex * 80; }} }}
  }}
}});

// Line: Score trend
new Chart(document.getElementById('scoreChart'), {{
  type: 'line',
  data: {{
    labels: {json.dumps(score_dates)},
    datasets: [{{
      label: '報酬スコア',
      data: {json.dumps(score_values)},
      borderColor: '#ffc107',
      backgroundColor: 'rgba(255,193,7,0.1)',
      fill: true,
      tension: 0.3,
      pointRadius: 3,
    }}]
  }},
  options: {{
    plugins: {{ legend: {{ display: false }} }},
    scales: {{
      x: {{ grid: {{ color: gridColor }} }},
      y: {{ grid: {{ color: gridColor }}, beginAtZero: true }}
    }},
    animation: {{ duration: 1200 }}
  }}
}});
</script>
</body>
</html>"""

output.write_text(html, encoding="utf-8")
size_kb = round(output.stat().st_size / 1024, 1)
print(f"✅ ダッシュボード生成完了: {output} ({size_kb} KB)")
PYEOF

# ================================================================
# GitHub Pages 用にリポジトリルートの docs/ にもコピー（組織ごとのサブディレクトリ）
# ================================================================
PAGES_DIR="docs/secretary/${ORG_SLUG}"
mkdir -p "$PAGES_DIR"
cp "${OUTPUT_DIR}/dashboard.html" "${PAGES_DIR}/dashboard.html"

# 既存の組織ダッシュボードをスキャンして一覧 HTML を生成
python3 - "docs/secretary" "$ORG_SLUG" <<'PYEOF'
import sys, os
from pathlib import Path
from datetime import datetime

secretary_dir = Path(sys.argv[1])
current_org = sys.argv[2]

# ダッシュボードが存在する組織を収集
orgs = sorted([
    d.name for d in secretary_dir.iterdir()
    if d.is_dir() and (d / 'dashboard.html').exists()
]) if secretary_dir.exists() else []

# 現在の組織が未追加なら追加（生成直後は存在するはず）
if current_org not in orgs:
    orgs.append(current_org)
    orgs.sort()

cards = ""
for org in orgs:
    active = ' style="border:2px solid #4361ee;"' if org == current_org else ''
    cards += f'''
    <a href="./secretary/{org}/dashboard.html" class="card"{active}>
      <div class="org-name">{org}</div>
      <div class="org-label">ダッシュボードを開く →</div>
    </a>'''

html = f"""<!DOCTYPE html>
<html lang="ja">
<head>
<meta charset="UTF-8">
<meta http-equiv="refresh" content="300">
<title>cc-sier-organization</title>
<style>
:root {{ --bg:#f8f9fa; --bg2:#fff; --text:#1a1a2e; --blue:#4361ee; --border:rgba(0,0,0,.08); }}
@media (prefers-color-scheme: dark) {{
  :root {{ --bg:#0d1117; --bg2:#161b22; --text:#e6edf3; --border:rgba(255,255,255,.08); }}
}}
* {{ box-sizing:border-box; margin:0; padding:0; }}
body {{ background:var(--bg); color:var(--text); font-family:system-ui,sans-serif; padding:40px 32px; }}
h1 {{ font-size:1.5rem; margin-bottom:8px; }}
p  {{ color:#6c757d; font-size:.88rem; margin-bottom:32px; }}
.grid {{ display:grid; grid-template-columns:repeat(auto-fill,minmax(240px,1fr)); gap:16px; }}
.card {{ background:var(--bg2); border:1px solid var(--border); border-radius:12px;
         padding:20px 24px; text-decoration:none; color:var(--text);
         transition:box-shadow .2s; display:block; }}
.card:hover {{ box-shadow:0 4px 16px rgba(0,0,0,.12); }}
.org-name {{ font-size:1rem; font-weight:600; margin-bottom:6px; }}
.org-label {{ font-size:.8rem; color:#6c757d; }}
.updated {{ margin-top:40px; font-size:.78rem; color:#6c757d; }}
</style>
</head>
<body>
<h1>cc-sier-organization</h1>
<p>組織を選択してダッシュボードを表示します</p>
<div class="grid">{cards}
</div>
<p class="updated">最終更新: {datetime.now().strftime('%Y-%m-%d %H:%M')} ／ 5分ごと自動リフレッシュ</p>
</body>
</html>"""

Path("docs/index.html").write_text(html, encoding="utf-8")
print("docs/index.html を更新しました")
PYEOF

# コミット＆プッシュ
git add "docs/secretary/${ORG_SLUG}/dashboard.html" docs/index.html "${OUTPUT}"
git commit -m "chore: ダッシュボード更新 [${ORG_SLUG}] $(date '+%Y-%m-%d %H:%M')"
git push origin main

echo "✅ docs/ を更新しました（GitHub Pages 組織別ダッシュボード）"
