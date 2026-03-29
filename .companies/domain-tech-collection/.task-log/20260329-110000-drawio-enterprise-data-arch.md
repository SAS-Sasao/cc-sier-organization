# タスクログ: エンタープライズデータアーキテクチャ（MDM中心）

- **task-id**: 20260329-110000-drawio-enterprise-data-arch
- **ステータス**: completed
- **開始日時**: 2026-03-29 11:00
- **完了日時**: 2026-03-29 11:00
- **オペレーター**: SAS-Sasao
- **実行モード**: direct
- **部署**: secretary
- **Subagent**: (direct - /company-drawio skill)

## 依頼内容

ERP・販売管理・会計等の社内アプリケーションからMDMを通じてゴールデンレコードを抽出し、DWH/データレイク経由でBIツールでインサイトを得るエンタープライズデータアーキテクチャ図を作成。AWSなど特定サービスに依存しない抽象的な構成図。

## 成果物

| ファイル | 内容 |
|---------|------|
| `docs/drawio/enterprise-data-arch.html` | 詳細ページ（Mermaid.jsプレビュー + draw.io編集ボタン） |
| `docs/drawio/index.html` | ギャラリーにカード追加（2件目） |
| `.companies/domain-tech-collection/docs/drawio/enterprise-data-arch.md` | Mermaidソースコード・メタデータ |

## judge

- completeness: 5/5 — 6層（ソース/統合/MDM/プラットフォーム/分析/利用者）を全て網羅
- accuracy: 5/5 — MDM中心のエンタープライズアーキテクチャとして標準的な構成要素を配置
- clarity: 4/5 — LR（左→右）フローで層の流れが明確。ノード数が多いため横幅が必要

## reward

- score: 0.95
- reason: 抽象的なエンタープライズアーキテクチャを6層構成で網羅的に設計。MDMを中核としたデータフローが明確。構成要素テーブルも充実。
