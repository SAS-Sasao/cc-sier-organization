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

# 3. Subagent usage from task-log
tl_dir = org_dir / ".task-log"
agent_counts = {}
if tl_dir.exists():
    for f in tl_dir.glob("*.md"):
        text = f.read_text(encoding="utf-8", errors="ignore")
        for m in re.findall(r'(?:subagent|agent|担当)[：:]\s*(\S+)', text, re.IGNORECASE):
            agent_counts[m] = agent_counts.get(m, 0) + 1

# Also check session summaries
ss_dir = org_dir / ".session-summaries"
if ss_dir.exists():
    for f in ss_dir.glob("*.md"):
        text = f.read_text(encoding="utf-8", errors="ignore")
        for m in re.findall(r'(?:subagent|agent)[：:]\s*(\S+)', text, re.IGNORECASE):
            agent_counts[m] = agent_counts.get(m, 0) + 1

# Sort by count descending
agent_labels = list(agent_counts.keys())[:10]
agent_values = [agent_counts[k] for k in agent_labels]

# 4. Score trend from case-bank
cb_path = org_dir / ".case-bank" / "index.json"
score_dates, score_values = [], []
if cb_path.exists():
    try:
        cases = json.loads(cb_path.read_text(encoding="utf-8", errors="ignore"))
        if isinstance(cases, list):
            for c in cases[-30:]:
                d = c.get("date", c.get("timestamp", ""))[:10]
                s = c.get("reward_score", c.get("score", 0))
                if d and isinstance(s, (int, float)):
                    score_dates.append(d)
                    score_values.append(s)
    except: pass

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
