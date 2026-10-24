# 成果物配置ルール

生成したファイルをどこに置くかの原則。配置を間違えると GitHub Pages 配信対象外になったり、組織独立性が破綻する。

## 配置先マトリクス

| 成果物種別 | 配置先 | 理由 |
|---|---|---|
| 業務ドキュメント（MD） | `.companies/{org}/docs/{dept}/` | 組織スコープ、Git管理、PR運用 |
| **知見解析レポート（MD）** | **`docs/insights/analyses/`** | **HTML 化して Pages 配信するため（例外、下記参照）** |
| 知見カタログ・入口 README | `.companies/{org}/docs/insights/` | 採用判断は組織スコープの意思決定 |
| タスクログ | `.companies/{org}/.task-log/` | 組織スコープ、docs/と分離 |
| マスタデータ | `.companies/{org}/masters/` | 組織設定 |
| 日次ダイジェスト MD | `.companies/{org}/docs/daily-digest/` | 組織固有 |
| 日次ダイジェスト HTML | `docs/daily-digest/` | GitHub Pages 配信 |
| AWS 構成図 PNG/HTML/YAML | `docs/diagrams/` | GitHub Pages 配信 |
| draw.io 汎用図 | `docs/drawio/` | GitHub Pages 配信 |
| Excel/Office 成果物（xlsx） | `docs/office/`（バイナリ）+ `.companies/{org}/docs/{dept}/sheet-{name}.yaml`（YAML設計図） | DL用に commit（Pages配信なし）+ 設計証跡は組織スコープ |
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
| `docs/handover/*.html` | `.companies/{org}/docs/insights/catalog.md` |
| `docs/insights/index.html`（TodoInsights） | `docs/office/*.xlsx`（DL用、ブラウザ閲覧しない） |
| `docs/insights/analyses/*.html` | （組織固有の業務ドキュメント全般） |

## 同一成果物を複数箇所に置くケース

日次ダイジェストは例外的に **2 箇所** に配置:
- **MD ソース**: `.companies/{org}/docs/daily-digest/YYYY-MM-DD.md`（PR運用・組織スコープ）
- **HTML 配信**: `docs/daily-digest/index.html`（main 直コミット・Pages 配信）

両者は `/company-daily-digest` Phase 7 の HTML 再生成工程で自動同期される。

## 知見解析レポートの例外（2026-08-16）

`docs/insights/analyses/` は「業務ドキュメント（MD）は組織スコープ」という原則の**明示的な例外**。オーナー判断で既存 7 本を `.companies/domain-tech-collection/docs/insights/analyses/` から移設した。

| | 配置先 | 理由 |
|---|---|---|
| **解析レポート（根拠）** | `docs/insights/analyses/*.md` | ブラウザから読ませたい。`docs/requirements.md` / `docs/guide/*.md` と同じ扱い |
| **カタログ・README（判断）** | `.companies/{org}/docs/insights/` | 採用可否は組織の意思決定であり、公開対象ではない |

- HTML は `.claude/hooks/generate-insights-analyses-html.sh` が MD から生成する（`analyses/*.html` + `analyses/index.html`）
- **MD を直接 Pages で読ませない**。本リポジトリに Jekyll 設定はなく、front matter の無い `.md` は生 テキストとして配信されるため
- 生成元 Skill は `/company-digest-insights`、公開まで通すオーケストレータは `/company-insights-cycle`
- **なぜ MD ソースも `docs/` 側なのか**: 日次ダイジェストのような 2 箇所配置にしなかったのは、解析レポートが組織横断の技術知見であり、特定部署の業務成果物ではないため。カタログ側に判断が残るので組織スコープの独立性は保たれる

## `docs/index.html` への複数生成器の書き込み（2026-08-22）

`docs/index.html` は **4 つの hook/生成器** が書き込む共有ファイルであり、各生成器の正規表現が他の生成器が挿入したセクションを巻き添え削除するリスクがある。

| 生成器 | 起動元 | 頻度 |
|---|---|---|
| `generate-insights-html.py` | `daily-insights-sync` workflow | **毎晩** |
| `generate-daily-digest-html.sh` | `daily-digest-automation` workflow | **毎晩** |
| `generate-insights-analyses-html.sh` | ローカル `/company-insights-cycle` | 手動 |
| `generate-dashboard.sh` | ローカル `/company-dashboard` | 手動 |

### 事故実例（#805）

`generate-insights-html.py` の削除正規表現 `\./insights/[^"]*` が `./insights/analyses/index.html` にもマッチし、解析レポートカードが **6 日間毎晩削除** され続けた（8/16 公開 → 8/22 検知）。

### 防止ルール

- ❌ 共有ファイルの正規表現に `[^"]*` 等のワイルドカードを使う場合、他セクションの href パターンと照合してから投入
- ✅ hook/生成器を修正した後は、同じファイルに書き込む **全生成器を模擬実行** し、全セクション（カード等）が生存することを実測確認
- ✅ 新たに `docs/index.html` に書き込む生成器を追加する場合は上記テーブルを更新

## 関連

- @.claude/rules/multi-org.md — 組織独立性の原則
- @.claude/rules/git-workflow.md — main 直コミット許可対象
