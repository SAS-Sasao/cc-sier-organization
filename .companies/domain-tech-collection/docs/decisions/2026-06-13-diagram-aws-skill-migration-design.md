# `/company-diagram` AWS skill 方式移行 確定設計書

| 項目 | 内容 |
|---|---|
| 設計ID | 2026-06-13-diagram-aws-skill-migration-design |
| 対象 Issue | #569（方針B: deploy-on-aws `aws-architecture-diagram` skill 方式へ移行） |
| ブランチ | `feat/2026-06-13-diagram-aws-skill-migration` |
| 設計責任者 | system-architect（team-lead 直下） |
| Wave1 入力 | tech-researcher / qa-lead / cloud-engineer の各成果 |
| ステータス | 確定（実装着手は人手承認後） |
| 関連メモリ | `aws-diagram-mcp-deprecation`（A暫定→C中期→B長期の段階移行） |

---

## 1. 意思決定サマリ

### 1.1 背景

`awslabs.aws-diagram-mcp-server`（PNG 生成 MCP、Python `diagrams` ラッパー）が PyPI から yank・公式 deprecated となり、MCP サーバ自身が deploy-on-aws plugin の `aws-architecture-diagram` skill への移行を案内している。現在は短期策（A）として `==1.0.23` をピンして延命中だが、物理 remove リスクがあるため、長期策（B）として **draw.io XML 生成方式（MCP 不使用）** へ移行する。

### 1.2 方針B採用の確定

**方針B（deploy-on-aws の draw.io XML 直接生成方式）を採用する。** PNG ラスタ生成を伴う MCP 依存を断ち、LLM が draw.io XML を直接出力する方式に切り替えることで、PyPI / GraphViz / `uv` への外部依存をゼロにする。cloud-engineer の PoC で `shape=mxgraph.aws4.resourceIcon;resIcon=mxgraph.aws4.*` 書式により AWS4 アイコン・日本語ラベルの利用が追加インストールなしで成立し、`review-drawio.js` の L0 検証も `exit 0/pass` まで到達済みのため、技術的実現性は確認済み。

### 1.3 B-1 vs B-2 の最終決定 → **B-2 を確定採用**

| 観点 | B-1（plugin install）| B-2（cc-sier native skill へ手法移植）|
|---|---|---|
| MCP 汚染 | awsiac/awsknowledge/awspricing の3 MCP を `.mcp.json` に引き込む | なし（既存 `.mcp.json` 不変）|
| 出力先 | deploy-on-aws 既定 `./docs/` と cc-sier `docs/diagrams/` が不一致 | `docs/diagrams/` を完全制御 |
| Phase7（PR/auto-merge）| skill に PR/auto-merge 工程なし → 9フェーズ崩壊 | 既存 9フェーズの Phase7/8 を温存 |
| L2 統合 | deploy-on-aws の検証は PostToolUse hook 方式で L2（fresh general-purpose）統合不可 | 既存 L2 review-prompt を温存・改修 |
| 出力パス / 3層レビュー / IaC / task-log | cc-sier 規約外で制御不能 | すべて cc-sier 内で制御可 |
| L0 二段構え | 組めない | `review-drawio.js`（エッジ貫通）+ `validate_drawio.py`（シェイプ検証）を直列で組める |

**根拠**: B-1 は deploy-on-aws plugin を丸ごと install するため、(a) 不要な3 MCP がプロジェクト全体の `.mcp.json` を汚染し、(b) 出力先・Phase7（PR/auto-merge）・L2（fresh general-purpose）統合が cc-sier の 9フェーズ + 3層レビュー設計と構造的に噛み合わない。一方 B-2 は deploy-on-aws の**手法（XML 生成規約・シェイプ辞書・検証スクリプト）のみを資産としてコピー移植**し、生成・配置・レビュー・PR・task-log のオーケストレーションは cc-sier 既存 SKILL.md が担う。これにより既存ギャラリー資産（PNG 23 / HTML 47 / index.html）と 9フェーズ + auto-merge をすべて保全できる。deploy-on-aws の対象資産は全て Apache-2.0 でコピー移植可能（tech-researcher 確認済み）。

---

## 2. 移植する資産の確定リスト

deploy-on-aws `skills/aws-architecture-diagram/` から cc-sier `plugins/cc-sier/skills/company-diagram/` 配下へコピーする。**真ソースは `plugins/` 側**で、`.claude/skills/company-diagram/` へ同期する（CLAUDE.md skill-development ルール）。

### 2.1 コピー対象ファイルと配置先

| 移植元（deploy-on-aws）| 配置先（cc-sier）| 用途 | 必須/任意 |
|---|---|---|---|
| `references/xml-rules.md` | `references/drawio/xml-rules.md` | mxfile/mxGraphModel ラッパー・mxCell 書式規約 | 必須 |
| `references/style-guide.md` | `references/drawio/style-guide.md` | スタイル文字列規約 | 必須 |
| `references/layout-guidelines.md` | `references/drawio/layout-guidelines.md` | レイアウト（横ゾーン・水平エッジ）方針 | 必須 |
| `references/aws4-shapes-services.md` | `references/drawio/aws4-shapes-services.md` | サービスアイコン shape 名 | 必須 |
| `references/aws4-shapes-resources.md` | `references/drawio/aws4-shapes-resources.md` | リソースアイコン shape 名 | 必須 |
| `aws4-shapes.json`（1077 シェイプ辞書）| `references/drawio/aws4-shapes.json` | L0 allowlist 照合の根拠 | 必須 |
| `references/xml-templates-*.md` | `references/drawio/xml-templates-*.md` | XML テンプレート断片 | 必須 |
| `references/group-styles.md` | `references/drawio/group-styles.md` | グループ/コンテナスタイル | 推奨 |
| `references/general-icons.md` | `references/drawio/general-icons.md` | 非AWS汎用アイコン | 推奨 |
| `references/diagram-templates-*.md` | `references/drawio/diagram-templates-*.md` | 図種別テンプレート | 推奨 |
| `scripts/lib/validate_drawio.py`（defusedxml）| `references/drawio/scripts/validate_drawio.py` | L0 シェイプ/XML 構造検証 | 必須 |
| `scripts/lib/post_process_drawio.py`（5段フィクサー）| `references/drawio/scripts/post_process_drawio.py` | エッジ・レイアウト自動補正 | 推奨 |
| `scripts/lib/fix_*.py` | `references/drawio/scripts/fix_*.py` | 個別フィクサー | 推奨 |
| `scripts/lib/drawio_url.py` | `references/drawio/scripts/drawio_url.py` | エディタ URL 生成 | 任意 |
| `references/cli-export.md` | `references/drawio/cli-export.md` | draw.io CLI による PNG export 手順 | 必須（サムネイル方針に直結）|
| `references/post-processing.md` | `references/drawio/post-processing.md` | 後処理パイプライン説明 | 推奨 |
| サンプル `.drawio` ×7 | `references/drawio/samples/*.drawio` | few-shot 用参考 | 任意 |

**注**: `references/drawio/` というサブディレクトリ配下にまとめ、cc-sier 固有の `review-prompt.md` / `aws-cost-estimation.md` と名前空間を分離する。`xml-templates-*.md` / `diagram-templates-*.md` の `*` 部分は実ファイル名が Wave1 サマリに列挙されていないため、**コピー時に実ディレクトリを `ls` して全件取りこぼしなく移植する（要検証＝実ファイル名）**。

### 2.2 `scripts/lib/*.py` の依存

`validate_drawio.py` は `defusedxml` を import する（tech-researcher 確認済み）。実行環境に `defusedxml` が必要なため、**(要検証)** ローカル Python に `defusedxml` が導入済みか、`uv run --with defusedxml` 等で隔離実行するかを実装時に確認する。`post_process_drawio.py` は標準ライブラリ範囲か追加依存があるか **要検証**。

### 2.3 Apache-2.0 帰属対応の具体手順

deploy-on-aws は Apache-2.0。コピー移植時の帰属充足は以下を実施する。

1. **各コピーファイル先頭に著作権表示を付記**（Markdown はファイル冒頭の HTML コメント、Python はモジュール docstring 直前のコメント、JSON は移植元を記録した別添 README）:
   ```
   # Adapted from awslabs/agent-plugins (deploy-on-aws / aws-architecture-diagram skill)
   # Original work Copyright Amazon.com, Inc. or its affiliates. Licensed under the Apache License 2.0.
   # Modifications Copyright cc-sier-organization contributors, 2026.
   ```
   - JSON（`aws4-shapes.json`）はコメント不可のため、同ディレクトリに `references/drawio/THIRD-PARTY-NOTICES.md` を置き、JSON とサンプル `.drawio` の帰属をそこに記載する。
2. **LICENSE 同梱**: Apache-2.0 全文を `plugins/cc-sier/skills/company-diagram/references/drawio/LICENSE-APACHE-2.0.txt` に配置。
3. **NOTICE 配置**: `references/drawio/NOTICE` に「本ディレクトリ配下の XML 規約・シェイプ辞書・検証スクリプトは awslabs/agent-plugins (deploy-on-aws) から派生」「上流リポジトリ URL」「改変点の概要（cc-sier 9フェーズ統合のためのパス・ラッパー調整）」を記載。
4. **リポジトリルートの帰属集約（推奨）**: 既存の `THIRD-PARTY-NOTICES` 系ファイルがある場合はそこにも 1 行追記する（**要検証＝ルート集約ファイルの有無**）。

> 帰属の最小充足は「LICENSE 同梱 + 各ファイルヘッダ + NOTICE」。tech-researcher の「各ファイル先頭に著作権表示付記 + LICENSE 同梱で帰属充足」の見解に沿う。

---

## 3. 新 9フェーズ定義（現行との差分）

フェーズ番号・中断ポリシー・auto-merge は現行を踏襲する。**Phase 2（生成）/ Phase 3（配置）/ Phase 4（L0）/ Phase 6（L2）が変更点**。

| Phase | 現行（MCP/PNG）| 新（draw.io XML）| 差分規模 |
|---|---|---|---|
| 0 ヒアリング | Q3 図名 + ラベル英語注意 | **ラベルは日本語可**（注意文を削除）。IaC ヒアリングを追加（下記 4.C）| 小 |
| 1 前処理 | branch/task-log。subagents: `[mcp-aws-diagram-server, ...]` | subagents を `[general-purpose-reviewer]` 等に更新（MCP サブエージェント表記を削除）| 小 |
| 2 生成 | `list_icons → get_diagram_examples → generate_diagram`（MCP, PNG出力）| **LLM が draw.io XML を直接生成**。`references/drawio/` の xml-rules / style-guide / layout-guidelines / aws4-shapes-*/ samples を参照。`mxfile` ラッパー書式を統一。横ゾーン水平エッジをプロンプト化し初回貫通率を下げる | 大 |
| 3 配置 | PNG + HTML(7セクション) + index + YAML + iac.html | **`.drawio` + HTML(7セクション) + index + YAML + iac.html + PNG（サムネイル, 下記 4.A）**。HTML ビューア部に `.drawio` 埋め込み（iframe）を採用 | 大 |
| 4 L0 | IaC存在 + Python日本語ラベル検出 | **二段直列**: ① `review-drawio.js`（エッジ貫通, パス引数を `docs/diagrams/{name}.drawio` に変更するのみ）② `validate_drawio.py`（XML構造 + AWS4 シェイプ allowlist 照合）+ IaC/drawio 存在チェック + 7セクション grep 先行。英語ラベル検出は**廃止** | 大 |
| 5 L1 | HTML 7セクション + index 整合 | 7セクション grep は維持。サムネイル参照先を `.png`（CLI export）または iframe fallback に応じて調整 | 中 |
| 6 L2 | fresh general-purpose + **PNG を Read** | fresh general-purpose + **`.drawio` XML を Read**。新6軸（下記 §3.2）。judge3軸マッピングのキー変更 | 大 |
| 7 PR & auto-merge | `gh pr merge --auto --squash --delete-branch` | 不変（add 対象に `.drawio` を追加）| 小 |
| 8 task-log & Issue | judge セクション・Issue 作成 | judge マッピングのキー名のみ更新 | 小 |

### 3.1 Phase 4 L0 の二段直列（確定）

```
# 先行: 必須ファイル・7セクション存在
[ -f docs/diagrams/{name}.drawio ] || FAIL=1
[ -f docs/diagrams/{name}.yaml ]   || FAIL=1
[ -f docs/diagrams/{name}-iac.html ] || FAIL=1
grep -q '<h2>凡例</h2>' ... （7セクション grep 先行）

# ① エッジ貫通（既存 review-drawio.js を流用、パスのみ変更）
node .claude/skills/company-diagram/references/drawio/review-drawio.js docs/diagrams/{name}.drawio

# ② XML構造 + AWS4 シェイプ allowlist 照合
python3 .claude/skills/company-diagram/references/drawio/scripts/validate_drawio.py docs/diagrams/{name}.drawio
#   - allowlist 不一致は WARN（fail にしない＝qa-lead 設計に準拠）
```

> `review-drawio.js` は純粋な XML パーサで出力先ディレクトリに依存しない（コード確認済み）。`company-drawio` から `company-diagram` 配下へ**コピー配置**し、両 Skill が独立に持つ（同期破綻を避ける）。

### 3.2 Phase 6 L2 新6軸（qa-lead 設計を確定採用）

| # | 軸 | 致命 | 旧からの変化 |
|---|---|---|---|
| s1 | 構造準拠（HTML 7セクション・順序）| ★（不変・継続）| 変化なし |
| s2 | IaC 生成 | ★（不変）| 変化なし |
| s3 | XML-HTML 整合性 | 非致命 | `s3_png_consistency` → `s3_xml_html_consistency`。PNG Read → **XML Read** に置換 |
| s4 | 凡例完全性 | 非致命 | 画像照合 → **XML 属性（edge strokeColor）照合** |
| s5 | index 更新 | 非致命 | カードテンプレ変更に追従 |
| s6 | drawio 品質（エッジ貫通 + AWS4 シェイプ名 + HTML 禁則）| ★（新設）| 旧 `s6_english_labels` を**廃止**（draw.io は日本語ラベル可）。`s6_drawio_quality` に置換 |

judge 3軸マッピング（task-log `## judge`）:
- `completeness = (s1_structure + s5_index_update) / 2`
- `accuracy = (s2_iac + s3_xml_html_consistency) / 2`
- `clarity = (s4_legend + s6_drawio_quality) / 2`
- `total = l2_composite`

---

## 4. 未決事項 A〜E の決着（各々推奨を1つ確定）

### A. PNG サムネイル方針 → **draw.io CLI export を正路、不可時はアイコンカード fallback**

- **確定**: Phase 3 で draw.io CLI（`references/drawio/cli-export.md` 手順）により `.drawio` → `.png` を export し、既存 index.html の `card-thumb`（`<img src="./{name}.png">`）をそのまま使う。CLI が環境に無い／export 失敗時は、`/company-drawio` 方式の **iframe 埋め込み + アイコンカード fallback**（PNG なしでカード成立）に切り替える。
- 根拠: 既存 index.html は `card-thumb` img を前提とした 23 件のカード資産があり、サムネイル無しは見栄えの後退になる。CLI export なら既存カードテンプレを温存できる。
- **要検証**: draw.io CLI（`drawio` / `@drawio/export` 等）が CI/ローカルに導入可能か、ヘッドレス Chromium 依存の有無を実装時に実機確認。fallback ルートは確実に動くため、CLI が無くてもブロッカーにはならない。

### B. draw.io MCP 実機確認の要否 → **不要（MCP を使わないため）**

- **確定**: 本移行は **MCP 不使用**（LLM が XML を直接生成）が前提のため、「draw.io MCP 出力 XML が review-drawio.js 期待形式か」の実機確認は**移行スコープ外＝不要**。代わりに検証すべきは「**LLM 直接生成 XML（PoC 形式）が review-drawio.js / validate_drawio.py を通るか**」で、これは cloud-engineer の PoC（`exit 0/pass`）で既に成立済み。
- 補足: `/company-drawio`（こちらは draw.io MCP を継続使用）には影響しない。両 Skill の review-drawio.js は別コピーとして独立保持する。

### C. IaC 生成元 → **当面ヒアリング → LLM 直接生成（CFn YAML）、後続で XML 属性抽出**

- **確定**: Phase 0 で対象リソース/環境（Dev/Prod）をヒアリングし、Phase 3 で LLM が CloudFormation YAML を直接生成する。`aws-iac` MCP（`validate_cloudformation_template` / cfn-lint）は**生成後の検証**に任意で使う（生成元ではない）。
- 後続改善: `.drawio` の `mxCell value` / `resIcon` 属性からリソースを機械抽出して IaC 雛形を半自動生成する経路を別 Issue で検討（本移行スコープ外）。
- 根拠: s2（IaC）は致命軸であり PNG 移行の影響を受けない（メモリ既述）。当面は確実な LLM 直接生成で s2 を担保し、自動抽出は段階導入する。

### D. Edge strokeColor 明示ルール化 → **ルール化して確定（凡例＝strokeColor の単一ソース化）**

- **確定**: すべての `edge` mxCell に `strokeColor=#RRGGBB` を**必須明示**とする（PoC でも全エッジに明示済み）。凡例（s4）の各行は、図中に実在する strokeColor 集合と 1:1 対応させる。これにより s4 の照合が「画像目視」から「XML 属性集合 vs 凡例行集合の機械比較」に置換でき、L2 の客観性が上がる。
- 規約は `references/drawio/style-guide.md`（移植）に追記し、xml-rules にも「strokeColor 省略禁止」を明記する。

### E. s1 致命軸 → **不変・継続（致命軸維持）**

- **確定**: s1（HTML 7セクション構造準拠）は致命軸を**継続**。必須セクション欠落・順序違反は `critical_triggered = true` を強制（review-pattern.md の均し込み禁止原則）。draw.io 移行でも 7セクション（凡例/概要/データフロー/レイヤー構成/設計のポイント/コスト概算/学習ポイント）は不変。

---

## 5. 変更ファイル一覧（実装フェーズ用）

| ファイル | 規模 | 変更内容 | plugins↔.claude 同期 |
|---|---|---|---|
| `plugins/cc-sier/skills/company-diagram/SKILL.md` | 大 | Phase 2/3/4/5/6 全面改稿。MCP 記述削除、XML 直接生成・二段 L0・新6軸・サムネ方針・IaC ヒアリングを反映 | **必須**（cp 後 diff 確認）|
| `plugins/cc-sier/skills/company-diagram/references/review-prompt.md` | 大 | s3→s3_xml_html_consistency / s6→s6_drawio_quality に改稿。PNG Read 指示 → XML Read 指示。英語ラベル軸を削除、drawio 品質（貫通/AWS4 シェイプ/HTML 禁則）を新設 | **必須** |
| `.../references/drawio/`（新規ディレクトリ一式）| 大 | §2.1 の移植資産（xml-rules / style-guide / layout / aws4-shapes-*/ aws4-shapes.json / templates / scripts / cli-export / samples）+ LICENSE / NOTICE / THIRD-PARTY-NOTICES | **必須** |
| `.../references/drawio/review-drawio.js` | 中 | `company-drawio` からコピー配置（内容無改変、独立保持）| **必須** |
| `plugins/cc-sier/skills/company-diagram/references/aws-cost-estimation.md` | 小 | 変更なし（流用）。SKILL.md 参照表に残す | 不要 |
| `.companies/domain-tech-collection/masters/mcp-services.md` | 中 | 「引き続き aws-diagram-mcp-server を推奨」を「draw.io XML 直接生成方式（MCP 不要）へ移行済み」に更新 | 不要（組織マスタ）|
| `docs/guide/11-diagram-generation.md` | 中 | MCP 前提の手順記述を XML 生成方式へ更新 | 不要 |
| `CLAUDE.md`（ルート）技術スタック表 | 小 | 「GraphViz（aws-diagram 用）」「aws-diagram MCP」の記述を更新（draw.io XML / 不要化）。`/company-diagram` の概要行（「AWS 構成図生成 + ... 9フェーズ」）の表現確認 | 該当なし |
| `.mcp.json` | 小 | `awslabs.aws-diagram-mcp-server==1.0.23` エントリ削除可（移行完了後）。**要検証＝他 Skill が参照していないこと**（grep 確認） | 該当なし |
| `docs/diagrams/index.html` | 小〜中 | サムネ方針 A の fallback 採用時のみカードテンプレ調整（CLI export なら無改修）| 該当なし |

### 5.1 SKILL.md 取りこぼし防止プロセス（<h2> grep）の適用箇所

skill-development.md の取りこぼし防止プロセスを**以下に必ず適用**する:

1. **Step 0（最重要）**: 既存 `docs/diagrams/*.html`（`-iac.html` / `index.html` を除く）に対し
   ```bash
   for f in docs/diagrams/*.html; do
     [[ "$f" == *-iac.html || "$f" == *index.html ]] && continue
     echo "=== $(basename $f) ==="; grep -o "<h2>[^<]*</h2>" "$f"
   done
   ```
   を実行し、**6/10 以上の HTML に共通する見出し = 実質必須セクション**を抽出。新 SKILL.md の 7セクションと照合（凡例/概要/データフロー/レイヤー構成/設計のポイント/コスト概算/学習ポイントの取りこぼしゼロを確認）。
2. **Step 1**: 旧 SKILL.md の `references/` 参照を grep 抽出し、`aws-cost-estimation.md` 参照が新 SKILL.md に残っているか確認（過去 PR #251→#253→#254 で同種の取りこぼし発生）。
3. **Step 2**: 新 `references/drawio/` の orphan 検出（SKILL.md から参照されない移植ファイルの洗い出し）。
4. **Step 3**: SKILL.md の必須セクション/軸変更を **必ず** `review-prompt.md` の採点基準（s3/s6 のキーと致命判定）に同時反映。片側だけの更新を禁止。
5. **Step 4**: 初回実運用前に `--dry-run`（Phase 6 まで）で既存成果物と diff を取り、7セクション・IaC・サムネの整合を確認。

---

## 6. 受け入れ基準（AC）

qa-lead の AC を統合。すべて満たして初めて移行完了とする。

- **AC-1（生成）**: MCP を一切呼ばず、LLM 直接生成の `.drawio` が `docs/diagrams/{name}.drawio` に出力される。AWS4 シェイプ（`resIcon=mxgraph.aws4.*`）と日本語ラベルが利用できる。
- **AC-2（L0 二段）**: `review-drawio.js` が `exit 0`（貫通なし）かつ `validate_drawio.py` が XML 構造 OK。AWS4 シェイプ allowlist 不一致は WARN として出るが fail にしない。
- **AC-3（L1）**: HTML 7セクションが順序通り全存在（grep）。コスト概算（Dev/Prod・USD+JPY・合計行）と学習ポイント（`learning-points`・3件以上）が存在。index.html カード追記 + 件数 +1。
- **AC-4（L2）**: fresh general-purpose が `.drawio` XML を Read して新6軸採点。`composite ≥ 0.85` かつ `critical_triggered = false` で pass。s1/s2/s6 のいずれかが `< 0.5` で composite 強制 0・fail。
- **AC-5（IaC）**: `{name}.yaml`（CFn）と `{name}-iac.html` が存在し、図のリソースと整合（s2 致命軸）。
- **AC-6（凡例＝strokeColor 単一ソース）**: 図中の全 edge `strokeColor` が凡例行と 1:1 対応（s4）。
- **AC-7（PR/auto-merge）**: Phase 7 で PR 作成 → `gh pr merge --auto --squash --delete-branch` が成立。`.drawio` が add 対象に含まれる。
- **AC-8（task-log）**: YAML フロントマターに l0/l1/l2 と新 6軸キーを記録。`## judge` 3軸マッピングが新キーで正しく計算される。
- **AC-9（既存資産保全）**: 既存 PNG 23 / HTML 47 / index.html のカード・検索・フィルタ JS を破壊しない（件数表示の右側数字のみ更新）。
- **AC-10（帰属）**: Apache-2.0 LICENSE 同梱・各移植ファイルヘッダ・NOTICE/THIRD-PARTY-NOTICES が配置されている。
- **AC-11（同期）**: `plugins/` → `.claude/skills/company-diagram/` の `diff -rq` が一致。

---

## 7. リスクと緩和策

| # | リスク | 影響 | 緩和策 |
|---|---|---|---|
| R1 | 複雑図でエッジ貫通リトライが増え、L0 で詰まる | 生成失敗率↑ | layout-guidelines（横ゾーン水平エッジ）をプロンプト化。strokeColor/exitX-Y 明示。PoC 形式を few-shot で同梱（cloud-engineer 知見）|
| R2 | draw.io CLI export が環境に無く PNG サムネ不可 | カード見栄え後退 | fallback（iframe + アイコンカード）を確実ルートとして実装（4.A）。CLI はベストエフォート |
| R3 | `validate_drawio.py` の `defusedxml` 依存が未導入 | L0 ② が動かない | `uv run --with defusedxml` 等の隔離実行、または依存を事前導入（要検証）|
| R4 | SKILL.md 全面改稿で必須セクション/軸を取りこぼす | L2 がすり抜け | §5.1 の <h2> grep プロセスを必須適用。SKILL.md と review-prompt.md を同時更新（過去 #251→#254 の再発防止）|
| R5 | `.mcp.json` から MCP 削除時に他 Skill が壊れる | 既存機能停止 | 削除前に `awslabs.aws-diagram-mcp-server` の参照を全 Skill で grep 確認。移行完了確認まで削除しない（A暫定ピンを維持）|
| R6 | IaC を図から自動抽出しないため図と YAML がドリフト | s2 整合性低下 | 当面は LLM が図・YAML を同時生成し整合を担保。cfn-lint（aws-iac MCP）で構文検証 |
| R7 | 移植資産の実ファイル名（`xml-templates-*` 等）を取りこぼす | 規約欠落で生成品質低下 | コピー時に上流ディレクトリを `ls` 全件突合（要検証＝実ファイル名）|
| R8 | 既存 index.html のサブタイトル「AWS Diagram MCP Server で生成」が実態と乖離 | 表示の正確性 | サブタイトル文言を「draw.io XML で生成」に更新（小改修）|

---

## 8. 実装着手順序（推奨ステップ）

各ステップ末で人手承認を取る単位に分割する。Step ごとに独立 PR を推奨（取りこぼし検出を段階化）。

- **Step 0（承認待ち＝本設計書）**: 本設計の確定承認。B-2・未決 A〜E の決着・帰属手順を team-lead/オーナーが是認。
- **Step 1（資産移植 + 帰属）**: §2 の deploy-on-aws 資産を `references/drawio/` へコピー、LICENSE/NOTICE/ヘッダ付記、`review-drawio.js` コピー配置。**生成ロジックは未変更**（既存 MCP フローは温存）。→ 単独 PR。
- **Step 2（L0 検証スクリプト疎通）**: `validate_drawio.py` を PoC `.drawio` に対して実行し、`defusedxml` 依存解消・allowlist 照合（WARN）動作を確認。`review-drawio.js` の `docs/diagrams/` パスでの疎通確認。→ 検証ログを Issue に記録。
- **Step 3（SKILL.md / review-prompt.md 改稿）**: §5.1 の <h2> grep プロセスを実施してから Phase 2/3/4/6 を改稿。SKILL.md と review-prompt.md を同一 PR で同時更新。plugins→.claude 同期 + `diff -rq`。
- **Step 4（ドライ実行）**: `--dry-run` で 1 図を Phase 6 まで生成し、AC-1〜AC-6・AC-9 を確認。既存成果物と diff レビュー。
- **Step 5（本実運用 + 周辺更新）**: 実図を 1 件 auto-merge まで完走（AC-7/8/10/11）。あわせて mcp-services.md / guide / CLAUDE.md / index.html サブタイトルを更新。
- **Step 6（MCP 退役）**: 全 Skill が新方式で安定後、`.mcp.json` から `awslabs.aws-diagram-mcp-server` を削除（R5 の grep 確認後）。A暫定ピンを撤去。

---

## 付録: 要検証事項一覧（Wave1 サマリに事実が無く確定できない点）

1. `xml-templates-*.md` / `diagram-templates-*.md` の実ファイル名（コピー時に上流 `ls` で全件突合）。
2. `validate_drawio.py` の `defusedxml` 導入方法、`post_process_drawio.py` の追加依存有無。
3. draw.io CLI（PNG export）の環境導入可否・ヘッドレス Chromium 依存。
4. `.mcp.json` の `aws-diagram-mcp-server` を他 Skill が参照していないか（削除前 grep）。
5. リポジトリルートに帰属集約ファイル（THIRD-PARTY-NOTICES 等）が既存か。
6. LLM 直接生成 XML が `review-drawio.js` 期待形式に合致するか（PoC で成立済みだが、複雑図での再現性は Step 4 で確認）。
