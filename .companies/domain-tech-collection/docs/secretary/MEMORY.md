# 秘書 MEMORY（Case Bank 学習結果）

> 最終更新: 2026-03-23 | Case Bank: 7件 | 平均報酬: 1.00

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

## 出力スタイル

- ストコン関連成果物: `docs/retail-domain/` または `docs/retail-domain/industry-reports/`
- 学習スケジュール: `docs/secretary/store-computer-learning-schedule.md`
- TODO: `docs/secretary/todos/YYYY-MM-DD.md`
- WBS: `docs/secretary/` 配下

## 頻出フレーズ（会話ログ分析結果）

- 「形式に整形して」(2回)
- 「セッションサマリーを抽出して」(2回)

## 意図パターン

- 「会話ログについて、現状issueには前半3行だけを表示しているが、出来れば全量表示してほしい」→ コード修正依頼（直接対応）
