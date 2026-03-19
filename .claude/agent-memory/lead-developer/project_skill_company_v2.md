---
name: company Skill v2 改修内容
description: SKILL.md（マルチ組織・Git統合・組織選択UI）、claude-md-template.md（ORG_SLUG変数追加）、git-workflow.md（新規作成）の改修記録
type: project
---

2026-03-19 に以下の改修を実施した。

## 変更ファイル一覧

- `.claude/skills/company/SKILL.md`（全面改修）
- `plugins/cc-sier/skills/company/SKILL.md`（同期）
- `.claude/skills/company/references/claude-md-template.md`（改修）
- `plugins/cc-sier/skills/company/references/claude-md-template.md`（同期）
- `.claude/skills/company/references/git-workflow.md`（新規作成）
- `plugins/cc-sier/skills/company/references/git-workflow.md`（新規作成・同期）

## 主な変更内容

### SKILL.md
- セクション1.1: `.company/` → `.companies/` ベースに変更
- セクション1.3（新規）: 組織選択UI（3ケース分岐）
- セクション2: Q0（組織名・org-slug）を追加、全パスを `.companies/{org-slug}/` に変更、完了時に `.companies/.active` 書き込み
- セクション3: 全パスを `.companies/{org-slug}/` ベースに変更
- セクション3.6（新規）: Gitワークフロー概要（詳細は git-workflow.md に外出し）
- セクション4: パスを `.companies/{org-slug}/` ベースに変更
- セクション5（新規）: 組織管理（一覧表示・切り替え・マイグレーション）

### claude-md-template.md
- `{{ORG_SLUG}}` 変数を追加
- 組織構成ツリーを `.companies/{{ORG_SLUG}}/` 起点に変更
- 作業依頼の流れの「成果物保存先」を `.companies/{{ORG_SLUG}}/` に変更
- 「Gitワークフロー」セクションを新規追加

### git-workflow.md（新規）
- ファイル生成有無の判定基準
- ブランチ命名規則（type 一覧・例）
- 作業前後の Git コマンド手順
- PR 作成テンプレート（通常・Agent Teams 用）
- エラーハンドリング（push 失敗・コンフリクト）
- `.company/` → `.companies/{org-slug}/` マイグレーション手順

**Why:** マルチプロジェクト運用とGit管理を統合し、成果物のトレーサビリティを確保するため。

**How to apply:** 今後 SKILL.md を参照する際はセクション5（組織管理）と3.6（Gitワークフロー）が追加されていることを前提とする。
