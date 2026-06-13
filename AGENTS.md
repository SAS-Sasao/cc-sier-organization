# CC-SIer Organization Agent Guide

## 基本方針

- 応答、ドキュメント、説明は日本語を基本とする。コード内コメントは英語でもよい。
- 既存成果物、`.claude/rules/`、`.companies/{org-slug}/CLAUDE.md` を先に確認し、推測で仕様を埋めない。
- 依頼外のリファクタ、過剰な抽象化、不要なコメント追加は避ける。
- 破壊的操作（`git reset --hard`、`git push --force`、`rm -rf` など）は必ず事前承認を取る。
- `--no-verify` でフックを回避しない。

## プロジェクト概要

このリポジトリは Claude Code プラグイン `cc-sier` の開発リポジトリ。SIer 業務を仮想組織として扱い、秘書エージェントが依頼を受け、専門 Subagent に委譲し、成果物を Git/PR で管理する。

主な機能:

- `.companies/` 配下で複数組織を管理するマルチ組織運営
- `/company-*` 系 Skill による業務自動化
- ロール別 Subagent による専門作業
- L0/L1/L2 の 3 層レビューと auto-merge
- `.task-log/`、Case Bank、会話ログを使った継続学習
- GitHub Pages によるダッシュボード、ダイアグラム、日次ダイジェスト、ナレッジポータル公開

要件定義の詳細は `docs/requirements.md` と `requirements/cc-sier-requirements-v0.3.md` を参照する。

## 重要な配置ルール

- 業務成果物は必ず `.companies/{org-slug}/docs/` または `docs/` 配下に置く。リポジトリルート直下に業務成果物を作らない。
- `.claude/skills/`、`.claude/agents/`、`.claude/hooks/`、`.claude/rules/` 以外の `.claude/` 配下に業務成果物を置かない。
- `.companies/.active` はローカル設定であり、コミットしない。
- タスクログは YAML フロントマター形式で `.companies/{org-slug}/.task-log/` に記録する。
- `plugins/cc-sier/skills/` を編集した場合は、対応する `.claude/skills/` にも同期する。

## ディレクトリの見方

```text
cc-sier-organization/
├── .claude-plugin/        # plugin.json / marketplace.json
├── .claude/               # ランタイム Skill、Agent、Hook、Rules
├── .companies/            # 組織データ、成果物、タスクログ
├── plugins/cc-sier/       # プラグインソースの真ソース
├── docs/                  # GitHub Pages 配信物、要件定義、ガイド
├── requirements/          # 要件定義の保管先
├── scripts/               # 同期などの補助スクリプト
├── CLAUDE.md              # Claude Code 向け開発ルール
├── README.md              # 利用者向け概要
└── AGENTS.md              # Codex/汎用エージェント向けガイド
```

## よく使うコマンド

Skill 実行:

```bash
/company
/company-admin
/company-daily-digest
/company-diagram
/company-drawio
/company-dashboard
/company-digest-html
/company-handover
/company-spawn
/company-report
/company-evolve
/company-quality-setup
```

ブランチ作成例:

```bash
git checkout -b {org-slug}/{type}/{YYYY-MM-DD}-{summary}
```

PR 作成例:

```bash
gh pr create --title "..." --body "..."
```

Skill 同期例:

```bash
cp -r plugins/cc-sier/skills/{name} .claude/skills/
diff -rq plugins/cc-sier/skills/{name}/ .claude/skills/{name}/
```

draw.io L0 レビュー例:

```bash
node .claude/skills/company-drawio/references/review-drawio.js docs/drawio/{filename}.drawio
```

## 開発規約

- コミットメッセージは Conventional Commits を使う（`feat:`、`fix:`、`docs:`、`refactor:`、`chore:`、`admin:`）。
- ブランチ名は `{org-slug}/{type}/{YYYY-MM-DD}-{summary}` を基本にする。
- Markdown、YAML、HTML は 2 スペースインデント。タブは使わない。
- Markdown リンクタイトルの半角 `[...]` は、必要に応じて全角 `【...】` に置換する。
- `SKILL.md` は 1,500〜2,000 語以内を目安にし、詳細は `references/` に外出しする。
- SKILL リライト時は、旧版 `references/` の必須セクションを取りこぼさない。

## レビューと品質

- ファイル生成を伴う作業は原則ブランチと PR を使う。例外は `.claude/rules/git-workflow.md` を確認する。
- 3 層レビュー（L0/L1/L2）を通さずに auto-merge しない。
- 必須セクションの欠落や順序違反は重大な品質問題として扱う。
- `docs/` 配下の成果物は LLM-as-Judge の completeness、accuracy、clarity 評価対象になる。
- `cmd | tee log.txt` のようなパイプを使う場合は `set -euo pipefail` を使い、失敗を握り潰さない。
- workflow では `2>/dev/null` や `|| true` で重要なエラーを隠さない。

## 注意が必要な実装ポイント

- `/company-diagram` 詳細ページは、凡例、概要、データフロー、レイヤー構成、設計のポイント、コスト概算、学習ポイントの 7 セクション固定順序。
- 日次ダイジェストは A、B、C、D の章順固定。B 章は該当記事なしでも B1〜B6 を記載する。
- 日次ダイジェスト D 章ステータスは `成功`、`失敗`、`0件` の文字列で記載し、絵文字を使わない。
- AWS Diagram Python コードのラベルに `\n` 改行を含めない。
- Subagent 名は task-log に英字で記録する。
- `claude-code-action@v1` は token を input parameter で渡す。workflow の post step に必要な env は job レベルに置く。
- `PROJECTS_PAT` は Classic PAT が必要。scope は `project`、`read:org`、`read:discussion`。
- GitHub Projects v2 GraphQL API の `items(first: N)` は `N <= 100`。100 件超は cursor pagination を使う。

## 参照すべきルールファイル

- `.claude/rules/git-workflow.md`: ブランチ、コミット、PR、auto-merge
- `.claude/rules/task-log.md`: タスクログ形式、Issue 自動作成、ラベル
- `.claude/rules/multi-org.md`: マルチ組織運用、org-slug、`.active`
- `.claude/rules/artifact-placement.md`: 成果物配置
- `.claude/rules/review-pattern.md`: L0/L1/L2 レビュー
- `.claude/rules/skill-development.md`: Skill 開発と同期
- `.claude/rules/todo-management.md`: TODO 管理
- `.claude/rules/wbs-schema.md`: WBS markdown 拡張スキーマ
