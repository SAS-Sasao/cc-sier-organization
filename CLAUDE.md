# CC-SIer 開発リポジトリ

このリポジトリは Claude Code プラグイン **cc-sier**（SIer業務特化の仮想組織プラグイン）の開発リポジトリです。

## ディレクトリ構成

```
cc-sier-organization/
├── .claude-plugin/           ← プラグインメタデータ（marketplace.json, plugin.json）
├── .companies/               ← 組織データ（マルチ組織対応）
│   ├── .active               ← アクティブ組織のslug
│   └── {org-slug}/           ← 組織ごとのディレクトリ
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

## マルチ組織構造

### .companies/ ディレクトリ

複数の仮想組織を並列管理するためのルートディレクトリ。各組織のマスタデータ・成果物はすべてこのディレクトリ配下の組織ディレクトリに格納される。

```
.companies/
├── .active                  ← 現在操作対象のorg-slugを1行で記載
├── a-sha-dwh-project/       ← 組織ディレクトリの例
│   ├── masters/             ← マスタデータ
│   ├── CLAUDE.md            ← 組織の文脈情報
│   └── {dept}/              ← 部署ごとの成果物
└── standardization-initiative/
    └── ...
```

### org-slug 命名ルール

- kebab-case（小文字英数字とハイフンのみ）
- 日本語はローマ字または英訳に変換
- 例: 「A社DWH構築プロジェクト」→ `a-sha-dwh-project`
- 例: 「社内標準化推進」→ `standardization-initiative`
- `.companies/` 直下のディレクトリ名として一意であること
- 既存と重複する場合はサフィックス（-2, -3等）を付与

### .active ファイル

`.companies/.active` にアクティブ組織の org-slug を1行で記載する。
Skillはこのファイルを起動時に読み取り、操作対象組織を特定する。

```
# .companies/.active の例
a-sha-dwh-project
```

---

## 成果物格納ルール

- **全成果物は `.companies/{org-slug}/` 配下に作成すること**
- リポジトリルートや `.claude/` 配下に業務成果物ファイルを作成してはならない
- Subagentへの委譲時も、組織パス（`.companies/{org-slug}/`）を明示して指示すること
- Subagentファイル（`.claude/agents/`）はグローバルリソースのため例外とする

---

## Gitワークフロー

ファイル生成を伴うすべての業務作業はブランチを作成してPRで管理する。

### ブランチ命名規則

```
{org-slug}/{type}/{YYYY-MM-DD}-{summary}
```

- `{type}`: 作業種別（`feat`, `fix`, `docs`, `admin` 等）
- `{summary}`: 作業概要をkebab-caseで記述
- 例: `a-sha-dwh-project/feat/2026-03-19-add-security-dept`
- 例: `a-sha-dwh-project/admin/2026-03-19-update-roles`

### コミットメッセージ

```
{type}: {概要} [{org-slug}]
```

- 例: `feat: セキュリティ部門を追加 [a-sha-dwh-project]`
- 例: `docs: 要件定義書を更新 [standardization-initiative]`

### フロー

1. mainから作業ブランチを作成
2. 成果物を `.companies/{org-slug}/` 配下に生成
3. コミット（メッセージは上記規則に従う）
4. PR作成（変更サマリーをPR本文に記載）
5. mainブランチに戻る

---

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
- プロジェクトルートの `CLAUDE.md`（このファイル）は開発用。ユーザー環境に生成される `.companies/{org-slug}/CLAUDE.md` とは別物
