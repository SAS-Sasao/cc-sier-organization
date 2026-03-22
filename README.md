# cc-sier-organization

**Claude Code で SIer の仕事を仮想組織として動かすプラグイン**

```
あなた ──依頼──▶ 秘書エージェント ──振り分け──▶ 専門Subagent ──成果物──▶ Git PR
                      ↑                                              ↓
              Case Bank 参照                             自動ログ・学習
```

Claude Code に「組織」の概念を持ち込み、秘書エージェントが依頼を受け取り、専門Subagentに委譲し、成果物をGit経由で管理します。使うほど賢くなる継続学習機能を内蔵しています。

---

## なぜ cc-sier-organization を使うのか

### 普通の Claude Code との違い

| | 普通の Claude Code | cc-sier-organization |
|---|---|---|
| 依頼の振り分け | 毎回手動でコンテキスト説明 | 秘書が自動でSubagentに委譲 |
| 成果物の管理 | フォルダが散乱しがち | `.companies/{org}/docs/` に自動整理 |
| 作業履歴 | セッションをまたいで消える | `.task-log/` + GitHub Issues に永続化 |
| 組織のルール | プロンプトで毎回説明 | `masters/` に一度書けばずっと参照 |
| 複数プロジェクト | ディレクトリを手動で切り替え | `/company {org}` で一発切り替え |
| 品質の向上 | 指示を繰り返すしかない | 継続学習で自動的に精度が上がる |

### 具体的なメリット

**① 認知負荷ゼロの委譲**
「A社のDWH設計をやって」と言うだけで、秘書が data-architect Subagentに委譲し、設計書を `docs/data/` に配置してPRを作ります。何を誰に頼むかを考えなくていい。

**② ルールの一元管理**
顧客ごとの制約、部署ごとの文書フォーマット、使用技術スタックを `masters/` に記述すれば、全Subagentが自動参照します。「前も言ったのに」がなくなります。

**③ 作業履歴が自動で残る**
ツール実行のたびに `.interaction-log/` に記録され、セッション終了時に GitHub Issues に自動投稿されます。振り返りや引き継ぎが楽になります。

**④ 組織がだんだん賢くなる**（継続学習 / Memento-Skills）
使えば使うほど、高品質だった作業パターンが自動でワークフロー化されます。Subagentの説明文が実績データで更新されます。新しいSkillやSubagentが必要になったら自動生成を提案します。

**⑤ 複数組織・複数プロジェクトを一つのリポジトリで**
`/company-spawn` で新しいアプリリポジトリを切り出しながら、元の組織の知識は共有し続けられます。

---

## できること

| 機能 | コマンド / Skill | 説明 |
|---|---|---|
| ① 組織を作る・入る | `/company` | 引数なしで起動→メニューから新規作成または既存組織に切り替え |
| ② タスクを依頼 | 自然言語で話しかける | 秘書が自動でSubagentに振り分け |
| ③ マスタ管理 | `/company-admin` | 顧客・役割・ワークフローのCRUD |
| ④ アプリ切り出し | `/company-spawn` | 新規Gitリポジトリを生成 |
| ⑤ 定期レポート | `/company-report` | 週次・月次サマリーをGitへ |
| ⑥ 継続学習 | `/company-evolve` | 組織の知識と手順を自動更新 |
| ⑦ ログ自動記録 | Stop hook | セッション終了時にIssueへ自動投稿 |
| ⑧ Skill 自動生成 | Skill Synthesizer | 繰り返しパターンからSkillを生成 |
| ⑨ Agent 精緻化 | Subagent Refiner | 実績データでAgentを自動更新 |
| ⑩ Agent 自動生成 | Subagent Spawner | 対応Agentがない作業に新規生成 |

---

## 同梱の組織・Subagent

### 組織

`/company` を引数なしで実行するとメニューが表示されます。
既存組織への切り替えと新規組織の作成をメニューから選べます。

**初期同梱の3組織（すぐに使い始められます）:**

| org-slug | 用途 |
|---|---|
| `standardization-initiative` | 社内標準化・ガイドライン策定 |
| `jutaku-dev-team` | 受注開発プロジェクト管理 |
| `domain-tech-collection` | 技術調査・ドメイン知識蓄積 |

**新規組織を作成する場合:**

```
/company
→ メニューから「新規組織を作成」を選択
→ 4問の対話に答えると自動生成されます
```

実行すると `.companies/{org-slug}/` 配下のディレクトリ構成・CLAUDE.md・masters/ が自動生成されます。

### Subagent（20種）

秘書（secretary）が依頼内容に応じて以下のSubagentに委譲します。

| カテゴリ | Subagent |
|---|---|
| 設計 | system-architect, data-architect, infra-engineer |
| 開発 | backend-engineer, frontend-engineer, devops-engineer |
| 文書 | technical-writer, proposal-writer, report-writer |
| PM | project-manager, scrum-master |
| 分析 | business-analyst, data-analyst, cost-optimizer |
| 知識管理 | knowledge-manager, domain-researcher |
| 品質 | code-reviewer, qa-engineer |
| その他 | security-engineer, integration-specialist |

---

## 継続学習（Memento-Skills ベース）

cc-sier-organization は論文「Memento-Skills: Let Agents Design Agents」の設計思想を実装しています。

### 仕組みの概要

```
Write フェーズ（セッション終了・/company-evolve 起動時）
  ├── Skill Evaluator    : タスクの成否を報酬スコアで評価
  ├── Case Bank 再構築   : 全タスクを構造化インデックスに保存
  ├── MEMORY.md 更新     : 出力スタイル・ルーティング先読みを学習
  ├── ワークフロー生成   : 高品質パターンを手順書として登録
  ├── Skill Synthesizer  : 未対応パターンに新規Skillを提案（PR）
  └── Subagent Refiner   : 実績でAgentの説明・制約を精緻化（PR）
       └── Subagent Spawner: 対応Agentがない作業に新規Agentを生成（PR）

Read フェーズ（次のセッション起動時）
  └── 秘書が Case Bank を参照 → 類似タスクの高品質パターンをルーティングに反映
```

### 評価指標（報酬スコア）

タスクを以下の4シグナルで自動評価し、0.0〜1.0のスコアを付与します。

| シグナル | 内容 |
|---|---|
| completed | status が completed であるか |
| artifacts_exist | 成果物ファイルが実際に存在するか |
| no_excessive_edits | 同一ファイルへの修正が5回以下か |
| no_retry | 「やり直し」などの否定的フィードバックがないか |

詳細は [`docs/guide/05-learning-system.md`](docs/guide/05-learning-system.md) を参照。

---

## ディレクトリ構成

```
cc-sier-organization/
│
├── .claude/
│   ├── settings.json              # Hooks設定（自動ログ・学習）
│   ├── agents/
│   │   ├── secretary.md           # 秘書（メインエージェント）
│   │   └── {subagent}.md × 20    # 専門Subagent
│   ├── skills/
│   │   ├── company/               # /company Skill
│   │   ├── company-admin/         # /company-admin Skill
│   │   ├── company-spawn/         # /company-spawn Skill
│   │   ├── company-report/        # /company-report Skill
│   │   └── company-evolve/        # /company-evolve Skill（継続学習）
│   └── hooks/
│       ├── capture-interaction.sh # PostToolUse: ツール実行ログ
│       ├── session-boundary.sh    # Stop: セッション集計・GitHub Issue
│       ├── skill-evaluator.sh     # 報酬スコア付与
│       ├── rebuild-case-bank.sh   # Case Bank 再構築
│       ├── skill-synthesizer.sh   # 新規Skill自動生成
│       └── subagent-refiner.sh    # Agent精緻化・新規生成
│
├── .companies/
│   ├── .active                    # 現在のアクティブ組織
│   └── {org-slug}/
│       ├── CLAUDE.md              # 組織状態サマリー
│       ├── masters/               # 組織マスタ（顧客・役割・ワークフロー）
│       ├── docs/                  # 成果物（Git管理）
│       ├── .task-log/             # タスク実行ログ（Git管理）
│       ├── .interaction-log/      # ツール実行ログ（Git管理外）
│       ├── .session-summaries/    # セッション統計（Git管理外）
│       └── .case-bank/            # 継続学習インデックス（Git管理外）
│
└── docs/
    └── guide/                     # 詳細ガイド
```

---

## クイックスタート

### 1. セットアップ

```bash
git clone https://github.com/SAS-Sasao/cc-sier-organization
cd cc-sier-organization

# Hooksの実行権限を付与
chmod +x .claude/hooks/*.sh

# GitHub CLI（自動Issue投稿に必要）
gh auth login
```

### 2. 組織に入る

```bash
/company jutaku-dev-team
```

### 3. 依頼する

```
A社の要件定義書を作成してほしい。
クラウドネイティブなWebシステムで、ユーザー管理・在庫管理・発注管理が必要。
```

### 4. 学習を走らせる

```
/company-evolve
```

---

## インストール要件

- Claude Code（最新版）
- Git
- GitHub CLI（`gh`）: Issue/PR の自動作成に必要
- Python 3（継続学習の Case Bank 構築に必要）
- bash

---

## 詳細ガイド

| ドキュメント | 内容 |
|---|---|
| [00 全体概要](docs/guide/00-overview.md) | 設計思想・アーキテクチャ |
| [01 クイックスタート](docs/guide/01-quickstart.md) | 初期設定から最初の依頼まで |
| [02 Skills リファレンス](docs/guide/02-skills.md) | 全Skillの使い方と引数 |
| [03 Subagent 一覧](docs/guide/03-subagents.md) | 各Subagentの役割と得意領域 |
| [04 Hooks 設定](docs/guide/04-hooks.md) | 自動ログ・カスタマイズ |
| [05 継続学習システム](docs/guide/05-learning-system.md) | Phase 1〜3の詳細仕様 |
| [06 マルチ組織運用](docs/guide/06-multi-org.md) | 複数組織の管理方法 |
| [07 company-spawn](docs/guide/07-company-spawn.md) | アプリリポジトリの切り出し方 |

---

## ライセンス

MIT
