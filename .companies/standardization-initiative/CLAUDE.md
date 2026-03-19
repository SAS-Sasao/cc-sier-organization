# 社内標準化推進 — 仮想組織

## オーナー情報

- **名前**: 笹尾豊樹
- **事業**: 標準化活動
- **組織ID**: standardization-initiative
- **セットアップ日**: 2026-03-19

## 組織構成

```
.companies/standardization-initiative/
├── masters/            ← マスタデータ
├── CLAUDE.md           ← 組織ルール
└── docs/               ← 全成果物
    ├── secretary/      ← 秘書室（常設）
    └── pm/             ← プロジェクト管理室
```

## 部署一覧

| 部署ID | 名称 | ステータス | 対応Subagent |
|--------|------|----------|-------------|
| dept-secretary | 秘書室 | active | secretary |
| dept-pm | プロジェクト管理室 | active | project-manager |

## 運営ルール

### ファイル命名規則
- 日付ファイル: `YYYY-MM-DD.md`
- ID付きファイル: `{prefix}-{連番またはslug}.md`
- 同日ファイルが存在する場合は追記。新規作成しない

### 作業依頼の流れ
1. ユーザーが `/company` または直接話しかける
2. 秘書がマスタを参照して最適な対応を判定
3. Subagent または Agent Teams で実行
4. 成果物を `.companies/standardization-initiative/docs/` 配下に保存

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
- ブランチ命名: `standardization-initiative/{type}/{YYYY-MM-DD}-{summary}`
- コミット対象: `.companies/standardization-initiative/` 配下のみ
- 作業完了後は PR を作成し、URL をユーザーに報告
- 詳細は `.claude/skills/company/references/git-workflow.md` を参照
