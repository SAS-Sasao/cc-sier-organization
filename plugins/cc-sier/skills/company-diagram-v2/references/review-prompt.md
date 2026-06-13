# L2 独立レビュープロンプト — AWS構成図 v2 / draw.io XML 方式（LLM-as-Judge）

`/company-diagram-v2` Phase 6 で、**秘書とは別の fresh な `general-purpose` agent** に渡して
AWS構成図（draw.io XML 方式）を採点させるためのプロンプトテンプレート。

秘書は以下のテンプレートの `{...}` を埋めて `Agent` ツールで起動する。
**重要**: agent には Read ツールで **`.drawio` XML を実際に読み込ませ**、XML 属性ベースで整合性を評価させること。
（現行 /company-diagram の PNG画像 Read は本 v2 では廃止。draw.io はラスタ画像を生成しないため XML Read に置換する。）

---

## 起動時に渡すプロンプト全文

```
あなたは独立レビュアーです。以下の AWS構成図（draw.io XML 方式）を 6 軸で採点してください。
あなたは執筆者ではないため、バイアスなく厳密に評価してください。

## 評価対象
- 組織: {org-slug}
- 図名: {filename}
- 詳細HTMLパス: {html-path}
- .drawio XMLパス: {drawio-path}
- IaC YAMLパス: {yaml-path}
- IaCビューアHTMLパス: {iac-html-path}
- 一覧 index.html パス: {index-path}
- Phase 4 L0① validate_drawio.py 結果（exit code + ログ）:
---
{l0_validate_result}
---
- Phase 4 L0② review-drawio.js 結果（exit code + ログ）:
---
{l0_review_result}
---

## レビュー手順（必須）

1. **Read ツールで .drawio XML を読み込む** — mxCell の value 属性（ノードラベル）、edge の strokeColor、
   resIcon=mxgraph.aws4.* のシェイプ名を実際に確認する（画像ではなく XML テキストを読む）
2. **Read ツールで詳細HTMLを読み込む** — **必須7セクション**（凡例/概要/データフロー/レイヤー構成/
   **設計のポイント**/**コスト概算**/**学習ポイント**）の存在と順序を確認
3. **Read ツールで IaC YAMLを読み込む** — CFn テンプレートの内容を確認
4. .drawio の value ノード集合と HTML のレイヤー構成表（s3）、edge の strokeColor 集合と凡例行（s4）を機械的に突合する
5. コスト概算セクションの妥当性を確認（Dev/Prod 併記、USD+JPY、合計行、前提条件）
6. 学習ポイントセクションの妥当性を確認（3〜5 項目、設計のポイントと重複せず transferable な知見か）
7. 6軸で採点する（必須セクション欠落または順序違反時は s1 = 0.30 以下かつ critical_triggered = true を強制）

## 構造仕様（これに準拠しているかを判定）

### 詳細HTML 必須7セクション（順序固定）
1. **凡例** — .drawio ビューア（iframe）の直下、Edge の strokeColor ごとのフロー種別を日本語で説明
2. **概要** — 目的・背景・対象ユースケース
3. **データフロー** — flow ステップ表示、複数パターン時はバッジ分類
4. **レイヤー構成** — テーブル形式（レイヤー / AWSサービス / 用途）
5. **設計のポイント** — 重要判断・トレードオフ・BP（2〜5項目、この構成固有）
6. **コスト概算** — Dev/Prod 月額テーブル（USD + JPY 併記）、合計行、前提条件、コスト最適化
7. **学習ポイント** — 普遍的な学び（`<ul class="learning-points">` で 3〜5 項目、transferable knowledge）

**重要**: 必須セクションのうち**1 つでも欠落している場合**、または**順序が違う場合**、
他のスコアに関わらず **`critical_triggered = true` かつ `verdict = "fail"` を強制する**こと。

**設計のポイント と 学習ポイント の違い**:
- 設計のポイント = この構成でなぜ X を選んだか（prescriptive、構成固有）
- 学習ポイント = この図から学べる普遍的な知見（transferable、汎用化された原理原則）
- 両方が存在し、かつ内容が明確に差別化されていることを確認する

### IaC 必須ファイル
- `{filename}.yaml` — CFn YAML
- `{filename}-iac.html` — IaCビューア（YAMLを埋め込み表示）

### draw.io XML 規約（.drawio を Read して確認）
- ルート構造が `mxfile > diagram > mxGraphModel > root`（validate_drawio.py がここを検証する）
- AWS アイコンは `shape=mxgraph.aws4.resourceIcon;resIcon=mxgraph.aws4.{shape_name}` 書式で、
  `{shape_name}` は aws4-shapes.json の正式名（無効名は L0① ERROR=exit1 で弾かれる）
- すべての edge mxCell に `strokeColor=#RRGGBB` が明示されている（凡例の単一ソース）
- 図内ラベル（value）は**日本語可**（旧 PNG 版の英語ラベル必須は本方式では撤廃）
- `mxGraphModel` に `background` 属性が無い（あると dark mode 破壊・L0① ERROR）

## 採点基準

各軸を 0.00〜1.00 で採点し、根拠を 1〜2 行で述べてください。

### s1. 構造準拠【致命軸】
- HTML 7セクションの順序と存在（凡例 / 概要 / データフロー / レイヤー構成 / **設計のポイント** / **コスト概算** / **学習ポイント**）
- 1.00: 完全準拠 / 0.70: 全7セクションあるが順序ずれ / 0.30: 1+ セクション欠落 / 0.00: 章構造崩壊
- **1 つでも欠落・順序違反した時点で s1 ≤ 0.30、かつ `critical_triggered = true` を強制**
- コスト概算セクションは `Dev (月額)` / `Prod (月額)` カラムを含むテーブルと、USD + JPY 併記、合計行が必須
- 学習ポイントセクションは `<ul class="learning-points">` で 3〜5 項目、各項目は `<strong>テーマ</strong> — 解説` 形式
- 設計のポイントと学習ポイントは内容が差別化されている（設計=構成固有の判断、学習=普遍的な知見）こと

### s2. IaC生成【致命軸】
- `{filename}.yaml` と `{filename}-iac.html` の両方が存在し、内容が図（.drawio のサービス群）と整合
- 1.00: 両ファイル存在・整合 / 0.80: 存在するがノードと要素が一部不一致 / 0.50: 片方のみ存在 / 0.30: 内容が空・スタブ / 0.00: 両方欠落

### s3. XML-HTML 整合性（XML Read）
- Read した `.drawio` の mxCell value（ノード/サービスラベル）集合と、HTML のレイヤー構成表に列挙された AWS サービスが一致
- 1.00: 完全一致 / 0.80: 軽微な差異（ラベル表記揺れ等） / 0.50: ノード1-2件の差異 / 0.30: 重大な不整合 / 0.00: XML と HTML が別物
- 画像 Read ではなく、XML テキスト中の value 属性を根拠にすること

### s4. 凡例完全性（edge strokeColor 集合 ↔ 凡例行）
- `.drawio` の edge mxCell が持つ `strokeColor` の集合（色の種類）が、HTML 凡例セクションの行と 1:1 対応し、矛盾しない
- dashed=1 のエッジ（失敗/フォールバック系）が凡例で区別されていること
- 1.00: 完全網羅・1:1対応 / 0.70: 1色欠落 / 0.50: 2色欠落 or strokeColor 明示漏れ / 0.30: 凡例セクション存在するが空 / 0.00: 凡例欠落

### s5. 一覧ページ更新
- `docs/diagrams/index.html` にカード追記済み、件数（右側数字）更新済み。検索/フィルタ JS は無改変
- 1.00: カード+件数更新 / 0.70: カードあり件数未更新 / 0.50: 件数のみ / 0.00: 更新なし

### s6. drawio品質【致命軸】
3 要素を総合評価する。いずれかに重大違反があれば s6 < 0.5（致命）とする:
- (a) **エッジ貫通**: Phase 4 L0② review-drawio.js の結果。exit 0（貫通なし）が前提。貫通残存は重大違反
- (b) **AWS4 シェイプ名妥当性**: Phase 4 L0① validate_drawio.py の結果。無効シェイプ名（ERROR/exit1）残存は重大違反。
  例: `cloudwatch_alarm` は無効（正は `cloudwatch`）。`mxGraphModel` の background 属性も ERROR
- (c) **HTML 禁則**: 詳細HTML の凡例/ステップ内に絵文字や `\n` 等の禁則が混入していないこと
- 1.00: (a)(b)(c) すべて clean / 0.80: 軽微（HTML 表記揺れ等） / 0.50: 1要素に明確な違反 / 0.30: 複数違反 / 0.00: 貫通・無効シェイプが多発

## 判定ルール

- **致命軸 (s1, s2, s6)** のいずれかが `< 0.5` → composite を **強制的に 0.00** とし `fail`（critical_triggered = true）
- **必須7セクションのいずれかが欠落・順序違反**している場合は、他のスコアに関わらず composite = 0.00, verdict = fail, critical_triggered = true
- それ以外: `composite = (s1 + s2 + s3 + s4 + s5 + s6) / 6`
  - `composite >= 0.85` → `pass`
  - `composite < 0.85` → `fail`

## 出力形式（JSON のみ、コードブロック不要、他の前置き一切なし）

{
  "s1_structure": 0.00,
  "s2_iac": 0.00,
  "s3_xml_html_consistency": 0.00,
  "s4_legend": 0.00,
  "s5_index_update": 0.00,
  "s6_drawio_quality": 0.00,
  "composite": 0.00,
  "verdict": "pass",
  "critical_triggered": false,
  "findings": [
    "具体的な指摘1（.drawio XML を Read して観察した事実を含める）",
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
   - s1 致命 fail → HTML の欠落/順序を修正（7セクション固定順序に並べ替え）
   - s2 致命 fail → IaC（YAML / iac.html）を再生成
   - s6 致命 fail → .drawio を修正（貫通: waypoint 追加 / 無効シェイプ名: 正式名へ置換 / HTML 禁則除去）→ Phase 4 L0 を再実行
   - 非致命軸 fail → HTML/index.html を修正
   - 1回だけ修正 → 同じレビュアー条件で再採点
4. 再採点結果も fail → Phase 7 以降を中断、現在のブランチを維持してユーザーに JSON 結果を報告

---

## しきい値調整の運用メモ

- 初期しきい値: **composite ≥ 0.85**
- diagram は構造成果物のため、XML Read による整合判定は PNG 視認より客観性が高い（strokeColor 集合の機械突合等）。
  2-4 週間運用して fail 率が 30% を超える場合は 0.80 に緩和を検討
- s3 (XML-HTML 整合性) / s4 (strokeColor 凡例) のスコア分布を特に注視する
- 致命軸（s1, s2, s6）のしきい値 0.5 は下げない（構造的な品質保証の最後の砦）
- **旧 s6_english_labels（英語ラベル致命軸）は廃止**した。draw.io XML 方式では図内ラベルに日本語を使えるため、
  英語ラベル準拠は不要。代わりに s6 を drawio品質（貫通/AWS4シェイプ名/HTML禁則）に置換した
- s1 を致命軸化した理由: 現行 /company-diagram 初回運用時（2026-04-11）にコスト概算セクション欠落を L2 が
  捕捉できず別途指摘で判明したため。必須セクションの欠落は composite が 0.85 を割らないレベルの均し込みでは検出漏れが発生する
