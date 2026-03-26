#!/usr/bin/env bash
# task-log/*.md を走査して .case-bank/index.json を再構築する
# 既存の enriched データ（reward, conversation_context 等）は保持する

rebuild_case_bank() {
  local org_slug="$1"
  local task_log_dir=".companies/${org_slug}/.task-log"
  local case_bank_dir=".companies/${org_slug}/.case-bank"

  [[ ! -d "$task_log_dir" ]] && return 0
  command -v python3 &>/dev/null || return 0
  mkdir -p "$case_bank_dir"

  # Resolve feedback memory directory
  local cwd_slug
  cwd_slug=$(pwd | sed 's|/|-|g; s|^-||')
  local feedback_dir="${HOME}/.claude/projects/-${cwd_slug}/memory"

  python3 - "$task_log_dir" "$case_bank_dir" "$org_slug" "$feedback_dir" <<'PYEOF'
import sys, re, json
from pathlib import Path
from datetime import datetime

task_log_dir = Path(sys.argv[1])
case_bank_dir = Path(sys.argv[2])
org_slug = sys.argv[3]
feedback_dir = Path(sys.argv[4]) if len(sys.argv) > 4 else None

# ================================================================
# Load existing Case Bank to preserve enriched data
# ================================================================
existing_index = case_bank_dir / "index.json"
existing_cases = {}
extra_fields = {}  # preserved top-level fields (frequent_phrases, etc.)
if existing_index.exists():
    try:
        old = json.loads(existing_index.read_text(encoding="utf-8", errors="ignore"))
        for c in old.get("cases", []):
            existing_cases[c["id"]] = c
        # Preserve enrichment metadata
        for key in ("frequent_phrases", "intent_patterns", "conversation_enriched_at"):
            if key in old:
                extra_fields[key] = old[key]
    except Exception:
        pass

# ================================================================
# Parse task-log files
# ================================================================
cases = []

for md_file in sorted(task_log_dir.glob("*.md")):
    text = md_file.read_text(encoding="utf-8", errors="ignore")
    task_id = md_file.stem

    # --- Parse: support both frontmatter (---) and bullet (- **key**:) formats ---
    def get_field(key_patterns, default=""):
        """Search for a field in frontmatter or bullet format."""
        for pat in key_patterns:
            # Frontmatter: key: "value" or key: value
            m = re.search(rf'^{pat}:\s*"?(.*?)"?\s*$', text, re.MULTILINE)
            if m and m.group(1).strip():
                return m.group(1).strip()
            # Bullet: - **label**: value
            m = re.search(rf'^\-\s*\*\*{pat}\*\*:\s*(.+)$', text, re.MULTILINE | re.IGNORECASE)
            if m and m.group(1).strip():
                return m.group(1).strip()
        return default

    status  = get_field(["status", "ステータス"])
    mode    = get_field(["mode", "実行モード"])
    started = get_field(["started", "開始時刻", "開始"])
    request = get_field(["request", "依頼内容"])
    org     = get_field(["org", "組織"], org_slug)

    # If request is empty, try to extract from ## 依頼内容 section
    if not request:
        m = re.search(r'## 依頼内容\s*\n\n(.+?)(?:\n\n|\n##|\Z)', text, re.DOTALL)
        if m:
            request = m.group(1).strip()[:100]

    # Clean mode: extract from "Agent Teams（2部署並列）" → "agent-teams"
    mode_lower = mode.lower()
    if "agent" in mode_lower and "team" in mode_lower:
        mode = "agent-teams"
    elif "subagent" in mode_lower or "委譲" in mode_lower:
        mode = "subagent"
    elif "direct" in mode_lower or "直接" in mode_lower:
        mode = "direct"

    # --- Subagent detection (multiple patterns) ---
    # Known agent name pattern: lowercase ASCII with hyphens (e.g. retail-domain-researcher)
    AGENT_RE = r'[a-z][a-z0-9]+(?:-[a-z0-9]+)+'  # must contain at least one hyphen
    subagents = []
    # Pattern 1: "secretary → {name}" in log entries
    for m in re.findall(rf'secretary\s*→\s*({AGENT_RE})', text):
        subagents.append(m)
    # Pattern 2: "- **アサイン**: agent-name" (single line)
    assign_single = re.search(r'\*\*アサイン\*\*:\s*(.+)$', text, re.MULTILINE)
    if assign_single:
        for name in re.findall(AGENT_RE, assign_single.group(1)):
            subagents.append(name)
    # Pattern 3: "  - agent-name: 作業内容" in indented assign list
    assign_list = re.search(r'\*\*アサイン\*\*:\s*\n((?:\s+-\s+.+\n)*)', text)
    if assign_list:
        for name in re.findall(rf'^\s+-\s+({AGENT_RE}):', assign_list.group(1), re.MULTILINE):
            subagents.append(name)
    # Pattern 4: "### {agent-name}" section headers in work log
    for m in re.finditer(rf'^###\s+({AGENT_RE})\s*$', text, re.MULTILINE):
        subagents.append(m.group(1))
    # Deduplicate preserving order
    seen = set()
    unique_subagents = []
    for s in subagents:
        if s not in seen:
            seen.add(s)
            unique_subagents.append(s)
    subagent_str = ",".join(unique_subagents)

    # --- Reward score ---
    reward_score = None
    m = re.search(r'score:\s*([\d.]+)', text)
    if m:
        try:
            reward_score = float(m.group(1))
        except ValueError:
            pass

    # --- Judge score (## judge section) ---
    judge_data = None
    # Format 1: YAML code block
    judge_section = re.search(r'## judge\s*```yaml\s*(.*?)```', text, re.DOTALL)
    if judge_section:
        judge_yaml = judge_section.group(1)
        judge_data = {}
        for key in ['completeness', 'accuracy', 'clarity', 'total']:
            m = re.search(rf'^{key}:\s*([\d.]+)', judge_yaml, re.MULTILINE)
            if m:
                judge_data[key] = float(m.group(1))
        for key in ['failure_reason', 'judge_comment']:
            m = re.search(rf'^{key}:\s*"?(.*?)"?\s*$', judge_yaml, re.MULTILINE)
            if m:
                judge_data[key] = m.group(1).strip()
        m = re.search(r'^judged_at:\s*"?(.*?)"?\s*$', judge_yaml, re.MULTILINE)
        if m:
            judge_data['judged_at'] = m.group(1).strip()
    # Format 2: Markdown table (| 軸 | スコア | コメント |)
    if judge_data is None:
        judge_block = re.search(r'## judge\b(.*?)(?=\n## |\n---|\Z)', text, re.DOTALL)
        if judge_block:
            jtext = judge_block.group(1)
            # Parse table rows: | completeness | 4 | ... | or | completeness | 4/5 | ... |
            scores = {}
            for row in re.finditer(r'\|\s*(completeness|accuracy|clarity)\s*\|\s*([\d.]+)(?:\s*/\s*\d+)?\s*\|', jtext, re.IGNORECASE):
                scores[row.group(1).lower()] = float(row.group(2))
            # Parse total: **総合スコア**: 4.3 / 5.0 or **総合**: **4.3/5.0**
            total_m = re.search(r'総合[^:]*[:：]\s*\*{0,2}([\d.]+)\s*/\s*([\d.]+)', jtext)
            if total_m:
                raw_total = float(total_m.group(1))
                max_total = float(total_m.group(2))
                scores['total'] = round(raw_total / max_total, 2) if max_total > 0 else raw_total
            if scores:
                judge_data = {}
                for key in ['completeness', 'accuracy', 'clarity']:
                    if key in scores:
                        # Normalize 1-5 scale to 0.0-1.0 scale
                        val = scores[key]
                        judge_data[key] = round(val / 5.0, 2) if val > 1.0 else val
                if 'total' in scores:
                    judge_data['total'] = scores['total']
                judge_data.setdefault('failure_reason', '')
                judge_data.setdefault('judge_comment', '')

    # --- Artifacts: both absolute and relative paths ---
    artifacts = []
    # Absolute: `.companies/org/docs/...`
    artifacts.extend(re.findall(r'`(\.companies/[^`]+)`', text))
    # Relative: `docs/...` (convert to absolute)
    for rel in re.findall(r'`(docs/[^`]+\.md)`', text):
        abs_path = f".companies/{org_slug}/{rel}"
        if abs_path not in artifacts:
            artifacts.append(abs_path)
    artifacts = list(dict.fromkeys(artifacts))  # deduplicate

    # --- Keywords ---
    keywords = [kw for kw in re.split(r'[\s、。「」【】（）・,]', request)
                if len(kw) >= 2][:8]

    # --- Build case, merging with existing enriched data ---
    new_case = {
        "id": task_id,
        "state": {
            "request_keywords": keywords,
            "request_head": request[:60],
            "org_slug": org,
        },
        "action": {
            "subagent": subagent_str,
            "mode": mode,
            "artifact_count": len(artifacts),
        },
        "reward": reward_score,
        "judge": judge_data,
        "outcome": {
            "files_written": artifacts[:8],
            "started": started,
        },
    }

    # Preserve enriched fields from existing case
    if task_id in existing_cases:
        old_case = existing_cases[task_id]
        # Keep reward if already evaluated and new parse found nothing
        if new_case["reward"] is None and old_case.get("reward") is not None:
            new_case["reward"] = old_case["reward"]
        if old_case.get("reward_signals"):
            new_case["reward_signals"] = old_case["reward_signals"]
        # Keep judge if already evaluated and new parse found nothing
        if new_case["judge"] is None and old_case.get("judge") is not None:
            new_case["judge"] = old_case["judge"]
        # Keep conversation context
        if old_case.get("conversation_context"):
            new_case["conversation_context"] = old_case["conversation_context"]
        if old_case.get("conversation_enriched"):
            new_case["conversation_enriched"] = old_case["conversation_enriched"]

    cases.append(new_case)

# ================================================================
# Aggregate failure_patterns from judge data
# ================================================================
from collections import Counter
failure_counter = Counter()
for c in cases:
    j = c.get("judge")
    if j and isinstance(j, dict):
        total = j.get("total", 1.0)
        reason = j.get("failure_reason", "").strip()
        subagent = c.get("action", {}).get("subagent", "unknown")
        if total < 0.6 and reason:
            key = f"{subagent}::{reason}"
            failure_counter[key] += 1

failure_patterns = []
for key, count in failure_counter.most_common(10):
    parts = key.split("::", 1)
    subagent = parts[0] if len(parts) > 1 else "unknown"
    reason = parts[1] if len(parts) > 1 else key
    # Average score for this pattern
    related = [
        c.get("judge", {}).get("total", 0)
        for c in cases
        if c.get("action", {}).get("subagent") == subagent
        and c.get("judge", {}).get("failure_reason", "") == reason
    ]
    avg_score = sum(related) / len(related) if related else 0
    failure_patterns.append({
        "subagent": subagent,
        "failure_reason": reason,
        "count": count,
        "avg_score": round(avg_score, 2),
    })

# ================================================================
# Merge feedback memory into failure_patterns
# ================================================================
if feedback_dir and feedback_dir.exists():
    existing_fb_ids = {fp.get("feedback_id") for fp in failure_patterns if fp.get("feedback_id")}

    KNOWN_AGENTS = re.compile(
        r'(?:secretary|tech-researcher|retail-domain-researcher|project-manager|'
        r'system-architect|data-architect|lead-developer|backend-developer|'
        r'frontend-developer|test-engineer|sre-engineer|cloud-engineer|'
        r'ci-cd-engineer|qa-lead|knowledge-manager|ai-developer|'
        r'devops-coordinator|standards-lead|technical-writer)'
    )

    for fb_file in sorted(feedback_dir.glob("feedback_*.md")):
        fb_text = fb_file.read_text(encoding="utf-8", errors="ignore")
        fb_id = fb_file.stem

        # Skip if already merged
        if fb_id in existing_fb_ids:
            continue

        # Parse frontmatter
        fm_match = re.match(r'^---\s*\n(.*?)\n---\s*\n', fb_text, re.DOTALL)
        if not fm_match:
            continue
        fm = fm_match.group(1)

        # Verify type: feedback
        fb_type = ""
        for line in fm.split("\n"):
            m = re.match(r'type:\s*(.+)', line)
            if m:
                fb_type = m.group(1).strip()
        if fb_type != "feedback":
            continue

        # Extract name/description
        fb_name, fb_desc = "", ""
        for line in fm.split("\n"):
            m = re.match(r'name:\s*(.+)', line)
            if m:
                fb_name = m.group(1).strip()
            m = re.match(r'description:\s*(.+)', line)
            if m:
                fb_desc = m.group(1).strip()

        # Extract "How to apply" section
        how_match = re.search(
            r'\*\*How to apply:\*\*\s*(.*?)(?=\n##|\n\*\*Why|\n\*\*How to apply|\Z)',
            fb_text, re.DOTALL
        )
        how_to_apply = how_match.group(1).strip()[:200] if how_match else ""

        # Detect related subagent
        agents_found = KNOWN_AGENTS.findall(fb_text.lower())
        subagent = agents_found[0] if agents_found else "general"

        # Extract keywords for Read-phase matching
        keywords = [kw for kw in re.split(r'[\s、。「」【】（）・,\-]', fb_name + " " + fb_desc)
                    if len(kw) >= 2 and not kw.startswith("*")][:8]

        failure_patterns.append({
            "subagent": subagent,
            "failure_reason": fb_desc[:100] if fb_desc else fb_name[:100],
            "count": 1,
            "avg_score": 0.0,
            "source": "feedback-memory",
            "feedback_id": fb_id,
            "how_to_apply": how_to_apply,
            "match_keywords": keywords,
        })

# ================================================================
# Write index.json
# ================================================================
index = {
    "org_slug": org_slug,
    "updated_at": datetime.now().isoformat(timespec="seconds"),
    "case_count": len(cases),
    "failure_patterns": failure_patterns,
    "cases": cases,
}
index.update(extra_fields)

(case_bank_dir / "index.json").write_text(
    json.dumps(index, ensure_ascii=False, indent=2)
)
print(f"Case Bank: {len(cases)} cases")
PYEOF
}
