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

  python3 - "$task_log_dir" "$case_bank_dir" "$org_slug" <<'PYEOF'
import sys, re, json
from pathlib import Path
from datetime import datetime

task_log_dir = Path(sys.argv[1])
case_bank_dir = Path(sys.argv[2])
org_slug = sys.argv[3]

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
        # Keep conversation context
        if old_case.get("conversation_context"):
            new_case["conversation_context"] = old_case["conversation_context"]
        if old_case.get("conversation_enriched"):
            new_case["conversation_enriched"] = old_case["conversation_enriched"]

    cases.append(new_case)

# ================================================================
# Write index.json
# ================================================================
index = {
    "org_slug": org_slug,
    "updated_at": datetime.now().isoformat(timespec="seconds"),
    "case_count": len(cases),
    "cases": cases,
}
index.update(extra_fields)

(case_bank_dir / "index.json").write_text(
    json.dumps(index, ensure_ascii=False, indent=2)
)
print(f"Case Bank: {len(cases)} cases")
PYEOF
}
