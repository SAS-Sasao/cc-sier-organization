---
name: company-today
description: >
  GitHub Projects v2 #2 (TODOKANBAN) のオープン TODO から組織 → タスク → 対応方針の順で
  ユーザが選択し、選ばれた方針に従って subagent/skill に委譲する対話型ディスパッチャ Skill。
  「今日のタスク進めたい」「kanban から選んで作業」「今日何やる」「TODO 選んで対応」
  「/company-today」と言われたときに使用する。
---

# /company-today — 今日の WBS タスクを選んで対応するスキル

TODOKANBAN (Project 2) に入っているオープン TODO の中から、ユーザが「組織 → タスク → 対応方針」の
3 段階で対話的に選び、選ばれた方針に応じて適切な subagent / skill / 手動支援に委譲する。

**想定ユースケース**: 朝の TODO 決め、学習開始、壁打ち、図解作成、調査依頼の起点として使う。

---

## 1. 適用条件と前提

- `gh` CLI がローカル認証済み、かつ `project` + `read:org` + `read:discussion` scope を持つ
- `.claude/hooks/parse-wbs.py` が存在する
- Project 2 (`https://github.com/users/SAS-Sasao/projects/2`) に WBS-origin の item が入っている
  (毎朝 05:30 JST の `daily-kanban-sync.yml` が補充)

---

## 2. Phase 1: 認証確認

```bash
gh auth status 2>&1 | grep -i "Token scopes"
```

出力例: `Token scopes: 'project', 'read:org', 'repo', ...`

- `project` が無ければ `gh auth refresh -h github.com -s project,read:org,read:discussion` を提案して停止
- authenticated でなければ `gh auth login` を提案して停止

---

## 3. Phase 2: Project 2 のオープン TODO 取得

```bash
gh api graphql -f query='
query {
  user(login: "SAS-Sasao") {
    projectV2(number: 2) {
      items(first: 100) {
        nodes {
          id
          content {
            __typename
            ... on Issue {
              number url title state body
              labels(first: 30) { nodes { name } }
            }
          }
          fieldValues(first: 20) {
            nodes {
              __typename
              ... on ProjectV2ItemFieldSingleSelectValue {
                field { ... on ProjectV2FieldCommon { name } }
                name
              }
              ... on ProjectV2ItemFieldDateValue {
                field { ... on ProjectV2FieldCommon { name } }
                date
              }
            }
          }
        }
      }
    }
  }
}' > /tmp/company-today-items.json
```

---

## 4. Phase 3: Filter + 組織別グループ化

`/tmp/company-today-items.json` を Python でパース:

```python
import json
data = json.load(open('/tmp/company-today-items.json'))
items = data['data']['user']['projectV2']['items']['nodes']

def label_names(it):
    c = it.get('content') or {}
    return [l['name'] for l in (c.get('labels') or {}).get('nodes', [])]

def field_value(it, field_name):
    for fv in (it.get('fieldValues') or {}).get('nodes', []):
        if (fv.get('field') or {}).get('name') == field_name:
            return fv.get('name') or fv.get('date')
    return None

# Filter: Issue + OPEN + todo:wbs + Status != Done
filtered = []
for it in items:
    c = it.get('content') or {}
    if c.get('__typename') != 'Issue':
        continue
    if c.get('state') != 'OPEN':
        continue
    labels = label_names(it)
    if 'todo:wbs' not in labels:
        continue
    if field_value(it, 'Status') == 'Done':
        continue
    filtered.append(it)

# 組織別グループ化 (label org:<slug> から抽出)
from collections import defaultdict
by_org = defaultdict(list)
for it in filtered:
    org = next((l.removeprefix('org:') for l in label_names(it) if l.startswith('org:')), 'unknown')
    by_org[org].append(it)
```

結果を 2 つ用意:
- `by_org`: 組織名 → TODO リスト
- 全体 `filtered` の件数

### エッジケース

- `len(filtered) == 0` → 「オープン TODO がありません。`/company-kanban-sync` で補充してください」と報告して終了
- `len(by_org) == 1` → Phase 4 (組織選択) を skip し、その組織の TODO 一覧で Phase 5 に進む

---

## 5. Phase 4: 組織選択 (AskUserQuestion)

`AskUserQuestion` tool を以下のフォーマットで呼び出す:

```yaml
questions:
  - header: 組織選択
    question: "どの組織のタスクから始めますか?"
    multiSelect: false
    options:
      - label: "{org_slug_1}"
        description: "{N}件のオープン TODO (priority 上位: {WBS N.M})"
      - label: "{org_slug_2}"
        description: "{M}件のオープン TODO"
      - label: "全組織から選ぶ"
        description: "{合計}件 (priority 横断)"
```

- 最大 4 org + 1 横断 option = 5 options 以内
- label には組織 slug を **そのまま**記載
- description には件数と priority 1 の最上位 WBS ID を添える (判断材料)

ユーザの回答を `selected_org` に保存。`"全組織から選ぶ"` 選択時は `selected_org = None` とする。

---

## 6. Phase 5: タスク選択 (AskUserQuestion)

`selected_org` に属する TODO（または全件）を以下でソート:

```python
def sort_key(it):
    labels = label_names(it)
    priority = next((int(l.removeprefix('priority:')) for l in labels if l.startswith('priority:')), 9)
    wbs_id = next((l.removeprefix('wbs:') for l in labels if l.startswith('wbs:')), '9.9')
    # Iteration (W3 等) を整数化してタイブレーク
    iteration = next((l.removeprefix('iteration:') for l in labels if l.startswith('iteration:')), 'W99')
    return (priority, iteration, wbs_id)

sorted_todos = sorted(tasks_in_org, key=sort_key)
```

上位 4 件 + `"その他 (N 件)"` option で AskUserQuestion:

```yaml
questions:
  - header: タスク選択
    question: "どの WBS タスクに取り組みますか?"
    multiSelect: false
    options:
      - label: "WBS {wbs_id}: {title を 40 字まで}"
        description: "{iteration} / priority {N} / type {type} / 成果物: {artifact}"
      - ... (最大 4 タスク)
      - label: "その他 ({残り件数} 件)"
        description: "上位 4 件以外から選ぶ"
```

ユーザが `その他` を選んだ場合は、残りタスクをテキストで一覧表示した後、再度 AskUserQuestion で選択させる。

タスク決定後、**対応する Issue の URL と labels を記憶** しておく (Phase 8 で使用)。

---

## 7. Phase 6: タスク詳細取得

選ばれた WBS ID と org で `parse-wbs.py` を呼び、元 WBS markdown からタスク詳細を取得:

```bash
python3 .claude/hooks/parse-wbs.py --format=json --org="$ORG" 2>/dev/null \
  | python3 -c "
import json, sys
data = json.load(sys.stdin)
target = next((t for t in data if t['wbs_id'] == '$WBS_ID'), None)
if target:
    print(json.dumps(target, ensure_ascii=False, indent=2))
else:
    print('{}')
"
```

取得できる情報:
- `task` (タスク名)
- `section` / `subsection` (Phase/章)
- `assignee` / `period` / `iteration` / `priority` / `type`
- `artifact` (期待成果物)
- `wbs_file` (元 WBS markdown パス)

さらに元 WBS markdown から該当行前後の context (Phase 説明、到達目標) を取得:

```bash
grep -B 5 -A 1 "| $WBS_ID |" "$WBS_FILE" | head -20
```

parse-wbs.py で取得できない場合は Project 2 item の Issue body (Phase 2 で取得済み) にフォールバック。

### ユーザへの表示 (チャット本文)

```
📋 WBS {wbs_id}: {title}

- 組織: {org}
- セクション: {section} / {subsection}
- タイプ: {type}
- 優先度: priority {N}
- 期間: {period} ({iteration})
- 成果物: {artifact}
- 参考リソース: {resource}  ← 元 markdown の リソース列

🔗 GitHub Issue: {url}
```

---

## 8. Phase 7: 対応方針の選択 (AskUserQuestion)

タスクの `type` に応じて以下のルーティングで選択肢を提示:

### type = learning

```yaml
options:
  - label: "学習開始: 関連資料を並べて章立てで解説"
    description: "秘書が resource 列の資料を整理して解説"
  - label: "ハンズオン実施: 手を動かしながら学ぶ"
    description: "実コマンド/実操作ベースの対話型学習"
  - label: "ノート自動作成 (subagent 委譲)"
    description: "tech-researcher / retail-domain-researcher が learning-notes/ に MD 生成"
  - label: "壁打ちから: 現状理解を話して穴を埋める"
    description: "秘書が理解度テスト形式でギャップ発見"
```

### type = diagram

```yaml
options:
  - label: "/company-diagram (AWS 構成図)"
  - label: "/company-drawio (汎用図: ER/フロー/シーケンス)"
  - label: "要件を壁打ちしてから決める"
```

### type = research

```yaml
options:
  - label: "tech-researcher に委譲"
    description: "技術系 web 調査 + レポート作成"
  - label: "retail-domain-researcher に委譲"
    description: "小売ドメイン web 調査 + レポート作成"
  - label: "両方並列で調査 (Agent Teams)"
    description: "技術×小売の横串レポート"
  - label: "まず範囲を壁打ち"
```

### type = delivery

```yaml
options:
  - label: "実装開始 (関連コード Read + ハンズオン)"
  - label: "テンプレ作成 (standards-lead / technical-writer)"
  - label: "設計→実装の 2 段階 (system-architect + lead-developer)"
  - label: "まず仕様を壁打ち"
```

### type = operational

```yaml
options:
  - label: "秘書 (secretary) に委譲"
  - label: "手動で対応 (資料だけ並べる)"
```

---

## 9. Phase 8: 実行

ユーザが選んだ方針に応じて以下を実行:

| 方針 | 実装 |
|---|---|
| 学習開始 (資料解説) | 秘書として Web 検索せず、resource 列のファイル/URL を Read + 章立てで解説 |
| ハンズオン | 手順を 1 ステップずつ提示、実コマンド実行 (Bash) + 確認 |
| subagent 委譲 | `Task` tool で対応 subagent_type を spawn、prompt に タスク詳細 + 期待成果物パス + Case Bank 参照指示を含める |
| skill 呼出 | `/company-diagram` / `/company-drawio` を `Skill` tool で起動 |
| 壁打ち | 秘書として対話、ユーザの現状理解をヒアリングしてギャップを埋める |
| 手動 | タスク詳細表示のみで終了 (ユーザが自分で進める) |

**重要**: 実行開始時に「このタスクに `status:in-progress` ラベルを付けますか?」と確認し、yes なら:

```bash
gh issue edit "$ISSUE_NUMBER" --add-label "status:in-progress"
```

---

## 10. Phase 完了後の扱い

作業完了時、ユーザに以下を問いかける:

1. 「このタスクを完了にしますか?」
   - Yes → `gh issue close "$ISSUE_NUMBER" --reason completed`
   - 翌朝 05:00 JST の `daily-todo-sync.yml` が WBS markdown の `[x]` を更新する
   - 翌朝 05:30 JST の `daily-kanban-sync.yml` が Project 2 から該当 item を削除する

2. 「学習ノート / 成果物を保存しますか?」
   - 学習系 → `.companies/{org}/docs/secretary/learning-notes/{wbs_id}-{slug}.md` に追記/新規作成
   - delivery 系 → 適切な部署配下に配置

---

## 11. 禁止事項

- ❌ Project 2 の item を勝手に追加・削除しない (`daily-kanban-sync` の責務)
- ❌ WBS markdown を直接編集しない (`daily-todo-sync` で自動同期される)
- ❌ Issue label を勝手に付け替えない (`bootstrap` の責務、例外は `status:in-progress`)
- ❌ ユーザ確認なしに破壊的操作 (issue close / label 削除) をしない
- ❌ AskUserQuestion の options を 5 件超にしない (UI 制約)

---

## 12. 関連ファイル・スキル

| ファイル / Skill | 用途 |
|---|---|
| `.claude/hooks/parse-wbs.py` | WBS タスク詳細取得 |
| `.companies/*/docs/**/*wbs*.md` | WBS 元データ |
| `.claude/rules/todo-management.md` | TODO 管理ルール全体版 |
| `.github/workflows/daily-kanban-sync.yml` | Project 2 自動補充 |
| `/company-diagram` | diagram 系タスクの delegate 先 |
| `/company-drawio` | drawio 系タスクの delegate 先 |

---

## 13. 起動例

```
User: /company-today

秘書: 🔍 Project 2 のオープン TODO を取得しています...
秘書: 見つかったタスク: 5 件
       - domain-tech-collection: 3 件
       - standardization-initiative: 2 件

       [AskUserQuestion] どの組織のタスクから始めますか?

User: → domain-tech-collection

秘書: ✅ domain-tech-collection の TODO 3 件 (priority 順):
       1. WBS 2.1.3 店舗内システム構成 (W3 / learning)
       2. WBS 3.1.3 コンテナ基礎 (W3 / learning)
       3. WBS 4.1.3 リスク管理基礎 (W3 / learning)

       [AskUserQuestion] どの WBS タスクに取り組みますか?

User: → WBS 3.1.3 コンテナ基礎

秘書: 📋 WBS 3.1.3: コンテナ基礎（Docker, ECS/Fargate, Lambda入門）
       - セクション: 3. 技術スタック習得 / Phase 1: AWS基礎
       - タイプ: learning
       - 優先度: 1
       - 期間: W3 (6h)
       - 成果物: ハンズオンメモ
       - 参考: AWSハンズオン + Docker公式ドキュメント
       🔗 https://github.com/.../issues/294

       [AskUserQuestion] このタスクをどう進めますか?

User: → ハンズオン実施

秘書: 🎯 では Docker 基礎から始めましょう。
       まず公式チュートリアルの "Get Docker" を開いて...
       (手順を 1 ステップずつ提示)
```
