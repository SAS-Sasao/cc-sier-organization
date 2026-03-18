# ワークフロー定義集

このファイルは `/company` Skill が作業依頼受付時に参照するワークフロー定義集です。
各ワークフローの実行方式、必要ロール、ステップ、成果物パスを定義します。

---

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

---

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

---

## wf-dwh-design

- **名称**: DWH/データレイク設計
- **トリガー**: 「DWH設計」「データレイク」「メダリオン」
- **実行方式**: subagent（data-architect を名前指定で呼び出し）
- **呼び出し例**: 「data-architect エージェントを使って、DWH/データレイクの設計を行って」
- **ステップ**:
  1. データアーキテクトが全体設計（メダリオンアーキテクチャ）
  2. パイプライン設計（ETL/ELT）
  3. 消費レイヤー設計（セマンティックレイヤー）
  4. 統合レビュー
- **成果物**:
  - `.company/data/models/{model-id}/architecture.md`
  - `.company/data/models/{model-id}/pipeline-design.md`
  - `.company/data/models/{model-id}/semantic-layer.md`

---

## wf-code-review

- **名称**: コードレビュー
- **トリガー**: 「コードレビュー」「PRレビュー」
- **実行方式**: agent-teams
- **チーム構成**:
  - team-lead: secretary
  - teammate: lead-developer（コード品質・設計）
  - teammate: test-engineer（テストカバレッジ）
  - teammate: standards-lead（規約準拠）
- **ステップ**:
  1. 各テイメイトが独立してレビュー実施
  2. メールボックスで指摘事項を相互共有
  3. チームリード（秘書）が統合レビューレポートを作成
- **成果物**:
  - `.company/development/reviews/{review-id}.md`

---

## wf-test-strategy

- **名称**: テスト戦略策定
- **トリガー**: 「テスト戦略」「テスト計画」
- **実行方式**: subagent（qa-lead を名前指定で呼び出し）
- **呼び出し例**: 「qa-lead エージェントを使って、このプロジェクトのテスト戦略を策定して」
- **ステップ**:
  1. qa-lead がプロジェクト情報・設計書を参照
  2. テスト戦略書をドラフト
  3. レビュー結果を反映
- **成果物**:
  - `.company/quality/strategies/{project-id}/test-strategy.md`

---

## wf-postmortem

- **名称**: ポストモーテム
- **トリガー**: 「ポストモーテム」「振り返り」
- **実行方式**: subagent（knowledge-manager を名前指定で呼び出し）
- **呼び出し例**: 「knowledge-manager エージェントを使って、ポストモーテムを作成して」
- **ステップ**:
  1. インシデント/プロジェクトの概要をヒアリング
  2. タイムライン作成
  3. 根本原因分析（5 Whys）
  4. 再発防止策の策定
- **成果物**:
  - `.company/knowledge-base/postmortems/{id}.md`

---

## wf-tech-research

- **名称**: 技術調査
- **トリガー**: 「調べて」「比較して」「調査」
- **実行方式**:
  - 単一技術 → subagent（tech-researcher）
  - 複数技術並列比較 → agent-teams（tech-researcher を複数テイメイトで）
- **呼び出し例**:
  - 単一: 「tech-researcher エージェントを使って、{技術}を調査して」
  - 並列: 「エージェントチームで {技術A} と {技術B} を並列比較して」
- **ステップ**:
  1. 調査目的・スコープを確認
  2. 調査実施（Web検索、ドキュメント参照）
  3. 比較表作成（複数技術の場合）
  4. 推奨事項と根拠を整理
- **成果物**:
  - `.company/research/topics/{topic-id}.md`

---

## wf-standardization

- **名称**: 標準化策定
- **トリガー**: 「標準化」「規約」「ガイドライン作成」
- **実行方式**: subagent（standards-lead）
- **呼び出し例**: 「standards-lead エージェントを使って、{対象}の標準を策定して」
- **ステップ**:
  1. 対象領域のヒアリング
  2. 既存の標準・規約を確認
  3. ドラフト作成
  4. レビュー・承認
- **成果物**:
  - `.company/standardization/standards/{standard-id}.md`
  - `.company/standardization/templates/{template-id}.md`

---

## wf-onboarding-material

- **名称**: 新人教育資料作成
- **トリガー**: 「教育資料」「新人向け」「オンボーディング」
- **実行方式**: agent-teams
- **チーム構成**:
  - team-lead: secretary
  - teammate: technical-writer（コンテンツ作成）
  - teammate: knowledge-manager（既存ナレッジ参照）
- **ステップ**:
  1. 教育対象・スコープの確認
  2. knowledge-manager が既存ナレッジから関連情報を収集
  3. technical-writer がコンテンツを作成
  4. 統合レビュー
- **成果物**:
  - `.company/knowledge-base/training/{topic-id}.md`

---

## ワークフロー照合ルール

Skill が依頼を受けた際の照合手順:

1. ユーザーの依頼テキストを `workflows.md` の各ワークフローのトリガーと照合
2. 複数一致する場合は、最も具体的なトリガーを優先
3. 一致しない場合は `departments.md` のトリガーワード照合にフォールバック
4. それでも一致しない場合は秘書が汎用対応

## 新規ワークフロー追加時の注意

- `/company-admin` Skill で追加する
- 必要ロールが `roles.md` に存在することを確認
- agent-teams の場合、team-lead は1つのみ指定可能
- 成果物パスは対応する部署のフォルダ配下であること
