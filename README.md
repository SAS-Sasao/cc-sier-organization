# cc-sier

**Claude Code で SIer業務の仮想組織を構築・運営するプラグイン**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

---

## できること

### ① 秘書に話しかけるだけで業務が回る

`/company` で秘書が起動。依頼内容に応じて自動で専門エージェントに振り分ける。

- TODO管理、壁打ち、メモ、ダッシュボードを秘書が一手に対応
- マスタのトリガーワードと照合し、最適な部署・Subagent に自動ルーティング
- 判断に迷う依頼も秘書が受け止めて対応方針を提案

```
あなた: 「今日のTODOに設計レビューの準備を追加して」
秘書:   TODOに追加 → .companies/{org}/docs/secretary/todos/2026-03-19.md

あなた: 「A社のインフラ構成を設計して」
秘書:   トリガーワード「インフラ」→ cloud-engineer Subagent に委譲
```

### ② 専門エージェントが並列で動く（Agent Teams）

19種の Subagent を同梱。ワークフロー定義に従い、Claude Code が自動でチームを編成する。

- **設計レビュー** → SA + リードデベロッパー + QAリードが同時レビュー
- **受託案件キックオフ** → PM + SA + QAリードが並列でドキュメント作成
- **技術比較** → 複数のリサーチャーが同時調査して比較表を統合

```
あなた: 「A社のDWH設計をやって」
  ↓
秘書: チーム編成
  ├── データアーキテクト → メダリオン全体設計
  ├── システムアーキテクト → 非機能要件・インフラ選定
  └── QAリード           → データ品質テスト戦略
  ↓
統合レポートを .companies/{org}/docs/data/ に保存
PRを自動作成してURLを報告
```

### ③ マスタ駆動で組織が育つ

部署・ロール・ワークフローは md ファイルのマスタで管理。対話的に追加・変更・削除できる。

- `/company-admin` でロール追加 → Subagent ファイル自動生成 → マスタ整合性チェックまで一気通貫
- 部署削除時はデータ有無を確認し、アーカイブを提案（安全策付き）
- 最初は秘書室だけでスタート。使うほど部署が増えて組織が成長する

```
/company-admin
「セキュリティ室を追加して。脆弱性診断と設計レビューを担当」
  ↓
1. masters/departments.md にエントリ追加
2. masters/roles.md に security-engineer ロール追加
3. .claude/agents/security-engineer.md を自動生成
4. docs/security/ フォルダ + CLAUDE.md を作成
5. 組織CLAUDE.md の部署一覧を更新
```

### ④ マルチ組織 + Git PR ワークフロー

案件ごとに独立した組織を作成・切り替え。成果物は自動で PR 管理される。

- `/company` 起動時に組織選択 UI を表示。複数案件を並行運用可能
- ファイル生成時: 自動ブランチ作成 → 作業 → コミット → PR作成 → main 復帰
- 成果物はすべて `.companies/{org}/docs/` に集約。リポジトリルートは汚さない
- CLAUDE.md と masters/ は組織ルート直下に配置（Claude Code の遅延ロード対応）
- `.active` はGit管理しないため、各メンバーが独立して作業組織を選択できます

### ⑤ タスクの実行過程が GitHub Issue で可視化される

ファイル生成を伴うタスクの完了時に、実行過程を GitHub Issue として自動作成する。

- 秘書の判断（なぜその実行モード・ロールを選んだか）
- 各 Subagent の作業サマリーと成果物
- エージェント間の連携内容（誰が誰に何を渡したか）
- ラベルで組織・実行モード・部署・タスク種別をフィルタ可能

```
[a-sha-dwh] DWH メダリオンアーキテクチャ設計     mode:agent-teams  dept:data

## 実行計画（秘書の判断）
- 実行モード: Agent Teams
- アサイン: data-architect, system-architect, qa-lead
- 判断理由: データソース4種 + 分析要件5種 → 並列設計が効率的

## エージェント作業ログ
### data-architect → メダリオン3層設計を完了
### system-architect → Azure Synapse を推奨
### qa-lead → データ品質テスト戦略を策定

## 成果物一覧
| ファイル | 作成者 | パス |
|---------|--------|------|
| メダリオン全体設計 | data-architect | docs/data/models/.../architecture.md |
```

---

## 導入メリット

| 観点 | Before（従来） | After（CC-SIer） |
|------|---------------|-----------------|
| 作業の振り分け | 自分でプロンプトを毎回考える | 秘書がマスタ参照で自動振り分け |
| 専門知識の適用 | 1つのセッションで全領域カバー | 専門 Subagent が独立コンテキストで対応 |
| 並列作業 | 逐次処理のみ | Agent Teams で 3〜5名が同時並行 |
| ナレッジ蓄積 | チャット履歴に埋もれる | 組織ディレクトリに md 形式で永続化 |
| 案件の分離 | 全案件が同じコンテキスト | マルチ組織で案件ごとに独立管理 |
| 成果物の管理 | ルートに散乱 | `docs/` 配下に集約 + PR で変更追跡 |
| 組織の拡張 | 最初から全構成を定義 | `/company-admin` で使いながら動的追加 |
| 作業の追跡 | 「何をやったか」が不明 | タスク完了時に GitHub Issue で自動可視化 |

---

## 導入方法

### 前提条件

- Claude Code がインストール済み
- Agent Teams を有効化（推奨）:
  ```json
  // ~/.claude/settings.json
  {"env":{"CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS":"1"}}
  ```
- GitHub CLI（`gh`）推奨（PR 自動作成に使用）

### ステップ1: リポジトリをクローン

```bash
git clone https://github.com/SAS-Sasao/cc-sier-organization.git
cd cc-sier-organization
```

### ステップ2: Claude Code を起動

```bash
claude
```

`.claude/skills/` と `.claude/agents/` が自動認識される。インストール作業不要。

### ステップ3: 組織を作成

```
/company
```

秘書が起動し、3問のヒアリングで組織を初期化:
1. 組織名（プロジェクト名）
2. オーナー名
3. 事業内容
4. 起動する部署の選択

### ステップ4: 仕事を始める

```
/company
今日のTODOを教えて
```

---

## 同梱 Subagent 一覧（18種）

| Subagent | モデル | 担当領域 |
|----------|--------|---------|
| secretary | opus | 窓口・TODO・壁打ち・メモ・振り分け |
| project-manager | sonnet | WBS・マイルストーン・進捗・リスク管理 |
| system-architect | opus | 全体設計・技術選定・ADR・設計レビュー |
| data-architect | opus | データモデル・DWH・メダリオンアーキテクチャ |
| ai-developer | opus | プロンプト設計・RAG・LLMアプリ開発 |
| lead-developer | sonnet | コードレビュー・技術方針・実装ガイドライン |
| backend-developer | sonnet | API設計・DB設計・サーバーサイド実装 |
| frontend-developer | sonnet | UI実装・UX改善・コンポーネント設計 |
| qa-lead | sonnet | テスト戦略・テスト計画・品質メトリクス |
| test-engineer | sonnet | テスト自動化・テストケース設計・カバレッジ |
| ci-cd-engineer | sonnet | パイプライン設計・デプロイ自動化・リリース |
| cloud-engineer | sonnet | IaC実装・クラウド設計・セキュリティ |
| sre-engineer | sonnet | 監視設計・SLI/SLO・インシデント対応 |
| standards-lead | sonnet | 開発標準・規約管理・テンプレート整備 |
| process-engineer | sonnet | ワークフロー最適化・業務プロセス改善 |
| knowledge-manager | sonnet | ポストモーテム・ナレッジ蓄積・知見構造化 |
| technical-writer | sonnet | 技術文書・教育資料・オンボーディング |
| tech-researcher | sonnet | 技術調査・競合分析・PoC実施 |
| devops-coordinator | sonnet | リポジトリ初期構成・アプリ切り出し・CI/CD |

---

## コマンド一覧

| コマンド | 概要 |
|---------|------|
| `/company` | 組織の作成・選択・秘書との対話・作業依頼 |
| `/company-admin` | マスタ管理（部署・ロール・ワークフローの CRUD） |

---

## ディレクトリ構成

```
cc-sier-organization/
│
├── .claude/                          ← Claude Code が認識する実行ファイル
│   ├── skills/
│   │   ├── company/                  ← /company（メイン Skill）
│   │   │   ├── SKILL.md
│   │   │   └── references/           ← 部署テンプレート、ワークフロー定義等
│   │   └── company-admin/            ← /company-admin（マスタ管理 Skill）
│   │       ├── SKILL.md
│   │       └── references/
│   └── agents/                       ← 18種の Subagent 定義
│       ├── secretary.md
│       ├── system-architect.md
│       └── ...
│
├── .companies/                       ← 組織データ（マルチ組織対応）
│   ├── .active                       ← アクティブ組織の org-slug
│   └── {org-slug}/                   ← 組織ごとのディレクトリ
│       ├── CLAUDE.md                 ← 組織ルール（ルート直下）
│       ├── masters/                  ← マスタデータ（ルート直下）
│       │   ├── organization.md
│       │   ├── departments.md
│       │   ├── roles.md
│       │   └── workflows.md
│       └── docs/                     ← 全成果物はここに集約
│           ├── secretary/            ← 秘書室（TODO・メモ・壁打ち）
│           ├── pm/                   ← プロジェクト管理室
│           ├── architecture/         ← アーキテクチャ室
│           ├── development/          ← 開発室
│           ├── quality/              ← 品質管理室
│           ├── infra/                ← インフラ・IaC室
│           └── ...
│
├── dist/cc-sier/                     ← 配布用プラグインパッケージ
│   ├── .claude-plugin/               ← sync-to-dist.sh で生成
│   ├── skills/
│   └── agents/
│
├── docs/
│   └── requirements.md               ← 要件定義書
├── CLAUDE.md                         ← 開発用指示ファイル
├── README.md
└── LICENSE
```

| 層 | パス | 役割 |
|----|------|------|
| Skills / Subagent | `.claude/` | Claude Code が認識する Skill と Subagent の実体 |
| 組織データ | `.companies/` | マスタ定義 + `docs/` 配下の成果物（案件ごとに独立） |
| 配布パッケージ | `dist/` | `sync-to-dist.sh` で生成するプラグイン配布用ファイル |

---

## ライセンス

MIT
