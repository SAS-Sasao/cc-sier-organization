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

### 3.3 アーキテクチャレビュー（AWS Knowledge MCP）

生成された構成図を AWS Knowledge MCP Server でレビューし、品質を担保する。

#### レビューフロー

```
generate_diagram 完了
  ↓
AWS Knowledge MCP でレビュー実行
  ├── ✅ 全観点 Pass → 3.4 配置へ進む
  └── ❌ 1つ以上 Fail → 指摘を反映して再生成（3.2 に戻る）
       ├── リトライ 1〜3回目 → 指摘事項を修正して generate_diagram 再実行
       └── 3回連続 Fail → フォールバック処理（3.3.4）
```

#### 3.3.1 レビュー観点（6軸）

生成されたダイアグラムコードと構成を、以下の6観点で評価する。
各観点は `aws___search_documentation` / `aws___recommend` で裏付けを取る。

| # | 観点 | 検証内容 | MCP ツール |
|---|------|---------|-----------|
| 1 | **サービス互換性** | 接続しているサービス同士が実際に統合可能か（例: API Gateway → Lambda は OK、API Gateway → Redshift は直接不可） | `search_documentation` |
| 2 | **データフロー整合性** | データの流れに論理的矛盾がないか（書き込み専用サービスからの読み取り、循環参照等） | `search_documentation` |
| 3 | **セキュリティ** | パブリックアクセス保護（WAF/CloudFront）、認証の有無、暗号化の考慮、最小権限 | `recommend` |
| 4 | **可用性・耐障害性** | 単一障害点（SPOF）の有無、マルチAZ/リージョンの考慮、バックアップ戦略 | `recommend` |
| 5 | **コスト効率** | 不要な重複サービスがないか、サーバーレス vs プロビジョニングの選択が適切か | `recommend` |
| 6 | **ユーザー要望との一致** | 依頼内容で指定されたサービス・領域・要件が構成図に反映されているか | — (依頼原文と照合) |

#### 3.3.2 レビュー実行手順

1. 生成されたダイアグラムコード（Python DSL）を解析し、使用サービスと接続関係を抽出
2. 各サービスの接続パターンについて `aws___search_documentation` で統合可否を確認
3. アーキテクチャ全体について `aws___recommend` でベストプラクティスとの差分を検出
4. 6観点それぞれを **Pass / Fail** で判定し、Fail の場合は具体的な指摘事項を記録

レビュー結果フォーマット:
```
## architecture-review (attempt {N}/3)

| # | 観点 | 判定 | 指摘事項 |
|---|------|------|---------|
| 1 | サービス互換性 | ✅ Pass / ❌ Fail | {具体的な指摘} |
| 2 | データフロー整合性 | ✅ Pass / ❌ Fail | {具体的な指摘} |
| 3 | セキュリティ | ✅ Pass / ❌ Fail | {具体的な指摘} |
| 4 | 可用性・耐障害性 | ✅ Pass / ❌ Fail | {具体的な指摘} |
| 5 | コスト効率 | ✅ Pass / ❌ Fail | {具体的な指摘} |
| 6 | ユーザー要望との一致 | ✅ Pass / ❌ Fail | {具体的な指摘} |

**総合判定**: ✅ Pass（6/6） / ❌ Fail（{N}/6）
```

#### 3.3.3 リトライ（最大3回）

Fail 時のリトライフロー:
1. 指摘事項を具体的な修正指示に変換
2. ダイアグラムコードを修正（サービス追加・接続変更・Cluster再構成等）
3. `generate_diagram` を再実行
4. 再度レビューを実行（attempt 2/3, 3/3）

リトライ時の注意:
- 前回の指摘事項をすべて反映したうえで再生成する
- 修正により新たな問題が発生していないか全観点を再チェック
- リトライ回数と各回の指摘事項をタスクログの `## architecture-review` セクションに記録

#### 3.3.4 フォールバック（3回連続Fail時）

3回連続で Fail した場合、以下の手順を実行する:

**Step 1: 失敗パターンを Case Bank に記録**

`.companies/{org-slug}/.case-bank/index.json` の `failure_patterns` に以下を追加:
```json
{
  "subagent": "secretary",
  "failure_reason": "構成図レビュー3回不合格: {主要な指摘事項の要約}",
  "count": 1,
  "source": "diagram-review",
  "how_to_apply": "{3回分の指摘から導出した再発防止策}",
  "detected_at": "{ISO8601}"
}
```

**Step 2: レビュアー自身がダイアグラムを作成**

レビューを実施した側（AWS Knowledge MCP を使用するエージェント）が、
3回分の指摘事項を踏まえたうえで自らダイアグラムを作成する。

手順:
1. `aws___recommend` で対象領域のリファレンスアーキテクチャを取得
2. `aws___search_documentation` で各サービスの統合パターンを確認
3. 3回分の全指摘事項を制約条件としてダイアグラムコードを新規作成
4. `generate_diagram` で PNG 生成
5. 自作の構成図に対してもレビュー6観点のセルフチェックを実施（ログに記録）
6. セルフチェック Pass → 3.4 配置へ進む

タスクログへの記録:
```
## architecture-review (fallback)

3回のレビューで不合格のため、レビュアーが直接作成に切り替え。
- 累積指摘事項: {3回分の指摘一覧}
- リファレンスアーキテクチャ: {aws___recommend の結果}
- セルフチェック: {6観点の判定結果}
```

### 3.4 IaCソースコード生成

レビュー Pass 後、ダイアグラムの構成を CloudFormation YAML で実装する。

#### 3.4.1 生成フロー

```
レビュー Pass
  ↓
CloudFormation YAML 生成
  ├── Parameters: 環境差分（dev/stg/prod）をパラメータ化
  ├── Resources: ダイアグラムの全AWSサービスを定義
  ├── サンプルデータ: # TODO: 実運用時に変更 コメント付き
  └── セキュリティ: 暗号化・最小権限・パブリックアクセスブロックをデフォルトON
  ↓
AWS IaC MCP Server で検証
  ├── validate_cloudformation_template（構文・スキーマ検証）
  └── check_cloudformation_template_compliance（セキュリティ・コンプライアンス検証）
  ↓
検証 Pass → コードビューアHTML生成 + 詳細ページにボタン追加
検証 Fail → 指摘を修正して再検証（最大2回リトライ）
```

#### 3.4.2 CloudFormation YAML の規約

- テンプレートフォーマット: `AWSTemplateFormatVersion: '2010-09-09'`
- `Description` にアーキテクチャ名と概要を記載
- `Parameters` セクションで環境名・VPC CIDR・アカウントID等をパラメータ化
- サンプル値には `# TODO: 実運用時に変更してください` コメントを付与
- 暗号化（KMS/SSE）をデフォルト有効
- IAMロールは最小権限で定義
- `Outputs` セクションで主要リソースのARN/エンドポイントを出力

#### 3.4.3 IaC MCP Server による検証

1. `validate_cloudformation_template` で構文・スキーマを検証
2. `check_cloudformation_template_compliance` でセキュリティ規則を検証
3. エラーがあれば修正して再検証（最大2回）
4. 検証結果をタスクログの `## iac-validation` セクションに記録

#### 3.4.4 成果物の配置

```
docs/diagrams/
├── {filename}.yaml          ← CloudFormation テンプレート
├── {filename}-iac.html      ← コードビューアページ（シンタックスハイライト付き）
├── {filename}.html          ← 詳細ページ（「IaCソースコードを見る」ボタンを追加）
└── {filename}.png
```

#### 3.4.5 コードビューアページ（{filename}-iac.html）

`references/generate-iac-viewer.py` を使用して生成する。

```bash
python3 .claude/skills/company-diagram/references/generate-iac-viewer.py \
  docs/diagrams/{filename}.yaml "{タイトル}"
```

**重要**: bash ヒアドキュメント内でのインライン生成は禁止。
JS正規表現の `$1`/`$2` がシェル変数展開されるため。必ず上記スクリプトを使用すること。

構成要素:
- ヘッダー: タイトル、生成日、検証ステータス
- YAMLコード表示（行番号付き、キーワードハイライト）
- 「構成図に戻る」リンク
- 「YAMLをダウンロード」リンク
- ダークモード対応

#### 3.4.6 詳細ページへのボタン追加

既存の詳細ページ（{filename}.html）の構成図画像の下に以下のボタンを追加:

```html
<a href="./{filename}-iac.html" class="iac-btn">IaCソースコードを見る</a>
```

### 3.5 ファイル配置

レビュー Pass + IaC生成後に実行する。

```
1. generated-diagrams/{filename}.png → docs/diagrams/{filename}.png にコピー
2. docs/diagrams/{filename}.yaml（CloudFormation テンプレート）を保存
3. docs/diagrams/{filename}-iac.html（コードビューアページ）を新規作成
4. docs/diagrams/{filename}.html（詳細ページ）を新規作成（IaCボタン付き）
5. docs/diagrams/index.html（一覧ページ）にカードを追記
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

**注意**: 一覧ページには検索・フィルタ機能（`<!-- ▼ 検索・フィルタ -->` ～ `<!-- ▲ 検索・フィルタ ここまで -->`）が実装済み。
カード追加時にこの範囲を編集・削除しないこと。カードは `<div class="grid">` 内にのみ追記する。

### 詳細ページ（{filename}.html）の構成

既存の詳細ページをテンプレートとして使用。**以下5セクションは必須**:

1. **凡例** — 構成図画像の直下に配置。Edge色ごとにフローの意味を日本語で説明（画像内は英語のため）
2. **概要** — アーキテクチャの目的・背景・対象ユースケース
3. **データフロー** — flow ステップ表示。複数パターンがあればバッジ（Sync/Async/Event等）で分類
4. **レイヤー構成** — テーブル形式（レイヤー / AWSサービス / 用途）
5. **設計のポイント** — このアーキテクチャの重要な設計判断・トレードオフ・ベストプラクティス（3〜5項目）

凡例セクションのHTML:
```html
/* CSS（<style>内に追加） */
.legend-grid { display:flex; flex-wrap:wrap; gap:12px 24px; }
.legend-item { display:flex; align-items:center; gap:8px; font-size:.85rem; }
.legend-line { width:28px; height:3px; border-radius:2px; flex-shrink:0; }
.legend-dashed { height:0; border-top:3px dashed; background:none !important; }

/* HTML（diagram-container の直後、概要セクションの前に配置） */
<div class="section">
  <h2>凡例</h2>
  <div class="legend-grid">
    <div class="legend-item"><span class="legend-line" style="background:{Edge色}"></span> {ラベル} — {日本語の説明}</div>
    <!-- 破線の場合 -->
    <div class="legend-item"><span class="legend-line legend-dashed" style="border-color:{Edge色}"></span> {ラベル} — {日本語の説明}</div>
  </div>
</div>
```

- Edge色はPythonコードの `Edge(color=...)` と同じCSS色名を使用（darkblue, darkgreen, purple, red, teal, darkorange, gray 等）
- `style="bold"` のEdgeは実線（`.legend-line`）、`style="dashed"` のEdgeは破線（`.legend-dashed`）で表示
- 画像内は英語のため、凡例で日本語の補足説明を提供する

上記に加え、アーキテクチャ固有の補足セクション（コスト概算、レイテンシー特性、学習ポイント等）を必要に応じて追加する。

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
| MCP Server (図生成) | `awslabs.aws-diagram-mcp-server` が `.mcp.json` に設定済み |
| MCP Server (レビュー) | `aws-knowledge-mcp-server` が `.mcp.json` に設定済み |
| uv | インストール済み |
| Python 3.10 | インストール済み |
| GraphViz | インストール済み（`dot -V` で確認） |
