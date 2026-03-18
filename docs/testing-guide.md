# CC-SIer テスト手順書

このドキュメントは CC-SIer プラグインの動作確認テスト手順を記載します。

---

## 前提条件

- Claude Code CLI がインストール済み
- 本リポジトリを clone 済み
- `.claude/skills/` と `.claude/agents/` にファイルが配置済み

---

## シナリオ1: 初回セットアップ

### 手順

**Step 1: リポジトリで Claude Code を起動**

```bash
cd cc-sier-organization
claude
```

**Step 2: /company を実行**

```
/company
```

**期待結果**: `.company/` が存在しないため、オンボーディングモードが起動する。秘書の口調で以下の3問が順に表示される。

**Step 3: Q1 に回答（オーナー名）**

```
山田
```

**期待結果**: Q2（事業内容）に遷移する。

**Step 4: Q2 に回答（事業内容）**

```
SIer、受託開発
```

**期待結果**: Q3（初期部署の選択）に遷移する。選択肢が表示される。

**Step 5: Q3 に回答（初期部署の選択）**

```
秘書室のみ
```

**期待結果**: セットアップが実行され、完了メッセージが表示される。

### 確認項目

| # | 確認対象 | 期待結果 |
|---|---------|---------|
| 1-1 | `.company/masters/` ディレクトリ | 存在する |
| 1-2 | `.company/masters/organization.md` | オーナー名「山田」、事業内容「SIer、受託開発」が含まれる |
| 1-3 | `.company/masters/departments.md` | dept-secretary（active）が含まれる |
| 1-4 | `.company/masters/roles.md` | secretary ロールが含まれる |
| 1-5 | `.company/masters/workflows.md` | ファイルが存在する（空でもよい） |
| 1-6 | `.company/masters/projects.md` | ファイルが存在する（空でもよい） |
| 1-7 | `.company/masters/mcp-services.md` | ファイルが存在する（空でもよい） |
| 1-8 | `.company/secretary/inbox/` | ディレクトリが存在する |
| 1-9 | `.company/secretary/todos/` | ディレクトリが存在する |
| 1-10 | `.company/secretary/notes/` | ディレクトリが存在する |
| 1-11 | `.company/CLAUDE.md` | 組織ルールが記載されている |
| 1-12 | `.company/secretary/CLAUDE.md` | 秘書室ルールが記載されている |

**確認コマンド**:
```bash
ls -R .company/
cat .company/masters/organization.md
cat .company/masters/departments.md
```

---

## シナリオ2: マスタ管理

### 2-1: 部署追加

**Step 1: /company-admin を実行**

```
/company-admin
```

**期待結果**: マスタ管理モードが起動する。

**Step 2: 部署追加を依頼**

```
セキュリティ室を追加して
```

**期待結果**: 秘書の口調でヒアリングが開始される（役割、ロール、トリガーワード等）。

**Step 3: ヒアリングに回答**

```
役割: セキュリティ設計レビュー、脆弱性診断、ISMS対応
ロール: 新しくsecurity-engineerを作りたい
責務: セキュリティ設計レビュー、脆弱性診断
モデル: sonnet
Agent Teams時の役割: teammate
トリガーワード: セキュリティ, 脆弱性, ISMS, ペネトレーション
```

**期待結果**: 変更サマリーが表示され、確認を求められる。

**Step 4: 承認**

```
OK
```

**期待結果**: マスタ更新 + 連鎖更新が実行され、完了メッセージが表示される。

### 確認項目

| # | 確認対象 | 期待結果 |
|---|---------|---------|
| 2-1-1 | `.company/masters/departments.md` | dept-security が追加されている |
| 2-1-2 | `.company/masters/roles.md` | security-engineer が追加されている |
| 2-1-3 | `.claude/agents/security-engineer.md` | Subagentファイルが自動生成されている |
| 2-1-4 | `.company/security/` | フォルダが作成されている |
| 2-1-5 | `.company/security/CLAUDE.md` | 部署CLAUDE.mdが生成されている |
| 2-1-6 | `.company/CLAUDE.md` | 組織構成にセキュリティ室が追記されている |

**確認コマンド**:
```bash
grep "security" .company/masters/departments.md
grep "security-engineer" .company/masters/roles.md
cat .claude/agents/security-engineer.md
ls .company/security/
```

### 2-2: ロール追加（既存部署への配属）

**Step 1: /company-admin を実行してロール追加を依頼**

```
/company-admin
アーキテクチャ室にセキュリティアーキテクトを追加して
```

**期待結果**: security-architect ロールのヒアリングが開始される。

**Step 2: ヒアリングに回答して承認**

### 確認項目

| # | 確認対象 | 期待結果 |
|---|---------|---------|
| 2-2-1 | `.company/masters/roles.md` | security-architect が追加されている |
| 2-2-2 | `.company/masters/departments.md` | dept-architecture の対応Subagentに security-architect が追加されている |
| 2-2-3 | `.claude/agents/security-architect.md` | Subagentファイルが自動生成されている |

### 2-3: 部署削除（データありの場合）

**前提**: `.company/security/` にテストファイルを事前に作成しておく。

```bash
echo "テストデータ" > .company/security/test-data.md
```

**Step 1: /company-admin を実行して部署削除を依頼**

```
/company-admin
セキュリティ室を削除して
```

**期待結果**: データが残っているため、物理削除ではなく**アーカイブ提案**が表示される。

### 確認項目

| # | 確認対象 | 期待結果 |
|---|---------|---------|
| 2-3-1 | 秘書の応答 | 「データが残っています」「アーカイブをお勧めします」という趣旨のメッセージが表示される |
| 2-3-2 | `.company/security/` | フォルダが**削除されていない**（データが保護されている） |
| 2-3-3 | アーカイブ承認後の departments.md | dept-security のステータスが `archived` になっている |

### 2-4: ロール削除（ワークフロー参照ありの場合）

**前提**: security-engineer がワークフローで参照されている状態。

**Step 1: /company-admin でロール削除を依頼**

```
/company-admin
security-engineer ロールを削除して
```

**期待結果**: ワークフローで参照されている場合は**警告**が表示され、代替ロールの指定を求められる。

### 確認項目

| # | 確認対象 | 期待結果 |
|---|---------|---------|
| 2-4-1 | 秘書の応答 | 参照しているワークフロー一覧と警告が表示される |
| 2-4-2 | 代替ロール指定後 | workflows.md のロール参照が更新される |
| 2-4-3 | `.claude/agents/security-engineer.md` | 削除確認後に削除される |
| 2-4-4 | departments.md | 所属部署の対応Subagentリストから除去される |

---

## シナリオ3: 日常運営

### 3-1: TODO追加

**Step 1: /company を実行**

```
/company
今日のTODOに「設計書のレビュー」を追加して
```

**期待結果**: 秘書が今日の日付を確認し、TODOファイルに記録する。

### 確認項目

| # | 確認対象 | 期待結果 |
|---|---------|---------|
| 3-1-1 | `.company/secretary/todos/YYYY-MM-DD.md` | 今日の日付のファイルが存在する |
| 3-1-2 | ファイル内容 | 「設計書のレビュー」が記録されている |
| 3-1-3 | 同日追加実行時 | 新規ファイルではなく、既存ファイルへの追記になる |

**確認コマンド**:
```bash
cat .company/secretary/todos/$(date +%Y-%m-%d).md
```

### 3-2: 壁打ち

**Step 1: /company を実行**

```
/company
新しいプロジェクトの技術選定について壁打ちしたい
```

**期待結果**: 秘書が壁打ちモードに入り、対話的に議論を進める。

### 確認項目

| # | 確認対象 | 期待結果 |
|---|---------|---------|
| 3-2-1 | `.company/secretary/notes/` | 壁打ちの記録ファイルが保存されている |

### 3-3: Agent Teams 編成提案

**Step 1: /company を実行**

```
/company
この設計書をレビューして
```

**期待結果**: `workflows.md` の wf-design-review に一致し、Agent Teams 編成が提案される。

### 確認項目

| # | 確認対象 | 期待結果 |
|---|---------|---------|
| 3-3-1 | 秘書の応答 | Agent Teams による設計レビューを提案 |
| 3-3-2 | チーム構成の表示 | system-architect、lead-developer、qa-lead の3名構成が提示される |
| 3-3-3 | コスト設定の考慮 | `organization.md` の COST_AWARENESS に応じた判断がされる |

### 3-4: ダッシュボード

**Step 1: /company を実行**

```
/company
ダッシュボード
```

**期待結果**: 組織情報、アクティブ部署、今日のTODO、最近の活動が一覧表示される。

### 確認項目

| # | 確認対象 | 期待結果 |
|---|---------|---------|
| 3-4-1 | 組織情報セクション | オーナー名、事業内容、コスト設定が表示される |
| 3-4-2 | アクティブ部署テーブル | 各部署のステータスとSubagent数が表示される |
| 3-4-3 | TODOセクション | 今日のTODO内容が表示される |

---

## シナリオ4: dist 同期

### 4-1: sync-to-dist.sh の実行

**Step 1: スクリプトを実行**

```bash
chmod +x scripts/sync-to-dist.sh
./scripts/sync-to-dist.sh
```

**期待結果**: エラーなく完了し、ファイル一覧と集計が表示される。

### 確認項目

| # | 確認対象 | 期待結果 |
|---|---------|---------|
| 4-1-1 | `dist/cc-sier/skills/company/SKILL.md` | 存在する |
| 4-1-2 | `dist/cc-sier/skills/company/references/` | 6ファイル存在する（departments.md, claude-md-template.md, workflow-definitions.md, agent-templates.md, sier-templates.md, master-schemas.md） |
| 4-1-3 | `dist/cc-sier/skills/company-admin/SKILL.md` | 存在する |
| 4-1-4 | `dist/cc-sier/skills/company-admin/references/master-schemas.md` | 存在する |
| 4-1-5 | `dist/cc-sier/agents/` | 18ファイル存在する |
| 4-1-6 | `dist/cc-sier/.claude-plugin/marketplace.json` | 存在する |
| 4-1-7 | `dist/cc-sier/.claude-plugin/plugin.json` | 存在する |

**確認コマンド**:
```bash
ls -R dist/cc-sier/
find dist/cc-sier/agents -name "*.md" | wc -l  # → 18
find dist/cc-sier/skills -name "SKILL.md" | wc -l  # → 2
```

### 4-2: カスタムSubagentの除外確認

**前提**: シナリオ2で `.claude/agents/security-engineer.md` を追加済み。

**Step 1: スクリプトを再実行**

```bash
./scripts/sync-to-dist.sh
```

### 確認項目

| # | 確認対象 | 期待結果 |
|---|---------|---------|
| 4-2-1 | `dist/cc-sier/agents/security-engineer.md` | **存在しない**（`.claude/agents/` にはあるが、`plugins/cc-sier/agents/` にはないため dist に含まれない） |
| 4-2-2 | `dist/cc-sier/agents/` のファイル数 | 18（初期同梱のみ） |

---

## Skill/Subagent の認識確認手順

Claude Code でのSkill/Subagent認識を確認するには:

### Skills の確認

```bash
claude
```

起動後、`/company` と入力して Tab 補完が効くか、またはスキル一覧に表示されるか確認。

| 確認項目 | 期待結果 |
|---------|---------|
| `/company` | Skill として認識され実行可能 |
| `/company-admin` | Skill として認識され実行可能 |

### Subagents の確認

Claude Code セッション内で:

```
secretaryエージェントを使って、今日のTODOを表示して
```

| 確認項目 | 期待結果 |
|---------|---------|
| secretary Subagent | 起動して秘書として振る舞う |
| その他のSubagent | 名前指定で呼び出し可能 |
