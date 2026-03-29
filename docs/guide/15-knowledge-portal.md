# 15. ナレッジポータル（/company-handover）

Claude Codeとの全活動履歴を収集・分類し、検索可能なHTMLポータルとしてGitHub Pagesに公開する機能です。

## 概要

従来のダッシュボード（`/company-dashboard`）がタスクボードの「今の状態」を表示するのに対し、ナレッジポータルは「これまでの全記録」を時系列で俯瞰できます。

プロジェクト業務だけでなく、Skill追加・MCP導入・壁打ちなどClaude Codeへの全依頼を自動分類して可視化します。

## 実行方法

```
/company-handover
```

または自然言語で:
- 「引き継ぎ資料を作って」
- 「ナレッジポータルを更新して」
- 「活動履歴を可視化して」

## データソース

| ソース | 収集内容 |
|--------|---------|
| Git ログ | 全コミット・変更ファイル |
| task-log | タスク実行ログ（subagent名・reward・judge評価） |
| conversation-log | 会話ログ（Human発言から依頼意図抽出） |
| Case Bank | 成功/失敗パターン（reward付き） |
| feedback memory | 教訓・ルール（`~/.claude/projects/.../memory/feedback_*.md`） |
| session-summaries | セッション統計（ツール使用状況） |
| GitHub Issues/PRs | ラベル・状態・作成日 |

## 自動カテゴリ分類

全エントリは以下の5カテゴリに自動分類されます:

| カテゴリ | 色 | 判定基準 |
|----------|-----|---------|
| **PJ業務** | 青 | `docs/` 配下の成果物変更、PM/設計/開発系Subagent |
| **基盤構築** | 紫 | `skills/`, `agents/`, `hooks/` の変更、MCP設定 |
| **組織管理** | 黄 | `masters/` の変更、`/company-admin` 経由のタスク |
| **品質・学習** | 緑 | `/company-evolve`, Case Bank, 品質ゲート関連 |
| **壁打ち** | 灰 | ファイル生成を伴わないセッション、相談・検討 |

## ポータルの構成

### 8つのタブ

1. **全体年表** — 全カテゴリの活動を月ごとにグルーピングして時系列表示
2. **PJ業務** — プロジェクト関連の成果物・タスク・Issueに絞り込み
3. **基盤構築** — Skill/MCP/Hook/Agentの変更をサブカテゴリ別テーブルで表示
4. **組織管理** — masters/の変更、部署・ロール・ワークフロー関連の活動
5. **品質・学習** — /company-evolve, Case Bank, 品質ゲート関連の活動
6. **壁打ち** — ファイル生成を伴わない相談・検討・議論セッション
7. **判断履歴** — feedback memoryの教訓。ルール・理由・出典を構造化表示
8. **Tips** — Case Bank reward 0.8以上の高品質ナレッジ

### 機能

- **キーワード検索**: 全タブ横断で即座にフィルタ
- **カテゴリフィルタ**: ドロップダウンで絞り込み
- **月フィルタ**: 期間指定
- **URLハッシュ連動**: `#platform` でタブ直リンク可能
- **ダークモード**: 既存ポータルとデザイン統一
- **5分ごと自動リフレッシュ**

## 出力ファイル

| ファイル | 内容 |
|--------|------|
| `docs/handover/data.json` | 構造化データ（全エントリ・判断履歴・Tips） |
| `docs/handover/index.html` | ナレッジポータルSPA |
| `docs/index.html` | トップページに緑枠カード追加 |

## GitHub Pages URL

```
トップ:     https://{user}.github.io/{repo}/
ポータル:   https://{user}.github.io/{repo}/handover/
直リンク例: https://{user}.github.io/{repo}/handover/#platform
```

## 内部スクリプト

ナレッジポータルは2つのスクリプトで構成されます:

| スクリプト | 役割 |
|-----------|------|
| `.claude/hooks/generate-handover-data.sh` | 7つのデータソースからdata.jsonを生成 |
| `.claude/hooks/generate-handover-html.sh` | data.jsonからHTMLポータルを生成 |

data.json分離方式のため、HTMLテンプレートは固定でデータだけ更新される設計です。

## 利用シーン

| シーン | 操作 |
|--------|------|
| 新メンバー参画時 | `/company-handover` → URLを共有 |
| 週次/月次の振り返り | ポータルで全体年表を確認 |
| 「あの判断いつだっけ」 | ポータルのキーワード検索で即座に特定 |
| 顧客への活動報告 | カテゴリフィルタでPJ業務のみ表示 |
