---
name: company-handover
description: >
  Claude Codeとの全活動をナレッジポータルとして可視化する。
  プロジェクト業務・基盤構築・意思決定履歴・暗黙知を自動収集し、
  検索・フィルタ可能なHTMLとしてGitHub Pagesに公開する。
  「引き継ぎ」「ナレッジポータル」「handover」「活動履歴」
  「/company-handover」と言われたときに使用する。
---

# ナレッジポータル生成 Skill

Claude Codeとの全活動履歴（PJ業務・Skill追加・MCP導入・壁打ち等）を
収集・分類し、検索可能なHTMLポータルとしてGitHub Pagesに公開する。

## 1. 起動

1. `.companies/.active` から org-slug を取得
2. `bash .claude/hooks/generate-handover-data.sh {org-slug}` を実行（data.json生成）
3. `bash .claude/hooks/generate-handover-html.sh {org-slug}` を実行（HTML生成）
4. 生成結果をコミットし、GitHub Pages の URL を報告する

## 2. データ収集（generate-handover-data.sh）

### 2.1 データソース

| ソース | 収集内容 | カテゴリ判定 |
|--------|---------|-------------|
| `git log --all` | 全コミット履歴 | コミットメッセージの type + [org-slug] タグ |
| `.task-log/*.md` | タスク実行ログ | mode・subagent名・成果物パス |
| `.conversation-log/*.md` | 会話ログ | Human発言から依頼意図抽出 |
| `.case-bank/index.json` | 成功/失敗パターン | reward スコア付き |
| `~/.claude/projects/.../memory/feedback_*.md` | 教訓・ルール | feedback type のメモリ |
| `.session-summaries/*.json` | セッション統計 | ツール使用状況 |
| `gh issue list / gh pr list` | GitHub Issues/PRs | ラベルで分類 |

### 2.2 自動カテゴリ分類

全エントリを以下の5カテゴリに自動分類する:

| カテゴリ | 判定ロジック |
|----------|-------------|
| **project** | コミットに [org-slug] タグあり、かつ docs/ 配下の変更 |
| **platform** | skills/ agents/ hooks/ の変更、またはSKILL.md関連コミット |
| **organization** | masters/ の変更、/company-admin 経由のタスク |
| **learning** | /company-evolve, case-bank, quality-gate 関連 |
| **discussion** | conversation-log にあるがtask-logにないセッション |

### 2.3 出力

```
docs/handover/data.json
```

## 3. HTML生成（generate-handover-html.sh）

### 3.1 出力ファイル

| 出力先 | 内容 |
|--------|------|
| `docs/handover/index.html` | ナレッジポータル（タブ式SPA） |
| `docs/index.html` | トップページに緑枠カードを追加 |

### 3.2 ポータル構成（5タブ）

**全体年表タブ**: 全カテゴリの活動を時系列で表示。月ごとにグルーピング。
**PJ業務タブ**: プロジェクト関連の成果物・タスク・Issue。
**基盤構築タブ**: Skill追加・MCP導入・Hook設定・Agent変更の履歴テーブル。
**判断履歴タブ**: feedback memoryと高reward Case Bankエントリの一覧。経緯・理由付き。
**Tipsタブ**: Case Bank reward≥0.8 のナレッジ。暗黙知・注意事項。

### 3.3 HTML機能

- **キーワード検索**: 全タブ横断。data.json をクライアントサイドでフィルタ
- **カテゴリフィルタ**: project / platform / organization / learning / discussion
- **期間フィルタ**: 月選択のドロップダウン
- **ダークモード対応**: 既存ダッシュボードとデザイン統一
- **URLハッシュ連動**: `#platform` でタブ直リンク
- **5分ごと自動リフレッシュ**: 他ポータルと統一

## 4. 実行フロー

### 4.1 スクリプト実行

```bash
bash .claude/hooks/generate-handover-data.sh {org-slug}
bash .claude/hooks/generate-handover-html.sh {org-slug}
```

### 4.2 Gitワークフロー

`docs/` 配下（GitHub Pages配信用）を更新するため、
mainブランチに直接コミットする。`/company-dashboard` と同じ運用方式。

1. `git add docs/handover/ docs/index.html`
2. `git commit -m "chore: ナレッジポータル更新 [{org-slug}]"`
3. `git push origin main`

## 5. 報告形式

```
ナレッジポータルを生成しました！

ファイル:
  データ: docs/handover/data.json ({N}件のエントリ)
  ポータル: docs/handover/index.html ({N} KB)

カテゴリ別件数:
  PJ業務: {N}件 | 基盤構築: {N}件 | 組織管理: {N}件
  学習: {N}件 | 壁打ち: {N}件

GitHub Pages URL:
  トップ:    https://{user}.github.io/{repo}/
  ポータル:  https://{user}.github.io/{repo}/handover/
```

## 6. 利用シーン

| タイミング | 操作 |
|-----------|------|
| 新メンバー参画時 | `/company-handover` で最新ポータル生成→URLを共有 |
| 週次/月次の振り返り | `/company-handover` で活動全体を俯瞰 |
| 顧客への活動報告 | ポータルURLを共有（カテゴリフィルタでPJ業務のみ表示） |
| 自分の作業記録として | 「あの判断いつだっけ」をポータル検索で即座に特定 |
