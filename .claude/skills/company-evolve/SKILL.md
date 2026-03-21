---
name: company-evolve
description: >
  過去のやり取りログからユーザーの好みとパターンを抽出し、
  エージェントメモリ（MEMORY.md）とワークフローを自動更新する継続学習Skill。
  「学習して」「好みを覚えて」「進化させて」「/company-evolve」と言われたとき、
  または /company-report の完了後に自動起動したときに使用する。
---

# CC-SIer 継続学習Skill

過去のログを解析して3種類のパターンを抽出し、確認なしで各メモリファイルに自動書き込みします。

---

## 1. 起動時の準備

1. `.companies/.active` から org-slug を取得
2. `git config user.name` でオペレーター名を取得（取得できなければ `anonymous`）
3. 今日の日付を取得
4. 学習対象期間を決定（デフォルト: 直近30日）
   - `/company-report` からの自動呼び出し時はそのレポート期間を引き継ぐ
   - 手動実行時は直近30日を使う

---

## 2. データ収集

以下のファイルをすべて読み込む。

```
A) .companies/{org-slug}/.session-summaries/*.json
   → セッション単位のtool実行数・種別・書き込みファイル一覧

B) .companies/{org-slug}/.task-log/*.md
   → タスクのrequest原文・実行モード・使用Subagent・成果物パス・status

C) .companies/{org-slug}/.interaction-log/*.md
   → tool実行の生ログ（Bashコマンド・ファイルパス・検索クエリ）
```

---

## 3. パターン抽出と学習（3ドメイン）

### 3.1 出力スタイルの好み抽出

task-log の `request` フィールドと interaction-log を照合し、以下を検出する。

| 検出条件 | 抽出する好み |
|---------|------------|
| requestに「ASCII」「図」「ダイアグラム」が3回以上 | `ASCII図を必ず添付する` |
| requestに「比較」「テーブル」「表で」が3回以上 | `比較表をセットで出力する` |
| requestに「短く」「簡潔に」が3回以上 | `簡潔な出力を好む` |
| requestがほぼ日本語のみ | `日本語で出力する` |
| Write後にEditが連続するパターンが多い | `一発で正確な出力を求める傾向` |

**書き込み先:** `.claude/agent-memory/secretary/MEMORY.md`

書き込むセクション:
```markdown
## 出力スタイルの好み（{TODAY} 学習・{N}セッション分析）

- {抽出した好み}（根拠: {検出回数}回のパターン）
```

### 3.2 よく使うSubagentのルーティング先読み

task-log の全件から以下を集計する。

1. **Subagent使用頻度ランキング（上位3件）**
2. **キーワード→委譲先の対応表**
   - request 冒頭キーワードと実際に使われたSubagentの対応

**書き込み先:** `.claude/agent-memory/secretary/MEMORY.md`

書き込むセクション:
```markdown
## よく使うSubagentと先読みパターン（{TODAY} 学習）

### 頻度ランキング
1. {agent-name}（{N}回使用、{主な用途}）
2. {agent-name}（{N}回使用、{主な用途}）
3. {agent-name}（{N}回使用、{主な用途}）

### キーワード→委譲先の対応
- 「{キーワード}」→ {agent-name}（{N}/{M}回）
```

### 3.3 繰り返しパターンのワークフロー自動登録

task-log の request を比較し、**類似したリクエストが3回以上** 繰り返されているパターンを検出する。

類似判定の基準:
- request の冒頭15文字が一致する
- 同じSubagentへの委譲を含む
- 同じ成果物ディレクトリへの書き込みを含む

検出したパターンを `.companies/{org-slug}/masters/workflows.md` に自動追記する。

追記形式:
```markdown
## wf-{slug}

- **名称**: {パターン名}（自動検出）
- **トリガー**: [{検出したキーワード}]
- **実行方式**: subagent
- **ロール**: {使われたSubagent}
- **検出日**: {TODAY}
- **検出根拠**: {N}回の繰り返しパターン
- **成果物**: `.companies/{org-slug}/{書き込み先ディレクトリ}`
```

ワークフロー追記後、Gitワークフローを実行する。
詳細は `.claude/skills/company/references/git-workflow.md` を参照。

```
ブランチ: {org-slug}/admin/{TODAY}-auto-workflow-{slug}
コミット: feat: {パターン名}ワークフローを自動登録 [{org-slug}] by {operator}
```

---

## 4. MEMORY.md の更新ルール

- MEMORY.md が存在しない場合は新規作成する
- 既存の同セクションは**上書き**する（追記ではなく置換）
- 各セクションは最大20行以内に収める（200行制限への対応）
- 上位5件のみ残し、古いエントリは新しいものに置き換える

ファイルパス:
```
secretary（ユーザー固有・全組織で永続）:
  .claude/agent-memory/secretary/MEMORY.md

各Subagent（プロジェクト固有）:
  .claude/agent-memory/{agent-name}/MEMORY.md
```

---

## 5. ユーザーへの報告

```
学習が完了しました！

## 今回の学習結果

### 出力スタイル（{N}パターン検出）
- {適用した好み1}
- {適用した好み2}

### ルーティング（{N}件更新）
- よく使うSubagent上位3件を先読みリストに登録

### ワークフロー（{N}件自動登録）
- {ワークフロー名}（{N}回の繰り返しを検出）
  PR: {PR URL}

次回のセッションから自動的に適用されます。
```

---

## 6. 注意事項

- `masters/workflows.md` への書き込みは必ず Gitワークフロー（ブランチ→PR）を通す
- MEMORY.md への書き込みは Git 管理しない
- session-summaries が0件の場合はスキップしてユーザーに通知する
- 検出パターンが1件もない場合は「学習対象なし」と報告して終了する
