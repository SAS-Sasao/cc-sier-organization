# 秘書 MEMORY（Case Bank 学習結果）

> 最終更新: 2026-07-12 16:10 | Case Bank: 160件 | 平均報酬: 0.84

## ルーティング先読み

以下のパターンはCase Bankの高報酬実績に基づく推奨ルーティングです。

| 依頼パターン | 推奨ルーティング | 実績報酬 |
|-------------|----------------|---------|
| ストアコンピューター関連の調査・知識収集 | retail-domain-researcher (subagent) | 1.00 |
| 学習スケジュール策定（複数分野横断） | agent-teams (retail-domain + tech-researcher) | 1.00 |
| PM視点の学習コンテンツ追加 | project-manager (subagent) | 1.00 |
| 情報ソースマスタ作成・整備 | agent-teams (tech-researcher + retail-domain) | 1.00 |
| WBS・準備計画の作成 | direct (秘書直接対応) | 1.00 |
| 知識収集 + TODO作成 | retail-domain-researcher (subagent) | 1.00 |
| コンビニ業界構造の深掘り調査 | retail-domain-researcher (subagent) | 1.00 |
| ニュース巡回・日次ダイジェスト | **秘書が直接WebFetch並列実行**（Subagent委譲不可） | 0.60 |

## 出力スタイル

- ストコン関連成果物: `docs/retail-domain/` または `docs/retail-domain/industry-reports/`
- 学習スケジュール: `docs/secretary/store-computer-learning-schedule.md`
- TODO: `docs/secretary/todos/YYYY-MM-DD.md`
- WBS: `docs/secretary/` 配下
- 日次ダイジェスト: `docs/daily-digest/YYYY-MM-DD.md`

## 失敗パターン（低報酬ケースからの教訓）

### wf-daily-digest 実行時の注意（reward: 0.6）
1. **SubagentにWebFetchなし** → Agent Teams委譲せず秘書が直接WebFetchを並列実行する
2. **WebFetchでURL欠落** → プロンプトに「各記事のURL（https://...）を含めて」と必ず明記
3. **品質ゲート必須** → コミット前に `masters/quality-gates/by-type/daily-digest.md` を実行

## 頻出フレーズ（会話ログ分析結果）

- 「形式に整形して」(2回)
- 「セッションサマリーを抽出して」(2回)
- 「マージしたからブランチ削除して」(3回) → post-merge-cleanup パターン
- 「品質ゲート」(2回) → quality-gate-setup パターン

## 意図パターン

- 「ニュース巡回」「daily digest」「情報収集」→ wf-daily-digest（秘書直接WebFetch）
- 「ストコン」「ストアコンピューター」「コンビニ」→ wf-storcon-research（retail-domain-researcher）
- 「マージした」「ブランチ削除」→ git cleanup（秘書直接対応）
- 「品質ゲート」「チェックリスト」→ quality-gate-setup
- 「学習して」「進化させて」→ /company-evolve
- 「レポート」「振り返り」→ /company-report

## 更新履歴メモ（2026-07-12 追記）

- **日次ダイジェストの現行運用**: GitHub Actions 経由の agent-teams 自動実行（`mode:agent-teams-actions`）が定着。`daily-digest-au*` パターン 48 件で平均報酬 0.80。上記「秘書が直接WebFetch並列実行」の記述はローカル手動実行時代のもので、現在は Actions 自動化が主経路
- **#618 教訓**: claude-code-action で Task subagent を spawn する workflow は job-level env に `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS: "1"` が必須（subagent バックグラウンド化による早期終了・success 偽装を防止）。修正後 2026-07-11/07-12 の連続自動実行成功で有効性確認済み
- **L2 品質傾向**: 直近ダイジェストは composite 0.95 で安定。最弱軸は s5_dedup（重複排除、0.85）— 複数ソースが同一トピックを扱う場合の集約フェーズでの重複検知が今後の改善点
