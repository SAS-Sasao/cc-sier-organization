---
name: company-insights-cycle
description: >
  /company-digest-insights → HTML 生成 → GitHub Pages 公開 を直列実行する
  オーケストレータ Skill（軽量型）。日次ダイジェストからの知見抽出・採用判断・
  レポートの Web 公開を 1 コマンドで完了する。
  「知見サイクル」「解析して公開」「知見を公開」「insights cycle」
  「解析レポートを Pages に」「/company-insights-cycle」と言われたときに使用する。
---

# CC-SIer 知見サイクルオーケストレータ Skill（軽量型）

`company-digest-insights`（解析）と `generate-insights-analyses-html.sh`（公開）を直列実行する軽量オーケストレータ。`/company-cycle` と同じ 4 フェーズ構成。

## 1. 適用条件

- `.companies/.active` に org-slug が存在する
- `.claude/skills/company-digest-insights/` がインストール済み
- `.claude/hooks/generate-insights-analyses-html.sh` が存在する
- `docs/insights/analyses/` に既存レポートがある、または Phase 1 で新規作成される
- 既存 sub-skill の git 動作を尊重する（PR と main 直コミットの混在を許容）

`/company-cycle` と違い **GitHub Actions でも動く**。使うデータが日次ダイジェスト MD と解析レポート MD で、いずれも git tracked のため。ただし Phase 1 は Web 取得を伴うのでローカル実行を推奨する。

---

## 2. 4 フェーズ概要

| Phase | 名称 | 中断条件 |
|---|---|---|
| 0 | 前処理（org / 対象期間 / git clean / task-log 初期化） | git dirty |
| 1 | `/company-digest-insights` 実行（解析 + カタログ追記 + PR） | 解析失敗 |
| 2 | HTML 生成 + Pages 公開（main 直コミット） | 生成スクリプト失敗 |
| 3 | task-log 更新 + Issue + 最終報告 | - |

各 phase 失敗時は task-log を `status: blocked` で保存し、復旧手順を報告する。

**`--publish-only` 指定時は Phase 1 をスキップする**（既存レポートの再公開のみ）。

---

## 3. Phase 0: 前処理

```
1. .companies/.active から {org-slug} を取得
2. git config user.name → {operator}
3. 対象期間を解釈（デフォルト: 未解析の最新週）
4. git status --porcelain が空でなければ中断
5. {date_jst} = TZ=Asia/Tokyo date +%Y-%m-%d
6. {task-id} = YYYYMMDD-HHMMSS-insights-cycle
7. .companies/{org}/.task-log/{task-id}.md を YAML フロントマター形式で作成
   subagents: [company-digest-insights]
```

task-log の `subagents` は必ず英字で記録する（Case Bank 検出のため）。

---

## 4. Phase 1: /company-digest-insights 実行

`@.claude/skills/company-digest-insights/SKILL.md` の指示に従う。

### 重要事項

- レポートの出力先は **`docs/insights/analyses/{slug}.md`**（リポジトリルート側）。組織スコープではない
- カタログの追記先は **`.companies/{org}/docs/insights/catalog.md`**（組織スコープ側）。判断は組織に残す
- **原文は curl で取得する**（@.claude/rules/web-content-fetch.md）。WebFetch は信頼ドメイン外で要約経由になる
- 精読しなかったクラスタは「タイトルからの推定に留まる」と明記させる
- digest-insights は PR を作る。その PR は **Phase 2 の main 直コミットとは別物**

### 完了時に記録する情報

- レポート MD パス: `docs/insights/analyses/{slug}.md`
- 母数（記事数 / ユニークタイトル数）と精読件数
- カタログに追加した候補 ID
- PR URL

---

## 5. Phase 2: HTML 生成 + Pages 公開

```bash
bash .claude/hooks/generate-insights-analyses-html.sh
```

### スクリプトがやること

| 出力 | 内容 |
|---|---|
| `docs/insights/analyses/{slug}.html` | 各レポートの HTML（目次つき） |
| `docs/insights/analyses/index.html` | 一覧ページ（作成日の新しい順） |
| `docs/index.html` | トップページに「知見解析レポート」カードを追記（冪等） |

引数は不要。`docs/insights/analyses/*.md` を全件走査して毎回すべて再生成する。

### 重要事項

- **main 直コミット**（`/company-dashboard` `/company-digest-html` と同じ扱い。@.claude/rules/git-workflow.md の許可対象）
- **Phase 1 の PR がマージされてから実行すること**。未マージだと新レポートの MD が main に無く、HTML に含まれない
- **`docs/index.html` のカード定義は 2 箇所にある**。本スクリプトの挿入処理と、`generate-dashboard.sh` の再生成側。片方だけ直すと `/company-dashboard` の次回実行で消えるため、カードの文言を変えるときは両方直す
- `docs/insights/index.html` は **TodoInsights** の別系統。同じディレクトリだが上書きしない
- MD を直接 Pages で配信しない。本リポジトリに Jekyll 設定がなく、front matter の無い `.md` は生テキストとして返るため

### コミット

```bash
git add docs/insights/analyses/ docs/index.html
git commit -m "chore: 知見解析レポートの HTML を再生成 [{org-slug}] by {operator}"
git push
```

### 完了時に記録する情報

- 生成レポート数・合計サイズ (KB)
- Pages URL: `https://sas-sasao.github.io/cc-sier-organization/insights/analyses/`

---

## 6. Phase 3: task-log + Issue + 最終報告

### 6.1 task-log 更新

```yaml
---
task_id: "{task-id}"
org: "{org-slug}"
operator: "{operator}"
status: completed
mode: "direct"
started: "..."
completed: "..."
request: "/company-insights-cycle {期間}"
issue_number: null
pr_number: null
subagents: [company-digest-insights]
sub_skill_results:
  digest_insights:
    report: "docs/insights/analyses/{slug}.md"
    articles_total: N
    articles_read: N
    candidates: ["AD", "AE"]
    pr: "https://github.com/.../pull/N"
  publish:
    reports: N
    size_kb: N
    url: "https://sas-sasao.github.io/cc-sier-organization/insights/analyses/"
---
```

### 6.2 `## judge` セクション追記

cycle 自体に L2 レビューが無いため、sub-skill の結果から**合成 judge** を生成する（`rebuild-case-bank.sh` が読み、ダッシュボードの judge スコア推移に反映される）。

- `completeness` = レポート作成 && カタログ追記 && HTML 生成 の 3 つ揃えば 1.00、欠ければ 0.50
- `accuracy` = **原文精読率**（精読件数 / 母数）が記録されていれば 1.00、未記録なら 0.50
- `clarity` = Pages 公開成功なら 1.00
- `total` = 3 軸の平均

`judge_comment` には「/company-insights-cycle 合成 judge」と明記し、詳細は sub-skill の task-log を参照させる。

**sub-skill が独自に judge を書いている場合は追記しない**（重複防止）。

### 6.3 最終報告

```
✅ /company-insights-cycle 完了

Phase 1 (解析):  docs/insights/analyses/{slug}.md
  └ 母数 {N} 件 / 精読 {N} 件（{X}%）
  └ 追加候補: {ID 一覧}
  └ PR: {pr_url}
Phase 2 (公開):  {N} 本 / {size} KB
  └ {pages_url}

未検証事項: {レポート §未検証事項 の件数} 件
```

**精読率を必ず報告に出すこと。** 「解析済み」と「原文を読んだ」は違う。

---

## 7. オプションフラグ

| フラグ | 既定 | 効果 |
|---|---|---|
| `--publish-only` | off | Phase 1 をスキップし、既存 MD の HTML 再生成のみ実行 |
| `--period` | 未解析の最新週 | 解析対象期間（例: `2026-08-03..2026-08-09`） |
| `--no-pr` | off | Phase 1 の PR 作成をスキップ（debug 用） |

---

## 8. エラー時の中断ポリシー

- 各 Phase で fail → task-log を `status: blocked` で保存
- 報告に Phase 名・原因・手動復旧コマンドを含める
- 部分作成済みの PR / コミットは削除しない
- **Phase 1 が部分成功（MD はできたが PR 未作成）の場合、Phase 2 は実行してよい**。HTML はローカルの MD から生成できるため
- Phase 2 のカード挿入に失敗した場合（グリッド終端を特定できない）はスクリプトが exit 1 する。`docs/index.html` の構造が変わった可能性があるため、手で直さず生成器側を直す

---

## 9. なぜ 2 箇所に分かれているか

| | 配置 | 理由 |
|---|---|---|
| 解析レポート（根拠） | `docs/insights/analyses/` | ブラウザから読ませる。`docs/guide/*.md` と同じ扱い |
| カタログ・README（判断） | `.companies/{org}/docs/insights/` | 採用可否は組織の意思決定で、公開対象ではない |

2026-08-16 にオーナー判断で既存 7 本を移設した。`@.claude/rules/artifact-placement.md` の「知見解析レポートの例外」に明文化してある。

---

## 10. 関連

- @.claude/skills/company-digest-insights/SKILL.md — Phase 1 の本体
- @.claude/hooks/generate-insights-analyses-html.sh — Phase 2 の本体
- @.claude/hooks/generate-dashboard.sh — トップページカードのもう 1 つの定義元
- @.claude/rules/artifact-placement.md — 配置の根拠（知見解析レポートの例外）
- @.claude/rules/web-content-fetch.md — 原文取得は curl
- @.claude/rules/git-workflow.md — main 直コミット許可対象
- @.claude/skills/company-cycle/SKILL.md — 本 Skill の構成のもとにした軽量オーケストレータ
