---
name: company-dashboard
description: >
  組織の活動状況をHTMLダッシュボードとして生成する。
  「ダッシュボード」「状況を可視化」「/company-dashboard」と言われたときに使用する。
---

# ダッシュボード生成 Skill

## 1. 起動

1. `.companies/.active` から org-slug を取得
2. `bash .claude/hooks/generate-dashboard.sh {org-slug}` を実行
3. 生成されたファイルのパスと GitHub Pages 公開方法を報告する

## 2. ダッシュボード構成

`generate-dashboard.sh` が以下のデータソースを収集し、HTMLダッシュボードを生成する。

### 2.1 データソース

| ソース | 収集内容 |
|--------|---------|
| `docs/secretary/board.md` | タスクボード統計（TODO/In Progress/Review/Done） |
| `.quality-gate-log/*.jsonl` | 品質ゲート通過率 |
| `.case-bank/index.json` | LLM-as-Judge評価データ・失敗パターン |
| `.conversation-log/*.md` | 会話ログ統計・頻出フレーズ |
| `.session-summaries/*.json` | セッション統計・ツール実行数 |

### 2.2 表示セクション

1. **ステータスカード** — TODO / In Progress / Review / Done の件数
2. **品質ゲート通過率** — ドーナツチャート
3. **Judge スコア推移** — 折れ線チャート（直近30件）
4. **Subagent 評価軸レーダー** — completeness / accuracy / clarity の3軸レーダーチャート
5. **改善インサイト** — 下記の分析ロジックで自動生成
6. **会話統計** — セッション数・発言数・頻出フレーズ

### 2.3 改善インサイト分析ロジック

Case Bank の judge データから以下の3分析を自動実行し、ダッシュボードに表示する。

**軸別弱点分析**:
- Subagentごとに completeness / accuracy / clarity の平均スコアを算出
- 最も低い軸を「弱点」として赤色バーで強調表示
- 全軸をバーチャートで可視化（0〜1.0 スケール）

**低スコアケース分析**:
- `judge.total < 0.7` のケースを抽出
- タスク概要・担当Subagent・judge_comment を表示（上位5件）
- 共通の失敗原因を可視化

**改善アクション提案**:
- 全Subagentの軸別平均が `< 0.9` の軸を検出
- 軸ごとに定義された改善アクションを自動提示:
  - **網羅性（completeness）**: 調査範囲の事前定義・チェックリスト活用
  - **正確性（accuracy）**: 公式ドキュメントURL添付必須・推測と事実の区別
  - **明瞭性（clarity）**: フォーマット統一・読み手ペルソナの指示明示

### 2.4 スコア正規化

judge データは 0〜10 スケール（旧形式）と 0〜1.0 スケール（新形式）が混在し得る。
ダッシュボード生成時に `completeness / accuracy / clarity` の値が `> 1.0` であれば
10で割って 0〜1.0 に正規化する。`total` は常に 0〜1.0 前提。

## 3. 報告形式

```
✅ ダッシュボードを生成しました！

ファイル: .companies/{org-slug}/docs/secretary/dashboard.html
サイズ: {N} KB

GitHub Pages で公開する場合:
  リポジトリ設定 → Pages → Source: main ブランチ / docs フォルダ
  トップURL:       https://{user}.github.io/{repo}/
  ダッシュボード:  https://{user}.github.io/{repo}/secretary/dashboard.html

  ※ トップURLにアクセスすると自動でダッシュボードにリダイレクトされます
  ※ docs/index.html は /company-dashboard 実行時に自動更新されます
```
