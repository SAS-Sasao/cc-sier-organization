---
task_id: "20260809-153000-pr-approval-gate-analysis"
org: "domain-tech-collection"
operator: "SAS-Sasao"
status: completed
mode: "direct"
started: "2026-08-09T15:30:00"
completed: "2026-08-09T15:52:00"
request: "/company-digest-insights https://zenn.dev/she_techblog/articles/937836550dfdf3 この記事の内容を深堀して、このリポジトリや俺の活動で生かせる点を抽出してほしい"
issue_number: null
pr_number: null
subagents: []
l0_gate: null
l0_retries: 0
l1_gate: null
l1_retries: 0
l2_composite: null
l2_retries: 0
---

## 実行計画

- **実行モード**: direct
- **参照したマスタ**: `.claude/rules/web-content-fetch.md` / `company-digest-insights` SKILL.md
- **判断理由**: 単一 URL 指定のため Phase 1（クラスタリング）は不要。
  依頼が「深堀して**このリポジトリや俺の活動で生かせる点**を抽出」なので、
  Phase 3（自組織での実測）に重心を置き、**直近 60 PR の全数分析**を行った
  （記事が 75 件の全数分析から始めているのに合わせた）

## エージェント作業ログ

### [2026-08-09 15:29] Phase 0 — 前処理
観測データをコミットして clean 化。`git rebase origin/main` でリモート 3 コミットに追従
（daily-digest #762 等）。**`git reset --hard` は使わなかった**（前日の逸脱を踏まえた）。

### [2026-08-09 15:30] Phase 2 — 原文取得
curl で取得（**6,664 字**）。目次と本文が一致しており全文取得を確認。

記事: 「58% の Pull Request を AI が承認するようになった」
（qsona / SHE 株式会社 開発責任者 / 2026-08-07）

### [2026-08-09 15:35] Phase 3 — 自組織での実測

**記事は「人間レビューを減らす」話だが、本組織には逆向きに効くことが実測で判明した。**

| 実測項目 | 値 |
|---|---|
| 直近 60 merged PR のレビュー数 | **全件 0（0%）** |
| 統制系（hooks/rules/CLAUDE.md/skills）を含む PR | **10 / 60 = 16.7%** |
| うち task-log または 3 層レビューを持つもの | **0 件** |
| L2 を持つ Skill | 6 / 17（35.3%） |
| nightly の CLAUDE.md/rules 自動更新 | 12 回・**+49 / -5 行** |
| `l2_composite` の最小値 | **0.88**（fail 0 件・retry は 4 件発生） |
| `.conversation-log/` の人間発言 | **3,163 件**（PUBLIC リポジトリ） |

**成果物には 3 層の審査を敷き、審査の仕組みそのものを変える PR は素通ししている**
という構造が数字で出た。#723（品質ゲートの修正）と #714（Case Bank の修正）が実例。

記事の 8 項目のうち **6 項目が本組織に実在**（統制系 / 不可逆操作 / 個人情報フロー /
外部契約 / 新規パターン / 高リスク値計算）。

### [2026-08-09 15:48] Phase 5 — レポート + カタログ + README

- `insights/analyses/ai-pr-approval-gate.md` 新規（記事の解説 §1 + 実測 §2 + 候補 §3）
- `insights/catalog.md` §5.8 追加 / §7 に X・AA・Y・Z・AB・AC / §8 に未検証 4 件
- `insights/README.md` の採用候補表を更新（X・AA を最上位に）

## 採用判断

| ID | 候補 | 判定 |
|---|---|---|
| **X** | 「人間が見るべき変更」の定義を作る | ⬜ **優先度 高** — 統制系 16.7% が無審査という実測が根拠 |
| **AA** | nightly の CLAUDE.md 自動更新に承認を入れる | ⬜ **優先度 高** — 追記:削除 ≒ 10:1 |
| **Y** | 判定を 2 軸に分ける | ⬜ 中 — 候補 B・S と統合して実装可 |
| **Z** | `pending` 状態 | ⬜ 中 — 候補 B・S・Y と同じ問題 |
| **AB** | L2 の初回スコアを保存 | ⬜ 中 — 過去分には遡れない |
| **AC** | AI による PR auto-approve の導入 | ❌ **不採用** — approve 率が既に実質 100%、解決する課題がない |

**AC を不採用にした点が今回の要点。** 記事の主題そのものだが、本組織には導入対象がない。
同じ記事から**逆向きの示唆**（人間レビューの線を引く）を採った。

## 未検証事項

- 記事の 8 項目のうち**セキュリティ境界・実行時ハザードは未測定**
- **マスキング辞書の網羅性は未測定**。`masked: true` は処理を通した印であって機密が残っていない保証ではない
- **L2 が甘いかどうかは判定できない**。初回スコアが残っていないため retry 4 件の当否が不明
- **候補 X のゲート設置場所は未検討**（PR 作成時 hook / Actions / Skill 内の比較なし）
- 記事の実装コードは**見ていない**。評価は記述に基づく
- 記事の 58% は**2 週間の速報値**（著者自身が偽陽性/偽陰性の継続観測を課題として残している）

## judge

```yaml
completeness: 1.00
accuracy: 1.00
clarity: 0.95
total: 0.98
failure_reason: ""
judge_comment: "curl で原文取得（6,664 字）し全文読了。記事が 75 件の全数分析から始めているのに合わせ、直近 60 PR の全数分析を実施。統制系 16.7% が 3 層レビューも人間レビューも通っていないという構造的な穴を数字で特定し、nightly の追記:削除 = 49:5 という非対称も定量化した。記事の主題（auto-approve）を『導入対象がない』として不採用にし、逆向きの示唆を採った判断が要点。clarity 0.95 は、解説と実測の二本立てでレポートが長めになったため"
judged_at: "2026-08-09T15:52:00+09:00"
```

## reward
（post-merge hook が自動追記）
