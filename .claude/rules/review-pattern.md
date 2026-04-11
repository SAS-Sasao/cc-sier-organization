# 3層レビュー + auto-merge パターン

`/company-daily-digest`, `/company-diagram`, `/company-drawio` で採用する共通レビュー設計。PR 自動マージまでを統合実行する Skill は全てこのパターンに従う。

## 3層レビューの全体像

| 層 | 評価者 | 目的 | 実装 |
|---|---|---|---|
| **L0 機械レビュー** | シェル/Node スクリプト | 決定論的・定量チェック | grep / ls / 外部スクリプト（例: `review-drawio.js`） |
| **L1 セルフ構造ゲート** | 秘書（author） | 構造・フォーマット・必須項目存在 | `masters/quality-gates/` の必須項目を自己チェック |
| **L2 独立 LLM レビュー** | **fresh `general-purpose` agent** | 内容品質・整合性 | `references/review-prompt.md` で 6軸採点、JSON 出力 |

## なぜ fresh general-purpose agent か

- `lead-developer` 等の専門エージェントはコード/技術方針向きで文面評価の fit が弱い
- 執筆者（秘書）自身に評価させると authoring bias が発生
- fresh な general-purpose は WebFetch/Read 等全ツールを持ち、画像 Read も可能
- 独立コンテキストで採点の一貫性と客観性を担保

## L2 採点 6軸構成

Skill ごとに軸の中身は変わるが、**共通で必ず 6軸 + composite + 致命軸**で設計する:

```json
{
  "s1_structure": 0.00,        // 構造準拠（致命軸★が多い）
  "s2_*": 0.00,                // Skill 固有（致命軸）
  "s3_*": 0.00,                // Skill 固有
  "s4_*": 0.00,
  "s5_*": 0.00,
  "s6_*": 0.00,                // 禁則違反系（致命軸）
  "composite": 0.00,
  "verdict": "pass|fail",
  "critical_triggered": false,
  "findings": [],
  "fix_suggestions": []
}
```

## 判定ルール（統一）

- **致命軸** のいずれかが `< 0.5` → composite 強制 0.00, verdict = fail, critical_triggered = true
- **必須セクション欠落** → composite 強制 0.00, verdict = fail, critical_triggered = true（数値均し込みで通過させない）
- それ以外: composite = 等重み平均、`≥ 0.85` で pass

## リトライポリシー

- 各層 **1 回まで** 自動修正リトライ
- L1 fail → 秘書が自動修正 → 再チェック → それでも fail なら中断
- L2 fail → reviewer の findings/fix_suggestions を秘書にフィードバック → 1 回修正 → 再採点 → fail なら **auto-merge 中止**

## Skill 別の致命軸設計

| Skill | 致命軸 | 備考 |
|---|---|---|
| `/company-daily-digest` | s2 リンク完全性 / s6 禁則違反 | L2 2層（L0 なし） |
| `/company-diagram` | s1 構造準拠 / s2 IaC生成 / s6 英語ラベル | L0: IaC存在+英語ラベル、L1: HTML 7セクション |
| `/company-drawio` | s2 エッジ貫通 / s6 HTML埋め込み禁則 | L0: `review-drawio.js` 実行 |

## 9フェーズ統合実行フロー（diagram/drawio 型）

```
Phase 0  ヒアリング（--yes でスキップ可）
Phase 1  前処理（branch / task-log 初期化）
Phase 2  MCP 生成
Phase 3  ファイル配置（必須全ファイル）
Phase 4  L0 機械レビュー
Phase 5  L1 セルフ構造ゲート
Phase 6  L2 独立 LLM レビュー
Phase 7  PR 作成 & 自動マージ（gh pr merge --auto --squash --delete-branch）
Phase 8  task-log 完了更新 + Issue 作成 + 報告
```

`/company-daily-digest` は Phase 0 なし（Q&A 不要、固定入力）、Phase 7 の後に main 直コミットの HTML 再生成工程が追加される 8 フェーズ構成。

## 必須セクション欠落の検出設計

**1 セクション欠落で composite 0.5 減点程度の均し込みでは検出漏れが発生する**（6軸平均で (0.3+5)/6 = 0.88 となり 0.85 を超えてしまう）。対策:

1. L1 で機械的に grep → 1 つでも欠落で retry
2. L2 review-prompt.md に **「必須セクションのうち 1 つでも欠落している場合、他のスコアに関わらず critical_triggered = true かつ verdict = fail を強制」** を明記
3. s1（構造準拠）を致命軸に昇格

過去の教訓: 2026-04-11 /company-diagram 初回実運用で コスト概算 と 学習ポイント の欠落が L2 通過し、PR #251 → #253 → #254 の 3 段階ですり抜け修正が発生（`feedback_skill_rewrite_regression.md`）。

## task-log への記録

L0/L1/L2 の結果は task-log の YAML フロントマターに必ず記録:

```yaml
l0_gate: pass
l0_retries: 0
l1_gate: pass
l1_retries: 0
l2_composite: 0.98
l2_retries: 0
l2_scores:
  s1_structure: 1.00
  s2_iac: 1.00
  ...
```

## 関連

- @.claude/rules/skill-development.md — SKILL.md リライト時の取りこぼし防止
- @.claude/rules/task-log.md — task-log 形式
- @.claude/rules/git-workflow.md — PR + auto-merge
