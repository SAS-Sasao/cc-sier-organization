# TODO 管理ルール（全組織共通）

WBS markdown を Source of Truth とし、GitHub Issues + Projects v2 を派生ビューとして同期する三層構造の TODO 管理ルール。毎朝 05:00 JST の `daily-todo-sync.yml` workflow および、ローカル `/company` Skill から参照される。

## 1. 三層モデル

```
[layer 1 / SSoT]  WBS markdown (.companies/{org}/docs/**/*wbs*.md)
                           │
[layer 2 / 派生]  GitHub Issues (label: todo:wbs, wbs:N.M, org:{slug}, iteration:WN)
                           │
[layer 3 / 可視化] GitHub Projects v2 (Fields: Iteration, Priority, Org, WBS-ID, Type, Today)
```

- **layer 1 (WBS)**: ステータスの最終判定はここ。`[ ]` → `[~]` → `[x]` の三値
- **layer 2 (Issues)**: WBS タスクと 1:1 対応。close されると layer 1 の `[x]` も反映
- **layer 3 (Projects)**: UI 操作・ドラッグ編集を受ける。ただし翌朝 layer 1 が勝つ

## 2. ステータス同期のルール

### 2.1 完了判定（`[x]` 遷移）

以下の **いずれか** が発生したら該当 WBS タスクを `[x]` に更新:

1. **対応 Issue が close された** (label `wbs:N.M` が一致)
2. **対応する成果物ファイルが main に commit された** (WBS 行の「成果物」列パスが存在)
3. **対応する task-log が status: completed かつ request に WBS ID を含む**
4. **ユーザが明示的に WBS markdown を直接編集した** (human override)

### 2.2 進行中判定（`[~]` 遷移）

以下で `[ ]` → `[~]`:

1. 対応 Issue に `in-progress` ラベルが付いた
2. 対応 task-log が status: in-progress で存在
3. 関連ブランチが open されている（`wbs:N.M` を含むブランチ名）
4. Projects v2 で Status = "In Progress" になっている（UI 操作）

### 2.3 停滞判定（Blocker 警告）

以下で警告のみ（自動ステータス変更なし）:

- Projects v2 Status = "In Progress" のまま **3 日以上** 滞留
- 対応 Issue が open のまま **7 日以上** 活動なし
- 期限 (Iteration) を過ぎても `[ ]` のまま

警告方法: tracking issue コメント + Projects v2 に `blocker` ラベル付与

## 3. 今日の Top N 選定ロジック（AI判断）

毎朝 `daily-todo-sync.yml` の Claude Code Action が以下の順序で「今日やるべき Top N」を選ぶ:

### 3.1 候補の絞り込み

1. **開始時点で候補全て取得**:
   - 全組織の WBS markdown を parse
   - ステータスが `[ ]` または `[~]` のタスク全て

2. **完了除外 (WBS 照合)**:
   - `[x]` 完了済みタスクは候補から除外
   - 前日 merge PR に紐付く Issue の WBS タスクも除外
   - ※ 旧秘書室 CLAUDE.md の「WBS → 前日未完了 → 完了除外 → 本日 TODO 構成」照合順序をここで適用

3. **iteration フィルタ**:
   - 今週に属する iteration (例: 今日が W3 の木曜 → iteration:W3) のタスクを優先
   - 前週の繰り越しタスクも含める
   - 前々週以前の繰り越しは blocker 扱いで選定しない

4. **優先度ソート**:
   - Priority 1 (最優先) → Priority 2 (高) → Priority 3 (中) → Priority 4 (低)
   - 同優先度内では Type = "delivery" > "learning" > "diagram" > "research" > "operational"

### 3.2 Top N 選定（N = 5 デフォルト）

1. **依存関係チェック**: 親タスク (M1-M4 milestone / phase prerequisite) が未完了なら後続を後回し
2. **時間見積もり累計**: 「時間」列の合計が 4 時間を超えたら打ち切り（1 日の作業上限）
3. **Case Bank 参照**: 類似の過去失敗パターンがあれば priority を +1 格上げ
4. **Type バランス**: learning/diagram/research の比率が偏らないよう調整

### 3.3 ユーザ操作の尊重

- Projects v2 UI で既に "Today = Yes" が付いているアイテムは **先に確定**（AI の上書き禁止）
- AI が選んだ Top N は既存の Today タスクを「補完」する形で追加
- 最終的な Today 数が N を超えた場合は AI 追加分から削減

## 4. 複数組織の扱い

- 全 `.companies/*/docs/**/*wbs*.md` を対象に一括処理
- Issue/Projects item には `org:{slug}` ラベル必須
- Top N は組織横断で選定（ただし active な組織のみ）
- 組織ごとに独自の WBS スキーマ差異があるため、parse-wbs.py で header-aware に解釈

## 5. ブランチ・コミット戦略

### 5.1 WBS 自動更新のコミット

- WBS のステータス自動変更は **feature branch + PR** で main に反映
- PR タイトル: `chore: WBS status 自動同期 ({date}) [todo-sync]`
- PR body に差分サマリー（何を `[x]` に変えたか、理由）を記載
- `daily-todo-sync` ラベル付与
- 変更なしの日は PR 作成しない

### 5.2 Issue 自動操作

- Issue の auto-close / label 変更は GITHUB_TOKEN で直接実行（PR 不要）
- 操作履歴は tracking issue にコメントとして残す

### 5.3 Projects v2 操作

- PROJECTS_PAT secret 経由で GraphQL mutation
- 失敗時はリトライ 1 回、それでも失敗なら tracking issue に警告

## 6. sync-board.sh との共存

- `.claude/hooks/sync-board.sh` は既存の board.md 生成スクリプト
- daily-todo-sync.yml が実行する順序:
  1. 全組織の WBS を parse-wbs.py で解釈
  2. Claude Code Action で status 更新 / Top N 選定
  3. WBS markdown 更新
  4. sync-board.sh を全組織で実行 → board.md 再生成
  5. Projects v2 同期
- board.md は sync-board.sh が管轄、Projects v2 は新 workflow が管轄（棲み分け）

## 7. 禁止事項

- ❌ GitHub Projects v2 UI で status 以外のフィールド (WBS-ID, Org, Type) を手動編集
  - 理由: これらは WBS から派生するため、WBS 側を変更すべき
- ❌ layer 2 (Issue) から layer 1 (WBS) への反映を待たずに判断
  - 理由: SSoT 原則に反する、レース条件を招く
- ❌ ユーザが UI で動かしたアイテムを AI が翌朝書き換える
  - 理由: ユーザの意思を尊重する（3.3 のルール）
- ❌ WBS markdown の既存カラム順序を変更する
  - 理由: sync-board.sh の pattern 判定が壊れる（新カラムは末尾にのみ追加可）

## 8. 関連

- @.claude/rules/wbs-schema.md — WBS markdown の拡張スキーマ定義
- @.claude/hooks/parse-wbs.py — マルチスキーマ parser 実装
- @.claude/hooks/bootstrap-todo-issues.sh — 初回 Issue バルク作成
- @.claude/hooks/sync-board.sh — board.md 自動生成（既存）
- @.github/workflows/daily-todo-sync.yml — 朝 05:00 JST の同期 workflow
- @.claude/rules/git-workflow.md — ブランチ・PR 運用
- @.claude/rules/task-log.md — task-log → Issue 連携
