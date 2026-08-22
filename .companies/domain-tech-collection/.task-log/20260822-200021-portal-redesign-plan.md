---
task_id: "20260822-200021-portal-redesign-plan"
org: "domain-tech-collection"
operator: "SAS-Sasao"
status: completed
mode: "direct"
started: "2026-08-22T17:00:00"
completed: "2026-08-22T17:20:00"
request: "明日からデザインの移植（実態のページに合わせて）を行いたい。計画書いて。／HTML作成のSKILLも変更必要だから計画に載せてね"
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
- **判断理由**: 計画立案のみ。実装は明日以降。

## エージェント作業ログ

### [2026-08-22 17:00] 移植元の調査

Claude Design の `DesignSync` ツールで読み取り（`/design consent` 済み）。

| 対象 | 結果 |
|---|---|
| `CC-SIER組織ポータル刷新案` | type: `PROJECT_TYPE_PROJECT` / `Portal.dc.html` **62,567 字** |
| `Organic` DS | type: `PROJECT_TYPE_DESIGN_SYSTEM` / readme を精読 |
| `support.js` | **React ランタイム**（`window.React` 必須、70.6 KB） |

**重要な判明事項**: `Portal.dc.html` は `<x-dc>` / `<sc-if>`×8 / `{{ }}`×42 を使う **6 画面の対話プロトタイプ**。**素の GitHub Pages では描画されない**。

### [2026-08-22 17:10] 自組織の実測

- 現行 Pages **8 本すべてがスクリプト生成物**。手で維持されている HTML は 0
- テーマが正反対（現行 `#0b1222` ダーク ↔ Organic `#f5ead8` クリーム）
- `docs/index.html` は **4 つの処理**が書き込む

### [2026-08-22 17:15] オーナー指摘を反映

「HTML作成のSKILLも変更必要だから計画に載せてね」を受けて実測し §2.4 を新設。

| 対象 | 件数 |
|---|---|
| SKILL.md（HTML/CSS 規定あり） | **9 本** |
| L2 採点プロンプト（構造採点） | **5 本** |

`@.claude/rules/skill-development.md` の「**片方だけ更新すると L2 レビューが旧仕様で通過してしまう**」に該当。**生成器 / SKILL.md / review-prompt.md の 3 点セット**を各 Day のチェックリストに入れた。

### [2026-08-22 17:20] 成果物

- `docs/decisions/2026-08-22-portal-redesign-plan.md`（**358 行**）
- 構成: 現状実測 → 移植方針 → §2.4 Skill も対象 → Day 1〜6 の段階計画 → オーナー判断 4 件 → リスク → 未確認事項 10 件

## 未検証事項

- **`Portal.dc.html` を描画していない**。構造とトークンの読み取りのみで**見た目を一度も見ていない**（Day 1-2 で解消予定）
- **`styles.css` を取得していない**。「1 枚で自己完結」は readme の記述に依存
- **`_ds_bundle.js` を読んでいない**。`.card` 等が CSS だけで完結するか未確認
- `company-sheet` / `company-daily-digest` の L2 が**デザイン変更の影響を受けるか未確認**
- **既存成果物（図 44 本等）を再生成するかを決めていない**
- 1 日 1 段階という見積もりは**楽観的である可能性がある**（対象 28 ファイル前後）
- **Day 1 以降は一切着手していない**

## reward
```yaml
score: 1.0
signals:
    completed: true
    artifacts_exist: true
    excessive_edits: false
    retry_detected: false
evaluated_at: "2026-08-22T20:06:31"
```
