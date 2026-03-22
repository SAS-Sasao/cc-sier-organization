---
name: company-dashboard
description: >
  組織の活動状況をHTMLダッシュボードとして生成する。
  「ダッシュボード」「状況を可視化」「/company-dashboard」と言われたときに使用する。
---

# ダッシュボード生成 Skill

## 1. 起動

1. `.companies/.active` から org-slug を取得
2. `bash .claude/hooks/generate-dashboard.sh {org-slug}` を実行
3. 生成されたファイルのパスと GitHub Pages 公開方法を報告する

## 2. 報告形式

```
✅ ダッシュボードを生成しました！

ファイル: .companies/{org-slug}/docs/secretary/dashboard.html
サイズ: {N} KB

GitHub Pages で公開する場合:
  リポジトリ設定 → Pages → Source: main ブランチ / docs フォルダ
  トップURL:       https://{user}.github.io/{repo}/
  ダッシュボード:  https://{user}.github.io/{repo}/secretary/dashboard.html

  ※ トップURLにアクセスすると自動でダッシュボードにリダイレクトされます
  ※ docs/index.html は /company-dashboard 実行時に自動更新されます
```
