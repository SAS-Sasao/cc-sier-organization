# Git ワークフロー

ブランチ運用・コミット・PR・auto-merge の詳細ルール。CLAUDE.md 本体から @参照。

## ブランチ命名規則

```
{org-slug}/{type}/{YYYY-MM-DD}-{summary}
```

プラグイン開発など組織スコープ外の変更は `{type}/{YYYY-MM-DD}-{summary}` 形式可。

- `{type}`: `feat` / `fix` / `docs` / `refactor` / `chore` / `admin`
- `{summary}`: kebab-case で概要

例:
- `domain-tech-collection/feat/2026-04-11-daily-digest`
- `a-sha-dwh-project/admin/2026-03-19-update-roles`
- `fix/2026-04-11-diagram-cost-section`

## コミットメッセージ

Conventional Commits 準拠:

```
{type}: {概要} [{org-slug}] by {operator}
```

- `{operator}` は `git config user.name`
- 組織スコープ内作業は `[{org-slug}]` 必須、スコープ外（プラグイン開発等）は省略可

例:
- `feat: セキュリティ部門を追加 [a-sha-dwh-project] by SAS-Sasao`
- `fix: /company-diagram に コスト概算必須化 [domain-tech-collection]`
- `chore: .claude/skills/ を同期（ランタイム反映）`

## PR 運用

### ファイル生成を伴う作業（原則）

1. `main` から作業ブランチを作成
2. 成果物を `.companies/{org-slug}/docs/` または `docs/` 配下に生成
3. コミット
4. `git push` → `gh pr create`
5. PR 本文に変更サマリー・L0/L1/L2 スコア・関連 Issue を記載
6. `gh pr merge --auto --squash --delete-branch`
7. `main` に戻り pull

### main 直コミット許可

以下のみ main 直コミットを許可（PR 運用対象外）:

- ダッシュボード HTML 再生成（`/company-dashboard`）
- ダイジェスト HTML 再生成（`/company-digest-html`）
- TodoInsights HTML 再生成（`daily-insights-sync` workflow 経由、`docs/insights/index.html` + `docs/index.html`）
- Case Bank 自動報酬スコア追記（hook 経由）
- プラグインランタイム同期（`.claude/skills/` ↔ `plugins/cc-sier/skills/`）
- マージ後のタスクログ `completed` 更新（Issue/PR番号追記）

## auto-merge パターン

3層レビュー（L0/L1/L2）通過後、PR は自動マージ:

```bash
gh pr merge {N} --auto --squash --delete-branch
```

- required status checks が無い場合 `--auto` は即時発火
- マージ後、ローカル `main` は fast-forward で自動同期
- リモート削除済みブランチは `git fetch --prune` で追従

## 禁止事項

- `main` への force push（緊急時もユーザー明示承認が必要）
- `--no-verify` フック skip
- `git reset --hard` / `rm -rf` の無承認実行
- `.companies/.active` のコミット（`.gitignore` で除外済み）
- マージ前の source branch 削除

## 関連

- @.claude/rules/task-log.md — タスクログと Issue 自動作成
- @.claude/rules/review-pattern.md — L0/L1/L2 3層レビュー設計
