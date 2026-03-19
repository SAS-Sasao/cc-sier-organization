# 部署テンプレート集

このファイルは `/company` Skill が部署追加時に参照するテンプレート集です。
各部署のフォルダ構成、CLAUDE.md 雛形、初期ステータスを定義します。

---

## 部署マスタ テンプレート

### departments.md エントリの書式

```markdown
## {dept-id}

- **名称**: {部署名}
- **ステータス**: {active / standby / archived}
- **役割**: {部署の役割説明}
- **フォルダ**: .company/docs/{folder}/
- **対応Subagent**: [{role-id, ...}]
- **トリガーワード**: [{ワード1, ワード2, ...}]
- **Agent Teams適性**: {high / medium / low}
```

---

## 初期部署定義

### dept-secretary

- **名称**: 秘書室
- **ステータス**: active
- **役割**: オーナーの窓口。TODO管理、壁打ち、メモ、作業振り分け
- **フォルダ**: .company/docs/secretary/
- **対応Subagent**: [secretary]
- **トリガーワード**: [TODO, タスク, 壁打ち, 相談, メモ, ダッシュボード]

**フォルダ構成**:
```
.company/docs/secretary/
├── CLAUDE.md
├── inbox/          ← 受信メモ
├── todos/          ← TODO管理（YYYY-MM-DD.md）
└── notes/          ← 壁打ちメモ
```

**CLAUDE.md テンプレート**:
```markdown
# 秘書室

## 役割
オーナーの常駐窓口。全作業依頼の初回受付を担当する。

## ファイル操作ルール
- TODOは `todos/YYYY-MM-DD.md` に記録
- メモは `inbox/YYYY-MM-DD.md` に記録
- 壁打ちは `notes/` に保存
- 同日ファイルが存在する場合は追記。新規作成しない
- ファイル操作前に必ず今日の日付を確認

## マスタ参照
作業振り分け時は以下のマスタを参照すること:
- `masters/departments.md` — トリガーワード照合
- `masters/roles.md` — 必要ロールの特定
- `masters/workflows.md` — ワークフロー照合
```

---

### dept-pm

- **名称**: プロジェクト管理室
- **ステータス**: standby
- **役割**: 受託案件のプロジェクト管理
- **フォルダ**: .company/docs/pm/
- **対応Subagent**: [project-manager]
- **トリガーワード**: [プロジェクト, 案件, WBS, マイルストーン, 進捗, チケット]
- **Agent Teams適性**: high

**フォルダ構成**:
```
.company/docs/pm/
├── CLAUDE.md
├── projects/       ← プロジェクト定義（{project-id}/）
├── tickets/        ← チケット管理
└── reports/        ← 進捗レポート
```

**CLAUDE.md テンプレート**:
```markdown
# プロジェクト管理室

## 役割
受託案件のプロジェクト管理を担当。WBS、マイルストーン、進捗、リスクを管理する。

## ステータス管理
- プロジェクト: planning → in-progress → review → completed → archived
- チケット: open → in-progress → done

## ファイル操作ルール
- プロジェクト定義は `projects/{project-id}/project-definition.md` に配置
- チケットは `tickets/{ticket-id}.md` に配置
- 進捗レポートは `reports/{YYYY-MM-DD}-{project-id}.md` に配置
```

---

### dept-architecture

- **名称**: アーキテクチャ室
- **ステータス**: standby
- **役割**: システム設計、技術選定、ADR
- **フォルダ**: .company/docs/architecture/
- **対応Subagent**: [system-architect, data-architect]
- **トリガーワード**: [設計, アーキテクチャ, 非機能, 技術選定, ADR, 構成図]
- **Agent Teams適性**: high

**フォルダ構成**:
```
.company/docs/architecture/
├── CLAUDE.md
├── designs/        ← 設計書（{design-id}/）
├── adrs/           ← ADR（ADR-{number}.md）
└── reviews/        ← レビュー結果（{review-id}.md）
```

**CLAUDE.md テンプレート**:
```markdown
# アーキテクチャ室

## 役割
システム全体設計、技術選定、非機能要件定義、ADR作成、設計レビューを担当。

## ADR作成ルール
必ず以下の構成で記録すること:
1. コンテキスト（なぜ判断が必要か）
2. 検討した選択肢（比較表付き）
3. 決定事項
4. トレードオフと結果

## ファイル操作ルール
- 設計書は `designs/{design-id}/` に配置
- ADRは `adrs/ADR-{number}.md` に配置（番号は連番）
- レビュー結果は `reviews/{review-id}.md` に配置
```

---

### dept-development

- **名称**: 開発室
- **ステータス**: standby
- **役割**: 実装、コードレビュー、AI駆動開発
- **フォルダ**: .company/docs/development/
- **対応Subagent**: [lead-developer, backend-developer, frontend-developer, ai-developer]
- **トリガーワード**: [実装, コーディング, コードレビュー, リファクタリング, 開発]
- **Agent Teams適性**: high

**フォルダ構成**:
```
.company/docs/development/
├── CLAUDE.md
├── guidelines/     ← 開発ガイドライン
├── reviews/        ← コードレビュー結果
└── spikes/         ← 技術スパイク
```

**CLAUDE.md テンプレート**:
```markdown
# 開発室

## 役割
実装、コードレビュー、AI駆動開発を担当。

## 開発ルール
- コミットメッセージは Conventional Commits に従う
- コードレビューは必ずレビューチェックリストに基づく
- AI駆動開発ではプロンプト設計書を必ず作成する

## ファイル操作ルール
- ガイドラインは `guidelines/` に配置
- レビュー結果は `reviews/{review-id}.md` に配置
- 技術スパイクは `spikes/{spike-id}.md` に配置
```

---

### dept-quality

- **名称**: 品質管理室
- **ステータス**: standby
- **役割**: テスト戦略、テスト自動化、CI/CD
- **フォルダ**: .company/docs/quality/
- **対応Subagent**: [qa-lead, test-engineer, ci-cd-engineer]
- **トリガーワード**: [テスト, 品質, QA, CI/CD, パイプライン, 自動化]
- **Agent Teams適性**: medium

**フォルダ構成**:
```
.company/docs/quality/
├── CLAUDE.md
├── strategies/     ← テスト戦略（{project-id}/）
├── test-plans/     ← テスト計画（{project-id}/）
├── metrics/        ← 品質メトリクス
└── cicd/           ← CI/CDパイプライン設計
```

**CLAUDE.md テンプレート**:
```markdown
# 品質管理室

## 役割
テスト戦略策定、テスト自動化、CI/CDパイプライン設計を担当。

## テスト戦略の原則
- リスクベースドテストの考え方を基本とする
- テストピラミッド: 単体 > 結合 > E2E
- 非機能テスト（性能、セキュリティ）は早期から計画する

## ファイル操作ルール
- テスト戦略は `strategies/{project-id}/test-strategy.md` に配置
- テスト計画は `test-plans/{project-id}/` に配置
- メトリクスは `metrics/` に配置
- CI/CD設計は `cicd/` に配置
```

---

### dept-data

- **名称**: データエンジニアリング室
- **ステータス**: standby
- **役割**: データアーキテクチャ、DWH、ETL/ELT
- **フォルダ**: .company/docs/data/
- **対応Subagent**: [data-architect]
- **トリガーワード**: [データ, DWH, データレイク, ETL, dbt, メダリオン, Snowflake]
- **Agent Teams適性**: medium

**フォルダ構成**:
```
.company/docs/data/
├── CLAUDE.md
├── models/         ← データモデル（{model-id}/）
├── pipelines/      ← パイプライン設計（{pipeline-id}/）
└── catalogs/       ← データカタログ
```

**CLAUDE.md テンプレート**:
```markdown
# データエンジニアリング室

## 役割
データモデル設計、DWH/データレイクアーキテクチャ、パイプライン設計を担当。

## メダリオンアーキテクチャの原則
- Bronze: ソースそのまま（Raw）
- Silver: クレンジング済み（Cleaned）
- Gold: ビジネスロジック適用済み（Business）

## ファイル操作ルール
- データモデルは `models/{model-id}/` に配置
- パイプライン設計は `pipelines/{pipeline-id}/` に配置
- データカタログは `catalogs/` に配置
```

---

### dept-infra

- **名称**: インフラ・IaC室
- **ステータス**: standby
- **役割**: クラウドインフラ、IaC、運用設計
- **フォルダ**: .company/docs/infra/
- **対応Subagent**: [cloud-engineer, sre-engineer]
- **トリガーワード**: [インフラ, IaC, Terraform, AWS, Azure, 運用, 監視, SRE]
- **Agent Teams適性**: medium

**フォルダ構成**:
```
.company/docs/infra/
├── CLAUDE.md
├── designs/        ← インフラ設計
├── iac/            ← IaCコード・設計
├── monitoring/     ← 監視設計
└── runbooks/       ← 運用手順書
```

**CLAUDE.md テンプレート**:
```markdown
# インフラ・IaC室

## 役割
クラウドインフラ設計、IaC実装、運用設計、監視設計を担当。

## IaCの原則
- Infrastructure as Codeを徹底。手動変更は禁止
- 環境間の差分は変数で管理
- セキュリティ設計は最初から組み込む

## ファイル操作ルール
- インフラ設計は `designs/` に配置
- IaC関連は `iac/` に配置
- 監視設計は `monitoring/` に配置
- 運用手順書は `runbooks/` に配置
```

---

### dept-standardization

- **名称**: 標準化推進室
- **ステータス**: standby
- **役割**: 開発標準、規約、テンプレート整備
- **フォルダ**: .company/docs/standardization/
- **対応Subagent**: [standards-lead, process-engineer]
- **トリガーワード**: [標準化, 規約, テンプレート, ガイドライン, プロセス]
- **Agent Teams適性**: low

**フォルダ構成**:
```
.company/docs/standardization/
├── CLAUDE.md
├── standards/      ← 標準文書（{standard-id}.md）
├── templates/      ← テンプレート（{template-id}.md）
└── processes/      ← プロセス定義
```

**CLAUDE.md テンプレート**:
```markdown
# 標準化推進室

## 役割
開発標準の策定、規約管理、テンプレート整備を担当。

## 標準化の原則
- 標準は現場の実態に即したものにする
- 形骸化しないよう定期的に見直す
- テンプレートは最小限の記述で最大限の効果を得る設計にする

## ファイル操作ルール
- 標準文書は `standards/{standard-id}.md` に配置
- テンプレートは `templates/{template-id}.md` に配置
- プロセス定義は `processes/` に配置
```

---

### dept-knowledge

- **名称**: ナレッジ管理室
- **ステータス**: standby
- **役割**: ポストモーテム、ナレッジ蓄積、教育資料
- **フォルダ**: .company/docs/knowledge-base/
- **対応Subagent**: [knowledge-manager, technical-writer]
- **トリガーワード**: [ナレッジ, ポストモーテム, 振り返り, 教育, 研修, ドキュメント]
- **Agent Teams適性**: medium

**フォルダ構成**:
```
.company/docs/knowledge-base/
├── CLAUDE.md
├── postmortems/    ← ポストモーテム
├── training/       ← 教育資料
├── tech-notes/     ← 技術メモ
└── index.md        ← 横断検索インデックス
```

**CLAUDE.md テンプレート**:
```markdown
# ナレッジ管理室

## 役割
ポストモーテム管理、ナレッジ蓄積、教育資料作成を担当。

## ナレッジ蓄積の原則
- 技術的な意思決定後は必ず記録する
- インシデント対応後はポストモーテムを作成する
- 教育資料は実践的な内容を重視する

## ファイル操作ルール
- ポストモーテムは `postmortems/{id}.md` に配置
- 教育資料は `training/{topic-id}.md` に配置
- 技術メモは `tech-notes/{topic}.md` に配置
- index.md を更新して横断検索を維持する
```

---

### dept-research

- **名称**: リサーチ室
- **ステータス**: standby
- **役割**: 技術調査、競合分析、PoC
- **フォルダ**: .company/docs/research/
- **対応Subagent**: [tech-researcher]
- **トリガーワード**: [調査, リサーチ, PoC, 検証, トレンド, 比較]
- **Agent Teams適性**: high

**フォルダ構成**:
```
.company/docs/research/
├── CLAUDE.md
└── topics/         ← 調査レポート（{topic-id}.md）
```

**CLAUDE.md テンプレート**:
```markdown
# リサーチ室

## 役割
技術調査、競合分析、PoCの実施を担当。

## 調査レポートの原則
- 調査目的を明確にしてから着手する
- 比較表を必ず含める
- 推奨事項と根拠を明示する
- PoCの場合は再現可能な手順を記録する

## ファイル操作ルール
- 調査レポートは `topics/{topic-id}.md` に配置
```

---

## カスタム部署テンプレート

上記に無い部署を追加する場合の汎用テンプレート:

### departments.md エントリ
```markdown
## dept-{custom-id}

- **名称**: {部署名}
- **ステータス**: active
- **役割**: {役割の説明}
- **フォルダ**: .company/docs/{folder-name}/
- **対応Subagent**: [{role-id}]
- **トリガーワード**: [{ワード1, ワード2, ...}]
- **Agent Teams適性**: {high / medium / low}
```

### フォルダ構成
```
.company/docs/{folder-name}/
├── CLAUDE.md
└── (部署の責務に応じたサブフォルダ)
```

### CLAUDE.md テンプレート
```markdown
# {部署名}

## 役割
{役割の説明}

## ファイル操作ルール
{部署固有のルール}
```
