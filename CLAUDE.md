# CC-SIer 開発リポジトリ

## AI 運用ルール

### 基本原則

- **言語**: 応答・ドキュメント・コメントは日本語（コード内コメントは英語可）
- **業務成果物の配置**: 必ず `.companies/{org-slug}/docs/` または `docs/` 配下（リポジトリルート直下は禁止）
- **破壊的操作**: `git reset --hard` / `git push --force` / `rm -rf` 等は事前承認必須
- **リファクタのスコープ遵守**: 依頼外の改善・コメント追加・過剰な抽象化は禁止
- **不明点の解消**: 既存成果物や rules/ を先に確認し、推測で埋めない

### 作業ルール

- ファイル生成を伴う作業は必ずブランチ＋PR（例外は @.claude/rules/git-workflow.md 参照）
- `plugins/cc-sier/skills/` を編集したら `.claude/skills/` にも必ず同期
- 3層レビュー（L0/L1/L2）を通さずに auto-merge しない
- タスクログは YAML フロントマター形式で `.task-log/` に記録

詳細: @.claude/rules/git-workflow.md / @.claude/rules/task-log.md

---

## プロジェクト概要

このリポジトリは Claude Code プラグイン **cc-sier**（SIer 業務特化の仮想組織プラグイン）の開発リポジトリです。マスタデータ駆動で部署・ロール・ワークフローを動的に編成し、Agent Teams で並列作業を実行します。

主要機能:

- **マルチ組織運営**: `.companies/` 配下で複数組織を並列管理（現在 3 組織）
- **Skill による業務自動化**: 12 種類の `/company-*` コマンド
- **Subagent による専門領域**: 19 種類のロール別エージェント
- **3 層レビュー + auto-merge**: Skill 成果物を機械的・構造的・LLM的に 3 層で品質担保
- **Case Bank 継続学習**: 過去タスクログを報酬スコア付きで蓄積し次セッションで参照

要件定義書 v0.3: @docs/requirements.md (1,515 行)

---

## 技術スタック

| 領域 | 技術 | バージョン |
|---|---|---|
| プラグイン基盤 | Claude Code Plugin（Skill + Subagent） | - |
| MCP サーバー | aws-knowledge / aws-diagram / aws-iac / drawio | 各 latest |
| ランタイム（Python） | Python + uv + GraphViz（aws-diagram 用） | 3.10+ |
| ランタイム（Node） | Node.js + npx（drawio MCP, review-drawio.js） | 20+ |
| シェル | Bash（`.claude/hooks/` 配下 15 本） | 5.x |
| CLI | GitHub CLI (`gh`) | latest |
| ドキュメント配信 | GitHub Pages (`docs/` 配下) | - |

---

## 開発コマンド

### Skill 実行（`/` プレフィックス）

| コマンド | 用途 |
|---|---|
| `/company` | 秘書・組織運営・壁打ち・部署追加 |
| `/company-admin` | マスタデータ管理（部署・ロール・ワークフロー） |
| `/company-daily-digest` | 日次ニュース巡回 → MD → 3層レビュー → PR → HTML公開（8フェーズ） |
| `/company-diagram` | AWS 構成図生成 + L0/L1/L2 レビュー + auto-merge（9フェーズ） |
| `/company-drawio` | draw.io 汎用図生成 + 3層レビュー + auto-merge（9フェーズ） |
| `/company-dashboard` | 組織活動ダッシュボード HTML 生成 |
| `/company-digest-html` | 日次ダイジェスト HTML 再生成（main 直コミット） |
| `/company-handover` | 全活動のナレッジポータル HTML 生成 |
| `/company-spawn` | アプリケーションリポジトリ切り出し |
| `/company-report` | 組織活動サマリーレポート（日次/週次/月次） |
| `/company-evolve` | Case Bank 継続学習・Skill トリガー語拡張 |
| `/company-quality-setup` | `masters/quality-gates/` チェックリスト配置 |

### Git / PR

```bash
# ブランチ作成
git checkout -b {org-slug}/{type}/{YYYY-MM-DD}-{summary}

# PR 作成 + auto-merge
gh pr create --title "..." --body "..."
gh pr merge {N} --auto --squash --delete-branch
```

### Skill 同期（新規追加・更新時）

```bash
cp -r plugins/cc-sier/skills/{name} .claude/skills/
diff -rq plugins/cc-sier/skills/{name}/ .claude/skills/{name}/
```

### L0 レビュースクリプト

```bash
node .claude/skills/company-drawio/references/review-drawio.js docs/drawio/{filename}.drawio
```

---

## ディレクトリ構造

```
cc-sier-organization/
├── .claude-plugin/           ← plugin.json / marketplace.json
├── .claude/
│   ├── skills/               ← ランタイム Skill（plugins からの同期先、12種）
│   ├── agents/               ← 19 種の Subagent
│   ├── hooks/                ← 15 本の Shell スクリプト（Case Bank / Dashboard 等）
│   └── rules/                ← 詳細ルール（本 CLAUDE.md から @参照）
├── .companies/               ← 組織データ（マルチ組織対応）
│   ├── .active               ← .gitignore で除外、ローカル設定
│   └── {org-slug}/
│       ├── masters/          ← organization/departments/roles/workflows/projects/mcp-services/quality-gates
│       ├── docs/             ← 全業務成果物（部署別）
│       ├── .task-log/        ← タスクログ（Git 管理）
│       └── CLAUDE.md         ← 組織文脈
├── plugins/cc-sier/          ← プラグインソース（VCS 真ソース）
│   ├── skills/               ← 9 種の Skill（company / -admin / -diagram 等）
│   └── agents/               ← Subagent 定義
├── docs/                     ← GitHub Pages 配信 + 要件定義
│   ├── requirements.md       ← 要件定義 v0.3（実装時必読）
│   ├── diagrams/             ← AWS 構成図（PNG/HTML/YAML/iac-viewer）
│   ├── drawio/               ← draw.io 汎用図
│   ├── daily-digest/         ← 日次ダイジェスト HTML
│   ├── secretary/            ← ダッシュボード HTML
│   └── handover/             ← ナレッジポータル
├── CLAUDE.md                 ← このファイル（開発用）
└── README.md
```

詳細: @.claude/rules/multi-org.md / @.claude/rules/artifact-placement.md

---

## コーディング規約

- **コミットメッセージ**: Conventional Commits（`feat:` / `fix:` / `docs:` / `refactor:` / `chore:` / `admin:`）
- **コミット本文形式**: `{type}: {概要} [{org-slug}] by {operator}`
- **ブランチ命名**: `{org-slug}/{type}/{YYYY-MM-DD}-{summary}`
- **SKILL.md の長さ**: 1,500〜2,000 語以内（プログレッシブ・ディスクロージャ、詳細は `references/` に外出し）
- **MD リンクタイトル**: 半角 `[...]` は全角 `【...】` に置換（HTML 変換時のリンク消失防止）
- **インデント**: 2 スペース（HTML/YAML/Markdown）、タブ使用禁止

詳細: @.claude/rules/git-workflow.md / @.claude/rules/skill-development.md

---

## 注意事項

- ❌ リポジトリルートや `.claude/skills/agents/hooks/rules` 以外の `.claude/` 配下に業務成果物を作成しない
- ❌ `main` への force push 禁止（緊急時も明示承認必要）
- ❌ `.companies/.active` のコミット禁止（ローカル専用、`.gitignore` で除外済み）
- ❌ SKILL.md リライト時の旧版 references/ 取りこぼし禁止（事前に既存成果物を `grep -o "<h2>"` で必須セクション抽出）
- ❌ 必須セクション欠落のまま auto-merge 禁止（L2 で `critical_triggered = true` を強制する設計）
- ❌ `--no-verify` でのフック skip
- ⚠️ `/company-diagram` 詳細ページは **必須 7 セクション固定順序**: 凡例 → 概要 → データフロー → レイヤー構成 → 設計のポイント → コスト概算 → 学習ポイント
- ⚠️ 日次ダイジェストは章順固定（A → B → C → D）・テーブル形式・テーマ別分類
- ⚠️ 日次ダイジェスト D章ステータスは文字列（`成功`/`失敗`/`0件`）で記載、絵文字（`✅`等）は L2 s6 致命軸 fail。B章は該当記事なしでも B1-B6 全サブセクション記載（4/13・4/19 で L2 retry 発生）
- ⚠️ AWS Diagram Python コードのラベルに `\n` 改行を含めない（silent error）
- ⚠️ Subagent 名は task-log に英字で記録（日本語名だと Case Bank 検出不可）
- ⚠️ `claude-code-action@v1` は `claude_code_oauth_token` / `anthropic_api_key` を **input parameter で渡す**（action.yml が env を input で上書きするため env block だけでは効かない）
- ⚠️ claude-code-action を挟む workflow では post step にも env が必要なため env は **job レベル** に配置（step-level は post step に伝播しない）
- ⚠️ claude-code-action 実行後の `git push` 前に `git remote set-url origin https://x-access-token:${GH_TOKEN}@...` を再設定（action が remote URL を書き換える可能性）
- ⚠️ 必須セクションの**順序違反**も `critical_triggered = true` 扱い（欠落と同じく均し込み禁止）
- ⚠️ nightly 系 workflow で Opus に複数シグナル（PR/task-log/commit 20件以上）を分析させる場合 `max-turns` は **60 以上**（30 だと Claude が全件丁寧に Read してツール呼び出し枯渇で timeout）。prompt 側にも「全件丁寧に読まない、優先順位をつけて効率重視」を明示する
- ⚠️ third-party action の `with:`/`env:` 挙動が公式 docs と食い違う時は `action.yml` の raw ソース（例: `https://raw.githubusercontent.com/anthropics/claude-code-action/v1/action.yml`）を直接参照して真因特定（公式 docs の parameter table が不完全なケースあり）
- ⚠️ `PROJECTS_PAT` は **Classic PAT 必須**（fine-grained は user-owned Project v2 非対応）。scope は `project` + `read:org` + `read:discussion`
- ⚠️ `gh project` コマンドは `--owner "@me"` を使う（user 名ベタ書きは Classic PAT で `unknown owner type` エラー）。`gh project item-add` は冪等なので bootstrap hook の `[found]` 分岐でも必ず呼ぶ
- ⚠️ Python→bash で区切りデータを渡す時は `\t` ではなく `\x1f` (ASCII Unit Separator) を使う（bash IFS whitespace で空フィールドが潰れ column shift 発生）
- ⚠️ workflow の `permissions:` は使う scope を全て明示列挙し、`2>/dev/null` / `|| true` でエラー握り潰し禁止（silent fail で誤集計の実例あり）
- ⚠️ gitignored データ（`.session-summaries/` `.case-bank/` 等）を参照する Skill は **ローカル実行専用** を SKILL.md に明記（Actions から読めないため完全 observability 不可）
- ⚠️ GitHub Projects v2 GraphQL API の `items(first: N)` は **N ≤ 100**（100 超で `EXCESSIVE_PAGINATION` エラー）。100 超取得は `pageInfo { hasNextPage endCursor }` の cursor-based pagination 必須
- ⚠️ workflow shell で `cmd | tee log.txt` を使うと **pipefail なしでは cmd の非 0 exit code が潰され success 偽装**される。`set -euo pipefail` を冒頭に入れるか、実行と log 表示を分離する

詳細: @.claude/rules/review-pattern.md

---

## 外部参照

| ファイル | 内容 |
|---|---|
| @docs/requirements.md | 要件定義書 v0.3（§2 機能マッピング / §3 Skill / §4 Subagent / §5 CLAUDE.md 階層 / §6 マスタ / §7 Agent Teams / §8 SIer テンプレート） |
| @.claude/rules/git-workflow.md | ブランチ命名・コミット・PR 運用・auto-merge の詳細 |
| @.claude/rules/skill-development.md | SKILL.md 制約・plugins↔.claude 同期・リライト時の取りこぼし防止 |
| @.claude/rules/multi-org.md | `.companies/` マルチ組織運用・org-slug 命名・.active |
| @.claude/rules/artifact-placement.md | 成果物配置マトリクス（`docs/` vs `.companies/{org}/docs/`） |
| @.claude/rules/task-log.md | YAML フロントマター形式・Issue 自動作成・ラベル決定 |
| @.claude/rules/review-pattern.md | L0/L1/L2 3 層レビュー + auto-merge 設計 |

---

## 重要な前提

- `plugins/cc-sier/` = プラグインソース（VCS 真ソース）
- `.claude/skills/` と `.claude/agents/` = インストール済みランタイム（`plugins/` から手動 `cp` 同期）
- プロジェクトルート `CLAUDE.md`（本ファイル）= 開発用
- `.companies/{org-slug}/CLAUDE.md` = 組織文脈（ランタイム、別物）
- `/company-spawn` でアプリケーションリポジトリ新規作成可、設計成果物とSubagent を自動コピー、追跡情報は新リポ `docs/design/origin.md` に記録
