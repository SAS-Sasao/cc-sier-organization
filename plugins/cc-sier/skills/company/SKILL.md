---
name: company
description: >
  SIer業務の仮想組織スキル。/company で秘書に話しかける。
  マスタ駆動で部署・ロールを動的に編成。Agent Teamsで並列作業を実行。
  「秘書」「TODO」「管理」「壁打ち」「相談」「組織」「組織切替」「別の組織」と言われたとき、
  または /company を実行したときに使用する。
---

# CC-SIer メインSkill

このSkillは SIer業務の仮想組織を運営するコアロジックです。
マスタデータを参照し、作業依頼に応じて Subagent や Agent Teams を動的に編成します。

---

## 1. 検出とモード判定

### 1.1 組織の存在チェック

```
IF .companies/ が存在しない         → 組織選択UI（セクション1.3へ）
IF .companies/ が存在する           → 組織選択UI（セクション1.3へ）
```

### 1.2 ユーザー意図の判定

ユーザーの発話から以下を判定します:

| 意図 | キーワード | 遷移先 |
|------|-----------|--------|
| 秘書への依頼 | TODO, タスク, 壁打ち, 相談, メモ, ダッシュボード | 運営モード → 秘書 Subagent |
| 特定部署への依頼 | マスタのトリガーワードと照合 | 運営モード → 該当部署 |
| 部署追加 | 「〜室を作って」「部署を追加」 | 部署追加フロー（セクション4） |
| マスタ管理 | 「マスタ管理」「ロール追加」「組織変更」 | `/company-admin` Skill への誘導 |
| 組織切替 | 「組織切替」「別の組織」「組織を変える」 | 組織選択UI（セクション1.3へ） |
| 状態確認 | 「組織の状態」「ダッシュボード」 | ダッシュボード表示（3.5） |
| アプリ切り出し | 「リポジトリを作って」「アプリを切り出し」「spawn」 | `/company-spawn` Skill への誘導 |

### 1.3 組織選択UI

`/company` 起動時に以下の分岐で表示します:

**ケース A: `.companies/.active` が存在する**

> `.active` はローカル設定ファイル（.gitignore で除外）のため、各ユーザーが独立して組織を切り替え可能。

```
現在のアクティブ組織: {active_org}

どうしますか？
A) {active_org} で作業を続ける  → 運営モード（セクション3へ）
B) 別の組織で作業する           → 組織一覧を表示 → 選択 → .active 更新 → 運営モード
C) 新しい組織を作成する         → オンボーディング（セクション2へ）
```

**ケース B: `.companies/` に組織ディレクトリはあるが `.active` がない**
```
既存の組織が見つかりました。

{組織一覧を表示}

どの組織で作業しますか？ → 選択 → .companies/.active に書き込み → 運営モード
```

**ケース C: `.companies/` が存在しない、または組織ディレクトリが 0 件**
```
組織がまだありません。新しく作成します。
→ オンボーディング（セクション2へ）
```

---

## 2. オンボーディング（初回セットアップ）

組織が存在しない場合、または新規作成を選んだ場合に実行します。4問のヒアリングで組織を初期化します。

### 2.1 ヒアリング

**Q0: 組織名（プロジェクト名）を教えてください。**
> 例: A社DWH構築プロジェクト、社内標準化推進
> 入力をもとに org-slug を自動生成（kebab-case）し、ユーザーに確認します。
> 例: "A社DWH構築" → `a-sha-dwh`

**Q1: あなたのお名前（ニックネーム）を教えてください。**
> 秘書がオーナーを呼ぶときの名前に使います。

**Q2: どんな事業・業務をしていますか？**
> 例: SIer、受託開発、データ基盤構築、社内IT

**Q3: 最初に立ち上げたい部署はありますか？**
> デフォルトでは秘書室のみ起動します。他の部署は後から追加できます。
> 選択肢: [秘書室のみ（推奨）/ 秘書室 + PM室 / 秘書室 + アーキテクチャ室 / カスタム]

### 2.2 マスタファイル生成

ヒアリング結果をもとに以下を生成します:

1. **ディレクトリ作成**:
   - `.companies/{org-slug}/masters/`
   - `.companies/{org-slug}/docs/secretary/inbox/`
   - `.companies/{org-slug}/docs/secretary/todos/`
   - `.companies/{org-slug}/docs/secretary/notes/`
   - Q3 で選択された追加部署のフォルダ

2. **マスタファイル生成**（テンプレートは `references/departments.md` を参照）:
   - `.companies/{org-slug}/masters/organization.md` — 組織名、org-slug、オーナー名、事業内容、コスト設定
   - `.companies/{org-slug}/masters/departments.md` — 秘書室（active）+ 選択された追加部署
   - `.companies/{org-slug}/masters/roles.md` — secretary + 追加部署に対応するロール
   - `.companies/{org-slug}/masters/workflows.md` — 空（後から `/company-admin` で追加）
   - `.companies/{org-slug}/masters/projects.md` — 空
   - `.companies/{org-slug}/masters/mcp-services.md` — 空

3. **CLAUDE.md 生成**（テンプレートは `references/claude-md-template.md` を参照）:
   - `.companies/{org-slug}/CLAUDE.md` — 組織ルール
   - `.companies/{org-slug}/docs/secretary/CLAUDE.md` — 秘書室ルール
   - 追加部署がある場合、各部署の CLAUDE.md

4. **`.companies/.active` に org-slug を書き込む**

5. **完了メッセージ**:
   ```
   組織「{org_name}」のセットアップが完了しました！
   組織ID: {org-slug}

   オーナー: {owner_name}
   事業: {business}
   アクティブ部署: 秘書室{, 追加部署名}

   「/company」で秘書がお待ちしています。
   部署やロールの追加は「/company-admin」で行えます。
   ```

---

## 3. 運営モード

マスタが存在する場合の通常運用フローです。
アクティブ組織のパスは常に `.companies/{org-slug}/` を基点とします。

### 3.0 ユーザー識別

起動時に `git config user.name` を実行してユーザー名を取得し、`{operator}` 変数として保持する。
取得できない場合は `anonymous` をデフォルトとする。

```bash
git config user.name || echo "anonymous"
```

`{operator}` はコミットメッセージ、タスクログ、PR本文に記録される。

### 3.1 状態読み込み

起動時に以下のマスタを読み込みます:

1. `.companies/{org-slug}/masters/organization.md` — コスト設定、組織ポリシー
2. `.companies/{org-slug}/masters/departments.md` — 部署一覧とトリガーワード
3. `.companies/{org-slug}/masters/workflows.md` — 定義済みワークフロー

### 3.2 依頼内容の分析とルーティング

**Step 1: ワークフロー照合**
- `masters/workflows.md` のトリガーと依頼を照合
- 一致するワークフローがあれば、そのワークフローの実行方式に従う

**Step 2: 部署照合**（ワークフロー不一致の場合）
- `masters/departments.md` のトリガーワードと照合
- 一致する部署が見つかったら、その部署の対応 Subagent を確認

**Step 3: 実行モード判定**

| 条件 | 実行モード | アクション |
|------|-----------|-----------|
| ワークフロー一致 + subagent | Subagent委譲 | 該当 Subagent を名前指定で起動 |
| ワークフロー一致 + agent-teams | Agent Teams | チーム編成して並列実行 |
| 部署一致 + 小規模作業 | 秘書が直接対応 | secretary Subagent で処理 |
| 部署一致 + 専門作業 | Subagent委譲 | 部署の対応 Subagent を起動 |
| 部署一致 + 大規模並列 | Agent Teams | Agent Teams適性を確認して編成 |
| どれにも一致しない | 秘書対応 | secretary Subagent で汎用対応 |

### 3.3 Subagent 呼び出し

```
「{agent-name}エージェントを使って、{依頼内容}を実行してください。
 成果物は .companies/{org-slug}/docs/{dept}/{path} に保存してください。」
```

対応する Subagent ファイルは `.claude/agents/{agent-name}.md` にあります。

### 3.4 Agent Teams 編成

Agent Teams を使用する場合（`references/agent-templates.md` を参照）:

1. ワークフローのチーム構成を確認
2. `masters/roles.md` から各ロールのテイメイト指示テンプレートを取得
3. チームリード（通常は secretary）を指定し、**ブランチ名を生成**（詳細は 3.6 参照）
4. 各テイメイトに「ブランチ `{branch-name}` 上で作業すること」を明示して並列実行
5. 結果を統合して `.companies/{org-slug}/` 配下に保存
6. チームリードがまとめてコミット → PR 作成（3.6 を参照）

**コスト管理**: `masters/organization.md` の `COST_AWARENESS` 設定に従う:
- `conservative`: Agent Teams は明示指示時のみ。デフォルトは Subagent
- `balanced`（推奨）: workflows.md の実行方式に従う
- `aggressive`: 並列可能な場面では積極的に Agent Teams 使用

### 3.5 ダッシュボード表示

「ダッシュボード」「組織の状態」と言われた場合:

```
## CC-SIer ダッシュボード

### 組織情報
- 組織名: {org_name}
- 組織ID: {org-slug}
- オーナー: {owner_name}
- 事業: {business}
- コスト設定: {cost_awareness}

### アクティブ部署
| 部署 | ステータス | Subagent数 |
|------|----------|-----------|
| {各部署の情報} |

### 今日のTODO
{.companies/{org-slug}/docs/secretary/todos/YYYY-MM-DD.md の内容}

### 最近の活動
{直近の成果物やメモ}
```

### 3.6 Gitワークフロー

ファイル生成を伴う作業の前後で実行します。詳細は `references/git-workflow.md` を参照。

**ファイル生成を伴わない作業（壁打ち、ダッシュボード表示、口頭相談等）では実行しません。**

**作業前:**
1. 現在のブランチを確認（main でない場合は警告）
2. 未コミットの変更がないか確認（あれば stash するか警告）
3. ブランチ作成: `{org-slug}/{type}/{YYYY-MM-DD}-{summary}`
4. ブランチに切り替え

**作業後:**
1. **LLM-as-Judge 評価**: 成果物が `docs/` 配下にある場合、secretary.md の「タスク完了後の品質評価」手順に従い、completeness / accuracy / clarity の3軸評価を実行し `.task-log/{task-id}.md` に `## judge` セクションを追記する（詳細は secretary.md 参照）。成果物がない場合はスキップ。
2. `git add .companies/{org-slug}/`（組織ディレクトリのみ）
3. `git commit -m "{type}: {概要} [{org-slug}] by {operator}"`
4. `git push origin {branch-name}`
5. PR 作成（gh CLI）: タイトルと本文に組織名・変更概要を含める
6. PR の URL をユーザーに報告
7. `git checkout main` で元のブランチに戻る

### 3.7 タスクログと Issue 作成

ファイル生成を伴うタスクの実行過程を記録し、完了時に GitHub Issue として可視化する。
詳細なテンプレートは `references/task-log-template.md` を参照。

**スキップ条件**: Gitワークフロー（3.6）と同じ。ファイル生成を伴わない作業（壁打ち、ダッシュボード等）ではログ作成・Issue作成ともにスキップ。

**タスクログの記録フロー**:

1. **タスク受付時**: `.companies/{org-slug}/.task-log/{task-id}.md` を作成（task-id: `YYYYMMDD-HHMMSS-{概要slug}`）
2. **秘書の判断時**: 実行モード・アサインロール・判断理由をログに記録
3. **Subagent委譲 / Agent Teams編成時**: 委譲先・指示内容をログに記録
4. **エージェント作業完了時**: 各Subagentの作業サマリー・成果物パスをログに追記
5. **タスク全体完了時**: ステータスを completed に更新

**Issue 作成フロー**（タスク完了時に実行）:

1. `.task-log/{task-id}.md` を読み込む
2. `references/task-log-template.md` の Issue テンプレートに従い本文を組み立てる
3. ラベルを決定（`references/task-log-template.md` のラベル決定ルール参照）
4. `gh issue create` で Issue 作成（gh CLI が使えない場合はスキップ）
5. `.task-log/{task-id}.md` に issue_number を追記

**.task-log/ の配置**: `.companies/{org-slug}/.task-log/` に配置。Git管理対象としてPRに含める。docs/ 配下には置かない（成果物の可読性を保つ）。

---

## 4. 部署の動的追加

ユーザーが「〜室を追加して」と依頼した場合の簡易フロー。
詳細な管理操作は `/company-admin` Skill に誘導します。

### 4.1 簡易追加フロー

1. `references/departments.md` からテンプレートを参照
2. 部署名、役割、トリガーワードをヒアリング
3. 以下を実行:
   - `masters/departments.md` にエントリ追加
   - `masters/roles.md` に対応ロール追加
   - `.companies/{org-slug}/docs/{dept}/` フォルダ作成
   - `.companies/{org-slug}/docs/{dept}/CLAUDE.md` 生成
   - `.companies/{org-slug}/CLAUDE.md` の部署一覧を更新
   - `.claude/agents/{role}.md` を生成（`references/agent-templates.md` のテンプレートから）

### 4.2 高度な管理操作への誘導

以下の操作は `/company-admin` を案内します:

- ロールの変更・削除
- ワークフローの追加・変更
- 組織ポリシーの変更
- マスタの整合性チェック

```
この操作には詳細な設定が必要です。
「/company-admin」でマスタ管理モードを起動してください。
```

---

## 5. 組織管理

### 5.1 組織一覧の表示

`.companies/` 直下のディレクトリを列挙し、各組織の `organization.md` からオーナー名・事業を読み取って表示します:

```
利用可能な組織:
1. {org-slug-1}  オーナー: {name}  事業: {business}
2. {org-slug-2}  オーナー: {name}  事業: {business}
...
```

### 5.2 組織の切り替え

1. ユーザーが番号または org-slug を選択
2. `.companies/.active` を選択した org-slug で上書き
3. 切り替え先の組織のマスタを読み込み直して運営モードへ

### 5.3 マイグレーション（既存 `.company/` からの移行）

`.company/` が存在する場合:

1. `organization.md` のオーナー名から org-slug を推定し、ユーザーに確認
2. `.company/` を `.companies/{org-slug}/` に移動
3. `.companies/.active` を作成して org-slug を書き込む
4. 完了を報告

詳細な移行手順は `references/git-workflow.md` のマイグレーションセクションを参照。

---

## 参照ファイル一覧

| ファイル | 用途 | 参照タイミング |
|---------|------|-------------|
| `references/departments.md` | 部署テンプレート集 | 部署追加時 |
| `references/claude-md-template.md` | CLAUDE.md 生成テンプレート | オンボーディング時 |
| `references/git-workflow.md` | Gitワークフロー詳細定義 | ファイル生成を伴う作業の前後 |
| `references/workflow-definitions.md` | ワークフロー定義集 | 作業依頼受付時 |
| `references/agent-templates.md` | Subagent 生成テンプレート | Subagent/Agent Teams 編成時 |
| `references/sier-templates.md` | SIer業務特化テンプレート | ドキュメント生成時 |
| `references/master-schemas.md` | マスタスキーマ・バリデーション | マスタCRUD操作時 |
| `references/task-log-template.md` | タスクログ・Issueテンプレート | タスク実行時・完了時 |
