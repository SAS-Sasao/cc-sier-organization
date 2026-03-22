# 01 クイックスタート

セットアップから最初のタスク完了まで、15分でできます。

---

## 前提条件

```bash
claude --version    # Claude Code
git --version       # Git
gh --version        # GitHub CLI（Issue/PR自動作成に必要）
python3 --version   # 継続学習のCase Bank構築に必要
```

---

## Step 1: リポジトリのセットアップ

```bash
git clone https://github.com/SAS-Sasao/cc-sier-organization
cd cc-sier-organization

# Hooksスクリプトに実行権限を付与
chmod +x .claude/hooks/*.sh

# GitHub CLI の認証（初回のみ）
gh auth login
```

---

## Step 2: 組織を作る・入る

**存在しない org-slug を指定すると新規作成、存在する場合は切り替えになります。**

```
# 初期同梱の組織に入る
/company jutaku-dev-team

# 新規組織を作る（指定した org-slug が存在しなければ自動生成）
/company a-corp-ordering-system
```

**初期同梱の3組織（すぐに使い始められます）:**

| org-slug | 用途 |
|---|---|
| `jutaku-dev-team` | 受注開発プロジェクト |
| `standardization-initiative` | 社内標準化 |
| `domain-tech-collection` | 技術調査・知識収集 |

新規作成時は `CLAUDE.md`・`masters/`・`docs/secretary/` が自動生成されます。
その後 `/company-admin` でマスタ（顧客情報・役割など）を追加してください。

---

## Step 3: 最初のタスクを依頼する

```
A社の受注システムについて要件定義書を作成してほしい。
ECサイトで商品管理、注文管理、顧客管理が必要。
AWSを使う予定。
```

秘書が business-analyst → technical-writer の順で委譲し、
`docs/system/requirements/` に成果物を配置してPRを作成します。

---

## Step 4: 継続学習を初回実行する

```
/company-evolve
```

Case Bank が構築され、次のセッションから秘書のルーティング精度が向上します。

---

## よくある使い方パターン

### プロジェクト管理

```
今日のタスクを整理して
B社向けのシステム設計書（概要レベル）を作成して
今日の進捗をまとめて
```

### 技術調査

```
/company domain-tech-collection

Apache Kafkaについて調査して。
AWSのMSKとの比較、SIer案件での適用ケースをまとめてほしい。
```

### 週次レポート

```
/company-report week
```

---

## トラブルシューティング

**`gh: command not found`**
GitHub CLI をインストールしてください。ログ記録・PR作成機能が使えなくなります。

**`.companies/.active が存在しない`**
`/company {org-slug}` を先に実行してアクティブ組織を設定してください。

**`Case Bank not found, skipping`**
`/company-evolve` を実行する前に少なくとも1件タスクを完了させてください。
