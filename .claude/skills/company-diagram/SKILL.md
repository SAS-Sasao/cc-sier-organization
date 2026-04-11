---
name: company-diagram
description: >
  AWS Diagram MCP Server を使用してAWSアーキテクチャ構成図を生成し、
  L0機械レビュー → L1構造ゲート → L2独立レビュー → PR自動マージまでを統合実行する。
  「構成図」「アーキテクチャ図」「ダイアグラム」「diagram」「AWS図」
  「/company-diagram」と言われたときに使用する。
---

# AWS構成図統合実行 Skill

AWS Diagram MCP Server（`awslabs.aws-diagram-mcp-server`）を使い、
AWSアーキテクチャ構成図の「生成 → 3層レビュー → PR自動マージ」を 1 コマンドで完走する。

## 1. 適用条件

- `.companies/.active` に org-slug が存在する
- `awslabs.aws-diagram-mcp-server` が `.mcp.json` に設定済み
- `uv` / `Python 3.10` / `GraphViz` インストール済み（`dot -V` で確認）
- git status が clean（dirty なら中断）

---

## 2. 9フェーズ概要

| Phase | 名称 | 中断条件 |
|---|---|---|
| 0 | ヒアリング | `--yes` でスキップ |
| 1 | 前処理（branch / task-log） | git dirty |
| 2 | MCP 生成（list_icons → examples → generate_diagram） | 生成失敗 |
| 3 | ファイル配置（PNG + HTML + index + YAML + iac.html） | IaC生成スキップ不可 |
| 4 | L0 機械レビュー（IaC存在 + 英語ラベル） | 1回自動修正後もfail |
| 5 | L1 セルフ構造ゲート（5セクション + index整合） | 1回自動修正後もfail |
| 6 | L2 独立レビュー（fresh general-purpose + 画像Read） | composite<0.85 がリトライ後も継続 |
| 7 | PR作成 & 自動マージ | gh pr merge失敗 |
| 8 | task-log & Issue & 報告 | - |

各中断時は task-log を `status: blocked` で保存し、Phase名・原因・復旧手順を報告する。

---

## 3. Phase 0: ヒアリング

依頼が不明確な場合のみ以下を確認する。`--yes` 指定時はスキップしてデフォルト値で進む。

```
Q1: どの領域の構成図ですか？（例: DWH, ネットワーク, アプリケーション）
Q2: 含めたい AWS サービスはありますか？（任意）
Q3: 図の名前は？（英語 kebab-case 推奨）
```

**注意**: diagrams パッケージは日本語フォント非対応。**図内ラベルは必ず英語**で記述し、日本語の解説は HTML ビューア側で表示する。

---

## 4. Phase 1: 前処理

```
1. .active → {org-slug}
2. git config user.name → {operator}
3. git status --porcelain が空でなければ中断
4. {date} = YYYY-MM-DD, {task-id} = YYYYMMDD-HHMMSS-diagram-{name}
5. {branch} = {org-slug}/feat/{date}-add-diagram-{name}
6. git checkout -b {branch}
7. .task-log/{task-id}.md を YAML フロントマターで作成
    subagents: [mcp-aws-diagram-server, general-purpose-reviewer]
```

---

## 5. Phase 2: MCP 生成

### 5.1 MCP ツール利用順序

1. `list_icons` — 利用可能アイコンの確認
2. `get_diagram_examples` — 構文の参考取得
3. `generate_diagram` — 図の生成（PNG出力）

### 5.2 generate_diagram 呼び出し

```
必須パラメータ:
  - code: Python diagrams DSL コード
  - filename: ファイル名（kebab-case、拡張子なし）
  - workspace_dir: リポジトリルートの絶対パス
```

### 5.3 Python コード規約

- `with Diagram(...)` 開始、import 不要（ランタイムが自動インポート）
- **ラベルは必ず英語**（Phase 4 L0 機械チェックあり、日本語検出で fail）
- **ラベルに `\n` 改行を含めない**（`generate_diagram` が silent error で失敗する。半角スペース区切りを使う）
- `show=False` を必ず指定
- `direction="LR"` 推奨（左→右のデータフロー）
- `Cluster()` でレイヤーグルーピング
- `Edge(label=..., color=..., style=...)` でフロー種別を可視化

---

## 6. Phase 3: ファイル配置

以下を**すべて**生成する。IaC生成工程の省略は禁止（memory: feedback_no_skip_iac）。
**コスト概算・学習ポイントの省略も禁止**（memory: feedback_diagram_required_sections）。

```
1. generated-diagrams/{filename}.png → docs/diagrams/{filename}.png にコピー
2. docs/diagrams/{filename}.html         ← 詳細ページ（7セクション）
3. docs/diagrams/index.html              ← カード追記 + 件数更新
4. docs/diagrams/{filename}.yaml         ← CFn または CDK YAML
5. docs/diagrams/{filename}-iac.html     ← IaCビューア（YAML埋め込み）
```

### 6.1 詳細ページの必須7セクション（順序固定）

1. **凡例** — 構成図画像の直下。Edge色ごとのフロー種別を日本語で説明
2. **概要** — 目的・背景・対象ユースケース
3. **データフロー** — flow ステップ表示、複数パターン時はバッジで分類
4. **レイヤー構成** — テーブル形式（レイヤー / AWSサービス / 用途）
5. **設計のポイント** — 重要判断・トレードオフ・BP（2〜5項目、この構成固有の判断理由）
6. **コスト概算** — Dev/Prod 月額、USD + JPY 併記、合計行、前提条件、コスト最適化
7. **学習ポイント** — エンジニア/PM が得るべき普遍的な学び（`<ul class="learning-points">` で 3〜5 項目）

**コスト概算セクションの生成方法**:
- `references/aws-cost-estimation.md` の「クイックリファレンス見積」テーブル・「構成パターン別の概算」・「表示フォーマット」セクションを必ず参照する
- 使用する AWS サービスを構成図から洗い出し、Dev / Prod の 2 カラムで月額概算を記載
- 為替レートは `aws-cost-estimation.md` の「為替レート」セクションの値を使用（$1 = 150円 基準、JPY は参考値）
- 合計行を必ず付ける
- 前提条件とコスト最適化のポイントを各 1 段落で記載
- （任意）`awspricing` MCP が利用可能な場合はリアルタイム価格で補正可

**学習ポイントセクションの生成方法**:
- 3〜5 項目、各項目は `<li><strong>テーマ</strong> &#8212; 解説文（2〜4行）</li>` 形式
- **設計のポイント との違い**: 設計のポイントは「この構成でなぜ X を選んだか」（prescriptive）、学習ポイントは「この図から学べる普遍的な知見」（transferable / 汎用的）
- 他の類似案件にも通用する「原理原則」を書く（固有名詞依存の話ではなく、設計思想・パターン・トレードオフの一般化）
- `learning-points` クラスの `<ul>` を使い、CSS で左ボーダー強調・番号なしリスト表示にする
- 例: 「IAM と Lake Formation の役割分担」「Pub/Sub で密結合を解消する原則」「段階的導入戦略の重要性」等

### 6.2 一覧ページ（index.html）のカード追記

`<div class="grid">` 内にカードを追記する:

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

件数表示（`<p class="count">` の**右側の数字のみ**）も更新する。左側の `<span id="match-count">` は JS が自動制御。
検索バー・フィルタタグ・JavaScript は編集しないこと。

### 6.3 凡例セクションの HTML

```html
<style>
.legend-grid { display:flex; flex-wrap:wrap; gap:12px 24px; }
.legend-item { display:flex; align-items:center; gap:8px; font-size:.85rem; }
.legend-line { width:28px; height:3px; border-radius:2px; flex-shrink:0; }
.legend-dashed { height:0; border-top:3px dashed; background:none !important; }
</style>
<div class="section">
  <h2>凡例</h2>
  <div class="legend-grid">
    <div class="legend-item"><span class="legend-line" style="background:{Edge色}"></span> {ラベル} — {日本語の説明}</div>
  </div>
</div>
```

---

## 7. Phase 4: L0 機械レビュー

```bash
# 1. IaC ファイル存在チェック（s2 致命軸の基礎）
[ -f "docs/diagrams/{filename}.yaml" ] || FAIL=1
[ -f "docs/diagrams/{filename}-iac.html" ] || FAIL=1

# 2. Python コード内ラベルの英語チェック（s6 致命軸の基礎）
#    generate_diagram に渡したコード文字列から日本語を検出
grep -P "[\p{Hiragana}\p{Katakana}\p{Han}]" <<< "$code" && FAIL=1
```

**致命判定**: どちらか fail → 1回自動修正 → 再チェック → それでも fail なら中断して報告。

---

## 8. Phase 5: L1 セルフ構造ゲート

| チェック項目 | 方法 |
|---|---|
| HTML 7セクション全存在 | grep で `<h2>凡例</h2>`, `<h2>概要</h2>`, `<h2>データフロー</h2>`, `<h2>レイヤー構成</h2>`, `<h2>設計のポイント</h2>`, `<h2>コスト概算</h2>`, `<h2>学習ポイント</h2>` |
| 7セクションの順序 | 上記の順で並んでいること（設計のポイント → コスト概算 → 学習ポイント） |
| コスト概算テーブル | grep で `Dev (月額)` と `Prod (月額)` および `合計` 行の存在 |
| 為替換算（JPY）記載 | grep で `円` を含むコストセル（USD単独記載は不可） |
| 学習ポイントリスト | grep で `class="learning-points"` と 3 件以上の `<li>` |
| index.html カード追記 | grep で `{filename}.html` リンク存在 |
| 件数更新 | `<p class="count">` の右側数字が +1 されている |
| PNG / YAML / iac.html 存在 | ls チェック |

fail → 1回自動修正 → 再チェック → それでも fail なら中断。

---

## 9. Phase 6: L2 独立レビュー（画像Read 精度最大化）

**fresh `general-purpose` agent** を起動し、PNG 画像を Read ツールで実際に読み込ませて視認評価する。

### 起動方法

```
Agent(
  description: "AWS diagram L2 review",
  subagent_type: "general-purpose",
  prompt: <references/review-prompt.md の内容 + 以下の情報>
    - 詳細HTMLパス
    - PNG画像パス（必ず Read させる）
    - IaC YAMLパス
    - IaCビューアHTMLパス
    - Pythonコード（generate_diagram に渡したもの）
)
```

### 採点 6軸（詳細は `references/review-prompt.md`）

| # | 軸 | 致命 |
|---|---|---|
| s1 | **構造準拠（HTML 7セクション）** — 1つでも欠落で critical_triggered | ★ |
| s2 | **IaC生成** | ★ |
| s3 | PNG整合性（画像Read × HTML × Pythonコード） | - |
| s4 | 凡例完全性 | - |
| s5 | 一覧ページ更新 | - |
| s6 | **英語ラベル準拠** | ★ |

**判定**:
- 致命軸 (s2, s6) が `< 0.5` → composite 強制 0, fail
- それ以外は等重み平均 `≥ 0.85` で pass
- fail → 1回自動修正 → 再レビュー → それでも fail なら **auto-merge 中止**

---

## 10. Phase 7: PR作成 & 自動マージ

```bash
git add docs/diagrams/ .companies/{org-slug}/.task-log/
git commit -m "feat: AWS構成図 {name} を追加 [{org-slug}] by {operator}"
git push origin {branch}
gh pr create --title "feat: AWS構成図 {name} [{org-slug}]" --body "$(PR本文)"
gh pr merge --auto --squash --delete-branch
```

PR 本文には L0/L1/L2 全スコアと致命軸判定を埋め込む。

**注意**: 成果物はすべて `docs/diagrams/` 配下（GitHub Pages 配信先）にあるため、
マージ後の main 直コミットは不要。PR マージで即 Pages に反映される（`/company-daily-digest` Phase 7 相当の工程は不要）。

---

## 11. Phase 8: task-log & Issue & 報告

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
subagents: [mcp-aws-diagram-server, general-purpose-reviewer]
l0_gate: pass
l0_retries: {0|1}
l1_gate: pass
l1_retries: {0|1}
l2_composite: 0.00
l2_retries: {0|1}
l2_scores:
  s1_structure: 0.00
  s2_iac: 0.00
  s3_png_consistency: 0.00
  s4_legend: 0.00
  s5_index_update: 0.00
  s6_english_labels: 0.00
---
```

### `## judge` セクション追記（dashboard 統合のため必須）

task-log YAML フロントマターに加えて、`## judge` セクションを以下の YAML 形式で**必ず**追記する。これは `rebuild-case-bank.sh` が読み取り、`/company-dashboard` の「judge スコア推移」グラフに反映される。

6 軸 → 3 軸マッピング:
- `completeness` = `(s1_structure + s5_index_update) / 2`
- `accuracy` = `(s2_iac + s3_png_consistency) / 2`
- `clarity` = `(s4_legend + s6_english_labels) / 2`
- `total` = `l2_composite`

```markdown
## judge

\`\`\`yaml
completeness: {0.00}
accuracy: {0.00}
clarity: {0.00}
total: {l2_composite}
failure_reason: ""
judge_comment: "/company-diagram l2_scores から自動マッピング: completeness=avg(s1_structure,s5_index_update), accuracy=avg(s2_iac,s3_png_consistency), clarity=avg(s4_legend,s6_english_labels)"
judged_at: "{ISO8601 with TZ}"
\`\`\`
```

### Issue 作成

```bash
gh issue create \
  --title "[{org-slug}] AWS構成図 {name}" \
  --label "org:{org-slug},mode:direct,type:diagram,dept:secretary" \
  --body "$(Issue本文)"
```

### 最終報告フォーマット

```
✅ AWS構成図 {name} を公開しました！

L0機械レビュー:   PASS（retry {0|1}）
L1構造ゲート:     PASS（retry {0|1}）
L2独立レビュー:   composite {score}（retry {0|1}）

PR:     {pr_url} (merged)
Issue:  {issue_url}
図URL:  https://sas-sasao.github.io/cc-sier-organization/diagrams/{filename}.html
```

---

## 12. オプションフラグ

| フラグ | 既定 | 効果 |
|---|---|---|
| `--force` | off | 同名ファイル既存時に上書き |
| `--no-merge` | off | PR 作成まで実行し、`gh pr merge` をスキップ |
| `--dry-run` | off | Phase 6 まで実行、Phase 7 以降スキップ |
| `--yes` | off | Phase 0 ヒアリングをスキップしデフォルト値で進行 |

---

## 13. エラー時の中断ポリシー

- 各 Phase で fail → task-log を `status: blocked` で保存
- ユーザーへの報告に Phase 名・原因・手動復旧コマンドを含める
- 部分作成済みのブランチ / PR は削除しない（手動引き継ぎ用）
- MCP 呼び出し失敗時は 1 回リトライ。それでも失敗なら Phase 2 を中断報告

---

## 14. 参照ファイル

| ファイル | 用途 |
|---|---|
| `references/review-prompt.md` | L2 独立レビュアー採点プロンプト（6軸、JSON出力、画像Read指示） |
| `references/aws-cost-estimation.md` | コスト概算セクション生成用リファレンス（クイックリファレンス、為替、HTMLフォーマット） |
| `.claude/skills/company/references/task-log-template.md` | task-log / Issue の共通スキーマ |
