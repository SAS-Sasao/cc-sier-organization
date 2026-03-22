#!/usr/bin/env bash
# task-log/*.md を走査して .case-bank/index.json を再構築する

rebuild_case_bank() {
  local org_slug="$1"
  local task_log_dir=".companies/${org_slug}/.task-log"
  local case_bank_dir=".companies/${org_slug}/.case-bank"

  [[ ! -d "$task_log_dir" ]] && return 0
  command -v python3 &>/dev/null || return 0
  mkdir -p "$case_bank_dir"

  python3 - "$task_log_dir" "$case_bank_dir" <<'PYEOF'
import sys, re, json
from pathlib import Path
import datetime

task_log_dir = Path(sys.argv[1])
case_bank_dir = Path(sys.argv[2])
cases = []

for md_file in sorted(task_log_dir.glob("*.md")):
    text = md_file.read_text(encoding="utf-8", errors="ignore")

    fm = {}
    fm_block = re.search(r'^---\n(.*?)\n---', text, re.DOTALL)
    if fm_block:
        for line in fm_block.group(1).splitlines():
            m = re.match(r'^(\w+):\s*"?(.*?)"?\s*$', line)
            if m:
                fm[m.group(1)] = m.group(2)

    task_id = fm.get("task_id", md_file.stem)
    status  = fm.get("status", "")
    mode    = fm.get("mode", "")
    started = fm.get("started", "")
    request = fm.get("request", "")
    org     = fm.get("org", "")

    reward_score = None
    m = re.search(r'score:\s*([\d.]+)', text)
    if m:
        try:
            reward_score = float(m.group(1))
        except ValueError:
            pass

    artifacts = list(dict.fromkeys(re.findall(r'`(\.companies/[^`]+)`', text)))
    subagents = re.findall(r'secretary\s*→\s*(\S+)', text)
    primary_subagent = subagents[0] if subagents else ""

    keywords = [kw for kw in re.split(r'[\s、。「」【】（）・,]', request)
                if len(kw) >= 2][:8]

    cases.append({
        "id": task_id,
        "state": {
            "request_keywords": keywords,
            "request_head": request[:30],
            "org_slug": org,
        },
        "action": {
            "subagent": primary_subagent,
            "mode": mode,
            "artifact_count": len(artifacts),
        },
        "reward": reward_score,
        "outcome": {
            "files_written": artifacts[:5],
            "started": started,
        },
    })

index = {
    "org_slug": case_bank_dir.parent.name,
    "updated_at": datetime.datetime.now().isoformat(timespec="seconds"),
    "case_count": len(cases),
    "cases": cases,
}

(case_bank_dir / "index.json").write_text(
    json.dumps(index, ensure_ascii=False, indent=2)
)
print(f"Case Bank: {len(cases)} cases")
PYEOF
}
