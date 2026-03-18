# CC-SIer

**Claude Code 仮想組織プラグイン — SIer業務特化版**

## 概要

SIer業務は多領域にまたがります。プロジェクト管理、システム設計、受託開発、標準化、AI駆動開発、テスト自動化、CI/CD、IaC、データアーキテクチャ（DWH構築）—— これらが同時並行で走る環境において、Claude Code 上に**仮想組織**を構築し、業務ごとに専門化されたエージェントチームを動的に編成・運用する仕組みを提供します。

[cc-company v2.0.0](https://github.com/Shin-sibainu/cc-company) の「秘書 → 部署」モデルを踏襲しつつ、以下の進化を加えています:

1. **マスタ駆動の動的組織編成** — 組織・部署・メンバー（エージェントロール）をmdファイルでマスタ管理し、Skillが作業依頼に応じて最適な構成を提案
2. **Claude Code 公式機能への正確なマッピング** — Skills、Subagents、Agent Teams、CLAUDE.md をそれぞれの正規ディレクトリに配置
3. **SIer業務ドメインの深い対応** — 受託開発ライフサイクル、標準化活動、ナレッジ蓄積に特化したテンプレートとワークフロー
4. **Skill経由のマスタ管理** — `/company-admin` で部署・ロール・ワークフローを対話的にCRUD。変更時にはSubagentファイルやCLAUDE.mdへの整合性連鎖更新が自動で実行

---

## クイックスタート

### 開発モード（このリポジトリで直接使う）

```bash
git clone https://github.com/SAS-Sasao/cc-sier-organization.git
cd cc-sier-organization
claude
```

`.claude/` 配下の Skill と Subagent が即座に認識されます。追加設定は不要です。

### 配布モード（プラグインとして配布）

```bash
# dist/ に配布用パッケージを生成
./scripts/sync-to-dist.sh

# dist/cc-sier/ をプラグインとして配布
# （プラグインインストール手順は今後公開予定）
```

---

## 利用可能なコマンド

| コマンド | 説明 |
|---------|------|
| `/company` | メインSkill。秘書に話しかける。TODO管理、壁打ち、作業依頼の受付・振り分け |
| `/company-admin` | マスタ管理Skill。部署・ロール・ワークフローの追加・変更・削除を対話的に実行 |

### /company でできること

- **初回**: オンボーディング（3問のヒアリングで組織を初期化）
- **日常**: TODO管理、壁打ち、メモ、ダッシュボード表示
- **作業依頼**: マスタのトリガーワードに基づいて最適な部署・Subagentに自動振り分け
- **並列作業**: Agent Teams を使った設計レビュー、フルスタック開発等

### /company-admin でできること

- 部署の追加・変更・削除（連鎖更新: フォルダ作成、CLAUDE.md生成）
- ロールの追加・変更・削除（連鎖更新: Subagentファイル自動生成）
- ワークフローの追加・変更・削除
- プロジェクトの追加・更新
- 組織情報・MCPサービスの管理

---

## 同梱 Subagent 一覧（18種）

### opus モデル（複雑な判断・設計タスク）

| 名前 | ファイル | 担当領域 |
|------|---------|---------|
| 秘書 | `secretary.md` | TODO管理、壁打ち、メモ、作業振り分け |
| システムアーキテクト | `system-architect.md` | 全体設計、技術選定、ADR、設計レビュー |
| データアーキテクト | `data-architect.md` | データモデル設計、DWH、メダリオンアーキテクチャ |
| AI駆動開発エンジニア | `ai-developer.md` | プロンプト設計、RAGパイプライン、LLMアプリ |

### sonnet モデル（標準的な実装・文書作成）

| 名前 | ファイル | 担当領域 |
|------|---------|---------|
| プロジェクトマネージャー | `project-manager.md` | WBS、マイルストーン、進捗・リスク管理 |
| リードデベロッパー | `lead-developer.md` | コードレビュー、技術方針、実装ガイドライン |
| バックエンドデベロッパー | `backend-developer.md` | API設計・実装、DB設計 |
| フロントエンドデベロッパー | `frontend-developer.md` | UI実装、UX改善、コンポーネント設計 |
| QAリード | `qa-lead.md` | テスト戦略策定、テスト計画、品質メトリクス |
| テストエンジニア | `test-engineer.md` | テスト自動化、テストケース設計、カバレッジ |
| CI/CDエンジニア | `ci-cd-engineer.md` | パイプライン設計・構築、デプロイ自動化 |
| クラウドエンジニア | `cloud-engineer.md` | IaC実装、クラウドアーキテクチャ、セキュリティ |
| SREエンジニア | `sre-engineer.md` | 監視設計、SLI/SLO、インシデント対応 |
| 標準化リード | `standards-lead.md` | 開発標準、規約管理、テンプレート整備 |
| プロセスエンジニア | `process-engineer.md` | ワークフロー最適化、業務プロセス改善 |
| ナレッジマネージャー | `knowledge-manager.md` | ポストモーテム管理、ナレッジ蓄積 |
| テクニカルライター | `technical-writer.md` | 技術文書、教育資料、オンボーディング |
| テクニカルリサーチャー | `tech-researcher.md` | 技術調査、競合分析、PoC |

---

## ファイル構成

本リポジトリは **開発用（.claude/）** と **配布用（dist/）** のデュアル構造です。

```
cc-sier-organization/
│
├── .claude/                          ← 開発モード: Claude Code が直接認識
│   ├── skills/
│   │   ├── company/                  ← /company コマンド
│   │   │   ├── SKILL.md
│   │   │   └── references/           ← 部署テンプレート、ワークフロー定義等
│   │   └── company-admin/            ← /company-admin コマンド
│   │       ├── SKILL.md
│   │       └── references/
│   └── agents/                       ← 18種の Subagent
│       ├── secretary.md
│       ├── system-architect.md
│       ├── ... (全18ファイル)
│       └── tech-researcher.md
│
├── plugins/cc-sier/                  ← 開発ソース（.claude/ の原本）
│   ├── skills/                       ← Skill ソース
│   │   ├── company/
│   │   └── company-admin/
│   └── agents/                       ← Subagent ソース
│
├── .claude-plugin/                   ← プラグインメタデータ
│   ├── marketplace.json
│   └── plugin.json
│
├── dist/cc-sier/                     ← 配布モード: sync-to-dist.sh で生成
│   ├── .claude-plugin/
│   ├── skills/
│   └── agents/
│
├── scripts/
│   └── sync-to-dist.sh              ← 配布用パッケージ生成スクリプト
│
├── docs/
│   ├── requirements.md               ← 要件定義書 v0.3
│   └── testing-guide.md              ← テスト手順書
│
├── CLAUDE.md                         ← 開発用の指示ファイル
├── README.md                         ← このファイル
└── LICENSE
```

### 開発フロー

1. `plugins/cc-sier/` 配下を編集（ソース原本）
2. `.claude/` にコピーして動作確認（`cp -r plugins/cc-sier/skills/* .claude/skills/` 等）
3. 確認後、`scripts/sync-to-dist.sh` で配布用パッケージを生成

---

## コンセプト

```
[CC-SIer 機能マッピング]

Claude Code 機能         本プラグインでの用途
─────────────────────    ──────────────────────────────────
CLAUDE.md                組織ルール、部署ルール、運営ポリシーの永続的な指示
Skills (.claude/skills/) /company コマンド、マスタ参照ロジック、ワークフロー実行
Subagents (.claude/agents/) 部署ロールの実体（SA、PM、QA等の専門エージェント）
Agent Teams              大規模並列作業（設計レビュー、フルスタック開発等）
Plugins (.claude-plugin/)  CC-SIer全体のパッケージング・配布

[実行フロー]

/company 実行
  │
  ▼
Skill (SKILL.md) が起動
  │
  ├─ masters/ を参照して実行方式を判定
  │
  ├─ [subagent の場合]
  │   └─ 名前指定で Subagent を呼び出し
  │      → 独立コンテキストで専門作業を実行
  │
  └─ [agent-teams の場合]
      └─ チームリード（秘書）が Agent Teams を編成
         → 複数テイメイトが並列作業
         → 共有タスクリスト + メールボックスで自律連携
```

---

## ライセンス

MIT
