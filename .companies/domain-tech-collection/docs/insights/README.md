# 知見カタログ — 外部技術記事の解析と採用判断

外部の技術記事から得た知見を、**cc-sier および派生アプリへ採用するか判断する**ためのディレクトリ。

> **どこから読むか**: 採用判断をしたいなら [`catalog.md`](catalog.md) だけ見れば足ります。
> 個別の根拠が要るときに `analyses/` を開いてください。

---

## 構成

```
insights/
├── README.md              ← いまここ（入口）
├── catalog.md             ← 採用判断カタログ（本体・これを見る）
└── analyses/              ← 個別の解析レポート（根拠）
    ├── 2026-08-digest-ai.md        日次ダイジェスト 8月分の徹底解析
    ├── ai-pr-approval-gate.md      AIによるPR承認ゲートと「人間が見るべき変更」
    ├── comment-density.md          AIが書くコメントの分量
    ├── pkb-three-stage-pipeline.md PKB の 3 段導線と自組織の実測
    ├── task-management.md          中〜大規模開発のタスク管理
    └── webfetch-summarization.md   WebFetch の要約バイパス検証
```

---

## 日次ダイジェストの解析済み範囲

**解析済みは 2026-08 の 8 日分のみです。**

| 項目 | 値 |
|---|---|
| 蓄積されているダイジェスト | **115 日分**（2026-03-21 〜 2026-08-08） |
| うち解析済み | **8 日分（7.0%）** |
| 未解析 | **107 日分** |
| A1+A2 の総記事数 | 約 3,192 件 |

> 2026-03-21 〜 2026-07-31 の約 107 日分は**読んでいません**。ここに本組織へ効く知見が残っている可能性はありますが、**サンプリングもしていないため量は不明**です。

これは PKB 記事が「詰まりどころ」として挙げる **Inbox の取り込み過多**（capture が強力なぶん処理が追いつかず生データが溢れる）そのものです。全件遡及は非現実的（約 3,000 件・古い記事は陳腐化）と判断し、**未解析であることを明示する**方針を採っています。

根拠: [`analyses/pkb-three-stage-pipeline.md`](analyses/pkb-three-stage-pipeline.md)（候補 U）

**解析するたびに、この表を更新してください。**

---

## catalog.md の見方

知見を **A〜AC で採番**し、それぞれに次を記録しています。

| 記号 | 意味 |
|---|---|
| ✅ | 採用済み（実装または明文化されている） |
| 🔶 | 部分採用（一部のみ / 明文化されていない） |
| ⬜ | 未採用（検討対象） |
| ❌ | 不採用（**理由あり**） |

**§7 の優先度まとめ表**が一覧になっているので、そこから入るのが早いです。

「未採用」には**コストと、判断に必要な追加情報**を書いてあります。着手を判断するときはそこを見てください。「不採用」も理由つきで残しています（理由がないと同じ検討を繰り返すため）。

---

## 現在の採用候補（2026-08-08 時点）

優先度が高いものだけ抜粋します。最新は [`catalog.md` §7](catalog.md) を参照。

| ID | 候補 | 状況 | なぜ優先度が高いか |
|---|---|---|---|
| **X** | 「人間が見るべき変更」の定義を作る | ⬜ | **統制系（hooks/rules/CLAUDE.md/skills）を含む PR が 60 件中 10 件（16.7%）あり、そのすべてが 3 層レビューも人間レビューも通っていない**（実測 2026-08-09） |
| **AA** | nightly の CLAUDE.md 自動更新に承認を入れる | ⬜ | nightly が 12 回で **+49 行 / -5 行**。**AI が自分を縛るルールを一方向に増やしている**。候補 Q が進まない原因がこれで説明できる |
| **B** | task-log に `verification-pending` を追加 | ⬜ | **実際に問題が起きている**。`retail-stats-tracker` で「動いたが使えるか未検証」が `completed` として記録されている |
| **S** | 「緑 ≠ 実用可」の明文化 | ⬜ | L2 pass 後に設計不整合 3 件（#724/#728/#729）。**B・Y・Z と同じ問題を別角度から指す**ため統合して扱う |

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

| 旧パス | 新パス |
|---|---|
| `research/ai-driven-development-practices-catalog.md` | `insights/catalog.md` |
| `research/digest-2026-08-ai-insights.md` | `insights/analyses/2026-08-digest-ai.md` |
| `research/comment-density-analysis.md` | `insights/analyses/comment-density.md` |
| `research/ai-agent-task-management-analysis.md` | `insights/analyses/task-management.md` |
| `research/webfetch-summarization-verification.md` | `insights/analyses/webfetch-summarization.md` |
