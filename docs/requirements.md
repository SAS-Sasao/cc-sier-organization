# CC-SIer 要件定義書 v0.2

## Claude Code 仮想組織プラグイン — SIer業務特化版

| 項目 | 内容 |
|------|------|
| ドキュメント種別 | 要件定義書（詳細レベル） |
| バージョン | 0.3.0（マスタ管理Skill追加） |
| 作成日 | 2026-03-18 |
| ベースライン | [cc-company v2.0.0](https://github.com/Shin-sibainu/cc-company) |
| 参照公式ドキュメント | [Skills](https://code.claude.com/docs/en/skills) / [Subagents](https://code.claude.com/docs/en/sub-agents) / [Agent Teams](https://code.claude.com/docs/en/agent-teams) / [CLAUDE.md](https://claude.com/blog/using-claude-md-files) |
| ステータス | レビュー待ち |

---

## 1. プロジェクト概要

### 1.1 背景と目的

SIer業務は多領域にまたがる。プロジェクト管理、システム設計、受託開発、標準化、AI駆動開発、テスト自動化、CI/CD、IaC、データアーキテクチャ（DWH構築）—— これらが同時並行で走る環境において、Claude Code 上に**仮想組織**を構築し、業務ごとに専門化されたエージェントチームを動的に編成・運用する仕組みを作る。

cc-company の「秘書 → 部署」モデルを踏襲しつつ、以下の進化を加える:

1. **マスタ駆動の動的組織編成** — 組織・部署・メンバー（エージェントロール）をmdファイルでマスタ管理し、SKILLが作業依頼に応じて最適な構成を提案する
2. **Claude Code 公式機能への正確なマッピング** — Skills（`.claude/skills/`）、Subagents（`.claude/agents/`）、Agent Teams、CLAUDE.md をそれぞれの正規ディレクトリに配置し、Claude Code の仕組みを最大限に活用する
3. **SIer業務ドメインの深い対応** — 受託開発ライフサイクル、標準化活動、ナレッジ蓄積に特化したテンプレートとワークフロー
4. **Skill経由のマスタ管理** — ユーザーが対話的に部署・ロール・ワークフローを追加・更新・削除でき、変更時にはSubagentファイルやCLAUDE.mdへの整合性連鎖更新が自動で行われる

### 1.2 スコープ

| 区分 | 内容 |
|------|------|
| **スコープ内** | プラグイン構造設計、Skill/Subagent定義、マスタスキーマ、部署テンプレート、ワークフロー定義、Agent Teams連携設計、MCP連携インターフェース定義 |
| **スコープ外（実装後回し）** | MCP連携の実装、外部ツール（Backlog・GitHub・Slack等）との実際の接続 |

### 1.3 利用シーン

- **Phase 1**: 自分1人の業務効率化として運用開始
- **Phase 2**: チームメンバーへ展開（プラグインとして配布）

---

## 2. Claude Code 機能マッピング

### 2.1 Claude Code の拡張機能体系

公式ドキュメントに基づく、本プラグインが活用する Claude Code 機能の整理。

| 機能 | 配置場所 | ロードタイミング | 本プラグインでの用途 |
|------|---------|-----------------|-------------------|
| **CLAUDE.md** | プロジェクトルート / サブディレクトリ | セッション開始時に自動ロード（サブディレクトリは遅延ロード） | 組織ルール、部署ルール、運営ポリシーの永続的な指示 |
| **Skills** | `.claude/skills/[name]/SKILL.md` | フロントマター（name/description）はセッション開始時にロード。SKILL.md本文はスキル発動時にロード | `/company` コマンド、マスタ参照ロジック、ワークフロー実行 |
| **Subagents** | `.claude/agents/[name].md` | セッション開始時に一覧ロード。タスク委譲時に独立コンテキストで起動 | 部署ロールの実体（SA、PM、QA等の専門エージェント） |
| **Agent Teams** | 実行時に動的編成 | チームリードがテイメイトをスポーン | 大規模並列作業（設計レビュー、フルスタック開発等） |
| **Plugins** | `.claude-plugin/` + `skills/` + `agents/` | プラグインインストール時 | CC-SIer全体のパッケージング・配布 |

### 2.2 成果物とClaude Code機能の対応

本プラグインが生成・管理する成果物が、Claude Code のどの機能に対応し、どのディレクトリに配置されるかの全体マップ。

```
[CC-SIer プラグイン構造]
cc-sier/
├── .claude-plugin/
│   ├── marketplace.json          ← プラグインメタデータ（配布用）
│   └── plugin.json               ← プラグイン定義
│
├── skills/
│   ├── company/
│   │   ├── SKILL.md              ← メインSkill（/company コマンド）
│   │   └── references/
│   │       ├── departments.md     ← 部署テンプレート集
│   │       ├── claude-md-template.md ← CLAUDE.md生成テンプレート
│   │       ├── workflow-definitions.md ← ワークフロー定義集
│   │       ├── agent-templates.md ← Subagent生成テンプレート集
│   │       ├── sier-templates.md  ← SIer業務特化テンプレート
│   │       └── master-schemas.md  ← マスタスキーマ・バリデーションルール
│   │
│   └── company-admin/             ← マスタ管理Skill（/company-admin コマンド）
│       ├── SKILL.md              ← マスタCRUD＋連鎖更新ロジック
│       └── references/
│           └── master-schemas.md  ← （company/ と同一内容を参照）
│
├── agents/                        ← Subagent定義（プラグイン同梱）
│   ├── secretary.md               ← 秘書エージェント
│   ├── project-manager.md         ← PMエージェント
│   ├── system-architect.md        ← SAエージェント
│   ├── data-architect.md          ← データアーキテクト
│   ├── lead-developer.md          ← リードデベロッパー
│   ├── qa-lead.md                 ← QAリード
│   ├── test-engineer.md           ← テストエンジニア
│   ├── ci-cd-engineer.md          ← CI/CDエンジニア
│   ├── cloud-engineer.md          ← クラウドエンジニア
│   ├── standards-lead.md          ← 標準化リード
│   ├── knowledge-manager.md       ← ナレッジマネージャー
│   ├── technical-writer.md        ← テクニカルライター
│   └── tech-researcher.md         ← テクニカルリサーチャー
│
├── README.md
└── LICENSE


[ユーザー環境に生成される構造]

プロジェクトルート/
├── CLAUDE.md                      ← プロジェクトレベルのCLAUDE.md（既存を尊重）
│
├── .claude/
│   ├── skills/
│   │   ├── company/               ← プラグインインストール時に配置
│   │   │   ├── SKILL.md
│   │   │   └── references/
│   │   │
│   │   └── company-admin/         ← プラグインインストール時に配置
│   │       ├── SKILL.md
│   │       └── references/
│   │
│   └── agents/                    ← プラグインインストール時に配置（初期セット）
│       ├── secretary.md           ← 常設
│       ├── project-manager.md     ← 初期同梱
│       ├── system-architect.md    ← 初期同梱
│       ├── ... (他の初期同梱Subagent)
│       └── [user-added].md        ← /company-admin で追加されたカスタムSubagent
│
├── .company/                      ← /company 実行後に生成される業務データ
│   ├── CLAUDE.md                  ← 組織ルール（サブディレクトリCLAUDE.md）
│   ├── masters/                   ← マスタデータ（/company-admin で管理）
│   │   ├── organization.md
│   │   ├── departments.md
│   │   ├── roles.md
│   │   ├── workflows.md
│   │   ├── projects.md
│   │   └── mcp-services.md
│   ├── secretary/
│   │   ├── CLAUDE.md              ← 秘書室ルール（遅延ロード）
│   │   ├── inbox/
│   │   ├── todos/
│   │   └── notes/
│   ├── pm/                        ← 動的追加（/company-admin or /company）
│   │   └── CLAUDE.md
│   ├── architecture/              ← 動的追加
│   │   └── CLAUDE.md
│   ├── [user-added-dept]/         ← /company-admin で追加されたカスタム部署
│   │   └── CLAUDE.md
│   └── ...
│
└── settings.json (参考)
    ← Agent Teams有効化:
       {"env":{"CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS":"1"}}
```

### 2.3 各Claude Code機能の役割分担の原則

| 判断基準 | 使用する機能 | 理由 |
|---------|-------------|------|
| **常にロードされるべき指示** | CLAUDE.md | セッション開始時に自動読み込み。組織ルール、ファイル命名規則等 |
| **特定コマンドで起動する業務ロジック** | Skill（SKILL.md） | `/company` で起動。マスタ参照→判定→実行の一連のロジック |
| **マスタの追加・更新・削除** | Skill（SKILL.md） | `/company-admin` で起動。対話的CRUDと連鎖更新を実行 |
| **専門領域の深い知識・スクリプト** | Skill の `references/` | Skill発動時にのみロード。コンテキスト節約 |
| **独立コンテキストで専門作業を実行** | Subagent（`.claude/agents/`） | 独自のシステムプロンプト・ツール制限・メモリを持つ |
| **複数エージェントの並列・協調作業** | Agent Teams | 共有タスクリスト＋メールボックスで自律連携 |
| **永続的な業務データ** | `.company/` 配下のmdファイル | TODO、メモ、プロジェクト情報、ナレッジ等 |

---

## 3. Skill 設計

### 3.1 メインSkill: `/company`

**配置先**: `.claude/skills/company/SKILL.md`

```yaml
---
name: company
description: >
  SIer業務の仮想組織スキル。/company で秘書に話しかける。
  マスタ駆動で部署・ロールを動的に編成。Agent Teamsで並列作業を実行。
  「秘書」「TODO」「管理」「壁打ち」「相談」「組織」と言われたとき、
  または /company を実行したときに使用する。
---
```

SKILL.md本文には以下のワークフローロジックを記載する（プログレッシブ・ディスクロージャに従い、詳細は`references/`に外出し）:

1. **検出とモード判定**
2. **オンボーディング**（初回のみ）
3. **運営モード**（マスタ参照→Subagent/Agent Teams判定→実行）
4. **部署の動的追加**
5. **マスタ管理**（対話的なマスタCRUD操作）
6. **マイグレーション**（v1→v2互換）

**重要設計原則: SKILL.mdは1,500〜2,000語に収める。**
詳細な部署テンプレート、ワークフロー定義、エージェントテンプレートは`references/`配下に配置し、必要時のみ参照する。

### 3.2 マスタ管理Skill: `/company-admin`

**配置先**: `.claude/skills/company-admin/SKILL.md`

マスタの追加・更新・削除を対話的に行うための専用Skill。

```yaml
---
name: company-admin
description: >
  仮想組織のマスタデータを管理するスキル。
  部署の追加・変更・削除、ロール（エージェント）の追加・変更・削除、
  ワークフローの追加・変更、プロジェクトの追加・更新を行う。
  「部署を追加」「ロールを追加」「エージェントを追加」「組織を変更」
  「ワークフローを追加」「マスタ管理」と言われたときに使用する。
---
```

SKILL.md本文の構成:

1. **操作対象の判定** — ユーザーの依頼から対象マスタ（部署/ロール/ワークフロー/プロジェクト/組織）を特定
2. **現在の状態確認** — 該当マスタファイルを読み込み、現状を把握
3. **対話的ヒアリング** — 必要な項目をユーザーにヒアリング（スキーマに基づく）
4. **バリデーション** — `references/master-schemas.md` のスキーマに照合して入力を検証
5. **マスタ更新の実行** — 対象のmdファイルを更新
6. **連鎖更新の実行** — 関連するSubagent・CLAUDE.md・フォルダ構成を自動更新
7. **結果の確認** — 変更内容のサマリーをユーザーに提示

### 3.3 Skill の references/ 構成

```
.claude/skills/company/
├── SKILL.md                          ← コアロジック（1,500〜2,000語）
└── references/
    ├── departments.md                 ← 部署テンプレート集（フォルダ構成・CLAUDE.md雛形）
    ├── claude-md-template.md          ← .company/CLAUDE.md 生成テンプレート
    ├── workflow-definitions.md        ← ワークフロー定義集
    ├── agent-templates.md             ← Subagent動的生成テンプレート
    ├── sier-templates.md              ← SIer業務特化テンプレート（ADR, ポストモーテム等）
    └── master-schemas.md              ← マスタスキーマ定義・バリデーションルール（★追加）

.claude/skills/company-admin/
├── SKILL.md                          ← マスタ管理ロジック（★追加）
└── references/
    └── master-schemas.md              ← 共有（company/ と同一内容、またはシンボリック参照）
```

各referenceファイルの役割:

| ファイル | 参照タイミング | 内容 |
|---------|-------------|------|
| `departments.md` | 部署追加時 | 各部署のフォルダ構成、CLAUDE.md雛形、テンプレートファイル群 |
| `claude-md-template.md` | オンボーディング時 | `.company/CLAUDE.md` の生成テンプレート（変数置換） |
| `workflow-definitions.md` | 作業依頼受付時 | 定義済みワークフロー（必要ロール、ステップ、成果物パス） |
| `agent-templates.md` | Subagent/Agent Teams編成時 | 各ロールのテイメイト指示テンプレート |
| `sier-templates.md` | 各種ドキュメント生成時 | ADR、ポストモーテム、テスト戦略等のテンプレート |
| `master-schemas.md` | マスタCRUD操作時 | 各マスタの必須フィールド、型、バリデーションルール、連鎖更新ルール |

---

## 4. Subagent 設計

### 4.1 Subagentの配置と構造

**配置先**: `.claude/agents/[name].md`

公式ドキュメントに従い、各Subagentは以下のYAMLフロントマターとマークダウン本文で構成する。

```markdown
---
name: [agent-name]
description: [いつ起動されるべきかの説明]
tools: [許可するツール一覧]
model: [sonnet | opus | haiku]
memory: [user | project | local]  # 永続メモリのスコープ
---

[システムプロンプト（ペルソナ定義＋責務＋ルール）]
```

### 4.2 Subagent 一覧と定義

#### secretary.md — 秘書エージェント

```markdown
---
name: secretary
description: >
  仮想組織の秘書。TODO管理、壁打ち、メモ、作業振り分けを担当。
  「TODO」「今日やること」「壁打ち」「メモ」「ダッシュボード」と言われたとき、
  または /company 経由で作業が振り分けられたときに使用する。
tools: Read, Write, Edit, Glob, Grep, Bash
model: opus
memory: project
---

# 秘書エージェント

## 役割
オーナーの常駐窓口。全作業依頼の初回受付を担当する。

## ペルソナ
- 丁寧だが堅すぎない。「〜ですね！」「承知しました」「いいですね！」
- 主体的に提案する。「ついでにこれもやっておきましょうか？」
- 過去のメモや決定事項を参照して文脈を持った対話をする

## 起動時の動作
1. `.company/masters/` 配下のマスタファイルを確認
2. `.company/CLAUDE.md` を読み込み組織状態を把握
3. `secretary/todos/` で今日のTODO状況を確認
4. オーナーの依頼に応じて対応

## マスタ参照による作業振り分け
1. `masters/departments.md` のトリガーワードと依頼内容を照合
2. `masters/roles.md` で必要なロール（Subagent）を特定
3. `masters/workflows.md` で定義済みワークフローを確認
4. 作業規模に応じて実行モードを判定:
   - 小規模 → 自身で直接対応
   - 中規模 → 該当Subagentを名前指定で呼び出し
   - 大規模・並列 → Agent Teams編成を提案

## ファイル操作ルール
- TODOは `secretary/todos/YYYY-MM-DD.md` に記録
- メモは `secretary/inbox/YYYY-MM-DD.md` に記録
- 壁打ちは `secretary/notes/` に保存
- 同日ファイルが存在する場合は追記。新規作成しない
- ファイル操作前に必ず今日の日付を確認

## メモリ活用
エージェントメモリに以下を蓄積すること:
- オーナーの好みや頻出パターン
- 過去の意思決定の傾向
- 各部署の利用頻度
```

#### project-manager.md — PMエージェント

```markdown
---
name: project-manager
description: >
  プロジェクト管理の専門エージェント。WBS作成、マイルストーン管理、
  進捗レポート、リスク管理を担当。
  「プロジェクト」「WBS」「マイルストーン」「進捗」「チケット」と
  言われたとき、または秘書から委譲されたときに使用する。
tools: Read, Write, Edit, Glob, Grep
model: sonnet
memory: project
---

# プロジェクトマネージャー

## ペルソナ
冷静で俯瞰的。リスクに敏感。ステークホルダー視点を常に持つ。

## 責務
- WBS作成・更新
- マイルストーン管理
- 進捗レポート作成
- リスク・課題管理
- 工数見積もり

## 成果物の保存先
- プロジェクト定義: `.company/pm/projects/{project-id}/`
- チケット: `.company/pm/tickets/`
- 進捗レポート: `.company/pm/reports/`

## ステータス管理
- プロジェクト: planning → in-progress → review → completed → archived
- チケット: open → in-progress → done

## メモリ活用
プロジェクトの進捗パターン、見積もり精度の振り返り、
頻出リスクパターンをエージェントメモリに蓄積すること。
```

#### system-architect.md — システムアーキテクトエージェント

```markdown
---
name: system-architect
description: >
  システムアーキテクチャ設計の専門エージェント。全体設計、技術選定、
  非機能要件定義、ADR作成、設計レビューを担当。
  「設計」「アーキテクチャ」「非機能」「技術選定」「ADR」と
  言われたとき、または秘書から委譲されたときに使用する。
tools: Read, Write, Edit, Glob, Grep, Bash
model: opus
memory: project
---

# システムアーキテクト

## ペルソナ
全体最適を重視。トレードオフの明示を怠らない。ASCII図を多用する。

## 責務
- システム全体設計
- 技術選定と根拠の文書化
- 非機能要件定義（性能、可用性、セキュリティ）
- ADR（Architecture Decision Record）作成
- 設計レビュー

## 成果物の保存先
- 設計書: `.company/architecture/designs/{design-id}/`
- ADR: `.company/architecture/adrs/ADR-{number}.md`
- レビュー結果: `.company/architecture/reviews/{review-id}.md`

## ADR作成時のルール
必ず以下の構成で記録すること:
1. コンテキスト（なぜ判断が必要か）
2. 検討した選択肢（比較表付き）
3. 決定事項
4. トレードオフと結果

## メモリ活用
過去のADR、技術選定の結果、アーキテクチャパターンの適用実績を
エージェントメモリに蓄積すること。
```

#### data-architect.md — データアーキテクトエージェント

```markdown
---
name: data-architect
description: >
  データアーキテクチャ設計の専門エージェント。データモデル設計、
  DWH/データレイク設計、メダリオンアーキテクチャ、データ品質を担当。
  「データモデル」「DWH」「データレイク」「メダリオン」「dbt」「ETL」
  と言われたとき、または秘書から委譲されたときに使用する。
tools: Read, Write, Edit, Glob, Grep, Bash
model: opus
memory: project
---

# データアーキテクト

## ペルソナ
データの一貫性と品質を最優先。メダリオンアーキテクチャ等のパターンに精通。

## 責務
- データモデル設計（概念・論理・物理）
- DWH/データレイクアーキテクチャ設計
- メダリオンアーキテクチャ（Bronze/Silver/Gold）の設計
- データリネージ管理
- データ品質ルール定義

## 成果物の保存先
- データモデル: `.company/data/models/{model-id}/`
- パイプライン設計: `.company/data/pipelines/{pipeline-id}/`
- データカタログ: `.company/data/catalogs/`

## メモリ活用
データモデルパターン、パイプライン設計の知見、
データ品質問題の対処履歴をエージェントメモリに蓄積すること。
```

#### qa-lead.md — QAリードエージェント

```markdown
---
name: qa-lead
description: >
  品質管理の専門エージェント。テスト戦略策定、テスト計画書作成、
  品質メトリクス管理を担当。
  「テスト戦略」「テスト計画」「品質」「QA」と言われたとき、
  または秘書から委譲されたときに使用する。
tools: Read, Write, Edit, Glob, Grep
model: sonnet
memory: project
---

# QAリード

## ペルソナ
テスト戦略を俯瞰的に設計。リスクベースドテストの考え方を持つ。

## 責務
- テスト戦略策定
- テスト計画書作成
- 品質メトリクス定義・追跡
- テスト結果分析

## 成果物の保存先
- テスト戦略: `.company/quality/strategies/{project-id}/`
- テスト計画: `.company/quality/test-plans/{project-id}/`
- メトリクス: `.company/quality/metrics/`

## メモリ活用
テスト戦略のパターン、バグ傾向、品質メトリクスの推移を
エージェントメモリに蓄積すること。
```

#### その他のSubagent（概要）

以下のSubagentも同様のフォーマットで `.claude/agents/` に配置する:

| ファイル名 | ロール名 | model | 主な責務 | 成果物の保存先 |
|-----------|---------|-------|---------|--------------|
| `lead-developer.md` | リードデベロッパー | sonnet | コードレビュー、技術方針、実装ガイドライン | `.company/development/` |
| `backend-developer.md` | バックエンドデベロッパー | sonnet | API設計・実装、DB設計 | `.company/development/` |
| `frontend-developer.md` | フロントエンドデベロッパー | sonnet | UI実装、UX改善 | `.company/development/` |
| `ai-developer.md` | AI駆動開発エンジニア | opus | プロンプト設計、RAGパイプライン | `.company/development/` |
| `test-engineer.md` | テストエンジニア | sonnet | テスト自動化、テストケース設計 | `.company/quality/` |
| `ci-cd-engineer.md` | CI/CDエンジニア | sonnet | パイプライン設計・構築 | `.company/quality/cicd/` |
| `cloud-engineer.md` | クラウドエンジニア | sonnet | IaC実装、セキュリティ設計 | `.company/infra/` |
| `sre-engineer.md` | SREエンジニア | sonnet | 監視設計、SLI/SLO、ポストモーテム | `.company/infra/` |
| `standards-lead.md` | 標準化リード | sonnet | 開発標準、規約管理 | `.company/standardization/` |
| `process-engineer.md` | プロセスエンジニア | sonnet | ワークフロー最適化 | `.company/standardization/` |
| `knowledge-manager.md` | ナレッジマネージャー | sonnet | ナレッジ蓄積、ポストモーテム管理 | `.company/knowledge-base/` |
| `technical-writer.md` | テクニカルライター | sonnet | 技術文書、教育資料 | `.company/knowledge-base/` |
| `tech-researcher.md` | テクニカルリサーチャー | sonnet | 技術調査、PoC | `.company/research/` |

### 4.3 Subagent のモデル選定基準

公式ドキュメントに基づき、タスクの性質でモデルを使い分ける:

| モデル | 用途 | 対象Subagent |
|--------|------|-------------|
| **opus** | 複雑な分析・設計判断・創造的タスク | secretary, system-architect, data-architect, ai-developer |
| **sonnet** | 標準的な実装・レビュー・文書作成 | その他の全Subagent |
| **haiku** | 軽量な定型処理（将来拡張） | （Phase 2以降で検討） |

### 4.4 Subagent のメモリ設計

公式ドキュメントの `memory` フィールドを活用し、Subagentが会話を超えて学習する:

| メモリスコープ | 用途 | 対象 |
|-------------|------|------|
| **project** | プロジェクト固有の知見（コードパターン、設計判断等） | ほぼ全Subagent |
| **user** | ユーザー個人の好み・スタイル（プロジェクト横断） | secretary |
| **local** | （将来検討） | — |

メモリディレクトリには `MEMORY.md`（先頭200行がシステムプロンプトに含まれる）と、追加の知見ファイルが蓄積される。各Subagentのシステムプロンプトには、メモリの読み書き指示を含める。

---

## 5. CLAUDE.md 設計

### 5.1 CLAUDE.md の階層構造

Claude Codeは複数階層の CLAUDE.md を認識する。本プラグインでは以下のように活用する:

```
プロジェクトルート/
├── CLAUDE.md                ← [既存] ユーザーのプロジェクト固有ルール（変更しない）
│
└── .company/
    ├── CLAUDE.md            ← [生成] 組織ルール・運営ポリシー
    │                          （.company/ 配下のファイル操作時に遅延ロード）
    ├── secretary/
    │   └── CLAUDE.md        ← [生成] 秘書室の振る舞いルール
    ├── pm/
    │   └── CLAUDE.md        ← [動的生成] PM室のルール
    ├── architecture/
    │   └── CLAUDE.md        ← [動的生成] アーキテクチャ室のルール
    ├── development/
    │   └── CLAUDE.md        ← [動的生成] 開発室のルール
    ├── quality/
    │   └── CLAUDE.md        ← [動的生成] 品質管理室のルール
    ├── data/
    │   └── CLAUDE.md        ← [動的生成] データエンジニアリング室のルール
    ├── infra/
    │   └── CLAUDE.md        ← [動的生成] インフラ室のルール
    ├── standardization/
    │   └── CLAUDE.md        ← [動的生成] 標準化推進室のルール
    ├── knowledge-base/
    │   └── CLAUDE.md        ← [動的生成] ナレッジ管理室のルール
    └── research/
        └── CLAUDE.md        ← [動的生成] リサーチ室のルール
```

**原則**: プロジェクトルートの `CLAUDE.md` は本プラグインでは**一切変更しない**。組織固有のルールは `.company/CLAUDE.md` 以下で完結させる。

### 5.2 .company/CLAUDE.md の内容

`references/claude-md-template.md` から生成。サブディレクトリの CLAUDE.md として、Claude が `.company/` 配下のファイルにアクセスした際に遅延ロードされる。

含める内容:
- オーナープロフィール（事業・目標）
- 組織構成ツリー（現在アクティブな部署）
- 部署一覧テーブル
- 運営ルール（ファイル命名、同日1ファイル、追記ルール等）
- Agent Teams ポリシー
- パーソナライズメモ

### 5.3 部署CLAUDE.md のロードタイミング

公式ドキュメントに基づき、サブディレクトリの CLAUDE.md は**遅延ロード**される（そのディレクトリ内のファイルをClaudeが読む際に初めてロードされる）。

これにより:
- 使わない部署の CLAUDE.md はコンテキストを消費しない
- Subagentが特定部署のフォルダにアクセスした際に、部署ルールが自動的にロードされる
- 部署が増えてもセッション開始時のコンテキスト負荷は増えない

---

## 6. マスタデータ設計

### 6.1 マスタの配置と役割

マスタは `.company/masters/` に配置する。これはClaude Codeの標準機能ではなく、本プラグイン独自のデータ層。Skill（`/company`）がマスタを参照して動的判定を行う。

```
.company/masters/
├── organization.md    ← 組織全体の定義
├── departments.md     ← 部署マスタ（トリガーワード、配下ロール、Agent Teams適性）
├── roles.md           ← ロールマスタ（Subagentとの対応関係）
├── workflows.md       ← ワークフローマスタ（実行モード、必要ロール、ステップ）
├── projects.md        ← プロジェクトマスタ（アクティブ案件）
└── mcp-services.md    ← MCP連携サービスマスタ
```

### 6.2 departments.md スキーマ（Subagent対応追記）

```markdown
# 部署マスタ

## dept-secretary

- **名称**: 秘書室
- **ステータス**: active
- **役割**: オーナーの窓口。TODO管理、壁打ち、メモ、作業振り分け
- **フォルダ**: .company/secretary/
- **対応Subagent**: [secretary]  ← .claude/agents/secretary.md
- **トリガーワード**: [TODO, タスク, 壁打ち, 相談, メモ, ダッシュボード]

## dept-pm

- **名称**: プロジェクト管理室
- **ステータス**: standby
- **役割**: 受託案件のプロジェクト管理
- **フォルダ**: .company/pm/
- **対応Subagent**: [project-manager, scrum-master]  ← .claude/agents/*.md
- **トリガーワード**: [プロジェクト, 案件, WBS, マイルストーン, 進捗, チケット]
- **Agent Teams適性**: high

## dept-architecture

- **名称**: アーキテクチャ室
- **ステータス**: standby
- **役割**: システム設計、技術選定、ADR
- **フォルダ**: .company/architecture/
- **対応Subagent**: [system-architect, solution-architect, data-architect]
- **トリガーワード**: [設計, アーキテクチャ, 非機能, 技術選定, ADR, 構成図]
- **Agent Teams適性**: high

## dept-development

- **名称**: 開発室
- **ステータス**: standby
- **役割**: 実装、コードレビュー、AI駆動開発
- **フォルダ**: .company/development/
- **対応Subagent**: [lead-developer, backend-developer, frontend-developer, ai-developer]
- **トリガーワード**: [実装, コーディング, コードレビュー, リファクタリング, 開発]
- **Agent Teams適性**: high

## dept-quality

- **名称**: 品質管理室
- **ステータス**: standby
- **役割**: テスト戦略、テスト自動化、CI/CD
- **フォルダ**: .company/quality/
- **対応Subagent**: [qa-lead, test-engineer, ci-cd-engineer]
- **トリガーワード**: [テスト, 品質, QA, CI/CD, パイプライン, 自動化]
- **Agent Teams適性**: medium

## dept-data

- **名称**: データエンジニアリング室
- **ステータス**: standby
- **役割**: データアーキテクチャ、DWH、ETL/ELT
- **フォルダ**: .company/data/
- **対応Subagent**: [data-architect, data-engineer, analytics-engineer]
- **トリガーワード**: [データ, DWH, データレイク, ETL, dbt, メダリオン, Snowflake]
- **Agent Teams適性**: medium

## dept-infra

- **名称**: インフラ・IaC室
- **ステータス**: standby
- **役割**: クラウドインフラ、IaC、運用設計
- **フォルダ**: .company/infra/
- **対応Subagent**: [cloud-engineer, sre-engineer]
- **トリガーワード**: [インフラ, IaC, Terraform, AWS, Azure, 運用, 監視, SRE]
- **Agent Teams適性**: medium

## dept-standardization

- **名称**: 標準化推進室
- **ステータス**: standby
- **役割**: 開発標準、規約、テンプレート整備
- **フォルダ**: .company/standardization/
- **対応Subagent**: [standards-lead, process-engineer]
- **トリガーワード**: [標準化, 規約, テンプレート, ガイドライン, プロセス]
- **Agent Teams適性**: low

## dept-knowledge

- **名称**: ナレッジ管理室
- **ステータス**: standby
- **役割**: ポストモーテム、ナレッジ蓄積、教育資料
- **フォルダ**: .company/knowledge-base/
- **対応Subagent**: [knowledge-manager, technical-writer]
- **トリガーワード**: [ナレッジ, ポストモーテム, 振り返り, 教育, 研修, ドキュメント]
- **Agent Teams適性**: medium

## dept-research

- **名称**: リサーチ室
- **ステータス**: standby
- **役割**: 技術調査、競合分析、PoC
- **フォルダ**: .company/research/
- **対応Subagent**: [tech-researcher]
- **トリガーワード**: [調査, リサーチ, PoC, 検証, トレンド, 比較]
- **Agent Teams適性**: high
```

### 6.3 roles.md スキーマ（Subagentとの明示的対応）

```markdown
# ロールマスタ

<!-- 各ロールは .claude/agents/ 配下のSubagentファイルに1:1対応する -->

## secretary

- **Subagentファイル**: .claude/agents/secretary.md
- **所属部署**: dept-secretary
- **model**: opus
- **Agent Teams時の役割**: team-lead

## project-manager

- **Subagentファイル**: .claude/agents/project-manager.md
- **所属部署**: dept-pm
- **model**: sonnet
- **Agent Teams時の役割**: teammate
- **テイメイト指示テンプレート**: |
    あなたはプロジェクトマネージャーです。
    担当プロジェクト: {project_name}
    スコープ: WBS管理、進捗追跡、リスク識別
    成果物の保存先: .company/pm/projects/{project_id}/
    他テイメイトとの連携:
    - アーキテクトからの技術リスクを受け取り統合する
    - QAからのテスト進捗を受け取り統合する

## system-architect

- **Subagentファイル**: .claude/agents/system-architect.md
- **所属部署**: dept-architecture
- **model**: opus
- **Agent Teams時の役割**: teammate
- **テイメイト指示テンプレート**: |
    あなたはシステムアーキテクトです。
    対象: {target_system}
    スコープ: 全体設計、非機能要件、技術選定
    成果物の保存先: .company/architecture/designs/{design_id}/
    ADRフォーマットに従って意思決定を記録すること

<!-- 以下、他のロールも同様にSubagentファイルとの対応を明記 -->
```

### 6.4 workflows.md スキーマ（実行方式の明確化）

```markdown
# ワークフローマスタ

## wf-design-review

- **名称**: 設計レビュー
- **トリガー**: 「設計レビュー」「アーキテクチャレビュー」
- **実行方式**: agent-teams
- **チーム構成**:
  - team-lead: secretary（秘書がコーディネート）
  - teammate: system-architect（セキュリティ・性能観点）
  - teammate: lead-developer（実装可能性観点）
  - teammate: qa-lead（テスタビリティ観点）
- **各テイメイトの指示ソース**: roles.md のテイメイト指示テンプレート
- **ステップ**:
  1. 各テイメイトが独立してレビュー実施
  2. メールボックスで指摘事項を相互共有
  3. チームリード（秘書）が統合レビューレポートを作成
- **成果物**:
  - `.company/architecture/reviews/{review-id}.md`

## wf-project-kickoff

- **名称**: 受託案件キックオフ
- **トリガー**: 「新しい案件」「プロジェクト立ち上げ」「キックオフ」
- **実行方式**: agent-teams
- **チーム構成**:
  - team-lead: secretary
  - teammate: project-manager
  - teammate: system-architect
  - teammate: qa-lead
- **ステップ**:
  1. PM がプロジェクト定義書を作成
  2. SA が技術スコープ・制約を整理
  3. QA がテスト戦略概要を作成
  4. 全員が合流して統合レビュー
- **成果物**:
  - `.company/pm/projects/{project-id}/project-definition.md`
  - `.company/architecture/designs/{project-id}/scope.md`
  - `.company/quality/strategies/{project-id}/overview.md`

## wf-dwh-design

- **名称**: DWH/データレイク設計
- **トリガー**: 「DWH設計」「データレイク」「メダリオン」
- **実行方式**: agent-teams
- **チーム構成**:
  - team-lead: secretary
  - teammate: data-architect（全体設計）
  - teammate: data-engineer（パイプライン設計）
  - teammate: analytics-engineer（消費レイヤー設計）
- **成果物**:
  - `.company/data/models/{model-id}/architecture.md`
  - `.company/data/models/{model-id}/pipeline-design.md`
  - `.company/data/models/{model-id}/semantic-layer.md`

## wf-code-review

- **名称**: コードレビュー
- **トリガー**: 「コードレビュー」「PRレビュー」
- **実行方式**: agent-teams
- **チーム構成**:
  - team-lead: secretary
  - teammate: lead-developer（コード品質・設計）
  - teammate: test-engineer（テストカバレッジ）
  - teammate: standards-lead（規約準拠）
- **成果物**:
  - `.company/development/reviews/{review-id}.md`

## wf-test-strategy

- **名称**: テスト戦略策定
- **トリガー**: 「テスト戦略」「テスト計画」
- **実行方式**: subagent（qa-leadを名前指定で呼び出し）
- **ステップ**:
  1. 「qa-leadエージェントを使って、このプロジェクトのテスト戦略を策定して」
  2. qa-lead がプロジェクト情報・設計書を参照
  3. テスト戦略書をドラフト
- **成果物**:
  - `.company/quality/strategies/{project-id}/test-strategy.md`

## wf-postmortem

- **名称**: ポストモーテム
- **トリガー**: 「ポストモーテム」「振り返り」
- **実行方式**: subagent（knowledge-managerを名前指定で呼び出し）
- **成果物**:
  - `.company/knowledge-base/postmortems/{id}.md`

## wf-tech-research

- **名称**: 技術調査
- **トリガー**: 「調べて」「比較して」「調査」
- **実行方式**: 
  - 単一技術 → subagent（tech-researcher）
  - 複数技術並列比較 → agent-teams（tech-researcher を複数テイメイトで）
- **成果物**:
  - `.company/research/topics/{topic-id}.md`

## wf-standardization

- **名称**: 標準化策定
- **トリガー**: 「標準化」「規約」「ガイドライン作成」
- **実行方式**: subagent（standards-lead）
- **成果物**:
  - `.company/standardization/standards/{standard-id}.md`
  - `.company/standardization/templates/{template-id}.md`

## wf-onboarding-material

- **名称**: 新人教育資料作成
- **トリガー**: 「教育資料」「新人向け」「オンボーディング」
- **実行方式**: agent-teams
- **チーム構成**:
  - team-lead: secretary
  - teammate: technical-writer（コンテンツ作成）
  - teammate: knowledge-manager（既存ナレッジ参照）
- **成果物**:
  - `.company/knowledge-base/training/{topic-id}.md`
```

### 6.5 マスタ管理操作設計（`/company-admin` Skill）

ユーザーが対話的にマスタの追加・更新・削除を行い、変更が関連するSubagent・CLAUDE.md・フォルダ構成に自動的に波及する仕組み。

#### 6.5.1 操作一覧

| 操作 | 対象マスタ | トリガー例 | 連鎖更新 |
|------|----------|-----------|---------|
| **部署の追加** | departments.md | 「営業部を追加して」 | roles.md確認、.company/フォルダ作成、CLAUDE.md生成、.company/CLAUDE.md更新 |
| **部署の変更** | departments.md | 「開発室のトリガーワードを変えたい」 | .company/[部署]/CLAUDE.md再生成 |
| **部署の削除** | departments.md | 「リサーチ室を廃止して」 | roles.md更新、Subagent削除提案、.company/CLAUDE.md更新 |
| **ロールの追加** | roles.md | 「セキュリティエンジニアを追加して」 | .claude/agents/ にSubagentファイル生成、departments.md更新 |
| **ロールの変更** | roles.md | 「PMのモデルをopusに変えて」 | .claude/agents/ のSubagentファイル再生成 |
| **ロールの削除** | roles.md | 「スクラムマスターを外して」 | .claude/agents/ のSubagentファイル削除、departments.md更新、workflows.md確認 |
| **ワークフローの追加** | workflows.md | 「セキュリティ監査のワークフローを作って」 | 必要に応じてロール不足を検出→追加提案 |
| **ワークフローの変更** | workflows.md | 「設計レビューにセキュリティエンジニアも加えて」 | 該当ロールの存在確認 |
| **プロジェクトの追加** | projects.md | 「新しい案件を登録して」 | 関連部署のステータス確認→standbyなら追加提案 |
| **プロジェクトの更新** | projects.md | 「A案件のステータスをcompletedにして」 | — |
| **組織情報の変更** | organization.md | 「Agent Teamsのポリシーを変えたい」 | .company/CLAUDE.md再生成 |
| **MCPサービスの追加** | mcp-services.md | 「Backlog連携の定義を追加して」 | — |

#### 6.5.2 対話フロー例（部署追加）

```
ユーザー: /company-admin
秘書: マスタ管理モードです。何を行いますか？

ユーザー: セキュリティ室を追加したい

秘書: セキュリティ室を追加しますね。いくつか確認させてください。

  Q1: 役割・担当領域を教えてください。
  > 例: 脆弱性診断、セキュリティ設計レビュー、インシデント対応

ユーザー: セキュリティ設計レビュー、脆弱性診断、ISMS対応

秘書: Q2: この部署に所属させるロール（エージェント）はどうしますか？
  > 既存ロールから選択、または新規ロールを作成できます。
  > 現在の全ロール一覧: [secretary, project-manager, system-architect, ...]

ユーザー: 新しくsecurity-engineerを作りたい

秘書: security-engineer ロールを作成します。
  Q3: このロールの主な責務は？
  Q4: 使用するモデルは？（opus/sonnet/haiku、推奨: sonnet）
  Q5: Agent Teams で使う際の役割は？（teammate/team-lead）

ユーザー: (回答)

秘書: 以下の変更を行います。確認してください。

  【マスタ更新】
  1. departments.md に dept-security を追加
     - 名称: セキュリティ室
     - ステータス: active
     - 対応Subagent: [security-engineer]
     - トリガーワード: [セキュリティ, 脆弱性, ISMS, ペネトレーション]
     - Agent Teams適性: medium

  2. roles.md に security-engineer を追加
     - Subagentファイル: .claude/agents/security-engineer.md
     - 所属部署: dept-security
     - model: sonnet

  【連鎖更新】
  3. .claude/agents/security-engineer.md を新規作成
  4. .company/security/ フォルダ作成
  5. .company/security/CLAUDE.md 生成
  6. .company/CLAUDE.md の組織構成を更新

  実行してよいですか？

ユーザー: OK

秘書: 完了しました！
  - masters/departments.md ← dept-security 追加
  - masters/roles.md ← security-engineer 追加
  - .claude/agents/security-engineer.md ← 新規作成
  - .company/security/ ← フォルダ作成
  - .company/security/CLAUDE.md ← 生成
  - .company/CLAUDE.md ← 組織構成更新
```

#### 6.5.3 対話フロー例（ロール追加・既存部署への配属）

```
ユーザー: アーキテクチャ室にセキュリティアーキテクトを追加して

秘書: アーキテクチャ室（dept-architecture）にロールを追加しますね。

  現在の配下ロール: [system-architect, solution-architect, data-architect]
  追加するロール名: security-architect でよいですか？

ユーザー: はい

秘書: security-architect の詳細を教えてください。
  Q1: 主な責務は？
  Q2: ペルソナ（振る舞い・口調）の特徴は？
  Q3: モデルは？（推奨: opus — 設計判断を含むため）

ユーザー: (回答)

秘書: 以下の変更を行います。

  【マスタ更新】
  1. roles.md に security-architect を追加
  2. departments.md の dept-architecture.対応Subagent に追加

  【連鎖更新】
  3. .claude/agents/security-architect.md を新規作成

  実行してよいですか？
```

#### 6.5.4 対話フロー例（ワークフロー追加）

```
ユーザー: セキュリティ監査のワークフローを追加したい

秘書: ワークフローを作成しますね。

  Q1: ワークフロー名は？
  > 例: wf-security-audit
  
  Q2: トリガーとなる言葉は？
  > 例: 「セキュリティ監査」「脆弱性診断」
  
  Q3: 実行方式は？
  > - subagent（単一エージェントに委譲）
  > - agent-teams（複数エージェントで並列）
  
  Q4: 必要なロールは？（既存ロールから選択）
  > 利用可能: [security-engineer, system-architect, ...]
  > ※不足するロールがあれば新規作成も提案します
  
  Q5: ステップと成果物は？

ユーザー: (回答)

秘書: 以下を workflows.md に追加します。

  ## wf-security-audit
  - 名称: セキュリティ監査
  - トリガー: 「セキュリティ監査」「脆弱性診断」
  - 実行方式: agent-teams
  - チーム構成:
    - team-lead: secretary
    - teammate: security-engineer（脆弱性診断）
    - teammate: system-architect（アーキテクチャ観点）
  - 成果物:
    - .company/security/audits/{audit-id}.md

  実行してよいですか？
```

#### 6.5.5 連鎖更新ルール

マスタ変更時に自動的に更新される関連リソースのルール。`references/master-schemas.md` に定義する。

| マスタ変更 | 連鎖更新対象 | 更新内容 |
|-----------|------------|---------|
| **departments.md に部署追加** | `.company/[dept]/` | フォルダ＋サブフォルダ作成 |
| | `.company/[dept]/CLAUDE.md` | `references/departments.md` から部署CLAUDE.mdを生成 |
| | `.company/CLAUDE.md` | 組織構成ツリー・部署一覧テーブルに追記 |
| **departments.md から部署削除** | `.company/[dept]/` | 削除確認（データがある場合はアーカイブ提案） |
| | `.company/CLAUDE.md` | 組織構成から除去 |
| | `roles.md` | 該当部署所属のロールに警告表示 |
| | `workflows.md` | 該当部署のロールを使うワークフローに警告表示 |
| **roles.md にロール追加** | `.claude/agents/[name].md` | `references/agent-templates.md` からSubagentファイルを生成 |
| | `departments.md` | 所属部署の対応Subagentリストに追記 |
| **roles.md からロール削除** | `.claude/agents/[name].md` | Subagentファイル削除（確認付き） |
| | `departments.md` | 所属部署の対応Subagentリストから除去 |
| | `workflows.md` | 該当ロールを含むワークフローに警告表示＋代替提案 |
| **workflows.md にWF追加** | — | 必要ロールの存在確認。不足時は追加を提案 |
| **projects.md にPJ追加** | `departments.md` | 関連部署がstandbyの場合、active化を提案 |
| **organization.md 変更** | `.company/CLAUDE.md` | テンプレートから再生成 |

#### 6.5.6 バリデーションルール（`references/master-schemas.md` に定義）

```markdown
# マスタスキーマ定義

## departments.md エントリスキーマ

### 必須フィールド
| フィールド | 型 | バリデーション |
|-----------|-----|-------------|
| ID | string | `dept-` プレフィックス、kebab-case、一意 |
| 名称 | string | 空文字不可 |
| ステータス | enum | active / standby / archived のいずれか |
| 役割 | string | 空文字不可 |
| フォルダ | string | `.company/` プレフィックス |
| 対応Subagent | string[] | roles.md に存在するロールID |
| トリガーワード | string[] | 1つ以上 |

### オプションフィールド
| フィールド | 型 | バリデーション |
|-----------|-----|-------------|
| Agent Teams適性 | enum | high / medium / low |

### 整合性ルール
- 対応SubagentのロールIDは roles.md に存在すること
- フォルダパスは他の部署と重複しないこと
- ステータスが active の場合、フォルダが存在すること

---

## roles.md エントリスキーマ

### 必須フィールド
| フィールド | 型 | バリデーション |
|-----------|-----|-------------|
| ID | string | kebab-case、一意 |
| Subagentファイル | string | `.claude/agents/` プレフィックス、`.md` サフィックス |
| 所属部署 | string | departments.md に存在する部署ID |
| model | enum | opus / sonnet / haiku |
| Agent Teams時の役割 | enum | team-lead / teammate |

### オプションフィールド
| フィールド | 型 | バリデーション |
|-----------|-----|-------------|
| テイメイト指示テンプレート | string (multiline) | {変数} を含んでよい |

### 整合性ルール
- 所属部署のIDは departments.md に存在すること
- Subagentファイルのパスが実際に `.claude/agents/` に存在すること（作成後）
- 1つのロールは1つのSubagentファイルに対応すること

---

## workflows.md エントリスキーマ

### 必須フィールド
| フィールド | 型 | バリデーション |
|-----------|-----|-------------|
| ID | string | `wf-` プレフィックス、kebab-case、一意 |
| 名称 | string | 空文字不可 |
| トリガー | string[] | 1つ以上 |
| 実行方式 | enum | subagent / agent-teams |
| チーム構成またはロール | object | roles.md に存在するロールID |

### 整合性ルール
- 参照するロールIDがすべて roles.md に存在すること
- agent-teams の場合、team-lead が1つ指定されていること
- 成果物のパスが対応する部署のフォルダ配下であること

---

## projects.md エントリスキーマ

### 必須フィールド
| フィールド | 型 | バリデーション |
|-----------|-----|-------------|
| ID | string | `proj-` プレフィックス、一意 |
| 名称 | string | 空文字不可 |
| ステータス | enum | planning / active / review / completed / archived |

### 整合性ルール
- 関連部署のIDがすべて departments.md に存在すること
- 関連ワークフローのIDがすべて workflows.md に存在すること
```

#### 6.5.7 Subagentファイルの自動生成テンプレート

ロール追加時に `.claude/agents/[name].md` を自動生成する際のテンプレート（`references/agent-templates.md` に定義）:

```markdown
## Subagent自動生成テンプレート

---
name: {{ROLE_ID}}
description: >
  {{ROLE_DESCRIPTION}}
  {{TRIGGER_PHRASES}}
  または秘書から委譲されたときに使用する。
tools: Read, Write, Edit, Glob, Grep
model: {{MODEL}}
memory: project
---

# {{ROLE_NAME}}

## ペルソナ
{{PERSONA}}

## 責務
{{RESPONSIBILITIES}}

## 成果物の保存先
{{OUTPUT_PATHS}}

## メモリ活用
担当領域の知見、パターン、判断履歴をエージェントメモリに蓄積すること。
```

#### 6.5.8 削除時の安全策

| 対象 | 安全策 |
|------|--------|
| **部署削除** | `.company/[dept]/` 配下にファイルがある場合は削除不可。アーカイブ（`archived` ステータス）を提案 |
| **ロール削除** | workflows.md で参照されている場合は警告。代替ロールの指定を求める |
| **ワークフロー削除** | 削除のみ。他マスタへの影響なし |
| **プロジェクト削除** | `archived` ステータスへの変更を推奨。物理削除は `.company/pm/projects/` 配下が空の場合のみ |
| **全操作共通** | 実行前に変更内容のサマリーを表示し、ユーザーの明示的な承認を必ず取得する |

---

## 7. Agent Teams 統合設計

### 7.1 有効化

```json
// settings.json または環境変数
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

### 7.2 Skill → Subagent → Agent Teams の連携フロー

```
/company 実行
  │
  ▼
Skill (SKILL.md) が起動
  │
  ├─ masters/ を参照して実行方式を判定
  │
  ├─ [subagent の場合]
  │   └─ 「{agent-name}エージェントを使って〜」で名前指定呼び出し
  │      → .claude/agents/{name}.md のSubagentが独立コンテキストで起動
  │      → 結果を秘書に返却
  │      → 秘書が .company/ 配下に成果物を保存
  │
  └─ [agent-teams の場合]
      └─ チームリード（秘書）がAgent Teamsを編成:
         1. roles.md からテイメイト指示テンプレートを取得
         2. 自然言語でチーム構成を記述してClaude Codeに指示
         3. 各テイメイトが独立コンテキストで並列作業
         4. 共有タスクリストで進捗管理
         5. メールボックスで相互連携
         6. チームリードが統合→ .company/ 配下に保存
```

### 7.3 Agent Teams 編成時のプロンプト生成

Skillが `references/agent-templates.md` と `masters/roles.md` を参照して、以下のようなプロンプトを動的に生成する:

```
この設計書のレビューを行います。エージェントチームを作成してください。

チーム構成:
- テイメイト1（セキュリティ・性能レビュアー）:
  あなたはシステムアーキテクトです。セキュリティと性能の観点で
  この設計書をレビューしてください。
  指摘事項は .company/architecture/reviews/{id}/ に保存。

- テイメイト2（実装可能性レビュアー）:
  あなたはリードデベロッパーです。実装可能性と保守性の観点で
  この設計書をレビューしてください。

- テイメイト3（テスタビリティレビュアー）:
  あなたはQAリードです。テスタビリティの観点で
  この設計書をレビューしてください。

各テイメイトはレビュー完了後、発見事項を他テイメイトに共有してください。
全員のレビューが完了したら、統合レポートを作成します。
```

### 7.4 コスト管理

Agent Teamsはトークン消費が約15倍になる（公式ドキュメント参照）。`masters/organization.md` の `COST_AWARENESS` 設定で制御:

| 設定 | 動作 |
|------|------|
| **conservative** | Agent Teamsは明示指示時のみ。デフォルトはSubagent |
| **balanced**（推奨） | workflows.mdの実行方式に従う。agent-teams指定時のみ使用 |
| **aggressive** | 並列可能な場面では積極的にAgent Teams使用 |

---

## 8. SIer特化テンプレート

### 8.1 テンプレートの配置

テンプレートは2箇所に存在する:

| 配置場所 | 用途 | 参照タイミング |
|---------|------|-------------|
| `references/sier-templates.md` | Skillが参照するテンプレート集 | ドキュメント生成時 |
| `.company/[部署]/` 配下 | 実際に生成されたドキュメント | 業務遂行時 |

### 8.2 ADR テンプレート（`references/sier-templates.md` に含む）

```markdown
## ADRテンプレート

---
adr_id: "ADR-{{NUMBER}}"
created: "{{YYYY-MM-DD}}"
status: proposed  <!-- proposed/accepted/deprecated/superseded -->
deciders: []
---

# ADR-{{NUMBER}}: {{TITLE}}

## ステータス
{{STATUS}}

## コンテキスト
何が問題か？なぜ意思決定が必要か？

## 決定
何を決めたか？

## 選択肢の比較

| 観点 | 選択肢A | 選択肢B | 選択肢C |
|------|---------|---------|---------|
| メリット | | | |
| デメリット | | | |
| コスト | | | |
| リスク | | | |

## 結果
この決定によってどうなるか？トレードオフは？
```

### 8.3 ポストモーテムテンプレート

```markdown
## ポストモーテムテンプレート

---
postmortem_id: "PM-{{NUMBER}}"
created: "{{YYYY-MM-DD}}"
type: {{TYPE}}  <!-- incident/project/process -->
severity: {{SEVERITY}}  <!-- critical/major/minor -->
tags: []
---

# ポストモーテム: {{TITLE}}

## サマリー（3行以内）

## タイムライン
| 時刻 | イベント |
|------|---------|

## 根本原因（5 Whys）
1. Why:
2. Why:
3. Why:
4. Why:
5. Why:

## 影響範囲

## 対応内容

## 再発防止策
| アクション | 担当 | 期限 | ステータス |
|-----------|------|------|----------|

## 学び・教訓
```

### 8.4 テスト戦略テンプレート

```markdown
## テスト戦略テンプレート

---
created: "{{YYYY-MM-DD}}"
project: "{{PROJECT_ID}}"
status: draft
---

# テスト戦略: {{PROJECT_NAME}}

## スコープ

## テストレベル
### 単体テスト
### 結合テスト
### E2Eテスト
### 非機能テスト

## テスト自動化方針

## リスクベース優先順位
| リスク | 影響度 | 発生確率 | テスト優先度 |
|--------|--------|---------|-------------|

## 品質メトリクス
| メトリクス | 目標値 |
|-----------|--------|
```

### 8.5 DWH設計テンプレート

```markdown
## DWH設計テンプレート

---
created: "{{YYYY-MM-DD}}"
project: "{{PROJECT_ID}}"
platform: {{PLATFORM}}
status: draft
---

# データアーキテクチャ設計: {{PROJECT_NAME}}

## メダリオンアーキテクチャ

### Bronze（Raw Layer）
| ソース | 形式 | 取得方法 | 頻度 |
|--------|------|---------|------|

### Silver（Cleaned Layer）

### Gold（Business Layer）

## データフロー図

## データリネージ

## 非機能要件
```

---

## 9. ナレッジ管理設計

### 9.1 配置

```
.company/knowledge-base/
├── CLAUDE.md             ← ナレッジ室のルール（遅延ロード）
├── postmortems/          ← ポストモーテム
├── training/             ← 教育資料
├── tech-notes/           ← 技術メモ
└── index.md              ← 横断検索インデックス
```

### 9.2 自動蓄積ルール

knowledge-manager Subagentのメモリに蓄積パターンを学習させつつ、秘書が以下のタイミングでナレッジ登録を提案:

| タイミング | 登録先 |
|-----------|--------|
| 技術的な意思決定後 | tech-notes/ or ADR |
| インシデント対応後 | postmortems/ |
| 教育資料作成後 | training/ |
| 技術調査完了後 | tech-notes/ |

---

## 10. MCP連携インターフェース定義

（実装は後回し。`masters/mcp-services.md` でインターフェースのみ定義）

| サービス | 連携部署 | 想定操作 |
|---------|---------|---------|
| Backlog | dept-pm, dept-development | チケットCRUD、Wiki参照 |
| GitHub | dept-development, dept-quality | Issue/PR管理、コード検索 |
| Notion | dept-knowledge, dept-standardization | ページCRUD、DB検索 |
| Google Calendar | dept-secretary, dept-pm | 予定参照・作成 |
| Slack | dept-secretary, dept-pm | メッセージ送信・検索 |

---

## 11. 実装ロードマップ

### Phase 1: コア機能（MVP）

| 成果物 | Claude Code機能 | 配置先 |
|--------|---------------|-------|
| メインSkill | Skill | `.claude/skills/company/SKILL.md` |
| マスタ管理Skill | Skill | `.claude/skills/company-admin/SKILL.md` |
| referencesファイル群（master-schemas.md含む） | Skill references | `.claude/skills/company/references/` |
| 秘書Subagent | Subagent | `.claude/agents/secretary.md` |
| マスタファイル群 | 業務データ | `.company/masters/` |
| 秘書室 | 業務データ + CLAUDE.md | `.company/secretary/` |
| 部署追加ロジック | Skill内ロジック | SKILL.md + references/ |
| マスタCRUD＋連鎖更新ロジック | Skill内ロジック | company-admin/SKILL.md + references/master-schemas.md |

### Phase 2: Subagent群 + Agent Teams

| 成果物 | Claude Code機能 | 配置先 |
|--------|---------------|-------|
| 全Subagent（13種） | Subagent | `.claude/agents/*.md` |
| Agent Teams編成ロジック | Skill + Agent Teams | SKILL.md + references/agent-templates.md |
| ワークフロー実行 | Skill + workflows.md | references/workflow-definitions.md |
| 部署CLAUDE.md群 | CLAUDE.md（遅延ロード） | `.company/[部署]/CLAUDE.md` |

### Phase 3: ナレッジ + MCP + 配布

| 成果物 | Claude Code機能 | 配置先 |
|--------|---------------|-------|
| ナレッジ管理 | Subagent + 業務データ | `.company/knowledge-base/` |
| MCP連携 | MCP Server | settings.json |
| プラグインパッケージ | Plugin | `.claude-plugin/` + `skills/` + `agents/` |

---

## 付録A: 用語集

| 用語 | 定義 |
|------|------|
| **Skill** | `.claude/skills/` に配置するSKILL.md。フロントマターの `name` がスラッシュコマンドになる。本文はClaude Codeがスキル発動時にロードする指示書 |
| **Subagent** | `.claude/agents/` に配置するmd。独立コンテキストウィンドウで動作し、指定されたツールのみ使用可能。タスク完了後に結果を親に返す |
| **Agent Teams** | 実験的機能。チームリード＋テイメイトで構成。共有タスクリスト＋メールボックスで自律連携。テイメイト間は直接通信可能 |
| **CLAUDE.md** | プロジェクトルートやサブディレクトリに配置するmd。セッション開始時（ルート）または遅延（サブディレクトリ）でロードされる永続的な指示 |
| **Plugin** | Skill + Subagent をバンドルして配布する仕組み。`.claude-plugin/` でメタデータを定義 |
| **マスタ** | `.company/masters/` 配下の業務データmd。本プラグイン独自の概念で、Skillが参照して動的判定を行う |
| **マスタ管理Skill** | `/company-admin` で起動するSkill。マスタのCRUD操作と連鎖更新を対話的に実行する |
| **連鎖更新** | マスタ変更時に、関連するSubagentファイル・CLAUDE.md・フォルダ構成を自動的に整合性を保って更新する仕組み |
| **バリデーション** | `references/master-schemas.md` に定義されたスキーマに基づき、マスタ登録・変更時に入力値の妥当性と整合性を検証する処理 |
| **テイメイト** | Agent Teams でスポーンされる個別のClaude Codeインスタンス。独立コンテキスト（最大1Mトークン） |
| **チームリード** | Agent Teams で全体を統括するセッション。テイメイトのスポーン、タスク割り当て、結果統合を担う |
| **メモリ** | Subagentの `memory` フィールド。会話を超えて知見を蓄積するディレクトリ（`MEMORY.md`） |

## 付録B: Claude Code 公式ドキュメント参照先

| 機能 | URL |
|------|-----|
| Skills | https://code.claude.com/docs/en/skills |
| Subagents | https://code.claude.com/docs/en/sub-agents |
| Agent Teams | https://code.claude.com/docs/en/agent-teams |
| CLAUDE.md | https://claude.com/blog/using-claude-md-files |
| Plugins | https://code.claude.com/docs/en/plugins |
| Agent Skills仕様 | https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview |
