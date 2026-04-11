# L2 独立レビュープロンプト — draw.io ダイアグラム（LLM-as-Judge）

`/company-drawio` Phase 6 で、**秘書とは別の fresh な `general-purpose` agent** に渡して draw.io ダイアグラムを採点させるためのプロンプトテンプレート。

秘書は以下のテンプレートの `{...}` を埋めて `Agent` ツールで起動する。
**重要**: Phase 4 で実行済みの `review-drawio.js` の結果を s2 スコアに反映させる。

---

## 起動時に渡すプロンプト全文

```
あなたは独立レビュアーです。以下の draw.io ダイアグラムを 6 軸で採点してください。
あなたは執筆者ではないため、バイアスなく厳密に評価してください。

## 評価対象
- 組織: {org-slug}
- 図名: {filename}
- 図の種類: {diagram-type}（ER図/フローチャート/シーケンス図/C4モデル 等）
- 詳細HTMLパス: {html-path}
- .drawio ファイルパス: {drawio-path}
- 一覧ページパス: docs/drawio/index.html
- review-drawio.js 実行結果: {l0-result}（exit 0 = OK / exit 1 = issues detected / 詳細ログ）

## レビュー手順（必須）

1. **Read ツールで .drawio XML を読み込む** — ノード構造とエッジを把握
2. **Read ツールで詳細HTMLを読み込む** — 4セクション構成と構成要素表を確認
3. **Read ツールで一覧ページ (index.html) を読み込む** — カード追記と件数更新を確認
4. .drawio XML と HTML 説明の整合性を検証する
5. Phase 4 の `review-drawio.js` 結果を s2 スコアに反映する
6. 6軸で採点する

## 構造仕様（これに準拠しているかを判定）

### 詳細HTML 必須4セクション
1. **draw.ioビューア** — iframe または Mermaid プレビュー + XMLダウンロードボタン
2. **概要** — 図の目的・対象システム・スコープ
3. **構成要素** — テーブル形式（要素名 / 種類 / 説明）
4. **設計のポイント** — 設計判断・トレードオフ（2〜4項目）

### HTML 埋め込み禁則（Mermaid 文字化け防止）
- `<pre class="mermaid">` 内に絵文字禁止（🌙🌅☀️等）
- `\n`（改行エスケープ）禁止、半角スペースで代替
- `""`（ダブルクォート2つ）禁止、`"` で代替

### ファイル必須
- `docs/drawio/{filename}.drawio` — draw.io XML
- `docs/drawio/{filename}.html` — 詳細ページ
- `docs/drawio/index.html` — カード追記済み
- `.companies/{org}/docs/drawio/{filename}.md` — ソースメタデータ（任意だが推奨）

### エッジ設計方針
- 層間エッジ（コンテナをまたぐ接続）は **直線**（`edgeStyle` 指定なし）
- 層内エッジ（同一コンテナ内）のみ `edgeStyle=orthogonalEdgeStyle`
- waypoint ではなく配置で貫通を回避する

## 採点基準

各軸を 0.00〜1.00 で採点し、根拠を 1〜2 行で述べてください。

### s1. 構造準拠
- HTML 4セクション存在と順序
- 1.00: 全4セクション順序正 / 0.70: 順序ずれ / 0.50: 1セクション欠落 / 0.30: 2+欠落 / 0.00: 章構造崩壊

### s2. エッジ貫通【致命軸】
- Phase 4 の `review-drawio.js` 実行結果を基準とする
- **exit 0 → 1.00 固定**
- exit 1 で issues 1-2 件 → 0.60
- exit 1 で issues 3-5 件 → 0.30
- exit 1 で issues 6+ 件 → 0.00
- exit 2 (file error) → 0.00

### s3. XML/HTML整合性
- `.drawio` XML に含まれる主要ノード（`value` 属性）と HTML 構成要素表の要素名が一致
- 1.00: 全要素一致 / 0.80: 軽微な表記揺れ / 0.50: 1-2要素の欠落 / 0.30: 3+要素の欠落 / 0.00: ほぼ一致しない

### s4. 設計ポイントの具体性
- 2〜4項目あり、各項目が 1-3 行で具体的（「適切に設計」等の抽象表現を減点）
- 1.00: 全項目が具体的かつ数量や根拠あり / 0.70: 具体性バラつき / 0.50: 半数が抽象的 / 0.30: ほぼ抽象 / 0.00: セクション欠落 or 1項目のみ

### s5. 一覧ページ更新
- `docs/drawio/index.html` にカード追記済み、件数更新済み、アイコン・tag-type色が図の種類に合致
- 1.00: 全項目OK / 0.70: アイコン色不一致 / 0.50: 件数未更新 / 0.30: カードのみ / 0.00: 更新なし

### s6. HTML埋め込み禁則【致命軸】
- `<pre class="mermaid">` 内の絵文字・`\n`・`""` の有無
- 1.00: 違反なし / 0.70: 絵文字1個 / 0.50: 複数違反 / 0.30: 絵文字多数 or `\n` / 0.00: フォーマット崩壊

## 判定ルール

- 致命軸 (s2, s6) のいずれかが `< 0.5` → composite を **強制的に 0.00** とし `fail`
- それ以外: `composite = (s1 + s2 + s3 + s4 + s5 + s6) / 6`
  - `composite >= 0.85` → `pass`
  - `composite < 0.85` → `fail`

## 出力形式（JSON のみ、コードブロック不要、他の前置き一切なし）

{
  "s1_structure": 0.00,
  "s2_edge_penetration": 0.00,
  "s3_xml_html_consistency": 0.00,
  "s4_design_points_specificity": 0.00,
  "s5_index_update": 0.00,
  "s6_html_violations": 0.00,
  "composite": 0.00,
  "verdict": "pass",
  "critical_triggered": false,
  "findings": [
    "具体的な指摘1",
    "具体的な指摘2"
  ],
  "fix_suggestions": [
    "修正提案1",
    "修正提案2"
  ]
}

出力は上記 JSON のみ。マークダウンの装飾やコードブロックで囲まないでください。
```

---

## 秘書側（呼び出し元）での後処理

1. レビュアー応答を JSON パース（失敗時は再試行1回、それでも失敗なら L2 fail）
2. `verdict == "pass"` かつ `critical_triggered == false` → Phase 7 へ進む
3. `verdict == "fail"` → `findings` と `fix_suggestions` を秘書にフィードバック
   - s2 (エッジ貫通) fail → 4.2.1 の方針に従い配置・エッジスタイルを修正、`review-drawio.js` 再実行
   - s6 (HTML禁則) fail → `<pre class="mermaid">` 内の絵文字・`\n` を除去
   - その他 → 該当 HTML/XML を修正
   - 1回だけ修正 → 同じレビュアー条件で再採点
4. 再採点結果も fail → Phase 7 以降を中断、現在のブランチを維持してユーザーに JSON 結果を報告

---

## しきい値調整の運用メモ

- 初期しきい値: **composite ≥ 0.85**
- drawio は `review-drawio.js` という決定論的 L0 があるため、L2 は内容整合性の判定が中心
- 2-4 週間運用して fail 率を観察、過剰な fail が s4 (設計ポイント具体性) に偏る場合はしきい値を 0.80 に緩和を検討
- s2 (エッジ貫通) は L0 の結果をそのまま反映するため、しきい値調整ではなく review-drawio.js の検出ロジック側で改善する
