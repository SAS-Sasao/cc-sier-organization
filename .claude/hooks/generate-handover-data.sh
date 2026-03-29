#!/usr/bin/env bash
# generate-handover-data.sh — ナレッジポータル用 data.json 生成
set -uo pipefail

ORG_SLUG="${1:-}"
if [[ -z "$ORG_SLUG" ]]; then
  [[ -f ".companies/.active" ]] || { echo "No active org" >&2; exit 1; }
  ORG_SLUG=$(tr -d '[:space:]' < ".companies/.active")
fi

ORG_DIR=".companies/${ORG_SLUG}"
[[ -d "$ORG_DIR" ]] || { echo "Org not found: ${ORG_SLUG}" >&2; exit 1; }

OUTPUT_DIR="docs/handover"
mkdir -p "$OUTPUT_DIR"
OUTPUT="${OUTPUT_DIR}/data.json"

echo "Generating handover data.json for ${ORG_SLUG}..."

# Collect memory dir path
MEMORY_DIR=""
for d in "$HOME/.claude/projects/"*"/memory"; do
  if [[ -d "$d" ]]; then
    MEMORY_DIR="$d"
    break
  fi
done

python3 - "$ORG_DIR" "$ORG_SLUG" "$OUTPUT" "$MEMORY_DIR" <<'PYEOF'
import sys, json, re, os, subprocess, hashlib
from pathlib import Path
from datetime import datetime

org_dir = Path(sys.argv[1])
org_slug = sys.argv[2]
output_path = Path(sys.argv[3])
memory_dir = Path(sys.argv[4]) if sys.argv[4] else None
now = datetime.now().strftime("%Y-%m-%dT%H:%M:%S")

entries = []
decisions = []
tips = []
entry_id = 0

def next_id(prefix="entry"):
    global entry_id
    entry_id += 1
    return f"{prefix}-{entry_id:04d}"

def safe_json_str(s):
    if not s:
        return ""
    return s.replace("\x00", "").strip()

# ============================================================
# Source 1: Git log — all commits
# ============================================================
try:
    result = subprocess.run(
        ["git", "log", "--all", "--format=%H\t%ai\t%s\t%an", "--no-merges"],
        capture_output=True, text=True, timeout=30
    )
    for line in result.stdout.strip().splitlines():
        parts = line.split("\t", 3)
        if len(parts) < 4:
            continue
        commit_hash, date_str, subject, author = parts
        date = date_str[:10]

        # Category detection
        category = "project"
        subcategory = ""
        tags = []

        subj_lower = subject.lower()
        if any(kw in subj_lower for kw in ["skill", "mcp", "hook", "agent", ".mcp.json"]):
            category = "platform"
            if "skill" in subj_lower:
                subcategory = "skill"
            elif "mcp" in subj_lower:
                subcategory = "mcp"
            elif "hook" in subj_lower:
                subcategory = "hook"
            elif "agent" in subj_lower:
                subcategory = "agent"
        elif any(kw in subj_lower for kw in ["evolve", "learning", "case bank", "reward", "case-bank"]):
            category = "learning"
        elif any(kw in subj_lower for kw in ["部署", "ロール", "ワークフロー", "masters/", "admin"]):
            category = "organization"
        elif any(kw in subj_lower for kw in ["chore: ダッシュボード", "chore: ナレッジ"]):
            category = "platform"
            subcategory = "config"

        # Detect changed files for better categorization
        try:
            files_result = subprocess.run(
                ["git", "diff-tree", "--no-commit-id", "--name-only", "-r", commit_hash],
                capture_output=True, text=True, timeout=10
            )
            changed_files = [f for f in files_result.stdout.strip().splitlines() if f]

            has_skill = any("skills/" in f for f in changed_files)
            has_agent = any("agents/" in f for f in changed_files)
            has_hook = any("hooks/" in f for f in changed_files)
            has_master = any("masters/" in f for f in changed_files)
            has_mcp = any(".mcp.json" in f for f in changed_files)

            if has_skill or has_hook or has_mcp:
                category = "platform"
                if has_skill:
                    subcategory = "skill"
                elif has_hook:
                    subcategory = "hook"
                elif has_mcp:
                    subcategory = "mcp"
            elif has_agent and not has_master:
                category = "platform"
                subcategory = "agent"
            elif has_master:
                category = "organization"
        except Exception:
            changed_files = []

        # Extract commit type
        commit_type = ""
        type_match = re.match(r'^(\w+):', subject)
        if type_match:
            commit_type = type_match.group(1)

        # Extract tags from subject
        words = re.findall(r'[a-zA-Z\-]{3,}', subject)
        tags = list(set(w.lower() for w in words[:5]))

        entry = {
            "id": next_id(),
            "date": date,
            "category": category,
            "title": safe_json_str(subject),
            "description": "",
            "source": "git-log",
            "source_ref": commit_hash[:7],
            "tags": tags,
            "related_files": changed_files[:10],
            "metadata": {
                "commit_hash": commit_hash[:7],
                "commit_type": commit_type,
                "author": safe_json_str(author)
            }
        }
        if subcategory:
            entry["subcategory"] = subcategory
        entries.append(entry)
except Exception as e:
    print(f"Warning: git log collection failed: {e}", file=sys.stderr)

# ============================================================
# Source 2: Task logs
# ============================================================
task_log_dir = org_dir / ".task-log"
if task_log_dir.exists():
    for f in sorted(task_log_dir.glob("*.md")):
        try:
            text = f.read_text(encoding="utf-8", errors="ignore")

            # Extract date from filename (YYYYMMDD-HHMMSS-slug.md)
            fname = f.stem
            date = ""
            date_match = re.match(r'(\d{4})(\d{2})(\d{2})', fname)
            if date_match:
                date = f"{date_match.group(1)}-{date_match.group(2)}-{date_match.group(3)}"

            # Extract fields from frontmatter/content
            title = ""
            subagent = ""
            mode = ""
            reward = None
            judge_total = None
            artifacts = []

            for line in text.splitlines():
                if line.startswith("# "):
                    title = line[2:].strip()
                m = re.match(r'^-\s*\*\*subagent\*\*:\s*(.+)', line)
                if m:
                    subagent = m.group(1).strip()
                m = re.match(r'^-\s*\*\*mode\*\*:\s*(.+)', line)
                if m:
                    mode = m.group(1).strip()
                m = re.match(r'^-\s*\*\*reward\*\*:\s*([\d.]+)', line)
                if m:
                    try:
                        reward = float(m.group(1))
                    except ValueError:
                        pass
                m = re.match(r'^-\s*\*\*total\*\*:\s*([\d.]+)', line)
                if m:
                    try:
                        judge_total = float(m.group(1))
                    except ValueError:
                        pass
                if "docs/" in line and line.strip().startswith("- "):
                    path_match = re.search(r'(\.companies/[^\s]+|docs/[^\s]+)', line)
                    if path_match:
                        artifacts.append(path_match.group(1))

            # Determine category based on subagent/mode
            category = "project"
            if any(kw in subagent.lower() for kw in ["devops", "ci-cd"]):
                category = "platform"
            elif "admin" in mode.lower() if mode else False:
                category = "organization"

            entry = {
                "id": next_id(),
                "date": date,
                "category": category,
                "title": safe_json_str(title) or fname,
                "description": "",
                "source": "task-log",
                "source_ref": f.name,
                "tags": [t for t in [subagent, mode] if t],
                "related_files": artifacts[:5],
                "metadata": {}
            }
            if subagent:
                entry["metadata"]["subagent"] = subagent
            if mode:
                entry["metadata"]["mode"] = mode
            if reward is not None:
                entry["metadata"]["reward"] = reward
            if judge_total is not None:
                entry["metadata"]["judge_total"] = judge_total

            entries.append(entry)
        except Exception as e:
            print(f"Warning: task-log parse failed for {f}: {e}", file=sys.stderr)

# ============================================================
# Source 3: Conversation logs
# ============================================================
conv_log_dir = org_dir / ".conversation-log"
if conv_log_dir.exists():
    task_log_dates = set()
    if task_log_dir.exists():
        for f in task_log_dir.glob("*.md"):
            m = re.match(r'(\d{8})', f.stem)
            if m:
                task_log_dates.add(m.group(1))

    for f in sorted(conv_log_dir.glob("*.md")):
        try:
            text = f.read_text(encoding="utf-8", errors="ignore")
            fname = f.stem

            date = ""
            date_match = re.match(r'(\d{4})(\d{2})(\d{2})', fname)
            if date_match:
                date = f"{date_match.group(1)}-{date_match.group(2)}-{date_match.group(3)}"

            # Extract human utterances
            human_lines = []
            in_human = False
            for line in text.splitlines():
                if "## " in line and "Human" in line:
                    in_human = True
                    continue
                elif line.startswith("## "):
                    in_human = False
                elif in_human and line.strip() and not line.startswith("---"):
                    cleaned = re.sub(r'^[-*]\s*', '', line.strip())
                    if cleaned and len(cleaned) > 5:
                        human_lines.append(cleaned)

            # Extract stats
            session_stats = {}
            stats_match = re.search(r'Human発言:\s*(\d+)', text)
            if stats_match:
                session_stats["human_count"] = int(stats_match.group(1))
            stats_match = re.search(r'ツール実行:\s*(\d+)', text)
            if stats_match:
                session_stats["tool_count"] = int(stats_match.group(1))

            # Determine if discussion (no corresponding task-log)
            date_compact = date.replace("-", "")
            is_discussion = date_compact not in task_log_dates

            category = "discussion" if is_discussion else "project"

            # Check for platform-related discussions
            text_lower = text.lower()
            if any(kw in text_lower for kw in ["skill", "mcp", "hook", "壁打ち", "構想"]):
                if is_discussion:
                    category = "discussion"

            summary = "; ".join(human_lines[:5]) if human_lines else fname
            if len(summary) > 200:
                summary = summary[:200] + "..."

            entry = {
                "id": next_id(),
                "date": date,
                "category": category,
                "title": safe_json_str(summary[:100]),
                "description": safe_json_str(summary),
                "source": "conversation-log",
                "source_ref": f.name,
                "tags": [],
                "related_files": [],
                "metadata": session_stats
            }
            entries.append(entry)
        except Exception as e:
            print(f"Warning: conversation-log parse failed for {f}: {e}", file=sys.stderr)

# ============================================================
# Source 4: Case Bank
# ============================================================
case_bank_path = org_dir / ".case-bank" / "index.json"
if case_bank_path.exists():
    try:
        cases = json.loads(case_bank_path.read_text(encoding="utf-8", errors="ignore"))
        if isinstance(cases, list):
            for case in cases:
                if not isinstance(case, dict):
                    continue
                reward = case.get("reward")
                if reward is not None and isinstance(reward, (int, float)) and reward >= 0.8:
                    tips.append({
                        "id": next_id("tip"),
                        "title": safe_json_str(case.get("request_summary", case.get("task_id", ""))),
                        "content": safe_json_str(case.get("judge_comment", case.get("failure_reason", ""))),
                        "reward": reward,
                        "source": "case-bank",
                        "source_ref": case.get("task_id", ""),
                        "subagent": case.get("subagent", ""),
                        "tags": case.get("request_keywords", [])
                    })
    except Exception as e:
        print(f"Warning: case-bank parse failed: {e}", file=sys.stderr)

# ============================================================
# Source 5: Feedback memories
# ============================================================
if memory_dir and memory_dir.exists():
    for f in sorted(memory_dir.glob("feedback_*.md")):
        try:
            text = f.read_text(encoding="utf-8", errors="ignore")

            # Extract frontmatter
            title = f.stem.replace("feedback_", "").replace("_", " ")
            description = ""

            # Parse frontmatter
            fm_match = re.search(r'^---\s*\n(.*?)\n---', text, re.DOTALL)
            if fm_match:
                fm = fm_match.group(1)
                name_match = re.search(r'name:\s*(.+)', fm)
                if name_match:
                    title = name_match.group(1).strip()
                desc_match = re.search(r'description:\s*(.+)', fm)
                if desc_match:
                    description = desc_match.group(1).strip()

            # Extract body (after frontmatter)
            body = re.sub(r'^---\s*\n.*?\n---\s*\n', '', text, flags=re.DOTALL).strip()

            # Extract reason
            reason = ""
            reason_match = re.search(r'\*\*Why:\*\*\s*(.+)', body)
            if reason_match:
                reason = reason_match.group(1).strip()

            decisions.append({
                "id": next_id("dec"),
                "date": "",
                "title": safe_json_str(title),
                "rule": safe_json_str(body[:300]),
                "reason": safe_json_str(reason or description),
                "source": "feedback_memory",
                "source_ref": f.name
            })
        except Exception as e:
            print(f"Warning: feedback memory parse failed for {f}: {e}", file=sys.stderr)

# ============================================================
# Source 6: Session summaries
# ============================================================
session_dir = org_dir / ".session-summaries"
if session_dir.exists():
    for f in sorted(session_dir.glob("*.json")):
        try:
            data = json.loads(f.read_text(encoding="utf-8", errors="ignore"))
            if not isinstance(data, dict):
                continue

            date = ""
            date_match = re.match(r'(\d{4})(\d{2})(\d{2})', f.stem)
            if date_match:
                date = f"{date_match.group(1)}-{date_match.group(2)}-{date_match.group(3)}"

            tool_count = data.get("tool_count", 0)
            written = data.get("written_files", [])

            # Only add if not already covered by task-log or conversation-log
            # (session summaries are supplementary)
            if not written:
                # No files written = likely a discussion
                entry = {
                    "id": next_id(),
                    "date": date,
                    "category": "discussion",
                    "title": f"Session {f.stem} (tools: {tool_count})",
                    "description": f"Tool executions: {tool_count}, No files written",
                    "source": "session-summary",
                    "source_ref": f.name,
                    "tags": [],
                    "related_files": [],
                    "metadata": {"tool_count": tool_count}
                }
                entries.append(entry)
        except Exception as e:
            pass

# ============================================================
# Source 7: GitHub Issues & PRs
# ============================================================
try:
    result = subprocess.run(
        ["gh", "issue", "list", "--state", "all", "--json",
         "number,title,state,createdAt,closedAt,labels", "--limit", "100"],
        capture_output=True, text=True, timeout=30
    )
    if result.returncode == 0:
        issues = json.loads(result.stdout)
        for issue in issues:
            if not isinstance(issue, dict):
                continue
            created = issue.get("createdAt", "")[:10]
            labels = [l.get("name", "") for l in issue.get("labels", []) if isinstance(l, dict)]

            # Skip interaction-log issues
            if "interaction-log" in labels:
                continue

            category = "project"
            if any("company-report" in l for l in labels):
                category = "learning"
            elif any("admin" in l for l in labels):
                category = "organization"

            entry = {
                "id": next_id(),
                "date": created,
                "category": category,
                "title": safe_json_str(f"#{issue.get('number', '')} {issue.get('title', '')}"),
                "description": "",
                "source": "github-issue",
                "source_ref": str(issue.get("number", "")),
                "tags": [l for l in labels if l],
                "related_files": [],
                "metadata": {
                    "state": issue.get("state", ""),
                    "number": issue.get("number", 0)
                }
            }
            entries.append(entry)
except Exception as e:
    print(f"Warning: GitHub issue collection failed: {e}", file=sys.stderr)

try:
    result = subprocess.run(
        ["gh", "pr", "list", "--state", "all", "--json",
         "number,title,state,createdAt,mergedAt,labels", "--limit", "100"],
        capture_output=True, text=True, timeout=30
    )
    if result.returncode == 0:
        prs = json.loads(result.stdout)
        for pr in prs:
            if not isinstance(pr, dict):
                continue
            created = pr.get("createdAt", "")[:10]

            title = pr.get("title", "")
            category = "project"
            title_lower = title.lower()
            if any(kw in title_lower for kw in ["skill", "mcp", "hook", "agent"]):
                category = "platform"
            elif any(kw in title_lower for kw in ["evolve", "learning", "reward"]):
                category = "learning"
            elif any(kw in title_lower for kw in ["admin", "部署", "ロール"]):
                category = "organization"

            entry = {
                "id": next_id(),
                "date": created,
                "category": category,
                "title": safe_json_str(f"PR #{pr.get('number', '')} {title}"),
                "description": "",
                "source": "github-pr",
                "source_ref": str(pr.get("number", "")),
                "tags": [],
                "related_files": [],
                "metadata": {
                    "state": pr.get("state", ""),
                    "number": pr.get("number", 0),
                    "merged": bool(pr.get("mergedAt"))
                }
            }
            entries.append(entry)
except Exception as e:
    print(f"Warning: GitHub PR collection failed: {e}", file=sys.stderr)

# ============================================================
# Deduplicate & sort
# ============================================================

# Sort by date descending
entries.sort(key=lambda e: e.get("date", ""), reverse=True)

# Remove duplicates by similar title+date
seen = set()
unique_entries = []
for e in entries:
    key = f"{e['date']}:{e['title'][:50]}"
    if key not in seen:
        seen.add(key)
        unique_entries.append(e)
entries = unique_entries

# Summary
by_category = {}
for e in entries:
    cat = e.get("category", "other")
    by_category[cat] = by_category.get(cat, 0) + 1

dates = [e["date"] for e in entries if e.get("date")]

output_data = {
    "generated_at": now,
    "org_slug": org_slug,
    "summary": {
        "total_entries": len(entries),
        "by_category": by_category,
        "date_range": {
            "earliest": min(dates) if dates else "",
            "latest": max(dates) if dates else ""
        },
        "total_decisions": len(decisions),
        "total_tips": len(tips)
    },
    "entries": entries,
    "decisions": decisions,
    "tips": tips
}

output_path.parent.mkdir(parents=True, exist_ok=True)
output_path.write_text(
    json.dumps(output_data, ensure_ascii=False, indent=2),
    encoding="utf-8"
)

print(f"Generated {output_path}: {len(entries)} entries, {len(decisions)} decisions, {len(tips)} tips")
print(f"Categories: {json.dumps(by_category, ensure_ascii=False)}")
PYEOF

echo "Done: ${OUTPUT}"
