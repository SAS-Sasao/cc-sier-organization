# 14 draw.io ダイアグラム生成

draw.io MCP Server を使い、ER図・フローチャート・シーケンス図・C4モデル等の汎用ダイアグラムを生成して GitHub Pages ギャラリーに公開します。

---

## 概要

```
「C4モデルで人材管理アーキテクチャを描いて」
  ↓
/company-drawio Skill 起動
  ├── 図の種類を判定（ER図/フロー/シーケンス/C4等）
  ├── 最適なMCPツールを選択（mermaid / csv / xml）
  └── draw.io MCP Server でダイアグラム生成
  ↓
docs/drawio/ に配置
  ├── {name}.drawio（draw.io XMLソース）
  ├── {name}.html（詳細ページ：Mermaidプレビュー + drawioダウンロード）
  └── index.html（一覧ページにカード追加）
  ↓
エッジ貫通レビュー → Git PR → GitHub Pagesで公開
```

---

## `/company-diagram` との使い分け

| 用途 | 使用するSkill |
|------|-------------|
| AWS構成図（AWSアイコン付きPNG） | `/company-diagram` |
| ER図・テーブル設計 | `/company-drawio` |
| フローチャート・業務フロー | `/company-drawio` |
| シーケンス図 | `/company-drawio` |
| C4モデル・システム概要図 | `/company-drawio` |
| ネットワーク図（非AWS） | `/company-drawio` |
| 組織図・階層構造 | `/company-drawio` |

**ポイント**: AWSサービスアイコンが必要なら `/company-diagram`、それ以外の汎用図は `/company-drawio` を使います。

---

## 使い方

自然言語で依頼するだけです。

```
C4モデルでデータ統合アーキテクチャを描いて
ER図でユーザーテーブルの関連を描いて
業務フローで承認プロセスを可視化して
シーケンス図でAPI連携の流れを描いて
```

必要に応じて秘書が以下をヒアリングします:

| # | 質問 | 例 |
|---|------|-----|
| Q1 | どんな図を作るか | ER図、フローチャート、C4モデル等 |
| Q2 | 含めたい要素 | テーブル名、処理ステップ、アクター等 |
| Q3 | 図の名前 | `talent-data-arch`（英語kebab-case推奨） |

---

## MCP Server

draw.io MCP Server（`@drawio/mcp`）がプロジェクトの `.mcp.json` に設定されています。

### 利用するMCPツール

| ツール | 入力形式 | 推奨用途 |
|--------|---------|---------|
| `open_drawio_mermaid` | Mermaid記法 | フローチャート、シーケンス図、ER図、状態遷移図 |
| `open_drawio_csv` | CSV | 組織図、ネットワークトポロジ、階層構造 |
| `open_drawio_xml` | draw.io XML | 精密なレイアウトが必要な図、C4モデル等 |

### ツール選択の基準

- **シンプルなフロー・シーケンス図** → `open_drawio_mermaid`（Mermaid記法で最も簡潔）
- **階層・ツリー構造** → `open_drawio_csv`（表形式でノード定義）
- **精密な配置・スタイル制御** → `open_drawio_xml`（完全なレイアウト制御、C4カラースキーム等）

---

## エッジ設計方針（貫通回避）

draw.io XMLで図を生成する際、エッジ（接続線）がノードを貫通しないよう以下のルールに従います。

### エッジスタイルの使い分け

| エッジ種別 | スタイル | 用途 |
|-----------|---------|------|
| 層間エッジ（コンテナをまたぐ） | **直線**（edgeStyle指定なし） | swimlane間の接続 |
| 層内エッジ（同一コンテナ内） | `orthogonalEdgeStyle`（直角） | 同一層内の隣接ノード間 |

### ノード配置の原則

- 接続先が隣接するよう並び順を調整（A→B→C なら A,B,C の順）
- 分岐がある場合は2列配置
- 層間で多対一の接続がある場合、ターゲットを接続元の中央高さに配置

### 自動レビュー

`.drawio` ファイル保存後、レビュースクリプトが自動実行されます:

```bash
node .claude/skills/company-drawio/references/review-drawio.js {filename}.drawio
```

- 終了コード `0`: 問題なし
- 終了コード `1`: エッジ貫通を検出 → ノード配置またはエッジスタイルを修正して再実行

---

## ギャラリー構成

```
docs/drawio/
├── index.html                        ← 一覧ページ（カードグリッド + 検索・フィルタ）
├── talent-data-arch.html             ← 詳細ページ（Mermaidプレビュー + drawioダウンロード）
├── talent-data-arch.drawio           ← draw.io XMLソース
├── enterprise-data-arch.html
├── enterprise-data-arch.drawio
└── ...
```

### 一覧ページ（index.html）

カードグリッドレイアウトで全ダイアグラムを一覧表示します。検索バー・フィルタタグ・ページネーション機能付き。

各カードには以下が含まれます:
- 図の種類アイコン（ER図: 🗄️、フロー: 🔀、C4: 🏗️ 等）
- タイトル
- プロジェクトタグ・種類タグ
- 1行の説明
- 作成日

### 詳細ページ（{name}.html）

各ダイアグラムの詳細ページには以下が含まれます:

- **Mermaid.jsプレビュー** — ページを開くだけで図を確認できる（CDNでSVGレンダリング）
- **draw.io XMLダウンロード** — `.drawio` ファイルをダウンロードしてdraw.ioアプリで編集可能
- **概要** — 図の目的・対象システム・スコープ
- **構成要素テーブル** — 要素名・種類・説明
- **設計のポイント** — 設計判断・トレードオフ

### 図の種類とアイコン

| 図の種類 | アイコン |
|---------|---------|
| ER図 | 🗄️ |
| フローチャート | 🔀 |
| シーケンス図 | 🔄 |
| ネットワーク図 | 🌐 |
| 業務フロー | 📋 |
| C4モデル | 🏗️ |
| 組織図 | 👥 |

---

## GitHub Pages での閲覧

ダイアグラムは `docs/drawio/` に配置されるため、GitHub Pages を有効にすれば自動で公開されます。

```
https://{user}.github.io/{repo}/drawio/
```

ポータルトップ（`docs/index.html`）からも紫枠のカードでリンクされます。ダッシュボード（`/company-dashboard`）からもギャラリーへのリンクが自動生成されます。

---

## `/company-diagram` との連携

C4モデル（論理設計）を `/company-drawio` で作成した後、AWSサービス実装版を `/company-diagram` で生成する、という2段階の使い方が効果的です。

```
Step 1: /company-drawio → C4 Container図（論理アーキテクチャ）
  ↓ AWSサービスにマッピング
Step 2: /company-diagram → AWS構成図（物理アーキテクチャ + IaCコード）
```

**実例**: 本リポジトリの「人材・パートナーデータ統合アーキテクチャ」は、この2段階で作成しました。

- C4モデル（draw.io）: [talent-data-arch.html](https://sas-sasao.github.io/cc-sier-organization/drawio/talent-data-arch.html)
- AWS構成図: [talent-data-arch-aws.html](https://sas-sasao.github.io/cc-sier-organization/diagrams/talent-data-arch-aws.html)

---

## タスクログとIssue

ダイアグラム生成はファイル生成を伴うため、通常のタスクと同じく:

1. `.task-log/{task-id}.md` にタスクログを記録
2. LLM-as-Judge で3軸評価を実施
3. Git PR を作成
4. GitHub Issue を自動作成

---

## 前提条件

| 項目 | 要件 |
|------|------|
| MCP Server | `drawio`（`@drawio/mcp`）が `.mcp.json` に設定済み |
| Node.js | インストール済み（レビュースクリプト実行用） |
| npx | インストール済み |

### draw.io MCP Server の確認

`.mcp.json` に以下の設定があることを確認:

```json
{
  "mcpServers": {
    "drawio": {
      "command": "npx",
      "args": ["-y", "@anthropic/draw.io-mcp"]
    }
  }
}
```
