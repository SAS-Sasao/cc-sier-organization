# CC-SIer

**Claude Code 仮想組織プラグイン — SIer業務特化版**

## 概要

SIer業務は多領域にまたがります。プロジェクト管理、システム設計、受託開発、標準化、AI駆動開発、テスト自動化、CI/CD、IaC、データアーキテクチャ（DWH構築）—— これらが同時並行で走る環境において、Claude Code 上に**仮想組織**を構築し、業務ごとに専門化されたエージェントチームを動的に編成・運用する仕組みを提供します。

[cc-company v2.0.0](https://github.com/Shin-sibainu/cc-company) の「秘書 → 部署」モデルを踏襲しつつ、以下の進化を加えています:

1. **マスタ駆動の動的組織編成** — 組織・部署・メンバー（エージェントロール）をmdファイルでマスタ管理し、Skillが作業依頼に応じて最適な構成を提案
2. **Claude Code 公式機能への正確なマッピング** — Skills、Subagents、Agent Teams、CLAUDE.md をそれぞれの正規ディレクトリに配置
3. **SIer業務ドメインの深い対応** — 受託開発ライフサイクル、標準化活動、ナレッジ蓄積に特化したテンプレートとワークフロー
4. **Skill経由のマスタ管理** — `/company-admin` で部署・ロール・ワークフローを対話的にCRUD。変更時にはSubagentファイルやCLAUDE.mdへの整合性連鎖更新が自動で実行

## コンセプト

```
[CC-SIer 機能マッピング]

Claude Code 機能         本プラグインでの用途
─────────────────────    ──────────────────────────────────
CLAUDE.md                組織ルール、部署ルール、運営ポリシーの永続的な指示
Skills (.claude/skills/) /company コマンド、マスタ参照ロジック、ワークフロー実行
Subagents (.claude/agents/) 部署ロールの実体（SA、PM、QA等の専門エージェント）
Agent Teams              大規模並列作業（設計レビュー、フルスタック開発等）
Plugins (.claude-plugin/)  CC-SIer全体のパッケージング・配布

[実行フロー]

/company 実行
  │
  ▼
Skill (SKILL.md) が起動
  │
  ├─ masters/ を参照して実行方式を判定
  │
  ├─ [subagent の場合]
  │   └─ 名前指定で Subagent を呼び出し
  │      → 独立コンテキストで専門作業を実行
  │
  └─ [agent-teams の場合]
      └─ チームリード（秘書）が Agent Teams を編成
         → 複数テイメイトが並列作業
         → 共有タスクリスト + メールボックスで自律連携
```

## インストール

> **注意**: 本プラグインは開発中です。インストール手順は今後公開予定です。

```bash
# プラグインインストール（予定）
# claude plugin install cc-sier
```

## 使い方

```
/company        — 秘書に話しかける（メインSkill）
/company-admin  — マスタ管理（部署・ロール・ワークフローのCRUD）
```

## 実装ロードマップ

### Phase 1: コア機能（MVP）
- メインSkill (`/company`) とマスタ管理Skill (`/company-admin`)
- references ファイル群（master-schemas.md 含む）
- 秘書 Subagent
- マスタファイル群 + 秘書室

### Phase 2: Subagent群 + Agent Teams
- 全 Subagent（13種: PM、SA、データアーキテクト、QAリード等）
- Agent Teams 編成ロジック
- ワークフロー実行
- 部署 CLAUDE.md 群（遅延ロード）

### Phase 3: ナレッジ + MCP + 配布
- ナレッジ管理（ポストモーテム、技術メモ、教育資料）
- MCP 連携（Backlog、GitHub、Notion、Slack等）
- プラグインパッケージとして配布

## ライセンス

MIT
