---
name: company-spawn
description: >
  組織の設計成果物をもとにアプリケーションリポジトリを新規作成する。
  設計書・ADRのコピー、Subagentのエクスポート、初期構成の生成を行う。
  「リポジトリを作って」「アプリを切り出して」「実装リポを作りたい」
  「新しいリポジトリ」「spawn」と言われたときに使用する。
---

# CC-SIer アプリリポジトリ切り出しSkill

組織の設計成果物をもとに、アプリケーション用の新規GitHubリポジトリを作成します。
設計書・ADRのコピー、Subagentのエクスポート、技術スタックに応じたスキャフォールド生成を行います。

---

## 1. 前提確認

起動時に以下を確認します:

```
1. .companies/.active からアクティブ組織の org-slug を取得
2. git config user.name から operator を取得（取得できない場合は anonymous）
3. masters/projects.md を読み込み、関連プロジェクト情報を確認
4. gh CLI が利用可能か確認（使えない場合はエラーメッセージを出して終了）
```

gh CLI が使えない場合:
```
エラー: /company-spawn の実行には GitHub CLI（gh）が必要です。
gh をインストールし、gh auth login で認証してください。
```

---

## 2. ヒアリング

以下の6問でリポジトリ情報を収集します:

**Q1: リポジトリ名は？**
> 例: a-sha-dwh-app, jutaku-frontend
> kebab-case で入力してください

**Q2: リポジトリの説明は？**
> 例: A社DWH構築プロジェクトのdbt + Terraformリポジトリ

**Q3: 技術スタックは？**
> 選択肢から選ぶか、自由入力してください
> [Python + dbt / Python + FastAPI / Terraform / React + TypeScript / Django / 汎用 / カスタム]

**Q4: コピーしたい設計成果物を選んでください**
> `.companies/{org-slug}/docs/` 配下のファイル・フォルダを一覧表示
> 複数選択可能（カンマ区切り or 番号指定）
> 例: 1, 3, 5 または docs/data/models/medallion/, docs/architecture/adrs/

**Q5: コピーしたいSubagentを選んでください**
> `.claude/agents/` 配下のSubagent一覧を表示
> 複数選択可能
> 例: data-architect, cloud-engineer, test-engineer
> 推奨: 技術スタックに関連するSubagentを自動提案する

**Q6: 公開設定は？（public / private）**

---

## 3. 実行計画の提示と承認

ヒアリング結果を整理して以下を表示し、ユーザーの承認を得る:

```
リポジトリ「{repo-name}」を作成します。

【基本情報】
- リポジトリ名: {repo-name}
- 説明: {description}
- 公開設定: {visibility}
- 技術スタック: {tech-stack}
- 作業者: {operator}

【コピーする設計成果物】
{選択された成果物の一覧（ファイルパスと概要）}

【コピーするSubagent】
{選択されたSubagentの一覧}
※ パスは新リポ用に自動書き換えされます

【生成されるファイル】
- CLAUDE.md（プロジェクト概要 + 設計の出自情報）
- docs/design/origin.md（トレーサビリティ）
- docs/design/{コピーした設計成果物}
- .claude/agents/{コピーしたSubagent}
- {技術スタックに応じたスキャフォールド}
- README.md
- .gitignore

実行してよいですか？
```

---

## 4. 実行（devops-coordinator に委譲）

承認後、devops-coordinator Subagent に以下を委譲する:

```
「devops-coordinator エージェントを使って、以下の仕様でアプリケーションリポジトリを
作成してください。

リポジトリ名: {repo-name}
説明: {description}
公開設定: {visibility}
技術スタック: {tech-stack}
作業者: {operator}

cc-sier情報:
- cc-sierリポジトリURL: {cc-sier-repo-url}（git remote get-url origin で取得）
- 組織: {org-slug}
- 現在のコミットハッシュ: {commit-hash}（git rev-parse HEAD で取得）

コピーする設計成果物（cc-sier内のパス）:
{成果物パスの一覧}

コピーするSubagent（cc-sier内のパス）:
{Subagentパスの一覧}

実行手順:
1. 現在のディレクトリの親ディレクトリに移動（cd ..）
2. gh repo create {repo-name} --{visibility} --clone --description "{description}"
3. cd {repo-name}
4. 技術スタックに応じたスキャフォールド生成
5. docs/design/ ディレクトリを作成し、設計成果物をコピー
6. docs/design/origin.md を生成
7. .claude/agents/ にSubagentをコピーし、パスを書き換え
8. CLAUDE.md を生成
9. README.md を生成
10. .gitignore を生成（技術スタックに応じた内容、references/spawn-templates.md を参照）
11. git add -A && git commit -m "feat: 初期構成 — cc-sier/{org-slug} から切り出し"
12. git push origin main
13. 作成完了後、cc-sierリポジトリに戻る（cd ../cc-sier-organization）」
```

---

## 5. cc-sier側の記録更新

devops-coordinator の作業完了後、以下を実行する:

### 5.1 projects.md への追記

`masters/projects.md` に実装リポジトリ情報を追記する:
- 該当プロジェクトが存在する場合: 「実装リポジトリ」フィールドを追加
- 該当プロジェクトが存在しない場合: 新規エントリを作成

追記内容:
```markdown
## proj-{repo-name}
- **名称**: {description}
- **ステータス**: active
- **実装リポジトリ**: https://github.com/{owner}/{repo-name}
- **スポーン日**: {YYYY-MM-DD}
- **スポーン作業者**: {operator}
- **コピーした成果物**: [{成果物パスの一覧}]
- **コピーしたSubagent**: [{Subagent名の一覧}]
```

### 5.2 タスクログの記録

`.companies/{org-slug}/.task-log/` にspawnログを記録する（通常のタスクログと同じフォーマット）。

### 5.3 Gitワークフロー

```
1. ブランチ: {org-slug}/feat/{YYYY-MM-DD}-spawn-{repo-name}
2. コミット: feat: {repo-name} をスポーン [{org-slug}] by {operator}
3. PR作成
4. mainに戻る
```

### 5.4 ユーザーへの報告

```
リポジトリの作成が完了しました！

【新リポジトリ】
- URL: https://github.com/{owner}/{repo-name}
- 技術スタック: {tech-stack}
- Subagent: {コピーしたSubagent数}種

【コピーした設計成果物】
{成果物の一覧}

【次のステップ】
cd ../{repo-name} && claude
で新リポに移動してClaude Codeを起動すると、
コピーしたSubagentがそのまま使えます。

【cc-sier側の更新】
- PR: {PR URL}（projects.md にリポジトリ情報を追記）
```

---

## 6. Subagentエクスポートの詳細ルール

Subagentを新リポにコピーする際のパス書き換えルールは devops-coordinator のシステムプロンプトに定義済み。

主な書き換え:
- `.companies/{org-slug}/docs/` → `docs/`
- `.companies/{org-slug}/` → （削除）
- 「成果物格納ルール」セクション → 新リポ用に簡素化
- マルチ組織前提の記述 → 削除

---

## 参照ファイル一覧

| ファイル | 用途 | 参照タイミング |
|---------|------|-------------|
| `references/spawn-templates.md` | .gitignore・CLAUDE.md・README.mdテンプレート | リポジトリ生成時 |
