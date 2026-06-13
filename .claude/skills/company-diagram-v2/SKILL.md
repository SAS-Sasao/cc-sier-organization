---
name: company-diagram-v2
description: >
  draw.io XML を LLM が直接生成する方式（AWS 公式 deploy-on-aws skill 手法）で
  AWS アーキテクチャ構成図を作り、L0機械レビュー → L1構造ゲート → L2独立レビュー →
  PR作成までを統合実行する。MCP を一切使わず PyPI/GraphViz 依存ゼロ。
  「AWS構成図 v2」「AWS構成図 drawio版」「diagram v2」「AWS図 v2」
  「/company-diagram-v2」と言われたときに使用する。
  ※ 現行 /company-diagram は PNG/MCP 方式（docs/diagrams）で温存。本 v2 は同じ
  docs/diagrams へ draw.io XML(.drawio) を出力する移行版。AWS以外の汎用図は /company-drawio。
---

# AWS構成図統合実行 Skill（v2 / draw.io XML 方式）

LLM が draw.io XML（`.drawio`）を**直接生成**し、AWSアーキテクチャ構成図の
「生成 → 3層レビュー → PR」を 1 コマンドで完走する。`awslabs.aws-diagram-mcp-server`
（PNG生成MCP、deprecated）を使わず、PyPI / GraphViz / `uv`（生成）への外部依存をゼロにする。

**現行 `/company-diagram`（PNG/MCP方式）は無変更で温存**し、本 v2 は並列の別スキルとして
両方 `/` から呼べる。出力先は現行と同じ `docs/diagrams/`（資産・index.html を共有）。

設計の正本: `.companies/domain-tech-collection/docs/decisions/2026-06-13-diagram-aws-skill-migration-design.md`

## 1. 適用条件

- `.companies/.active` に org-slug が存在する
- `node`（`review-drawio.js` 用）と `uv`（`validate_drawio.py` を `--with defusedxml` 隔離実行）が利用可能
- `.claude/skills/company-diagram-v2/references/drawio/` 一式が存在する（同期済み）
- git status が clean（dirty なら中断）
- **MCP は不要**（`.mcp.json` 不変、本スキルは MCP を呼ばない）

---

## 2. 9フェーズ概要

| Phase | 名称 | 中断条件 |
|---|---|---|
| 0 | ヒアリング | `--yes` でスキップ |
| 1 | 前処理（branch / task-log） | git dirty |
| 2 | **生成（LLM が draw.io XML を直接生成・MCP不使用）** | 生成失敗 |
| 3 | ファイル配置（.drawio + HTML + index + YAML + iac.html + サムネ） | IaC生成スキップ不可 |
| 4 | L0 機械レビュー（二段直列: validate_drawio.py + review-drawio.js） | 1回自動修正後もfail |
| 5 | L1 セルフ構造ゲート（7セクション + コスト + 学習ポイント + index整合） | 1回自動修正後もfail |
| 6 | L2 独立レビュー（fresh general-purpose + .drawio XML Read） | composite<0.85 がリトライ後も継続 |
| 7 | PR作成（**v2 は auto-merge せず人手レビュー推奨**） | gh pr create失敗 |
| 8 | task-log & Issue & 報告 | - |

各中断時は task-log を `status: blocked` で保存し、Phase名・原因・復旧手順を報告する。

---

## 3. Phase 0: ヒアリング

依頼が不明確な場合のみ確認する。`--yes` 指定時はスキップしデフォルト値で進む。

```
Q1: どの領域の構成図ですか？（例: DWH, ネットワーク, アプリケーション）
Q2: 含めたい AWS サービスはありますか？（任意）
Q3: 図の名前は？（英語 kebab-case 推奨）
Q4: IaC 対象リソースと環境は？（Dev/Prod。CFn YAML を Phase 3 で直接生成する）
```

**注意**: draw.io XML 方式では **図内ラベルに日本語を使用してよい**（現行PNG版の「ラベル英語必須」制約は撤廃）。
ただし**シェイプ名（`resIcon=mxgraph.aws4.*` の名前）は英語の正式名のみ**（無効名は L0 で ERROR=exit1）。

---

## 4. Phase 1: 前処理

```
1. .active → {org-slug}
2. git config user.name → {operator}
3. git status --porcelain が空でなければ中断
4. {date} = YYYY-MM-DD, {task-id} = YYYYMMDD-HHMMSS-diagram-v2-{name}
5. {branch} = {org-slug}/feat/{date}-add-diagram-v2-{name}
6. git checkout -b {branch}（既に作業ブランチ上なら流用可）
7. .task-log/{task-id}.md を YAML フロントマターで作成
    subagents: [general-purpose-reviewer]   ← 英字記録（Case Bank 検出のため）
```

---

## 5. Phase 2: 生成（draw.io XML 直接生成・最重要）

**MCP を一切呼ばない。** LLM が `mxfile > diagram > mxGraphModel > root` 構造の draw.io XML を直接書く。
以下を**この順序でロード**し規約を頭に入れてから生成する（プログレッシブ・ディスクロージャ）:

1. `references/drawio/xml-rules.md` — mxCell 書式・edge ラベル・コンテナ規約
2. `references/drawio/style-guide.md` — スタイル文字列・カテゴリ色・タイトルブロック・凡例
3. `references/drawio/xml-templates-structure.md` — mxfile ラッパー・タイトル・Users・凡例の XML 骨格
4. `references/drawio/layout-guidelines.md` — 間隔・エッジ貫通回避・複雑図スケーリング
5. （複雑図の few-shot）`references/drawio/samples/*.drawio`、種別テンプレ `diagram-templates-{basic,advanced}.md`

### 5.1 シェイプ名（必須・致命）

- AWS アイコンは `shape=mxgraph.aws4.resourceIcon;resIcon=mxgraph.aws4.{shape_name}` 書式
- `{shape_name}` は **`references/drawio/aws4-shapes-services.md` / `aws4-shapes-resources.md` に載る正式名のみ**使う
- `aws4-shapes.json` に無い名前は `validate_drawio.py` が **ERROR（exit 1）** で弾く（旧PNG版の WARN ではない）
- 例: CloudWatch アラームは `cloudwatch_alarm` は**無効**。`cloudwatch` を使う（PoC 既知ハマり。ドライ実行では `cloudwatch_2` が有効名）
- 注: `validate_drawio.py` の "N unique shapes" 表示は `shape=mxgraph.aws4.X` のみ数え `resIcon=` を含めないため実サービス数と乖離する（表示上の癖。採点・判定には影響しない）

### 5.2 エッジ（凡例の単一ソース化＝設計 未決D）

- すべての `edge` mxCell に **`strokeColor=#RRGGBB` を必須明示**（省略禁止）
- 凡例（HTML s4）の各行は、図中に実在する `strokeColor` 集合と **1:1 対応**させる
- 層間エッジは直線、層内隣接のみ `edgeStyle=orthogonalEdgeStyle`（貫通回避）
- フォールバック/失敗系のみ `dashed=1`

### 5.3 貫通回避（初回 L0 ② で詰まらないため）

**最重要（v2 ドライ実行で判明・必須）**: `review-drawio.js` は装飾コンテナ（`container=1;pointerEvents=0` の aws-cloud / region 等）も貫通判定の対象に含める。以下2点を**初回から必ず**守ること（守らないと deploy-on-aws の shipped サンプルですら exit 1 になる既知の挙動。ドライ実行ではこれを守らず初回40件の誤検知が出た）:

- **エッジは必ずサービスアイコン同士（icon-to-icon）を `source`/`target` にする**。group / コンテナを `source`/`target` にしない（group→group 接続は自分の target アイコンを「貫通」と誤検知される）
- **service group（VPC/Subnet/サービス群コンテナ）は `parent` を aws-cloud 等の上位コンテナに設定（reparent）し、子要素は相対座標にする**。絶対座標のままだと aws-cloud 全面コンテナを全エッジが貫通と誤検知される

- **横ゾーン・水平エッジ**を基本にする（layout-guidelines の column-based / pipeline）
- 13+ サービスは horizontal 220px / vertical 160px、長距離エッジは `<Array as="points">` 明示 waypoint
- 中間コンテナを貫くエッジは waypoint で迂回。同一サービスの複数出力は exit 点を別々に振る

### 5.4 出力

- `docs/diagrams/{filename}.drawio`（**非圧縮 XML**。`mxGraphModel に background 属性を付けない**＝dark mode 破壊・L0 ERROR）

---

## 6. Phase 3: ファイル配置

以下を**すべて**生成する。IaC生成・コスト概算・学習ポイントの省略は禁止
（memory: feedback_no_skip_iac / feedback_diagram_required_sections）。

```
1. docs/diagrams/{filename}.drawio       ← draw.io XML（Phase 2 出力）
2. docs/diagrams/{filename}.html          ← 詳細ページ（必須7セクション）
3. docs/diagrams/index.html               ← カード追記 + 件数更新
4. docs/diagrams/{filename}.yaml          ← CFn YAML（LLM 直接生成。設計 未決C）
5. docs/diagrams/{filename}-iac.html      ← IaCビューア（generate-iac-viewer.py で YAML 埋め込み）
6. docs/diagrams/{filename}.png           ← サムネイル（設計 未決A、下記 6.3）
```

### 6.1 詳細ページの必須7セクション（順序固定・現行 /company-diagram と同一）

1. **凡例** — `.drawio` ビューア（iframe 埋め込み）の直下。Edge の strokeColor ごとのフロー種別を日本語で説明（5.2 と 1:1）
2. **概要** — 目的・背景・対象ユースケース
3. **データフロー** — flow ステップ表示、複数パターン時はバッジで分類
4. **レイヤー構成** — テーブル形式（レイヤー / AWSサービス / 用途）。`.drawio` の各サービス value と整合
5. **設計のポイント** — 重要判断・トレードオフ・BP（2〜5項目、この構成固有の判断理由）
6. **コスト概算** — Dev/Prod 月額、USD + JPY 併記、合計行、前提条件、コスト最適化
7. **学習ポイント** — `<ul class="learning-points">` で 3〜5 項目、transferable な普遍的学び

**コスト概算**: `references/aws-cost-estimation.md` の「クイックリファレンス見積」「構成パターン別の概算」
「表示フォーマット」「為替レート（$1=150円基準）」を必ず参照。Dev/Prod 2カラム・合計行・前提条件・最適化を記載。

**学習ポイント**: 各項目 `<li><strong>テーマ</strong> &#8212; 解説文（2〜4行）</li>`。
設計のポイント（prescriptive・構成固有）と内容を明確に差別化し、原理原則（transferable）を書く。

### 6.2 ビューア（iframe）と凡例 HTML

`.drawio` を draw.io の viewer 埋め込み（`https://viewer.diagrams.net/?...` もしくは
`<iframe src="./{filename}.drawio">` の embed パターン）で表示する。サムネ PNG がある場合は
カード/詳細頭にも `<img>` を併用。凡例 HTML は現行 /company-diagram と同じ `.legend-grid` 構造を踏襲し、
各 `.legend-line` の `background` を図中の strokeColor と一致させる。

### 6.3 サムネイル（設計 未決A: CLI export → fallback）

- 正路: `references/drawio/cli-export.md` 手順で draw.io CLI が PATH にあれば
  `drawio -x -f png -b 10 -o docs/diagrams/{filename}.png docs/diagrams/{filename}.drawio` で PNG export
- fallback: CLI が無い／失敗時は **iframe 埋め込み + アイコンカード**（PNG なしでカード成立）に切替。
  index.html の `card-thumb` を持たないカード variant を使う（CLI が無くてもブロッカーにしない）

### 6.4 一覧ページ（index.html）のカード追記

`<div class="grid">` 内にカードを追記し、件数表示（`<p class="count">` の**右側の数字のみ**）を更新する。
左側 `<span id="match-count">`・検索バー・フィルタ・JavaScript は**編集しない**（AC-9: 既存 PNG23/HTML47 資産保全）。
サムネ無し fallback 時は `card-thumb` img を省いたカードにする。

---

## 7. Phase 4: L0 機械レビュー（二段直列）

**重要**: exit code をパイプで潰さない。実行と表示を分離するか `set -o pipefail` を冒頭に置く（`| tail` 等で握りつぶし禁止）。

```bash
set -o pipefail
FAIL=0
# 先行: 必須ファイル・7セクション存在
[ -f "docs/diagrams/{filename}.drawio" ] || FAIL=1
[ -f "docs/diagrams/{filename}.yaml" ]   || FAIL=1
[ -f "docs/diagrams/{filename}-iac.html" ] || FAIL=1
for h in 凡例 概要 データフロー レイヤー構成 設計のポイント コスト概算 学習ポイント; do
  grep -q "<h2>$h</h2>" "docs/diagrams/{filename}.html" || FAIL=1
done

# L0① XML構造 + AWS4 シェイプ allowlist（無効シェイプ名は ERROR=exit1）
uv run --with defusedxml python \
  .claude/skills/company-diagram-v2/references/drawio/scripts/validate_drawio.py \
  docs/diagrams/{filename}.drawio > /tmp/l0_validate.txt 2>&1
V_EXIT=$?
cat /tmp/l0_validate.txt   # 実行と表示を分離（exit code を潰さない）

# L0② エッジ貫通検出（exit 1 = 貫通あり）
node .claude/skills/company-diagram-v2/references/drawio/review-drawio.js \
  docs/diagrams/{filename}.drawio > /tmp/l0_review.txt 2>&1
R_EXIT=$?
cat /tmp/l0_review.txt
```

| チェック | 合格条件 | fail 時 |
|---|---|---|
| 先行ファイル/7セクション | FAIL=0 | Phase 3 を補完して 1回リトライ |
| L0① validate_drawio.py | `V_EXIT=0`（PASSED / INFO・warning のみ） | **無効シェイプ名等を修正**して 1回リトライ |
| L0② review-drawio.js | `R_EXIT=0`（貫通なし） | waypoint 追加・ノード再配置で 1回リトライ |

- `defusedxml` は環境に入れず `uv run --with defusedxml` で隔離実行する
- **致命判定**: 1回リトライ後も fail なら中断して report（L2 の s6 にも結果を反映）
- 検証パスはランタイムでは `.claude/skills/company-diagram-v2/references/drawio/...`（plugins ではない）

---

## 8. Phase 5: L1 セルフ構造ゲート

| チェック項目 | 方法 |
|---|---|
| HTML 7セクション全存在・順序 | grep で `<h2>凡例</h2>`→`概要`→`データフロー`→`レイヤー構成`→`設計のポイント`→`コスト概算`→`学習ポイント` の順 |
| コスト概算テーブル | grep で `Dev (月額)` と `Prod (月額)` および `合計` 行の存在 |
| 為替換算（JPY）記載 | grep で `円` を含むコストセル（USD単独記載は不可） |
| 学習ポイントリスト | grep で `class="learning-points"` と 3 件以上の `<li>` |
| index.html カード追記 | grep で `{filename}.html` リンク存在 |
| 件数更新 | `<p class="count">` の右側数字が +1 |
| .drawio / YAML / iac.html 存在 | ls チェック |
| サムネ参照整合 | CLI export 時は `{filename}.png`、fallback 時は iframe カードであることを確認 |

fail → 1回自動修正 → 再チェック → それでも fail なら中断。

---

## 9. Phase 6: L2 独立レビュー（.drawio XML Read）

**fresh `general-purpose` agent** を起動し、`.drawio` XML を Read ツールで読み込ませて評価する
（PNG画像 Read は廃止＝XML Read に置換）。

### 起動方法

```
Agent(
  description: "AWS diagram v2 L2 review",
  subagent_type: "general-purpose",
  prompt: <references/review-prompt.md の内容 + 以下の情報>
    - 詳細HTMLパス（必ず Read）
    - .drawio XMLパス（必ず Read）
    - IaC YAMLパス（必ず Read）
    - IaCビューアHTMLパス
    - 一覧 index.html パス
    - Phase 4 の L0① validate_drawio.py 結果（exit + ログ）
    - Phase 4 の L0② review-drawio.js 結果（exit + ログ）
)
```

### 採点 6軸（詳細は `references/review-prompt.md`）

| # | 軸 | 致命 |
|---|---|---|
| s1 | **構造準拠（HTML 7セクション・順序）** — 1つでも欠落/順序違反で critical_triggered | ★ |
| s2 | **IaC生成**（{filename}.yaml + {filename}-iac.html 存在・整合） | ★ |
| s3 | XML-HTML 整合性（.drawio の value ノード ↔ HTML レイヤー構成表） | - |
| s4 | 凡例完全性（.drawio の edge strokeColor 集合 ↔ 凡例行） | - |
| s5 | 一覧ページ更新（カード + 件数） | - |
| s6 | **drawio品質**（エッジ貫通 + AWS4シェイプ名妥当性 + HTML禁則） | ★ |

**判定**: 致命軸 (s1, s2, s6) が `< 0.5` → composite 強制 0.00, fail。
それ以外は等重み平均 `≥ 0.85` で pass。
fail → 1回自動修正 → 再レビュー → それでも fail なら **Phase 7 を中止**。

---

## 10. Phase 7: PR作成（v2 は auto-merge しない）

```bash
git add docs/diagrams/ .companies/{org-slug}/.task-log/
git commit -m "feat: AWS構成図v2(drawio) {name} を追加 [{org-slug}] by {operator}"
git push origin {branch}
gh pr create --title "feat: AWS構成図v2(drawio) {name} [{org-slug}]" --body "$(PR本文)"
# v2 は新スキルのため初回は人手レビュー推奨 → auto-merge しない
```

**重要**: v2 は新スキルのため、現行 /company-diagram と異なり `gh pr merge --auto` を**実行しない**。
PR を作成し人手レビューに委ねる（`.drawio` を必ず add 対象に含める）。PR 本文には L0①/L0②/L1/L2 全スコアと
致命軸判定、draw.io 図 URL を埋め込む。安定後に auto-merge 化を別途検討する。

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
subagents: [general-purpose-reviewer]
l0_gate: pass
l0_retries: {0|1}
l1_gate: pass
l1_retries: {0|1}
l2_composite: 0.00
l2_retries: {0|1}
l2_scores:
  s1_structure: 0.00
  s2_iac: 0.00
  s3_xml_html_consistency: 0.00
  s4_legend: 0.00
  s5_index_update: 0.00
  s6_drawio_quality: 0.00
---
```

### `## judge` セクション追記（dashboard 統合のため必須）

6 軸 → 3 軸マッピング:
- `completeness` = `(s1_structure + s5_index_update) / 2`
- `accuracy` = `(s2_iac + s3_xml_html_consistency) / 2`
- `clarity` = `(s4_legend + s6_drawio_quality) / 2`
- `total` = `l2_composite`

```markdown
## judge

\`\`\`yaml
completeness: {0.00}
accuracy: {0.00}
clarity: {0.00}
total: {l2_composite}
failure_reason: ""
judge_comment: "/company-diagram-v2 l2_scores から自動マッピング: completeness=avg(s1_structure,s5_index_update), accuracy=avg(s2_iac,s3_xml_html_consistency), clarity=avg(s4_legend,s6_drawio_quality)"
judged_at: "{ISO8601 with TZ}"
\`\`\`
```

### Issue 作成

```bash
gh issue create \
  --title "[{org-slug}] AWS構成図v2(drawio) {name}" \
  --label "org:{org-slug},mode:direct,type:diagram,dept:secretary" \
  --body "$(Issue本文)"
```

### 最終報告フォーマット

```
AWS構成図v2(drawio) {name} の PR を作成しました（人手レビュー待ち）。

L0① XML/シェイプ検証: PASS（retry {0|1}）
L0② エッジ貫通検出:   PASS（retry {0|1}）
L1構造ゲート:        PASS（retry {0|1}）
L2独立レビュー:      composite {score}（retry {0|1}）

PR:     {pr_url} (auto-merge せず人手レビュー推奨)
Issue:  {issue_url}
図URL:  https://sas-sasao.github.io/cc-sier-organization/diagrams/{filename}.html
```

---

## 12. オプションフラグ

| フラグ | 既定 | 効果 |
|---|---|---|
| `--force` | off | 同名ファイル既存時に上書き |
| `--no-merge` | （v2 は既定で merge しない） | 影響なし（v2 はそもそも auto-merge しない） |
| `--dry-run` | off | Phase 6 まで実行、Phase 7 以降スキップ |
| `--yes` | off | Phase 0 ヒアリングをスキップしデフォルト値で進行 |

---

## 13. エラー時の中断ポリシー

- 各 Phase で fail → task-log を `status: blocked` で保存
- ユーザーへの報告に Phase 名・原因・手動復旧コマンドを含める
- 部分作成済みのブランチ / PR は削除しない（手動引き継ぎ用）

---

## 14. 注意事項（CLAUDE.md 由来の制約）

- **現行 `/company-diagram`（PNG/MCP方式）を変更・削除しない**（pristine 維持＝ロールバック安全）
- ラベル: draw.io は**日本語ラベル可**だが **シェイプ名（resIcon）は英語の正式名必須**（無効名は L0① ERROR）
- 必須7セクションは**固定順序**: 凡例 → 概要 → データフロー → レイヤー構成 → 設計のポイント → コスト概算 → 学習ポイント。**順序違反も欠落と同じく `critical_triggered=true`**（数値均し込み禁止）
- L0 で `| tail` 等のパイプにより exit code を潰さない（`set -o pipefail` か実行/表示分離）
- `defusedxml` は環境導入せず `uv run --with defusedxml` 隔離実行
- `plugins/cc-sier/skills/company-diagram-v2/` を編集したら **`.claude/skills/company-diagram-v2/` へ必ず同期**し `diff -rq` で一致確認
- MD リンクタイトルの半角 `[...]` は全角 `【...】` に置換（HTML 変換時のリンク消失防止）
- `mxGraphModel` に `background` 属性を付けない（dark mode 破壊・L0① ERROR）

---

## 15. 参照ファイル

| ファイル | 用途 |
|---|---|
| `references/review-prompt.md` | L2 独立レビュアー採点プロンプト（drawio版6軸、JSON出力、XML Read指示） |
| `references/aws-cost-estimation.md` | コスト概算セクション生成用（クイックリファレンス、為替、HTMLフォーマット） |
| `references/aws-service-defaults.md` | AWS サービス既定値（IaC/コスト補助） |
| `references/generate-iac-viewer.py` | `{filename}-iac.html`（YAML埋め込みビューア）生成スクリプト |
| `references/drawio/xml-rules.md` | mxCell 書式・edge ラベル・コンテナ規約（生成の正本） |
| `references/drawio/style-guide.md` | スタイル文字列・カテゴリ色・タイトル/凡例規約 |
| `references/drawio/xml-templates-structure.md` | mxfile ラッパー・タイトル・Users・凡例の XML 骨格 |
| `references/drawio/layout-guidelines.md` | 間隔・エッジ貫通回避・複雑図スケーリング |
| `references/drawio/aws4-shapes-services.md` / `aws4-shapes-resources.md` | 正式シェイプ名（これ以外は L0① ERROR） |
| `references/drawio/diagram-templates-{basic,advanced}.md` / `group-styles.md` / `general-icons.md` | 図種別テンプレ・グループ/汎用アイコン |
| `references/drawio/samples/*.drawio` | few-shot 用参考図 |
| `references/drawio/scripts/validate_drawio.py` | L0① XML構造 + AWS4 シェイプ allowlist 検証 |
| `references/drawio/review-drawio.js` | L0② エッジ貫通検出 |
| `references/drawio/cli-export.md` | サムネイル PNG export 手順（CLI） |
| `references/drawio/scripts/post_process_drawio.py` ほか `fix_*.py` | （任意）エッジ・レイアウト自動補正 |
| `.claude/skills/company/references/task-log-template.md` | task-log / Issue の共通スキーマ |
