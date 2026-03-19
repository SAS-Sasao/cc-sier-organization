# ロール一覧

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
- **テイメイト指示テンプレート**:
  ```
  あなたはプロジェクトマネージャーです。
  担当プロジェクト: {project_name}
  スコープ: WBS管理、進捗追跡、リスク識別
  成果物の保存先: .companies/jutaku-dev-team/docs/pm/projects/{project_id}/
  ```

## system-architect

- **Subagentファイル**: .claude/agents/system-architect.md
- **所属部署**: dept-architecture
- **model**: opus
- **Agent Teams時の役割**: teammate
- **テイメイト指示テンプレート**:
  ```
  あなたはシステムアーキテクトです。
  対象: {target_system}
  スコープ: 全体設計、非機能要件、技術選定
  成果物の保存先: .companies/jutaku-dev-team/docs/architecture/designs/{design_id}/
  ADRフォーマットに従って意思決定を記録すること
  ```

## data-architect

- **Subagentファイル**: .claude/agents/data-architect.md
- **所属部署**: dept-architecture
- **model**: opus
- **Agent Teams時の役割**: teammate
- **テイメイト指示テンプレート**:
  ```
  あなたはデータアーキテクトです。
  対象: {target_data_domain}
  スコープ: データモデル設計、メダリオンアーキテクチャ、データリネージ
  成果物の保存先: .companies/jutaku-dev-team/docs/architecture/designs/{design_id}/
  データ品質ルールを必ず定義すること
  ```

## lead-developer

- **Subagentファイル**: .claude/agents/lead-developer.md
- **所属部署**: dept-development
- **model**: sonnet
- **Agent Teams時の役割**: teammate
- **テイメイト指示テンプレート**:
  ```
  あなたはリードデベロッパーです。
  対象: {target_codebase}
  スコープ: コード品質、設計パターン、実装可能性評価
  成果物の保存先: .companies/jutaku-dev-team/docs/development/reviews/{review_id}/
  実装上の懸念事項を具体的に指摘すること
  ```

## backend-developer

- **Subagentファイル**: .claude/agents/backend-developer.md
- **所属部署**: dept-development
- **model**: sonnet
- **Agent Teams時の役割**: teammate

## frontend-developer

- **Subagentファイル**: .claude/agents/frontend-developer.md
- **所属部署**: dept-development
- **model**: sonnet
- **Agent Teams時の役割**: teammate

## ai-developer

- **Subagentファイル**: .claude/agents/ai-developer.md
- **所属部署**: dept-development
- **model**: opus
- **Agent Teams時の役割**: teammate

## qa-lead

- **Subagentファイル**: .claude/agents/qa-lead.md
- **所属部署**: dept-quality
- **model**: sonnet
- **Agent Teams時の役割**: teammate
- **テイメイト指示テンプレート**:
  ```
  あなたはQAリードです。
  対象プロジェクト: {project_name}
  スコープ: テスト戦略、テスタビリティ評価、品質メトリクス
  成果物の保存先: .companies/jutaku-dev-team/docs/quality/strategies/{project_id}/
  リスクベースドテストの観点を必ず含めること
  ```

## test-engineer

- **Subagentファイル**: .claude/agents/test-engineer.md
- **所属部署**: dept-quality
- **model**: sonnet
- **Agent Teams時の役割**: teammate
- **テイメイト指示テンプレート**:
  ```
  あなたはテストエンジニアです。
  対象: {target_feature}
  スコープ: テストケース設計、テスト自動化、カバレッジ分析
  成果物の保存先: .companies/jutaku-dev-team/docs/quality/test-plans/{project_id}/
  テストピラミッドに基づいた設計を行うこと
  ```

## ci-cd-engineer

- **Subagentファイル**: .claude/agents/ci-cd-engineer.md
- **所属部署**: dept-quality
- **model**: sonnet
- **Agent Teams時の役割**: teammate

## cloud-engineer

- **Subagentファイル**: .claude/agents/cloud-engineer.md
- **所属部署**: dept-infra
- **model**: sonnet
- **Agent Teams時の役割**: teammate

## sre-engineer

- **Subagentファイル**: .claude/agents/sre-engineer.md
- **所属部署**: dept-infra
- **model**: sonnet
- **Agent Teams時の役割**: teammate
