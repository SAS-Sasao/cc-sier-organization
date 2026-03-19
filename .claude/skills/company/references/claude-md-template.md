# CLAUDE.md 生成テンプレート

このファイルは `/company` Skill のオンボーディング時に `.companies/{org-slug}/CLAUDE.md` を生成する際のテンプレートです。
`{{変数名}}` はオンボーディングのヒアリング結果で置換されます。

---

## .companies/{org-slug}/CLAUDE.md テンプレート

```markdown
# {{ORGANIZATION_NAME}} — 仮想組織

## オーナー情報

- **名前**: {{OWNER_NAME}}
- **事業**: {{BUSINESS_DESCRIPTION}}
- **組織ID**: {{ORG_SLUG}}
- **セットアップ日**: {{SETUP_DATE}}

## 組織構成

```
.companies/{{ORG_SLUG}}/
├── masters/            ← マスタデータ
└── docs/                ← 全成果物はここに集約
    ├── secretary/       ← 秘書室（常設）
    {{DEPARTMENT_TREE}}
```

## 部署一覧

| 部署ID | 名称 | ステータス | 対応Subagent |
|--------|------|----------|-------------|
| dept-secretary | 秘書室 | active | secretary |
{{DEPARTMENT_TABLE}}

## 運営ルール

### ファイル命名規則
- 日付ファイル: `YYYY-MM-DD.md`
- ID付きファイル: `{prefix}-{連番またはslug}.md`
- 同日ファイルが存在する場合は追記。新規作成しない

### 作業依頼の流れ
1. ユーザーが `/company` または直接話しかける
2. 秘書がマスタを参照して最適な対応を判定
3. Subagent または Agent Teams で実行
4. 成果物を `.companies/{{ORG_SLUG}}/docs/` 配下に保存

### Agent Teams ポリシー
- **コスト設定**: {{COST_AWARENESS}}
  - conservative: 明示指示時のみ Agent Teams 使用
  - balanced: workflows.md の実行方式に従う
  - aggressive: 並列可能な場面で積極的に使用
- テイメイト数: ワークフロー定義に従う（最大5テイメイト推奨）

### マスタ管理
- マスタの変更は `/company-admin` Skill で行う
- マスタ変更時は連鎖更新（Subagent、CLAUDE.md、フォルダ）が自動実行される
- `masters/` 配下のファイルを直接編集する場合は整合性に注意

## パーソナライズメモ

{{PERSONALIZATION_NOTES}}

## Gitワークフロー

- ファイル生成を伴う作業は必ず専用ブランチで実施
- ブランチ命名: `{{ORG_SLUG}}/{type}/{YYYY-MM-DD}-{summary}`
- コミット対象: `.companies/{{ORG_SLUG}}/docs/` と `masters/` 配下
- 作業完了後は PR を作成し、URL をユーザーに報告
- 詳細は `.claude/skills/company/references/git-workflow.md` を参照
```

---

## 部署 CLAUDE.md 生成時の注意

- 部署の CLAUDE.md はサブディレクトリに配置するため、**遅延ロード**される
- そのディレクトリ内のファイルにアクセスした際に初めて読み込まれる
- コンテキスト節約のため、不要な部署の CLAUDE.md は生成しない
- 部署のCLAUDE.mdテンプレートは `departments.md` の各部署定義に含まれている

---

## 変数一覧

| 変数名 | 取得元 | 説明 |
|--------|--------|------|
| `{{ORGANIZATION_NAME}}` | Q0の回答 | 組織名・プロジェクト名 |
| `{{ORG_SLUG}}` | Q0の回答から自動生成 | kebab-case の組織識別子 |
| `{{OWNER_NAME}}` | Q1の回答 | オーナーのニックネーム |
| `{{BUSINESS_DESCRIPTION}}` | Q2の回答 | 事業・業務の説明 |
| `{{SETUP_DATE}}` | 実行時の日付 | YYYY-MM-DD 形式 |
| `{{DEPARTMENT_TREE}}` | Q3の回答 + departments.md | アクティブ部署のツリー |
| `{{DEPARTMENT_TABLE}}` | Q3の回答 + departments.md | 部署一覧テーブルの行 |
| `{{COST_AWARENESS}}` | デフォルト: "balanced" | Agent Teams のコスト設定 |
| `{{PERSONALIZATION_NOTES}}` | オンボーディング中の会話 | カスタマイズメモ |
