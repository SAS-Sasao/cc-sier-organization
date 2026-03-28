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
2. docs/diagrams/{filename}.html（詳細ページ）を新規作成
3. docs/diagrams/index.html（一覧ページ）にカードを追記
```

## 4. ページ構成（一覧 → 詳細）

```
docs/diagrams/
├── index.html                        ← 一覧ページ（カードグリッド）
├── storcon-dwh-architecture.html     ← 詳細ページ
├── storcon-dwh-architecture.png      ← 構成図PNG
├── {new-diagram}.html                ← 追加時に作成
└── {new-diagram}.png
```

### 一覧ページ（index.html）のカードテンプレート

`<div class="grid">` 内に追記する:
```html
<a href="./{filename}.html" class="card">
  <img class="card-thumb" src="./{filename}.png" alt="{図タイトル}">
  <div class="card-body">
    <div class="card-title">{図タイトル}</div>
    <div class="card-meta">
      <span class="tag tag-project">{案件名}</span>
      <span class="tag tag-area">{領域}</span>
    </div>
    <div class="card-desc">{1行の説明}</div>
    <div class="card-date">{YYYY-MM-DD}</div>
  </div>
</a>
```
件数表示（`<p class="count">` 内の `11 / 11` の**右側の数字のみ**）も更新する。
左側の数字（`<span id="match-count">`）はJSが自動制御するため変更不要。

**注意**: 一覧ページには検索・フィルタ機能が実装済み。`<div class="grid">` 内にカードを追記するだけでよい。
検索バー・フィルタタグ・JavaScript は編集しないこと。

### 詳細ページ（{filename}.html）の構成

既存の詳細ページ（`storcon-dwh-architecture.html`）をテンプレートとして使用。**以下5セクションは必須**:

1. **凡例** — 構成図画像の直下に配置。Edge色ごとにフローの意味を日本語で説明（画像内は英語のため）
2. **概要** — アーキテクチャの目的・背景・対象ユースケース
3. **データフロー** — flow ステップ表示。複数パターンがあればバッジで分類
4. **レイヤー構成** — テーブル形式（レイヤー / AWSサービス / 用途）
5. **設計のポイント** — 重要な設計判断・トレードオフ・ベストプラクティス

凡例セクションのHTML:
```html
/* CSS */
.legend-grid { display:flex; flex-wrap:wrap; gap:12px 24px; }
.legend-item { display:flex; align-items:center; gap:8px; font-size:.85rem; }
.legend-line { width:28px; height:3px; border-radius:2px; flex-shrink:0; }
.legend-dashed { height:0; border-top:3px dashed; background:none !important; }

/* HTML（diagram-container 直後） */
<div class="section">
  <h2>凡例</h2>
  <div class="legend-grid">
    <div class="legend-item"><span class="legend-line" style="background:{Edge色}"></span> {ラベル} — {日本語の説明}</div>
    <div class="legend-item"><span class="legend-line legend-dashed" style="border-color:{Edge色}"></span> {破線ラベル} — {説明}</div>
  </div>
</div>
```

共通要素:
- ヘッダー: タイトル、タグ、生成日
- 構成図画像（クリックでライトボックス拡大）
- 「構成図一覧に戻る」リンク

## 5. タスクログと Issue 作成

構成図の生成はファイル生成を伴う作業のため、必ずtask-logを記録する。

### 5.1 タスクログ記録

**タスク受付時**に `.companies/{org-slug}/.task-log/{task-id}.md` を作成する。

task-id: `YYYYMMDD-HHMMSS-diagram-{name}`

```yaml
---
task_id: "{task-id}"
org: "{org-slug}"
operator: "{operator}"
status: in-progress
mode: direct
started: "{ISO8601}"
completed: ""
request: "{ユーザーの依頼原文}"
issue_number: null
pr_number: null
---
```

記録するセクション:
- **実行計画**: 描画対象、使用AWSサービス、MCP Server利用
- **成果物**: PNG、詳細HTML、一覧HTML更新、ソースMD

**タスク完了時**: `status: completed`、`completed` フィールドを更新。

### 5.2 LLM-as-Judge 評価

成果物が `docs/` 配下にあるため、コミット前に completeness / accuracy / clarity の3軸評価を実施し、task-logに `## judge` セクションを追記する。

### 5.3 Issue 作成

タスク完了時に `gh issue create` で Issue を作成する。ラベル:
- `org:{org-slug}`
- `mode:direct`
- `type:feat`
- `dept:secretary`

## 6. Git ワークフロー

```
1. ブランチ: {org-slug}/feat/{YYYY-MM-DD}-add-diagram-{name}
2. git add docs/diagrams/ .companies/{org-slug}/
3. コミット: feat: AWS構成図を追加（{name}）[{org-slug}] by {operator}
4. PR作成 → URL報告
5. main に戻る
```

## 7. GitHub Pages 連携

- 構成図は `docs/diagrams/` に配置（GitHub Pages 公開対象）
- トップページ `docs/index.html` にオレンジ枠のカードで自動リンク
- `/company-dashboard` 実行時も `generate-dashboard.sh` が `docs/diagrams/index.html` を検出してカードを維持

## 8. 前提条件

| 項目 | 要件 |
|------|------|
| MCP Server | `awslabs.aws-diagram-mcp-server` が `.mcp.json` に設定済み |
| uv | インストール済み |
| Python 3.10 | インストール済み |
| GraphViz | インストール済み（`dot -V` で確認） |
