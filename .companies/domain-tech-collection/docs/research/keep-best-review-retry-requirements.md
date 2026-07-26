# keep-best 付きレビューリトライ 要件定義書

## 3層レビュー基盤改修 — L1/L2 リトライ時の品質劣化防止・レビュー基準固定・承認キュー健全性

| 項目 | 内容 |
|------|------|
| ドキュメント種別 | 要件定義書 v0.1（ドラフト） |
| 作成日 | 2026-07-26 |
| 作成者 | 技術リサーチ室（qa-lead） |
| 対象システム | keep-best review retry（3層レビュー基盤改修） |
| ステータス | レビュー待ち |

---

## 1. 概要

### 1.1 背景

cc-sier の 3 層レビュー（L0 機械 / L1 セルフ構造 / L2 独立 LLM、@.claude/rules/review-pattern.md）は `/company-daily-digest`・`/company-diagram`・`/company-diagram-v2`・`/company-drawio`・`/company-sheet` の各 Skill で共通採用されている。現行のリトライポリシーは以下の通り：

> 「L1 fail → 秘書が自動修正 → 再チェック → それでも fail なら中断」
> 「L2 fail → reviewer の findings/fix_suggestions を秘書にフィードバック → 1 回修正 → 再採点 → fail なら auto-merge 中止」
> （`.claude/rules/review-pattern.md` リトライポリシー節）

この現行設計には、以下 3 つの構造的な穴がある。

#### 問題1: リトライで品質が劣化しても検知・巻き戻しできない（本丸）

根拠記事: [AI修正ループが良い原稿を壊す問題をkeep-bestで防ぐ](https://zenn.dev/miyoki_labs/articles/keepbest-revision-loop)

現行フローは成果物ファイルを **その場で上書き修正** するのみで、修正前のスナップショットを一切保持しない。修正が指摘箇所を直す過程で既に良かった別の箇所を壊しても、それを検知する仕組みが存在しない。

実際の task-log からも、この設計の弱点を裏付ける具体的な証拠が見つかった：

- `.task-log/20260419-080048-daily-digest-actions.md` — 初回 L2 レビューで `s6=0.65`（D章絵文字）・B6セクション欠落が指摘され fail。秘書が修正して再採点し `composite=0.95` で pass しているが、**YAML フロントマターの `l2_scores` には最終試行（2 回目）の値しか記録されておらず、初回試行の 6 軸内訳は自由記述のエージェント作業ログにしか残っていない**。初回試行が実際にどの軸で何点だったか、修正後にどの軸が下がったかは構造化データとして追跡不能。
- `.task-log/20260421-080642-daily-digest-actions.md` — `l1_retries: 1`（総記事数不整合を検出・修正）に加え、L2 は初回採点で **`composite=0.88`・verdict=pass** に到達した後、`B6記事URLの重複`・`D章絵文字`・`ロジスティクス・トゥデイ本文未掲載` の 3 点指摘を受けて秘書が追加修正を実施している（task-log L58「L2 採点結果 composite=0.88, verdict=pass」→ L60「秘書にて指摘修正を実施」の順）。**これは `20260418` と同型の「pass 判定後にも任意の追加修正が行われ、修正前バージョンが上書きで破棄される」事例の 2 例目**であり、修正前後のスコア比較データは存在せず「本当に直す前より良くなったか」は検証できない。
- `.task-log/20260418-125530-diagram-storcon-sales-aggregation-high-concurrency.md` — 初回 L2 は `composite=0.96` で **verdict=pass** だったにもかかわらず、reviewer が PNG のタイトル残骸（`test5`）と YAML の EventBridge Rule 欠落を指摘したため秘書が追加修正・再生成し `composite=1.00` に到達。**現行ルールは「fail のときだけ 1 回修正」だが、実運用では pass 判定後にも任意に追加修正が行われており、修正前バージョンが破棄される点は同じ**。仮にこの追加修正で何かが壊れていても検知できない。

#### 問題2: レビュー基準が後から変わると採点の一貫性が崩れる

根拠記事: [AIレビューの基準を後から変えない：Review DefinitionをPR headから解決する設計](https://zenn.dev/nnku/articles/f6c7a62b78a47e)

`references/review-prompt.md` は Skill 発動のたびに現行版が読み込まれるため、プロンプトを更新すると過去・進行中のタスクとの採点基準が食い違う。この懸念は仮説ではなく、**現行の `company-daily-digest/references/review-prompt.md` 自身が明示的にこの設計を選んでいる**ことが確認できた：

> 「調整履歴は本ファイルのバージョン履歴ではなく、運用ログ（`.task-log/` の `l2_composite` を集計）で追跡する」
> （`plugins/cc-sier/skills/company-daily-digest/references/review-prompt.md` L111、しきい値調整の運用メモ節）

同ファイルは続けて「fail 率が 30% を超える場合はしきい値を 0.80 に緩和」「全 pass が続く場合は致命軸基準を 0.7 に引き上げ」という**しきい値そのものを動的に調整する運用**を明記している（L108〜110）。加えて `.claude/rules/review-pattern.md` には過去に実際に review-prompt.md 側の判定基準（s6 絵文字禁止・B章全サブセクション必須）を修正した記録がある（2026-04-13 `s6=0.80`、2026-04-19 `s6=0.65→0.95`）。

つまり **prompt/しきい値の変更履歴を持たないまま、`l2_composite` の時系列集計だけで「品質トレンド」を判断する設計**になっている。これでは、しきい値緩和や採点基準変更による composite 上昇と、実質的な品質向上を区別できない。Case Bank・`/company-evolve` による継続学習が今後この集計に依存するほど、この問題は深刻化する。

#### 問題3: 承認キューのボトルネック化リスク

根拠記事: [AI承認待ちキューが月300件を超えてパンクした — 承認基準の自動化と例外設計](https://zenn.dev/joinclass/articles/ai-300-20260721220003-5956)

現状の PR 発行ペースを実測した：

| 対象 | 件数 | 期間 | 月換算 |
|---|---|---|---|
| `domain-tech-collection` の `pr_number` 付き task-log | 62 件 | 2026-03-21〜2026-07-26（約 127 日） | 約 14.7 件/月 |
| 全組織合計（`domain-tech-collection` + `standardization-initiative`） | 66 件 | 同上 | 約 15.6 件/月 |
| リポジトリ全体のマージ済み PR（`git log` 実測、task-log を伴わないものを含む） | 169 件 | 2026-03-18〜2026-07-26（約 130 日） | 約 39 件/月 |

上記 2 行は Skill 経由（task-log あり）の PR に限った値であり、承認キューの実負荷はリポジトリに届く PR 全体で決まる。したがって**評価に用いるべき分母は 3 行目の約 39 件/月**である。プラグイン開発・workflow 修正・`daily-todo-sync` 等の自動 PR が差分を構成する。

参考記事の「月 300 件でパンク」の水準に対し、現状は **約 1/8 の規模**。現時点で重厚な承認自動化基盤を作るのは過剰設計であるため、要件は「実測に基づく閾値監視の仕組みだけ用意し、実装は現状規模に見合う軽量な形にとどめる」段階的対応とする。ただし 1/20 ではなく 1/8 であり、増加ペース次第では想定より早く閾値に到達しうる点に留意する。

### 1.2 目的

1. L0/L1/L2 の各リトライで **修正前後の成果物とスコアをスナップショットとして保持し、最終的に composite が最良（かつ致命軸 fail でない）だった版を採用する** keep-best 機構を導入する
2. L2 採点に使用した `review-prompt.md` の版を task-log に記録し、**採点基準の変更が品質トレンド分析を歪めない**データ基盤を用意する
3. PR 発行ペースの実測値に基づき、**承認キューの将来的なボトルネック化を早期検知する軽量な監視方針**を定義する（現状規模では自動化は不要と判断し、段階的対応とする）

### 1.3 スコープ

| 区分 | 内容 |
|------|------|
| スコープ内 | keep-best スナップショット・採用判定ロジック、task-log YAML フロントマターの拡張（試行履歴・採用版・プロンプトバージョン）、`review-prompt.md` のバージョンフィールド追加、PR 発行ペースの監視方針（設計のみ）、影響を受ける全レビュー付き Skill（`company-daily-digest` / `company-diagram` / `company-diagram-v2` / `company-drawio` / `company-sheet`）と `.claude/rules/review-pattern.md`・`task-log.md` の改修範囲定義 |
| スコープ外（v0.1） | 承認キュー自動化の実装（監視ロジックの用意のみ）、L0/L1/L2 の 3 層構造自体の変更、pass 閾値 0.85・致命軸閾値 0.5 自体の変更、Agent Teams のコストポリシー変更、Codex レビューゲートウェイ（別要件定義書 `codex-review-gateway-requirements.md` の対象） |

### 1.4 システム構成概要

keep-best は独立サービスではなく、既存 Skill の Phase 内部に組み込むリトライ制御ロジックの改修である。

```
[秘書 (author)]                         [一時スナップショット領域]
   │                                     /tmp/cc-sier-keep-best/{task_id}/
   ├─ Phase N 初回生成 ──────────────▶  attempts/{layer}-1/ にコピー保存
   │                                          │
   ├─ L0/L1/L2 採点 ──記録──────────▶  attempts/{layer}-1/score.json
   │                                          │
   ├─ fail 時のみ 1 回修正 ─────────▶  attempts/{layer}-2/ にコピー保存
   │                                          │
   ├─ 再採点 ──記録──────────────────▶  attempts/{layer}-2/score.json
   │                                          │
   ├─ keep-best 判定 ◀────────────────  全 attempts の scores を比較
   │     └─ 致命軸 fail を除外 → composite 最大を採用
   │
   ├─ 採用版を成果物ディレクトリへ確定コピー
   │
   ├─ task-log に attempts 配列 + adopted_attempt を記録
   │
   └─ Phase 7 PR作成後、attempts/ を削除（リポジトリにはコミットしない）

[review-prompt.md]
   version フィールド（日付+連番）を Phase N の L2 呼び出し時に読み取り、
   attempt ごとに prompt_version としてハッシュ記録
```

- スナップショット領域はリポジトリ外（`/tmp` 配下）に置き、Git 管理対象にしない。攻撃対象領域を増やさず、`.task-log/` の可読性も損なわない
- 最終的に task-log に残るのは「試行ごとの採点結果」であり、生成物本体の全試行分は残さない（4.3 節）

---

## 2. 機能要件

### 2.1 keep-best スナップショット管理系（問題1対応）

| ID | 機能名 | 内容 | 優先度 |
|----|--------|------|--------|
| FR-01 | 試行スナップショット保存 | L0①②・L1・L2 の**各層の採点が完了した直後に、pass/fail を問わず無条件で**、現時点の成果物一式を `/tmp/cc-sier-keep-best/{task_id}/attempts/{layer}-{n}/` にコピー保存する。fail 時の自動修正だけでなく、**pass 判定後に秘書が任意の追加修正を行うケース**（1.1 節「問題1」の `20260418-125530` 事例：初回 L2 composite 0.96 で pass だったが test5 残骸・EventBridge Rule 欠落の指摘で追加修正し 1.00 に到達）でも、修正前の版が必ずスナップショットとして残るようにする | 必須 |
| FR-02 | 試行採点記録 | 各試行の `scores`（軸別）・`composite`・`verdict`・`critical_triggered` を試行番号付きで記録する（4.1 節スキーマ） | 必須 |
| FR-03 | 最良版判定（keep-best 本体） | `critical_triggered == false` の試行の中から `composite` 最大の版を採用する。**致命軸 fail の版は composite がどれだけ高くても採用禁止**（現行の「必須セクション欠落は数値均し込み禁止」原則の踏襲、@.claude/rules/review-pattern.md 判定ルール節）。**注記**: L0/L1 は現行通りリトライ上限 1 回のため最大 2 版（初回＋修正 1 回）から選択する。L2 は FR-15 によりリトライ上限を 2 回に拡張するため最大 3 版（初回＋修正 2 回）から選択する | 必須 |
| FR-04 | 同点タイブレーク | `composite` が同点の場合、**試行番号が小さい方（＝変更量が少ない方）を採用**する。理由: CLAUDE.md の「リファクタのスコープ遵守（依頼外の改善・過剰な抽象化は禁止）」原則と整合させ、不要な追加変更を評価上も優遇しない | 必須 |
| FR-05 | 全試行 fail 時の扱い | 全試行が `critical_triggered == true`、または `composite < 0.85` の場合は現行通り **fail 確定・中断**とする。ただしユーザー報告には全試行の findings を集約して提示する（現行は最終試行の findings のみ） | 必須 |
| FR-06 | 品質劣化検知アラート | 採用版（最終的に採用された試行）の `composite` が **初回試行の `composite` を下回った場合**、`quality_regression_detected: true` を task-log に記録し、完了報告に明記する。pass/fail に関わらず判定する（1.1 節「問題1」の `20260418` 事例のように、pass 後の任意修正でも対象とする） | 高 |
| FR-07 | 採用版の確定・不採用版の破棄 | 採用試行のスナップショットを成果物ディレクトリへ確定コピーし、PR 作成完了後（Phase 7 相当完了時）に `/tmp/cc-sier-keep-best/{task_id}/` を丸ごと削除する | 必須 |

### 2.2 Review Definition 固定・バージョニング系（問題2対応）

| ID | 機能名 | 内容 | 優先度 |
|----|--------|------|--------|
| FR-08 | プロンプトバージョンフィールド追加 | 各 Skill の `references/review-prompt.md` 冒頭に YAML フロントマター（`version: "{YYYY-MM-DD}-{連番}"`）を追加する。**現行の「本ファイルのバージョン履歴を持たない」運用メモ（company-daily-digest 版 L111）を撤回**し、プロンプト内容を変更するたびに手動でインクリメントすることを Skill 開発ルールの必須手順とする | 必須 |
| FR-09 | 試行ごとのプロンプトバージョン記録 | L2 起動（Agent 呼び出し）の都度、その時点の `references/review-prompt.md` の `version` フィールドおよび内容の SHA256 ハッシュ（先頭 8 桁）を試行データに記録する | 必須 |
| FR-10 | 試行間ドリフト検知 | 同一タスク内で L2 リトライが発生し、attempt 間でハッシュが変化していた場合（人手レビュー待ちで PR が長期滞留し、その間に main 側の review-prompt.md が更新されたケースを想定）、`review_definition_drift: true` を記録し、完了報告で明示的に警告する。自動対応はせず、運用者判断に委ねる | 高 |
| FR-11 | Case Bank 集計のバージョン区分（データ基盤のみ） | `l2_composite` の時系列集計・しきい値調整判断（company-daily-digest review-prompt.md L106-111 の運用メモ）を行う際、`prompt_version` でグルーピングできるようにデータを整備する。集計ロジック自体の実装は本 v0.1 のスコープ外とし、task-log に必要フィールドを揃えるところまでとする | 中 |

### 2.3 承認キュー健全性モニタリング系（問題3対応）

| ID | 機能名 | 内容 | 優先度 |
|----|--------|------|--------|
| FR-12 | PR発行ペースの可視化 | 既存の `/company-report` またはダッシュボード集計に、月次 PR 発行件数を追加表示する。集計分母は **Skill 経由の PR（約 15.6 件/月）とリポジトリ全体の PR（約 39 件/月）を分けて表示**し、承認キュー負荷は後者で評価する（1.1 節参照） | 中 |
| FR-13 | 閾値監視ロジック（設計のみ、実装見送り） | リポジトリ全体の月間 PR 件数が **150 件/月**（参考記事のパンク水準 300 件/月の半分。実測 39 件/月に対して約 3.8 倍の余裕がある）を超えた場合に警告する設計を定義するが、**現状規模では実装を見送り、監視ロジックの仕様のみ本書に残す** | 低 |
| FR-14 | 人手レビュー滞留の例外エスカレーション（将来用） | `/company-diagram-v2` のように auto-merge しない Skill の PR が、一定件数（暫定 20 件）または一定日数（暫定 7 日）滞留した場合に警告する設計を定義する。実装判断は 8 章「今後の進め方」で再評価する | 低 |

### 2.4 リトライ上限系（問題1関連・L0/L1/L2 全層共通の方針）

| ID | 機能名 | 内容 | 優先度 |
|----|--------|------|--------|
| FR-15 | L2 リトライ上限の拡張 | **L2（独立LLMレビュー）のみ**リトライ上限を現行 1 回から **2 回（初回＋修正2回＝最大3試行）** に拡張する。**L0/L1 は現行通り 1 回のまま維持**する。判断根拠: (a) L0/L1 は機械的・構造的チェックであり、実際の task-log（`20260421-080642-daily-digest-actions.md` の `l1_retries:1`、`20260502-212427-drawio-cc-sier-webapp-architecture.md` の `l0_retries:1`）でも 1 回の修正で収束しており、2 回以上を要する場合は Skill 定義側の設計不備の可能性が高くリトライで粘るより人手介入に倒すべき (b) L2 は内容評価であり、致命軸に触れない範囲の指摘（文言・要約の質等）は 1 回の修正で潰しきれず fail が続くケースが構造的に起こりうる。keep-best（FR-03）導入により「試行を増やしても最悪版が採用される心配がない」ため、L2 のみ試行回数を増やす価値が相対的に高い (c) 現状の承認キュー実測（リポジトリ全体で約 39 件/月、1.1 節）にはコスト面の余裕があり、コスト増は 3 章 NFR-08 で許容範囲と判断した | 必須 |

---

## 3. 非機能要件

| ID | 分類 | 要件 | 目標値 |
|----|------|------|--------|
| NFR-01 | 性能 | スナップショットコピーによる Phase 実行時間への影響 | 既存フローに対し体感できる遅延を追加しない（成果物は数ファイル〜十数ファイル程度の小規模のため cp コマンドで十分） |
| NFR-02 | ストレージ | スナップショット領域 | リポジトリ外（`/tmp` 配下）に配置し Git 管理対象にしない。PR 作成完了後に必ず削除する |
| NFR-03 | 後方互換性 | 既存 task-log（`attempts` フィールドを持たない）の扱い | パーサは `attempts` 未定義時、既存の `l0_retries`/`l1_gate` 等の単一フィールドのみで解釈できること。旧形式の task-log を壊さない（4.2 節） |
| NFR-04 | 監査性 | 試行履歴の追跡可能性 | 採用されなかった試行のスコア・findings は task-log 本文に要約として残し、後から「なぜその版を採用したか」を追跡できること |
| NFR-05 | 保守性 | 既存フェーズ番号への影響 | 9 フェーズ / 8 フェーズの既存フェーズ番号・名称は変更しない。keep-best は各層（L0/L1/L2）のリトライ処理内のサブステップとして追加する |
| NFR-06 | 一貫性 | Skill 間の実装差異 | `company-daily-digest`（L1/L2 の 2 層構成）・`company-diagram-v2`（L0①②/L1/L2 の 4 段構成）など層数が異なる Skill でも、同一の attempts スキーマ（4.1 節）で表現できること |
| NFR-07 | 運用コスト | プロンプトバージョン手動管理の負荷 | フロントマター 1 行の追記のみで済む設計とし、Skill リライト時の取りこぼし防止プロセス（@.claude/rules/skill-development.md）の Step 3 に統合し追加の運用負荷を最小化する |
| NFR-08 | コスト | L2 リトライ上限拡張（FR-15）の追加コスト | 1 タスクあたりの L2 fresh general-purpose Agent 起動回数の上限が 2 回→3 回に増加（最大 +50%）。リポジトリ全体の実測 PR ペース（約 39 件/月、1.1 節）に照らし総コスト増は許容範囲と見積もる。ただし L2 で 2 回目のリトライ（3 試行目）が実際に発生する頻度は現時点で未観測のため、実効コスト増分はパイロット運用後（8 章）に実測して再評価する |

---

## 4. データ定義

### 4.1 試行履歴スキーマ（task-log 本文への追加セクション）

task-log の YAML フロントマターとは別に、本文に `## 試行履歴` セクションを追加し、YAML ブロックで記録する（現行の `## judge` セクションと同様の形式）。

```markdown
## 試行履歴

attempts:
  - layer: l2                       # l0-1 / l0-2 / l1 / l2 のいずれか
    attempt_no: 1
    scores:
      s1_structure: 0.95
      s2_links: 1.00
      s3_summary: 0.95
      s4_cross_domain: 0.95
      s5_dedup: 0.90
      s6_violations: 0.65
    composite: 0.73
    verdict: fail
    critical_triggered: false
    prompt_version: "2026-07-01-03"
    prompt_hash: "a1b2c3d4"
    snapshot_ref: "/tmp/cc-sier-keep-best/20260419-080048-daily-digest-actions/attempts/l2-1/"
    timestamp: "2026-04-19T08:13:30+09:00"
  - layer: l2
    attempt_no: 2
    scores:
      s1_structure: 0.95
      s2_links: 1.00
      s3_summary: 0.95
      s4_cross_domain: 0.95
      s5_dedup: 0.90
      s6_violations: 0.95
    composite: 0.95
    verdict: pass
    critical_triggered: false
    prompt_version: "2026-07-01-03"
    prompt_hash: "a1b2c3d4"
    snapshot_ref: "/tmp/cc-sier-keep-best/20260419-080048-daily-digest-actions/attempts/l2-2/"
    timestamp: "2026-04-19T08:16:00+09:00"

adopted_attempt: 2                  # 採用された attempt_no
quality_regression_detected: false  # 採用版 composite < 初回 composite の場合 true
review_definition_drift: false      # attempt 間で prompt_hash が変化した場合 true
```

### 4.2 task-log フロントマター拡張フィールド一覧

既存フィールド（`.claude/rules/task-log.md`）に以下を追加する。**全て任意フィールド**とし、未定義時は「試行 1 回のみ・keep-best 判定なし」の旧来動作と解釈する。

| フィールド | 型 | 必須/任意 | デフォルト解釈（未定義時） | 説明 |
|---|---|---|---|---|
| `keep_best_enabled` | boolean | 任意 | `false` | この task で keep-best 判定を実施したか |
| `adopted_attempt` | int | 任意 | `null`（＝最終試行をそのまま採用、旧来動作） | 採用された試行番号 |
| `quality_regression_detected` | boolean | 任意 | `false` | 採用版が初回試行より composite が低いか |
| `review_definition_drift` | boolean | 任意 | `false` | 試行間で review-prompt.md のハッシュが変化したか |
| `l2_prompt_version` | string | 任意 | `null` | 最終採用試行で使用した review-prompt.md の version 値 |

既存の `l0_gate` / `l0_retries` / `l1_gate` / `l1_retries` / `l2_composite` / `l2_retries` / `l2_scores` は**そのまま維持**し、`adopted_attempt` が指す試行のスコアをそこに転記する（後方互換性維持のため、既存フィールドの意味を変えない）。

### 4.3 スナップショット保持構造

```
/tmp/cc-sier-keep-best/{task_id}/
└── attempts/
    ├── l0-1/                    # L0 初回採点直後の成果物一式（pass/fail問わず無条件保存、FR-01）
    ├── l0-2/                    # L0 修正後（リトライ発生時のみ生成）
    ├── l1-1/
    ├── l1-2/
    ├── l2-1/
    ├── l2-2/
    └── l2-3/                    # FR-15 によりL2のみ最大3試行まで生成されうる
        ├── {filename}.drawio (or .md 等、Skill 依存)
        ├── {filename}.html
        ├── ...
        └── score.json           # scores / composite / verdict / critical_triggered / prompt_hash
```

- ディレクトリはリポジトリ外（NFR-02）
- Phase 7（PR作成・auto-merge 判定）完了後、成功・中断を問わず削除する
- 中断（全試行 fail）の場合も削除する。診断が必要な場合は task-log の `## 試行履歴` セクションの findings 要約で代替する（生成物そのものの保全はスコープ外）

### 4.4 review-prompt.md のバージョンフィールド定義

各 Skill の `references/review-prompt.md` 冒頭に以下を追加する。

```yaml
---
version: "2026-07-26-01"    # {YYYY-MM-DD}-{当日の連番}。内容変更時に手動インクリメント必須
---
```

`.claude/rules/skill-development.md` の「SKILL.md リライト時の取りこぼし防止プロセス Step 3」（review-prompt.md の同時更新）に、この version 更新を追加タスクとして統合する。

---

## 5. 処理フロー定義

### 5.1 現行フロー（as-is）

```
生成 ──▶ L2レビュー ──fail──▶ 秘書が修正（上書き）──▶ 再レビュー ──pass──▶ Phase7へ
                │                                              │
               pass                                           fail
                │                                              │
                ▼                                              ▼
            Phase7へ                                    中断・報告
```

修正前バージョンは上書きにより消失。修正前後のスコアを比較する手段がない（1.1 節 問題1 の task-log 事例が示す通り）。

### 5.2 改修後フロー（to-be、keep-best 導入）

```
生成 ──▶ L2レビュー(attempt-1) ──採点完了・pass/fail問わず無条件──▶ attempt-1 スナップショット保存（FR-01）
                                                   │
                        ┌──────────────────────────┴───────────────────┐
                       pass                                           fail
                        │                                              │
                        ▼                                              ▼
              追加修正の要否を判断                            秘書が修正（コピー先で編集）
              （不要ならそのまま採用候補）                              │
                        │                                    L2レビュー(attempt-2)
              (修正する場合のみ)                                        │
                        ▼                              採点完了・無条件で
              秘書が追加修正                            attempt-2 スナップショット保存（FR-01）
                        │                                              │
              L2レビュー(attempt-2)                                    │
                        │                                              │
              採点完了・無条件で                                         │
              attempt-2 スナップショット保存（FR-01）                     │
                        │                                              │
                        └──────────────┬───────────────────────────────┘
                                        ▼
                         keep-best 判定:
                         critical_triggered=false の attempts から
                         composite 最大を採用（FR-03/FR-04）
                         ※ L2 は FR-15 により最大 attempt-3 まで同様のループを継続しうる
                                        │
                          ┌─────────────┴─────────────┐
                    採用版 pass                  全 attempts fail
                          │                              │
                          ▼                              ▼
              採用版を確定コピー                    中断・全 findings 集約報告
              quality_regression_detected判定
              attempts/ 削除（NFR-02）
                          │
                          ▼
                       Phase7へ
```

### 5.3 承認キューモニタリングフロー（将来用、FR-13/FR-14）

```
月次集計（/company-report 等） ──▶ リポジトリ全体のPR発行件数を算出
                                        │
                              150件/月超？（FR-13、現状未実装）
                                        │
                                       no ──▶ 現状維持（現在ここ: 約39件/月）
                                        │
                                       yes ─▶ 承認自動化の実装検討をタスク化
```

---

## 6. 影響範囲

### 6.1 改修対象 Skill 一覧

| Skill | 現行リトライ層 | 影響箇所 |
|---|---|---|
| `company-daily-digest` | L1（構造）/ L2（内容）の 2 層 | SKILL.md Phase 4・Phase 5、references/review-prompt.md（version追加、L106-111運用メモ改訂） |
| `company-diagram` | L0（IaC・英語ラベル）/ L1 / L2 | SKILL.md（フェーズ番号は要 grep 確認）、references/review-prompt.md |
| `company-diagram-v2` | L0①(validate_drawio.py)+L0②(review-drawio.js) / L1 / L2 | SKILL.md Phase 4〜6（本書調査で実際に参照した箇所）、references/review-prompt.md |
| `company-drawio` | L0(review-drawio.js) / L1 / L2 | SKILL.md、references/review-prompt.md |
| `company-sheet` | L0（Phase5 機械レビュー）/ L1（Phase6 セルフ構造ゲート）/ L2（Phase7 独立レビュー）の 3 層 | SKILL.md Phase 5〜7（L153/L179/L193）、references/review-prompt.md |

### 6.2 共通ルールファイルの改修範囲

| ファイル | 変更内容 |
|---|---|
| `.claude/rules/review-pattern.md` | 「リトライポリシー」節に keep-best 判定ルール（FR-03/FR-04）を追加。「task-log への記録」節に `attempts`/`adopted_attempt`/`quality_regression_detected`/`review_definition_drift` を追記 |
| `.claude/rules/task-log.md` | YAML フロントマター例に 4.2 節の拡張フィールドを追加（既存フィールドはそのまま維持） |
| `.claude/rules/skill-development.md` | 「SKILL.md リライト時の取りこぼし防止プロセス Step 3」に review-prompt.md の `version` フィールド更新を追加 |

### 6.3 各 SKILL.md への変更（Phase 単位、具体箇所）

- `company-diagram-v2/SKILL.md`
  - Phase 4（L0 機械レビュー、L180-217）: `V_EXIT`/`R_EXIT` fail 時に attempt-1 スナップショット保存処理を追加
  - Phase 5（L1 セルフ構造ゲート、L221-234）: fail → 修正前に attempt スナップショット保存
  - Phase 6（L2 独立レビュー、L238-274）: Agent 起動プロンプトに `prompt_version`/`prompt_hash` 埋め込みを追加。判定ルール（L271-273）に keep-best 選定処理を追加
  - Phase 8（task-log、L293〜）: YAML フロントマターに 4.2 節フィールドを追加
- `company-daily-digest/SKILL.md`
  - Phase 4（L1、L101-113）・Phase 5（L2、L116-149）: 同様にスナップショット・keep-best 判定を追加
  - `references/review-prompt.md`: L106-111 の運用メモを「バージョン履歴を本ファイルで管理する」方針に改訂
- `company-diagram/SKILL.md`・`company-drawio/SKILL.md`: 上記 2 Skill と同様のパターンで Phase 番号を確認の上、同じ変更を適用

### 6.4 plugins ↔ .claude 同期手順

`plugins/cc-sier/skills/` が VCS 真ソース（@.claude/rules/skill-development.md）のため、以下の順で同期する。

```bash
# 各対象 Skill について
cp plugins/cc-sier/skills/{name}/SKILL.md .claude/skills/{name}/SKILL.md
cp plugins/cc-sier/skills/{name}/references/review-prompt.md .claude/skills/{name}/references/review-prompt.md
diff -rq plugins/cc-sier/skills/{name}/ .claude/skills/{name}/
```

---

## 7. 前提・制約・リスク

| # | 種別 | 内容 | 対応方針 |
|---|------|------|---------|
| 1 | 前提 | スナップショット領域はリポジトリ外（`/tmp`）に置く前提で設計している | プロセスクラッシュ時に attempt データが失われうるが、diagram/digest 等の 1 タスクは数分〜数十分規模のため許容リスクとする |
| 2 | 未決事項 | git stash / git commit（WIP）方式との比較を要件化の過程で検討したが、複数試行の同時保持と実装単純性の観点で一時ディレクトリコピー方式を採用した。チームリードの承認が必要 | 8 章のレビューで確定させる |
| 3 | 未決事項 | 承認キュー閾値（FR-13 の 150 件/月、FR-14 の 20 件/7日）は実測値からの暫定推定であり、経験則的根拠はない | パイロット運用後、実測に基づき再設定する |
| 4 | リスク | `review-prompt.md` の version 手動管理を徹底できないと、FR-08〜FR-11 のデータ基盤が形骸化する | Step 3（skill-development.md）への統合と、L2 起動時のハッシュ突合による機械的検知（FR-10）で運用漏れを補完する |
| 5 | リスク | 既存 task-log（190 件、@.companies/domain-tech-collection/.task-log/）は `attempts` フィールドを持たない。過去データとの混在集計で誤解を招く可能性 | NFR-03 の後方互換性設計に加え、集計時は `keep_best_enabled: true` の task-log のみを対象にする運用ルールを別途整備する |
| 6 | 制約 | `company-diagram-v2` は現行 v2 方針で auto-merge しない（人手レビュー必須）ため、FR-14 の滞留監視は他 Skill と異なる基準になりうる | 本書では設計のみとし、実装時に Skill 別の基準を再検討する |
| 7 | リスク | 致命軸 fail の版しか存在しない場合、keep-best 判定でも pass 版は生成されない（FR-05）。これは既存動作からの後退ではないが、ユーザー体感としては「何も変わらない」ため、findings 集約表示（FR-05）の価値をどう伝えるかは UX 上の検討課題 | 完了報告テンプレートに「全試行の指摘事項」セクションを追加する形で対応（本書スコープ内） |

---

## 8. 今後の進め方（参考）

1. 本要件のレビュー・フィックス（v0.2 で attempts スキーマの Skill 別差異吸収方法・スナップショット方式の最終決定を反映）
2. `company-daily-digest`（2 層構成で最もシンプル）を先行パイロットとして keep-best を実装
3. パイロット結果（quality_regression_detected の発生有無、運用負荷）を評価した上で `company-diagram` / `company-diagram-v2` / `company-drawio` / `company-sheet` へ展開
4. `references/review-prompt.md` の version フィールド追加を全 Skill に適用し、`.claude/rules/skill-development.md` の恒久ルールとして明文化
5. 3 ヶ月後を目安に PR 発行ペースを再実測し、FR-13/FR-14 の承認キュー自動化の要否を再判断
