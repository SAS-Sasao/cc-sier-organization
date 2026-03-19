# 部署一覧

## dept-secretary

- **名称**: 秘書室
- **ステータス**: active
- **役割**: オーナーの窓口。TODO管理、壁打ち、メモ、作業振り分け
- **フォルダ**: .companies/jutaku-dev-team/docs/secretary/
- **対応Subagent**: [secretary]
- **トリガーワード**: [TODO, タスク, 壁打ち, 相談, メモ, ダッシュボード]

## dept-pm

- **名称**: プロジェクト管理室
- **ステータス**: active
- **役割**: 受託案件のプロジェクト管理
- **フォルダ**: .companies/jutaku-dev-team/docs/pm/
- **対応Subagent**: [project-manager]
- **トリガーワード**: [プロジェクト, 案件, WBS, マイルストーン, 進捗, チケット]
- **Agent Teams適性**: high

## dept-architecture

- **名称**: アーキテクチャ室
- **ステータス**: active
- **役割**: システム設計、技術選定、ADR
- **フォルダ**: .companies/jutaku-dev-team/docs/architecture/
- **対応Subagent**: [system-architect, data-architect]
- **トリガーワード**: [設計, アーキテクチャ, 非機能, 技術選定, ADR, 構成図]
- **Agent Teams適性**: high

## dept-development

- **名称**: 開発室
- **ステータス**: active
- **役割**: 実装、コードレビュー、AI駆動開発
- **フォルダ**: .companies/jutaku-dev-team/docs/development/
- **対応Subagent**: [lead-developer, backend-developer, frontend-developer, ai-developer]
- **トリガーワード**: [実装, コーディング, コードレビュー, リファクタリング, 開発]
- **Agent Teams適性**: high

## dept-quality

- **名称**: 品質管理室
- **ステータス**: active
- **役割**: テスト戦略、テスト自動化、CI/CD
- **フォルダ**: .companies/jutaku-dev-team/docs/quality/
- **対応Subagent**: [qa-lead, test-engineer, ci-cd-engineer]
- **トリガーワード**: [テスト, 品質, QA, CI/CD, パイプライン, 自動化]
- **Agent Teams適性**: medium

## dept-infra

- **名称**: インフラ・IaC室
- **ステータス**: active
- **役割**: クラウドインフラ、IaC、運用設計
- **フォルダ**: .companies/jutaku-dev-team/docs/infra/
- **対応Subagent**: [cloud-engineer, sre-engineer]
- **トリガーワード**: [インフラ, IaC, Terraform, AWS, Azure, 運用, 監視, SRE]
- **Agent Teams適性**: medium
