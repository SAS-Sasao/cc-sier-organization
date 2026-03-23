# 08 ファイル構成リファレンス

「このファイルは何のためにあるのか」「どのタイミングで読み書きされるか」「他のどのファイルと連携しているか」を一箇所で確認できるリファレンスです。

---

## 目次

- [1. ルートレベル](#1-ルートレベル)
- [2. .claude/ ── Claude Code 設定](#2-claude----claude-code-設定)
  - [2.1 settings.json](#21-settingsjson)
  - [2.2 agents/](#22-agents)
  - [2.3 skills/](#23-skills)
  - [2.4 hooks/](#24-hooks)
- [3. .companies/ ── 組織データ](#3-companies----組織データ)
  - [3.1 .active](#31-active)
  - [3.2 {org-slug}/CLAUDE.md](#32-org-slugclaudemd)
  - [3.3 {org-slug}/masters/](#33-org-slugmasters)
  - [3.4 {org-slug}/docs/](#34-org-slugdocs)
  - [3.5 {org-slug}/.task-log/](#35-org-slugtask-log)
  - [3.6 {org-slug}/.interaction-log/](#36-org-sluginteraction-log)
  - [3.7 {org-slug}/.session-summaries/](#37-org-slugsession-summaries)
  - [3.8 {org-slug}/.case-bank/](#38-org-slugcase-bank)
  - [3.9 {org-slug}/.quality-gate-log/](#39-org-slugquality-gate-log)
  - [3.10 {org-slug}/.conversation-log/](#310-org-slugconversation-log)
- [4. docs/guide/ ── ガイドドキュメント](#4-docsguide----ガイドドキュメント)
- [5. ファイル間の依存関係](#5-ファイル間の依存関係)
- [6. Git管理方針まとめ](#6-git管理方針まとめ)
- [7. ファイルのライフサイクル](#7-ファイルのライフサイクル)

---

## 1. ルートレベル

#### `README.md`

| 項目 | 内容 |
|---|---|
| 役割 | リポジトリの概要・使い方・ガイドへのリンク集 |
| 書き込みタイミング | 機能追加・ドキュメント構成変更時に手動で更新 |
| 読み取りタイミング | 新規参加者の最初の入口。GitHub リポジトリページで表示 |
| Git 管理 | ✅ プロジェクトの顔となるドキュメント |

#### `CLAUDE.md`（ルート）

| 項目 | 内容 |
|---|---|
| 役割 | 開発用のプロジェクト規約。ディレクトリ構成・ブランチ命名規則・コミットルール等を定義 |
| 書き込みタイミング | 開発規約の変更時に手動で更新 |
| 読み取りタイミング | Claude Code セッション開始時に自動読み込み。開発者が規約を確認する際にも参照 |
| Git 管理 | ✅ 開発チーム全体で共有する規約 |

注意: `.companies/{org-slug}/CLAUDE.md`（組織用）とは別物です。

#### `.gitignore`

| 項目 | 内容 |
|---|---|
| 役割 | Git 追跡から除外するファイル・ディレクトリを定義 |
| 書き込みタイミング | 新しいGit管理外ファイルが追加された時に手動で更新 |
| 読み取りタイミング | Git が毎回参照 |
| Git 管理 | ✅ |

主な除外対象:

| パターン | 理由 |
|---|---|
| `.companies/.active` | ローカル設定（ユーザーごとに異なる） |
| `.companies/*/.interaction-log/` | 生ログ（大きく個人的） |
| `.companies/*/.session-summaries/` | 中間データ |
| `.companies/*/.case-bank/` | ローカル学習データ |
| `.claude/agent-memory/` | エージェントごとのローカル学習データ |
| `.claude/scheduled_tasks.lock` | ロックファイル |
| `bk/` | バックアップディレクトリ |
| `dist/` | ビルド成果物 |

#### `LICENSE`

| 項目 | 内容 |
|---|---|
| 役割 | MIT ライセンス |
| 書き込みタイミング | 初期作成時のみ |
| 読み取りタイミング | ライセンス確認時 |
| Git 管理 | ✅ |

---

## 2. .claude/ ── Claude Code 設定

### 2.1 settings.json

#### `.claude/settings.json`

| 項目 | 内容 |
|---|---|
| 役割 | Hooks 設定・環境変数・Claude Code の動作パラメータを定義する中核設定ファイル |
| 書き込みタイミング | Hooks の追加・変更時に手動で更新 |
| 読み取りタイミング | Claude Code セッション起動時に自動読み込み |
| Git 管理 | ✅ チーム全体で共有する設定 |

現在の設定内容:

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  },
  "alwaysThinkingEnabled": true,
  "effortLevel": "high",
  "hooks": {
    "PostToolUse": [
      {
        "matcher": ".*",
        "hooks": [{"type": "command", "command": "bash .claude/hooks/capture-interaction.sh"}]
      }
    ],
    "Stop": [
      {
        "matcher": ".*",
        "hooks": [{"type": "command", "command": "bash .claude/hooks/session-boundary.sh"}]
      }
    ]
  }
}
```

| 設定キー | 役割 |
|---|---|
| `env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` | Agent Teams 機能を有効化 |
| `alwaysThinkingEnabled` | 常時思考モードを有効化 |
| `effortLevel` | 推論の深さ（`high`） |
| `hooks.PostToolUse` | ツール実行のたびに `capture-interaction.sh` を起動 |
| `hooks.Stop` | セッション終了時に `session-boundary.sh` を起動 |

#### `.claude/settings.local.json`

| 項目 | 内容 |
|---|---|
| 役割 | ローカル環境固有の設定（パーミッション等） |
| 書き込みタイミング | ユーザーがローカル設定を変更した時 |
| 読み取りタイミング | Claude Code セッション起動時に `settings.json` とマージして読み込み |
| Git 管理 | ✅（ただし個人設定が含まれる可能性あり） |

---

### 2.2 agents/

Subagent 定義ファイル群。秘書（secretary）が依頼内容に応じて適切な Subagent に委譲する際に参照します。

#### `.claude/agents/secretary.md`

| 項目 | 内容 |
|---|---|
| 役割 | **メインエージェント**。ユーザーの依頼を受け取り、振り分け・委譲・タスクログ記録・PR 作成を行う |
| 書き込みタイミング | 手動のみ。Subagent Refiner による自動精緻化の**対象外** |
| 読み取りタイミング | `/company` Skill 起動時に毎回読み込まれる |
| Git 管理 | ✅ |

**起動時の動作手順:**

1. `.companies/.active` からアクティブ組織を取得
2. `.companies/{org}/CLAUDE.md` を読み込み（組織状態の把握）
3. `masters/` 配下のマスタデータを参照
4. `.case-bank/index.json` を読み込み（**Read フェーズ**: 類似ケースの高報酬パターンを Stateful Prompt として注入）
5. ユーザーの依頼を分析し、最適な Subagent に委譲
6. `.task-log/` にタスクログを記録
7. 成果物を `docs/` に配置し、Git PR を作成

#### 専門 Subagent（20種）

| ファイル | 役割 | カテゴリ |
|---|---|---|
| `ai-developer.md` | AI駆動開発（プロンプト設計、RAG構築、LLMアプリ） | 開発 |
| `backend-developer.md` | バックエンド実装・API設計 | 開発 |
| `ci-cd-engineer.md` | CI/CDパイプライン設計・構築 | インフラ |
| `cloud-engineer.md` | クラウドインフラ設計・IaC実装 | インフラ |
| `data-architect.md` | データ基盤・DWH設計 | 設計 |
| `devops-coordinator.md` | リポジトリ初期構成・スキャフォールド生成 | インフラ |
| `frontend-developer.md` | フロントエンド実装・UI設計 | 開発 |
| `knowledge-manager.md` | ナレッジ管理・ポストモーテム・知見の構造化 | 知識管理 |
| `lead-developer.md` | コードレビュー・技術方針策定・実装ガイドライン | 開発 |
| `process-engineer.md` | ワークフロー最適化・業務プロセス設計 | PM |
| `project-manager.md` | WBS作成・マイルストーン管理・進捗レポート | PM |
| `qa-lead.md` | テスト戦略策定・テスト計画書作成・品質メトリクス | 品質 |
| `retail-domain-researcher.md` | 小売業界のドメイン知識収集・業務プロセス分析 | 知識管理 |
| `sre-engineer.md` | 監視設計・SLI/SLO策定・インシデント対応 | インフラ |
| `standards-lead.md` | 開発標準策定・規約管理・テンプレート整備 | PM |
| `system-architect.md` | システム全体設計・技術選定・ADR作成 | 設計 |
| `tech-researcher.md` | 技術調査・競合分析・PoC実施 | 知識管理 |
| `technical-writer.md` | 技術ドキュメント・教育資料・オンボーディング資料 | 文書 |
| `test-engineer.md` | テスト自動化・テストケース設計・カバレッジ分析 | 品質 |

| 項目 | 内容 |
|---|---|
| 書き込みタイミング | 手動更新 + Subagent Refiner による自動精緻化（secretary を除く） |
| 読み取りタイミング | 秘書が委譲時に Agent tool の `subagent_type` で参照 |
| Git 管理 | ✅ 自動精緻化は PR 経由でマージ |

**Subagent Refiner による自動精緻化:**

`/company-evolve` または Stop hook 実行時、前回更新から3件以上の新規ケースがあるSubagentに対して、以下の3セクションを末尾に追記します。

| セクション | 内容 |
|---|---|
| `## refined_capabilities` | 高報酬ケースから導出した得意領域 |
| `## output_format` | 過去ケースの実際の出力先ディレクトリ |
| `## constraints` | 低報酬ケース（reward < 0.4）から導出した注意事項 |

---

### 2.3 skills/

Skill 定義ファイル群。`/command` として呼び出される手順書です。

| Skill ディレクトリ | コマンド | SKILL.md の役割 |
|---|---|---|
| `company/` | `/company` | 引数なしで起動→メニューから新規作成（4問対話）または切り替え・秘書起動の手順 |
| `company-admin/` | `/company-admin` | マスタデータCRUDの手順 |
| `company-spawn/` | `/company-spawn` | アプリリポジトリ切り出しの手順 |
| `company-report/` | `/company-report` | 活動レポート生成の手順 |
| `company-evolve/` | `/company-evolve` | 継続学習（Write フェーズ）の手順 |
| `company-quality-setup/` | `/company-quality-setup` | 品質チェックリスト配置の手順 |
| `company-review/` | `/company-review` | 成果物の品質チェック手動実行の手順 |
| `company-dashboard/` | `/company-dashboard` | ダッシュボードHTML生成の手順 |

| 項目 | 内容 |
|---|---|
| 書き込みタイミング | 手動更新 + Skill Synthesizer による自動生成（新規ディレクトリごと） |
| 読み取りタイミング | ユーザーが `/command` を実行した時に Claude Code が読み込み |
| Git 管理 | ✅ 自動生成は PR 経由でマージ |

#### references/ サブディレクトリ

SKILL.md から参照される詳細定義ファイル。プログレッシブ・ディスクロージャのために外出し。

**company/references/:**

| ファイル | 内容 |
|---|---|
| `agent-templates.md` | Subagent 定義テンプレート |
| `claude-md-template.md` | 組織 CLAUDE.md のテンプレート |
| `departments.md` | 部署定義テンプレート |
| `git-workflow.md` | Git ワークフローの詳細手順 |
| `master-schemas.md` | マスタデータのバリデーションルール |
| `sier-templates.md` | SIer 業務テンプレート（ADR、ポストモーテム等） |
| `task-log-template.md` | タスクログ・GitHub Issue のテンプレート |
| `workflow-definitions.md` | ワークフロー定義テンプレート |

**company-admin/references/:**

| ファイル | 内容 |
|---|---|
| `master-schemas.md` | マスタデータのスキーマ定義（バリデーションルール） |

**company-spawn/references/:**

| ファイル | 内容 |
|---|---|
| `spawn-templates.md` | リポジトリ切り出し時のテンプレート |

**Skill Synthesizer による自動生成:**

Case Bank から「手順書がないのに繰り返している作業パターン」を検出すると、`skill-synthesizer.sh` が新しい Skill ディレクトリと SKILL.md を自動生成し、PR で提案します。検出条件: mode=direct, artifact_count≥2, reward≥0.5, 同一パターン3件以上。

#### `skills/company-quality-setup/SKILL.md`

| 項目 | 内容 |
|---|---|
| 役割 | アクティブ組織に品質チェックリストを配置する。既存ファイルがある場合は上書き確認を行う |
| 処理内容 | `masters/quality-gates/` の存在確認 → 上書き可否の確認（既存あり） → `templates/` からコピー |
| トリガー | `/company-quality-setup`、「品質ゲートを設定して」 |

#### `skills/company-quality-setup/templates/`

| 項目 | 内容 |
|---|---|
| 役割 | **全組織共通のチェックリストマスターテンプレート**。`/company-quality-setup` 実行時のコピー元 |
| 更新タイミング | 全組織に反映したいテンプレート変更時（手動編集） |
| Git 管理 | ✅（Skillと同じリポジトリで管理） |

> テンプレートを更新して `git push` すると、次に `/company-quality-setup` を実行したすべての組織に反映されます。

#### `skills/company-review/SKILL.md`

| 項目 | 内容 |
|---|---|
| 役割 | 成果物の品質チェックを手動実行する |
| 処理内容 | 対象ファイルの特定 → チェックリスト選択 → `quality-gate.sh` の実行 → 結果報告 |
| トリガー | `/company-review`、「レビューして」、「品質チェック」 |

#### `skills/company-dashboard/SKILL.md`

| 項目 | 内容 |
|---|---|
| 役割 | 活動状況をHTMLダッシュボードとして生成する |
| 処理内容 | `generate-dashboard.sh` を呼び出して `docs/secretary/dashboard.html` を生成 |
| トリガー | `/company-dashboard`、「ダッシュボード」、「状況を可視化」 |

---

### 2.4 hooks/

イベント駆動スクリプト群。`settings.json` の Hooks 設定から呼び出されます。

#### `.claude/hooks/capture-interaction.sh`

| 項目 | 内容 |
|---|---|
| 役割 | ツール実行のたびに `.interaction-log/{YYYY-MM-DD}.md` にログエントリを追記 |
| 書き込みタイミング | PostToolUse イベント発火時（ツール実行のたびに自動） |
| 読み取りタイミング | 他のスクリプトは直接参照しない。出力先の `.interaction-log/` を参照 |
| Git 管理 | ✅（スクリプト自体はGit管理、出力先のログは管理外） |

**動作:** stdin から `tool_name`, `session_id`, `tool_input` を JSON で受け取り → `.companies/.active` からアクティブ組織を取得 → ツール種別に応じた詳細（パス、コマンド、パターン等）を抽出 → `.interaction-log/{TODAY}.md` に Markdown 形式で追記

#### `.claude/hooks/session-boundary.sh`

| 項目 | 内容 |
|---|---|
| 役割 | **最も多くの処理を担う中核スクリプト**。セッション終了時に統計集計・Issue投稿・継続学習を実行 |
| 書き込みタイミング | Stop イベント発火時（Claude の応答完了時に自動） |
| 読み取りタイミング | 他のスクリプトは直接参照しない。各出力先を参照 |
| Git 管理 | ✅ |

**10ステップの処理順序:**

| # | 処理 | 入出力 |
|---|---|---|
| 1 | stdin から `session_id` を取得 | stdin → 変数 |
| 2 | `.companies/.active` からアクティブ組織を取得 | `.active` → 変数 |
| 3 | `.interaction-log/{TODAY}.md` に区切り線を追記 | → `.interaction-log/` |
| 4 | ログからツール種別をカウント（Write/Read/Bash/Other） | `.interaction-log/` → 変数 |
| 5 | `.session-summaries/` に統計 JSON を保存 | → `.session-summaries/` |
| 6 | GitHub Issue に投稿（1日1件・追記方式） | → GitHub Issues |
| 7 | `skill-evaluator.sh` を source → 本日タスクに報酬スコアを付与 | → `.task-log/` |
| 8 | `rebuild-case-bank.sh` を source → Case Bank を再構築 | `.task-log/` → `.case-bank/` |
| 9 | `skill-synthesizer.sh` を source → 新規Skill候補をPR提案 | `.case-bank/` → `.claude/skills/` + PR |
| 10 | `subagent-refiner.sh` を source → Agent更新をPR提案 | `.case-bank/` → `.claude/agents/` + PR |

#### `.claude/hooks/skill-evaluator.sh`

| 項目 | 内容 |
|---|---|
| 役割 | タスクの成否を4シグナルで評価し、`.task-log/` の各ファイルに `## reward` セクションを追記 |
| 書き込みタイミング | `session-boundary.sh` から source される。または `/company-evolve` から呼び出し |
| 読み取りタイミング | `.task-log/*.md` と `.interaction-log/{TODAY}.md` を参照 |
| Git 管理 | ✅ |

**評価シグナル:**

| シグナル | 条件 | 点数 |
|---|---|---|
| completed | status が completed | 60点 |
| artifacts_exist | 成果物ファイルが実際に存在する | +20点 |
| no_excessive_edits | 同一ファイルへの Write が5回以下 | +20点 |
| no_retry | 「やり直し」等の否定フィードバックがない | ペナルティなし（検出時 -10点） |

スコアは 0.0〜1.0 に正規化されます。

#### `.claude/hooks/rebuild-case-bank.sh`

| 項目 | 内容 |
|---|---|
| 役割 | `.task-log/` の全ファイルを走査し、`.case-bank/index.json` を再構築する |
| 書き込みタイミング | `session-boundary.sh` から source される。または `/company-evolve` から呼び出し |
| 読み取りタイミング | `.task-log/*.md` を全件走査 |
| Git 管理 | ✅ |

Python3 が必要です。各タスクログから frontmatter、reward スコア、成果物パス、Subagent 情報を抽出し、構造化された JSON インデックスを生成します。

#### `.claude/hooks/skill-synthesizer.sh`

| 項目 | 内容 |
|---|---|
| 役割 | Case Bank から既存 Skill にマッチしないパターンを検出し、新規 SKILL.md を生成して PR で提案 |
| 書き込みタイミング | `session-boundary.sh` から source される。または `/company-evolve` から呼び出し |
| 読み取りタイミング | `.case-bank/index.json` と既存 `skills/*/SKILL.md` を参照 |
| Git 管理 | ✅ |

べき等性のために `.case-bank/synthesizer-log.json` に生成済みパターンを記録します。

#### `.claude/hooks/subagent-refiner.sh`

| 項目 | 内容 |
|---|---|
| 役割 | Case Bank の実績をもとに既存 Subagent を精緻化（Refiner）し、未対応パターンには新規 Subagent を生成（Spawner） |
| 書き込みタイミング | `session-boundary.sh` から source される。または `/company-evolve` から呼び出し |
| 読み取りタイミング | `.case-bank/index.json` と既存 `agents/*.md` を参照 |
| Git 管理 | ✅ |

べき等性のために `.case-bank/refiner-log.json` に精緻化・生成済み情報を記録します。`secretary.md` は自動精緻化の対象外です。

#### `hooks/quality-gate.sh`

| 項目 | 内容 |
|---|---|
| 役割 | `docs/` 配下の `.md` 保存時に品質チェックリストと照合し、結果をログ・ボード・Issueに反映する |
| 呼び出しイベント | `PostToolUse`（Write/Edit/CreateFile ツール） |
| 出力先 | `.quality-gate-log/YYYY-MM-DD.jsonl`、`board.md`、GitHub Issues |
| Git 管理 | ✅ |

#### `hooks/update-board.sh`

| 項目 | 内容 |
|---|---|
| 役割 | タスクボード（`board.md`）の操作ユーティリティ。`source` して4種の関数を提供する |
| 呼び出し方 | `secretary.md` のタスク管理処理 / `quality-gate.sh` から `source` して使う |
| Git 管理 | ✅ |

#### `hooks/generate-dashboard.sh`

| 項目 | 内容 |
|---|---|
| 役割 | 複数データソースを集計してダッシュボードHTMLを生成する |
| 呼び出し方 | `/company-dashboard` Skill から直接 / `/company-report` 完了後に自動呼び出し |
| 出力先 | `docs/secretary/dashboard.html` |
| Git 管理 | ✅ |

#### `hooks/capture-conversation.sh`

| 項目 | 内容 |
|---|---|
| 役割 | セッション終了時に会話全内容を取得・マスキング・Markdownに保存する |
| 呼び出しイベント | `Stop`（`session-boundary.sh` から自動呼び出し） |
| 入力 | stdin から `session_id` / `~/.claude/projects/{hash}/{session_id}.jsonl` |
| 出力先 | `.conversation-log/YYYY-MM-DD-{session_short}.md` |
| Git 管理 | ✅（スクリプト本体）/ ❌（生成ログは `.gitignore` で除外） |

#### `hooks/enrich-case-bank.sh`

| 項目 | 内容 |
|---|---|
| 役割 | 会話ログを走査して意図・頻出フレーズを抽出し、Case Bank エントリを補強する |
| 呼び出し方 | `/company-evolve` Skill から `source` して `enrich_case_bank` 関数を呼ぶ |
| 入力 | `.conversation-log/*.md`、`.case-bank/index.json` |
| 出力先 | `.case-bank/index.json`（`conversation_context` を各エントリに付加） |
| べき等性 | `.case-bank/enrich-log.json` で処理済みファイルを管理 |
| Git 管理 | ✅ |

---

## 3. .companies/ ── 組織データ

### 3.1 .active

#### `.companies/.active`

| 項目 | 内容 |
|---|---|
| 役割 | 現在操作対象の組織（org-slug）を1行で記載するファイル。全 Hooks スクリプトが**最初に読むファイル** |
| 書き込みタイミング | `/company {org-slug}` 実行時に秘書が書き込み |
| 読み取りタイミング | `capture-interaction.sh`、`session-boundary.sh` の起動時。秘書の起動時 |
| Git 管理 | ❌ ローカル設定（各ユーザーが独立して組織を切り替えるため） |

**重要:** このファイルが存在しない場合、すべての Hooks スクリプトは `exit 0` でスキップします。初回利用時は必ず `/company {org-slug}` を実行してください。

```
# .companies/.active の例
domain-tech-collection
```

---

### 3.2 {org-slug}/CLAUDE.md

#### `.companies/{org-slug}/CLAUDE.md`

| 項目 | 内容 |
|---|---|
| 役割 | 組織の状態サマリー。部署一覧・運営ルール・Agent Teams ポリシー・パーソナライズメモを記載 |
| 書き込みタイミング | `/company-admin` でマスタ変更時に連鎖更新。秘書がパーソナライズメモを追記する場合もある |
| 読み取りタイミング | 秘書の起動時に毎回読み込み。Claude Code がプロジェクト CLAUDE.md として自動参照 |
| Git 管理 | ✅ 組織のルールを共有 |

---

### 3.3 {org-slug}/masters/

組織のマスタデータ。秘書や Subagent が参照する「組織の知識」の原本です。

#### `masters/organization.md`

| 項目 | 内容 |
|---|---|
| 役割 | 組織全体の基本情報（オーナー名、事業、組織ID、セットアップ日） |
| 書き込みタイミング | `/company-admin` で組織情報変更時 |
| 読み取りタイミング | 秘書起動時、レポート生成時 |
| Git 管理 | ✅ |

#### `masters/departments.md`

| 項目 | 内容 |
|---|---|
| 役割 | 部署一覧と各部署に対応する Subagent のマッピング |
| 書き込みタイミング | `/company-admin` で部署追加・変更時。連鎖更新で `CLAUDE.md` も同時に更新 |
| 読み取りタイミング | 秘書がルーティング判断時に参照 |
| Git 管理 | ✅ |

#### `masters/roles.md`

| 項目 | 内容 |
|---|---|
| 役割 | 組織内の役割と責任範囲の定義 |
| 書き込みタイミング | `/company-admin` で役割変更時 |
| 読み取りタイミング | 秘書がSubagent選択時、Subagentがタスク実行時 |
| Git 管理 | ✅ |

#### `masters/workflows.md`

| 項目 | 内容 |
|---|---|
| 役割 | 定型業務の手順テンプレート。Agent Teams の編成パターンを含む |
| 書き込みタイミング | **手動更新**と **`/company-evolve` による自動追記**の両方がある |
| 読み取りタイミング | 秘書が実行モード（direct / subagent / agent-teams）を判断する際に参照 |
| Git 管理 | ✅ |

**自動追記されるワークフローの形式:**

`/company-evolve` の Phase 2 で、高報酬パターン（3件以上・平均 reward ≥ 0.7）が検出されると以下の形式で追記されます。

```markdown
### {パターン名}（自動生成 YYYY-MM-DD）

- **実行方式**: {mode}
- **テイメイト**: {subagent_list}
- **トリガー**: {keywords}
- **実績**: {n}件, 平均報酬: {avg_reward}
```

#### `masters/projects.md`

| 項目 | 内容 |
|---|---|
| 役割 | 組織で管理するプロジェクトの一覧と状態 |
| 書き込みタイミング | `/company-admin` でプロジェクト追加・更新時 |
| 読み取りタイミング | 秘書がタスクをプロジェクトに紐づける際に参照 |
| Git 管理 | ✅ |

#### `masters/mcp-services.md`

| 項目 | 内容 |
|---|---|
| 役割 | MCP（Model Context Protocol）サービスの設定情報 |
| 書き込みタイミング | `/company-admin` でMCPサービス変更時 |
| 読み取りタイミング | 外部サービス連携時 |
| Git 管理 | ✅ |

#### `masters/quality-gates/`

| 項目 | 内容 |
|---|---|
| 役割 | **品質チェックリストの保管場所**。`quality-gate.sh` がファイルパスに応じて自動選択・適用する |
| 初期配置 | `/company-quality-setup` を実行すると `templates/` からコピーされる |
| 更新タイミング | 手動編集（組織固有のルールを追記していく） |
| Git 管理 | ✅ |

**サブディレクトリ:**

| ファイル | 役割 |
|---|---|
| `_default.md` | 全成果物に適用される共通チェック |
| `by-type/*.md` | 成果物の種類（要件定義・設計書・提案書等）に応じたチェック |
| `by-customer/{slug}.md` | 顧客固有のチェック（`/company-admin` 登録時に自動生成） |
| `by-customer/_template.md` | 顧客別チェックリストの雛形 |

#### `masters/customers/{slug}.md`

| 項目 | 内容 |
|---|---|
| 役割 | 顧客ごとの情報（名称・制約・担当者・技術スタック） |
| 書き込みタイミング | `/company-admin` で顧客情報追加・更新時 |
| 読み取りタイミング | Subagent がタスク実行時に自動参照。秘書のルーティング判断にも影響 |
| Git 管理 | ✅ |

---

### 3.4 {org-slug}/docs/

全成果物の格納ディレクトリ。Subagent が生成する設計書・報告書・調査レポート等はすべてここに配置されます。

#### Subagent ごとの出力先サブディレクトリ

| サブディレクトリ | 出力する Subagent | 主な成果物 |
|---|---|---|
| `docs/secretary/` | secretary | TODO、メモ、学習スケジュール、統合レポート |
| `docs/secretary/reports/` | secretary（/company-report） | 日次・週次・月次レポート |
| `docs/secretary/todos/` | secretary | 日別TODOファイル |
| `docs/secretary/inbox/` | secretary | 受信メモ |
| `docs/secretary/notes/` | secretary | 作業ノート |
| `docs/system/architecture/` | system-architect | 全体設計・ADR・構成図 |
| `docs/system/requirements/` | business-analyst | 要件定義書 |
| `docs/system/api/` | backend-engineer | API設計書 |
| `docs/system/frontend/` | frontend-engineer | フロントエンド設計 |
| `docs/data/` | data-architect | DWH設計・メダリオン設計 |
| `docs/data/analytics/` | data-analyst | KPI設計・ダッシュボード |
| `docs/infra/` | cloud-engineer, infra-engineer | インフラ構成設計・IaC |
| `docs/infra/cicd/` | devops-engineer, ci-cd-engineer | CI/CDパイプライン設計 |
| `docs/infra/cost/` | cost-optimizer | コスト分析 |
| `docs/pm/` | project-manager | WBS・進捗管理 |
| `docs/pm/agile/` | scrum-master | スプリント計画 |
| `docs/proposals/` | proposal-writer | 提案書・見積書 |
| `docs/reports/` | report-writer | 進捗報告・月次報告 |
| `docs/research/` | tech-researcher, domain-researcher | 技術調査レポート |
| `docs/retail-domain/` | retail-domain-researcher | 小売ドメイン知識 |
| `docs/knowledge/` | knowledge-manager | ナレッジベース・FAQ |
| `docs/review/` | code-reviewer, lead-developer | コードレビュー結果 |
| `docs/qa/` | qa-lead, test-engineer | テスト計画・テストケース |
| `docs/security/` | security-engineer | セキュリティ設計 |
| `docs/integration/` | integration-specialist | システム連携設計 |
| `docs/daily-digest/` | secretary（/company-report） | 日次ダイジェスト |

#### `docs/secretary/MEMORY.md`

| 項目 | 内容 |
|---|---|
| 役割 | 秘書の「作業スタイルの好み」を記録するファイル。出力形式の傾向やルーティング先読みを保存 |
| 書き込みタイミング | `/company-evolve` の Phase 2 で自動更新。出力スタイル（ASCII図を好む等）が3回以上検出されると記録 |
| 読み取りタイミング | 秘書の起動時に参照。次のセッションの出力スタイルに反映 |
| Git 管理 | ✅ 組織の学習成果として共有 |

検出パターンの例:

| 検出条件 | 記録内容 |
|---|---|
| 「ASCII図」が3回以上出現 | `ASCII図を必ず添付する` |
| 「比較表」が3回以上出現 | `比較表をセットで出力する` |
| 「短く」が3回以上出現 | `簡潔な出力を好む` |

#### `docs/secretary/board.md`

| 項目 | 内容 |
|---|---|
| 役割 | **タスクボード**。Todo / In Progress / Review / Done の4列カンバン形式 |
| 書き込みタイミング | `update-board.sh` の各関数（秘書・品質ゲートから呼び出し） |
| 読み取りタイミング | `generate-dashboard.sh`（ダッシュボード生成時） |
| Git 管理 | ✅ |

#### `docs/secretary/dashboard.html`

| 項目 | 内容 |
|---|---|
| 役割 | **活動状況ダッシュボード**。Chart.jsを使ったアニメーション付きHTML |
| 書き込みタイミング | `/company-dashboard` 実行時 / `/company-report` 完了後に自動生成 |
| 読み取りタイミング | ブラウザで開いたとき（5分ごと自動リフレッシュ） |
| Git 管理 | ✅ |

---

### 3.5 {org-slug}/.task-log/

#### `.companies/{org-slug}/.task-log/{task-id}.md`

| 項目 | 内容 |
|---|---|
| 役割 | 1タスク＝1ファイルのタスク実行ログ。ファイル生成を伴うタスクのみ記録 |
| 書き込みタイミング | 秘書がタスク開始時に作成 → 実行中に追記 → 完了時に status 更新 → `skill-evaluator.sh` が `## reward` を追記 |
| 読み取りタイミング | `rebuild-case-bank.sh` が全件走査。`/company-report` が期間内のログを参照 |
| Git 管理 | ✅ 成果物・履歴として保存 |

**task-id の命名規則:** `YYYYMMDD-HHMMSS-{概要slug}`

例: `20260321-103000-store-computer-learning-plan`

**frontmatter のフィールド一覧:**

| フィールド | 型 | 内容 |
|---|---|---|
| `task_id` | string | タスクID（ファイル名と同一） |
| `org` | string | 組織のorg-slug |
| `operator` | string | 実行者名 |
| `status` | string | `in-progress` → `completed` |
| `mode` | string | `agent-teams` / `subagent` / `direct` |
| `started` | string | 開始日時（ISO 8601） |
| `completed` | string | 完了日時（完了時に記入） |
| `request` | string | ユーザーの依頼原文 |
| `issue_number` | number/null | 作成された GitHub Issue 番号 |
| `pr_number` | number/null | 作成された PR 番号 |

**`## reward` セクションの追記（`skill-evaluator.sh`）:**

セッション終了時に `skill-evaluator.sh` が本日の completed タスクを評価し、以下のセクションを末尾に追記します。既に `## reward` がある場合はスキップ（べき等）。

```yaml
## reward
score: 0.80
signals:
    completed: true
    artifacts_exist: true
    excessive_edits: false
    retry_detected: false
evaluated_at: "2026-03-21T21:30:00"
```

---

### 3.6 {org-slug}/.interaction-log/

#### `.companies/{org-slug}/.interaction-log/{YYYY-MM-DD}.md`

| 項目 | 内容 |
|---|---|
| 役割 | ツール実行の詳細ログ。1日1ファイル。`capture-interaction.sh` が自動追記 |
| 書き込みタイミング | PostToolUse フック発火時（ツール実行のたびに自動追記） |
| 読み取りタイミング | `session-boundary.sh` がセッション統計の抽出に使用。`skill-evaluator.sh` が過剰編集チェックに使用 |
| Git 管理 | ❌ 生ログは大きく個人的なデータ |

各エントリの形式:

```markdown
### 14:32:15 — **Write** `abc12345`
- path: `.companies/jutaku-dev-team/docs/system/requirements.md`
```

---

### 3.7 {org-slug}/.session-summaries/

#### `.companies/{org-slug}/.session-summaries/{YYYYMMDD-HHMMSS}-{session-short}.json`

| 項目 | 内容 |
|---|---|
| 役割 | セッション単位の統計 JSON。ツール実行回数、種別ごとのカウント、書き込みファイル一覧を保存 |
| 書き込みタイミング | `session-boundary.sh` のステップ5で生成 |
| 読み取りタイミング | `/company-report` がレポート生成時に参照 |
| Git 管理 | ❌ 中間データ |

JSON の構造例:

```json
{
  "session_id": "abc12345-...",
  "org_slug": "domain-tech-collection",
  "date": "2026-03-21",
  "datetime": "2026-03-21 21:30:00",
  "tool_count": 42,
  "by_type": { "write": 8, "read": 20, "bash": 5, "other": 9 },
  "files_written": ["path/to/file1.md", "path/to/file2.md"],
  "log_file": ".companies/domain-tech-collection/.interaction-log/2026-03-21.md"
}
```

---

### 3.8 {org-slug}/.case-bank/

継続学習の核心データディレクトリ。Git 管理外ですが、`.task-log/` から完全に再構築可能です。

#### `.case-bank/index.json`

| 項目 | 内容 |
|---|---|
| 役割 | **継続学習の核心データ**。全タスクを構造化したインデックス。秘書の Read フェーズで類似ケースの検索に使用 |
| 書き込みタイミング | `rebuild-case-bank.sh` が `.task-log/` を全件走査して再構築 |
| 読み取りタイミング | 秘書の起動時（Read フェーズ）、`skill-synthesizer.sh`、`subagent-refiner.sh` |
| Git 管理 | ❌ ローカル学習データ（`.task-log/` から完全再構築可能） |

**JSON の構造:**

```json
{
  "org_slug": "domain-tech-collection",
  "updated_at": "2026-03-21T21:30:00",
  "case_count": 7,
  "cases": [
    {
      "id": "20260321-103000-store-computer-learning-plan",
      "state": {
        "request_keywords": ["ストアコンピューター", "学習計画", "AWS", "移行"],
        "request_head": "コンビニエンスストアのストアコンピュー",
        "org_slug": "domain-tech-collection"
      },
      "action": {
        "subagent": "retail-domain-researcher",
        "mode": "agent-teams",
        "artifact_count": 3
      },
      "reward": 0.9,
      "outcome": {
        "files_written": [
          ".companies/domain-tech-collection/docs/retail-domain/store-computer-domain-knowledge.md"
        ],
        "started": "2026-03-21T10:30:00"
      }
    }
  ]
}
```

#### `.case-bank/synthesizer-log.json`

| 項目 | 内容 |
|---|---|
| 役割 | Skill Synthesizer がどのパターンを既に生成済みか記録する、べき等性チェック用ログ |
| 書き込みタイミング | `skill-synthesizer.sh` が新規 Skill を生成した時 |
| 読み取りタイミング | `skill-synthesizer.sh` が重複生成を防ぐために毎回参照 |
| Git 管理 | ❌ ローカル学習データ |

#### `.case-bank/refiner-log.json`

| 項目 | 内容 |
|---|---|
| 役割 | Subagent Refiner/Spawner がどの Agent を精緻化・生成済みか記録する、べき等性チェック用ログ |
| 書き込みタイミング | `subagent-refiner.sh` が Agent を精緻化・生成した時 |
| 読み取りタイミング | `subagent-refiner.sh` が差分チェック（前回更新からの新規ケース数）に毎回参照 |
| Git 管理 | ❌ ローカル学習データ |

---

## 4. docs/guide/ ── ガイドドキュメント

| ファイル | 対象読者 | 内容 |
|---|---|---|
| [00-overview.md](00-overview.md) | 全員 | 設計思想・アーキテクチャ全体図・Skill vs Subagent の使い分け |
| [01-quickstart.md](01-quickstart.md) | 新規参加者 | セットアップ〜最初のタスク依頼〜初回学習まで |
| [02-skills.md](02-skills.md) | 利用者 | 全 Skill（/company, /company-admin, /company-report, /company-evolve, /company-spawn）の使い方と引数 |
| [03-subagents.md](03-subagents.md) | 利用者・管理者 | 20種 Subagent の役割・得意領域・成果物ディレクトリ・自動精緻化の仕組み |
| [04-hooks.md](04-hooks.md) | 管理者 | Hooks 設定・カスタマイズ方法・動作確認手順 |
| [05-learning-system.md](05-learning-system.md) | 管理者・実装者 | Phase 1〜3 の詳細仕様・報酬スコア・Case Bank・Skill/Agent 自動生成 |
| [06-multi-org.md](06-multi-org.md) | 利用者 | 複数組織の作成・切り替え・知識共有の仕組み |
| [07-company-spawn.md](07-company-spawn.md) | 利用者 | アプリリポジトリの切り出し手順と親組織との関係 |
| [08-file-reference.md](08-file-reference.md) | 全員 | 本ドキュメント。全ファイルの役割詳細リファレンス |
| [09-quality-dashboard.md](09-quality-dashboard.md) | 利用者・管理者 | 品質ゲート・タスクボード・ダッシュボードの詳細ガイド |

---

## 5. ファイル間の依存関係

```
                    ┌─────────────────┐
                    │  settings.json   │
                    │  (Hooks 設定)    │
                    └────────┬────────┘
                             │ 起動設定
                ┌────────────┼────────────┐
                ▼                         ▼
  ┌──────────────────┐        ┌──────────────────────┐
  │ capture-          │        │ session-boundary.sh  │
  │ interaction.sh    │        │ (中核スクリプト)       │
  └────────┬─────────┘        └──────┬──────┬────────┘
           │                         │      │
           ▼                         │      ├── source ──▶ skill-evaluator.sh
  ┌────────────────┐                 │      ├── source ──▶ rebuild-case-bank.sh
  │ .interaction-   │                 │      ├── source ──▶ skill-synthesizer.sh
  │ log/YYYY-MM-   │◀── 読み取り ────┘      └── source ──▶ subagent-refiner.sh
  │ DD.md          │                                │              │
  └────────────────┘                                │              │
                                                    ▼              ▼
  ┌──────────┐    ┌────────────┐         ┌──────────────┐  ┌────────────┐
  │ .active  │──▶│ CLAUDE.md  │         │ .case-bank/   │  │ agents/    │
  │          │   │ (組織)     │         │ index.json    │  │ *.md       │
  └──────────┘   └─────┬──────┘         └──────┬───────┘  └────────────┘
      │                │                       │                 ▲
      │                ▼                       │        精緻化 / 新規生成
      │         ┌────────────┐                 │                 │
      │         │ masters/   │                 ▼                 │
      └────────▶│            │         ┌───────────────┐        │
   全Hooksが    │ workflows  │◀─自動─│ /company-evolve │────────┘
   最初に読む   │ roles      │  追記  └───────────────┘
               │ customers  │
               └─────┬──────┘
                     │
                     ▼
              ┌────────────┐        ┌──────────────┐
              │ secretary  │──委譲─▶│ Subagent     │
              │ .md        │        │ (20種)       │
              └─────┬──────┘        └──────┬───────┘
                    │                      │
                    ▼                      ▼
              ┌────────────┐        ┌────────────┐
              │ .task-log/ │        │ docs/       │
              │ *.md       │        │ (成果物)    │
              └────────────┘        └────────────┘
                    │
                    ▼
              ┌────────────┐
              │ GitHub     │
              │ Issues     │
              └────────────┘
```

---

## 6. Git管理方針まとめ

| ファイル/ディレクトリ | Git管理 | 理由 |
|---|---|---|
| `README.md`, `CLAUDE.md`, `LICENSE` | ✅ | プロジェクトの基本ドキュメント |
| `.claude/settings.json` | ✅ | チーム全体で共有する設定 |
| `.claude/agents/*.md` | ✅ | Subagent 定義はレビュー経由で更新（自動精緻化も PR） |
| `.claude/skills/*/SKILL.md` | ✅ | Skill 定義はレビュー経由で更新（自動生成も PR） |
| `.claude/hooks/*.sh` | ✅ | イベント駆動スクリプトの共有 |
| `.companies/{org}/CLAUDE.md` | ✅ | 組織ルールの共有 |
| `.companies/{org}/masters/` | ✅ | マスタデータの共有（ワークフロー自動追記も含む） |
| `.companies/{org}/docs/` | ✅ | 成果物の管理（PRフロー） |
| `.companies/{org}/.task-log/` | ✅ | 履歴として保存。reward スコア含む |
| `docs/guide/` | ✅ | ガイドドキュメント |
| `.companies/.active` | ❌ | ローカル設定（各ユーザーが独立して組織切替） |
| `.companies/{org}/.interaction-log/` | ❌ | 生ログが大きく個人的 |
| `.companies/{org}/.session-summaries/` | ❌ | セッション統計の中間データ |
| `.companies/{org}/.case-bank/` | ❌ | ローカル学習データ（`.task-log/` から再構築可能） |
| `.claude/agent-memory/` | ❌ | エージェントごとのローカル学習データ |
| `bk/` | ❌ | バックアップ |
| `dist/` | ❌ | ビルド成果物 |
| `.companies/{org}/.quality-gate-log/` | ❌ | 生ログ・再生成可能 |
| `.companies/{org}/masters/quality-gates/` | ✅ | 組織固有のチェックルール |
| `.companies/{org}/docs/secretary/board.md` | ✅ | タスク履歴（共有） |
| `.companies/{org}/docs/secretary/dashboard.html` | ✅ | GitHub Pages で公開するため |
| `.claude/skills/company-quality-setup/templates/` | ✅ | 全組織共通テンプレート |
| `.companies/{org}/.conversation-log/` | ❌ | 会話内容・プライバシー保護 |
| `.claude/hooks/capture-conversation.sh` | ✅ | スクリプト本体はチーム共有 |
| `.claude/hooks/enrich-case-bank.sh` | ✅ | スクリプト本体はチーム共有 |

---

## 7. ファイルのライフサイクル

### タスク実行時の書き込み順序

```
1. ユーザーが依頼
2. 秘書が .companies/.active を読み取り → 組織を特定
3. 秘書が CLAUDE.md, masters/ を読み込み
4. 秘書が .case-bank/index.json を読み込み（Read フェーズ）
5. 秘書が .task-log/{task-id}.md を新規作成（status: in-progress）
6. 秘書が Subagent に委譲
7. Subagent が docs/ に成果物を生成
8. 秘書が .task-log/{task-id}.md を更新（成果物パス・status: completed）
9. 秘書が Git ブランチ作成 → コミット → PR 作成
10. [Hook] capture-interaction.sh が各ツール実行を .interaction-log/ に記録
11. [Hook] session-boundary.sh が起動:
    11a. capture-conversation.sh: 会話ログを .conversation-log/ に保存（マスキング済み）
    11b. .interaction-log/ に区切り線追記
    11c. .session-summaries/ に統計 JSON 保存
    11d. GitHub Issue に会話サマリーを含めて投稿
    11e. skill-evaluator.sh が .task-log/ に reward 追記
    11e. rebuild-case-bank.sh が .case-bank/index.json を再構築
    11f. skill-synthesizer.sh が新規 Skill を PR 提案（条件に合致した場合）
    11g. subagent-refiner.sh が Agent を精緻化 / 新規生成して PR 提案（条件に合致した場合）
```

### /company-evolve 実行時の書き込み順序

```
1. .task-log/ の全ファイルを走査
2. [Phase 1] skill-evaluator.sh: 未評価タスクに reward スコアを付与
   → .task-log/{task-id}.md に ## reward セクション追記
3. [Phase 1] rebuild-case-bank.sh: Case Bank を再構築
   → .case-bank/index.json を上書き
4. [Phase 2] MEMORY.md 更新: 出力スタイルの傾向を分析
   → docs/secretary/MEMORY.md を更新
5. [Phase 2] ワークフロー自動生成: 高報酬パターンを検出
   → masters/workflows.md に追記
6. [Phase 3] skill-synthesizer.sh: 新規 Skill を生成
   → .claude/skills/{slug}/SKILL.md を作成 → PR 提案
   → .case-bank/synthesizer-log.json を更新
7. [Phase 3] subagent-refiner.sh: 既存 Agent を精緻化
   → .claude/agents/{name}.md に精緻化セクションを追記 → PR 提案
8. [Phase 3] subagent-refiner.sh（Spawner部）: 新規 Agent を生成
   → .claude/agents/{slug}.md を作成 → PR 提案
   → .case-bank/refiner-log.json を更新
```

### Case Bank 消失時の復元手順

`.case-bank/` は Git 管理外のため、環境移行やクリーンアップで消失する可能性があります。以下の手順で完全に再構築できます。

```bash
# 1. .task-log/ が存在することを確認（Git管理対象なので pull すれば復元可能）
ls .companies/{org-slug}/.task-log/

# 2. rebuild-case-bank.sh を直接実行
source .claude/hooks/rebuild-case-bank.sh
rebuild_case_bank "{org-slug}"

# 3. 復元を確認
cat .companies/{org-slug}/.case-bank/index.json | python3 -m json.tool | head -20

# 4. synthesizer-log.json と refiner-log.json は自動生成される
# （次回の /company-evolve または Stop hook 実行時に再作成）
```

`.task-log/` さえ残っていれば、Case Bank は完全に再構築されます。`synthesizer-log.json` と `refiner-log.json` はべき等性チェック用のため、消失しても Skill/Agent の重複生成が発生する程度で、既に PR マージ済みの場合は既存チェックで防がれます。

---

### 3.9 {org-slug}/.quality-gate-log/

**Git 管理外。品質チェック結果の生ログ。**

#### `.quality-gate-log/YYYY-MM-DD.jsonl`

| 項目 | 内容 |
|---|---|
| 役割 | 品質ゲートの実行結果を JSONL 形式で記録する（1行1チェック結果） |
| 書き込みタイミング | `quality-gate.sh` が実行されるたびに追記 |
| 読み取りタイミング | `generate-dashboard.sh` が合格率の集計に使用 |
| Git 管理 | ❌（`.gitignore` で除外） |

---

### 3.10 `{org-slug}/.conversation-log/`

**Git 管理外。会話ログのMarkdown（マスキング済み）。**

#### `.conversation-log/YYYY-MM-DD-{session_short}.md`

| 項目 | 内容 |
|---|---|
| 役割 | セッション内の発言・応答・ツール実行を時系列で保存したマスキング済み会話ログ |
| 書き込みタイミング | `capture-conversation.sh`（Stop Hook）が毎セッション終了時に生成 |
| 読み取りタイミング | `enrich-case-bank.sh` が `/company-evolve` 実行時に走査 |
| Git 管理 | ❌（`.gitignore` で除外・プライバシー保護） |
| 初回生成 | 組織の初回セッション終了時にディレクトリが自動作成される |

> **新規組織での動作:** `/company {org-slug}` でアクティブ組織を設定した後、
> セッションを終了するだけで自動的にログが記録されます。事前のディレクトリ作成は不要です。
