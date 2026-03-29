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

**⑥ 成果物の品質を自動チェック**
`docs/` 配下に .md ファイルを保存するたびに品質ゲートが自動起動します。必須セクションの欠落・顧客制約違反を検出してGitHub Issueを作成し、タスクボードに差し戻しを記録します。「確認が手動で大変」という作業が自動化されます。

**⑦ 進捗をダッシュボードで一望**
`/company-dashboard` でHTMLダッシュボードを生成します。タスクボードの状況・品質ゲート合格率・Subagent使用頻度・スコア推移をアニメーション付きで可視化します。GitHub Pagesで公開すればチーム全員がブラウザから確認できます。

**⑧ 会話がそのまま学習データになる**
セッション終了時に人間の発言・Claudeの応答・ツール実行をすべて自動でMarkdownに保存します。顧客名などの固有名詞は `[CLIENT-01]` 形式に自動マスキングされます。蓄積された会話ログは `/company-evolve` 実行時にCase Bankを補強し、「なぜその依頼をしたか」という背景情報が秘書の委譲判断に反映されます。

**⑨ AWS構成図をコマンド一つで生成**
「DWHの構成図を描いて」と言うだけでAWS Diagram MCP Serverが構成図PNGを生成し、GitHub Pagesのギャラリーに自動公開します。一覧ページと詳細ページが自動生成され、ダッシュボードからもリンクされます。

**⑩ 日次ダイジェストをWebで閲覧**
`/company-digest-html` で日次ダイジェストのMarkdownをインタラクティブなHTMLに変換します。日付タブ・キーボードナビ・ダークモード対応で、GitHub Pagesから誰でも閲覧できます。

**⑪ 成果物を3軸で自動品質評価**（LLM-as-Judge）
タスク完了時に成果物を **completeness（網羅性）・accuracy（正確性）・clarity（明瞭性）** の3軸で自動評価します。スコアはCase Bankに蓄積され、低スコアの失敗パターンは次回のルーティング判断に自動注入されます。

**⑫ 全活動をナレッジポータルで引き継ぎ**
`/company-handover` でClaude Codeとの全活動（PJ業務・Skill追加・MCP導入・壁打ち等）を自動収集し、検索・フィルタ可能なHTMLポータルとして可視化します。feedback memoryの教訓やCase Bankの暗黙知も構造化して表示。新メンバーへの引き継ぎや「あの判断いつだっけ」の検索に使えます。

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
| ⑪ 品質ゲートセットアップ | `/company-quality-setup` | アクティブ組織にチェックリストを配置 |
| ⑫ 品質チェック（手動） | `/company-review` | 成果物を任意タイミングでチェック |
| ⑬ 品質チェック（自動） | PostToolUse Hook | docs/ への保存時に自動でチェック |
| ⑭ ダッシュボード生成 | `/company-dashboard` | 活動状況をHTMLで可視化 |
| ⑮ 会話ログ自動保存 | Stop Hook | 発言・応答・ツール実行を自動記録 |
| ⑯ 固有名詞マスキング | capture-conversation.sh | 顧客名などを自動でマスク処理 |
| ⑰ Case Bank強化 | `/company-evolve` | 会話の背景・意図を学習データに統合 |
| ⑱ AWS構成図生成 | `/company-diagram` | AWS Diagram MCP Serverで構成図PNGを生成しGitHub Pagesギャラリーに公開 |
| ⑲ 汎用ダイアグラム生成 | `/company-drawio` | draw.io MCP ServerでER図・フローチャート・C4モデル等を生成しGitHub Pagesギャラリーに公開 |
| ⑳ 日次ダイジェストHTML | `/company-digest-html` | 日次ダイジェストMDをHTMLに変換しGitHub Pagesで閲覧 |
| ㉑ LLM-as-Judge 品質評価 | 秘書が自動実行 | 成果物をcompleteness/accuracy/clarityの3軸で自動評価 |
| ㉒ MCP Server連携 | `.mcp.json` | AWS Knowledge・AWS Diagram・draw.ioの3つのMCP Serverを統合 |
| ㉓ ナレッジポータル生成 | `/company-handover` | 全活動履歴・判断履歴・暗黙知をHTML化しGitHub Pagesで公開 |

### ダイアグラムSkillの使い分け

| 用途 | 使うSkill | 出力形式 |
|------|----------|---------|
| 高品質なAWS構成図を一発生成（レビュー・共有用） | `/company-diagram` | PNG（閲覧専用） |
| 編集可能なダイアグラムが欲しい（AWS構成図含む） | `/company-drawio` | draw.io XML（完全編集可） |
| 過去の `/company-diagram` 成果物を編集可能にしたい | 既存の構成図を指定して `/company-drawio` でリバース生成 | draw.io XML |

- `/company-diagram` は Python diagrams パッケージ（Graphviz）で PNG を直接生成するため、出力後の構造的な編集はできません
- `/company-drawio` は draw.io の AWS アイコンセットを使用でき、生成後も draw.io エディタで自由に編集・再配置が可能です
- 過去に `/company-diagram` で作成した構成図は、メタデータ（`.companies/{org}/docs/diagrams/{name}.md`）に Python DSL ソースコードと構成情報が保存されているため、これを参照して `/company-drawio` で同等の編集可能な図を再生成できます

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
  ├── 会話ログ取得       : 発言・応答・ツール実行を自動保存（マスキング済み）
  ├── Skill Evaluator    : タスクの成否を報酬スコアで評価
  ├── Case Bank 再構築   : 全タスクを構造化インデックスに保存
  ├── Case Bank 強化     : 会話の背景・意図・頻出フレーズをエントリに付加
  ├── MEMORY.md 更新     : 出力スタイル・ルーティング先読みを学習
  ├── ワークフロー生成   : 高品質パターンを手順書として登録
  ├── Skill Synthesizer  : 未対応パターンに新規Skillを提案（PR）
  └── Subagent Refiner   : 実績でAgentの説明・制約を精緻化（PR）
       └── Subagent Spawner: 対応Agentがない作業に新規Agentを生成（PR）

Read フェーズ（次のセッション起動時）
  └── 秘書が Case Bank を参照 → 類似タスクの高品質パターンをルーティングに反映
```

### 評価指標

#### 報酬スコア（自動4シグナル）

タスクを以下の4シグナルで自動評価し、0.0〜1.0のスコアを付与します。

| シグナル | 内容 |
|---|---|
| completed | status が completed であるか |
| artifacts_exist | 成果物ファイルが実際に存在するか |
| no_excessive_edits | 同一ファイルへの修正が5回以下か |
| no_retry | 「やり直し」などの否定的フィードバックがないか |

#### LLM-as-Judge（3軸品質評価）

成果物が `docs/` 配下にある場合、秘書がコミット前に3軸で評価します。

| 軸 | 評価内容 | スケール |
|---|---|---|
| completeness | 必須項目の網羅度 | 0-10 |
| accuracy | 技術的正確さ | 0-10 |
| clarity | 依頼意図との一致度 | 0-10 |

`total = (completeness + accuracy + clarity) / 30` → 0.0〜1.0。低スコアの失敗パターンは次回のルーティング判断に自動注入されます。

詳細は [`docs/guide/05-learning-system.md`](docs/guide/05-learning-system.md)、[`docs/guide/13-llm-as-judge.md`](docs/guide/13-llm-as-judge.md) を参照。

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
│   │   ├── company-evolve/        # /company-evolve Skill（継続学習）
│   │   ├── company-review/         # /company-review Skill（品質チェック）
│   │   ├── company-quality-setup/  # /company-quality-setup Skill
│   │   │   └── templates/          # チェックリストのマスターテンプレート
│   │   ├── company-dashboard/      # /company-dashboard Skill
│   │   ├── company-diagram/        # /company-diagram Skill（AWS構成図生成）
│   │   ├── company-drawio/         # /company-drawio Skill（汎用ダイアグラム生成）
│   │   ├── company-digest-html/    # /company-digest-html Skill（ダイジェストHTML）
│   │   └── company-handover/       # /company-handover Skill（ナレッジポータル生成）
│   └── hooks/
│       ├── capture-interaction.sh # PostToolUse: ツール実行ログ
│       ├── session-boundary.sh    # Stop: セッション集計・GitHub Issue
│       ├── skill-evaluator.sh     # 報酬スコア付与
│       ├── rebuild-case-bank.sh   # Case Bank 再構築
│       ├── skill-synthesizer.sh   # 新規Skill自動生成
│       ├── subagent-refiner.sh    # Agent精緻化・新規生成
│       ├── quality-gate.sh         # PostToolUse: 品質チェック自動実行
│       ├── update-board.sh         # タスクボード更新ユーティリティ
│       ├── generate-dashboard.sh   # ダッシュボードHTML生成
│       ├── capture-conversation.sh  # Stop: 会話ログ取得・マスキング・MD保存
│       ├── enrich-case-bank.sh      # Case Bankへの会話コンテキスト付加
│       ├── generate-daily-digest-html.sh # ダイジェストHTML生成
│       ├── generate-handover-data.sh  # ナレッジポータルdata.json生成
│       └── generate-handover-html.sh  # ナレッジポータルHTML生成
│
├── .mcp.json                        # MCP Server設定（AWS Knowledge / AWS Diagram）
│
├── .companies/
│   ├── .active                    # 現在のアクティブ組織
│   └── {org-slug}/
│       ├── CLAUDE.md              # 組織状態サマリー
│       ├── masters/               # 組織マスタ（顧客・役割・ワークフロー・品質ゲート）
│       │   └── quality-gates/     # 品質チェックリスト
│       ├── docs/                  # 成果物（Git管理）
│       │   └── secretary/         # 秘書ログ・TODO・レポート
│       │       ├── board.md       # タスクボード（自動更新）
│       │       └── dashboard.html # ダッシュボード（自動生成）
│       ├── .task-log/             # タスク実行ログ（Git管理）
│       ├── .interaction-log/      # ツール実行ログ（Git管理外）
│       ├── .session-summaries/    # セッション統計（Git管理外）
│       ├── .case-bank/            # 継続学習インデックス（Git管理外）
│       │   └── enrich-log.json     # 会話ログ処理済み管理
│       ├── .quality-gate-log/      # 品質チェック結果ログ（Git管理外）
│       └── .conversation-log/      # 会話ログMD（Git管理外・マスキング済み）
│
├── docs/
│   ├── guide/                     # 詳細ガイド
│   ├── diagrams/                  # AWS構成図ギャラリー（GitHub Pages）
│   │   ├── index.html             # 一覧ページ（カードグリッド）
│   │   └── {name}.html / .png    # 各構成図の詳細ページとPNG
│   ├── daily-digest/              # 日次ダイジェストHTML（GitHub Pages）
│   │   └── index.html             # タブ切替SPAページ
│   └── handover/                  # ナレッジポータル（GitHub Pages）
│       ├── index.html             # 全活動年表・判断履歴・Tips
│       └── data.json              # 構造化データ（エントリ・判断・Tips）
│
└── generated-diagrams/            # 構成図生成の中間ファイル（.gitignore）
```

---

## GitHub Pages ポータル

**https://sas-sasao.github.io/cc-sier-organization/**

各組織のダッシュボードや成果物をブラウザから閲覧できるポータルサイトです。5分ごとに自動リフレッシュされます。

| ページ | URL | 内容 |
|---|---|---|
| ポータルトップ | [/](https://sas-sasao.github.io/cc-sier-organization/) | 組織選択画面。各ダッシュボード・コンテンツへのハブ |
| 組織ダッシュボード | [/secretary/{org-slug}/dashboard.html](https://sas-sasao.github.io/cc-sier-organization/secretary/domain-tech-collection/dashboard.html) | タスクボード状況・品質ゲート合格率・Subagent使用頻度・スコア推移をアニメーション付きで可視化 |
| 日次ダイジェスト | [/daily-digest/](https://sas-sasao.github.io/cc-sier-organization/daily-digest/index.html) | 技術・小売ニュース巡回の日次ダイジェストを日付タブ・キーボードナビ・ダークモード対応で閲覧 |
| AWS構成図ギャラリー | [/diagrams/](https://sas-sasao.github.io/cc-sier-organization/diagrams/index.html) | `/company-diagram` で生成したAWSアーキテクチャ構成図の一覧・詳細表示 |
| draw.ioダイアグラムギャラリー | [/drawio/](https://sas-sasao.github.io/cc-sier-organization/drawio/index.html) | `/company-drawio` で生成したER図・フローチャート・C4モデル等の一覧・詳細表示 |
| ナレッジポータル | [/handover/](https://sas-sasao.github.io/cc-sier-organization/handover/index.html) | 全活動履歴・判断履歴・暗黙知の検索・閲覧ポータル |

ダッシュボードは `/company-dashboard` で生成、日次ダイジェストは `/company-digest-html` で生成、構成図は `/company-diagram` と `/company-drawio` で生成、ナレッジポータルは `/company-handover` で生成されます。

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
- uv（MCP Server の実行に必要）
- GraphViz（AWS構成図生成に必要。`dot -V` で確認）

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
| [08 ファイル構成リファレンス](docs/guide/08-file-reference.md) | 全ファイルの役割詳細リファレンス |
| [09 品質ゲートとダッシュボード](docs/guide/09-quality-dashboard.md) | 品質チェック・ボード・可視化の詳細 |
| [10 会話ログと継続学習](docs/guide/10-conversation-log.md) | 会話ログの自動取得・マスキング・学習への活用 |
| [11 AWS構成図生成](docs/guide/11-diagram-generation.md) | AWS Diagram MCP Serverによる構成図生成とギャラリー |
| [12 日次ダイジェスト](docs/guide/12-daily-digest.md) | 日次ダイジェストのHTML変換とGitHub Pages公開 |
| [13 LLM-as-Judge 品質評価](docs/guide/13-llm-as-judge.md) | 3軸自動品質評価と失敗パターン学習 |
| [14 draw.ioダイアグラム生成](docs/guide/14-drawio-generation.md) | draw.io MCP Serverによる汎用ダイアグラム生成とギャラリー |
| [15 ナレッジポータル](docs/guide/15-knowledge-portal.md) | 全活動履歴の可視化・引き継ぎポータル |

---

## ライセンス

MIT
