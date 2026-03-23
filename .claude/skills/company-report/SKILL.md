---
name: company-report
description: >
  組織の活動サマリーレポートを生成する。
  指定期間のセッションログ・タスクログ・成果物・GitHub Issueを統合して
  AIが要約し、mdファイル保存とGitHub Issue投稿を行う。
  「レポート」「週次レポート」「月次振り返り」「日次サマリー」「進捗まとめ」
  「/company-report」と言われたときに使用する。
---

# CC-SIer レポートSkill

指定期間の活動を5つの情報源から収集し、AI要約してレポートを生成します。

---

## 1. 起動時の確認と期間解釈

### 1.1 組織とオペレーター取得

1. `.companies/.active` を読み取り org-slug を取得
2. `git config user.name` でオペレーター名を取得（取得できなければ `anonymous`）
3. 今日の日付を取得

### 1.2 期間引数の解釈

ユーザーの発話から期間を判定する。明示がない場合は `today` とする。

| 発話例 | 解釈 | 対象範囲 |
|--------|------|---------|
| 「今日のレポート」「/company-report」 | `today` | 当日のみ |
| 「今週のレポート」「週次」 | `week` | 過去7日（当日含む） |
| 「今月のレポート」「月次」 | `month` | 当月1日〜当日 |
| 「3/19〜3/21」など具体的日付 | カスタム | 指定範囲 |

---

## 2. データ収集

以下の5ソースを順に読み込む。読み込みに失敗したソースはスキップして続行する。

### 2.1 .session-summaries/（最優先・軽量）

```
対象: .companies/{org-slug}/.session-summaries/*.json
期間フィルタ: ファイル名の日付プレフィックスで絞り込む
収集内容:
  - 各セッションのツール実行数・種別内訳
  - 書き込みファイルのパス一覧
  - セッション数合計
```

Bash例（today の場合）:
```bash
TODAY_COMPACT=$(date '+%Y%m%d')
ls .companies/{org-slug}/.session-summaries/${TODAY_COMPACT}*.json 2>/dev/null
```

### 2.2 .task-log/（物語ログ）

```
対象: .companies/{org-slug}/.task-log/*.md
期間フィルタ: frontmatter の started フィールドで絞り込む
収集内容:
  - 完了タスクのリクエスト原文（status: completed）
  - 実行モード（subagent / agent-teams / direct）
  - 成果物パス一覧
  - 進行中タスク（status: in-progress）
```

### 2.3 docs/ 配下の成果物

```
コマンド例:
  git log --since="{START_DATE}" --until="{TODAY}" \
    --name-only --pretty=format: \
    -- ".companies/{org-slug}/docs/" \
    | grep -v '^$' | sort -u
```

### 2.4 GitHub Issues

```
コマンド例:
  gh issue list \
    --label "org:{org-slug}" \
    --state all \
    --json number,title,state,createdAt,closedAt,labels \
    --limit 50
```

`interaction-log` ラベルのものは除外する（ノイズになるため）。

### 2.5 .conversation-log/（会話ログ）

```
対象: .companies/{org-slug}/.conversation-log/*.md
期間フィルタ: ファイル名の日付プレフィックスで絞り込む
収集内容:
  - 各セッションの Human 発言（依頼内容の全量リスト）
  - ファイル生成を伴わなかったやり取り（壁打ち・相談等）の把握
  - セッションごとの会話トピック・統計情報
```

Bash例（today の場合）:
```bash
ls .companies/{org-slug}/.conversation-log/{TODAY}*.md 2>/dev/null
```

各ファイルから `## 👤 Human` セクションの内容を抽出し、依頼内容リストを構築する。
`## 統計` セクションからセッションの発言数・ツール実行数も取得する。

---

## 3. AI要約（レポート生成）

収集したデータを以下の構成でレポートにまとめる。

```
# {org-slug} 活動レポート — {期間ラベル}

> 生成日時: {DATETIME} | 生成者: {operator} | 期間: {START_DATE} 〜 {TODAY}

## エグゼクティブサマリー

（3〜5文: 何を達成したか / 主な判断・決定 / 未完了の懸念点）

## 活動統計

| 指標 | 値 |
|------|-----|
| セッション数 | N 回 |
| ツール実行数（合計） | N 回 |
| 作成・編集ファイル数 | N 件 |
| 完了タスク数 | N 件 |
| オープンIssue数 | N 件 |
| クローズIssue数 | N 件 |

## 完了タスク

（.task-log から status: completed のものを列挙）
- [実行モード] リクエスト概要 → 成果物: パス

## 進行中タスク

（status: in-progress のもの）
- [実行モード] リクエスト概要

## 作成・更新された成果物

（docs/ の変更ファイルを部署ごとにグルーピング。
 月次で件数が多い場合は上位3部署のみ詳細表示）

## Issue 動向

### クローズされたIssue（期間内）
- #{番号} タイトル

### 新規オープンのIssue（期間内）
- #{番号} タイトル

## 会話トピック

（.conversation-log/ から抽出した全依頼内容。タスクログに記録されなかった
 壁打ち・相談・軽微な修正依頼も含む）

### セッション別の依頼内容
- **セッション {session_short}**（{human_count}発言 / {assistant_count}応答 / {tool_count}ツール実行）
  - {依頼内容1}
  - {依頼内容2}
  - ...

{各セッションを繰り返し}

### ファイル生成を伴わなかったやり取り
（壁打ち・相談・質問応答など、task-log に記録されなかった会話）
- {やり取りの概要}

## 次のアクション候補

（タスクログ・Issueのオープン状況・未完成成果物から優先度順に3〜5件）
1. アクション（根拠: 理由）

---
_このレポートは /company-report Skill によって自動生成されました_
_情報源: .session-summaries/ | .task-log/ | docs/ | GitHub Issues | .conversation-log/_
```

---

## 4. 出力

### 4.1 mdファイルへの保存

```
保存先: .companies/{org-slug}/docs/secretary/reports/{TODAY}-{period}.md
ディレクトリが存在しない場合は mkdir -p で作成する。
```

### 4.2 GitHub Issue への投稿

```bash
gh label create "company-report" --color "008672" --description "活動レポート" --force
gh label create "org:{org-slug}" --color "7057ff" --description "組織: {org-slug}" --force

gh issue create \
  --title "[{org-slug}] 活動レポート {period_label} ({TODAY})" \
  --body "{レポート本文}" \
  --label "company-report" \
  --label "org:{org-slug}"
```

`gh` が未認証の場合は Issue 投稿をスキップし、mdファイルのみ保存する。

### 4.3 ユーザーへの報告

```
レポートを生成しました！

期間: {START_DATE} 〜 {TODAY}
ファイル: .companies/{org-slug}/docs/secretary/reports/{TODAY}-{period}.md
Issue: {Issue URL}

{エグゼクティブサマリーの内容を再掲}
```

---

## 5. Gitワークフロー

レポートファイルの保存後、Gitワークフローを実行する。
詳細は `.claude/skills/company/references/git-workflow.md` を参照。

```
ブランチ: {org-slug}/docs/{TODAY}-report-{period}
コミット: docs: {period}レポートを生成 [{org-slug}] by {operator}
```

---

## 6. 継続学習の自動実行（レポート生成後）

レポートの生成・Issue投稿・Gitワークフローがすべて完了したら、
自動的に `/company-evolve` Skill を起動して継続学習を実行する。

レポートの対象期間（today / week / month）を引き継いで学習する。
学習完了後、学習結果のサマリーをレポートのGitHub Issueにコメントとして追記する。
