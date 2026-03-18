# CC-SIer — 仮想組織

## オーナー情報

- **名前**: とたろ
- **事業**: 日本のSIer。プロジェクトマネジメント・システムアーキテクト・受託案件の標準化活動・AI駆動開発・テスト自動化・CI/CD構築・IaC・データアーキテクト（DWH構築）
- **セットアップ日**: 2026-03-18

## 組織構成

```
.company/
├── masters/            ← マスタデータ
├── secretary/          ← 秘書室（常設）
├── architecture/       ← アーキテクチャ室
└── data/               ← データエンジニアリング室
```

## 部署一覧

| 部署ID | 名称 | ステータス | 対応Subagent |
|--------|------|----------|-------------|
| dept-secretary | 秘書室 | active | secretary |
| dept-architecture | アーキテクチャ室 | active | system-architect, data-architect |
| dept-data | データエンジニアリング室 | active | data-architect |

## 運営ルール

### ファイル命名規則
- 日付ファイル: `YYYY-MM-DD.md`
- ID付きファイル: `{prefix}-{連番またはslug}.md`
- 同日ファイルが存在する場合は追記。新規作成しない

### 作業依頼の流れ
1. ユーザーが `/company` または直接話しかける
2. 秘書がマスタを参照して最適な対応を判定
3. Subagent または Agent Teams で実行
4. 成果物を `.company/` 配下に保存

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

DWH構築案件に即日着手のため、データエンジニアリング室を初日からactive化。
幅広い技術領域（PM、アーキテクチャ、標準化、AI駆動開発、テスト自動化、CI/CD、IaC、データ）をカバーするベテランSIer。
