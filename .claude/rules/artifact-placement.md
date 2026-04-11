# 成果物配置ルール

生成したファイルをどこに置くかの原則。配置を間違えると GitHub Pages 配信対象外になったり、組織独立性が破綻する。

## 配置先マトリクス

| 成果物種別 | 配置先 | 理由 |
|---|---|---|
| 業務ドキュメント（MD） | `.companies/{org}/docs/{dept}/` | 組織スコープ、Git管理、PR運用 |
| タスクログ | `.companies/{org}/.task-log/` | 組織スコープ、docs/と分離 |
| マスタデータ | `.companies/{org}/masters/` | 組織設定 |
| 日次ダイジェスト MD | `.companies/{org}/docs/daily-digest/` | 組織固有 |
| 日次ダイジェスト HTML | `docs/daily-digest/` | GitHub Pages 配信 |
| AWS 構成図 PNG/HTML/YAML | `docs/diagrams/` | GitHub Pages 配信 |
| draw.io 汎用図 | `docs/drawio/` | GitHub Pages 配信 |
| ダッシュボード HTML | `docs/secretary/dashboard.html` および `.companies/{org}/docs/secretary/` | Pages 配信 + 組織スコープ |
| ナレッジポータル HTML | `docs/handover/` | Pages 配信 |
| トップ `index.html` | `docs/index.html` | Pages ルート |
| Subagent 定義 | `.claude/agents/` | グローバルリソース（組織外） |
| Skill 定義 | `plugins/cc-sier/skills/` + `.claude/skills/`（同期） | プラグインソース + ランタイム |

## 原則

### ✅ 必ず守る

- **業務成果物は `.companies/{org-slug}/docs/` 配下に作成**
- GitHub Pages 配信対象（構成図・ダイジェスト HTML・ダッシュボード）は `docs/` 配下
- Subagent への委譲時も組織パス（`.companies/{org}/docs/`）を明示して指示

### ❌ 禁止

- リポジトリルート直下に業務成果物を作成する
- `.claude/` 配下に業務成果物を作成する（`skills/` `agents/` `hooks/` `rules/` はグローバルリソースで例外）
- 組織 A の作業で組織 B のディレクトリに書き込む

## GitHub Pages 配信対象の判断

**`docs/` 配下に置く判断基準**: 成果物が HTML でブラウザから閲覧される・公開可視化される場合。

| 配信あり | 配信なし |
|---|---|
| `docs/diagrams/*.html` | `.companies/{org}/docs/research/*.md` |
| `docs/drawio/*.html` | `.companies/{org}/.task-log/*.md` |
| `docs/daily-digest/index.html` | `.companies/{org}/masters/*.md` |
| `docs/secretary/dashboard.html` | `.companies/{org}/docs/decisions/*.md` |
| `docs/handover/*.html` | （組織固有の業務ドキュメント全般） |

## 同一成果物を複数箇所に置くケース

日次ダイジェストは例外的に **2 箇所** に配置:
- **MD ソース**: `.companies/{org}/docs/daily-digest/YYYY-MM-DD.md`（PR運用・組織スコープ）
- **HTML 配信**: `docs/daily-digest/index.html`（main 直コミット・Pages 配信）

両者は `/company-daily-digest` Phase 7 の HTML 再生成工程で自動同期される。

## 関連

- @.claude/rules/multi-org.md — 組織独立性の原則
- @.claude/rules/git-workflow.md — main 直コミット許可対象
