# CC-SIer 開発リポジトリ

このリポジトリは Claude Code プラグイン **cc-sier**（SIer業務特化の仮想組織プラグイン）の開発リポジトリです。

## ディレクトリ構成

```
cc-sier-organization/
├── .claude-plugin/           ← プラグインメタデータ（marketplace.json, plugin.json）
├── plugins/cc-sier/
│   ├── skills/
│   │   ├── company/          ← メインSkill（/company コマンド）
│   │   │   ├── SKILL.md
│   │   │   └── references/   ← 部署テンプレート、ワークフロー定義等
│   │   └── company-admin/    ← マスタ管理Skill（/company-admin コマンド）
│   │       ├── SKILL.md
│   │       └── references/
│   └── agents/               ← Subagent定義（secretary.md, project-manager.md 等）
├── docs/
│   └── requirements.md       ← 要件定義書（実装時は必ず参照すること）
├── requirements/             ← 要件定義書の原本
├── CLAUDE.md                 ← このファイル
├── README.md
└── LICENSE
```

## 要件定義書

**docs/requirements.md** に要件定義書 v0.3 があります。実装時は必ず該当セクションを参照してください。

主要セクション:
- セクション 2: Claude Code 機能マッピング
- セクション 3: Skill 設計（/company, /company-admin）
- セクション 4: Subagent 設計（13種のエージェント定義）
- セクション 5: CLAUDE.md 設計（階層構造）
- セクション 6: マスタデータ設計（スキーマ、連鎖更新ルール）
- セクション 7: Agent Teams 統合設計
- セクション 8: SIer特化テンプレート（ADR、ポストモーテム等）

## 開発ルール

### コミットメッセージ
Conventional Commits に従うこと:
- `feat:` 新機能
- `fix:` バグ修正
- `docs:` ドキュメントのみの変更
- `refactor:` リファクタリング
- `chore:` ビルド・設定等の変更

### 言語
- ドキュメント・コメント: 日本語
- コード内コメント: 英語可

### SKILL.md の制約
- **1,500〜2,000語以内に収めること**（プログレッシブ・ディスクロージャ）
- 詳細な定義は `references/` 配下に外出しし、必要時のみ参照する

### 実装時の必須事項
- 実装前に必ず `docs/requirements.md` の該当セクションを読むこと
- マスタスキーマの変更は `references/master-schemas.md` のバリデーションルールに従うこと

## 重要な注意

- `plugins/cc-sier/skills/` 配下が **Skill ファイル**（プラグインインストール時に `.claude/skills/` に配置される）
- `plugins/cc-sier/agents/` 配下が **Subagent ファイル**（プラグインインストール時に `.claude/agents/` に配置される）
- プロジェクトルートの `CLAUDE.md`（このファイル）は開発用。ユーザー環境に生成される `.company/CLAUDE.md` とは別物
