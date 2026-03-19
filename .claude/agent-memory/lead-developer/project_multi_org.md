---
name: マルチ組織対応の設計方針
description: cc-sierプラグインのマルチ組織対応に関するアーキテクチャ決定
type: project
---

マルチ組織対応として `.company/` 単一ディレクトリ構造から `.companies/{org-slug}/` マルチディレクトリ構造に移行した。

変更対象ファイル:
- `.claude/skills/company-admin/SKILL.md`
- `.claude/skills/company/references/master-schemas.md`
- `CLAUDE.md`（リポジトリルート）
- `.gitignore`

主要な設計決定:
- アクティブ組織は `.companies/.active` に org-slug を1行記載して管理
- org-slug は kebab-case（例: `a-sha-dwh-project`）
- 全業務成果物は `.companies/{org-slug}/` 配下に格納
- Subagent（`.claude/agents/`）のみグローバルリソースとして例外
- `.companies/` はGit管理対象（.gitignoreに含めない）
- マスタ変更時はGitワークフロー（ブランチ→更新→コミット→PR→main）を適用
- ブランチ命名: `{org-slug}/{type}/{YYYY-MM-DD}-{summary}`
- コミットメッセージ: `{type}: {概要} [{org-slug}]`

**Why:** 複数のSIer案件（クライアント別プロジェクト）を単一のClaude Code環境で並列管理するため。

**How to apply:** 今後のSkill実装・テンプレート生成では `.company/` パスを使わず `.companies/{org-slug}/` を使う。Subagentだけは `.claude/agents/` を維持する。
