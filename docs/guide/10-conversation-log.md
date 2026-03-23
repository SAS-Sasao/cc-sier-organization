# 10 会話ログと継続学習

会話ログの自動取得・マスキング・Case Bankへの活用を説明します。

---

## 概要

cc-sier-organization はセッション終了時に会話の全内容を自動で保存します。
取得・マスキング・学習活用まで、何もしなくても自動で動きます。

```
セッション終了
  ↓ 自動
会話ログ取得（capture-conversation.sh）
  ├── 発言・応答・ツール実行をすべて記録
  ├── 顧客名など固有名詞をマスキング
  └── .conversation-log/YYYY-MM-DD-{id}.md に保存

/company-evolve 実行時
  ↓ 自動
Case Bank 強化（enrich-case-bank.sh）
  ├── 頻出フレーズを抽出
  ├── タスクの背景・意図をCase Bankに付加
  └── 秘書の委譲判断がより正確になる
```

---

## 自動化の仕組み

### いつから記録されるか

```
/company {org-slug} を実行（アクティブ組織を設定）
  ↓
Claude Code で作業する
  ↓
セッションを終了する
  ↓ Stop Hook が自動起動
.conversation-log/YYYY-MM-DD-{id}.md が自動生成される
```

**新規・既存どちらの組織でも同じです。**
初回セッション終了時にディレクトリが自動作成されるため、事前準備は不要です。

---

## マスキングの仕組み

会話ログには機密情報が含まれる可能性があるため、保存前にマスキング処理を行います。

### マスキングが自動適用されるもの

| 対象 | 変換後 | 例 |
|---|---|---|
| 顧客名（`masters/customers/` 記載） | `[CLIENT-01]` | `A社` → `[CLIENT-01]` |
| 担当者名（顧客マスタ記載） | `[PERSON-01]` | `山田様` → `[PERSON-01]` |
| 電話番号 | `[PHONE]` | `03-1234-5678` → `[PHONE]` |
| メールアドレス | `[EMAIL]` | `yamada@example.com` → `[EMAIL]` |
| 金額（5桁以上・¥付き） | `[NUMBER]` | `¥1,200,000` → `[NUMBER]` |

### マスキング辞書は自動で育つ

`/company-admin` で顧客を追加するたびに、
その顧客名・担当者名が自動でマスキング対象に追加されます。

```
/company-admin → A社を登録
  → 次のセッションから「A社」が [CLIENT-01] に自動変換される
```

---

## 会話ログのファイル形式

`.conversation-log/2026-03-22-abc12345.md` の例:

```markdown
---
session_id: "abc12345..."
date: "2026-03-22"
operator: "sasao"
org: "jutaku-dev-team"
masked: true
---

# 会話ログ — 2026-03-22

## 👤 Human

[CLIENT-01]のDWH設計をやってほしい。
メダリオンアーキテクチャで Bronze/Silver/Gold の3層構成で。

---

## 🤖 Claude

承知しました。[CLIENT-01]のDWH設計を進めます。

```tool_use:bash_tool
command: ls masters/customers/
```

---

## 統計

| 項目 | 値 |
|---|---|
| 人間の発言数 | 8 |
| Claudeの応答数 | 8 |
| ツール実行数 | 24 |
| マスキング適用 | 3 種類 |
```

---

## 継続学習への活用

### `/company-evolve` 実行時の処理

`enrich-case-bank.sh` が以下を行います。

**1. 頻出フレーズの抽出**

過去の会話から「2回以上使ったフレーズ」を検出して MEMORY.md に記録します。

```
「メダリオンアーキテクチャで」（5回）
「3層構成で」（4回）
→ MEMORY.md に記録 → 秘書がこのフレーズを認識して適切なSubagentに委譲
```

**2. Case Bank エントリへの意図・背景の付加**

タスクログの各エントリに `conversation_context` が追加されます。

```json
{
  "state": { "request_head": "A社のDWH設計をやって" },
  "action": { "subagent": "data-architect" },
  "reward": 0.9,
  "conversation_context": [
    "メダリオンアーキテクチャで Bronze/Silver/Gold の3層構成で",
    "先週の要件定義の続きで、データ品質管理も入れてほしい"
  ]
}
```

**3. 秘書の委譲精度が向上する**

次に似た依頼が来たとき、秘書は「以前この種の依頼は背景に
要件定義の続きがあった」という情報を使って委譲先を判断できます。

---

## Git管理とプライバシー

| ファイル | 管理 | 理由 |
|---|---|---|
| `.conversation-log/*.md` | Git管理外 | 会話内容・プライバシー保護 |
| `capture-conversation.sh` | Git管理 | スクリプト本体はチーム共有 |
| `enrich-case-bank.sh` | Git管理 | スクリプト本体はチーム共有 |

`.conversation-log/` は `.gitignore` によってGitHubにプッシュされません。
マスキング済みでもローカルにのみ保存されます。

---

## トラブルシューティング

**会話ログが生成されない場合:**

```bash
# 1. アクティブ組織が設定されているか確認
cat .companies/.active

# 2. スクリプトに実行権限があるか確認
ls -la .claude/hooks/capture-conversation.sh

# 3. Claude Codeの会話ログファイルが存在するか確認
PROJECT_HASH=$(python3 -c "
import hashlib, sys
print(hashlib.sha256(sys.argv[1].encode()).hexdigest())
" "$(pwd)")
ls "$HOME/.claude/projects/$PROJECT_HASH/" | tail -5
```

**マスキングが効いていない場合:**

`masters/customers/` の顧客ファイルを確認し、
顧客名が正しく記載されているか確認してください。

```bash
cat .companies/$(cat .companies/.active)/masters/customers/a-corp.md | head -5
```
