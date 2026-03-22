# 07 company-spawn

---

## 概要

`/company-spawn` は、設計・検討したシステムを**実際の開発リポジトリとして切り出す**Skillです。

```
cc-sier-organization（組織・知識・設計）
         │
         │ /company-spawn
         ↓
{app-repo}/（実際の開発リポジトリ）
  ├── CLAUDE.md        ← 親組織の知識を継承
  ├── .claude/agents/  ← 必要なSubagentのみコピー
  ├── src/
  └── docs/            ← 設計書が移植される
```

---

## 使い方

```
/company-spawn
→「新しいリポジトリを作りたい。
  名前は a-corp-ordering-system。
  要件定義書と基本設計書は既にdocs/に作ってある。」
```

対話形式で以下を確認・設定します。

| 質問 | 例 |
|---|---|
| リポジトリ名 | `a-corp-ordering-system` |
| GitHub Organization | `SAS-Sasao` |
| 移植する成果物 | `docs/system/requirements/`, `docs/data/` |
| 必要なSubagent | `backend-engineer, devops-engineer` |
| 言語・フレームワーク | `Python/Django, PostgreSQL` |

---

## 親組織との関係

切り出し後、アプリリポジトリは独立した Claude Code プロジェクトとして動作します。

- **cc-sier-organization**: 進捗追跡・設計変更提案・レポート生成
- **{app-repo}**: 実際のコード開発・PR管理・アプリ固有の継続学習

2リポジトリが並走する形になります。
