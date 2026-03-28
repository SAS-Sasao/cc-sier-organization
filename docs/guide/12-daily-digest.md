# 12 日次ダイジェスト

日次ダイジェストのMarkdownファイルをインタラクティブなHTMLに変換し、GitHub Pagesで公開します。

---

## 概要

```
wf-daily-digest ワークフローで MD 生成
  ↓
/company-digest-html 実行
  ↓
generate-daily-digest-html.sh
  ├── .companies/{org}/docs/daily-digest/*.md を読み取り
  ├── Markdownをパースし HTML に変換
  └── docs/daily-digest/index.html に出力
  ↓
main に直接コミット → GitHub Pages で公開
```

---

## 使い方

```
/company-digest-html
```

実行すると、アクティブ組織の日次ダイジェストMDファイルをすべて読み取り、1つのHTMLファイルに変換します。

### 利用シーン

| タイミング | 操作 |
|-----------|------|
| `wf-daily-digest` 完了後 | `/company-digest-html` でHTMLを最新化 |
| 過去ダイジェストの修正後 | `/company-digest-html` で再生成 |
| GitHub Pages の初回セットアップ時 | `/company-digest-html` で初回生成 |

---

## データソースと出力

### 入力

| ソース | パス |
|--------|------|
| 日次ダイジェストMD | `.companies/{org-slug}/docs/daily-digest/*.md` |

ダイジェストMDは `wf-daily-digest` ワークフロー（`/company-report` 等）で生成されます。

### 出力

| 出力先 | 内容 |
|--------|------|
| `docs/daily-digest/index.html` | 全ダイジェストをタブ切替で閲覧できるSPAページ |
| `docs/index.html` | トップページにダイジェストカード（緑枠）を追加 |

---

## HTML の機能

### サマリーカード

ページ上部に4つのサマリーカードを表示します:

- **総記事数** — 全ダイジェストの記事合計
- **最新日付** — 最も新しいダイジェストの日付
- **ダイジェスト数** — 生成済みダイジェストの件数
- **平均記事数/日** — 1ダイジェストあたりの平均記事数

### 日付タブ

- 最新日付がデフォルトで表示
- タブをクリックして過去のダイジェストに切り替え
- URLハッシュと連動（`#2026-03-27` で特定日付に直リンク可能）

### キーボードナビゲーション

- `←` キー: 前の日付に移動
- `→` キー: 次の日付に移動

### ダークモード

ダッシュボードと統一されたデザインシステムでダークモードに対応しています。

### Markdown 自動変換

テーブル、リスト、リンク、blockquote 等の Markdown 記法を自動で HTML に変換します。

---

## GitHub Pages での閲覧

```
https://{user}.github.io/{repo}/daily-digest/
```

特定の日付に直リンク:

```
https://{user}.github.io/{repo}/daily-digest/#2026-03-27
```

---

## Git ワークフロー

このスキルは `docs/` 配下（GitHub Pages配信用）を更新するため、組織ディレクトリのワークフロー（ブランチ + PR）とは異なり、**main ブランチに直接コミット** します。`/company-dashboard` と同じ運用方式です。

```bash
git add docs/daily-digest/ docs/index.html
git commit -m "chore: ダッシュボード更新 [company-digest-html]"
git push origin main
```

---

## 実行結果の報告形式

```
ダイジェストHTMLを生成しました！

ファイル: docs/daily-digest/index.html
サイズ: {N} KB
ダイジェスト数: {N}件
総記事数: {N}件

GitHub Pages URL:
  トップ:        https://{user}.github.io/{repo}/
  ダイジェスト:  https://{user}.github.io/{repo}/daily-digest/
```
