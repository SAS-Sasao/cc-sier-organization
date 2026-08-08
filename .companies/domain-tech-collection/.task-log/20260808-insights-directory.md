---
task_id: "20260808-insights-directory"
org: "domain-tech-collection"
operator: "SAS-Sasao"
status: completed
mode: "direct"
started: "2026-08-08T12:40:00"
completed: "2026-08-08T12:55:00"
request: "これ日次ダイジェスト解析のカタログ用ディレクトリを作成してほしい。※俺も確認しやすいように"
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

## 背景

知見カタログ系 5 本（1,202 行）が、設計書系 10 本（8,149 行）と同じ `docs/research/` に
混在していた。`retail-stats-tracker-design.md`（3,391 行）等の設計書に埋もれ、
オーナーが目的の文書に辿り着きにくい状態だった。

## 実施内容

### 1. `docs/insights/` を新設し `git mv` で移動

`git mv` を使ったのは**ファイル履歴を保つため**（`rm` + `add` だと履歴が切れる）。

| 旧 | 新 |
|---|---|
| `research/ai-driven-development-practices-catalog.md` | `insights/catalog.md` |
| `research/digest-2026-08-ai-insights.md` | `insights/analyses/2026-08-digest-ai.md` |
| `research/comment-density-analysis.md` | `insights/analyses/comment-density.md` |
| `research/ai-agent-task-management-analysis.md` | `insights/analyses/task-management.md` |
| `research/webfetch-summarization-verification.md` | `insights/analyses/webfetch-summarization.md` |

ファイル名も短縮した（`ai-driven-development-practices-catalog.md` → `catalog.md`）。
ディレクトリが役割を示すため、名前に役割を重ねる必要がなくなった。

### 2. README.md を入口として新設

依頼が「**俺も確認しやすいように**」だったため、単なるディレクトリ作成では足りないと判断した。

README に置いたもの:

- **どこから読むか**を冒頭に明示（採用判断なら `catalog.md` だけでよい）
- 現在の採用候補（優先度が高い 2 件のみ抜粋）と、採用済みの一覧
- 記号の意味（✅🔶⬜❌）
- `insights/` と `research/` の違い（何を決めるために読むか）
- **旧パス → 新パスの対応表**

### 3. 現行参照のみ更新（履歴は書き換えない）

参照元は 17 ファイルあったが、**過去ログは書き換えなかった**。

| 対象 | 扱い |
|---|---|
| `.claude/` の hooks / rules / skills | **更新**（現行の動作に影響する） |
| `plugins/` の SKILL.md | **更新**（VCS 真ソース） |
| `insights/` 内の相互参照 | **更新** |
| `.task-log/` `.conversation-log/` | **据え置き**（当時の記録として正しい） |
| `docs/secretary/reports/` | **据え置き**（同上） |

過去の日次レポート 8/3・8/8 に旧パスが残るが、**その時点での事実**なので改変しない。
README の対応表で追えるようにした。

## 検証

- `measure-comment-density.py` が移動後も動作（11.5% / 15 個 / 29 行、移動前と一致）
- README のリンク先が実在
- Skill のカタログ参照が新パス（`docs/insights/catalog.md`）
- `plugins/` との差分なし

## 未検証事項

- 過去の PR / Issue 本文に残る旧パスは**リンク切れになる**（GitHub 上で 404）。
  履歴として許容する方針だが、頻繁に参照されるなら別途対応が要る

## reward
（post-merge hook が自動追記）
