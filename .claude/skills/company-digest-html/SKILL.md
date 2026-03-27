---
name: company-digest-html
description: >
  日次ダイジェストのMDファイルをHTMLに変換しGitHub Pagesで公開する。
  「ダイジェストHTML」「ダイジェストページ生成」「/company-digest-html」と言われたときに使用する。
---

# 日次ダイジェスト HTML生成 Skill

日次ダイジェスト（`wf-daily-digest`）で生成したMDファイルをHTMLに変換し、
GitHub Pages で閲覧可能な形式で公開する。

## 1. 起動

1. `.companies/.active` から org-slug を取得
2. `bash .claude/hooks/generate-daily-digest-html.sh {org-slug}` を実行
3. 生成結果をコミットし、GitHub Pages の URL を報告する

## 2. 生成内容

### 2.1 データソース

| ソース | パス |
|--------|------|
| 日次ダイジェストMD | `.companies/{org-slug}/docs/daily-digest/*.md` |

### 2.2 出力ファイル

| 出力先 | 内容 |
|--------|------|
| `docs/daily-digest/index.html` | 全ダイジェストをタブ切替で閲覧できるSPAページ |
| `docs/index.html` | トップページにダイジェストカード（緑枠）を追加 |

### 2.3 HTML機能

- **サマリーカード**: 総記事数、最新日付、ダイジェスト数、平均記事数/日
- **日付タブ**: 最新がデフォルト表示。タブクリックで過去分に切替
- **URLハッシュ連動**: `#2026-03-27` で特定日付に直リンク可能
- **キーボードナビ**: ← → キーで日付切替
- **ダークモード対応**: ダッシュボードと統一されたデザインシステム
- **MD自動変換**: テーブル、リスト、リンク、blockquote等

## 3. 実行フロー

### 3.1 スクリプト実行

```bash
bash .claude/hooks/generate-daily-digest-html.sh {org-slug}
```

### 3.2 Gitワークフロー

HTMLはGitHub Pagesで配信するため `docs/` 配下に生成する。
コミット・プッシュは以下の手順で行う:

1. `git add docs/daily-digest/ docs/index.html`
2. `git commit -m "chore: ダッシュボード更新 [company-digest-html]"`
3. `git push origin main`

**注意**: このスキルは `docs/` 配下（GitHub Pages配信用）を更新するため、
組織ディレクトリ（`.companies/`）のGitワークフロー（ブランチ＋PR）とは異なり、
mainブランチに直接コミットする。`/company-dashboard` と同じ運用方式。

## 4. 報告形式

```
ダイジェストHTMLを生成しました！

ファイル: docs/daily-digest/index.html
サイズ: {N} KB
ダイジェスト数: {N}件
総記事数: {N}件

GitHub Pages URL:
  トップ:        https://sas-sasao.github.io/cc-sier-organization/
  ダイジェスト:  https://sas-sasao.github.io/cc-sier-organization/daily-digest/
```

## 5. 利用シーン

| タイミング | 操作 |
|-----------|------|
| `wf-daily-digest` 完了後 | `/company-digest-html` でHTMLを最新化 |
| 過去ダイジェストの修正後 | `/company-digest-html` で再生成 |
| GitHub Pages の初回セットアップ時 | `/company-digest-html` で初回生成 |
