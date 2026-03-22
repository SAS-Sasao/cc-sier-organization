# 09 品質ゲートとダッシュボード

成果物の品質を自動チェックし、活動状況を可視化する機能を説明します。

---

## 品質ゲートの全体像

```
docs/ 配下の .md を保存
    ↓ PostToolUse Hook（自動）
quality-gate.sh
    ├── masters/quality-gates/ のチェックリストと照合
    ├── ✅ Pass → board.md の Done に移動
    └── ❌ Fail → GitHub Issue 作成 + board.md の Review に移動
```

---

## セットアップ手順

### Step 1: チェックリストを配置する

```
/company-quality-setup
```

`masters/quality-gates/` にチェックリストが配置されます。

**既にファイルがある場合の確認:**
```
masters/quality-gates/ には既にファイルが存在します。

1. 上書きする（テンプレートで全て置き換え）
2. 存在しないファイルだけ追加する（既存ファイルは維持）
3. キャンセル
```

### Step 2: 組織のルールをカスタマイズする（任意）

配置されたチェックリストを組織の実情に合わせて編集します。

```bash
# 設計書チェックを編集する例
vi .companies/{org-slug}/masters/quality-gates/by-type/design.md
```

**顧客固有のルールを追加する場合:**
`/company-admin` で顧客を登録すると `by-customer/{slug}.md` が自動生成されます。
そこに顧客固有のルールを追記します。

---

## 品質チェックの動作

### 自動チェック（PostToolUse Hook）

`docs/` 配下の `.md` ファイルを保存するたびに自動で実行されます。

**チェックの仕組み（キーワードベース）:**
チェックリストの各項目からキーワードを抽出し、成果物ファイルにそのキーワードが存在するかを確認します。完全な文書解析ではなく軽量な簡易チェックです。

**偽陽性・偽陰性について:**
キーワードが存在しても内容が不十分なケース、または別の表現で書かれているケースは検出できません。自動チェックを「最低ラインの確認」として使い、重要な成果物は `/company-review` で手動確認することを推奨します。

### 手動チェック（/company-review）

```
/company-review                                    # 直近24時間の変更ファイル
/company-review docs/system/requirements/a-corp.md # 特定ファイル
/company-review docs/proposals/                    # ディレクトリ配下全件
```

---

## タスクボード

`docs/secretary/board.md` がカンバン形式のタスクボードです。

### 状態の流れ

```
Todo → In Progress → Done
               ↓
            Review（品質NGで差し戻し）
               ↓
           修正して再保存 → 自動チェック → Pass → Done
```

### 手動操作

秘書に自然言語で伝えればボードが更新されます。

```
A社の要件定義タスクを開始して
DWH設計タスクを完了にして
```

---

## ダッシュボード

### 生成する

```
/company-dashboard
```

`docs/secretary/dashboard.html` が生成されます。

### ローカルで確認する

```bash
open .companies/{org-slug}/docs/secretary/dashboard.html   # Mac
```

### GitHub Pages で公開する

1. リポジトリの Settings → Pages を開く
2. Source: `main` ブランチ、フォルダ: `/docs` に設定
3. Save

以下のURLでアクセス可能になります。
```
https://{user}.github.io/{repo}/secretary/dashboard.html
```

> プライベートリポジトリで Pages を使うには GitHub Pro / Teams プランが必要です。

### ダッシュボードのウィジェット

| ウィジェット | データソース | 説明 |
|---|---|---|
| タスクボード状況 | `board.md` | 4列の件数とプログレスバー |
| 品質ゲート合格率 | `.quality-gate-log/` | ドーナツゲージ（80%↑緑 / 60%↑黄 / それ以下赤） |
| Subagent使用頻度 | `.task-log/` | 横棒グラフ（上位8件） |
| スコア推移 | `.case-bank/index.json` | 折れ線グラフ（直近30件） |
| 最近の成果物 | `.task-log/` | タイムライン（10件） |

### 自動更新のタイミング

- ブラウザ: 5分ごとに自動リフレッシュ
- `/company-report` 実行後: ダッシュボードも自動再生成

---

## チェックリストのカスタマイズ

### 全組織共通のテンプレートを変更する

`.claude/skills/company-quality-setup/templates/` を編集して git push します。
次に `/company-quality-setup`（「2. 存在しないファイルだけ追加する」）を実行すると新しいチェック項目が追加されます。

### 組織固有のルールを追加する

`masters/quality-gates/by-type/` の各ファイルに項目を追記します。

```markdown
## 組織固有チェック（手動追記）

- [ ] 社内レビューの承認印が記載されている
- [ ] 見積書は必ず部長承認済みであること
```

### severity の意味

| 設定値 | 動作 |
|---|---|
| `error` | 未達成でFail判定 → GitHub Issue作成 |
| `warning` | 未達成でも Pass（警告のみ） |
