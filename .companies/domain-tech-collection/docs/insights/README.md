# 知見カタログ — 外部技術記事の解析と採用判断

外部の技術記事から得た知見を、**cc-sier および派生アプリへ採用するか判断する**ためのディレクトリ。

> **どこから読むか**: 採用判断をしたいなら [`catalog.md`](catalog.md) だけ見れば足ります。
> 個別の根拠が要るときに、リポジトリルートの [`docs/insights/analyses/`](../../../../docs/insights/analyses/) を開いてください。

---

## 構成

**判断するもの（カタログ・入口）は組織スコープ、根拠となる解析レポートは Pages 配信側**という 2 箇所構成です。

```
.companies/domain-tech-collection/docs/insights/    ← 判断側（組織スコープ）
├── README.md              ← いまここ（入口）
└── catalog.md             ← 採用判断カタログ（本体・これを見る）

docs/insights/                                      ← 根拠側（GitHub Pages 配信）
├── index.html             ← TodoInsights（既存・本ディレクトリとは別系統）
└── analyses/              ← 個別の解析レポート
    ├── 2026-08-digest-ai.md        日次ダイジェスト 8月分の徹底解析
    ├── 2026-08-w2-claude-code-codex-agent.md
    │                               8/3〜8/9 の Claude Code / Codex / エージェント設計
    ├── ai-pr-approval-gate.md      AIによるPR承認ゲートと「人間が見るべき変更」
    ├── comment-density.md          AIが書くコメントの分量
    ├── pkb-three-stage-pipeline.md PKB の 3 段導線と自組織の実測
    ├── task-management.md          中〜大規模開発のタスク管理
    └── webfetch-summarization.md   WebFetch の要約バイパス検証
```

**解析レポートは `docs/insights/analyses/` に置いてください**（2026-08-16 にオーナー判断で全 7 本を移動）。ブラウザから読めるようにするためで、`docs/requirements.md` や `docs/guide/*.md` と同じ扱いです。

> `@.claude/rules/artifact-placement.md` は業務ドキュメント（MD）の配置先を `.companies/{org}/docs/` と定めており、`analyses/` 配下はその例外にあたります。**ルールファイル側は未更新です。**

---

## 日次ダイジェストの解析済み範囲

**解析済みは 2026-08 の 9 日分のみです。**

| 項目 | 値 |
|---|---|
| 蓄積されているダイジェスト | **123 日分**（2026-03-21 〜 2026-08-16） |
| うち解析済み | **9 日分（7.3%）**（2026-08-01 〜 08-09） |
| 未解析 | **114 日分** |
| A1+A2 の総記事数 | **3447 件**（実測） |

> 2026-03-21 〜 2026-07-31 の約 107 日分は**読んでいません**。ここに本組織へ効く知見が残っている可能性はありますが、**サンプリングもしていないため量は不明**です。

> **「解析済み」は原文精読の意味ではありません。** 2026-08-03〜08-09 の週では、ユニーク 181 件のうち原文まで読んだのは **12 件（6.6%）**で、残りはタイトルと 1 行要約で判断しています（[`analyses/2026-08-w2-claude-code-codex-agent.md`](../../../../docs/insights/analyses/2026-08-w2-claude-code-codex-agent.md) §7）。

> **【訂正 2026-08-16】** 以前ここに「2026-08-10 以降のダイジェストは未生成」と書いていましたが**誤り**でした。`git fetch` していない古いチェックアウトを見たためで、実際には 08-10 〜 08-16 も生成されています。**解析前に必ず `git fetch` してください**（`/company-digest-insights` Phase 0 にも明記されています）。

これは PKB 記事が「詰まりどころ」として挙げる **Inbox の取り込み過多**（capture が強力なぶん処理が追いつかず生データが溢れる）そのものです。全件遡及は非現実的（約 3,000 件・古い記事は陳腐化）と判断し、**未解析であることを明示する**方針を採っています。

根拠: [`analyses/pkb-three-stage-pipeline.md`](../../../../docs/insights/analyses/pkb-three-stage-pipeline.md)（候補 U）

**解析するたびに、この表を更新してください。**

---

## catalog.md の見方

知見を **A〜AN で採番**し、それぞれに次を記録しています。

| 記号 | 意味 |
|---|---|
| ✅ | 採用済み（実装または明文化されている） |
| 🔶 | 部分採用（一部のみ / 明文化されていない） |
| ⬜ | 未採用（検討対象） |
| ❌ | 不採用（**理由あり**） |

**§7 の優先度まとめ表**が一覧になっているので、そこから入るのが早いです。

「未採用」には**コストと、判断に必要な追加情報**を書いてあります。着手を判断するときはそこを見てください。「不採用」も理由つきで残しています（理由がないと同じ検討を繰り返すため）。

---

## 現在の採用候補（2026-08-16 時点）

優先度が高いものだけ抜粋します。最新は [`catalog.md` §7](catalog.md) を参照。

| ID | 候補 | 状況 | なぜ優先度が高いか |
|---|---|---|---|
| **X** | 「人間が見るべき変更」の定義を作る | ⬜ | **統制系（hooks/rules/CLAUDE.md/skills）を含む PR が 60 件中 10 件（16.7%）あり、そのすべてが 3 層レビューも人間レビューも通っていない**（実測 2026-08-09） |
| **AA** | nightly の CLAUDE.md 自動更新に承認を入れる | ⬜ | nightly が 12 回で **+49 行 / -5 行**。**AI が自分を縛るルールを一方向に増やしている**。候補 Q が進まない原因がこれで説明できる |
| **B** | task-log に `verification-pending` を追加 | ⬜ | **実際に問題が起きている**。`retail-stats-tracker` で「動いたが使えるか未検証」が `completed` として記録されている |
| **S** | 「緑 ≠ 実用可」の明文化 | ⬜ | L2 pass 後に設計不整合 3 件（#724/#728/#729）。**B・Y・Z と同じ問題を別角度から指す**ため統合して扱う |
| **AD** | `AGENTS.md` を `CLAUDE.md` へ畳む | ⬜ | Codex を現用（CLI 0.144.5・2026-08-16 に使用形跡）しながら、**`AGENTS.md` は 2026-06-13 の 1 コミットのみ。同期間に `CLAUDE.md` は 19 コミット**。注意事項 28 件が Codex に届いていない |
| **AE** | Skill 台帳の棚卸し | ⬜ | **`plugins/cc-sier/skills/` に無い Skill が 3 種**（`company-evolve` / `company-quality-setup` / `company-report`）。VCS 真ソース原則の外。CLAUDE.md の表も 12 種記載に対し実体 17 種 |

既に採用したもの:

| ID | 内容 | 反映先 |
|---|---|---|
| **D** | 解析依頼では curl で原文取得 | `.claude/rules/web-content-fetch.md` |
| **N** | 不確実さを分量で埋めない | `CLAUDE.md` 注意事項 |
| I〜M | ループエンジニアリング 5 原則 | `retail-stats-tracker` の設計 |

---

## 解析の進め方

`/company-digest-insights` Skill が担当します（`「知見抽出」「ネタ探し」「採用判断」` 等で起動）。

守っている原則:

1. **原本を読む** — 配信 HTML ではなく `daily-digest/*.md`。HTML は変換物
2. **キーワード検索を主手段にしない** — 実績として `Skill` で 4 件しかヒットせず、最も効いた記事群を取りこぼした
3. **原文は curl で取得** — Zenn / Qiita は WebFetch の信頼ドメイン外で要約経由になる
4. **主張を鵜呑みにせず自組織で実測する** — 体感では効いた/効かないを取り違える
5. **採用しない判断も記録する**

---

## このディレクトリと `research/` の違い

| | insights/ | research/ |
|---|---|---|
| 中身 | **外部知見の解析と採用判断** | 自組織の**設計書・要件定義** |
| 例 | コメント分量の解析、WebFetch 検証 | `retail-stats-tracker-design.md` |
| 読む目的 | 何を採用するか決める | 何をどう作るか決める |

2026-08-08 に `research/` から分離しました（設計書と混在して探しにくかったため）。

**過去の PR / Issue / task-log には旧パス（`docs/research/...`）が記録されています。** 履歴として残す方針なので書き換えていません。対応は次のとおり。

| 旧パス | 現在のパス |
|---|---|
| `research/ai-driven-development-practices-catalog.md` | `.companies/domain-tech-collection/docs/insights/catalog.md` |
| `research/digest-2026-08-ai-insights.md` | `docs/insights/analyses/2026-08-digest-ai.md` |
| `research/comment-density-analysis.md` | `docs/insights/analyses/comment-density.md` |
| `research/ai-agent-task-management-analysis.md` | `docs/insights/analyses/task-management.md` |
| `research/webfetch-summarization-verification.md` | `docs/insights/analyses/webfetch-summarization.md` |

**2026-08-16 に `analyses/` 配下 7 本を組織スコープからリポジトリルートの `docs/` へ移しました。** それ以前の task-log / 日次レポート（`docs/secretary/reports/`）には旧パス（`.companies/domain-tech-collection/docs/insights/analyses/...`）が記録されていますが、履歴として残す方針で書き換えていません。
