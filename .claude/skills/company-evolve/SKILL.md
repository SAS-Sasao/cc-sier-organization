---
name: company-evolve
description: >
  Memento-Skills の Read-Write Reflective Learning を cc-sier に実装する継続学習Skill。
  過去のログから報酬スコアを付与し Case Bank を構築（Write フェーズ）、
  次のセッションで秘書が類似ケースを参照して判断する（Read フェーズ）。
  SKILL.md 自体のトリガーワード拡張とワークフロー自動生成も行う。
  「学習して」「進化させて」「/company-evolve」と言われたとき、
  または /company-report の完了後に自動起動したときに使用する。
---

# CC-SIer 継続学習Skill（Memento-Skills ベース）

## 1. 起動時の準備

1. `.companies/.active` から org-slug を取得
2. `git config user.name` でオペレーター名を取得
3. 学習対象期間を決定（デフォルト: 直近30日）

## 2. Write フェーズ（ポリシー評価）

### 2.1 Skill Evaluator

```bash
source .claude/hooks/skill-evaluator.sh
evaluate_session "{org-slug}" "{TODAY}"
```

シグナル（各20点、合計100点→0.0〜1.0）:
- completed: status が completed
- artifacts_exist: 成果物ファイルが実在
- no_excessive_edits: 同一ファイルへの Write が5回以下
- no_retry: interaction-log に「やり直し」等がない

### 2.2 Case Bank 再構築

```bash
source .claude/hooks/rebuild-case-bank.sh
rebuild_case_bank "{org-slug}"
```

task-log 全件を `.case-bank/index.json` にインデックス化する。

### 2.3 Skill Writer（SKILL.md 自体の改善）

#### 2.3.1 トリガーワード拡張

低報酬ケース（reward < 0.4）で mode が `direct` なのに artifact が多いパターンを検出。
同じ keywords の高報酬ケース（reward ≥ 0.7）の Subagent の description に
不足していたキーワードを追記する。

対象ファイル: `.claude/agents/{subagent-name}.md`
追記: description フィールド末尾に「「{キーワード}」と言われたときも使用する。」

#### 2.3.2 高報酬パターンからワークフロー自動生成

検出条件: request_head の先頭15文字が一致するケースが3件以上 かつ 平均 reward ≥ 0.7

生成形式:
```markdown
## wf-{slug}

- **名称**: {パターン名}（高報酬パターンから自動生成）
- **トリガー**: [{抽出したキーワード}]
- **実行方式**: subagent
- **ロール**: {最頻使用Subagent}
- **ステップ**: {task-log の実行計画から抽出}
- **成果物**: `{最頻の書き込みディレクトリ}`
- **平均報酬**: {avg_reward}
- **検出日**: {TODAY}
```

Gitワークフロー:
```
ブランチ: {org-slug}/admin/{TODAY}-auto-workflow-{slug}
コミット: feat: {パターン名}を高報酬ケースから自動生成 [{org-slug}] by {operator}
```

#### 2.3.3 MEMORY.md の更新（既存機能）

secretary/MEMORY.md を出力スタイル・ルーティング先読みで更新する。

## 3. Write フェーズ（Phase 3: 自律進化）

### 3.1 Skill Synthesizer

```bash
source .claude/hooks/skill-synthesizer.sh
synthesize_skills "{org-slug}" "{operator}"
```

Case Bank から既存 Skill にマッチしないパターンを検出し、新規 SKILL.md を動的生成する。

検出条件:
- mode が `direct` かつ artifact_count ≥ 2 かつ reward ≥ 0.5
- request_head 先頭15文字が一致するケースが3件以上
- 既存 SKILL.md のトリガーワードと重複率 ≤ 0.5（既存でカバーされていない）
- `synthesizer-log.json` に未記録（べき等）

生成物: `.claude/skills/{slug}/SKILL.md`
Git: ブランチ → コミット → PR（ラベル: `skill-synthesizer`, `org:{slug}`）

### 3.2 Subagent Refiner & Spawner

```bash
source .claude/hooks/subagent-refiner.sh
refine_subagents "{org-slug}" "{operator}"
```

**Refiner**: 既存 Subagent（secretary.md 除外）の末尾に以下を追記/上書き:
- `refined_capabilities`: 高報酬ケースから導出した得意領域
- `output_format`: 成果物出力先の実績
- `constraints`: 低報酬ケースから導出した注意事項

べき等: 前回精緻化時の case_count との差が3未満の場合はスキップ。

**Spawner**: 対応 Subagent がないパターン（mode=direct, 3件以上, avg_reward≥0.5）に新規 `.md` を生成。

Git: ブランチ → コミット → PR（ラベル: `subagent-refiner`, `org:{slug}`）

## 4. Read フェーズ（ポリシー改善）

このフェーズは secretary.md の起動時動作に統合する。

追加する動作（既存の 5. の後に挿入）:
```
6. .case-bank/index.json を読み込む（なければスキップ）
7. ユーザーの依頼と request_keywords を照合
8. reward ≥ 0.6 のケースを上位3件取得
9. 以下の Stateful Prompt を判断に注入する:

【過去の類似ケース（Case Bank より）】
- 「{request_head}」→ {subagent}（{mode}）報酬:{reward}
高報酬ケースと同じルーティングを優先すること。
```

照合ロジック: request_keywords の重複率 ≥ 0.3 で「類似」と判定。

## 5. ユーザーへの報告

```
学習完了（Memento-Skills Write フェーズ）

評価タスク: {N}件 / 平均報酬: {avg}
Case Bank: {total}件インデックス
トリガーワード追加: {N}件
ワークフロー自動生成: {N}件（PR: {URL}）
Skill Synthesizer: {N}件生成（PR: {URL}）
Subagent Refiner: 精緻化{N}件 / 新規生成{N}件（PR: {URL}）
MEMORY.md: 更新済み

次のセッションから Read フェーズが有効になります。
```

## 6. 注意事項

- SKILL.md への書き込みは追記のみ（既存記述の削除は禁止）
- `.case-bank/` は .gitignore に追加してローカル管理
- reward の追記はべき等（2回実行しても重複しない）
- Case Bank が空の場合は Read フェーズをスキップして通常ルーティング
