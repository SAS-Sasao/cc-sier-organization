# 11 AWS構成図生成

AWS Diagram MCP Server を使い、AWSアーキテクチャ構成図をPNG生成してGitHub Pagesギャラリーに公開します。

---

## 概要

```
「DWHの構成図を描いて」
  ↓
/company-diagram Skill 起動
  ├── list_icons: 利用可能アイコンを確認
  ├── get_diagram_examples: 構文の参考を取得
  └── generate_diagram: Python diagrams DSLでPNG生成
  ↓
docs/diagrams/ に配置
  ├── {name}.png（構成図画像）
  ├── {name}.html（詳細ページ）
  └── index.html（一覧ページにカード追加）
  ↓
Git PR → GitHub Pagesで公開
```

---

## 使い方

自然言語で依頼するだけです。

```
DWHの構成図を描いて
CI/CDパイプラインのアーキテクチャ図を作って
MLパイプラインのdiagramを追加して
```

必要に応じて秘書が以下をヒアリングします:

| # | 質問 | 例 |
|---|------|-----|
| Q1 | どの領域の構成図か | DWH, ネットワーク, アプリケーション |
| Q2 | 含めたいAWSサービス | S3, Glue, Redshift 等（任意） |
| Q3 | 図の名前 | `modern-data-lakehouse`（英語推奨） |

---

## MCP Server

AWS Diagram MCP Server（`awslabs.aws-diagram-mcp-server`）がプロジェクトの `.mcp.json` に設定されています。

### 利用するMCPツール

#### AWS Diagram MCP Server（図の生成）

| ツール | 用途 |
|--------|------|
| `list_icons` | 利用可能なAWSアイコンの一覧取得 |
| `get_diagram_examples` | 図の種類ごとのコード例取得 |
| `generate_diagram` | Python diagrams DSLからPNG生成 |

#### AWS Knowledge MCP Server（アーキテクチャレビュー）

| ツール | 用途 |
|--------|------|
| `aws___search_documentation` | サービス統合パターンの検証 |
| `aws___recommend` | ベストプラクティスとの差分検出 |

### コード規約

- `with Diagram(...)` で開始（import は自動）
- ラベルは **英語で記述**（日本語はフォント未対応で文字化け）
- `show=False` を必ず指定
- `direction="LR"` 推奨（左→右のデータフロー）
- `Cluster()` でレイヤーをグルーピング
- `Edge(label=..., color=..., style=...)` でフロー種別を可視化

---

## アーキテクチャレビュー

構成図の生成後、AWS Knowledge MCP Server を使って自動レビューが実行されます。

### レビュー観点（6軸）

| # | 観点 | 検証内容 |
|---|------|---------|
| 1 | サービス互換性 | 接続しているサービス同士が実際に統合可能か |
| 2 | データフロー整合性 | データの流れに論理的矛盾がないか |
| 3 | セキュリティ | パブリックアクセス保護、認証、暗号化、最小権限 |
| 4 | 可用性・耐障害性 | 単一障害点（SPOF）の有無、マルチAZ考慮 |
| 5 | コスト効率 | 不要な重複サービスがないか |
| 6 | ユーザー要望との一致 | 依頼内容が構成図に反映されているか |

### フロー

```
生成完了 → 6軸レビュー
  ├── 全 Pass → ギャラリー配置へ
  └── Fail → 指摘を反映して再生成（最大3回リトライ）
       └── 3回連続 Fail → 失敗パターンを Case Bank に記録
            → レビュアー自身がダイアグラムを作成
```

レビュー結果はタスクログの `## architecture-review` セクションに記録されます。

---

## ギャラリー構成

```
docs/diagrams/
├── index.html                        ← 一覧ページ（カードグリッド）
├── storcon-dwh-architecture.html     ← 詳細ページ
├── storcon-dwh-architecture.png      ← 構成図PNG
├── modern-data-lakehouse.html
├── modern-data-lakehouse.png
└── ...
```

### 一覧ページ（index.html）

カードグリッドレイアウトで全構成図を一覧表示します。各カードにはサムネイル、タイトル、プロジェクトタグ、領域タグ、説明、作成日が含まれます。

### 詳細ページ（{name}.html）

各構成図の詳細ページには以下が含まれます:

- ヘッダー（タイトル、タグ、生成日）
- 構成図画像（クリックでライトボックス拡大）
- 概要セクション
- データフロー（ステップ表示）
- レイヤー構成テーブル
- 「構成図一覧に戻る」リンク

---

## GitHub Pages での閲覧

構成図は `docs/diagrams/` に配置されるため、GitHub Pages を有効にすれば自動で公開されます。

```
https://{user}.github.io/{repo}/diagrams/
```

ダッシュボード（`/company-dashboard`）からもギャラリーへのリンクが自動生成されます。

---

## タスクログとIssue

構成図生成はファイル生成を伴うため、通常のタスクと同じく:

1. `.task-log/{task-id}.md` にタスクログを記録
2. LLM-as-Judge で3軸評価を実施
3. Git PR を作成
4. GitHub Issue を自動作成

---

## 前提条件

| 項目 | 要件 |
|------|------|
| MCP Server (図生成) | `awslabs.aws-diagram-mcp-server` が `.mcp.json` に設定済み |
| MCP Server (レビュー) | `aws-knowledge-mcp-server` が `.mcp.json` に設定済み |
| uv | インストール済み |
| Python 3.10+ | インストール済み |
| GraphViz | インストール済み（`dot -V` で確認） |

### GraphViz のインストール

```bash
# Ubuntu/Debian
sudo apt install graphviz

# macOS
brew install graphviz

# 確認
dot -V
```
