# 小売月次統計トラッカー CI/CD・自動化設計書

| 項目 | 内容 |
|------|------|
| ドキュメント種別 | 設計書 v0.2（L2 レビュー指摘反映） |
| 作成日 | 2026-07-26 |
| 作成者 | 技術リサーチ室（ci-cd-engineer） |
| 対象システム | retail-stats-tracker（CI/CD） |
| ステータス | レビュー待ち |

---

## 0. v0.2 での変更点（L2 レビュー対応）

v0.1 は実装設計（`retail-stats-tracker-design.md`）が未完成の段階で執筆したため、CLI インターフェースを推測で定義していた。実装設計が 2,302 行で確定したため、本改訂で以下を実装設計に一本化した。

| # | 変更 | 詳細 |
|---|------|------|
| 1 | CLI 契約を実装設計 §2.5 に統一 | `scripts/retail_stats/pipeline.py --mode ...` を廃し、`scripts/retail-stats-tracker/retail_stats/` を `python3 -m retail_stats build\|html\|measure --org ... --no-llm ... --report-json ...` で起動する形に全面書き換え |
| 2 | LLM フォールバックのメカニズムを変更 | 実装設計 §4.6.1 の `ClaudeCliClient` は `claude` CLI headless モードを **subprocess として内部から呼ぶ**設計であり、GitHub Actions 側が Task/エージェントを編成する必要がない。§4 を claude-code-action 前提から書き直した |
| 3 | NFR-05 のしきい値判定を CI 側で再実装しない | `--fail-on-unresolved-rate` フラグを CLI に委譲し、`report-json` の `quality.nfr05` を表示のみに使う |
| 4 | `runs.json`（JSON オブジェクト）に統一 | `extraction-runs.jsonl` の独自定義を撤回。冪等性検証から `runs.json` を除外 |
| 5 | `2>/dev/null` / `\|\| true` を実際に除去 | `gh label create --force` の冪等性を利用、`gh issue create` の URL 末尾抽出に統一 |
| 6 | task-log を PR に同梱 | main 直コミットの新設を解消。PR 番号の追記のみ post-merge の main 直コミット（許可済み操作）で行う |
| 7 | テストフレームワークを `unittest` に統一 | 実装設計 §7.1 の「外部依存を増やさない」方針に合わせ、pytest/coverage を撤回 |
| 8 | claude-code-action 固有の記述を整理 | model ID・`claude_args` の議論は変更 2 により本書の対象外になったため削除。既存 2 workflow（daily-digest-automation.yml 等）でこの形式が稼働している事実の注記のみ §8 に残す |

以下の本文は上記を反映した内容である。

---

## 1. 概要

### 1.1 本書の位置づけとスコープ

本書は `retail-stats-tracker-requirements.md`（**要件定義 v0.1.1**）と `retail-stats-tracker-design.md`（実装設計、2,302 行、確定済み）を受けて、日次自動更新（FR-21）・差分レポート（FR-22）・LLM フォールバックの実行主体（7-10 未決事項）・品質ゲートの CI 統合・可観測性・導入ロードマップを CI/CD の観点で設計するものである。

**実装設計を実装契約の正とする**。CLI のパス・引数・終了コード・データファイル形式について、本書と実装設計が食い違う場合は実装設計を採用する。

**スコープ外（他部署が担当）**:

- **検証 hooks（PreToolUse / PostToolUse 等）の設計** — ai-developer が担当するループエンジニアリング設計書（`retail-stats-tracker-loop-engineering-design.md`）のスコープ。本書では触れない
- パーサ本体（決定論パースの正規表現ルール・カタログ読込ロジック）の実装詳細 — system-architect / ai-developer 側の担当（実装設計 §2-§7）。本書は実装設計 §2.5 の **CLI インターフェース契約**をそのまま採用し、CI からどう呼び出すかのみを設計する
- 静的 HTML の画面構成（SC-01〜SC-06）の実装 — 本書は生成タイミングと機械チェック観点のみを扱う
- `--report-json` の最終的な JSON キー名の確定 — 実装設計 §8「M7. 運用への接続」が「CLI が返す終了コードと `--report-json` の形式を確定させるところまでを担当する」と明記しており、`quality.nfr05` 以外の一部キー（後述 §5・§8）は本書執筆時点で確定していない。**この点は本書の未決事項として §8 に明記する**

本書の担当範囲は **GitHub Actions workflow・ブランチ/PR 運用・品質ゲートの機械的検証・可観測性・段階導入計画** に限定する。

### 1.2 全体像

```
[07:30 JST]                                    [workflow_run トリガー]
daily-digest-automation.yml                    retail-stats-daily-update.yml
  Phase 1-8 完了                                    │
  (docs/daily-digest/YYYY-MM-DD.md が merge 済)      ▼
       │                                    ① 起点チェック
       │                                       当日分 MD の存在確認
       │ conclusion=success で発火               │
       └──────────────────────────────────────▶ ② パイプライン実行
                                                   python3 -m retail_stats build --no-llm
                                                   （実装設計 §2.5 の CLI 契約に準拠）
                                                       │
                                              ③ NFR-06 再現性チェック
                                                 （同一コマンドを再実行し diff。
                                                   runs.json は比較対象から除外）
                                                       │
                                              ④ 品質情報の表示（warning のみ）
                                                 report-json の quality.nfr05 等を
                                                 そのまま転記。CI 側で計算式を再実装しない
                                                       │
                                              ⑤ 差分レポート生成（FR-22）
                                                       │
                                              ⑥ 静的 HTML 再生成
                                                 python3 -m retail_stats html
                                                 （data 変更がある場合のみ）
                                                       │
                                              ⑦ 機械チェック（自己完結性・禁則）
                                                       │
                                              ⑧ task-log 同梱 → PR 作成 → 即 squash merge
                                                 → post-merge で task-log に PR 番号追記
                                                   （main 直コミット許可済み操作のみ）
                                                 → Issue 作成
                                                       │
                                                       ▼
                                        docs/retail-stats/index.html
                                        （GitHub Pages 配信）

[週次 日曜 09:00 JST]                           [独立 workflow・低頻度]
retail-stats-llm-fallback.yml
  claude CLI（headless）を PATH に用意し認証情報を環境変数で渡すのみ。
  python3 -m retail_stats build --rebuild を実行すると、
  実装設計 §4.6.1 の ClaudeCliClient が内部で claude CLI を subprocess 呼び出しする。
  GitHub Actions 側は claude-code-action も Task エージェントも使わない（§4 参照）。
```

日次自動化は**決定論パースのみ**（`--no-llm`）とし、LLM フォールバックは週次の独立 workflow に分離する。この判断の根拠は §2.2 で述べる。

---

## 2. 日次自動更新ワークフロー設計

### 2.1 daily-digest-automation.yml との連携方法

既存の `.github/workflows/daily-digest-automation.yml`（07:30 JST cron）を実際に読んだ上で、以下の理由から **`workflow_run` トリガー**を採用する:

| 方式 | 検討結果 |
|------|---------|
| **同一 workflow 内の後続ジョブ**（不採用） | daily-digest-automation.yml は Phase 7 で main に直接 push した直後に完結する設計。同一 workflow に混ぜると責務が曖昧になる |
| **別スケジュール**（不採用） | daily-digest-automation.yml は WebFetch 巡回を含み実行時間が変動するため、固定オフセットでは MD 未生成のままのレースコンディションを排除できない |
| **`workflow_run` トリガー**（採用） | `conclusion == 'success'` を条件にすることで当日分 MD の生成完了を確実に待てる |

```yaml
on:
  workflow_run:
    workflows: ["Daily Digest Automation (07:30 JST)"]
    types: [completed]
  workflow_dispatch:
    inputs:
      dry_run:
        description: "PR 作成をスキップして差分確認のみ"
        type: boolean
        default: false
```

`daily-digest-automation.yml` が「本日分 MD 既存のためスキップ」した場合も job 自体は `success` で完了するため `workflow_run` は発火する。この場合トラッカー側の「① 起点チェック」で当日分 MD の**内容に差分がない**ことを検出し、無変更のまま正常終了する（§2.3）。

### 2.2 LLM 抽出フォールバックの実行主体（7-10 未決事項への回答）

実装設計 §4.6.1 は「要件 7-10（LLM 実行主体）が未決のため、v0.1 は `ClaudeCliClient` によるローカル実行 + キャッシュ commit を既定とし、**日次自動実行は `--no-llm` で決定論パースのみとする**」と明記している。この方針を CI/CD 観点で検証し、**採用する**。根拠:

1. **NFR-11（コスト）**: キャッシュヒット率 95% 以上を想定。日次で新規 LLM 抽出が発生する行数はごく少数であり、この規模のために毎日 LLM 呼び出し経路を必須にする必要はない
2. **`ClaudeCliClient` は単発の headless プロンプト応答であり、エージェント的な複雑さを持たない**: 実装設計 §4.6.2/§4.6.3 が示す通り、1 記事 = 1 プロンプト = 1 JSON 応答の単純な subprocess 呼び出しである（Task ツールでのファイル編集や Agent Teams 的な編成は行わない）。したがって claude-code-action の落とし穴（認証 input parameter・job-level env・remote URL 再設定・`CLAUDE_CODE_DISABLE_BACKGROUND_TASKS`）は**そもそも本システムのアーキテクチャに存在しない**。詳細は §4 で述べる
3. **未解決行が急増した場合のバックプレッシャー**: `--fail-on-unresolved-rate` を週次 workflow のテスト・監視に用いることで、閾値超過を検知できる（§5）。まず決定論側の改善で対応し、LLM 呼び出し頻度を上げるのは最終手段とする

この判断により、日次 workflow（`retail-stats-daily-update.yml`）は `--no-llm` を渡し、`claude` CLI を一切必要としない。週次 workflow（`retail-stats-llm-fallback.yml`）でのみ `claude` CLI を PATH に用意する（§4）。

### 2.3 差分がない日は commit しない（FR-21）実装方法

パイプラインは常に `.companies/domain-tech-collection/docs/retail-stats/data/` 配下のファイルを再生成するが、CI 側では **`git status --porcelain` による差分の有無**でその後の HTML 再生成・commit・PR 作成をすべてスキップする。natural key upsert（FR-09）により、同一入力を再実行しても出力ファイルはバイト単位で不変（NFR-06、`runs.json` を除く）なので、`git diff` に現れない = 実質的な差分なしと判定できる。

### 2.4 成果物の配置とコミット方針

`.claude/rules/git-workflow.md` の「main 直コミット許可」対象リストには retail-stats-tracker の成果物は含まれていない。したがって **原則どおり PR 運用**とする。

JSON（中間データ）と HTML（配信物）を同一ブランチ・同一 PR にまとめ、1 回の squash merge で完結させる。main 直コミットの新設は行わない。

**task-log の扱い（v0.2 で修正）**: task-log ファイルの**新規作成**は成果物 PR に同梱する（main 直コミットでは行わない）。PR マージ後に task-log の `pr_number` を実際の PR 番号で埋める更新のみを main 直コミットで行う。これは `.claude/rules/git-workflow.md` が明示的に許可する「マージ後のタスクログ `completed` 更新（Issue/PR番号追記）」に該当し、新規ファイル作成ではなく既存ファイルのフィールド追記であるため許可リストの範囲内である。v0.1 では task-log の新規作成そのものを main 直コミットで行っており矛盾していた（§3.1 で修正）。

| 成果物 | 配置先 | コミット方式 |
|--------|--------|------------|
| `observations.json` / `articles.json` / `extraction-cache.json` / `unresolved.json` / `manifest.json` / `series.json` / `runs.json` | `.companies/domain-tech-collection/docs/retail-stats/data/` | PR（組織スコープ・証跡） |
| `index.html` | `docs/retail-stats/index.html` | 同一 PR（Pages 配信） |
| `.task-log/{task-id}.md`（新規作成） | `.companies/domain-tech-collection/.task-log/` | 同一 PR に同梱 |
| `.task-log/{task-id}.md` の `pr_number` 追記のみ | 同上 | post-merge の main 直コミット（許可済み） |
| `docs/index.html` へのリンク追加（IF-05） | `docs/index.html` | **日次 workflow の対象外**。ロードマップ Stage 1 で 1 回だけ手動 PR（§7） |

---

## 3. workflow YAML 設計

### 3.1 `retail-stats-daily-update.yml`（日次自動更新・決定論パースのみ）

```yaml
name: Retail Stats Tracker - Daily Update

# daily-digest-automation.yml の完了を受けて起動し、当日分の
# 「決算・統計」章を決定論パースのみで取り込む（LLM フォールバックは含まない。
# 設計判断の根拠は retail-stats-tracker-cicd-design.md §2.2 を参照）。
#
# CLI 契約は実装設計 retail-stats-tracker-design.md §2.5 に準拠する
# （scripts/retail-stats-tracker/retail_stats/ を python3 -m retail_stats で起動）。
#
# 既知の落とし穴への対策（CLAUDE.md 準拠）:
#   - 全 step 冒頭に set -euo pipefail。2>/dev/null によるエラー握り潰し禁止
#   - cmd | tee log の pipefail 問題は PIPESTATUS で明示的に exit code を捕捉
#   - branch protection 不在のため --auto は使わず直接 --squash --delete-branch
#   - JSON/HTML/task-log(新規) を同一 PR にまとめ、main 直コミットの新設を避ける（§2.4）
#   - gh label create は --force のみ（冪等）で 2>/dev/null || true を使わない
#   - gh issue create は --json/--jq 未対応のため URL 末尾から番号を取る

on:
  workflow_run:
    workflows: ["Daily Digest Automation (07:30 JST)"]
    types: [completed]
  workflow_dispatch:
    inputs:
      skip_pr:
        description: "PR 作成をスキップして差分確認のみ（CLI 自体の --dry-run とは別物）"
        type: boolean
        default: false

permissions:
  contents: write
  pull-requests: write
  issues: write

concurrency:
  group: retail-stats-daily-update
  cancel-in-progress: false

env:
  ORG_SLUG: domain-tech-collection
  DIGEST_DIR: .companies/domain-tech-collection/docs/daily-digest
  DATA_DIR: .companies/domain-tech-collection/docs/retail-stats/data
  HTML_PATH: docs/retail-stats/index.html
  PACKAGE_DIR: scripts/retail-stats-tracker
  TRACKING_LABEL: retail-stats-tracking

jobs:
  update:
    if: >
      github.event_name == 'workflow_dispatch' ||
      github.event.workflow_run.conclusion == 'success'
    runs-on: ubuntu-latest
    timeout-minutes: 20
    steps:
      - name: Checkout main
        uses: actions/checkout@v4
        with:
          ref: main
          fetch-depth: 0

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.11.9"

      # retail_stats パッケージは標準ライブラリのみに依存する設計
      # （実装設計 §7.1「外部依存を増やさない」方針）。pip install は不要。

      - name: Determine date & branch
        id: date
        run: |
          set -euo pipefail
          DATE_JST=$(TZ=Asia/Tokyo date +%Y-%m-%d)
          TIMESTAMP=$(TZ=Asia/Tokyo date +%Y%m%d-%H%M%S)
          STARTED_ISO=$(TZ=Asia/Tokyo date +%Y-%m-%dT%H:%M:%S+09:00)
          BRANCH="${ORG_SLUG}/chore/${DATE_JST}-retail-stats-update"
          {
            echo "date_jst=$DATE_JST"
            echo "started_iso=$STARTED_ISO"
            echo "task_id=${TIMESTAMP}-retail-stats-daily"
            echo "branch=$BRANCH"
          } >> "$GITHUB_OUTPUT"

      - name: Check source digest exists
        id: source
        run: |
          set -euo pipefail
          MD="${DIGEST_DIR}/${{ steps.date.outputs.date_jst }}.md"
          if [ ! -f "$MD" ]; then
            echo "::warning::本日分ダイジェスト未生成のためスキップ: $MD"
            echo "skip=true" >> "$GITHUB_OUTPUT"
          else
            echo "skip=false" >> "$GITHUB_OUTPUT"
          fi

      - name: Create branch
        if: steps.source.outputs.skip != 'true'
        run: |
          set -euo pipefail
          git config user.email "retail-stats-bot@users.noreply.github.com"
          git config user.name "Retail Stats Bot"
          git checkout -b "${{ steps.date.outputs.branch }}"

      - name: Run pipeline (build --no-llm)
        id: pipeline
        if: steps.source.outputs.skip != 'true'
        run: |
          set -euo pipefail
          REPORT=/tmp/retail-stats-run-report.json
          set +e
          (cd "$PACKAGE_DIR" && python3 -m retail_stats build \
            --no-llm \
            --org "$ORG_SLUG" \
            --report-json "$REPORT") \
            2>&1 | tee /tmp/pipeline.log
          PIPELINE_EXIT="${PIPESTATUS[0]}"
          set -e
          # 実装設計 §2.5 の終了コード契約: 0=正常 / 1=データ不整合(カタログ検証失敗・
          # 未解決率超過) / 2=引数エラー / 3=I/O エラー。--fail-on-unresolved-rate を
          # 渡していないため、日次実行での exit=1 はカタログ整合エラー（FR-24）を意味する。
          if [ "$PIPELINE_EXIT" -ne 0 ]; then
            echo "::error::retail_stats build が異常終了 (exit=$PIPELINE_EXIT)。pipeline.log を確認してください"
            exit 1
          fi
          [ -f "$REPORT" ] || { echo "::error::report-json が生成されませんでした"; exit 1; }
          echo "report_path=$REPORT" >> "$GITHUB_OUTPUT"

      - name: Verify idempotency (NFR-06)
        if: steps.source.outputs.skip != 'true'
        run: |
          set -euo pipefail
          cp -r "$DATA_DIR" /tmp/data-first-run
          (cd "$PACKAGE_DIR" && python3 -m retail_stats build \
            --no-llm \
            --org "$ORG_SLUG" \
            --report-json /tmp/retail-stats-run-report-2.json)
          # runs.json は実行時刻を含むためバイト一致保証の対象外
          # （実装設計 §5.1）。比較から明示的に除外する。
          if ! diff -rq --exclude='runs.json' /tmp/data-first-run "$DATA_DIR" > /tmp/idempotency-diff.log; then
            echo "::error::NFR-06 再現性チェック失敗。再実行で出力が変化しました"
            cat /tmp/idempotency-diff.log
            exit 1
          fi
          echo "::notice::NFR-06 idempotency check passed (runs.json excluded)"

      - name: Generate diff report (FR-22)
        id: diff
        if: steps.source.outputs.skip != 'true'
        run: |
          set -euo pipefail
          # quality.nfr05 等は report.py が算出した値をそのまま転記する。
          # CI 側で分母・分子を再計算しない（旧版の設計不備の是正）。
          # トップレベルの created/updated 等のキー名は実装設計 M7 で system-architect と
          # 最終確認する（本書執筆時点では report.py の出力例が series.json の quality
          # ブロックのみ確認できているため、.get() で欠落時も落ちないようにしている）。
          python3 - <<'PYEOF' > /tmp/diff-report.md
          import json
          report = json.load(open("${{ steps.pipeline.outputs.report_path }}"))
          q = report.get("quality", {})
          nfr05 = q.get("nfr05", {})
          by_method = q.get("by_method", {})
          print("| 項目 | 値 |")
          print("|---|---|")
          print(f"| 新規 observation | {report.get('created', 'N/A')} |")
          print(f"| 更新 observation | {report.get('updated', 'N/A')} |")
          print(f"| 未解決行 | {report.get('unresolved_count', 'N/A')} |")
          print(f"| decision内訳 (deterministic/llm/manual) | {by_method.get('deterministic','?')}/{by_method.get('llm','?')}/{by_method.get('manual','?')} |")
          if nfr05:
              print(f"| NFR-05 (対象内行のみ) | {nfr05.get('numerator')}/{nfr05.get('denominator')} = {nfr05.get('rate', 0):.1%}（目標 {nfr05.get('target', 0.8):.0%}） |")
          PYEOF
          cat /tmp/diff-report.md >> "$GITHUB_STEP_SUMMARY"
          if git status --porcelain "$DATA_DIR" | grep -q .; then
            echo "has_changes=true" >> "$GITHUB_OUTPUT"
          else
            echo "has_changes=false" >> "$GITHUB_OUTPUT"
          fi

      - name: Regenerate static HTML
        if: steps.source.outputs.skip != 'true' && steps.diff.outputs.has_changes == 'true'
        run: |
          set -euo pipefail
          (cd "$PACKAGE_DIR" && python3 -m retail_stats html --org "$ORG_SLUG")

      - name: Machine checks (L0-equivalent)
        if: steps.source.outputs.skip != 'true' && steps.diff.outputs.has_changes == 'true'
        run: |
          set -euo pipefail
          # NFR-08 自己完結性: 外部 script 参照・実行時 fetch が無いこと
          if grep -Eo '<script[^>]+src="https?://' "$HTML_PATH"; then
            echo "::error::外部 script 参照を検出（NFR-08 違反）"; exit 1
          fi
          if grep -q "fetch(" "$HTML_PATH"; then
            echo "::error::実行時 fetch を検出（NFR-08 違反）"; exit 1
          fi
          # NFR-13 禁則: 矢印記号の使用禁止（符号付き数値+テキストで表現すること）
          if grep -P '[\x{2190}-\x{21FF}\x{2B00}-\x{2BFF}]' "$HTML_PATH" > /dev/null; then
            echo "::error::矢印記号を検出（NFR-13 違反）"; exit 1
          fi
          echo "::notice::machine checks passed"

      - name: Prepare task-log (bundled into PR, not main-direct)
        id: tasklog
        if: steps.source.outputs.skip != 'true' && steps.diff.outputs.has_changes == 'true' && github.event.inputs.skip_pr != 'true'
        run: |
          set -euo pipefail
          TASKLOG=".companies/${ORG_SLUG}/.task-log/${{ steps.date.outputs.task_id }}.md"
          cat > "$TASKLOG" <<EOF
          ---
          task_id: "${{ steps.date.outputs.task_id }}"
          org: "${ORG_SLUG}"
          operator: "github-actions-bot"
          status: completed
          mode: "direct-actions"
          started: "${{ steps.date.outputs.started_iso }}"
          completed: "$(TZ=Asia/Tokyo date +%Y-%m-%dT%H:%M:%S+09:00)"
          request: "retail-stats-daily-update.yml workflow_run (daily-digest-automation.yml)"
          issue_number: null
          pr_number: null
          subagents: []
          l0_gate: pass
          l0_retries: 0
          l1_gate: null
          l1_retries: 0
          l2_composite: null
          l2_retries: 0
          ---

          ## 実行計画
          - 実行モード: direct（決定論パースのみ、LLM フォールバックなし）
          - 判断理由: retail-stats-tracker-cicd-design.md §2.2 参照

          ## エージェント作業ログ
          ### [${{ steps.date.outputs.started_iso }}] retail-stats-daily-update.yml
          \`python3 -m retail_stats build --no-llm\` 実行 → NFR-06 再現性検証 → 差分レポート生成

          ## 差分サマリー
          $(cat /tmp/diff-report.md)
          EOF
          echo "tasklog_path=$TASKLOG" >> "$GITHUB_OUTPUT"

      - name: Commit & create PR
        id: pr
        if: steps.source.outputs.skip != 'true' && steps.diff.outputs.has_changes == 'true' && github.event.inputs.skip_pr != 'true'
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          set -euo pipefail
          git add "$DATA_DIR" "$HTML_PATH" "${{ steps.tasklog.outputs.tasklog_path }}"
          git commit -m "chore: 小売統計トラッカー日次更新 ${{ steps.date.outputs.date_jst }} [${ORG_SLUG}] by retail-stats-bot"
          git push origin "${{ steps.date.outputs.branch }}"

          PR_BODY=$(cat <<EOF
          ## 概要
          - 小売月次統計トラッカー日次更新 ${{ steps.date.outputs.date_jst }}

          ## 差分サマリー (FR-22)
          $(cat /tmp/diff-report.md)

          ## 検証
          - NFR-06 再現性チェック: pass（runs.json を除く）
          - 機械チェック（自己完結性・禁則）: pass

          ---
          🤖 Generated by retail-stats-daily-update.yml — https://github.com/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}
          EOF
          )

          # --force は既存ラベルを冪等に更新するため 2>/dev/null || true は不要
          gh label create "retail-stats-tracker" --color "0e8a16" --force
          gh label create "org:${ORG_SLUG}" --color "0075ca" --force

          PR_URL=$(gh pr create \
            --title "chore: 小売統計トラッカー日次更新 ${{ steps.date.outputs.date_jst }} [${ORG_SLUG}]" \
            --body "$PR_BODY" \
            --label "retail-stats-tracker,org:${ORG_SLUG}" \
            --base main \
            --head "${{ steps.date.outputs.branch }}")
          # gh pr create は URL を標準出力するため、番号は末尾から取る
          PR_NUMBER="${PR_URL##*/}"
          gh pr merge "$PR_NUMBER" --squash --delete-branch
          {
            echo "pr_url=$PR_URL"
            echo "pr_number=$PR_NUMBER"
          } >> "$GITHUB_OUTPUT"

      - name: Update task-log with PR number (main-direct, whitelisted)
        if: steps.source.outputs.skip != 'true' && steps.diff.outputs.has_changes == 'true' && github.event.inputs.skip_pr != 'true'
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          set -euo pipefail
          # .claude/rules/git-workflow.md が明示的に許可する
          # 「マージ後のタスクログ completed 更新（Issue/PR番号追記）」に該当する。
          # task-log ファイル自体の新規作成は上記の PR に同梱済みであり、
          # ここでは既存フィールド(pr_number)の書き換えのみを行う。
          git checkout main
          git pull origin main
          TASKLOG="${{ steps.tasklog.outputs.tasklog_path }}"
          python3 - "$TASKLOG" "${{ steps.pr.outputs.pr_number }}" <<'PYEOF'
          import sys, re
          path, pr_number = sys.argv[1], sys.argv[2]
          text = open(path, encoding="utf-8").read()
          text = re.sub(r"^pr_number: null$", f"pr_number: {pr_number}", text, count=1, flags=re.M)
          open(path, "w", encoding="utf-8").write(text)
          PYEOF
          git add "$TASKLOG"
          git commit -m "chore: task-log PR番号追記 ${{ steps.date.outputs.date_jst }} [${ORG_SLUG}] by retail-stats-bot"
          git push origin main

      - name: Create Issue
        if: steps.source.outputs.skip != 'true' && steps.diff.outputs.has_changes == 'true' && github.event.inputs.skip_pr != 'true'
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          set -euo pipefail
          gh label create "type:retail-stats" --color "008672" --force
          gh label create "dept:research" --color "7057ff" --force
          gh issue create \
            --title "[${ORG_SLUG}] 小売統計トラッカー日次更新 ${{ steps.date.outputs.date_jst }} - auto" \
            --label "org:${ORG_SLUG},mode:direct,type:retail-stats,dept:research" \
            --body "PR: ${{ steps.pr.outputs.pr_url }}

          $(cat /tmp/diff-report.md)

          🤖 Generated by retail-stats-daily-update.yml" >/dev/null

      - name: Notify on failure or skip (avoid silent fail)
        if: always()
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          JOB_STATUS: ${{ job.status }}
          RUN_URL: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}
        run: |
          set -euo pipefail
          if [ "$JOB_STATUS" = "success" ]; then
            exit 0
          fi
          gh label create "${TRACKING_LABEL}" --color "fbca04" --force
          # --jq '.[0].number // empty' で該当なし時に null ではなく空文字を返す
          ISSUE_NUMBER=$(gh issue list --label "${TRACKING_LABEL}" --state open \
            --json number --jq '.[0].number // empty')
          if [ -z "$ISSUE_NUMBER" ]; then
            # gh issue create は --json/--jq 未対応のため URL 末尾から番号を取る
            ISSUE_URL=$(gh issue create \
              --title "retail-stats-tracker: 自動更新トラッキング" \
              --label "${TRACKING_LABEL}" \
              --body "retail-stats-daily-update.yml の実行履歴を記録します。")
            ISSUE_NUMBER="${ISSUE_URL##*/}"
          fi
          gh issue comment "$ISSUE_NUMBER" --body "❌ **${{ steps.date.outputs.date_jst || 'unknown' }}** job status=\`${JOB_STATUS}\` — ${RUN_URL}"
```

### 3.2 CLI インターフェース契約（実装設計 §2.5 に準拠、`scripts/retail-stats-tracker/`）

実装設計 §2.5 をそのまま CI からの呼び出し契約として採用する。v0.1 で本書が独自定義していた `pipeline.py --mode/--digest-dir/--catalog/--data-dir/--llm-fallback` は廃止する。

**エントリポイント**: `scripts/retail-stats-tracker/` を cwd にして `python3 -m retail_stats <サブコマンド>` で起動する（パッケージが同ディレクトリ配下にあるため）。

| サブコマンド | 用途 |
|---|---|
| `build` | 決定論パース + upsert（既定は増分実行、FR-12） |
| `html` | 静的 HTML のみ再生成（データは変更しない） |
| `measure` | reason_code 別の未解決分布・NFR-04/05 を計測（データは変更しない想定） |

| 引数 | 対象サブコマンド | 既定値 | CI での用途 |
|---|---|---|---|
| `--org SLUG` | build / html / measure | `domain-tech-collection` | 全 workflow で明示指定する |
| `--rebuild` | build / measure | off | 週次 LLM フォールバック・テスト workflow の golden dataset 検証で使用 |
| `--since YYYY-MM-DD` | build / measure | なし | 本書の workflow では未使用（デバッグ用） |
| `--invalidate-cache` | build | off | **CI からは指定しない**（キャッシュ破棄は明示操作のみ許可、要件リスク 7-6） |
| `--no-llm` | build / measure | off | **日次 workflow で必須指定**（§2.2 の判断） |
| `--dry-run` | build | off | 本書の workflow では未使用。ワークフロー側の `skip_pr` 入力とは別概念であることに注意 |
| `--report-json PATH` | build / measure | なし | 全 workflow で指定し、差分レポート・品質情報の表示に使う |
| `--fail-on-unresolved-rate R` | build / measure | なし | **`retail-stats-tests.yml` でのみ指定**（§5）。日次・週次では指定せず warning 表示に留める |

**終了コード**（実装設計 §2.5）: `0` = 正常、`1` = データ不整合（カタログ検証失敗・`--fail-on-unresolved-rate` 指定時の未解決率超過）、`2` = 引数エラー、`3` = I/O エラー。日次 workflow は `--fail-on-unresolved-rate` を渡さないため、日次実行での `exit=1` は事実上カタログ整合エラー（FR-24）のみを意味する。`2>/dev/null` や `\|\| true` による握り潰しは CLI 自体も行わない（NFR-10、実装設計 §2.5 に明記）。

**`--report-json` の出力形状**: 実装設計は `series.json` の `quality` オブジェクト（`by_method` / `by_reason_code` / `nfr05.{denominator,numerator,rate,target}` / `out_of_scope_breakdown` / `duplication`）を明確に定義しているが、`build`/`measure` の `--report-json` トップレベルのキー名（新規/更新件数など）は実装設計 M7（本書執筆時点で未着手）で確定する。**本書の CI は `quality` ブロックのキー名のみを確定情報として扱い、それ以外は `.get()` で欠落を許容する防御的な読み方をする**（§8 未決事項）。

---

## 4. LLM 抽出フォールバックの実行方式（週次）

### 4.1 v0.1 からの設計変更: claude-code-action を使わない

v0.1 は要件書 IF-03「Claude Code Task（subagent）」の記述から、GitHub Actions 上で `claude-code-action` を用いてエージェント的にファイルを読み書きさせる設計を組んでいた。しかし実装設計 §4.6.1 を読むと、実際の LLM 呼び出しは以下の単純な構造であることが分かる:

```python
class ClaudeCliClient:
    """claude CLI の headless モードを subprocess で呼ぶ。
    stderr は握り潰さずそのまま伝播する（NFR-10）。"""
    def __init__(self, model: str = "claude-sonnet-5", timeout_s: int = 120): ...
    def extract(self, prompt: str) -> str: ...
```

つまり `llm.py` が **1 記事 = 1 プロンプト = 1 JSON 応答**の単発 headless 呼び出しを Python の `subprocess` から行うだけであり、Task ツールでのファイル編集・Agent Teams 的なチーム編成・複数ターンの対話は発生しない。この場合、CI 側がやるべきことは「`claude` CLI を PATH に用意し、認証情報を環境変数で渡した状態で `python3 -m retail_stats build --rebuild` を実行する」だけであり、`claude-code-action` を workflow に組み込む必要がない。

**この変更により、CLAUDE.md に記載された claude-code-action 固有の落とし穴（認証 input parameter / job-level env / remote URL 再設定 / `max-turns` / `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS`）はいずれも本ワークフローに適用対象がなくなる**。これらは `claude-code-action` という GitHub Action 特有の挙動（`with:` と `env:` の優先順位、post step の env 伝播、Task subagent のバックグラウンド化）に起因するものであり、単純な CLI subprocess 呼び出しにはそもそも存在しない問題である。同様に、v0.1 で問題視されていた `--model claude-opus-4-6`（世代不一致）や `claude_args`（仕様リファレンス未記載）の議論も、`claude-code-action` を使わなくなったことで本書から解消される。実装設計 §4.6.1 が既定モデルとして `claude-sonnet-5` を指定しているため、モデル選択自体は実装側の責務であり CI 側では指定しない。

### 4.2 `retail-stats-llm-fallback.yml`

```yaml
name: Retail Stats Tracker - Weekly LLM Fallback

# 週次で unresolved.json の未解決行を LLM 抽出にかける。
# 実装設計 §4.6.1 の ClaudeCliClient が `claude` CLI を subprocess で内部呼び出しするため、
# 本 workflow は claude-code-action を使わない（設計変更の根拠は本書 §4.1 参照）。
# 日次自動化に含めない設計判断の根拠は §2.2 参照。
#
# --rebuild を指定する理由: 増分実行（FR-12）は前回処理済みの digest ファイルを
# 再走査しないため、過去に unresolved のまま残った行は増分実行では再挑戦されない。
# 全件再走査すれば、既に解決済みの記事は extraction-cache.json のヒットで
# コストゼロのまま、真に未解決の記事のみが新規に LLM へ回る（NFR-11 のキャッシュ設計）。

on:
  schedule:
    # 毎週日曜 09:00 JST = 00:00 UTC
    - cron: "0 0 * * 0"
  workflow_dispatch:
    inputs:
      skip_pr:
        description: "PR 作成をスキップ"
        type: boolean
        default: false

permissions:
  contents: write
  pull-requests: write

concurrency:
  group: retail-stats-llm-fallback
  cancel-in-progress: false

env:
  ORG_SLUG: domain-tech-collection
  DATA_DIR: .companies/domain-tech-collection/docs/retail-stats/data
  PACKAGE_DIR: scripts/retail-stats-tracker

jobs:
  llm-fallback:
    runs-on: ubuntu-latest
    timeout-minutes: 30
    env:
      # claude CLI 自身が読む環境変数。claude-code-action の input parameter 経由ではなく
      # 通常の env でよい（Action を経由しないため §4.1 参照）
      ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
      CLAUDE_CODE_OAUTH_TOKEN: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          ref: main
          fetch-depth: 0

      - name: Pre-flight auth check
        run: |
          set -euo pipefail
          if [ -z "${ANTHROPIC_API_KEY:-}" ] && [ -z "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]; then
            echo "::error::認証情報未設定"; exit 1
          fi

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.11.9"

      - name: Install Claude Code CLI (pinned)
        run: |
          set -euo pipefail
          # バージョンは .mcp.json の uvx/npx ピン留め方針（CLAUDE.md）と同じ思想で固定する。
          # 実際のパッケージ名・検証済みバージョンは実装時に system-architect と確認する
          # （本書執筆時点でリポジトリ内に前例が無いため §8 の未決事項とする）
          npm install -g @anthropic-ai/claude-code@CONFIRM_PINNED_VERSION
          claude --version

      - name: Check unresolved backlog
        id: check
        run: |
          set -euo pipefail
          UNRESOLVED="${DATA_DIR}/unresolved.json"
          if [ ! -f "$UNRESOLVED" ]; then
            echo "count=0" >> "$GITHUB_OUTPUT"; exit 0
          fi
          # unresolved.json は {schema_version, rows: [...]} 形状（実装設計 §5.1）。
          # トップレベルのキー数を数える誤りを修正し、rows の要素数を数える。
          COUNT=$(python3 -c "import json; print(len(json.load(open('$UNRESOLVED'))['rows']))")
          echo "count=$COUNT" >> "$GITHUB_OUTPUT"
          if [ "$COUNT" -eq 0 ]; then
            echo "::notice::未解決行なし。それでも --rebuild は cache ヒットのみで軽量に完了する"
          fi

      - name: Determine date & branch
        id: date
        run: |
          set -euo pipefail
          DATE_JST=$(TZ=Asia/Tokyo date +%Y-%m-%d)
          BRANCH="${ORG_SLUG}/chore/${DATE_JST}-retail-stats-llm-fallback"
          echo "date_jst=$DATE_JST" >> "$GITHUB_OUTPUT"
          echo "branch=$BRANCH" >> "$GITHUB_OUTPUT"
          git config user.email "retail-stats-bot@users.noreply.github.com"
          git config user.name "Retail Stats Bot"
          git checkout -b "$BRANCH"

      - name: Run pipeline (build --rebuild, LLM enabled)
        id: pipeline
        run: |
          set -euo pipefail
          REPORT=/tmp/llm-fallback-report.json
          set +e
          (cd "$PACKAGE_DIR" && python3 -m retail_stats build \
            --rebuild \
            --org "$ORG_SLUG" \
            --report-json "$REPORT") \
            2>&1 | tee /tmp/llm-fallback.log
          PIPELINE_EXIT="${PIPESTATUS[0]}"
          set -e
          if [ "$PIPELINE_EXIT" -ne 0 ]; then
            echo "::error::retail_stats build が異常終了 (exit=$PIPELINE_EXIT)"
            exit 1
          fi
          echo "report_path=$REPORT" >> "$GITHUB_OUTPUT"

      - name: Regenerate static HTML
        run: |
          set -euo pipefail
          (cd "$PACKAGE_DIR" && python3 -m retail_stats html --org "$ORG_SLUG")

      - name: Commit & create PR
        if: github.event.inputs.skip_pr != 'true'
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          set -euo pipefail
          git add "$DATA_DIR" docs/retail-stats/index.html
          if git diff --cached --quiet; then
            echo "::notice::変更なし"; exit 0
          fi
          git commit -m "chore: 小売統計トラッカー週次LLMフォールバック ${{ steps.date.outputs.date_jst }} [${ORG_SLUG}] by retail-stats-bot"
          git push origin "${{ steps.date.outputs.branch }}"

          REPORT_SUMMARY=$(python3 - <<'PYEOF'
          import json
          r = json.load(open("${{ steps.pipeline.outputs.report_path }}"))
          q = r.get("quality", {})
          by_method = q.get("by_method", {})
          nfr05 = q.get("nfr05", {})
          print(f"llm 抽出件数: {by_method.get('llm', 'N/A')} / 残り unresolved: {r.get('unresolved_count', 'N/A')}")
          if nfr05:
              print(f"NFR-05: {nfr05.get('numerator')}/{nfr05.get('denominator')} = {nfr05.get('rate', 0):.1%}")
          PYEOF
          )

          gh label create "retail-stats-tracker" --color "0e8a16" --force
          PR_URL=$(gh pr create \
            --title "chore: 小売統計トラッカー週次LLMフォールバック [${ORG_SLUG}]" \
            --body "## 概要
          週次 LLM 抽出フォールバックによる unresolved 解消（\`build --rebuild\`、cache ヒットは再課金されない）。

          ## 結果
          $REPORT_SUMMARY

          ---
          🤖 Generated by retail-stats-llm-fallback.yml" \
            --label "retail-stats-tracker" \
            --base main \
            --head "${{ steps.date.outputs.branch }}")
          PR_NUMBER="${PR_URL##*/}"
          # ロードマップ Stage 1-2 では auto-merge せず人手レビューを必須とする（§7）。
          # Stage 3 以降で以下を有効化する:
          # gh pr merge "$PR_NUMBER" --squash --delete-branch
          echo "::notice::PR created (manual review required at current stage): $PR_URL"
```

### 4.3 そもそも CI で LLM を回すべきか

**判断: 回すが、頻度を週次に限定し、日次自動化からは完全に分離する。**（§2.2 の理由と同一）

§4.1 の設計変更により、CI で LLM を回すことの複雑度は当初想定より大幅に低い（`claude-code-action` のオーケストレーションが不要なため）。それでも頻度を週次に限定するのは、NFR-11 が想定するコスト規模（新規解決対象がごく少数）に対し日次実行を追加する効果が薄く、`--rebuild` による全件再走査のコスト（キャッシュヒットで大部分は無料だが計算時間は発生する）を毎日払う理由がないためである。

---

## 5. 品質ゲートの CI 統合

本パイプラインは**決定論パース + 構造化データ生成**が中心であり、`/company-daily-digest` 等の L0/L1/L2 3層レビュー（`.claude/rules/review-pattern.md`）が前提とする「文面品質のLLM主観評価」は主要な検証対象ではない。そのため 3 層レビューをそのまま流用せず、以下のように **L0 相当の機械チェックのみ**で完結させる設計とする。

| 要件 | 検証方法 | 実行タイミング |
|------|---------|--------------|
| NFR-06（冪等性・バイト一致） | `build --no-llm` を 2 回実行し `diff -rq --exclude='runs.json'` で完全一致を確認。不一致は hard fail | 日次 workflow「Verify idempotency」step（§3.1） |
| NFR-04/05（決定論カバー率・抽出成功率） | `--report-json` の `quality.nfr05` を**表示するのみ**。CI 側で分母・分子を再計算しない | 日次・週次 workflow の diff report step |
| FR-24（カタログ整合チェック） | CLI の終了コード `1` を hard fail として扱う | 日次・週次 workflow 共通 |
| NFR-08（自己完結性） | 生成 HTML に対する `grep` チェック（外部 script src / fetch(）| 日次 workflow「Machine checks」step |
| NFR-13（アクセシビリティ表現） | 矢印記号 Unicode レンジの `grep -P` チェック | 同上 |
| テスト実行 | `python3 -m unittest discover` | 別 workflow（`retail-stats-tests.yml`、PR ベース） |
| NFR-05 の PR ゲート（`--fail-on-unresolved-rate`） | **v0.2 では warning のみ**。golden dataset に対する回帰テストでも hard fail にしない（後述） | `retail-stats-tests.yml` |

**NFR-04/05 を日次・週次・テストのいずれでも hard fail にしない理由（確定値を踏まえた再整理）**: しきい値割れは「今日のデータが壊れている」ではなく「決定論ルールの改善余地がある」ことを示すシグナルであり、PR マージをブロックすべき性質のものではない（要件書リスク#7 の対応方針と一致）。

実装設計 §4.3.7・§9.4 の U9 は、NFR-05 の実測を **64/83 = 77.1%（対象内行のみ、目標 80% に対し未達で確定）** としている。これは初版申告の「75/90 = 83.3%（達成、余裕 3.3 ポイント）」を「指標の解決可否を検査していなかった過大計上であり誤りだった」と実装設計自身が明示的に撤回した後の確定値であり、v0.1 の本節が引用していた「達成率 83.3% は余裕が小さい」という記述はもはや実装設計に存在しない。

U9 は目標値 80% の引き下げを提案しておらず、82.1% まで到達する経路（左窓の節境界緩和等）が実測で存在するとした上で、「M3 で誤抽出率と併せて検証してからでなければ採用できない。現時点で達成を宣言しない」としている。この設計判断（**未達であることを可視化しつつ開発は止めない**）を CI の運用にもそのまま反映し、NFR-05 は達成が M3 で確定するまで**全ての workflow で warning 表示に留める**（golden dataset に対する回帰テストも含む。詳細は §5.1）。一方 FR-24 のカタログ整合エラーは**未定義 ID の暗黙生成という致命的なデータ破損**につながるため、これとは切り離して hard fail のままとする。

NFR-04（主要 4 業態の月次既存店指標カバー率）は `series.json` の `quality` ブロックに専用キーが確認できていない。この検証は実装設計 M7 で `--report-json` の形式を system-architect と確定する際にあわせて確認し、キーが定まり次第 §3.1 の diff report step に追記する（§8 未決事項）。

### 5.1 テスト実行（`retail-stats-tests.yml`）

実装設計 §7.1 は「フレームワークは標準ライブラリの `unittest`。外部依存を増やさない（NFR-08 の思想を開発環境にも適用）」と明記している。v0.1 は pytest + pytest-cov を前提にしており矛盾していたため、本改訂で `unittest` に統一する（coverage 計測は外部パッケージ追加になるため v0.1 のスコープでは行わない。テストケースの網羅性は実装設計 §7.2 の必須テストケース一覧の充足で担保する）。

```yaml
name: Retail Stats Tracker - Tests

on:
  pull_request:
    paths:
      - "scripts/retail-stats-tracker/**"
      - ".companies/domain-tech-collection/docs/retail-domain/retail-monthly-kpi-catalog.md"

permissions:
  contents: read

env:
  PACKAGE_DIR: scripts/retail-stats-tracker

jobs:
  test:
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-python@v5
        with:
          python-version: "3.11.9"

      # 外部パッケージを追加しない方針（実装設計 §7.1）。pip install は不要。

      - name: Run unit tests (unittest)
        run: |
          set -euo pipefail
          python3 -m unittest discover -s "${PACKAGE_DIR}/tests" -v

      - name: Regression test against golden dataset (現在 102 ファイル / 595 行)
        run: |
          set -euo pipefail
          REPORT=/tmp/golden-report.json
          set +e
          (cd "$PACKAGE_DIR" && python3 -m retail_stats measure \
            --rebuild \
            --org domain-tech-collection \
            --report-json "$REPORT" \
            --fail-on-unresolved-rate 0.20) \
            2>&1 | tee /tmp/golden.log
          MEASURE_EXIT="${PIPESTATUS[0]}"
          set -e
          python3 - "$REPORT" <<'PYEOF'
          import json, sys
          report = json.load(open(sys.argv[1]))
          nfr05 = report.get("quality", {}).get("nfr05", {})
          if nfr05:
              print(f"NFR-05: {nfr05.get('numerator')}/{nfr05.get('denominator')} = {nfr05.get('rate', 0):.1%}（目標 {nfr05.get('target', 0.8):.0%}）")
          PYEOF
          if [ "$MEASURE_EXIT" -ne 0 ]; then
            echo "::error::--fail-on-unresolved-rate 0.20 を超過（NFR-05 未達、CLI 自身の判定）。golden.log を確認してください"
            echo "::warning::NFR-05 の目標値自体が実装設計時点の見込みであり、margin が小さいことに留意（design.md 記載）"
            exit 1
          fi
```

`--fail-on-unresolved-rate` を CLI に渡すことで、**NFR-05 の分母・分子の定義（発表主体が協会統計・マクロ統計である行に限定）を CI 側で再実装しない**。分母の再定義ロジックは実装設計 §4.3.7 の判定木にのみ存在し、CI はその結果（exit code と `quality.nfr05`）を読むだけにする。

---

## 6. 可観測性・運用

### 6.1 実行ログ（NFR-10）

- CLI の行単位ログ（成功/フォールバック/未解決 + 理由コード）は `2>&1 | tee /tmp/pipeline.log` で捕捉し、`PIPESTATUS[0]` で終了コードを明示的に判定する（`| tee` の pipefail 問題を CLAUDE.md の指摘どおり回避）
- `pipeline.log` は必要に応じて `actions/upload-artifact@v4` で保持し、Git 管理対象の `--report-json` サマリーとは別に post-hoc デバッグ用に残す
- **`2>/dev/null` や `\|\| true` によるエラー握り潰しは行わない**。v0.1 では「§3.1・§4.1 のいずれの step にも存在しない」と断定していたが、実際には `gh label create` への `2>/dev/null || true`（複数箇所）、`gh issue list`/`gh issue create` への同様の握り潰しが存在し、自己矛盾していた。本改訂（§3.1・§4.2）で実際に除去した: `gh label create` は `--force` のみで冪等に動作するため抑制は不要、`gh issue list` は `--jq '.[0].number // empty'` で未検出時に空文字を返す、`gh issue create` は `--json`/`--jq` 非対応のため戻り値の URL 末尾から番号を取得する

### 6.2 差分レポートの出力先（FR-22）

3 箇所に出力し、用途を分ける:

| 出力先 | 用途 |
|--------|------|
| PR 本文 | マージ判断時に見る一次情報 |
| `$GITHUB_STEP_SUMMARY` | PR を開かず Actions run 一覧から素早く確認 |
| task-log（成果物 PR に同梱） | `.claude/rules/task-log.md` の「ファイル生成を伴う作業は task-log 必須」原則に従い、Case Bank 学習対象として記録 |

### 6.3 失敗時の通知（silent fail の防止）

- 全 step で `set -euo pipefail` を先頭に置く
- 「Notify on failure or skip」step を `if: always()` で常時実行し、失敗時のみ専用トラッキング Issue（`retail-stats-tracking` ラベル。v0.1 の `retail-stats-tracker-tracker` は既存ラベル `retail-stats-tracker` と紛らわしい重複表記だったため改名した）にコメントする
- この通知 step 自体が壊れていないことを §6.1 の修正で担保する（`gh issue list`/`gh issue create` の正しい呼び出し形式）
- NFR-04/05 の情報は annotation ではなく `$GITHUB_STEP_SUMMARY` とレポート本文に常に表示し、埋没させない

### 6.4 抽出成功率の推移追跡

`runs.json`（実装設計 §5.1 の ExtractionRun 永続化、直近 180 日保持）は **パイプライン自身（`store.py`）が管理・追記する**ファイルであり、CI 側が別途追記ロジックを持つ必要はない（v0.1 の `extraction-runs.jsonl` という独自形式・独自追記ロジックの定義は撤回する）。CI は `runs.json` を通常の成果物として `git add`（§3.1）し、冪等性検証からのみ明示的に除外する（§3.1 / §5）。

180 日超のエントリを月次サマリーに集約する処理、および TodoInsights 等の既存ダッシュボード連携（`daily-insights-sync.yml` 相当）への統合は、本書の CI/CD スコープを超えるため将来検討とする。

---

## 7. 導入ロードマップ

要件書 §8「今後の進め方」と実装設計 §8「実装ステップ」の M1〜M7 と整合させ、**手動実行 → 半自動（人手レビュー必須）→ 完全自動**の 3 段階を採用する。

| Stage | 内容 | 完了条件 |
|-------|------|---------|
| **Stage 1: 手動実行** | `python3 -m retail_stats measure --rebuild` をローカルで実行し golden dataset（現在 102 ファイル/595 行）に対する PoC を完了させる（実装設計 M3）。`docs/index.html` への retail-stats リンク追加を手動 PR で 1 回実施。`retail-stats-tests.yml` を有効化 | 実装設計 M3〜M4 の完了条件（NFR-04/05 の実測、`--rebuild` 2 回連続実行で `runs.json` 以外がバイト一致）を満たす。`docs/retail-stats/index.html` が初回生成され Pages に公開される |
| **Stage 2: 半自動（人手レビュー必須）** | `retail-stats-daily-update.yml` を有効化するが、「Commit & create PR」step の `gh pr merge` を一時的にコメントアウトし、PR 作成までで止める（人手マージ）。`retail-stats-llm-fallback.yml` も同様に PR 作成のみ | 2 週間（14 回分）の日次実行で NFR-01/02（実行時間）・NFR-06（再現性）が安定して満たされ、誤検知（想定外の upsert 上書き等）が発生しないことを確認 |
| **Stage 3: 完全自動** | 日次 workflow の `gh pr merge --squash --delete-branch` を有効化（本書 §3.1 の記載どおり）。週次 LLM フォールバックも自動 merge に切り替え | Stage 2 の観測期間中に手動介入が発生した件数が 0 件、かつ NFR-04/05 の warning が閾値を持続的に下回っていること |
| **Stage 4（将来検討・本書スコープ外）** | unresolved backlog が継続的に閾値超過する場合、週次 LLM フォールバックの頻度引き上げ、または決定論パースルールの拡充を別タスクとして起票 | 本書の対象外 |

---

## 8. 前提・制約・未決事項

### 前提

- `scripts/retail-stats-tracker/retail_stats/` の実装は system-architect / ai-developer 側が担当し、本書は実装設計 §2.5 の CLI 契約とワークフロー呼び出し部分のみを固定する
- 検証 hooks（PreToolUse / PostToolUse 等、ローカル開発時の防御）は ai-developer 側のループエンジニアリング設計書に委ねる。本書はあくまで GitHub Actions 上の CI/CD のみを扱う

### 制約

- branch protection が現状不在のため、全 workflow で `gh pr merge --squash --delete-branch` を用いる（`--auto` は使わない）
- `workflow_run` トリガーは対象 workflow が **default branch（main）上に存在する**必要がある

### 未決事項（本書 v0.2 で残るもの）

- **`--report-json` のトップレベルキー名**（新規/更新件数等）: 実装設計 M7 で system-architect と確定する。本書の CI は `quality` ブロック以外を `.get()` で防御的に読む設計としている（§3.2・§5）
- **NFR-04（主要 4 業態カバー率）の report-json キー**: `quality` ブロックに専用フィールドが確認できていない。M7 で確定次第、§3.1 の diff report step に追記する
- **`@anthropic-ai/claude-code` の npm パッケージ名・ピン留めバージョン**: リポジトリ内に前例が無いため、実装時に system-architect / ai-developer と確認し確定させる（§4.2 の `CONFIRM_PINNED_VERSION` プレースホルダ）
- **§7 Stage 2 → Stage 3 の移行判断者**: 「手動介入 0 件」の確認は誰が行うか（オーナー本人か、secretary 経由の定期報告か）は未確定
- **`docs/index.html` へのリンク追加の実施者**: Stage 1 で手動 PR を作成するとしたが、担当部署（technical-writer / secretary）は未確定
- **`runs.json` の 180 日超集約バッチ**: §6.4 の通り本書スコープ外。実装担当・実行頻度は別途決定が必要

---

_本書 v0.2 は `retail-stats-tracker-design.md`（実装設計、確定済み）を実装契約の正として全面的に整合を取り直したものである。CLI パス・引数・終了コード・データファイル形式は同設計書 §2.5 / §5.1 に一本化した。`.claude/rules/git-workflow.md` / `.claude/rules/artifact-placement.md` / `.claude/rules/review-pattern.md` / CLAUDE.md「注意事項」節、および `cc-spec-reference.md`（Claude Code 公式仕様リファレンス）にも引き続き準拠する。_
