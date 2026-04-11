# WBS markdown 拡張スキーマ

各組織の WBS markdown に必要メタ情報を統合するための拡張スキーマ定義。`daily-todo-sync.yml` および `parse-wbs.py` がこのスキーマに従ってタスクを解釈する。

## 1. 背景

既存 WBS markdown は組織ごとに列数が異なる:

| 組織 | ファイル | 列数 | 既存カラム |
|---|---|---|---|
| domain-tech-collection | `docs/secretary/storcon-preparation-wbs.md` | 8 | WBS / タスク / 担当 / 期間 / 時間 / リソース / 成果物 / ステータス |
| standardization-initiative | `docs/pm/projects/standardization-project-wbs.md` | 4 | WBS# / 作業項目 / 成果物 / 期間 |

Projects v2 への同期 + Top N 選定に必要な情報（iteration, priority, type, issue#）が不足しているため、以下のルールで末尾カラムを追加する。

## 2. 拡張カラム定義

**既存の最終カラム（ステータス列）の直前**に以下 4 カラムを挿入する（ステータスは末尾のまま維持）:

| # | カラム名 | 型 | 値の例 | 説明 |
|---|---|---|---|---|
| +1 | `Iter` | string | `W1` / `W2-3` / `W1-10` | Iteration（週）。期間列から推測可能なら自動。連続週は `W2-4`、永続は `W1-10` |
| +2 | `Pri` | int | `1` / `2` / `3` / `4` | 優先度。1=最優先 / 2=高 / 3=中 / 4=低 |
| +3 | `Type` | enum | `learning` / `diagram` / `research` / `delivery` / `operational` | タスク種別 |
| +4 | `Issue` | string | `—` / `#123` | 紐付く GitHub Issue 番号。bootstrap 時に自動埋め |

**ステータス列（`[ ]` / `[~]` / `[x]`）は必ず最終カラムに維持**すること。sync-board.sh の parser が `trimmed[last_idx]` でステータスを取得するため。

## 3. 拡張前後の例

### 3.1 domain-tech-collection (storcon-preparation-wbs.md)

**Before** (8 cols):
```markdown
| WBS | タスク | 担当 | 期間 | 時間 | リソース | 成果物 | ステータス |
|-----|-------|------|------|------|---------|--------|----------|
| 3.1.1 | AWS基礎（IAM, VPC, EC2, S3） | 自学 | W1 | 8h | AWS Skill Builder | ハンズオンメモ | [ ] |
```

**After** (12 cols):
```markdown
| WBS | タスク | 担当 | 期間 | 時間 | リソース | 成果物 | Iter | Pri | Type | Issue | ステータス |
|-----|-------|------|------|------|---------|--------|------|-----|------|-------|----------|
| 3.1.1 | AWS基礎（IAM, VPC, EC2, S3） | 自学 | W1 | 8h | AWS Skill Builder | ハンズオンメモ | W1 | 1 | learning | — | [ ] |
```

### 3.2 standardization-initiative (standardization-project-wbs.md)

**Before** (4 cols, ステータス列なし):
```markdown
| WBS# | 作業項目 | 成果物 | 期間 |
|------|---------|--------|------|
| 1.0.1 | 過去実績データの収集・整理 | 実績データベース（Excel） | Week 1-2 |
```

**After** (9 cols, ステータス列新設):
```markdown
| WBS# | 作業項目 | 成果物 | 期間 | Iter | Pri | Type | Issue | ステータス |
|------|---------|--------|------|------|-----|------|-------|----------|
| 1.0.1 | 過去実績データの収集・整理 | 実績データベース（Excel） | Week 1-2 | W1-2 | 1 | delivery | — | [ ] |
```

## 4. Iter の記法規則

| 記法 | 意味 | 例 |
|---|---|---|
| `W1` | 単一週 | W1 のみ |
| `W2-4` | 連続週（範囲） | W2, W3, W4 |
| `W1-10` | 永続／全期間 | 毎週継続のタスク |
| `W5,W9` | 飛び飛び（カンマ区切り） | 月次タスク等 |
| `—` | 未定義／該当なし | 期間未定 |

Iteration は Projects v2 の `Iteration` field (週単位 sprint) にマップされる。範囲 `W2-4` は最初の週 (W2) に置かれ、`sub-iteration` として扱う（Projects v2 の制約）。

## 5. Pri の記法規則

| 値 | 意味 | 用途 |
|---|---|---|
| `1` | 最優先 | マイルストーン判定タスク、Phase 1 必須項目、delivery 系 |
| `2` | 高 | 順当な学習タスク、Phase 2 系 |
| `3` | 中 | サブリサーチ、補助タスク |
| `4` | 低 | nice-to-have、余裕があれば |

既存 WBS で明示的な優先度がない場合は **phase 番号**を参考に自動判定:
- Phase 1（基礎） → Pri 1
- Phase 2（案件直結） → Pri 2
- Phase 3（統合） → Pri 2
- Phase 4（仕上げ） → Pri 3
- セクション 5（リサーチ）→ Pri 3
- セクション 6（資格）→ 最重要資格のみ Pri 1、他は Pri 3

## 6. Type の記法規則

| 値 | 意味 | 例 |
|---|---|---|
| `learning` | 自学・インプット系 | AWS 基礎、PMBOK 読書 |
| `diagram` | 図解・可視化生成 | /company-diagram, /company-drawio 実行タスク |
| `research` | Web 調査・リサーチ | 技術動向調査、市場調査 |
| `delivery` | 成果物納品・実装 | テンプレ作成、実装、資料作成 |
| `operational` | 運用・継続タスク | 日次ダイジェスト、振り返り |

WBS 番号から自動推測:
- `3.x.x` (AWS) → learning
- `4.x.x` (PM) → learning
- `5.x` (リサーチ系) → research
- `6.x` (資格) → learning
- 「図解」「diagram」「drawio」を含むタスク → diagram
- 「作成」「納品」を含むタスク → delivery
- 日次・週次継続タスク → operational

## 7. ヘッダー行の検出（parser 側）

parse-wbs.py は以下のルールでヘッダー行を検出:

1. 行頭が `|` で始まる
2. セパレータ行（`|---|---|` 形式）の直前
3. セル内に以下のいずれかのキーワードを含む:
   - `WBS`, `WBS#`, `タスク`, `作業項目`, `Status`, `ステータス`
4. ヘッダー行が見つかったらマッピング辞書を作成:
   ```python
   {"WBS": 0, "タスク": 1, "ステータス": 11, "Iter": 7, ...}
   ```
5. データ行は WBS ID パターン (`^\d+(\.\d+)*(\.R?\d+)?$`) で判定

既存列名のゆらぎを吸収（`タスク` / `作業項目` / `Task` は同義）。

## 8. 移行スクリプト

既存 WBS ファイルの拡張カラム追加は `.claude/hooks/migrate-wbs-schema.py` により一括実行可能:

```bash
python3 .claude/hooks/migrate-wbs-schema.py \
  .companies/domain-tech-collection/docs/secretary/storcon-preparation-wbs.md
```

スクリプトは:
1. ヘッダー行を検出して既存カラム構造を解析
2. 各タスク行から Iter/Pri/Type を自動推測
3. 末尾にカラムを追加してファイル上書き
4. 冪等（既に拡張済みなら何もしない）

## 9. 関連

- @.claude/rules/todo-management.md — TODO 管理の全体ルール
- @.claude/hooks/parse-wbs.py — 実装
- @.claude/hooks/migrate-wbs-schema.py — 一括移行ツール
- @.claude/hooks/sync-board.sh — board.md 生成（pattern E 対応拡張あり）
