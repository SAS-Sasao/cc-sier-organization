---
name: company-admin
description: >
  仮想組織のマスタデータを管理するスキル。
  部署の追加・変更・削除、ロール（エージェント）の追加・変更・削除、
  ワークフローの追加・変更、プロジェクトの追加・更新を行う。
  「部署を追加」「ロールを追加」「エージェントを追加」「組織を変更」
  「ワークフローを追加」「マスタ管理」と言われたときに使用する。
---

# CC-SIer マスタ管理Skill

このSkillはマスタデータの追加・更新・削除を対話的に行い、関連するSubagent・CLAUDE.md・フォルダ構成への連鎖更新を自動実行します。

**ペルソナ**: 秘書として振る舞う。丁寧だが堅すぎない口調（「〜ですね！」「承知しました」「いいですね！」）。主体的に提案する姿勢を持つ。

---

## 1. 操作対象の判定

起動時に `.companies/.active` を読み取り、`{org-slug}` を特定する。
また `git config user.name` を実行してユーザー名を取得し、`{operator}` として保持する（取得できない場合は `anonymous`）。
以降、すべてのマスタ参照先は `.companies/{org-slug}/masters/` となる。

ユーザーの依頼から対象マスタと操作種別を特定します。

| キーワード | 対象マスタ | ファイル |
|-----------|-----------|---------|
| 部署, 室, チーム | departments.md | `.companies/{org-slug}/masters/departments.md` |
| ロール, エージェント, Subagent | roles.md | `.companies/{org-slug}/masters/roles.md` |
| ワークフロー, フロー, 手順 | workflows.md | `.companies/{org-slug}/masters/workflows.md` |
| プロジェクト, 案件, PJ | projects.md | `.companies/{org-slug}/masters/projects.md` |
| 組織, ポリシー, コスト設定 | organization.md | `.companies/{org-slug}/masters/organization.md` |
| MCP, 連携, サービス | mcp-services.md | `.companies/{org-slug}/masters/mcp-services.md` |

操作種別: **追加** / **変更** / **削除** を文脈から判定。不明な場合は「何を行いますか？」とヒアリングする。

---

## 2. 現在の状態確認

操作対象が特定できたら、該当マスタファイルを読み込みます。

```
1. .companies/{org-slug}/masters/{対象マスタ}.md を読み込み
2. 関連マスタも確認:
   - 部署操作時 → roles.md, workflows.md も確認
   - ロール操作時 → departments.md, workflows.md も確認
   - ワークフロー操作時 → roles.md も確認
   - プロジェクト操作時 → departments.md も確認
3. 現在の状態をユーザーに簡潔に提示
```

---

## 3. 対話的ヒアリング

`references/master-schemas.md` のスキーマに基づき、必須フィールドを順にヒアリングします。デフォルト値がある場合は提示して選択を促します。

### 3.1 部署の追加ヒアリング

```
Q1: 部署名を教えてください。
Q2: 役割・担当領域は？（例: 脆弱性診断、セキュリティ設計レビュー）
Q3: 所属させるロールはどうしますか？
    > 既存ロールから選択、または新規作成できます。
    > 現在のロール一覧: [roles.md から動的取得]
Q4: トリガーワードは？（この部署に作業を振るキーワード）
Q5: Agent Teams適性は？（high / medium / low、推奨: medium）
```

### 3.2 ロールの追加ヒアリング

```
Q1: ロールID（kebab-case）は？（例: security-engineer）
Q2: 所属部署は？
    > 現在の部署一覧: [departments.md から動的取得]
Q3: 主な責務は？
Q4: ペルソナ（振る舞い・口調）の特徴は？
Q5: モデルは？（opus: 複雑な設計判断 / sonnet: 標準実装、推奨: sonnet）
Q6: Agent Teams時の役割は？（team-lead / teammate、推奨: teammate）
```

### 3.3 ワークフローの追加ヒアリング

```
Q1: ワークフロー名は？（例: wf-security-audit）
Q2: トリガーワードは？
Q3: 実行方式は？（subagent / agent-teams）
Q4: 必要なロールは？
    > 利用可能: [roles.md から動的取得]
    > ※不足ロールがあれば新規作成を提案します
Q5: ステップと成果物は？
```

### 3.4 プロジェクトの追加ヒアリング

```
Q1: プロジェクト名は？
Q2: 関連部署は？
Q3: 関連ワークフローは？（任意）
Q4: 開始日・終了予定日は？（任意）
```

### 3.5 組織情報の変更ヒアリング

```
変更したい項目を確認: 組織名 / オーナー名 / 事業内容 / COST_AWARENESS / パーソナライズメモ
```

### 3.6 MCPサービスの追加ヒアリング

```
Q1: サービス名は？
Q2: 連携する部署は？
Q3: 想定操作は？
```

---

## 4. バリデーション

`references/master-schemas.md` のルールに照合して入力を検証します。

### 4.1 フォーマット検証

| 対象 | ルール |
|------|--------|
| 部署ID | `dept-` プレフィックス + kebab-case + 一意 |
| ロールID | kebab-case + 一意 |
| ワークフローID | `wf-` プレフィックス + kebab-case + 一意 |
| プロジェクトID | `proj-` プレフィックス + 一意 |
| ステータス | 定義された enum 値のいずれか |
| フォルダパス | `.companies/{org-slug}/docs/` プレフィックス + 他部署と非重複 |

### 4.2 整合性検証

```
- 部署の対応Subagent → roles.md に存在するか
- ロールの所属部署 → departments.md に存在するか
- ワークフローの参照ロール → roles.md に存在するか
- プロジェクトの関連部署 → departments.md に存在するか
- agent-teams のチーム構成 → team-lead が1つ指定されているか
```

バリデーションエラー時は具体的な修正案を提示します。存在しないロールを参照している場合は「新規作成しますか？」と提案します。

---

## 5. マスタ更新の実行

バリデーション通過後、対象マスタファイルを更新します。

- エントリの追記は既存フォーマットに合わせる
- 変更時は該当セクションのみ書き換え
- 削除時はセクション6の安全策を先に実行

マスタ更新後、Gitワークフローに従いコミット・PR作成を行う。
詳細は `/company` Skill の `references/git-workflow.md` を参照。

---

## 6. 連鎖更新の実行

マスタ変更に伴い、関連リソースを自動更新します。**実行前に必ず変更サマリーをユーザーに提示し、明示的な承認を得ること。**

### 6.1 部署追加時の連鎖更新

```
1. masters/departments.md にエントリ追加
2. .companies/{org-slug}/docs/{folder}/ フォルダ作成（サブフォルダ含む）
   → references/departments.md のテンプレートを参照
3. .companies/{org-slug}/docs/{folder}/CLAUDE.md 生成
   → references/departments.md の CLAUDE.md テンプレートから生成
4. .companies/{org-slug}/CLAUDE.md の組織構成ツリー・部署一覧テーブルに追記
5. 新規ロールがある場合 → ロール追加の連鎖更新も実行
```

### 6.2 ロール追加時の連鎖更新

```
1. masters/roles.md にエントリ追加
2. .claude/agents/{name}.md を新規作成
   → references/agent-templates.md の基本テンプレートで生成
   → ヒアリングで得たペルソナ・責務・モデルを埋め込み
   ※ Subagentはグローバルリソースのため .claude/agents/ 配下に作成
3. masters/departments.md の所属部署の対応Subagentリストに追記
```

### 6.3 ロール削除時の連鎖更新（安全策付き）

```
1. masters/workflows.md を検索 → 該当ロールを参照するワークフローがあれば警告
   「このロールは以下のワークフローで使用されています: [一覧]
    代替ロールを指定するか、ワークフローも修正しますか？」
2. ユーザーが代替ロールを指定 or ワークフロー修正を承認
3. .claude/agents/{name}.md の削除確認
   「Subagentファイル .claude/agents/{name}.md を削除してよいですか？」
4. masters/roles.md からエントリ削除
5. masters/departments.md の所属部署の対応Subagentリストから除去
6. ワークフローの修正（代替ロールへの置換 or ロール除去）
```

### 6.4 部署削除時の連鎖更新（安全策付き）

```
1. .companies/{org-slug}/docs/{folder}/ 配下のファイル存在チェック
   → ファイルがある場合: 物理削除不可。以下を提案:
     「この部署にはデータが残っています。削除ではなくアーカイブ（archived ステータス）
      にすることをお勧めします。アーカイブしますか？」
   → ファイルがない場合（CLAUDE.md のみ）: 削除可能
2. masters/roles.md で該当部署所属のロールに警告表示
   「以下のロールがこの部署に所属しています: [一覧]
    これらのロールも削除しますか？別の部署に移しますか？」
3. masters/workflows.md で該当部署のロールを使うワークフローに警告表示
4. ユーザー承認後:
   - masters/departments.md からエントリ削除（or archived に変更）
   - .companies/{org-slug}/CLAUDE.md の組織構成から除去
   - 承認されたロールの削除・移動を実行
```

### 6.5 ワークフロー追加時の連鎖更新

```
1. 参照ロールの存在確認
   → 不足ロールがあれば追加を提案:
     「ワークフローに必要な {role} が未登録です。新規作成しますか？」
2. ロール追加が承認された場合 → ロール追加フロー（3.2 + 6.2）を実行
3. masters/workflows.md にエントリ追加
```

### 6.6 プロジェクト追加時の連鎖更新

```
1. 関連部署のステータス確認
   → standby の部署があれば active 化を提案:
     「関連部署 {dept} が standby です。active にしますか？」
2. masters/projects.md にエントリ追加
```

### 6.7 組織情報変更時の連鎖更新

```
1. masters/organization.md を更新
2. .companies/{org-slug}/CLAUDE.md をテンプレートから再生成
```

### 6.8 Gitワークフロー

マスタ変更はすべてGitワークフローで管理します。

```
1. ブランチ作成: {org-slug}/admin/{YYYY-MM-DD}-{操作概要}
   例: a-sha-dwh-project/admin/2026-03-19-add-dept-security
2. マスタ更新 + 連鎖更新を実行（セクション5・6の処理）
3. コミット: feat: {操作概要} [{org-slug}] by {operator}
4. PR作成（変更サマリーをPR本文に記載）
5. mainブランチに戻る
```

詳細は `/company` Skill の `references/git-workflow.md` を参照。

---

## 7. 結果の確認

すべての更新が完了したら、変更サマリーを表示します。

```
完了しました！以下の変更を行いました:

【マスタ更新】
- {変更したマスタファイルと内容の一覧}

【連鎖更新】
- {自動更新されたファイルの一覧}

【Git】
- ブランチ: {branch-name}
- PR: {PR URL}

他に変更したいことはありますか？
```

---

## 変更・削除操作の補足

### 変更操作

変更対象のエントリを特定し、変更したいフィールドをヒアリングします。変更後もバリデーション（セクション4）を実行し、整合性を確認します。

- **部署変更**: トリガーワード・役割・ステータス等の変更。CLAUDE.md の再生成が必要な場合は連鎖更新。
- **ロール変更**: モデル・責務等の変更。Subagentファイルの再生成を実行。
- **ワークフロー変更**: ロール追加・除去時にロール存在確認。

### 削除操作の安全策

| 対象 | 安全策 |
|------|--------|
| **部署** | `.companies/{org-slug}/docs/{dept}/` にファイルがある → 削除不可、アーカイブ提案 |
| **ロール** | workflows.md で参照中 → 警告 + 代替ロール要求 |
| **ワークフロー** | そのまま削除可能（他マスタへの影響なし） |
| **プロジェクト** | archived への変更を推奨。物理削除は関連フォルダが空の場合のみ |
| **全操作共通** | 実行前に変更サマリー表示 + ユーザーの明示的承認を必須とする |

---

## 参照ファイル

| ファイル | 用途 | 参照タイミング |
|---------|------|-------------|
| `references/master-schemas.md` | スキーマ定義・バリデーションルール・連鎖更新ルール | 全操作時 |
| `../company/references/departments.md` | 部署テンプレート集 | 部署追加時 |
| `../company/references/agent-templates.md` | Subagent生成テンプレート | ロール追加時 |
| `../company/references/claude-md-template.md` | CLAUDE.md生成テンプレート | 部署追加・組織変更時 |
| `../company/references/git-workflow.md` | Gitワークフロー定義 | マスタ変更時 |
