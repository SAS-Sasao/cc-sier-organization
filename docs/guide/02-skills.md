# 02 Skills リファレンス

---

## /company

組織を選択・切り替えます。

```
/company {org-slug}
/company              ← 一覧表示
```

**動作:** `.companies/{org-slug}/` を確認 → `.companies/.active` を更新 → `CLAUDE.md` と `masters/` を読み込み

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

## Tips

**Skill とSubagent の使い分け:**
```
/company-report week    ← 決まったフロー → Skill
B社の新システムを設計して  ← 創造的判断 → 秘書 → Subagent
```

**masters/ を充実させると精度が上がる:**
特に `masters/customers/{slug}.md` の技術スタック・制約欄が重要です。
