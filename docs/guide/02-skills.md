# 02 Skills リファレンス

---

## /company

組織を作成、または切り替えます。引数なしで実行します。

```
/company
```

実行するとメニューが表示されます。

**メニューの選択肢:**
- 既存組織の一覧 → 選択すると切り替え
- 新規組織を作成 → 4問の対話フローで新規作成

**新規組織作成時の4問対話:**

| # | 質問 | 例 |
|---|---|---|
| Q0 | 組織名（プロジェクト名） | A社DWH構築プロジェクト → org-slug `a-sha-dwh` が自動生成 |
| Q1 | あなたのお名前（ニックネーム） | 秘書がオーナーを呼ぶ名前に使用 |
| Q2 | どんな事業・業務をしているか | SIer、受託開発、データ基盤構築 等 |
| Q3 | 最初に立ち上げたい部署 | 秘書室のみ（推奨）/ 秘書室+PM室 / 秘書室+アーキテクチャ室 / カスタム |

**新規作成時の動作:**
1. 4問の回答内容をもとに org-slug と初期設定を決定
2. `.companies/{org-slug}/` ディレクトリを生成
3. `CLAUDE.md` を作成
4. `masters/`（organization.md / departments.md / roles.md / workflows.md）を作成
5. `docs/secretary/`（inbox/ / todos/ / notes/）を作成
6. `.companies/.active` に org-slug を書き込む
7. 新規作成完了を報告

**切り替え時の動作:**
1. `.companies/.active` に org-slug を書き込む
2. `CLAUDE.md` と `masters/` を読み込み
3. 現在の組織状態を報告

**使い方例:**
```
# 起動してメニューを表示
/company

# → 「既存組織に切り替え」を選んで jutaku-dev-team を選択
# または
# → 「新規組織を作成」を選んで4問に回答
```

---

## /company-admin

組織のマスタデータを作成・更新・削除します。

| マスタ | ファイル | 内容 |
|---|---|---|
| 顧客情報 | `masters/customers/{slug}.md` | 顧客名・制約・担当者・技術スタック |
| 役割定義 | `masters/roles.md` | 組織内の役割と責任範囲 |
| ワークフロー | `masters/workflows.md` | 定型業務の手順テンプレート |

すべての変更はブランチ経由でPRを作成します（直接mainへのコミットなし）。

---

## /company-report

組織の活動レポートを生成します。

```
/company-report [period]
```

| 引数 | 対象期間 |
|---|---|
| `today`（省略時） | 本日 |
| `week` | 過去7日 |
| `month` | 当月1日〜今日 |
| `2026-03-01:2026-03-15` | カスタム日付範囲 |

**レポートの内容:** エグゼクティブサマリー / 活動統計 / 完了タスク / 進行中タスク / 成果物一覧 / Issue動向 / 次のアクション候補

**出力先:** `docs/secretary/reports/YYYY-MM-DD-{period}.md` + GitHub Issue + Git PR

完了後: `/company-evolve` が自動起動します。

---

## /company-evolve

組織の継続学習を実行します。

```
/company-evolve [days]   ← days省略時は30日
```

| Phase | 処理 |
|---|---|
| 1 | Skill Evaluator: タスクに報酬スコアを付与 |
| 1 | Case Bank 再構築: 全タスクをインデックス化 |
| 2 | MEMORY.md 更新: 出力スタイル・ルーティング先読み |
| 2 | ワークフロー自動生成: 高品質パターンを手順書に |
| 3 | Skill Synthesizer: 繰り返しパターンに新規Skillを提案（PR） |
| 3 | Subagent Refiner: 実績データでAgentを更新（PR） |
| 3 | Subagent Spawner: 対応Agentがない作業に新規Agentを提案（PR） |

詳細は [05 継続学習システム](05-learning-system.md) を参照。

---

## /company-spawn

新しいアプリリポジトリを生成します。詳細は [07 company-spawn](07-company-spawn.md) を参照。

---

## /company-quality-setup

アクティブな組織に品質チェックリストを配置します。

```
/company-quality-setup
```

**動作:**
1. `.companies/{org-slug}/masters/quality-gates/` の存在を確認
2. **既にファイルがある場合** → 以下の3択を提示
   - `1. 上書きする`（テンプレートで全て置き換え）
   - `2. 存在しないファイルだけ追加する`（既存カスタマイズを維持）
   - `3. キャンセル`
3. **ファイルがない場合** → 確認なしにそのまま配置
4. `.claude/skills/company-quality-setup/templates/` からコピー

**配置されるファイル:**

```
masters/quality-gates/
├── _default.md             # 全成果物共通チェック
├── by-type/
│   ├── requirements.md     # 要件定義書
│   ├── design.md           # 設計書
│   ├── proposal.md         # 提案書
│   ├── report.md           # 報告書
│   └── adr.md              # ADR
└── by-customer/
    └── _template.md        # 顧客別チェックリストの雛形
```

**顧客別チェックリストの自動生成:**
`/company-admin` で顧客を新規登録すると `by-customer/{slug}.md` が `_template.md` から自動生成されます。

**テンプレートのカスタマイズ:**
- 全組織共通の変更 → `.claude/skills/company-quality-setup/templates/` を編集
- 組織固有の変更 → `masters/quality-gates/` を直接編集

---

## /company-review

成果物の品質チェックを手動で実行します。

```
/company-review                    ← 直近24時間の変更ファイルを対象
/company-review {ファイルパス}      ← 特定ファイルを対象
/company-review {ディレクトリ}      ← 配下の全 .md を対象
```

**チェックの仕組み:**
`masters/quality-gates/` のチェックリストをファイルパスに応じて自動適用します。

| ファイルパス | 適用されるチェックリスト |
|---|---|
| `docs/system/requirements/...` | `_default.md` + `by-type/requirements.md` |
| `docs/proposals/...` | `_default.md` + `by-type/proposal.md` |
| パスに顧客slugが含まれる | 上記 + `by-customer/{slug}.md` |

**結果:**

```
✅ Pass の場合:
  品質チェック: {ファイル名} — 合格
  警告（任意対応）: {warning一覧}

❌ Fail の場合:
  品質チェック: {ファイル名} — 不合格（N件）
  不合格項目: {エラー一覧}
  GitHub Issue を作成しました: {URL}
```

> 自動チェックについて: `docs/` 配下の `.md` ファイルを保存するたびに PostToolUse Hook が自動で `/company-review` 相当の処理を実行します。手動実行は任意タイミングでの確認用です。

---

## /company-dashboard

組織の活動状況をHTMLダッシュボードとして生成します。

```
/company-dashboard
```

**生成されるもの:**
`docs/secretary/dashboard.html` — スタンドアロンHTML（外部依存なし）

**ウィジェット:**
- タスクボードの状況（Todo / 進行中 / 要修正 / 完了）
- 品質ゲート合格率（ドーナツゲージ・合格率で色変化）
- Subagent使用頻度ランキング（横棒グラフ）
- タスク品質スコア推移（折れ線グラフ）
- 最近の成果物タイムライン

**アニメーション:** 数値カウントアップ・棒グラフのスライドイン・折れ線の描画アニメーション

**自動更新:** ブラウザで開いた状態で5分ごとに自動リフレッシュします。

**ローカルで確認:**
```bash
open .companies/{org-slug}/docs/secretary/dashboard.html   # Mac
```

**チームと共有（GitHub Pages）:**
Settings → Pages → Source: main / docs フォルダ に設定後:
```
https://{user}.github.io/{repo}/secretary/dashboard.html
```

> `/company-report` 実行後にも自動でダッシュボードが再生成されます。

---

## /company-diagram

AWS Diagram MCP Server を使い、AWSアーキテクチャ構成図をPNG生成してGitHub Pagesギャラリーに公開します。

```
構成図を描いて
DWHのアーキテクチャ図を追加して
```

**必要に応じてヒアリング:**

| # | 質問 | 例 |
|---|------|-----|
| Q1 | どの領域の構成図か | DWH, ネットワーク, アプリケーション |
| Q2 | 含めたいAWSサービス | S3, Glue, Redshift 等（任意） |
| Q3 | 図の名前 | `modern-data-lakehouse`（英語推奨） |

**MCP ツール利用順序:**
1. `list_icons` — 利用可能アイコンの確認
2. `get_diagram_examples` — 構文の参考取得
3. `generate_diagram` — Python diagrams DSL で PNG 生成

**出力先:**
- `docs/diagrams/{name}.png`（構成図画像）
- `docs/diagrams/{name}.html`（詳細ページ）
- `docs/diagrams/index.html`（一覧ページにカード追加）

**注意:** ラベルは英語で記述（日本語はフォント未対応で文字化け）。日本語の解説は HTML ビューア側に記載。

**前提条件:** GraphViz（`dot -V`）、uv、Python 3.10+ がインストール済みであること。

詳細は [11 AWS構成図生成](11-diagram-generation.md) を参照。

---

## /company-digest-html

日次ダイジェストのMarkdownファイルをHTMLに変換し、GitHub Pagesで閲覧可能な形式で公開します。

```
/company-digest-html
```

**データソース:** `.companies/{org-slug}/docs/daily-digest/*.md`

**出力先:** `docs/daily-digest/index.html`（タブ切替SPAページ）

**HTML機能:**
- サマリーカード（総記事数、最新日付、ダイジェスト数、平均記事数/日）
- 日付タブ（最新がデフォルト表示、クリックで過去分に切替）
- URLハッシュ連動（`#2026-03-27` で特定日付に直リンク）
- キーボードナビ（← → キーで日付切替）
- ダークモード対応

**Gitワークフロー:** `docs/` 配下を更新するためmainブランチに直接コミット（`/company-dashboard` と同じ運用）。

詳細は [12 日次ダイジェスト](12-daily-digest.md) を参照。

---

## Tips

**Skill とSubagent の使い分け:**
```
/company-report week    ← 決まったフロー → Skill
B社の新システムを設計して  ← 創造的判断 → 秘書 → Subagent
```

**masters/ を充実させると精度が上がる:**
特に `masters/customers/{slug}.md` の技術スタック・制約欄が重要です。
