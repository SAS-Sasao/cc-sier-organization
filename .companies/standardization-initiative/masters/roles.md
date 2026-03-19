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
  成果物の保存先: .companies/standardization-initiative/docs/pm/projects/{project_id}/
  ```
