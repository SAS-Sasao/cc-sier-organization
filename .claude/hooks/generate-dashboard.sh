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
        rows = [l for l in sec.splitlines() if l.startswith('|') and not l.startswith('|--')]
        count = len([r for r in rows if r.strip() and not r.startswith('| タスクID') and '—' not in r.split('|')[1].strip()])
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
# Each session produces multiple summary snapshots; count unique session_ids
# and use the latest snapshot per session for tool_count (cumulative)
ss_dir = org_dir / ".session-summaries"
session_count = 0
total_tools = 0
if ss_dir.exists():
    _ss_latest = {}  # session_id -> (filename, data) keeping latest per session
    for f in sorted(ss_dir.glob("*.json")):
        try:
            sd = json.loads(f.read_text(encoding="utf-8", errors="ignore"))
            sid = sd.get("session_id", f.stem)
            _ss_latest[sid] = sd  # sorted order ensures last = latest
        except: pass
    session_count = len(_ss_latest)
    total_tools = sum(sd.get("tool_count", 0) for sd in _ss_latest.values())

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

# 4b. Case Bank evolve stats
cb_total_cases = 0
cb_avg_reward = 0.0
cb_today_tasks = []  # [{task_id, reward, mode}]
cb_low_reward = []   # [{task_id, reward}]
cb_reward_dist = {"high": 0, "medium": 0, "low": 0, "none": 0}  # >=0.7, 0.4-0.7, <0.4, None
today_str_compact = datetime.now().strftime("%Y-%m-%d")

if cb_path.exists():
    try:
        _cb_evolve = json.loads(cb_path.read_text(encoding="utf-8", errors="ignore"))
        _cb_cases = _cb_evolve.get("cases", [])
        cb_total_cases = len(_cb_cases)
        _rewards = [c.get("reward") for c in _cb_cases if c.get("reward") is not None]
        cb_avg_reward = round(sum(_rewards) / len(_rewards), 2) if _rewards else 0.0

        for c in _cb_cases:
            tid = c.get("task_id", c.get("id", "unknown"))
            reward = c.get("reward")
            mode = c.get("action", {}).get("mode", c.get("mode", "?"))
            started = c.get("outcome", {}).get("started", c.get("started", ""))

            # Reward distribution
            if reward is None:
                cb_reward_dist["none"] += 1
            elif reward >= 0.7:
                cb_reward_dist["high"] += 1
            elif reward >= 0.4:
                cb_reward_dist["medium"] += 1
            else:
                cb_reward_dist["low"] += 1

            # Today's tasks
            if tid.startswith(datetime.now().strftime("%Y%m%d")):
                cb_today_tasks.append({"task_id": tid, "reward": reward, "mode": mode})

            # Low reward alerts
            if reward is not None and reward < 0.4:
                cb_low_reward.append({"task_id": tid, "reward": reward})
    except:
        pass

# 5. Judge data aggregation
from collections import defaultdict as ddict
from datetime import datetime as dt

judge_by_agent = ddict(lambda: {"completeness": [], "accuracy": [], "clarity": [], "total": []})
judge_trend_raw = []
monthly_scores = ddict(lambda: ddict(list))  # month -> agent -> [total]
this_month_str = datetime.now().strftime("%Y-%m")
_lm_dt = datetime.now().replace(day=1)
_prev = _lm_dt.replace(month=_lm_dt.month-1) if _lm_dt.month > 1 else _lm_dt.replace(year=_lm_dt.year-1, month=12)
last_month_str = _prev.strftime("%Y-%m")

judge_failure_patterns = []
judge_most_improved = None

case_bank = org_dir / ".case-bank" / "index.json"
if case_bank.exists():
    try:
        _cb = json.loads(case_bank.read_text(encoding="utf-8", errors="ignore"))

        # failure_patterns
        judge_failure_patterns = _cb.get("failure_patterns", [])[:3]

        for c in _cb.get("cases", []):
            j = c.get("judge")
            if not j or not isinstance(j, dict):
                continue
            agent = c.get("action", {}).get("subagent", "unknown")
            started = c.get("outcome", {}).get("started", "")[:7]

            for axis in ["completeness", "accuracy", "clarity", "total"]:
                val = j.get(axis)
                if val is not None:
                    fval = float(val)
                    # Normalize: scores > 1.0 are on 0-10 scale, convert to 0-1.0
                    if axis != "total" and fval > 1.0:
                        fval = fval / 10.0
                    judge_by_agent[agent][axis].append(fval)

            if j.get("total") is not None:
                judge_trend_raw.append({
                    "date": c.get("outcome", {}).get("started", "")[:10],
                    "score": round(float(j["total"]), 2),
                })
            if started:
                monthly_scores[started][agent].append(float(j.get("total", 0)))
    except Exception:
        pass

# Radar chart data (top 6 agents by case count)
top_agents = sorted(
    judge_by_agent.keys(),
    key=lambda a: -len(judge_by_agent[a]["total"])
)[:6]

judge_radar = {
    "labels": top_agents,
    "completeness": [round(sum(judge_by_agent[a]["completeness"])/len(judge_by_agent[a]["completeness"]), 2) if judge_by_agent[a]["completeness"] else 0 for a in top_agents],
    "accuracy":     [round(sum(judge_by_agent[a]["accuracy"])/len(judge_by_agent[a]["accuracy"]), 2) if judge_by_agent[a]["accuracy"] else 0 for a in top_agents],
    "clarity":      [round(sum(judge_by_agent[a]["clarity"])/len(judge_by_agent[a]["clarity"]), 2) if judge_by_agent[a]["clarity"] else 0 for a in top_agents],
}

# --- Improvement Insights Analysis ---
# 1. Per-agent weakest axis
agent_weaknesses = []
for agent in judge_by_agent:
    axes = {}
    for axis in ["completeness", "accuracy", "clarity"]:
        vals = judge_by_agent[agent][axis]
        if vals:
            axes[axis] = round(sum(vals) / len(vals), 2)
    if axes:
        weakest = min(axes, key=axes.get)
        n_cases = len(judge_by_agent[agent]["total"])
        agent_weaknesses.append({
            "agent": agent or "(secretary直接)",
            "weakest_axis": weakest,
            "weakest_score": axes[weakest],
            "all_axes": axes,
            "case_count": n_cases,
        })

# 2. Low-score case analysis (total < 0.7)
low_score_cases = []
if case_bank.exists():
    try:
        _cb2 = json.loads(case_bank.read_text(encoding="utf-8", errors="ignore"))
        for c in _cb2.get("cases", []):
            j = c.get("judge")
            if not j or not isinstance(j, dict):
                continue
            total = j.get("total")
            if total is not None and float(total) < 0.7:
                low_score_cases.append({
                    "task_id": c.get("id", "?"),
                    "agent": c.get("action", {}).get("subagent", "") or "(secretary直接)",
                    "total": round(float(total), 2),
                    "comment": j.get("judge_comment", ""),
                    "failure_reason": j.get("failure_reason", ""),
                    "request": (c.get("state", {}).get("request_head", "") or "")[:60],
                })
    except Exception:
        pass

# 3. Action suggestions based on weak axes
axis_labels_ja = {"completeness": "網羅性", "accuracy": "正確性", "clarity": "明瞭性"}
action_suggestions = {
    "completeness": "調査範囲の事前定義やチェックリストの活用を検討。Subagentへの指示で「必ず含めるべき観点」を明示する。",
    "accuracy": "情報ソースの信頼性確認を強化。公式ドキュメントURLの添付を必須にし、推測と事実を明確に区別する。",
    "clarity": "成果物のフォーマット統一（目次・マトリックス・図解）を推進。読み手のペルソナ（PM/エンジニア）を指示に含める。",
}

# Judge score trend (last 30)
judge_trend_raw.sort(key=lambda x: x["date"])
judge_trend = judge_trend_raw[-30:]

# Most improved agent (this month vs last month)
best_agent = None
best_delta = 0
for agent in set(list(monthly_scores[this_month_str].keys()) + list(monthly_scores[last_month_str].keys())):
    this_scores = monthly_scores[this_month_str].get(agent, [])
    last_scores = monthly_scores[last_month_str].get(agent, [])
    if this_scores and last_scores:
        delta = (sum(this_scores)/len(this_scores)) - (sum(last_scores)/len(last_scores))
        if delta > best_delta:
            best_delta = delta
            best_agent = agent
if best_agent:
    judge_most_improved = {
        "agent": best_agent,
        "delta": round(best_delta, 2),
        "this_month_avg": round(sum(monthly_scores[this_month_str][best_agent])/len(monthly_scores[this_month_str][best_agent]), 2),
    }

# 6. Conversation log stats
conv_dir = org_dir / ".conversation-log"
conv_sessions = 0
conv_human_total = 0
conv_rallies = []  # list of (human_text, claude_text) tuples

def is_real_message(text):
    """tool_result, command-message, SKILL本文などを除外"""
    t = text.strip()
    if not t or len(t) < 5:
        return False
    if t.startswith('```tool_result') or t.startswith('```tool_use'):
        return False
    if t.startswith('<command-message>') or t.startswith('<command-name>'):
        return False
    if t.startswith('Base directory for this skill:'):
        return False
    if t.startswith('#') and len(t) > 100:
        return False
    return True

def extract_first_line(text, max_len=80):
    """実際の発言の先頭行を抽出（短く切る）"""
    for line in text.strip().split('\n'):
        line = line.strip()
        if line and not line.startswith('```') and not line.startswith('<'):
            return line[:max_len] + ('...' if len(line) > max_len else '')
    return text.strip()[:max_len]

if conv_dir.exists():
    for f in sorted(conv_dir.glob("*.md")):
        try:
            text = f.read_text(encoding="utf-8", errors="ignore")
            conv_sessions += 1
            human_sections = re.findall(r'## 👤 Human\n\n(.*?)(?=\n---|\Z)', text, re.DOTALL)
            conv_human_total += len(human_sections)
            # Extract rally pairs by scanning sections in order
            sections = re.findall(r'## (👤 Human|🤖 Claude)\n\n(.*?)(?=\n---|\Z)', text, re.DOTALL)
            pending_human = None
            for role, body in sections:
                if role == '👤 Human' and is_real_message(body):
                    pending_human = extract_first_line(body)
                elif role == '🤖 Claude' and pending_human is not None and is_real_message(body):
                    conv_rallies.append((pending_human, extract_first_line(body)))
                    pending_human = None
        except: pass

# Build conversation HTML — last 5 rallies
conv_topics_html = ""
if conv_rallies:
    recent = conv_rallies[-5:]
    items = ""
    for h, c in recent:
        h_esc = h.replace("&","&amp;").replace("<","&lt;").replace(">","&gt;")
        c_esc = c.replace("&","&amp;").replace("<","&lt;").replace(">","&gt;")
        items += f'<div class="rally"><div class="rally-human"><span class="rally-label">👤</span> {h_esc}</div><div class="rally-claude"><span class="rally-label">🤖</span> {c_esc}</div></div>'
    conv_topics_html = f'<div class="conv-topics"><h3>直近の会話</h3>{items}</div>'

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

# --- Evolve section HTML ---
evolve_section_html = ""
if cb_total_cases > 0:
    # Reward color helper
    def reward_class(r):
        if r is None: return "reward-none"
        if r >= 0.7: return "reward-high"
        if r >= 0.4: return "reward-mid"
        return "reward-low"

    def reward_text(r):
        return f"{r:.1f}" if r is not None else "N/A"

    # Today's tasks HTML
    today_html = ""
    if cb_today_tasks:
        rows = ""
        for t in cb_today_tasks:
            rc = reward_class(t["reward"])
            rt = reward_text(t["reward"])
            tid_short = t["task_id"].split("-", 2)[-1] if "-" in t["task_id"] else t["task_id"]
            rows += f'<div class="task-row"><span class="reward-badge {rc}">{rt}</span><span class="task-id">{tid_short}</span><span class="task-mode">{t["mode"]}</span></div>'
        today_html = f'<div class="today-tasks"><h3>本日のタスク評価</h3>{rows}</div>'

    # Low reward alerts HTML
    alert_html = ""
    if cb_low_reward:
        items = "".join(
            f'<div style="font-size:.85rem;padding:4px 0">'
            f'<span class="reward-badge reward-low">{r["reward"]:.1f}</span> '
            f'<span style="font-family:monospace">{r["task_id"]}</span></div>'
            for r in cb_low_reward[-3:]
        )
        alert_html = f'<div class="alert-card"><h3>⚠ 低報酬ケース</h3>{items}</div>'

    # Reward distribution bar
    dist_total = sum(cb_reward_dist.values())
    dist_pcts = {k: round(v / dist_total * 100) if dist_total > 0 else 0 for k, v in cb_reward_dist.items()}

    evolve_section_html = f'''<div class="evolve-section">
  <h2>継続学習（company-evolve）</h2>
  <div class="evolve-grid">
    <div class="evolve-card">
      <div class="ev-label">Case Bank</div>
      <div class="ev-value" style="color:var(--blue)">{cb_total_cases}</div>
      <div class="ev-sub">インデックス済みケース</div>
    </div>
    <div class="evolve-card">
      <div class="ev-label">平均報酬</div>
      <div class="ev-value" style="color:{"var(--green)" if cb_avg_reward >= 0.7 else "var(--yellow)" if cb_avg_reward >= 0.4 else "var(--red)"}">{cb_avg_reward:.2f}</div>
      <div class="ev-sub">全ケース平均</div>
    </div>
    <div class="evolve-card">
      <div class="ev-label">報酬分布</div>
      <div style="display:flex;gap:4px;height:14px;border-radius:7px;overflow:hidden;margin-top:10px">
        <div style="flex:{dist_pcts['high']};background:var(--green)" title="高 (≥0.7): {cb_reward_dist['high']}件"></div>
        <div style="flex:{dist_pcts['medium']};background:var(--yellow)" title="中 (0.4-0.7): {cb_reward_dist['medium']}件"></div>
        <div style="flex:{dist_pcts['low']};background:var(--red)" title="低 (<0.4): {cb_reward_dist['low']}件"></div>
        <div style="flex:{dist_pcts['none']};background:var(--border)" title="未評価: {cb_reward_dist['none']}件"></div>
      </div>
      <div class="ev-sub" style="margin-top:6px">高{cb_reward_dist['high']} / 中{cb_reward_dist['medium']} / 低{cb_reward_dist['low']} / 未{cb_reward_dist['none']}</div>
    </div>
    <div class="evolve-card">
      <div class="ev-label">本日評価</div>
      <div class="ev-value" style="color:var(--blue)">{len(cb_today_tasks)}</div>
      <div class="ev-sub">タスク</div>
    </div>
  </div>
  {today_html}
  {alert_html}
</div>'''

plan_section_html = ""
if todo_html or wbs_html or actions_html:
    plan_section_html = f'''<div class="plan-grid">
{todo_html}
{wbs_html}
</div>
{actions_html}'''

# --- Judge widget data preparation ---
radar_labels_json    = json.dumps(judge_radar["labels"], ensure_ascii=False)
radar_complete_json  = json.dumps(judge_radar["completeness"])
radar_accuracy_json  = json.dumps(judge_radar["accuracy"])
radar_clarity_json   = json.dumps(judge_radar["clarity"])
judge_t_labels_json  = json.dumps([t["date"] for t in judge_trend])
judge_t_data_json    = json.dumps([t["score"] for t in judge_trend])

# Improved highlight HTML
improved_html = ""
if judge_most_improved:
    improved_html = f"""<div style="border-left: 3px solid #06d6a0; padding: 12px 16px; border-radius: 8px; background: var(--card-bg); margin-bottom: 8px;">
  <div style="font-size:.75rem;color:var(--muted);text-transform:uppercase">今月最も改善した Subagent</div>
  <div style="font-size:1.2rem;font-weight:700;color:#06d6a0;margin-top:4px">{judge_most_improved['agent']}</div>
  <div style="font-size:.82rem;color:var(--muted);margin-top:2px">
    judge スコア +{judge_most_improved['delta']:.2f} ／ 今月平均: {judge_most_improved['this_month_avg']:.2f}
  </div>
</div>"""
else:
    improved_html = '<div style="font-size:.82rem;color:var(--muted);margin-bottom:8px">改善ハイライト: 月をまたいだデータが蓄積されると表示されます</div>'

# --- Weakness analysis HTML ---
weakness_html = ""
if agent_weaknesses:
    rows = ""
    for w in sorted(agent_weaknesses, key=lambda x: x["weakest_score"]):
        axes_bar = ""
        for ax in ["completeness", "accuracy", "clarity"]:
            v = w["all_axes"].get(ax, 0)
            pct = int(v * 100)
            color = "#ef476f" if ax == w["weakest_axis"] else "#06d6a0"
            axes_bar += f'<div style="display:flex;align-items:center;gap:6px;margin:2px 0">'
            axes_bar += f'<span style="font-size:.7rem;width:50px;color:var(--muted)">{axis_labels_ja[ax]}</span>'
            axes_bar += f'<div style="flex:1;height:6px;background:var(--border);border-radius:3px;overflow:hidden">'
            axes_bar += f'<div style="width:{pct}%;height:100%;background:{color};border-radius:3px"></div></div>'
            axes_bar += f'<span style="font-size:.7rem;width:30px;text-align:right">{v:.2f}</span></div>'
        rows += f'''<div style="padding:8px 0;border-bottom:1px solid var(--border)">
  <div style="display:flex;justify-content:space-between;align-items:center">
    <span style="font-size:.82rem;font-weight:600">{w["agent"]}</span>
    <span style="font-size:.7rem;color:var(--muted)">{w["case_count"]}件</span>
  </div>
  {axes_bar}
  <div style="font-size:.72rem;color:#ef476f;margin-top:4px">
    弱点: {axis_labels_ja[w["weakest_axis"]]}（{w["weakest_score"]:.2f}）
  </div>
</div>'''
    weakness_html = f'<div style="margin-bottom:12px"><div style="font-size:.8rem;font-weight:600;margin-bottom:6px">軸別弱点分析</div>{rows}</div>'

# --- Low-score case analysis HTML ---
low_score_html = ""
if low_score_cases:
    items = ""
    for lc in low_score_cases[:5]:
        comment = lc["comment"][:80] + "..." if len(lc["comment"]) > 80 else lc["comment"]
        items += f'''<li style="padding:6px 0;border-bottom:1px solid var(--border);font-size:.82rem">
  <div style="display:flex;justify-content:space-between">
    <span style="font-weight:500">{lc["agent"]}</span>
    <span style="color:var(--red);font-weight:600">{lc["total"]:.2f}</span>
  </div>
  <div style="font-size:.72rem;color:var(--muted);margin-top:2px">{lc["request"]}...</div>
  <div style="font-size:.72rem;color:var(--text);margin-top:2px">{comment}</div>
</li>'''
    low_score_html = f'<div style="margin-bottom:12px"><div style="font-size:.8rem;font-weight:600;margin-bottom:6px">低スコアケース（&lt;0.7）</div><ul style="list-style:none;padding:0;margin:0">{items}</ul></div>'

# --- Action suggestions HTML ---
suggested_actions_html = ""
if agent_weaknesses:
    # Collect globally weakest axes across all agents
    global_axis_scores = {ax: [] for ax in ["completeness", "accuracy", "clarity"]}
    for w in agent_weaknesses:
        for ax, v in w["all_axes"].items():
            global_axis_scores[ax].append(v)
    global_avgs = {ax: sum(vs)/len(vs) if vs else 1.0 for ax, vs in global_axis_scores.items()}
    weak_axes = [ax for ax, avg in sorted(global_avgs.items(), key=lambda x: x[1]) if avg < 0.9][:2]

    if weak_axes:
        action_items = ""
        for ax in weak_axes:
            action_items += f'''<li style="padding:6px 0;border-bottom:1px solid var(--border);font-size:.82rem">
  <span style="font-weight:600;color:var(--accent)">{axis_labels_ja[ax]}</span>
  <span style="color:var(--muted)">（全体平均 {global_avgs[ax]:.2f}）</span>
  <div style="font-size:.72rem;margin-top:3px">{action_suggestions[ax]}</div>
</li>'''
        suggested_actions_html = f'<div style="margin-bottom:12px"><div style="font-size:.8rem;font-weight:600;margin-bottom:6px">改善アクション提案</div><ul style="list-style:none;padding:0;margin:0">{action_items}</ul></div>'

# Failure patterns HTML
failure_items_html = "".join([
    f'<li style="padding:6px 0;border-bottom:1px solid var(--border);font-size:.82rem">'
    f'<span style="color:var(--red);font-weight:500">{fp["subagent"]}</span> — '
    f'{fp["failure_reason"]} '
    f'<span style="color:var(--muted)">({fp["count"]}件)</span></li>'
    for fp in judge_failure_patterns
]) or "<li style='color:var(--muted);font-size:.82rem'>データ蓄積中</li>"

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
  .card-hint {{ font-size: 0.65rem; color: var(--muted); margin-top: 4px; opacity: 0.7; }}
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
  .rally {{ padding: 10px 0; border-bottom: 1px solid var(--border); }}
  .rally:last-child {{ border-bottom: none; }}
  .rally-human, .rally-claude {{ font-size: 0.85rem; padding: 4px 0; }}
  .rally-human {{ color: var(--text); }}
  .rally-claude {{ color: var(--muted); margin-left: 16px; }}
  .rally-label {{ font-size: 0.8rem; margin-right: 4px; }}
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
  .evolve-section {{ margin-bottom: 24px; }}
  .evolve-section h2 {{ font-size: 1.1rem; margin-bottom: 16px; }}
  .evolve-grid {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 16px; margin-bottom: 16px; }}
  .evolve-card {{ background: var(--card-bg); border: 1px solid var(--border);
                  border-radius: 12px; padding: 16px; box-shadow: 0 2px 8px var(--shadow); }}
  .evolve-card .ev-label {{ font-size: 0.75rem; color: var(--muted); text-transform: uppercase; }}
  .evolve-card .ev-value {{ font-size: 1.8rem; font-weight: 700; margin-top: 4px; }}
  .evolve-card .ev-sub {{ font-size: 0.75rem; color: var(--muted); margin-top: 2px; }}
  .today-tasks {{ background: var(--card-bg); border: 1px solid var(--border);
                  border-radius: 12px; padding: 20px; margin-bottom: 16px;
                  box-shadow: 0 2px 8px var(--shadow); }}
  .today-tasks h3 {{ font-size: 0.95rem; margin-bottom: 12px; }}
  .task-row {{ display: flex; align-items: center; gap: 12px; padding: 8px 0;
               border-bottom: 1px solid var(--border); font-size: 0.85rem; }}
  .task-row:last-child {{ border-bottom: none; }}
  .reward-badge {{ display: inline-block; padding: 2px 10px; border-radius: 12px;
                   font-weight: 600; font-size: 0.8rem; min-width: 48px; text-align: center; }}
  .reward-high {{ background: rgba(25,135,84,0.15); color: var(--green); }}
  .reward-mid {{ background: rgba(255,193,7,0.15); color: var(--yellow); }}
  .reward-low {{ background: rgba(220,53,69,0.15); color: var(--red); }}
  .reward-none {{ background: var(--border); color: var(--muted); }}
  .task-id {{ flex: 1; font-family: monospace; font-size: 0.8rem; }}
  .task-mode {{ font-size: 0.7rem; color: var(--muted); }}
  .alert-card {{ background: var(--card-bg); border-left: 3px solid var(--red);
                 border-radius: 12px; padding: 16px; margin-bottom: 16px;
                 box-shadow: 0 2px 8px var(--shadow); }}
  .alert-card h3 {{ font-size: 0.9rem; color: var(--red); margin-bottom: 8px; }}
  .charts {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(380px, 1fr)); gap: 16px; }}
  .chart-box {{ background: var(--card-bg); border: 1px solid var(--border);
                border-radius: 12px; padding: 20px; box-shadow: 0 2px 8px var(--shadow); }}
  .chart-box h3 {{ font-size: 0.95rem; margin-bottom: 12px; }}
  canvas {{ max-height: 800px; }}
  .footer {{ margin-top: 24px; text-align: center; color: var(--muted); font-size: 0.75rem; }}
  .back-btn {{ display: inline-block; margin-bottom: 16px; padding: 6px 16px;
               background: var(--card-bg); border: 1px solid var(--border); border-radius: 8px;
               color: var(--text); text-decoration: none; font-size: 0.85rem;
               box-shadow: 0 1px 4px var(--shadow); transition: background 0.2s; }}
  .back-btn:hover {{ background: var(--border); }}
</style>
</head>
<body>
<a href="https://sas-sasao.github.io/cc-sier-organization/" class="back-btn">← トップに戻る</a>
<h1>📊 {org_slug}</h1>
<p class="subtitle">最終更新: {now} ｜ 5分ごとに自動リフレッシュ</p>

<div class="grid">
  <div class="card">
    <div class="card-label">Todo</div>
    <div class="card-value blue" data-count="{board['todo']}">0</div>
    <div class="card-hint">WBS + タスクログの未着手</div>
  </div>
  <div class="card">
    <div class="card-label">In Progress</div>
    <div class="card-value yellow" data-count="{board['in_progress']}">0</div>
    <div class="card-hint">WBS + タスクログの進行中</div>
  </div>
  <div class="card">
    <div class="card-label">Review (NG)</div>
    <div class="card-value red" data-count="{board['review']}">0</div>
    <div class="card-hint">品質ゲートNG・要修正</div>
  </div>
  <div class="card">
    <div class="card-label">Done</div>
    <div class="card-value green" data-count="{board['done']}">0</div>
    <div class="card-hint">WBS + タスクログの完了済み</div>
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

{plan_section_html}

{conv_topics_html}

<div class="charts">
  <div class="chart-box">
    <h3>品質ゲート合格率</h3>
    <canvas id="qgChart"></canvas>
  </div>
  <div class="chart-box">
    <h3>Subagent 使用頻度</h3>
    <canvas id="agentChart"></canvas>
  </div>
</div>

{evolve_section_html}

<div class="charts">
  <div class="chart-box">
    <h3>🔧 reward スコア推移（プロセス評価）</h3>
    <p style="font-size:.78rem;color:var(--muted);margin-bottom:12px">タスクの<strong>進め方</strong>を機械的に評価。completed / artifacts_exist / no_excessive_edits / no_retry の4シグナルで自動採点。</p>
    <canvas id="scoreChart"></canvas>
  </div>
  <div class="chart-box">
    <h3>📝 judge スコア推移（成果物評価）</h3>
    <p style="font-size:.78rem;color:var(--muted);margin-bottom:12px">成果物の<strong>出来栄え</strong>をAIが評価。completeness（網羅性）/ accuracy（正確性）/ clarity（意図理解）の3軸で採点。</p>
    <canvas id="judgeChart"></canvas>
  </div>

  <!-- LLM-as-Judge: レーダーチャート -->
  <div class="chart-box">
    <h3>Subagent 評価軸レーダー</h3>
    <p style="font-size:.78rem;color:var(--muted);margin-bottom:12px">Subagentごとの3軸評価平均。得意・不得意がひと目でわかる。</p>
    <canvas id="radarChart" style="max-height:800px"></canvas>
  </div>

  <!-- 改善インサイト -->
  <div class="chart-box">
    <h3>改善インサイト</h3>
    <p style="font-size:.78rem;color:var(--muted);margin-bottom:12px">judge 評価から自動分析。弱点の可視化・低スコア原因・改善アクションを提示。</p>
    {improved_html}
    {weakness_html}
    {low_score_html}
    {suggested_actions_html}
    <div style="margin-top:12px">
      <div style="font-size:.8rem;font-weight:600;margin-bottom:8px">よく出る失敗パターン（上位3件）</div>
      <ul style="list-style:none;padding:0;margin:0">{failure_items_html}</ul>
    </div>
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

// Radar: LLM-as-Judge evaluation axes
const radarCtx = document.getElementById('radarChart');
if (radarCtx) {{
  const radarLabelsData = {radar_labels_json};
  if (radarLabelsData.length > 0) {{
    new Chart(radarCtx.getContext('2d'), {{
      type: 'radar',
      data: {{
        labels: ['completeness', 'accuracy', 'clarity'],
        datasets: radarLabelsData.map((agent, i) => ({{
          label: agent,
          data: [
            {radar_complete_json}[i] || 0,
            {radar_accuracy_json}[i] || 0,
            {radar_clarity_json}[i] || 0,
          ],
          borderWidth: 1.5,
          fill: true,
          backgroundColor: `hsla(${{i * 60}}, 70%, 60%, 0.1)`,
          borderColor: `hsla(${{i * 60}}, 70%, 50%, 0.8)`,
        }})),
      }},
      options: {{
        animation: {{ duration: 1000, easing: 'easeOutQuart' }},
        scales: {{
          r: {{
            min: 0, max: 1.0,
            ticks: {{ stepSize: 0.2, color: textColor, font: {{ size: 10 }} }},
            grid: {{ color: 'rgba(128,128,128,.15)' }},
            pointLabels: {{ color: textColor, font: {{ size: 11 }} }},
          }}
        }},
        plugins: {{ legend: {{ labels: {{ color: textColor, font: {{ size: 11 }} }} }} }},
      }}
    }});
  }}
}}

// Line: Judge total trend
const judgeCtx = document.getElementById('judgeChart');
if (judgeCtx) {{
  const judgeTrendLabels = {judge_t_labels_json};
  const judgeTrendData = {judge_t_data_json};
  if (judgeTrendData.length > 0) {{
    new Chart(judgeCtx.getContext('2d'), {{
      type: 'line',
      data: {{
        labels: judgeTrendLabels,
        datasets: [{{
          label: 'judge total',
          data: judgeTrendData,
          borderColor: '#7209b7',
          backgroundColor: 'rgba(114,9,183,.12)',
          tension: 0.4,
          fill: true,
          pointRadius: 3,
        }}]
      }},
      options: {{
        animation: {{ duration: 1200, easing: 'easeOutQuart' }},
        plugins: {{ legend: {{ display: false }} }},
        scales: {{
          x: {{ grid: {{ color: gridColor }}, ticks: {{ color: textColor, maxTicksLimit: 8 }} }},
          y: {{ min: 0, max: 1, grid: {{ color: gridColor }}, ticks: {{ color: textColor }} }}
        }}
      }}
    }});
  }}
}}

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
      y: {{ grid: {{ color: gridColor }}, min: 0, max: 1, ticks: {{ stepSize: 0.2 }} }}
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
