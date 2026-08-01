---
task_id: "20260801-201500-fix-case-bank-feedback"
org: "domain-tech-collection"
operator: "SAS-Sasao"
status: completed
mode: "direct"
started: "2026-08-01T20:15:00"
completed: "2026-08-01T20:22:00"
request: "（/company-cycle の実行中に発見した evolve の機能不全）反映しておいて！"
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

- **実行モード**: direct（hook / SKILL.md の局所修正のため subagent 委譲は不要）
- **契機**: `/company-cycle` の Phase 1.5（evolve）で `failure_patterns: 0` を観測し、原因を調査

## 背景

`/company-evolve` の Read フェーズは、Case Bank の `failure_patterns` を秘書の判断に注入する設計。
しかし実際には `failure_patterns` が常に 0 件で、**学習した失敗パターンが次セッションで一切参照されていなかった**。

feedback メモリは蓄積されていたが、Case Bank に取り込まれる経路が 3 箇所で断線していた。

## 修正内容

### 1. `.claude/hooks/rebuild-case-bank.sh` — 3 点の断線を修正

| # | 問題 | 修正 |
|---|---|---|
| 1 | `glob("feedback_*.md")` がどのファイルにもマッチしない | `glob("*.md")` に変更し、絞り込みは `type: feedback` 判定のみに任せる |
| 2 | `re.match(r'type:\s*(.+)')` が行頭固定でインデントを取りこぼす | `re.match(r'\s*type:\s*(.+)')` に変更 |
| 3 | `How to apply` の正規表現がコロン内側形式のみ | `\*\*How to apply:?\*\*:?` で両表記を許容 |

**#1 の詳細**: 実在するメモリはいずれもマッチしなかった。

| ファイル | 不一致の理由 |
|---|---|
| `memory/cc-sier-design-review-lessons.md` | プレフィックスなし |
| `memory/user-prefers-decisive-action.md` | 同上 |
| `agent-memory/system-architect/feedback-verify-review-numbers.md` | ハイフン区切り |

ファイル名規約に依存すると命名のたびに漏れるため、**命名ではなく frontmatter の `type` で判定**する方式に変更した。

**#2 の詳細**: 現行のメモリ形式は `type` が `metadata:` 配下にインデントされる。

```yaml
metadata:
  type: feedback     # ← 行頭固定の正規表現では拾えない
```

### 2. `.claude/skills/company-report/SKILL.md` — 期間フィルタの取りこぼし

`started` のみで絞ると、**複数日にまたがるタスクが期間内の成果から消える**。

実例: 2026-08-01 の today レポートで、`started: 2026-07-26` / `completed: 2026-08-01` の
設計タスク（PR #710、6,189 行）が検出されず、当日の成果が日次ダイジェストのみになりかけた。

→ `started` **または** `completed` が期間内のものを対象とする（和集合、task_id で重複排除）に変更。
開始日が期間外の場合は「{開始日} 開始・{完了日} 完了」と補足を添える運用も明記した。

## 検証結果

修正後に `rebuild_case_bank` を再実行:

```
failure_patterns: 0 件 → 2 件
  - [feedback-memory] cc-sier-design-review-lessons
    subagent: general / how_to_apply 抽出成功
  - [feedback-memory] user-prefers-decisive-action
    subagent: general / how_to_apply 抽出成功
```

`type: reference` のメモリ（`claude-code-spec-reference-errors.md`）は
意図どおり対象外（feedback ではないため）。

## 残る課題（別途対応）

`match_keywords` が英語スラッグ（`['cc', 'sier', 'design', 'review', 'lessons']`）中心になっており、
日本語の依頼文との照合精度が低い。`description` 側も文全体が 1 トークンになる場合がある。

ただし現状の 2 件はいずれも `subagent: general` であり、
SKILL.md の Read フェーズ仕様「general の feedback は依頼内容に関わらず常に注入候補」により
キーワード照合に関わらず注入されるため、実害は限定的。

改善するなら形態素分割の導入が必要で、スコープが大きいため本タスクでは扱わない。

## 影響範囲

- `.claude/hooks/rebuild-case-bank.sh`（`/company-evolve` から呼ばれる。全組織に影響）
- `.claude/skills/company-report/SKILL.md`（`/company-report` と `/company-cycle` Phase 1）
- `plugins/` 側への同期は不要（両ファイルとも `plugins/cc-sier/` に存在しない）

## reward
（post-merge hook が自動追記）
