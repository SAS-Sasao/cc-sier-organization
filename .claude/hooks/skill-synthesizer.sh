#!/usr/bin/env bash
# .claude/hooks/skill-synthesizer.sh
#
# Case Bank から既存 Skill にマッチしないパターンを検出し、
# 新規 SKILL.md を動的生成して PR で提案する。
# session-boundary.sh または /company-evolve から source して使う。

synthesize_skills() {
  local org_slug="$1"
  local operator="${2:-anonymous}"
  local today
  today=$(date '+%Y-%m-%d')
  local case_bank=".companies/${org_slug}/.case-bank/index.json"
  local synth_log=".companies/${org_slug}/.case-bank/synthesizer-log.json"
  local skills_dir=".claude/skills"

  [[ ! -f "$case_bank" ]] && return 0
  command -v python3 &>/dev/null || return 0

  python3 - "$case_bank" "$synth_log" "$skills_dir" "$org_slug" "$operator" "$today" <<'PYEOF'
import sys, re, json, os, subprocess
from pathlib import Path
from collections import defaultdict

case_bank_path = Path(sys.argv[1])
synth_log_path = Path(sys.argv[2])
skills_dir     = Path(sys.argv[3])
org_slug       = sys.argv[4]
operator       = sys.argv[5]
today          = sys.argv[6]

# --- 1. Case Bank 読み込み ---
try:
    index = json.loads(case_bank_path.read_text(encoding="utf-8"))
    cases = index.get("cases", [])
except Exception:
    sys.exit(0)

if not cases:
    sys.exit(0)

# --- 2. フィルタ: mode=direct, artifact_count>=2, reward>=0.5 ---
candidates = []
for c in cases:
    action = c.get("action", {})
    reward = c.get("reward")
    if (action.get("mode") == "direct"
        and action.get("artifact_count", 0) >= 2
        and reward is not None
        and reward >= 0.5):
        candidates.append(c)

if not candidates:
    print("Skill Synthesizer: no candidates")
    sys.exit(0)

# --- 3. request_head 先頭15文字でグルーピング ---
groups = defaultdict(list)
for c in candidates:
    key = c.get("state", {}).get("request_head", "")[:15].strip()
    if key:
        groups[key].append(c)

# --- 4. 3件以上のグループのみ ---
viable = {k: v for k, v in groups.items() if len(v) >= 3}
if not viable:
    print("Skill Synthesizer: no viable groups (need 3+)")
    sys.exit(0)

# --- 5. 既存 SKILL.md のトリガーワード収集 ---
existing_triggers = set()
for skill_md in skills_dir.glob("*/SKILL.md"):
    try:
        text = skill_md.read_text(encoding="utf-8", errors="ignore")
        # triggers from frontmatter
        for m in re.finditer(r'triggers:\s*\n((?:\s+-\s+.+\n)*)', text):
            for t in re.findall(r'-\s+"?([^"\n]+)"?', m.group(1)):
                existing_triggers.add(t.strip().lower())
        # triggers from description
        for m in re.finditer(r'「([^」]+)」', text):
            existing_triggers.add(m.group(1).strip().lower())
    except Exception:
        pass

# --- 6. synthesizer-log.json で生成済みチェック（べき等） ---
synth_log_data = {"generated": []}
if synth_log_path.exists():
    try:
        synth_log_data = json.loads(synth_log_path.read_text(encoding="utf-8"))
    except Exception:
        pass
generated_keys = set(synth_log_data.get("generated", []))

# --- 7. 各グループを処理 ---
new_skills = []
for pattern_key, group_cases in viable.items():
    # 既存トリガーとの重複チェック
    key_lower = pattern_key.lower()
    overlap = sum(1 for t in existing_triggers if t in key_lower or key_lower in t)
    if existing_triggers and overlap / max(len(existing_triggers), 1) > 0.5:
        continue

    # べき等チェック
    if pattern_key in generated_keys:
        continue

    # メトリクス計算
    rewards = [c["reward"] for c in group_cases if c.get("reward") is not None]
    avg_reward = round(sum(rewards) / len(rewards), 2) if rewards else 0
    n_cases = len(group_cases)

    # キーワード集約
    all_kw = []
    for c in group_cases:
        all_kw.extend(c.get("state", {}).get("request_keywords", []))
    # 頻出順
    kw_count = defaultdict(int)
    for kw in all_kw:
        kw_count[kw] += 1
    top_keywords = sorted(kw_count, key=kw_count.get, reverse=True)[:5]

    # 成果物ディレクトリ集約
    all_files = []
    for c in group_cases:
        all_files.extend(c.get("outcome", {}).get("files_written", []))
    output_dirs = list(dict.fromkeys(
        str(Path(f).parent) for f in all_files if f
    ))[:3]

    # slug 生成
    slug = re.sub(r'[^a-z0-9]+', '-', pattern_key.lower()).strip('-')[:30]
    if not slug:
        slug = f"auto-skill-{n_cases}"

    # triggers リスト
    triggers_yaml = "\n".join(f'  - "{kw}"' for kw in [pattern_key] + top_keywords)
    triggers_list = "\n".join(f"- 「{kw}」" for kw in [pattern_key] + top_keywords)
    output_section = "\n".join(f"- `{d}`" for d in output_dirs) if output_dirs else "- （Case Bank から自動検出）"

    skill_md = f"""---
name: {slug}
description: >
  {pattern_key}に関するタスクを処理する自動生成Skill。
  Case Bank の {n_cases} ケース（平均報酬: {avg_reward}）から自動生成。
  生成日: {today}
triggers:
{triggers_yaml}
---

# {slug} Skill（自動生成）

## 概要

Case Bank の高報酬ケースから自動生成された Skill です。
パターン「{pattern_key}」に一致するタスクを処理します。

## 起動条件

以下のトリガーワードに一致した場合に起動:
{triggers_list}

## 実行手順（高報酬ケースから抽出）

1. ユーザーの依頼内容を分析
2. 過去の高報酬パターンに基づいて実行計画を策定
3. 成果物を所定のディレクトリに生成
4. タスクログを記録

## 成果物

出力先ディレクトリ（実績ベース）:
{output_section}

## 注意事項

> **このファイルは Skill Synthesizer による自動生成です。**
> 内容を確認・編集してからマージしてください。
> 実行手順は Case Bank の実績から推定したものであり、正確性は保証されません。

## 生成メタデータ

```yaml
generator: skill-synthesizer
org_slug: {org_slug}
pattern_key: "{pattern_key}"
case_count: {n_cases}
avg_reward: {avg_reward}
top_keywords: {json.dumps(top_keywords, ensure_ascii=False)}
generated_at: "{today}"
```
"""

    new_skills.append({
        "slug": slug,
        "pattern_key": pattern_key,
        "content": skill_md,
        "n_cases": n_cases,
        "avg_reward": avg_reward,
    })

if not new_skills:
    print("Skill Synthesizer: all patterns already covered or generated")
    sys.exit(0)

# --- 8. Git ブランチ → ファイル書き込み → コミット → PR ---
for skill in new_skills:
    slug = skill["slug"]
    skill_dir = Path(f".claude/skills/{slug}")
    skill_dir.mkdir(parents=True, exist_ok=True)
    (skill_dir / "SKILL.md").write_text(skill["content"], encoding="utf-8")

    # synthesizer-log に記録
    synth_log_data["generated"].append(skill["pattern_key"])

branch = f"{org_slug}/admin/{today}-skill-synthesizer"
slugs = ", ".join(s["slug"] for s in new_skills)
commit_msg = f"feat: Skill Synthesizer が {len(new_skills)} 件の新規 Skill を生成 [{org_slug}] by {operator}"

try:
    subprocess.run(["git", "checkout", "-b", branch], check=True,
                   capture_output=True, text=True)
    for skill in new_skills:
        subprocess.run(["git", "add", f".claude/skills/{skill['slug']}/SKILL.md"],
                       check=True, capture_output=True, text=True)
    subprocess.run(["git", "commit", "-m", commit_msg], check=True,
                   capture_output=True, text=True)
    subprocess.run(["git", "push", "-u", "origin", branch], check=True,
                   capture_output=True, text=True)

    # ラベル作成
    subprocess.run(["gh", "label", "create", "skill-synthesizer",
                    "--color", "5319e7", "--description",
                    "Skill Synthesizer 自動生成", "--force"],
                   capture_output=True, text=True)
    subprocess.run(["gh", "label", "create", f"org:{org_slug}",
                    "--color", "7057ff", "--description",
                    f"組織: {org_slug}", "--force"],
                   capture_output=True, text=True)

    pr_body = f"## Skill Synthesizer 自動生成\n\n"
    for s in new_skills:
        pr_body += f"- **{s['slug']}**: パターン「{s['pattern_key']}」（{s['n_cases']}件, 平均報酬: {s['avg_reward']}）\n"
    pr_body += f"\n> 自動生成された SKILL.md です。内容を確認・編集してからマージしてください。"

    result = subprocess.run(
        ["gh", "pr", "create",
         "--title", f"feat: 新規 Skill 自動生成 ({slugs}) [{org_slug}]",
         "--body", pr_body,
         "--label", "skill-synthesizer",
         "--label", f"org:{org_slug}"],
        capture_output=True, text=True
    )
    if result.returncode == 0:
        print(f"Skill Synthesizer: {len(new_skills)} skills created, PR: {result.stdout.strip()}")
    else:
        print(f"Skill Synthesizer: {len(new_skills)} skills created (PR creation failed: {result.stderr.strip()})")

    subprocess.run(["git", "checkout", "main"], capture_output=True, text=True)
except subprocess.CalledProcessError as e:
    print(f"Skill Synthesizer: Git error: {e.stderr.strip() if e.stderr else e}")
    subprocess.run(["git", "checkout", "main"], capture_output=True, text=True)

# synthesizer-log 保存
synth_log_path.parent.mkdir(parents=True, exist_ok=True)
synth_log_path.write_text(
    json.dumps(synth_log_data, ensure_ascii=False, indent=2),
    encoding="utf-8"
)
PYEOF
}
