---
task_id: "20260802-spawn-retail-stats-tracker"
org: "domain-tech-collection"
operator: "SAS-Sasao"
status: completed
mode: "subagent"
started: "2026-08-02T10:00:00"
completed: "2026-08-02T10:30:00"
request: "これまで固めてきた、要件定義・設計書を切り出して別リポジトリで対応できるようにしてほしい。"
issue_number: null
pr_number: null
subagents: [devops-coordinator]
l0_gate: null
l0_retries: 0
l1_gate: null
l1_retries: 0
l2_composite: null
l2_retries: 0
---

## 実行計画

- **実行モード**: subagent（devops-coordinator に委譲）
- **参照したマスタ**: projects.md
- **判断理由**: `/company-spawn` の標準フロー。リポジトリ作成・スキャフォールド生成は devops-coordinator の専門領域

## ヒアリング結果

6 問のうち、判断が要る 2 問のみユーザーに確認し、残りは設計書から確定させた。

| 項目 | 値 | 確定方法 |
|---|---|---|
| リポジトリ名 | `retail-stats-tracker` | 設計書の対象システム名をそのまま採用 |
| 説明 | 日次ダイジェストの決算・統計章を時系列データ化する小売月次統計トラッカー | 要件定義 §1.2 から |
| 技術スタック | Python（標準ライブラリのみ / unittest） | 実装設計 §7.1・補足 A で確定済み |
| コピーする成果物 | 設計 5 文書 | 依頼の対象そのもの |
| **公開設定** | **private** | **ユーザー確認**（設計書に提案材料としての見方が含まれるため） |
| **Subagent** | 既存 4 + **新規 2 も作成** | **ユーザー確認**（maker-checker 分離を初日から機能させる判断） |

## 実行結果

**リポジトリ**: https://github.com/SAS-Sasao/retail-stats-tracker （private）
**コミット**: `c2709a4`（47 ファイル / 8,364 行）

### 生成された構成

| 領域 | 内容 |
|---|---|
| `docs/design/` | 設計 5 文書 + `origin.md`（トレーサビリティ） |
| `scripts/retail-stats-tracker/retail_stats/` | 実装設計 §2 準拠の 14 モジュール。docstring 付き `NotImplementedError` スタブ、`py_compile` 済み |
| `scripts/retail-stats-tracker/tests/` | unittest 7 ファイル。§7.2 の T-1〜T-10 相当 44 ケースを skip 付きで配置（discover 実行済み・エラーなし） |
| `.claude/agents/` | 既存 4 本（パスを `.companies/{org}/docs/` → `docs/` に書き換え）+ 新規 2 本 |
| ルート | `CLAUDE.md` / `README.md` / `.gitignore` |

### ファイル名変更と相互参照

5 文書はリネームして配置したため、文書間の相互参照 **18 箇所**を機械的に置換した。

| 元 | 新 |
|---|---|
| `retail-stats-tracker-requirements.md` | `requirements.md` |
| `retail-stats-tracker-design.md` | `implementation-design.md` |
| `retail-stats-tracker-loop-engineering-design.md` | `loop-engineering-design.md` |
| `retail-stats-tracker-cicd-design.md` | `cicd-design.md` |
| `retail-monthly-kpi-catalog.md` | （変更なし） |

置換後 grep で残存 0 件を確認。`origin.md` にのみ旧ファイル名が残るが、これは**出自の対応表として意図的**。

### 秘書による検証

- リポジトリが private で作成されていること
- `__pycache__/*.pyc` が **追跡されていない**こと（`git ls-files` で 0 件。`.gitignore` が機能）
- 相互参照の残存が `origin.md` の対応表のみであること
- `origin.md` に未決事項 2 件が記載されていること

## cc-sier 側の記録更新

- `masters/projects.md` に `proj-retail-stats-tracker` を追記（既存 `proj-ai-virtual-office` と同形式）
- 設計原本は **cc-sier 側**に温存。新リポはスナップショットであり、設計変更時は cc-sier 側を更新する旨を `origin.md` と projects.md の双方に明記

## 引き継いだ未決事項

新リポの `docs/design/origin.md` に、実装着手前にオーナー判断が要る 2 件を記載した。
設計書だけを渡すとこの 2 点が「解決済み」に見えるため、独立した節として切り出している。

1. **NFR-05 未達確定** — 64/83 = 77.1%（目標 80%）。到達には (a) 左窓緩和 + (b) 定性表現の分子算入の定義確定 + (c) ランキング記事の分母除外 の**組み合わせ**が要る（単独では上限 78.6%）
2. **U10 複数主体併記** — 30 件（要対応 13 / 誤検出 17）で 2 社目が黙って捨てられる。現行の衝突検出は実データで 0 件しか発火しない

## reward
（post-merge hook が自動追記）
