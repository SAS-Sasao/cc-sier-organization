# マルチ組織運用

`.companies/` 配下で複数の仮想組織を並列管理する。各組織は独立のマスタ・成果物・task-log を持つ。

## ディレクトリ構造

```
.companies/
├── .active                  ← アクティブ組織のslug（1行、.gitignoreで除外）
├── domain-tech-collection/  ← 組織ディレクトリの例
│   ├── masters/             ← マスタデータ（organization/departments/roles/workflows/projects/mcp-services/quality-gates）
│   ├── docs/                ← 全業務成果物
│   │   ├── secretary/       ← 秘書室（常設）
│   │   ├── research/        ← 技術リサーチ室
│   │   ├── retail-domain/   ← 小売ドメイン室
│   │   ├── daily-digest/    ← 日次ダイジェスト MD
│   │   └── {dept}/          ← 部署ごとの成果物
│   ├── .task-log/           ← タスクログ（Git管理）
│   └── CLAUDE.md            ← 組織の文脈情報
├── jutaku-dev-team/
└── standardization-initiative/
```

## org-slug 命名ルール

- **kebab-case**（小文字英数字とハイフンのみ）
- 日本語はローマ字または英訳に変換
- `.companies/` 直下でディレクトリ名として一意
- 既存と重複する場合はサフィックス（`-2`, `-3` 等）を付与

例:
- 「A社DWH構築プロジェクト」→ `a-sha-dwh-project`
- 「社内標準化推進」→ `standardization-initiative`
- 「技術ドメイン収集PJT」→ `domain-tech-collection`

## .active ファイル

`.companies/.active` は**ローカル設定ファイル**（`.gitignore` で除外）。各ユーザーが独立して組織を切り替え可能。

```
# .companies/.active の例
domain-tech-collection
```

Skill はこのファイルを起動時に読み取り、操作対象組織を特定する。`/company` 等のコマンドが組織切替 UI を提供する。

## 組織マスタの標準構成

各組織の `masters/` 配下に以下を配置:

| ファイル | 用途 |
|---|---|
| `organization.md` | 組織名・オーナー・事業・コスト設定 |
| `departments.md` | 部署一覧とトリガーワード |
| `roles.md` | 部署対応 Subagent ロール |
| `workflows.md` | 定義済みワークフロー（wf-daily-digest 等） |
| `projects.md` | 進行中プロジェクト |
| `mcp-services.md` | MCP サーバー一覧・利用可否 |
| `quality-gates/by-type/*.md` | 成果物種別ごとの品質ゲート |

## 組織追加フロー

1. `/company` 起動 → 新規組織オンボーディング
2. Q0〜Q3 ヒアリング（組織名・オーナー・事業・初期部署）
3. `.companies/{new-slug}/` とマスタ生成
4. `.companies/.active` を新 slug で更新

詳細は `.claude/skills/company/SKILL.md` のオンボーディングフローを参照。

## 組織独立性の原則

- 組織 A の作業から組織 B のファイルを参照しない
- 共通ルール（CLAUDE.md, rules/）はリポジトリルートに配置
- 組織固有の文脈は `.companies/{slug}/CLAUDE.md` に配置
- 組織をまたぐ作業（ナレッジ横串）は `/company-handover` 専用 Skill 経由

## 関連

- @.claude/rules/artifact-placement.md — 成果物配置ルール
- @.claude/rules/git-workflow.md — 組織スコープのブランチ命名
