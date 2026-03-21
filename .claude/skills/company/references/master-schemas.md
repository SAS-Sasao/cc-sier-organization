# マスタスキーマ定義

このファイルはマスタデータの CRUD 操作時に参照するスキーマ・バリデーションルール・連鎖更新ルールを定義します。

---

## org-slug（組織識別子）スキーマ

### バリデーションルール

| フィールド | 型 | バリデーション |
|-----------|-----|-------------|
| org-slug | string | kebab-case（小文字英数字とハイフンのみ）、一意、空文字不可 |

### 命名ルール
- 組織名をkebab-caseに変換
- 日本語はローマ字または英訳に変換
- 例: 「A社DWH構築プロジェクト」→ `a-sha-dwh-project`
- 例: 「社内標準化推進」→ `standardization-initiative`
- ユーザーが直接slugを指定することも可能

### 一意性
- `.companies/` 直下のディレクトリ名として一意であること
- 既存と重複する場合はサフィックス（-2, -3等）を付与

---

## departments.md エントリスキーマ

### 必須フィールド

| フィールド | 型 | バリデーション |
|-----------|-----|-------------|
| ID | string | `dept-` プレフィックス、kebab-case、一意 |
| 名称 | string | 空文字不可 |
| ステータス | enum | active / standby / archived のいずれか |
| 役割 | string | 空文字不可 |
| フォルダ | string | `.companies/{org-slug}/docs/` プレフィックス |
| 対応Subagent | string[] | roles.md に存在するロールID |
| トリガーワード | string[] | 1つ以上 |

### オプションフィールド

| フィールド | 型 | バリデーション |
|-----------|-----|-------------|
| Agent Teams適性 | enum | high / medium / low |

### 整合性ルール
- 対応SubagentのロールIDは roles.md に存在すること
- フォルダパスは他の部署と重複しないこと
- ステータスが active の場合、フォルダが存在すること

---

## roles.md エントリスキーマ

### 必須フィールド

| フィールド | 型 | バリデーション |
|-----------|-----|-------------|
| ID | string | kebab-case、一意 |
| Subagentファイル | string | `.claude/agents/` プレフィックス、`.md` サフィックス |
| 所属部署 | string | departments.md に存在する部署ID |
| model | enum | opus / sonnet / haiku |
| Agent Teams時の役割 | enum | team-lead / teammate |

### オプションフィールド

| フィールド | 型 | バリデーション |
|-----------|-----|-------------|
| テイメイト指示テンプレート | string (multiline) | {変数} を含んでよい |

### 整合性ルール
- 所属部署のIDは departments.md に存在すること
- Subagentファイルのパスが実際に `.claude/agents/` に存在すること（作成後）
- 1つのロールは1つのSubagentファイルに対応すること

---

## workflows.md エントリスキーマ

### 必須フィールド

| フィールド | 型 | バリデーション |
|-----------|-----|-------------|
| ID | string | `wf-` プレフィックス、kebab-case、一意 |
| 名称 | string | 空文字不可 |
| トリガー | string[] | 1つ以上 |
| 実行方式 | enum | subagent / agent-teams |
| チーム構成またはロール | object | roles.md に存在するロールID |

### 整合性ルール
- 参照するロールIDがすべて roles.md に存在すること
- agent-teams の場合、team-lead が1つ指定されていること
- 成果物のパスが対応する部署のフォルダ配下であること

---

## projects.md エントリスキーマ

### 必須フィールド

| フィールド | 型 | バリデーション |
|-----------|-----|-------------|
| ID | string | `proj-` プレフィックス、一意 |
| 名称 | string | 空文字不可 |
| ステータス | enum | planning / active / review / completed / archived |

### オプションフィールド

| フィールド | 型 | バリデーション |
|-----------|-----|-------------|
| 関連部署 | string[] | departments.md に存在する部署ID |
| 関連ワークフロー | string[] | workflows.md に存在するワークフローID |
| 開始日 | string | YYYY-MM-DD 形式 |
| 終了予定日 | string | YYYY-MM-DD 形式 |
| 実装リポジトリ | string | GitHub URLフォーマット |
| スポーン日 | string | YYYY-MM-DD 形式 |
| スポーン作業者 | string | git user name |
| コピーした成果物 | string[] | ファイルパスの配列 |
| コピーしたSubagent | string[] | Subagent名の配列 |

### 整合性ルール
- 関連部署のIDがすべて departments.md に存在すること
- 関連ワークフローのIDがすべて workflows.md に存在すること

---

## organization.md エントリスキーマ

### 必須フィールド

| フィールド | 型 | バリデーション |
|-----------|-----|-------------|
| 組織名 | string | 空文字不可 |
| オーナー名 | string | 空文字不可 |
| 事業内容 | string | 空文字不可 |

### オプションフィールド

| フィールド | 型 | バリデーション |
|-----------|-----|-------------|
| COST_AWARENESS | enum | conservative / balanced / aggressive |
| セットアップ日 | string | YYYY-MM-DD 形式 |
| パーソナライズメモ | string | 自由記述 |

---

## mcp-services.md エントリスキーマ

### 必須フィールド

| フィールド | 型 | バリデーション |
|-----------|-----|-------------|
| サービス名 | string | 空文字不可、一意 |
| 連携部署 | string[] | departments.md に存在する部署ID |
| 想定操作 | string | 空文字不可 |

### オプションフィールド

| フィールド | 型 | バリデーション |
|-----------|-----|-------------|
| ステータス | enum | planned / configured / active |
| 設定先 | string | settings.json のパス |

---

## 連鎖更新ルール

マスタ変更時に自動的に更新される関連リソースのルール。

### departments.md 変更時

| 操作 | 連鎖更新対象 | 更新内容 |
|------|------------|---------|
| **部署追加** | `.companies/{org-slug}/docs/{dept}/` | フォルダ＋サブフォルダ作成 |
| | `.companies/{org-slug}/docs/{dept}/CLAUDE.md` | `references/departments.md` から部署CLAUDE.mdを生成 |
| | `.companies/{org-slug}/CLAUDE.md` | 組織構成ツリー・部署一覧テーブルに追記 |
| **部署変更** | `.companies/{org-slug}/docs/{dept}/CLAUDE.md` | 変更内容を反映して再生成 |
| **部署削除** | `.companies/{org-slug}/docs/{dept}/` | 削除確認（データがある場合はアーカイブ提案） |
| | `.companies/{org-slug}/CLAUDE.md` | 組織構成から除去 |
| | `roles.md` | 該当部署所属のロールに警告表示 |
| | `workflows.md` | 該当部署のロールを使うワークフローに警告表示 |

### roles.md 変更時

| 操作 | 連鎖更新対象 | 更新内容 |
|------|------------|---------|
| **ロール追加** | `.claude/agents/{name}.md` | `references/agent-templates.md` からSubagentファイルを生成 |
| | `departments.md` | 所属部署の対応Subagentリストに追記 |
| **ロール変更** | `.claude/agents/{name}.md` | Subagentファイルを再生成 |
| **ロール削除** | `.claude/agents/{name}.md` | Subagentファイル削除（確認付き） |
| | `departments.md` | 所属部署の対応Subagentリストから除去 |
| | `workflows.md` | 該当ロールを含むワークフローに警告表示＋代替提案 |

※ Subagentはグローバルリソースのため `.claude/agents/` 配下に格納する（組織ディレクトリ配下ではない）。

### workflows.md 変更時

| 操作 | 連鎖更新対象 | 更新内容 |
|------|------------|---------|
| **ワークフロー追加** | — | 必要ロールの存在確認。不足時は追加を提案 |
| **ワークフロー変更** | — | 参照ロールの存在確認 |
| **ワークフロー削除** | — | 他マスタへの影響なし |

### projects.md 変更時

| 操作 | 連鎖更新対象 | 更新内容 |
|------|------------|---------|
| **プロジェクト追加** | `departments.md` | 関連部署がstandbyの場合、active化を提案 |
| **プロジェクト更新** | — | — |

### organization.md 変更時

| 操作 | 連鎖更新対象 | 更新内容 |
|------|------------|---------|
| **組織情報変更** | `.companies/{org-slug}/CLAUDE.md` | テンプレートから再生成 |

---

## 削除時の安全策

| 対象 | 安全策 |
|------|--------|
| **部署削除** | `.companies/{org-slug}/docs/{dept}/` 配下にファイルがある場合は削除不可。アーカイブ（`archived` ステータス）を提案 |
| **ロール削除** | workflows.md で参照されている場合は警告。代替ロールの指定を求める |
| **ワークフロー削除** | 削除のみ。他マスタへの影響なし |
| **プロジェクト削除** | `archived` ステータスへの変更を推奨。物理削除は `.companies/{org-slug}/docs/pm/projects/` 配下が空の場合のみ |
| **全操作共通** | 実行前に変更内容のサマリーを表示し、ユーザーの明示的な承認を必ず取得する |
