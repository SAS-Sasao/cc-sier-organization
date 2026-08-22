# GitHub Pages デザイン刷新 移植計画

| 項目 | 内容 |
|------|------|
| ドキュメント種別 | 移植計画書 |
| 作成日 | 2026-08-22 |
| 作成者 | 技術リサーチ室（秘書室主導） |
| 依頼 | 「明日からデザインの移植（実態のページに合わせて）を行いたい。計画書いて」 |
| 移植元 | Claude Design プロジェクト **CC-SIER組織ポータル刷新案**（`Portal.dc.html`、62,567 字） |
| 参照 DS | **Organic**（`9ccf8d1e-067c-4ccb-bc4a-0a6417c90f23`、type: `PROJECT_TYPE_DESIGN_SYSTEM`） |
| ステータス | **計画のみ。実装は未着手** |

---

## 0. 3 行で

- 移植元は **React で動く 6 画面のプロトタイプ**。**そのままでは GitHub Pages で描画されない**。
- 現行ページは **8 本すべてがスクリプト生成物**。手で HTML を置いても**次の生成で消える**。
- したがって移植とは「HTML を差し替える」ことではなく、**`styles.css` を持ち込み、生成器のテンプレートを書き換える**作業になる。
- **さらに Skill 側（SKILL.md 9 本 + L2 採点プロンプト 5 本）も同時に直す必要がある。** 片方だけ直すと L2 が旧仕様で通してしまう。

---

## 1. 現状の実測（2026-08-22）

### 1.1 現行 Pages の全体像

| ページ | サイズ | 生成元 |
|---|---|---|
| `docs/index.html` | 3.7 KB | `generate-dashboard.sh`（**＋3 スクリプトがカードを挿入**） |
| `docs/secretary/{org}/dashboard.html` | 67.3 KB | `generate-dashboard.sh` |
| `docs/daily-digest/index.html` | **5,933 KB** | `generate-daily-digest-html.sh` |
| `docs/handover/index.html` | 567 KB | `generate-handover-html.sh` |
| `docs/insights/index.html` | 31.7 KB | `generate-insights-html.py` |
| `docs/insights/analyses/index.html` | 7.0 KB | `generate-insights-analyses-html.sh` |
| `docs/diagrams/index.html` | 26.9 KB | `/company-diagram` 系 |
| `docs/drawio/index.html` | 19.2 KB | `/company-drawio` |

**手で維持されている HTML は 1 つも無い。**

### 1.2 テーマが正反対

| | 現行 | Organic |
|---|---|---|
| 地色 | `#0b1222`（**ダーク**） | `#f5ead8`（**クリーム / ライト**） |
| アクセント | `#3b82f6`（青） | `#c67139`（テラコッタ） |
| 第 2 アクセント | なし | `#7a8a5e`（セージ） |
| 見出しフォント | system-ui | **Caprasimo** |
| 本文フォント | system-ui | **Figtree** + Zen Maru Gothic |
| 角丸 | 8px | **16px / ボタンは 999px（ピル）** |

**単なる配色変更ではなく、明暗の反転を含む全面刷新**である。

### 1.3 移植元の実体

`Portal.dc.html` は静的 HTML ではない。

| 要素 | 中身 |
|---|---|
| `<x-dc>` | `support.js`（**React ランタイム**、70.6 KB）が解釈するテンプレート |
| `<sc-if>` × 8 | **画面の出し分け**（home / dash / know / digest / dia / ins） |
| `{{ }}` × 42（ユニーク 33） | 大半が**ナビ状態とキーボードヒント**（`goDash` / `isHome` / `kHome` 等）。実データ変数ではない |
| `data-props` | `initialScreen` の enum（home/dash/know/digest/…） |

`support.js` は冒頭で `window.React` / `window.ReactDOM` を要求する。**React を読み込まない限り何も描画されない。**

つまり `Portal.dc.html` は **「1 ファイルに 6 画面を詰めた対話プロトタイプ」**であり、配布物ではない。

---

## 2. 移植方針

### 2.1 採るもの・捨てるもの

| | 扱い | 理由 |
|---|---|---|
| **`styles.css`（Organic の唯一のスタイルシート）** | ✅ **そのまま採る** | DS 側が「全ページからこの 1 枚をリンクせよ」と明言。自己完結しており Pages に置ける |
| **マークアップ構造・クラス**（`.card` `.btn` `.tag` `.nav` `.table`） | ✅ **採る** | DS が「component ページは素の HTML なので view source してコピーせよ」と明記 |
| **画面レイアウト**（274px サイドバー + メイン） | ✅ **採る** | 現行のカード羅列より情報設計が良い |
| **Google Fonts の 3 書体** | ✅ 採る | 外部参照のままで可 |
| `<x-dc>` / `<sc-if>` / `{{ }}` | ❌ **捨てる** | React 前提。生成器（bash / python）と噛み合わない |
| `support.js` / `_ds_bundle.js` | ❌ **捨てる** | 同上 |
| React 本体 | ❌ **持ち込まない** | 現行パイプラインに npm もビルドも無い |

### 2.2 中心となる判断

> **移植先は HTML ファイルではなく、生成器のテンプレートである。**

`docs/index.html` を手で書き換えても、次に `generate-dashboard.sh` が走った時点で消える。実際、**解析レポートのカードが 6 日間毎晩消えていた**事故が 2026-08-22 に発覚したばかりである（`generate-insights-html.py` の正規表現が巻き添え削除していた）。

**同じ轍を踏まないため、この計画では最初から生成器を書き換える。**

### 2.3 画面マッピング

プロトタイプの 6 画面は、実ページにそのまま対応する。

| プロトタイプ画面 | 実ページ | 生成器 |
|---|---|---|
| `home` | `docs/index.html` | `generate-dashboard.sh` |
| `dash` | `docs/secretary/{org}/dashboard.html` | `generate-dashboard.sh` |
| `know` | `docs/handover/index.html` | `generate-handover-html.sh` |
| `digest` | `docs/daily-digest/index.html` | `generate-daily-digest-html.sh` |
| `dia` | `docs/diagrams/` + `docs/drawio/` | `/company-diagram` 系 / `/company-drawio` |
| `ins` | `docs/insights/analyses/` | `generate-insights-analyses-html.sh` |

**プロトタイプの画面切替（`<sc-if>`）は、実世界では「サイドバーのリンク」になる。** React が要らなくなるのはこのためである。

---

## 2.4 ⚠️ 生成器だけ直しても足りない — Skill も対象

`docs/` の HTML は **hooks（生成器）と Skill（指示書）の両方**が形を決めている。**片方だけ直すと必ず事故る。**

### 2.4.1 なぜ Skill も直すのか

`@.claude/rules/skill-development.md` にこう明記されている。

> SKILL.md の必須セクション変更は **必ず** `references/review-prompt.md` の採点基準にも反映する。**片方だけ更新すると L2 レビューが旧仕様で通過してしまう。**

さらに `@CLAUDE.md` は `/company-diagram` の詳細ページについて **必須 7 セクション固定順序**（凡例 → 概要 → データフロー → レイヤー構成 → 設計のポイント → コスト概算 → 学習ポイント）を定め、**順序違反も `critical_triggered = true` 扱い**としている。

**デザインを変えて構造が変われば、この採点基準ごと作り直しになる。**

> 過去の実例: `/company-diagram` の 9 フェーズ化リライトで `aws-cost-estimation.md` 参照と学習ポイント生成を取りこぼし、**PR #251 → #253 → #254 の 3 段階ですり抜け修正**が発生している。

### 2.4.2 対象一覧（実測 2026-08-22）

**SKILL.md に HTML / CSS の規定を含むもの — 9 本**

| Skill | 言及箇所 | 対応するページ |
|---|---|---|
| `company-diagram-v2` | **33** | `docs/diagrams/` |
| `company-drawio` | **32** | `docs/drawio/` |
| `company-diagram` | **31** | `docs/diagrams/` |
| `company-insights-cycle` | 20 | `docs/insights/analyses/` |
| `company-digest-html` | 18 | `docs/daily-digest/` |
| `company-daily-digest` | 13 | `docs/daily-digest/` |
| `company-handover` | 10 | `docs/handover/` |
| `company-dashboard` | 5 | `docs/index.html` / `dashboard.html` |
| `company-cycle` | 4 | （オーケストレータ。参照のみ） |

**L2 採点プロンプトで HTML 構造を採点しているもの — 5 本**

| Skill | 構造言及 | 備考 |
|---|---|---|
| `company-diagram-v2` | **39** | 最も重い |
| `company-diagram` | 24 | 必須 7 セクションを採点 |
| `company-drawio` | 23 | |
| `company-sheet` | 7 | xlsx 側。**HTML 刷新の影響は薄いと推測（未確認）** |
| `company-daily-digest` | 4 | |

**加えて `@CLAUDE.md` 本体**にも必須 7 セクションの規定があり、変更するなら 3 箇所（SKILL.md / review-prompt.md / CLAUDE.md）を揃える必要がある。

### 2.4.3 各ページで「3 点セット」を揃える

**ページを 1 つ直すたびに、次の 3 つを同時に更新する。**

```
① hooks の生成器          … 実際に出る HTML
② SKILL.md               … 何を出すべきかの指示
③ references/review-prompt.md … 出たものをどう採点するか
```

**②③ を放置すると、新デザインの成果物が「旧仕様に合っていない」として L2 に落とされる**か、逆に**旧仕様のまま通ってしまう**。どちらも起きる。

### 2.4.4 同期を忘れない

`plugins/cc-sier/skills/` が **VCS 真ソース**で、`.claude/skills/` は同期先である。

```bash
cp plugins/cc-sier/skills/{name}/SKILL.md .claude/skills/{name}/SKILL.md
cp plugins/cc-sier/skills/{name}/references/*.md .claude/skills/{name}/references/
diff -rq plugins/cc-sier/skills/{name}/ .claude/skills/{name}/
```

> **なお現時点で `plugins/` に存在しない Skill が 3 本ある**（`company-evolve` / `company-quality-setup` / `company-report`、カタログ候補 AE）。**本移植の対象ではない**が、触る場合は先に移送が要る。

---

## 3. 段階計画

**原則: 1 ページずつ。全部いっぺんに変えない。**

理由は 2 つ。①生成器が 6 本あり、壊したときの切り分けが不可能になる ②`docs/index.html` は 4 つの処理が書き込む特殊なファイルで、最後に回すべきである。

### Day 1 — 土台を置く（変更を伴わない）

| # | 作業 | 完了条件（証拠） |
|---|---|---|
| 1-1 | `Organic` から `styles.css` を取得し `docs/assets/organic/styles.css` に配置 | ファイルが存在し、`--color-bg: #f5ead8` を含む |
| 1-2 | `Portal.dc.html` をローカルで**描画して目視**する（React を CDN で読ませた検証用 HTML を `/tmp` に作る） | **スクリーンショットまたは目視で「見えた」と言える状態** |
| 1-3 | 6 画面それぞれのマークアップを抽出し、`<sc-if>` を外した素の HTML 断片として `/tmp` に保存 | 6 ファイルが生成され、`{{` が 0 件 |
| 1-4 | Lucide アイコンの扱いを決める（CDN / インライン SVG / 使わない） | 決定が本計画書に追記されている |

> **Day 1 は `docs/` を一切変更しない。** 土台の確認だけで終える。

### Day 2 — いちばん安全な 1 ページで試す

対象: **`docs/insights/analyses/index.html`**

選定理由: ①生成器が 1 本だけ（`generate-insights-analyses-html.sh`）②他の処理が触らない ③**自分で作った生成器なので構造を把握している** ④壊れても影響が解析レポート閲覧に限定される

| # | 作業 | 完了条件（証拠） |
|---|---|---|
| 2-1 | `generate-insights-analyses-html.sh` の `STYLE` 定数を Organic トークン参照に置き換え | 生成された HTML に `var(--color-` が出現し、生の `#0b1222` が 0 件 |
| 2-2 | 一覧ページを `.card` クラス構成に変更 | `class="card"` が出現 |
| 2-3 | 個別レポートページに `.table` `.tag` を適用 | 生成 10 本すべてでエラーなし |
| 2-4 | **`company-insights-cycle/SKILL.md` の Phase 2 記述を新デザインに合わせる** | SKILL.md に旧構造の記述が残っていない |
| 2-5 | **ブラウザで開いて目視** | ライト/ダーク両方で表示確認（**目視必須**） |
| 2-6 | リンク健全性検査 | 壊れたリンク 0 件 |
| 2-7 | `plugins/` ↔ `.claude/skills/` を同期 | `diff -rq` が差分なし |

> `company-insights-cycle` に **L2 採点プロンプトは無い**（レビュー付き Skill ではない）。**3 点セットのうち ③ が無い最も軽いケース**であり、Day 2 の題材として適している。

### Day 3 — 独立した 2 ページ

対象: `docs/diagrams/` と `docs/drawio/`（互いに独立、他が触らない）

**本移植で最も重い 2 ページ。** Day 2 のような「生成器だけ」では済まない。

| # | 作業 | 完了条件（証拠） |
|---|---|---|
| 3-1 | 生成器（`/company-drawio` の HTML 出力部）を Organic トークンへ | 生の色コード 0 件 |
| 3-2 | **`company-drawio/SKILL.md`**（HTML 言及 **32 箇所**）を更新 | 旧構造の記述が残っていない |
| 3-3 | **`company-drawio/references/review-prompt.md`**（構造言及 **23 箇所**）の採点基準を新構造へ | 新旧の基準が混在していない |
| 3-4 | 同じ 3 点を `company-diagram-v2`（SKILL **33** / review **39**）に適用 | 同上 |
| 3-5 | `company-diagram`（SKILL **31** / review **24**）も同様 | 同上 |
| 3-6 | **`CLAUDE.md` の必須 7 セクション規定**を新構造に合わせるか判断 | 判断が計画書に追記されている |
| 3-7 | **実際に 1 図を生成して L0/L1/L2 を通す** | `l2_composite ≥ 0.85` かつ `critical_triggered: false` |
| 3-8 | `plugins/` ↔ `.claude/skills/` 同期 | `diff -rq` 差分なし |

> **3-7 が本 Day の本体である。** 採点基準を書き換えたら、**実際にレビューを通してみるまで直ったとは言えない**。
>
> **Day 2 で問題が出た場合はここに進まず、Day 2 に戻る。**

### Day 4 — 大物 2 ページ

対象: `docs/daily-digest/index.html`（**5.9 MB**）と `docs/handover/index.html`（567 KB）

**注意**: daily-digest は毎晩 GitHub Actions が生成する。生成器を変えると**翌朝から本番に出る**。ローカルで生成 → 目視 → その後に main へ入れる順序を守る。

3 点セットの対象:

| ページ | 生成器 | SKILL.md | review-prompt.md |
|---|---|---|---|
| daily-digest | `generate-daily-digest-html.sh` | `company-digest-html`（18）+ `company-daily-digest`（13） | `company-daily-digest`（4） |
| handover | `generate-handover-html.sh` | `company-handover`（10） | **無し** |

> `company-daily-digest` の L2 は **s6「禁則違反」が致命軸**で、絵文字禁止など**文面のルール**を採点している。**デザイン変更で影響を受けるかは未確認**。Day 4 で確認する。

### Day 5 — ダッシュボードとトップ（最難関）

対象: `docs/secretary/{org}/dashboard.html` と `docs/index.html`

**`docs/index.html` は 4 つの処理が書き込む。**

| 処理 | 起動元 |
|---|---|
| `generate-dashboard.sh` | ローカル `/company-dashboard`（**workflow からは呼ばれない**） |
| `generate-insights-html.py` | daily-insights-sync（**毎晩**） |
| `generate-daily-digest-html.sh` | daily-digest-automation（**毎晩**） |
| `generate-insights-analyses-html.sh` | ローカル `/company-insights-cycle` |

サイドバー構成にすると、**現在の「カードを末尾に挿入する」方式が成立しなくなる**。3 つの挿入処理をどう作り変えるかを Day 5 で設計する。

あわせて **`company-dashboard/SKILL.md`**（HTML 言及 5 箇所）の報告形式・構成説明も更新する。L2 採点プロンプトは無い。

> **ここが本計画で最も壊しやすい箇所である。** Day 4 までを終えてから着手し、**Day 5 だけで 1 日を使う**前提で見積もる。

### Day 6 以降 — 仕上げ

- ダークモード対応の方針決定（§4 の判断事項）
- 全ページの目視確認
- `artifact-placement.md` への記載（`docs/assets/` の位置づけ）

---

## 4. オーナーの判断が要る点

**着手前に決めてほしい 4 件。** 決まらないと Day 1 で止まる。

### (1) ダークモードをどうするか

現行は**全ページがダーク**で、`@media (prefers-color-scheme: dark)` を持つ。Organic は**ライト前提**のクリーム地である。

| 選択肢 | 内容 | コスト |
|---|---|---|
| A | **ライト固定にする**（Organic のまま） | 小。DS の意図に忠実 |
| B | ダークのトークンセットを自作して両対応 | 大。DS が持たない値を発明することになる |
| C | 当面ライト、要望が出たら B | 小 |

> DS の readme は「**パレットをグレーに脱色するな。暖かさが要点だ**」と明記している。B は DS の思想と衝突する可能性が高い。

### (2) 対象組織の範囲

現行トップには **`domain-tech-collection` と `standardization-initiative` の 2 組織**のダッシュボードカードがある。刷新案のサイドバーは単一組織前提に見える。

- 2 組織を並べるのか
- 組織切替 UI を作るのか
- `jutaku-dev-team`（3 組織目、Pages 未公開）をどうするか

### (3) 移植の完了条件

**「どうなったら完了か」を先に決める。** これは 2026-08-22 の解析で得た **Proof-or-Stop**（AI の「終わりました」は主張であって事実ではない）を適用するためである。

案: **全 8 ページがブラウザで目視確認され、リンク健全性検査が 0 件、かつ nightly を 1 晩通しても壊れていないこと。**

### (4) 既存の情報量を減らすか

刷新案は情報が整理されている一方、現行の `dashboard.html`（67 KB）は Chart.js のグラフを多数持つ。**捨てる情報があるかどうか**を決めておかないと、Day 5 で判断が止まる。

---

## 5. リスクと備え

| リスク | 影響 | 備え |
|---|---|---|
| **生成器を壊すと毎晩の自動処理が失敗する** | 大 | 1 ページずつ。各日の終わりに必ずローカル生成して目視 |
| **`docs/index.html` の 4 重書き込み** | 大 | Day 5 まで触らない。設計に 1 日使う |
| daily-digest は 5.9 MB あり、生成が重い | 中 | Day 4 でローカル生成の所要時間を測ってから判断 |
| Organic の `styles.css` が想定より大きい | 小 | Day 1-1 でサイズを測る |
| Lucide アイコンが外部依存になる | 小 | インライン SVG に落とす選択肢を Day 1-4 で検討 |
| **ライト化で既存の見た目を好む人が困る** | 中 | §4(1) をオーナーが決める |
| **生成器だけ直して SKILL.md / review-prompt.md を放置する** | **大** | §2.4 の 3 点セットを各 Day のチェックリストに入れた。Day 3-7 で**実際に L2 を通す** |
| **`plugins/` ↔ `.claude/skills/` の同期漏れ** | 中 | 各 Day の最後に `diff -rq`。**過去に同期漏れの実績あり**（候補 AE） |
| L2 採点基準を変えた結果、**旧成果物が全部 fail になる** | 中 | 既存 44 図を再生成するのか、採点を新規分のみに適用するのかを **Day 3 で決める**（**未検討**） |

---

## 6. この計画で確認していないこと

| # | 内容 |
|---|---|
| 1 | **`Portal.dc.html` を描画していない**。構造とトークンの読み取りのみで、**見た目を一度も見ていない**（Day 1-2 で解消する） |
| 2 | **`styles.css` を取得していない**。サイズも中身も未確認。「1 枚で自己完結」は readme の記述に依存 |
| 3 | **`_ds_bundle.js` を読んでいない**。`.card` 等のクラスが CSS だけで完結するのか、JS を要するのかは**未確認** |
| 4 | 各生成器の**改修工数を見積もっていない**。Day 2〜5 の粒度は「1 日 1 段階」という仮置き |
| 5 | プロトタイプに埋まっている数値（`202` / `1192` / `153`）が**何の指標か特定していない**（`0.81` が Case Bank 平均と一致することのみ確認） |
| 6 | `docs/assets/` というディレクトリは**現状存在しない**。`artifact-placement.md` にも記載が無い |
| 7 | **`company-sheet` の review-prompt（構造言及 7 箇所）が HTML 刷新の影響を受けるかを確認していない**。xlsx 側なので薄いと推測しただけ |
| 8 | `company-daily-digest` の L2 致命軸 s6（禁則違反）が**デザイン変更で影響を受けるか未確認** |
| 9 | **既存成果物（図 44 本・ダイジェスト 129 日分等）を再生成するかを決めていない**。採点基準を変えると旧成果物の扱いが問題になる |
| 10 | **Day 1 以降は一切着手していない**。本書は計画のみ |

---

## 7. 明日の最初の一手

```
1. §4 の判断 4 件をオーナーに確認する（特に (1) ダークモード）
2. Day 1-1: styles.css を取得してサイズを測る
3. Day 1-2: React を CDN で読ませて Portal.dc.html を描画し、目視する
```

**作業対象の総量（実測）**

| 種別 | 件数 |
|---|---|
| ページ | **8** |
| 生成器（hooks） | **6** |
| SKILL.md（HTML 規定あり） | **9** |
| L2 採点プロンプト | **5** |
| ルールファイル | `CLAUDE.md`（必須 7 セクション）/ `artifact-placement.md` |

**合計 28 ファイル前後**を触ることになる。1 日 1 段階という見積もりは、この規模に対して**楽観的である可能性がある**。

**Day 1-2 を先にやる価値が高い。** 見た目を一度も見ないまま生成器を書き換えるのは、今日学んだ Proof-or-Stop の反対である。

---

## 関連

- [`loop-engineering-proof-or-stop.md`](../../../../docs/insights/analyses/loop-engineering-proof-or-stop.md) — 完了条件の考え方（§4-3 の根拠）
- `@.claude/rules/artifact-placement.md` — `docs/assets/` の位置づけを Day 6 で追記する
- Claude Design: `CC-SIER組織ポータル刷新案`（`14fffc24-d353-4ebd-9468-b614e726c557`）
- Claude Design: `Organic`（`9ccf8d1e-067c-4ccb-bc4a-0a6417c90f23`）
