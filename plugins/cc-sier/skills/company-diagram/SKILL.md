---
name: company-diagram
description: >
  AWS Diagram MCP Server を使用してAWSアーキテクチャ構成図を生成する。
  「構成図」「アーキテクチャ図」「ダイアグラム」「diagram」「AWS図」と言われたときに使用する。
---

# AWS構成図生成 Skill

AWS Diagram MCP Server（`awslabs.aws-diagram-mcp-server`）を使い、
AWSアーキテクチャ構成図を生成して GitHub Pages に公開する。

---

## 1. 起動

1. `.companies/.active` から org-slug を取得
2. `git config user.name` で operator を取得
3. ユーザーの依頼から描画対象を判定

## 2. ヒアリング（必要に応じて）

```
Q1: どの領域の構成図ですか？（例: DWH, ネットワーク, アプリケーション）
Q2: 含めたいAWSサービスはありますか？（任意）
Q3: 図の名前は？（英語推奨、日本語はフォント制約で文字化けの可能性あり）
```

**注意**: diagrams パッケージは日本語フォントに対応していないため、ラベルは英語で記述する。
日本語の解説は HTML ビューア側で表示する。

## 3. 構成図生成フロー

### 3.1 MCP ツール利用順序

1. `list_icons` — 利用可能アイコンの確認
2. `get_diagram_examples` — 構文の参考取得
3. `generate_diagram` — 図の生成（PNG出力）

### 3.2 generate_diagram 呼び出し

```
必須パラメータ:
  - code: Python diagrams DSL コード
  - filename: ファイル名（kebab-case、拡張子なし）
  - workspace_dir: リポジトリルートの絶対パス
```

**コード規約**:
- `with Diagram(...)` で開始。import 不要（ランタイムが自動インポート）
- ラベルは英語で記述
- `show=False` を必ず指定
- `direction="LR"` 推奨（左→右のデータフロー）
- `Cluster()` でレイヤーをグルーピング
- `Edge(label=..., color=..., style=...)` でフロー種別を可視化

### 3.3 生成後の配置

```
1. generated-diagrams/{filename}.png → docs/diagrams/{filename}.png にコピー
2. docs/diagrams/index.html のギャラリーにカードを追記
   - 図のタイトル、案件名、領域、生成日
   - レイヤー解説テーブル
   - クリックで拡大表示（lightbox）
```

## 4. HTML ビューア更新

`docs/diagrams/index.html` の `<div class="diagram-list">` 内に新しいカードを追記する。

カードテンプレート:
```html
<div class="diagram-card">
  <h2>{図タイトル}</h2>
  <div class="diagram-meta">
    <span>案件: {案件名}</span>
    <span>領域: {領域}</span>
    <span>生成日: {YYYY-MM-DD}</span>
  </div>
  <div class="diagram-img">
    <img src="./{filename}.png" alt="{図タイトル}" onclick="openLightbox(this.src)">
  </div>
  <div class="diagram-desc">
    <p>{図の説明}</p>
    <table>
      <tr><th>レイヤー</th><th>サービス</th><th>用途</th></tr>
      <!-- 各レイヤーの行 -->
    </table>
  </div>
</div>
```

## 5. Git ワークフロー

```
1. ブランチ: {org-slug}/feat/{YYYY-MM-DD}-add-diagram-{name}
2. git add docs/diagrams/ .companies/{org-slug}/
3. コミット: feat: AWS構成図を追加（{name}）[{org-slug}] by {operator}
4. PR作成 → URL報告
5. main に戻る
```

## 6. GitHub Pages 連携

- 構成図は `docs/diagrams/` に配置（GitHub Pages 公開対象）
- トップページ `docs/index.html` にオレンジ枠のカードで自動リンク
- `/company-dashboard` 実行時も `generate-dashboard.sh` が `docs/diagrams/index.html` を検出してカードを維持

## 7. 前提条件

| 項目 | 要件 |
|------|------|
| MCP Server | `awslabs.aws-diagram-mcp-server` が `.mcp.json` に設定済み |
| uv | インストール済み |
| Python 3.10 | インストール済み |
| GraphViz | インストール済み（`dot -V` で確認） |
