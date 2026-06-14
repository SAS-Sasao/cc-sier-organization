---
name: company-sheet
description: >
  ユーザーと壁打ちしながら中間表現 YAML を確定させ、それを決定論的に Excel(xlsx)
  へ変換する Skill。試算表・コスト計算・各種モデルシートを生成。
  前半=対話（叩き台YAML→赤入れ往復）、後半=自動（YAML→xlsx→3層レビュー→PR）。
  「試算表」「Excel」「スプレッドシート」「コスト計算」「見積もり表」
  「モデルを作って」「シート作って」「/company-sheet」と言われたときに使用する。
---

# Excel 試算表・モデル統合実行 Skill

ユーザーとの壁打ちで**中間表現 YAML** を確定させ、それを決定論的に xlsx へ変換し、
「YAML確定 → xlsx生成 → 3層レビュー → PR自動マージ」までを完走する。

**核心は「前半=対話、後半=自動」の二層構造**。叩き台 YAML が確定した瞬間が人間の承認ゲートであり、
そこから先（YAML→xlsx）は写像が決定論的なので既存パターン通り自動でよい。

## 1. 適用条件

- `.companies/.active` に org-slug が存在する
- 純正 xlsx スキル（`/mnt/skills/public/xlsx/SKILL.md`）が参照可能
- `openpyxl` が利用可能（`uv run --with openpyxl` で隔離実行可）
- git status が clean（dirty なら中断。`--from-yaml` 時は Phase 3 から開始）

---

## 2. 設計思想: 二層モデルと承認ゲート

```
[対話層 / 非自動]  Phase 0-2   叩き台YAML → 赤入れ往復 → 「OK」で確定
        ────────── 承認ゲート（YAML 確定）──────────
[自動層 / 決定論]  Phase 3-9   YAML → xlsx → L0/L1/L2 → PR auto-merge
```

- **なぜ YAML を挟むか**: 値の正しさ（前提・数式の意味）は人間しか判断できない。
  YAML 上で揉めて確定させ、それを機械的に xlsx へ写すことで「人間が承認した内容」と
  「生成物」を一致させる。後半の機械チェックは「写像が壊れていないか」だけに集中できる。
- **数式は計算しない**: openpyxl は数式を文字列で書くだけで評価しない。値の正誤は Phase 2 で
  人間承認済みとみなす。L0/L1 は YAML→xlsx の写像健全性のみを検証する（§9-10）。

---

## 3. 9フェーズ + 承認ゲート概要

| Phase | 名称 | 中断条件 |
|---|---|---|
| 0 | 目的・スコープ軽ヒアリング | `--yes` でスキップ |
| 1 | 叩き台 YAML 生成 → 提示 | - |
| 2 | **壁打ちループ（YAML 差分編集の往復）★主役・非自動** | ユーザーが「OK」と言うまで先へ進まない |
| — | ──── 承認ゲート（YAML 確定・保存）──── | - |
| 3 | 前処理（branch / task-log） | git dirty |
| 4 | xlsx 生成（純正 xlsx skill 参照） | 生成失敗 |
| 5 | L0 機械レビュー（再オープン / 列網羅 / 参照健全） | 1回自動修正後もfail |
| 6 | L1 セルフ構造ゲート（assumptions/input/formula 反映・書式区別） | 1回自動修正後もfail |
| 7 | L2 独立レビュー（fresh general-purpose + テキスト抽出 + サムネPNG） | composite<0.85 がリトライ後も継続 |
| 8 | PR作成 & 自動マージ | gh pr merge失敗 |
| 9 | task-log & judge & Issue & 報告 | - |

各中断時は task-log を `status: blocked` で保存し、Phase名・原因・復旧手順を報告する。

---

## 4. Phase 0: 目的・スコープ軽ヒアリング

依頼が不明確な場合のみ最小限を確認する。`--yes` 指定時はスキップしデフォルトで進む。

```
Q1: 何の試算/モデルですか？（例: AWSコスト試算、要員計画、収支モデル）
Q2: シートの名前は？（英語 kebab-case 推奨。例: aws-cost-estimate）
Q3: どの部署の成果物ですか？（既定: secretary）
```

一問一答に陥らないこと。**ヒアリングは最小限**にとどめ、足りない前提は Phase 1 の
`assumptions` に Claude が仮置きして提示し、Phase 2 で赤入れさせる方式を取る。

---

## 5. Phase 1: 叩き台 YAML 生成

**完成形に近い YAML を Claude が先に提示する**（一問一答ではなく叩き台主導）。

- 為替・期間・対象などの揉めやすい値は **すべて `assumptions` に仮置き**し、`note` に根拠/仮定を明記
- `sheets[]` に列構成・`input_cols`（手入力セル）・`formula_cols`（数式セル）・`rows` を埋める
- 数式は `=SUM(...)` や `assumptions.usd_jpy` 参照を**文字列**で書く（§14 / sheet-schema.md）
- YAML をコードブロックで提示し、「**ここが違う、という箇所を指摘してください**」と促す

スキーマ詳細・記入例は `references/sheet-schema.md` を参照。

---

## 6. Phase 2: 壁打ちループ（★主役・非自動）

ユーザーの赤入れを **YAML の差分として反映**し、更新版を再提示する往復を繰り返す。

- ユーザー指摘 → 該当 `assumptions` / `formula_cols` / `rows` を編集 → 差分箇所を明示して再提示
- 値・前提・数式の意味についての議論はここで完結させる（**後半の自動層には持ち込まない**）
- **ユーザーが明示的に「OK」「確定」と言うまで Phase 3 に進まない**。Claude 判断で勝手に確定しない
- `--yes` でも Phase 2 はスキップしない（叩き台の承認は必須）。`--yes` は Phase 0 のみ対象

### 承認ゲート（YAML 確定・保存）

確定したら YAML を以下に保存する（設計意図の証跡、Git管理）:

```
.companies/{org-slug}/docs/{dept}/sheet-{name}.yaml
```

---

## 7. Phase 3: 前処理

```
1. .active → {org-slug}
2. git config user.name → {operator}
3. git status --porcelain が空でなければ中断（--from-yaml 時もこのチェックを行う）
4. {date} = YYYY-MM-DD, {task-id} = YYYYMMDD-HHMMSS-sheet-{name}
5. {branch} = {org-slug}/feat/{date}-add-sheet-{name}
6. git checkout -b {branch}
7. .task-log/{task-id}.md を YAML フロントマターで作成
    subagents: [openpyxl-generator, general-purpose-reviewer]  ← 必ず英字で記録
```

`--from-yaml {path}` 指定時は Phase 0-2 をスキップし、確定済み YAML を読み込んで本 Phase から開始する。

---

## 8. Phase 4: xlsx 生成

**純正 xlsx スキル（`/mnt/skills/public/xlsx/SKILL.md`）を必ず参照**し、その手法に従って
openpyxl で xlsx を生成する。YAML→xlsx の写像規約は `references/sheet-schema.md` に従う。

| YAML 要素 | xlsx への写像 |
|---|---|
| `assumptions[]` | 先頭 or 専用シートに key/value/note の表として出力。数式から参照される |
| `sheets[].columns` | 各シートのヘッダー行 |
| `sheets[].input_cols` | **手入力セル**。塗りつぶし色（例: 薄黄 `FFF9C4`）で計算セルと視覚的に区別 |
| `sheets[].formula_cols` | **数式セル**。`=...` 文字列をそのまま書き込む（openpyxl は計算しない） |
| `sheets[].rows` | データ行。input は値、formula は式を行番号に展開して配置 |
| `images[]`（任意） | `{sheet, cell, src}` を openpyxl の `Image` でセルに挿入（既存 `docs/diagrams/*.png` 等） |

### 配置

```
docs/office/{name}.xlsx                              ← xlsx バイナリ（commit、DL用。Pages配信なし）
.companies/{org-slug}/docs/{dept}/sheet-{name}.yaml  ← YAML 設計図（Phase 2 で保存済み）
```

数式参照（`assumptions.xxx`）は生成時に該当セル番地へ解決する。展開ルールは sheet-schema.md 参照。

---

## 9. Phase 5: L0 機械レビュー

写像健全性のみを決定論的に検証する（値の正誤は見ない）。

| # | チェック | 致命 |
|---|---|---|
| 1 | xlsx が openpyxl で再オープン可能（破損なし） | ★ |
| 2 | YAML の全シート・全列が生成物に存在する | ★ |
| 3 | 数式の参照先セルが範囲内・循環参照なし | ★ |

```bash
uv run --with openpyxl python - <<'PY'
# load_workbook で再オープン → sheet名/列名の集合一致 → 数式の参照解析（範囲内・循環なし）
PY
```

任意項目: `formulas` / `pycel` での式評価はベストエフォート（LibreOffice 依存は増やさない）。
fail → 1回自動修正（YAML or 生成コード）→ 再実行 → それでも fail なら中断。

⚠️ **チェック③の範囲式パース注意**: `=SUM(monthly!E2:E18)` の終端 `E18` はシート修飾なし。
個別セル抽出だと現シート参照と誤判定し false-positive を出す。**範囲は1トークンで捕捉し終端は
始端のシートを継承**させること（実運用の教訓、詳細は `references/sheet-schema.md` §4.5）。
L0 fail 時はまず「生成物の誤り／ゲートの誤判定」を切り分ける。

---

## 10. Phase 6: L1 セルフ構造ゲート

| チェック項目 | 方法 |
|---|---|
| `assumptions` 全件が xlsx に反映 | key/value がシート上に存在 |
| `input_cols` 全件が反映 | 各 input セルが存在 |
| `formula_cols` 全件が反映 | 各 formula セルに `=` 始まりの式が入る |
| **入力セルと計算セルの書式区別** | input セルに塗りつぶし色等、formula セルと異なる書式 |
| YAML 設計図が保存済み | `.companies/{org}/docs/{dept}/sheet-{name}.yaml` 存在 |

fail → 1回自動修正 → 再チェック → それでも fail なら中断。

---

## 11. Phase 7: L2 独立レビュー

**fresh `general-purpose` agent** を起動。xlsx のテキスト抽出結果と、サマリー/先頭シートの
**サムネイル PNG** を Read させ、task-log の request に対する **数表の構造妥当性**を採点する
（値の正誤ではなく構造を見る）。

### 起動方法

```
Agent(
  description: "sheet L2 review",
  subagent_type: "general-purpose",
  prompt: <references/review-prompt.md の内容 + 以下の情報>
    - xlsx パス（docs/office/{name}.xlsx）
    - xlsx テキスト抽出結果（シート/列/数式の一覧）
    - サムネイル PNG パス
    - YAML 設計図パス
    - task-log の request 原文
)
```

### 採点 6軸（詳細は `references/review-prompt.md`）

| # | 軸 | 致命 |
|---|---|---|
| s1 | 構造準拠（YAML 全シート/列が xlsx に存在） | ★ |
| s2 | 写像完全性（input/formula 列の反映漏れなし） | ★ |
| s3 | 数式整合性（参照先が範囲内・循環なし・数式列に式が入る） | - |
| s4 | 入力↔計算の書式区別（入力セルの色付け等） | - |
| s5 | request 充足（依頼意図を満たす列構成・粒度か） | - |
| s6 | 禁則違反（破損・空シート・assumptions 未反映） | ★ |

**判定**:
- 致命軸 (s1, s2, s6) のいずれかが `< 0.5` → composite 強制 0、fail
- それ以外は等重み平均 `≥ 0.85` で pass
- fail → 1回自動修正 → 再レビュー → それでも fail なら **auto-merge 中止**

---

## 12. Phase 8: PR作成 & 自動マージ

```bash
git add docs/office/{name}.xlsx .companies/{org-slug}/docs/{dept}/sheet-{name}.yaml .companies/{org-slug}/.task-log/
git commit -m "feat: Excel試算表 {name} を追加 [{org-slug}] by {operator}"
git push origin {branch}
gh pr create --title "feat: Excel試算表 {name} [{org-slug}]" --body "$(PR本文)"
gh pr merge --auto --squash --delete-branch
```

PR 本文に必ず含める項目: L0/L1/L2 全スコアと致命軸判定 / 確定 YAML の assumptions 要約 /
シート・列構成のサマリー。`--no-merge` 時は `gh pr merge` をスキップ。

---

## 13. Phase 9: task-log & judge & Issue & 報告

### task-log 更新（YAML フロントマター必須）

```yaml
---
task_id: "{task-id}"
status: completed
mode: "direct"
started: "..."
completed: "..."
request: "{ユーザー依頼原文}"
issue_number: {n}
pr_number: {n}
subagents: [openpyxl-generator, general-purpose-reviewer]
l0_gate: pass
l0_retries: {0|1}
l1_gate: pass
l1_retries: {0|1}
l2_composite: 0.00
l2_retries: {0|1}
l2_scores:
  s1_structure: 0.00
  s2_mapping_completeness: 0.00
  s3_formula_integrity: 0.00
  s4_format_distinction: 0.00
  s5_request_fulfillment: 0.00
  s6_violations: 0.00
---
```

### `## judge` セクション追記（dashboard 統合のため必須）

`rebuild-case-bank.sh` が読み取り `/company-dashboard` の judge グラフに反映される。
6軸 → 3軸マッピング:
- `completeness` = `(s1_structure + s2_mapping_completeness) / 2`
- `accuracy` = `(s3_formula_integrity + s5_request_fulfillment) / 2`
- `clarity` = `(s4_format_distinction + s6_violations) / 2`
- `total` = `l2_composite`

```markdown
## judge

\`\`\`yaml
completeness: {0.00}
accuracy: {0.00}
clarity: {0.00}
total: {l2_composite}
failure_reason: ""
judge_comment: "/company-sheet l2_scores から自動マッピング: completeness=avg(s1_structure,s2_mapping_completeness), accuracy=avg(s3_formula_integrity,s5_request_fulfillment), clarity=avg(s4_format_distinction,s6_violations)"
judged_at: "{ISO8601 with TZ}"
\`\`\`
```

### Issue 作成

```bash
gh issue create \
  --title "[{org-slug}] Excel試算表 {name}" \
  --label "org:{org-slug},mode:direct,type:sheet,dept:{dept}" \
  --body "$(Issue本文)"
```

### 最終報告フォーマット

```
✅ Excel試算表 {name} を生成しました！

L0機械レビュー:  PASS（retry {0|1}）
L1構造ゲート:    PASS（retry {0|1}）
L2独立レビュー:  composite {score}（retry {0|1}）

PR:      {pr_url} (merged)
Issue:   {issue_url}
xlsx:    docs/office/{name}.xlsx
YAML:    .companies/{org-slug}/docs/{dept}/sheet-{name}.yaml
```

---

## 14. 中間表現 YAML スキーマ（要約）

```yaml
name: aws-cost-estimate
title: AWS月額コスト試算
assumptions:
  - { key: usd_jpy, value: 155, note: "為替レート（2026-06 想定）" }
  - { key: months, value: 12, note: "試算期間" }
sheets:
  - name: monthly
    columns: [サービス, 単価USD, 数量, 月額USD, 月額JPY]
    input_cols: [サービス, 単価USD, 数量]        # 手入力セル
    formula_cols:                                  # 数式セル（文字列で記述）
      - { col: 月額USD, formula: "=単価USD*数量" }
      - { col: 月額JPY, formula: "=月額USD*assumptions.usd_jpy" }
    rows:
      - { サービス: EC2, 単価USD: 100, 数量: 3 }
images:                                            # 任意・サブ機能
  - { sheet: monthly, cell: G2, src: docs/diagrams/xxx.png }
```

- **input_cols と formula_cols を明示的に分離する**（入力 vs 計算の区別が品質の肝）
- 数式は `=SUM(...)` や `assumptions.xxx` 参照を文字列で記述（生成時にセル番地へ解決）
- 完全な定義・展開ルール・記入例は `references/sheet-schema.md`

---

## 15. オプションフラグ

| フラグ | 既定 | 効果 |
|---|---|---|
| `--yes` | off | Phase 0 ヒアリングをスキップ（Phase 2 の承認は省略不可） |
| `--no-merge` | off | PR 作成まで実行し、`gh pr merge` をスキップ |
| `--dry-run` | off | Phase 7 まで実行、Phase 8 以降スキップ |
| `--from-yaml {path}` | off | Phase 0-2 をスキップし、確定済み YAML から後半（Phase 3〜）を再実行 |

---

## 16. エラー時の中断ポリシー

- 各 Phase で fail → task-log を `status: blocked` で保存
- ユーザーへの報告に Phase 名・原因・手動復旧コマンドを含める
- 部分作成済みのブランチ / PR / xlsx は削除しない
- xlsx 生成失敗時は 1 回リトライ。それでも失敗なら Phase 4 を中断報告

---

## 17. 参照ファイル

| ファイル | 用途 |
|---|---|
| `references/sheet-schema.md` | 中間表現 YAML の完全定義 + 記入例 + openpyxl 写像規約 |
| `references/review-prompt.md` | L2 独立レビュアー採点プロンプト（6軸、JSON出力） |
| `/mnt/skills/public/xlsx/SKILL.md` | 純正 xlsx スキル（Phase 4 の生成手法の正本） |
| `.claude/skills/company/references/task-log-template.md` | task-log / Issue の共通スキーマ |
