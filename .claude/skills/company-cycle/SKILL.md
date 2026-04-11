---
name: company-cycle
description: >
  /company-report → /company-evolve → /company-dashboard を直列実行する
  オーケストレータ Skill（軽量型）。組織の活動レポート・継続学習・
  ダッシュボード更新を 1 コマンドで完了する。
  ローカル実行が前提（gitignored データを使うため、GitHub Actions では非対応）。
  「サイクル」「ローテーション」「定期処理」「サイクル回して」「日次サイクル」
  「/company-cycle」と言われたとき、または毎日の終業時に実行する。
---

# CC-SIer サイクルオーケストレータ Skill（軽量型）

3 つの skill (`company-report` / `company-evolve` / `company-dashboard`) を直列実行する軽量オーケストレータ。

## 1. 適用条件

- **必ずローカル Claude Code 実行**（GitHub Actions では gitignored データが欠落するため非対応）
- `.companies/.active` に org-slug が存在する
- `.claude/skills/company-report/`, `company-evolve/`, `company-dashboard/` がインストール済み
- 既存 sub-skill の git 動作を尊重する（複数 PR + main 直コミットの混在を許容）

---

## 2. 4 フェーズ概要

| Phase | 名称 | 中断条件 |
|---|---|---|
| 0 | 前処理（org / period / git clean / task-log 初期化） | git dirty |
| 1 | `/company-report` 実行（内部で `/company-evolve` を自動連携） | report 失敗 |
| 2 | `/company-dashboard` 実行 | dashboard 失敗 |
| 3 | 統合 task-log 更新 + tracking Issue にコメント + 最終報告 | - |

各 phase 失敗時は task-log を `status: blocked` で保存し、ユーザーに復旧手順を報告する。

---

## 3. Phase 0: 前処理

```
1. .companies/.active から {org-slug} を取得
2. git config user.name → {operator}
3. period を解釈（today / week / month / カスタム、デフォルト today）
4. git status --porcelain が空でなければ中断
5. {date_jst} = TZ=Asia/Tokyo date +%Y-%m-%d
6. {task-id} = YYYYMMDD-HHMMSS-cycle-{period}
7. .companies/{org}/.task-log/{task-id}.md を YAML フロントマター形式で作成
   subagents: [company-report, company-evolve, company-dashboard]
```

task-log の `subagents` 欄には必ず英字で記録する（Case Bank 検出のため）。

---

## 4. Phase 1: /company-report 実行

`@.claude/skills/company-report/SKILL.md` の指示に従って実行する。

### 重要事項

- report の **Section 6** で `/company-evolve` が自動起動される（既存仕様）
- evolve の副作用（synthesizer / refiner / wf-auto-generation の **複数 PR 生成**）はそのまま許容
- evolve の `enrich-case-bank.sh` `rebuild-case-bank.sh` などの hook は全て発火する（ローカル実行のため）
- 各 sub-skill の git 動作（report の PR、evolve の複数 PR）は変更しない

### 完了時に記録する情報

- report MD ファイルパス: `.companies/{org}/docs/secretary/reports/{date}-{period}.md`
- report Issue URL
- evolve が生成した PR URL 一覧（synthesizer / refiner / auto-workflow ぞれぞれあれば）
- evolve のサマリー（評価タスク件数 / 平均 reward / Case Bank 件数）

### Phase 1 の実行方法

ユーザー（あなた = Claude）は以下を順次行う:

1. `@.claude/skills/company-report/SKILL.md` を Read
2. report の指示に従って Phase 2-1 から Phase 2-5 のデータ収集を実行
3. AI 要約してレポート MD を生成
4. ファイル保存・Git commit・Issue 投稿
5. report Section 6 に従って `/company-evolve` を自動起動
6. evolve の Phase 2 (Write) と Phase 5.5 を実行
7. 完了情報を Phase 0 で作成した task-log に追記

---

## 5. Phase 2: /company-dashboard 実行

`@.claude/skills/company-dashboard/SKILL.md` の指示に従って実行する。

### 重要事項

- dashboard は **main 直コミット**（PR 経由ではない、既存仕様）
- `bash .claude/hooks/generate-dashboard.sh {org-slug}` を実行するだけ
- 出力: `.companies/{org}/docs/secretary/dashboard.html` および `docs/index.html`
- **Phase 1 で evolve が更新した Case Bank がここで反映される**（順序が重要）

### 完了時に記録する情報

- dashboard HTML ファイルパス
- 生成サイズ (KB)
- GitHub Pages URL

---

## 6. Phase 3: 統合 task-log + Issue + 最終報告

### 6.1 統合 task-log 更新

```yaml
---
task_id: "{task-id}"
org: "{org-slug}"
operator: "{operator}"
status: completed
mode: "direct"
started: "..."
completed: "..."
request: "/company-cycle {period}"
issue_number: null
pr_number: null
subagents: [company-report, company-evolve, company-dashboard]
sub_skill_results:
  report:
    file: ".companies/{org}/docs/secretary/reports/{date}-{period}.md"
    issue: "https://github.com/.../issues/N"
    pr: "https://github.com/.../pull/N"
  evolve:
    case_bank_count: N
    avg_reward: 0.00
    pr_synthesizer: "..." or null
    pr_refiner: "..." or null
    pr_workflow: "..." or null
  dashboard:
    file: ".companies/{org}/docs/secretary/dashboard.html"
    size_kb: N
---
```

### 6.2 統合 tracking Issue にコメント

label: `cycle-tracker`

既存 Issue があればコメント追加、なければ新規作成:

- title: `cycle: 統合実行ログ（継続トラッキング）`
- body 冒頭: workflow の説明 + ローカル実行が必要な理由

コメント内容:

```markdown
## 🔄 {date_jst} ({DOW_JP}) - /company-cycle {period} 完了

| Phase | 状態 | 成果物 |
|---|---|---|
| 1. report | ✅ | [Issue #N](url) / [PR #N](url) |
| 1.5 evolve (auto) | ✅ | case bank: N 件 / avg reward: X / 生成 PR: N 件 |
| 2. dashboard | ✅ | [HTML](url) ({size} KB) |

実行時間: N 分
```

### 6.3 最終報告（ユーザーへ）

```
✅ /company-cycle {period} 完了

Phase 1 (report):    {report_issue_url}
  └ 自動連携 evolve: case_bank {N}件 / avg reward {X}
                    生成 PR: {N}件
Phase 2 (dashboard): {dashboard_url}

統合 tracking: #{tracking_issue_number}
合計時間: {duration}
```

---

## 7. オプションフラグ

| フラグ | 既定 | 効果 |
|---|---|---|
| `--period` | today | today / week / month / カスタム日付範囲 |
| `--skip-evolve` | off | report の自動 evolve 連携をスキップ（debug 用） |
| `--dashboard-only` | off | report/evolve をスキップし dashboard のみ実行 |
| `--report-only` | off | dashboard をスキップし report (+ auto evolve) のみ |

---

## 8. なぜローカル実行が必須か

GitHub Actions runner では以下のデータが**完全に存在しない**:

| データ | gitignore | 影響 |
|---|---|---|
| `.session-summaries/` | ✅ | report の Section 2.1（最優先） / dashboard のセッション統計 |
| `.conversation-log/` | ✅ | report の「会話トピック」/ dashboard の頻出フレーズ・enrich-case-bank.sh |
| `.quality-gate-log/` | ✅ | dashboard の品質ゲート通過率（ドーナツチャート） |
| `.case-bank/` | ✅ | 毎回 rebuild 必要、永続化されない |
| `~/.claude/.../memory/feedback_*.md` | - | rebuild-case-bank.sh の feedback memory 統合 |

加えて、`enrich-case-bank.sh` などの hook はローカル Claude Code セッション内で発火する設計のため、Actions 環境では動作しない。

→ **完全な observability を得るためにはローカル実行が必須**。GitHub Actions は補完的に `daily-cycle-supplement.yml` で git tracked データのみの軽量サマリーを生成し、ユーザーに「今日 cycle がまだ走っていない」をリマインドする。

---

## 9. エラー時の中断ポリシー

- 各 Phase で fail → task-log を `status: blocked` で保存
- ユーザーへの報告に Phase 名・原因・手動復旧コマンドを含める
- 部分作成済みの PR / コミットは削除しない（手動引き継ぎ用）
- Phase 1 の report/evolve が部分成功している場合、Phase 2 dashboard はスキップして報告

---

## 10. 関連

- @.claude/skills/company-report/SKILL.md — Phase 1 の本体
- @.claude/skills/company-evolve/SKILL.md — Phase 1.5 の本体（report から自動起動）
- @.claude/skills/company-dashboard/SKILL.md — Phase 2 の本体
- @.github/workflows/daily-cycle-supplement.yml — 19:00 JST の補完 Actions
- @.claude/rules/review-pattern.md — 将来的な L0/L1/L2 統合（Phase 2 昇格時）
- @.claude/rules/git-workflow.md — ブランチ・コミット・PR 規約
