# 中間表現 YAML スキーマ定義 — /company-sheet

`/company-sheet` の Phase 1-2 で壁打ちしながら確定させ、Phase 4 で xlsx へ写像する
中間表現 YAML の完全定義。**この YAML が「人間の承認ゲート」の対象**であり、
確定後の YAML→xlsx 変換は決定論的に行われる。

保存先: `.companies/{org-slug}/docs/{dept}/sheet-{name}.yaml`

---

## 1. トップレベル構造

```yaml
name: <string>          # 必須。英語 kebab-case。ファイル名 sheet-{name}.yaml / {name}.xlsx に使う
title: <string>         # 必須。日本語可。シート/ブックの表示名
description: <string>   # 任意。何を試算するモデルか 1-2 行
assumptions: []         # 必須（空配列可）。前提パラメータ配列
sheets: []              # 必須。1 つ以上のシート定義
images: []              # 任意。画像挿入定義
```

---

## 2. assumptions[]（前提パラメータ）

壁打ちで揉める値（為替・期間・対象・単価係数など）を**ここに集約**する。
Phase 1 では Claude がデフォルト値を仮置きし、`note` に仮定の根拠を書く。Phase 2 で赤入れ。

```yaml
assumptions:
  - key: usd_jpy        # 必須。英数字スネークケース。formula から参照する識別子
    value: 155          # 必須。数値 or 文字列
    note: "為替レート（2026-06 想定、要確認）"  # 必須。仮定の根拠・出典
  - key: months
    value: 12
    note: "試算期間（月）"
```

| フィールド | 型 | 必須 | バリデーション |
|---|---|---|---|
| `key` | string | ✓ | snake_case、ブック内で一意。formula の `assumptions.{key}` 参照に使う |
| `value` | number/string | ✓ | 空不可 |
| `note` | string | ✓ | 仮定・根拠を必ず明記（赤入れ対象を可視化するため） |

**写像**: assumptions は専用シート `_assumptions`（または先頭シート上部）に
`key | value | note` の 3 列表として出力する。各 `value` セルが formula の参照先になる。

---

## 3. sheets[]（シート定義）

```yaml
sheets:
  - name: monthly                          # 必須。シート名（タブ名）
    columns: [サービス, 単価USD, 数量, 月額USD, 月額JPY]   # 必須。ヘッダー（左→右の順）
    input_cols: [サービス, 単価USD, 数量]   # 必須。手入力する列（columns の部分集合）
    formula_cols:                          # 必須（空配列可）。数式列
      - col: 月額USD
        formula: "=単価USD*数量"
      - col: 月額JPY
        formula: "=月額USD*assumptions.usd_jpy"
    rows:                                  # 必須。データ行（input 列の値を入れる）
      - { サービス: EC2, 単価USD: 100, 数量: 3 }
      - { サービス: RDS, 単価USD: 200, 数量: 1 }
```

| フィールド | 型 | 必須 | バリデーション |
|---|---|---|---|
| `name` | string | ✓ | ブック内で一意。Excel タブ名制約（31 文字以内、`/\?*[]:` 不可） |
| `columns` | string[] | ✓ | 1 つ以上。表示順 |
| `input_cols` | string[] | ✓ | `columns` の部分集合。**手入力セル** |
| `formula_cols` | object[] | ✓（空可） | `col` は `columns` に存在。`input_cols` と重複不可 |
| `rows` | object[] | ✓ | 各キーは `input_cols` に含まれること |

### 整合性ルール

- `input_cols ∪ {formula_cols[].col} ⊆ columns`（全列がどちらかに分類される）
- `input_cols ∩ {formula_cols[].col} = ∅`（**入力と計算は排他。これが品質の肝**）
- `columns` のうち input でも formula でもない列があれば Phase 1 で警告し分類を促す
- `rows[].{key}` は `input_cols` のキーのみ（formula 列の値は YAML に書かない＝計算で埋まる）

---

## 4. formula の記法と展開ルール

数式は**文字列**で記述する（openpyxl は計算せず文字列として書き込む）。

### 4.1 列名参照 → 同一行のセル番地に解決

`=単価USD*数量` のような **列名参照**は、生成時に「その行の該当列のセル番地」へ展開する。

例: `columns: [サービス, 単価USD, 数量, 月額USD]` で `月額USD` の formula `=単価USD*数量` は、
データ 1 行目（Excel 行 2）では `=B2*C2`、2 行目（行 3）では `=B3*C3` に展開される。

```
列→Excel列字: サービス=A, 単価USD=B, 数量=C, 月額USD=D
行 2: =B2*C2
行 3: =B3*C3
```

### 4.2 assumptions 参照 → assumptions セル番地に解決

`assumptions.usd_jpy` は `_assumptions` シートの該当 value セルへの絶対参照に展開する。

例: `_assumptions` で `usd_jpy` の value が B2 にあるなら
`=月額USD*assumptions.usd_jpy` → `=D2*_assumptions.$B$2`（同一行の月額USD × 為替）。

### 4.3 集計関数

`=SUM(月額JPY)` のような列全体集計は、その列のデータ範囲に展開する。

例: 月額JPY が E 列、データが行 2-4 なら合計行で `=SUM(E2:E4)`。
合計行を作る場合は `rows` の末尾に集計行用の formula を別途定義するか、
`formula_cols` の formula で範囲集計を指定する（記法は `=SUM({列名})`）。

### 4.4 サポートする演算

- 四則演算 `+ - * /`、括弧
- `SUM / AVERAGE / MAX / MIN / ROUND / IF`（Excel 標準関数名そのまま）
- 列名参照 / `assumptions.{key}` 参照

### 4.5 範囲式パースの注意（L0 数式参照チェック）★実運用の教訓

L0（Phase 5）で数式の参照先セルを範囲内検証する際、**範囲式 `sheet!A2:A18` の終端セル
`A18` にはシート修飾子が付かない**点に注意する。素朴に `[A-Z]+\d+` で個別セルを拾うと、
終端セルを「現在のシートの参照」と誤判定し **false-positive**（例: `summary!B2 -> summary!E18 範囲外`）
を出す。実際の数式 `=SUM(monthly!E2:E18)` は正しい。

L0 のセル参照抽出は **範囲を 1 トークンとして扱い、終端セルは始端セルのシートを継承させる**こと:

```python
# OK: 範囲式を1トークンで捕捉し、終端は始端のシートを継承
TOK = re.compile(r"(?:(?:'([^']+)'|([A-Za-z_]\w*))!)?(\$?[A-Z]{1,3}\$?\d+)(?::(\$?[A-Z]{1,3}\$?\d+))?")
# NG: 個別セルだけ拾うと範囲終端を現シート参照と誤判定する
```

初回実運用（2026-06-14 aws-cost-estimate, PR #582）で発生。**xlsx は無修正で、L0 チェッカ側の
バグだった**。L0 fail 時はまず「生成物の誤りか／ゲートの誤判定か」を切り分けること。

---

## 5. images[]（任意・サブ機能）

既存の図（`docs/diagrams/*.png` 等）を xlsx のセルに挿入する。

```yaml
images:
  - sheet: monthly        # 必須。挿入先シート名（sheets[].name のいずれか）
    cell: G2              # 必須。アンカーセル（左上）
    src: docs/diagrams/aws-architecture.png  # 必須。リポジトリ相対パス、実在すること
```

**写像**: openpyxl の `openpyxl.drawing.image.Image` で読み込み、`ws.add_image(img, cell)` で挿入。

| フィールド | 型 | 必須 | バリデーション |
|---|---|---|---|
| `sheet` | string | ✓ | `sheets[].name` に存在 |
| `cell` | string | ✓ | A1 形式のセル番地 |
| `src` | string | ✓ | リポジトリ相対パス、ファイルが実在 |

---

## 6. 完全な記入例

```yaml
name: aws-cost-estimate
title: AWS月額コスト試算
description: EDI受発注システムの AWS 移行後 月額ランニングコスト試算
assumptions:
  - { key: usd_jpy, value: 155, note: "為替レート（2026-06 想定、要確認）" }
  - { key: months, value: 12, note: "年額換算用の月数" }
sheets:
  - name: monthly
    columns: [サービス, 単価USD, 数量, 月額USD, 月額JPY]
    input_cols: [サービス, 単価USD, 数量]
    formula_cols:
      - { col: 月額USD, formula: "=単価USD*数量" }
      - { col: 月額JPY, formula: "=月額USD*assumptions.usd_jpy" }
    rows:
      - { サービス: EC2, 単価USD: 100, 数量: 3 }
      - { サービス: RDS, 単価USD: 200, 数量: 1 }
      - { サービス: S3,  単価USD: 30,  数量: 1 }
  - name: yearly
    columns: [項目, 月額JPY合計, 年額JPY]
    input_cols: [項目]
    formula_cols:
      - { col: 月額JPY合計, formula: "=SUM(monthly.月額JPY)" }
      - { col: 年額JPY, formula: "=月額JPY合計*assumptions.months" }
    rows:
      - { 項目: 合計 }
images:
  - { sheet: monthly, cell: G2, src: docs/diagrams/edi-aws-architecture.png }
```

---

## 7. xlsx 書式規約（Phase 4 / L1 で検証）

| 対象 | 書式 | 理由 |
|---|---|---|
| ヘッダー行 | 太字 + 背景色（例: `BDD7EE`） | 列の識別 |
| **input セル** | 塗りつぶし色（例: 薄黄 `FFF9C4`） | **手入力箇所を視覚的に明示** |
| **formula セル** | 塗りつぶしなし（または淡色） | 計算結果と入力を区別 |
| `_assumptions` value セル | input と同じ薄黄 | 前提も手で触る箇所のため |

入力セルと計算セルの書式区別は **L1 セルフ構造ゲートの必須項目**かつ **L2 s4 軸**の採点対象。

---

## 8. 関連

- `SKILL.md` — フェーズ構成と本スキーマの利用箇所
- `review-prompt.md` — L2 採点 6軸（本スキーマへの準拠を採点）
- `/mnt/skills/public/xlsx/SKILL.md` — openpyxl による xlsx 生成手法の正本
