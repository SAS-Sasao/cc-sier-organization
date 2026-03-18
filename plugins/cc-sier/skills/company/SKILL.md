---
name: company
description: >
  SIer業務の仮想組織スキル。/company で秘書に話しかける。
  マスタ駆動で部署・ロールを動的に編成。Agent Teamsで並列作業を実行。
  「秘書」「TODO」「管理」「壁打ち」「相談」「組織」と言われたとき、
  または /company を実行したときに使用する。
---

# CC-SIer メインSkill

このSkillは SIer業務の仮想組織を運営するコアロジックです。
マスタデータを参照し、作業依頼に応じて Subagent や Agent Teams を動的に編成します。

---

## 1. 検出とモード判定

起動時に以下を順に確認し、モードを決定します。

### 1.1 組織の存在チェック

```
IF .company/ が存在しない → オンボーディングモード（セクション2へ）
IF .company/masters/ が存在しない → オンボーディングモード（セクション2へ）
IF .company/masters/organization.md が存在する → 運営モード（セクション3へ）
```

### 1.2 ユーザー意図の判定

ユーザーの発話から以下を判定します:

| 意図 | キーワード | 遷移先 |
|------|-----------|--------|
| 秘書への依頼 | TODO, タスク, 壁打ち, 相談, メモ, ダッシュボード | 運営モード → 秘書 Subagent |
| 特定部署への依頼 | マスタのトリガーワードと照合 | 運営モード → 該当部署 |
| 部署追加 | 「〜室を作って」「部署を追加」 | 部署追加フロー（セクション4） |
| マスタ管理 | 「マスタ管理」「ロール追加」「組織変更」 | `/company-admin` Skill への誘導 |
| 状態確認 | 「組織の状態」「ダッシュボード」 | ダッシュボード表示 |

---

## 2. オンボーディング（初回セットアップ）

`.company/` が存在しない場合に実行します。3問のヒアリングで組織を初期化します。

### 2.1 ヒアリング

以下の3問をユーザーに順に質問します:

**Q1: あなたのお名前（ニックネーム）を教えてください。**
> 秘書がオーナーを呼ぶときの名前に使います。

**Q2: どんな事業・業務をしていますか？**
> 例: SIer、受託開発、データ基盤構築、社内IT

**Q3: 最初に立ち上げたい部署はありますか？**
> デフォルトでは秘書室のみ起動します。他の部署は後から追加できます。
> 選択肢: [秘書室のみ（推奨）/ 秘書室 + PM室 / 秘書室 + アーキテクチャ室 / カスタム]

### 2.2 マスタファイル生成

ヒアリング結果を元に以下を生成します:

1. **ディレクトリ作成**:
   - `.company/masters/`
   - `.company/secretary/inbox/`
   - `.company/secretary/todos/`
   - `.company/secretary/notes/`
   - Q3 で選択された追加部署のフォルダ

2. **マスタファイル生成**（テンプレートは `references/departments.md` を参照）:
   - `.company/masters/organization.md` — オーナー名、事業内容、コスト設定（デフォルト: balanced）
   - `.company/masters/departments.md` — 秘書室（active）+ 選択された追加部署
   - `.company/masters/roles.md` — secretary + 追加部署に対応するロール
   - `.company/masters/workflows.md` — 空（後から `/company-admin` で追加）
   - `.company/masters/projects.md` — 空
   - `.company/masters/mcp-services.md` — 空

3. **CLAUDE.md 生成**（テンプレートは `references/claude-md-template.md` を参照）:
   - `.company/CLAUDE.md` — 組織ルール
   - `.company/secretary/CLAUDE.md` — 秘書室ルール
   - 追加部署がある場合、各部署の CLAUDE.md

4. **完了メッセージ**:
   ```
   組織のセットアップが完了しました！

   オーナー: {owner_name}
   事業: {business}
   アクティブ部署: 秘書室{, 追加部署名}

   「/company」または直接話しかけてください。秘書がお待ちしています。
   部署やロールの追加は「/company-admin」で行えます。
   ```

---

## 3. 運営モード

マスタが存在する場合の通常運用フローです。

### 3.1 状態読み込み

起動時に以下のマスタを読み込みます:

1. `.company/masters/organization.md` — コスト設定、組織ポリシー
2. `.company/masters/departments.md` — 部署一覧とトリガーワード
3. `.company/masters/workflows.md` — 定義済みワークフロー

### 3.2 依頼内容の分析とルーティング

ユーザーの依頼を以下のステップで処理します:

**Step 1: ワークフロー照合**
- `masters/workflows.md` のトリガーと依頼を照合
- 一致するワークフローがあれば、そのワークフローの実行方式に従う

**Step 2: 部署照合**（ワークフロー不一致の場合）
- `masters/departments.md` のトリガーワードと依頼を照合
- 一致する部署が見つかったら、その部署の対応 Subagent を確認

**Step 3: 実行モード判定**

| 条件 | 実行モード | アクション |
|------|-----------|-----------|
| ワークフロー一致 + 実行方式 = subagent | Subagent委譲 | 該当 Subagent を名前指定で起動 |
| ワークフロー一致 + 実行方式 = agent-teams | Agent Teams | チーム編成して並列実行 |
| 部署一致 + 小規模作業 | 秘書が直接対応 | secretary Subagent で処理 |
| 部署一致 + 専門作業 | Subagent委譲 | 部署の対応 Subagent を起動 |
| 部署一致 + 大規模並列 | Agent Teams | Agent Teams適性を確認して編成 |
| どれにも一致しない | 秘書対応 | secretary Subagent で汎用対応 |

### 3.3 Subagent 呼び出し

Subagent を呼び出す際は、名前指定で起動します:

```
「{agent-name}エージェントを使って、{依頼内容}を実行してください。
成果物は {output_path} に保存してください。」
```

対応する Subagent ファイルは `.claude/agents/{agent-name}.md` にあります。

### 3.4 Agent Teams 編成

Agent Teams を使用する場合（`references/agent-templates.md` を参照）:

1. ワークフローのチーム構成を確認
2. `masters/roles.md` から各ロールのテイメイト指示テンプレートを取得
3. チームリード（通常は secretary）を指定
4. 各テイメイトに具体的な指示を与えて並列実行
5. 結果を統合して `.company/` 配下に保存

**コスト管理**: `masters/organization.md` の `COST_AWARENESS` 設定に従う:
- `conservative`: Agent Teams は明示指示時のみ。デフォルトは Subagent
- `balanced`（推奨）: workflows.md の実行方式に従う
- `aggressive`: 並列可能な場面では積極的に Agent Teams 使用

### 3.5 ダッシュボード表示

「ダッシュボード」「組織の状態」と言われた場合:

```
## CC-SIer ダッシュボード

### 組織情報
- オーナー: {owner_name}
- 事業: {business}
- コスト設定: {cost_awareness}

### アクティブ部署
| 部署 | ステータス | Subagent数 |
|------|----------|-----------|
| {各部署の情報} |

### 今日のTODO
{.company/secretary/todos/YYYY-MM-DD.md の内容}

### 最近の活動
{直近の成果物やメモ}
```

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
   - `.company/{dept}/` フォルダ作成
   - `.company/{dept}/CLAUDE.md` 生成（`references/departments.md` のテンプレートから）
   - `.company/CLAUDE.md` の部署一覧を更新
   - `.claude/agents/{role}.md` を生成（`references/agent-templates.md` のテンプレートから）

### 4.2 高度な管理操作への誘導

以下の操作はより詳細なヒアリングが必要なため、`/company-admin` を案内します:

- ロールの変更・削除
- ワークフローの追加・変更
- 組織ポリシーの変更
- マスタの整合性チェック

```
この操作には詳細な設定が必要です。
「/company-admin」で マスタ管理モードを起動してください。
```

---

## 参照ファイル一覧

詳細な定義は以下の references/ ファイルに外出ししています:

| ファイル | 用途 | 参照タイミング |
|---------|------|-------------|
| `references/departments.md` | 部署テンプレート集 | 部署追加時 |
| `references/claude-md-template.md` | CLAUDE.md 生成テンプレート | オンボーディング時 |
| `references/workflow-definitions.md` | ワークフロー定義集 | 作業依頼受付時 |
| `references/agent-templates.md` | Subagent 生成テンプレート | Subagent/Agent Teams 編成時 |
| `references/sier-templates.md` | SIer業務特化テンプレート | ドキュメント生成時 |
| `references/master-schemas.md` | マスタスキーマ・バリデーション | マスタCRUD操作時 |
