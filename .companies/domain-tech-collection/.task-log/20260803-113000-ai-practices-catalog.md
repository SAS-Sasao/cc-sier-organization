---
task_id: "20260803-113000-ai-practices-catalog"
org: "domain-tech-collection"
operator: "SAS-Sasao"
status: completed
mode: "direct"
started: "2026-08-03T11:30:00"
completed: "2026-08-03T11:50:00"
request: "https://zenn.dev/osakayakyu/articles/e6aa9835c04d73 このサイトも解析してほしい。※いくつか依頼したAIがらみの解析はいずれこのリポジトリや私が作成するアプリのclaude codeのアーキテクトに採用するか考えるからまとめておいてほしい。"
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
- **成果物の形**: 単発の記事解析ではなく、**採用判断用の横断カタログ**として作成

## 依頼の解釈

依頼は 2 つ:
1. 記事（Zenn / KoH 氏 / Skills は手順書）の解析
2. **これまでの AI 関連解析を、cc-sier および派生アプリのアーキテクチャに採用するか判断するための材料としてまとめる**

2 が本題と判断。個別レポートを積み上げるだけでは「採用するか考える」用途に使えないため、
**横断インデックス + 採用状況 + コスト + 判断に必要な追加情報**を持つカタログ形式にした。

新しい解析を行うたびに追記していく前提で構成している。

## 取得方法

新設した `.claude/rules/web-content-fetch.md` に従い **curl で原文取得**（6,783 字）。
ルール制定後、最初の適用事例。

## 記事の内容（要点）

Claude Code の Skill は「コード」ではなく **`SKILL.md` に自然言語で書いた手順書**である、という発見。
著者は `/article`（セッションの学びを Zenn 記事の下書きにする）を実例として提示。

中核の設計原則:

> 自動化の目的は、確認をなくすことではなく、**確認する前の面倒な作業を減らすこと**

この原則から「AI に任せる範囲」と「人間が見る範囲」を明示的に分離している。
具体策として `published: false` を必ず入れ、**公開判断は別コマンドに分離**（「ここは絶対に分けた方がいい」）。

## カタログの構成

13 の知見を A〜M で採番し、採用状況を 4 記号（✅採用済 / 🔶部分 / ⬜未採用 / ❌不採用）で整理した。

| 出典 | 知見数 | 主な採用状況 |
|---|---|---|
| 1. Skills は手順書（今回） | 5 論点 | ✅2 / 🔶2 / ⬜1 |
| 2. タスク管理 | 7 論点 | ✅5 / ⬜1 / ❌1 |
| 3. WebFetch 検証 | 2 | ✅1 / ⬜1 |
| 4. レビューループ品質管理 | 3 | ⬜2 / 🔶1（設計済・未実装） |
| 5. ループエンジニアリング | 5 | ✅5（実装済み） |
| 6. Claude Code 仕様の誤り | — | 実測知見として記録 |

## 判断のポイント

### 優先度「高」は 1 件のみ

**候補 B（task-log に `verification-pending` を追加）**。理由は理論上の欠落ではなく
**実際に問題が発生している**ため — `retail-stats-tracker` の M3 は関連タスクがすべて `completed` だが、
NFR-05 は 63.75% で未達、`no_metric_match_in_multi_value` が 29 件残存している。
「動いた」と「使える」の間の状態が記録上どこにもない。

### 今回の記事から新たに拾った候補

**候補 A（外部公開の確認ルール明文化）**。本組織で外部公開が発生するのは
spawn でのリポジトリ作成 / GitHub Pages 配信 / public リポジトリの Issue・PR 本文。
現状は個別に確認しているが（8/2 の spawn で public/private を確認した実績あり）ルール化されていない。

### 不採用と明記したもの

**進行中タスク 1 件制限**（❌）。cc-sier の並列は「1 タスク内での Subagent 分担」であり、
記事が警告する形とは異なる。Agent Teams の設計思想と衝突する。

## 派生アプリへの引き継ぎ

I / J / K / L / M（hooks 2 系統・損失関数・maker-checker・評価データ凍結・Stop 読み取り専用）は
既に retail-stats-tracker の設計へ織り込み済み。
**新規アプリを spawn する際は `CLAUDE.md` と `.claude/agents/` に引き継ぐこと**をカタログに明記した。

## 成果物

`.companies/domain-tech-collection/docs/research/ai-driven-development-practices-catalog.md`

## reward
（post-merge hook が自動追記）
