# 受託開発チーム — 仮想組織

## オーナー情報

- **名前**: 笹尾豊樹
- **事業**: 受託開発
- **組織ID**: jutaku-dev-team
- **セットアップ日**: 2026-03-19

## 組織構成

```
.companies/jutaku-dev-team/
├── masters/            ← マスタデータ
├── CLAUDE.md           ← 組織ルール
└── docs/               ← 全成果物
    ├── secretary/      ← 秘書室（常設）
    ├── pm/             ← プロジェクト管理室
    ├── architecture/   ← アーキテクチャ室
    ├── development/    ← 開発室
    ├── quality/        ← 品質管理室
    └── infra/          ← インフラ・IaC室
```

## 部署一覧

| 部署ID | 名称 | ステータス | 対応Subagent |
|--------|------|----------|-------------|
| dept-secretary | 秘書室 | active | secretary |
| dept-pm | プロジェクト管理室 | active | project-manager |
| dept-architecture | アーキテクチャ室 | active | system-architect, data-architect |
| dept-development | 開発室 | active | lead-developer, backend-developer, frontend-developer, ai-developer |
| dept-quality | 品質管理室 | active | qa-lead, test-engineer, ci-cd-engineer |
| dept-infra | インフラ・IaC室 | active | cloud-engineer, sre-engineer |

## 運営ルール

### ファイル命名規則
- 日付ファイル: `YYYY-MM-DD.md`
- ID付きファイル: `{prefix}-{連番またはslug}.md`
- 同日ファイルが存在する場合は追記。新規作成しない

### 作業依頼の流れ
1. ユーザーが `/company` または直接話しかける
2. 秘書がマスタを参照して最適な対応を判定
3. Subagent または Agent Teams で実行
4. 成果物を `.companies/jutaku-dev-team/docs/` 配下に保存

### Agent Teams ポリシー
- **コスト設定**: balanced
  - conservative: 明示指示時のみ Agent Teams 使用
  - balanced: workflows.md の実行方式に従う
  - aggressive: 並列可能な場面で積極的に使用
- テイメイト数: ワークフロー定義に従う（最大5テイメイト推奨）

### マスタ管理
- マスタの変更は `/company-admin` Skill で行う
- マスタ変更時は連鎖更新（Subagent、CLAUDE.md、フォルダ）が自動実行される
- `masters/` 配下のファイルを直接編集する場合は整合性に注意

## Gitワークフロー

- ファイル生成を伴う作業は必ず専用ブランチで実施
- ブランチ命名: `jutaku-dev-team/{type}/{YYYY-MM-DD}-{summary}`
- コミット対象: `.companies/jutaku-dev-team/` 配下のみ
- 作業完了後は PR を作成し、URL をユーザーに報告
- 詳細は `.claude/skills/company/references/git-workflow.md` を参照
