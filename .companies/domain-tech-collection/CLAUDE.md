# ドメイン知識や技術スタック収集PJT — 仮想組織

## オーナー情報

- **名前**: 笹尾豊樹
- **事業**: SIer
- **組織ID**: domain-tech-collection
- **セットアップ日**: 2026-03-21

## 組織構成

```
.companies/domain-tech-collection/
├── masters/            ← マスタデータ
├── CLAUDE.md           ← 組織ルール
└── docs/               ← 全成果物
    ├── secretary/      ← 秘書室（常設）
    ├── research/       ← 技術リサーチ室
    └── retail-domain/  ← 小売ドメイン室
```

## 部署一覧

| 部署ID | 名称 | ステータス | 対応Subagent |
|--------|------|----------|-------------|
| dept-secretary | 秘書室 | active | secretary |
| dept-research | 技術リサーチ室 | active | tech-researcher |
| dept-retail-domain | 小売ドメイン室 | active | retail-domain-researcher |

## 運営ルール

### ファイル命名規則
- 日付ファイル: `YYYY-MM-DD.md`
- ID付きファイル: `{prefix}-{連番またはslug}.md`
- 同日ファイルが存在する場合は追記。新規作成しない

### 作業依頼の流れ
1. ユーザーが `/company` または直接話しかける
2. 秘書がマスタを参照して最適な対応を判定
3. Subagent または Agent Teams で実行
4. 成果物を `.companies/domain-tech-collection/docs/` 配下に保存

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

## パーソナライズメモ

- この組織はドメイン知識と技術スタックの収集・体系化を目的としている
- 小売ドメイン室は日本の小売業界に特化したドメイン知識を扱う
- 技術リサーチ室と小売ドメイン室の連携で、業界×技術の掛け合わせた知見を蓄積する

## Gitワークフロー

- ファイル生成を伴う作業は必ず専用ブランチで実施
- ブランチ命名: `domain-tech-collection/{type}/{YYYY-MM-DD}-{summary}`
- コミット対象: `.companies/domain-tech-collection/` 配下のみ
- 作業完了後は PR を作成し、URL をユーザーに報告
- 詳細は `.claude/skills/company/references/git-workflow.md` を参照
