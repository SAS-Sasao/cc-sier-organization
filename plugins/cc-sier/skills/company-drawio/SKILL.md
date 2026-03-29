---
name: company-drawio
description: >
  draw.io MCP Server を使用してアプリケーション構成図・ER図・フローチャート・
  シーケンス図等の汎用ダイアグラムを生成する。
  「ER図」「フローチャート」「シーケンス図」「業務フロー」「draw.io」
  「ネットワーク図」「C4モデル」と言われたときに使用する。
  ※ AWS構成図は /company-diagram を使用すること。
---

# draw.io ダイアグラム生成 Skill

draw.io MCP Server（`@drawio/mcp`）を使い、
汎用ダイアグラムを生成して GitHub Pages に公開する。

---

## 1. 起動

1. `.companies/.active` から org-slug を取得
2. `git config user.name` で operator を取得
3. ユーザーの依頼から図の種類を判定

## 2. AWS Diagram MCP との使い分け

| 用途 | 使用Skill |
|------|----------|
| AWS構成図（AWSアイコン付き） | `/company-diagram` |
| ER図・テーブル設計 | **本Skill（/company-drawio）** |
| フローチャート・業務フロー | **本Skill** |
| シーケンス図 | **本Skill** |
| ネットワーク図（非AWS） | **本Skill** |
| C4モデル・システム概要図 | **本Skill** |
| 組織図・階層構造 | **本Skill** |

## 3. draw.io MCP ツールの使い分け

| ツール | 入力形式 | 推奨用途 |
|--------|---------|---------|
| `open_drawio_mermaid` | Mermaid記法 | フローチャート、シーケンス図、ER図、状態遷移図 |
| `open_drawio_csv` | CSV | 組織図、ネットワークトポロジ、階層構造 |
| `open_drawio_xml` | draw.io XML | 精密なレイアウトが必要な図、複雑なアーキテクチャ図 |

**選択基準**:
- シンプルなフロー・シーケンス図 → `open_drawio_mermaid`（最も簡潔）
- 階層・ツリー構造 → `open_drawio_csv`（表形式でノード定義）
- 精密な配置・スタイル制御 → `open_drawio_xml`（完全なレイアウト制御）

## 4. ダイアグラム生成フロー

### 4.1 ヒアリング（必要に応じて）

```
Q1: どんな図を作りますか？（ER図、フローチャート、シーケンス図等）
Q2: 含めたい要素は？（テーブル名、処理ステップ、アクター等）
Q3: 図の名前は？（英語kebab-case推奨）
```

### 4.2 ダイアグラム生成

1. 依頼内容から最適なツール（mermaid/csv/xml）を選択
2. ダイアグラムコンテンツを作成
3. MCP ツールを呼び出し（ブラウザでdraw.ioエディタが開く）
4. ソースコンテンツを `.drawio` ファイルとして保存

### 4.3 ファイル配置

```
docs/drawio/
├── index.html                        ← 一覧ページ（カードグリッド）
├── {filename}.html                   ← 詳細ページ（draw.ioビューア埋め込み）
├── {filename}.drawio                 ← draw.io XMLソース
└── {filename}.png                    ← エクスポート画像（任意）

.companies/{org-slug}/docs/drawio/
└── {filename}.md                     ← ソースメタデータ・Mermaid/XMLコード
```

## 5. ページ構成

### 5.1 一覧ページ（index.html）のカードテンプレート

`<div class="grid">` 内に追記する:
```html
<a href="./{filename}.html" class="card">
  <div class="card-body">
    <div class="card-icon">{アイコン}</div>
    <div class="card-title">{図タイトル}</div>
    <div class="card-meta">
      <span class="tag tag-project">{案件名}</span>
      <span class="tag tag-type">{図の種類}</span>
    </div>
    <div class="card-desc">{1行の説明}</div>
    <div class="card-date">{YYYY-MM-DD}</div>
  </div>
</a>
```

件数表示（`<p class="count">` 内の右側の数字のみ）も更新する。
左側の数字（`<span id="match-count">`）はJSが自動制御するため変更不要。

**注意**: 一覧ページには検索・フィルタ・ページネーション機能が実装済み。
カード追加時にこの範囲を編集・削除しないこと。カードは `<div class="grid">` 内にのみ追記する。

### 5.2 詳細ページ（{filename}.html）の構成

**以下のセクションは必須**:

1. **draw.ioビューア** — iframe でdraw.io Viewerを埋め込み、インライン表示
2. **概要** — 図の目的・対象システム・スコープ
3. **構成要素** — テーブル形式（要素名 / 種類 / 説明）
4. **設計のポイント** — 設計判断・トレードオフ（2〜4項目）

共通要素:
- ヘッダー: タイトル、タグ（案件名・図の種類）、生成日
- 「draw.ioで編集」ボタン（エディタURLへのリンク）
- 「一覧に戻る」リンク

### 5.3 draw.io エディタリンク

詳細ページの「draw.io で編集」ボタンには、**MCPツール呼び出し時に返却されたエディタURL**をそのまま使用する。
このURLにはダイアグラムデータが埋め込まれているため、`.drawio` ファイルのホスティング不要でワンクリックで図を開ける。

```html
<div class="diagram-actions">
  <a href="{MCPツールが返却したエディタURL}" class="edit-btn" target="_blank">draw.io で編集</a>
</div>
```

**重要**: `.drawio` ファイルへのリンクや `raw.githubusercontent.com` 経由のURLは使用しないこと。
MCPツール（`open_drawio_mermaid` / `open_drawio_csv` / `open_drawio_xml`）の戻り値に含まれる
`https://app.diagrams.net/...` 形式のURLを必ず使用する。

### 5.4 図の種類別アイコン

カードに表示するアイコン（絵文字）:

| 図の種類 | アイコン | tag-type色 |
|---------|---------|-----------|
| ER図 | 🗄️ | `#8b5cf6`（紫） |
| フローチャート | 🔀 | `#3b82f6`（青） |
| シーケンス図 | 🔄 | `#22c55e`（緑） |
| ネットワーク図 | 🌐 | `#06b6d4`（シアン） |
| 業務フロー | 📋 | `#f59e0b`（オレンジ） |
| C4モデル | 🏗️ | `#ef4444`（赤） |
| 組織図 | 👥 | `#6b7280`（グレー） |
| その他 | 📊 | `#6b7280`（グレー） |

## 6. タスクログと Issue 作成

構成図の生成はファイル生成を伴う作業のため、必ずtask-logを記録する。

### 6.1 タスクログ記録

task-id: `YYYYMMDD-HHMMSS-drawio-{name}`

### 6.2 Issue 作成

タスク完了時に `gh issue create` で Issue を作成する。ラベル:
- `org:{org-slug}`
- `mode:direct`
- `type:feat`
- `dept:secretary`

## 7. Git ワークフロー

```
1. ブランチ: {org-slug}/feat/{YYYY-MM-DD}-add-drawio-{name}
2. git add docs/drawio/ .companies/{org-slug}/
3. コミット: feat: draw.io図を追加（{name}）[{org-slug}] by {operator}
4. PR作成 → URL報告（PR本文に draw.io エディタURL を記載すること）
5. main に戻る
```

**PR本文に必ず含める項目**:
- draw.io MCP ツール呼び出し時に返却されたエディタURL（`https://app.diagrams.net/...`）を `## draw.io エディタ` セクションとしてPR本文に記載する
- レビュアーがワンクリックで図を確認・編集できるようにするため

## 8. GitHub Pages 連携

- ダイアグラムは `docs/drawio/` に配置（GitHub Pages 公開対象）
- トップページ `docs/index.html` に紫枠のカードで自動リンク
- `/company-dashboard` 実行時も `generate-dashboard.sh` が `docs/drawio/index.html` を検出してカードを維持

## 9. 前提条件

| 項目 | 要件 |
|------|------|
| MCP Server | `drawio`（`@drawio/mcp`）が `.mcp.json` に設定済み |
| Node.js | インストール済み |
| npx | インストール済み |
