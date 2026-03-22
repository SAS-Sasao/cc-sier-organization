# 00 全体概要

cc-sier-organization の設計思想とアーキテクチャを説明します。

---

## 設計思想

### 「組織」をコードで表現する

SIerの日常業務は高度に構造化されています。顧客ごとの制約、役割分担、成果物フォーマット、承認フロー。これらを毎回プロンプトで説明するのは無駄であり、ミスの原因にもなります。

cc-sier-organization は「組織のルール・知識・役割分担」をリポジトリ内のファイルとして表現し、Claude Code がそれを自律的に参照しながら動くことを目指しています。

```
従来の使い方:
  あなた ──「A社のDWH設計。A社はOracleを使っていて、XXX制約があって...」──▶ Claude

cc-sier-organization の使い方:
  あなた ──「A社のDWH設計をやって」──▶ 秘書 ──▶ data-architect
                                        ↑
                              masters/customers/a-corp.md を自動参照
```

### Memento-Skills：使うほど賢くなる

静的な設定ファイルだけでは、使い込むほど生まれる「暗黙知」を蓄積できません。cc-sier-organization は論文「Memento-Skills: Let Agents Design Agents」の設計を実装し、以下の学習ループを持ちます。

```
実行 → 評価（報酬スコア） → Case Bank 蓄積 → 次の判断に反映
                                    ↓
                          高品質パターンを検出
                                    ↓
                  新規Skill/Subagent として自動生成（PR提案）
```

LLMのパラメータを更新することなく、**Skill ファイル（Markdown）自体が進化的なメモリとして機能**します。

---

## アーキテクチャ全体図

```
┌──────────────────────────────────────────────────────────┐
│                    Claude Code セッション                   │
│                                                          │
│  あなた ──依頼──▶ secretary.md                            │
│                      │                                   │
│              ┌───────┴───────┐                           │
│              │  Read フェーズ  │                           │
│              │ Case Bank 参照 │                           │
│              └───────┬───────┘                           │
│                      │ 類似ケース注入                      │
│                      ▼                                   │
│               振り分け判断                                │
│              ┌────┬────┬────┐                            │
│              ▼    ▼    ▼    ▼                            │
│           SA-1  SA-2  SA-3  SA-N    ← 20種Subagent       │
│              └────┴────┴────┘                            │
│                      │                                   │
│                      ▼                                   │
│                成果物生成 → .companies/{org}/docs/         │
│                      │                                   │
│                      ▼                                   │
│              Git PR 作成（自動）                          │
│                                                          │
└──────────────────────────────────────────────────────────┘
             │                          │
      PostToolUse Hook              Stop Hook
             │                          │
             ▼                          ▼
   .interaction-log/         .session-summaries/ + GitHub Issue
             │                          │
             └──────────┬───────────────┘
                        │
              /company-evolve（Write フェーズ）
                        │
            ┌───────────┴────────────┐
            │                        │
      Case Bank 構築          Skill/Agent 進化
      (.case-bank/index.json)   (PR提案)
```

---

## ファイル・ロールの関係

### `.claude/` ─ Claude Code の設定

| ファイル | 役割 |
|---|---|
| `settings.json` | Hooks の設定（どのイベントにどのスクリプトを実行するか） |
| `agents/secretary.md` | 秘書エージェントの行動規範・起動時手順 |
| `agents/{name}.md` | 各専門Subagentの役割・出力形式・制約 |
| `skills/{name}/SKILL.md` | Claude Code `/コマンド` の実行手順 |
| `hooks/*.sh` | イベント駆動スクリプト |

### `.companies/{org-slug}/` ─ 組織データ

| ファイル/ディレクトリ | 役割 | Git 管理 |
|---|---|---|
| `CLAUDE.md` | 組織状態サマリー（秘書が毎回読む） | ✅ |
| `masters/` | 顧客・役割・ワークフロー定義 | ✅ |
| `docs/` | 成果物（設計書・報告書など） | ✅ |
| `.task-log/` | タスク実行ログ（reward スコア付き） | ✅ |
| `.interaction-log/` | ツール実行の詳細ログ | ❌ |
| `.session-summaries/` | セッション統計 JSON | ❌ |
| `.case-bank/` | 継続学習インデックス | ❌ |

---

## Skill vs Subagent の使い分け

| | Skill | Subagent |
|---|---|---|
| 呼び出し方 | `/company` などのスラッシュコマンド | 秘書が自動で委譲 |
| 役割 | 決まった手順のワークフロー（手順書） | 特定分野の専門家（判断と実行） |
| 設定ファイル | `.claude/skills/{name}/SKILL.md` | `.claude/agents/{name}.md` |
| 自動生成 | Skill Synthesizer が生成 | Subagent Spawner が生成 |

---

## 次のステップ

- セットアップを始めるには [01 クイックスタート](01-quickstart.md) へ
- コマンド一覧を確認するには [02 Skills リファレンス](02-skills.md) へ
- 継続学習の仕組みを深く理解するには [05 継続学習システム](05-learning-system.md) へ
