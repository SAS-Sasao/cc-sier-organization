#!/usr/bin/env bash
# .claude/hooks/subagent-refiner.sh
#
# Case Bank の実績をもとに既存 Subagent を精緻化（Refiner）し、
# 対応 Subagent がないパターンには新規 Subagent を生成（Spawner）する。
# session-boundary.sh または /company-evolve から source して使う。

refine_subagents() {
  local org_slug="$1"
  local operator="${2:-anonymous}"
  local today
  today=$(date '+%Y-%m-%d')
  local case_bank=".companies/${org_slug}/.case-bank/index.json"
  local refiner_log=".companies/${org_slug}/.case-bank/refiner-log.json"
  local agents_dir=".claude/agents"

  [[ ! -f "$case_bank" ]] && return 0
  command -v python3 &>/dev/null || return 0

  python3 - "$case_bank" "$refiner_log" "$agents_dir" "$org_slug" "$operator" "$today" <<'PYEOF'
import sys, re, json, os, subprocess
from pathlib import Path
from collections import defaultdict

case_bank_path = Path(sys.argv[1])
refiner_log_path = Path(sys.argv[2])
agents_dir     = Path(sys.argv[3])
org_slug       = sys.argv[4]
operator       = sys.argv[5]
today          = sys.argv[6]

# --- Case Bank 読み込み ---
try:
    index = json.loads(case_bank_path.read_text(encoding="utf-8"))
    cases = index.get("cases", [])
except Exception:
    sys.exit(0)

if not cases:
    sys.exit(0)

# --- refiner-log 読み込み ---
refiner_data = {"refined": {}, "spawned": []}
if refiner_log_path.exists():
    try:
        refiner_data = json.loads(refiner_log_path.read_text(encoding="utf-8"))
    except Exception:
        pass

changes_made = False

# ========================================================
# Part 1: Refiner — 既存 Subagent の精緻化
# ========================================================
# subagent ごとに実績を集計
agent_stats = defaultdict(lambda: {
    "rewards": [],
    "keywords": defaultdict(int),
    "output_dirs": defaultdict(int),
    "low_reward_heads": [],
    "high_reward_heads": [],
    "case_count": 0,
})

for c in cases:
    agent_name = c.get("action", {}).get("subagent", "")
    if not agent_name:
        continue
    stats = agent_stats[agent_name]
    stats["case_count"] += 1
    reward = c.get("reward")
    if reward is not None:
        stats["rewards"].append(reward)
        head = c.get("state", {}).get("request_head", "")
        if reward < 0.4:
            stats["low_reward_heads"].append((head, reward))
        elif reward >= 0.7:
            stats["high_reward_heads"].append(head)
    for kw in c.get("state", {}).get("request_keywords", []):
        stats["keywords"][kw] += 1
    for f in c.get("outcome", {}).get("files_written", []):
        if f:
            d = str(Path(f).parent)
            stats["output_dirs"][d] += 1

refined_agents = []
for agent_name, stats in agent_stats.items():
    agent_file = agents_dir / f"{agent_name}.md"
    if not agent_file.exists():
        continue
    # secretary.md は除外
    if agent_name == "secretary":
        continue

    # べき等チェック: 前回の case_count との差が3未満ならスキップ
    prev_count = refiner_data.get("refined", {}).get(agent_name, {}).get("case_count", 0)
    if stats["case_count"] - prev_count < 3:
        continue

    avg_reward = round(sum(stats["rewards"]) / len(stats["rewards"]), 2) if stats["rewards"] else None
    top_keywords = sorted(stats["keywords"], key=stats["keywords"].get, reverse=True)[:8]
    top_dirs = sorted(stats["output_dirs"], key=stats["output_dirs"].get, reverse=True)[:5]

    # 精緻化セクション生成
    refined_cap = f"\n## refined_capabilities（{today} 自動更新）\n\n"
    refined_cap += "Case Bank の実績から導出した本 subagent の得意領域:\n"
    for head in stats["high_reward_heads"][:5]:
        refined_cap += f"- 「{head}」タイプのタスク（実績あり）\n"
    if top_keywords:
        refined_cap += f"\n頻出キーワード: " + "、".join(f"「{kw}」" for kw in top_keywords) + "\n"

    output_fmt = f"\n## output_format（{today} 自動更新）\n\n"
    output_fmt += "過去の高報酬ケースで生成された成果物の出力先:\n"
    for d in top_dirs:
        count = stats["output_dirs"][d]
        output_fmt += f"- `{d}`（{count}件）\n"

    constraints = f"\n## constraints（{today} 自動更新）\n\n"
    if stats["low_reward_heads"]:
        constraints += "低報酬ケース（reward < 0.4）から導出した注意事項:\n"
        for head, r in stats["low_reward_heads"][:5]:
            constraints += f"- 「{head}」（報酬:{r}）パターンは注意\n"
    else:
        constraints += "低報酬ケースなし（良好）\n"

    new_sections = refined_cap + output_fmt + constraints

    # 既存ファイルの末尾に追記（既存の精緻化ブロックは置換）
    content = agent_file.read_text(encoding="utf-8")
    # 既存の精緻化ブロックを除去（## refined_capabilities 以降を全削除）
    content = re.sub(
        r'\n## refined_capabilities（.*$',
        '',
        content,
        flags=re.DOTALL
    )
    # 既存の output_format 自動更新ブロックも除去
    content = re.sub(
        r'\n## output_format（.*?(?=\n## |\Z)',
        '',
        content,
        flags=re.DOTALL
    )
    # 既存の constraints 自動更新ブロックも除去
    content = re.sub(
        r'\n## constraints（.*?(?=\n## |\Z)',
        '',
        content,
        flags=re.DOTALL
    )
    content = content.rstrip() + "\n" + new_sections

    agent_file.write_text(content, encoding="utf-8")

    refiner_data.setdefault("refined", {})[agent_name] = {
        "case_count": stats["case_count"],
        "avg_reward": avg_reward,
        "updated_at": today,
    }
    refined_agents.append(agent_name)
    changes_made = True

# ========================================================
# Part 2: Spawner — 新規 Subagent 生成
# ========================================================
# mode=direct, artifact_count>=2, reward>=0.5 のケースをグルーピング
direct_cases = []
for c in cases:
    action = c.get("action", {})
    reward = c.get("reward")
    if (action.get("mode") == "direct"
        and action.get("artifact_count", 0) >= 2
        and reward is not None
        and reward >= 0.5):
        direct_cases.append(c)

groups = defaultdict(list)
for c in direct_cases:
    key = c.get("state", {}).get("request_head", "")[:15].strip()
    if key:
        groups[key].append(c)

spawned_keys = set(refiner_data.get("spawned", []))
existing_agents = set(p.stem for p in agents_dir.glob("*.md"))

spawned_agents = []
for pattern_key, group_cases in groups.items():
    if len(group_cases) < 3:
        continue

    rewards = [c["reward"] for c in group_cases if c.get("reward") is not None]
    avg_reward = round(sum(rewards) / len(rewards), 2) if rewards else 0
    if avg_reward < 0.5:
        continue

    # slug 生成
    slug = re.sub(r'[^a-z0-9]+', '-', pattern_key.lower()).strip('-')[:30]
    if not slug:
        slug = f"auto-agent-{len(group_cases)}"

    # 既存エージェントチェック
    if slug in existing_agents:
        continue
    # べき等チェック
    if pattern_key in spawned_keys:
        continue

    n_cases = len(group_cases)
    all_kw = []
    for c in group_cases:
        all_kw.extend(c.get("state", {}).get("request_keywords", []))
    kw_count = defaultdict(int)
    for kw in all_kw:
        kw_count[kw] += 1
    top_keywords = sorted(kw_count, key=kw_count.get, reverse=True)[:5]

    all_files = []
    for c in group_cases:
        all_files.extend(c.get("outcome", {}).get("files_written", []))
    output_dirs = list(dict.fromkeys(
        str(Path(f).parent) for f in all_files if f
    ))[:3]

    high_heads = [c.get("state", {}).get("request_head", "")
                  for c in group_cases
                  if c.get("reward") is not None and c["reward"] >= 0.7]

    kw_list = "\n".join(f"- 「{kw}」" for kw in top_keywords) if top_keywords else "- （Case Bank から自動検出）"
    dir_list = "\n".join(f"- `{d}`" for d in output_dirs) if output_dirs else "- （Case Bank から自動検出）"
    head_list = "\n".join(f"- 「{h}」タイプのタスク" for h in high_heads[:5]) if high_heads else "- （高報酬ケースの実績から推定）"

    agent_md = f"""---
name: {slug}
description: >
  {pattern_key}に特化した自動生成サブエージェント。
  Case Bank の {n_cases} ケース（平均報酬: {avg_reward}）から Subagent Spawner が生成。
  生成日: {today}
---

# {slug}（自動生成 Subagent）

## 役割

「{pattern_key}」に関するタスクを専門的に処理するサブエージェント。
Case Bank の実績データに基づいて自動生成されました。

## 得意領域（Case Bank 実績より）

{head_list}

頻出キーワード: {", ".join(f"「{kw}」" for kw in top_keywords)}

## 実行手順（高報酬ケースから抽出）

1. ユーザーの依頼内容を分析し、過去の高報酬パターンと照合
2. 成果物の構成を決定（実績ベースの出力ディレクトリを優先）
3. タスクを実行し、成果物を生成
4. タスクログを記録して完了報告

## output_format

出力先ディレクトリ（実績ベース）:
{dir_list}

## constraints

> **このファイルは Subagent Spawner による自動生成です。**
> 内容を確認・編集してからマージしてください。
> 実行手順は Case Bank の実績から推定したものであり、正確性は保証されません。

## 生成メタデータ

```yaml
generator: subagent-spawner
org_slug: {org_slug}
pattern_key: "{pattern_key}"
case_count: {n_cases}
avg_reward: {avg_reward}
top_keywords: {json.dumps(top_keywords, ensure_ascii=False)}
generated_at: "{today}"
```
"""

    agent_file = agents_dir / f"{slug}.md"
    agent_file.write_text(agent_md, encoding="utf-8")

    refiner_data.setdefault("spawned", []).append(pattern_key)
    spawned_agents.append(slug)
    changes_made = True

# ========================================================
# Part 3: Git + PR（変更がある場合のみ）
# ========================================================
if changes_made:
    branch = f"{org_slug}/admin/{today}-subagent-refiner"
    parts = []
    if refined_agents:
        parts.append(f"精緻化: {', '.join(refined_agents)}")
    if spawned_agents:
        parts.append(f"新規生成: {', '.join(spawned_agents)}")
    commit_msg = f"feat: Subagent Refiner/Spawner による自動精緻化 [{org_slug}] by {operator}"

    try:
        subprocess.run(["git", "checkout", "-b", branch], check=True,
                       capture_output=True, text=True)

        # 精緻化されたファイルを add
        for name in refined_agents:
            subprocess.run(["git", "add", f".claude/agents/{name}.md"],
                           check=True, capture_output=True, text=True)
        # 新規生成されたファイルを add
        for name in spawned_agents:
            subprocess.run(["git", "add", f".claude/agents/{name}.md"],
                           check=True, capture_output=True, text=True)

        subprocess.run(["git", "commit", "-m", commit_msg], check=True,
                       capture_output=True, text=True)
        subprocess.run(["git", "push", "-u", "origin", branch], check=True,
                       capture_output=True, text=True)

        # ラベル作成
        subprocess.run(["gh", "label", "create", "subagent-refiner",
                        "--color", "0e8a16", "--description",
                        "Subagent Refiner/Spawner 自動生成", "--force"],
                       capture_output=True, text=True)
        subprocess.run(["gh", "label", "create", f"org:{org_slug}",
                        "--color", "7057ff", "--description",
                        f"組織: {org_slug}", "--force"],
                       capture_output=True, text=True)

        pr_body = "## Subagent Refiner/Spawner 自動精緻化\n\n"
        if refined_agents:
            pr_body += "### 精緻化された Subagent\n"
            for name in refined_agents:
                info = refiner_data["refined"].get(name, {})
                pr_body += f"- **{name}**（{info.get('case_count', '?')}件, 平均報酬: {info.get('avg_reward', '?')}）\n"
        if spawned_agents:
            pr_body += "\n### 新規生成された Subagent\n"
            for name in spawned_agents:
                pr_body += f"- **{name}**\n"
        pr_body += "\n> 自動生成・精緻化された内容です。確認・編集してからマージしてください。"

        result = subprocess.run(
            ["gh", "pr", "create",
             "--title", f"feat: Subagent 自動精緻化 ({'; '.join(parts)}) [{org_slug}]",
             "--body", pr_body,
             "--label", "subagent-refiner",
             "--label", f"org:{org_slug}"],
            capture_output=True, text=True
        )
        if result.returncode == 0:
            print(f"Subagent Refiner: {'; '.join(parts)}, PR: {result.stdout.strip()}")
        else:
            print(f"Subagent Refiner: {'; '.join(parts)} (PR failed: {result.stderr.strip()})")

        subprocess.run(["git", "checkout", "main"], capture_output=True, text=True)
    except subprocess.CalledProcessError as e:
        print(f"Subagent Refiner: Git error: {e.stderr.strip() if e.stderr else e}")
        subprocess.run(["git", "checkout", "main"], capture_output=True, text=True)
else:
    print("Subagent Refiner: no changes needed")

# --- refiner-log 保存 ---
refiner_log_path.parent.mkdir(parents=True, exist_ok=True)
refiner_log_path.write_text(
    json.dumps(refiner_data, ensure_ascii=False, indent=2),
    encoding="utf-8"
)
PYEOF
}
