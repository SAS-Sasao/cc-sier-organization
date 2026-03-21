# Spawnテンプレート集

このファイルは `/company-spawn` Skill が新リポジトリ生成時に参照するテンプレートを定義します。

---

## 1. 新リポ用 .gitignore テンプレート

### Python系（dbt, FastAPI, Django）

```gitignore
# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.venv/
venv/
.eggs/
*.egg-info/
*.egg

# Environment
.env
.env.local

# IDE
.vscode/
.idea/

# OS
.DS_Store
Thumbs.db

# Logs
*.log

# Claude Code
.claude/settings.json
```

### Node.js系（React + TypeScript）

```gitignore
# Dependencies
node_modules/

# Build
dist/
build/
.next/

# Environment
.env
.env.local

# IDE
.vscode/
.idea/

# OS
.DS_Store
Thumbs.db

# Logs
*.log

# Claude Code
.claude/settings.json
```

### Terraform

```gitignore
# Terraform
.terraform/
*.tfstate
*.tfstate.backup
*.tfplan
.terraform.lock.hcl

# Environment
.env

# IDE
.vscode/
.idea/

# OS
.DS_Store
Thumbs.db

# Logs
*.log

# Claude Code
.claude/settings.json
```

### 共通（技術スタック未指定時）

```gitignore
# Environment
.env
.env.local

# IDE
.vscode/
.idea/

# OS
.DS_Store
Thumbs.db

# Logs
*.log

# Claude Code
.claude/settings.json
```

---

## 2. 新リポ用 CLAUDE.md テンプレート

```markdown
# {repo-name}

## プロジェクト概要
{project-description}

## 設計の出自
このプロジェクトの設計は cc-sier-organization リポジトリの
組織「{org-slug}」で策定されました。
詳細は `docs/design/origin.md` を参照してください。

## 技術スタック
{tech-stack}

## ディレクトリ構成
{generated-tree}

## 開発ルール
- コミットメッセージ: Conventional Commits
- ブランチ戦略: GitHub Flow（main + feature branches）
- 設計変更: 重要な変更はADRで記録（docs/design/ADR-*.md）
```

---

## 3. 新リポ用 README.md テンプレート

```markdown
# {repo-name}

{description}

## 設計の出自

このプロジェクトの設計は [cc-sier-organization]({cc-sier-repo-url}) の
組織「{org-slug}」で策定されました。

設計成果物は `docs/design/` に配置されています。
詳細は [docs/design/origin.md](docs/design/origin.md) を参照してください。

## 技術スタック

{tech-stack-details}

## セットアップ

{tech-stack に応じた手順}

## 開発ルール

- コミットメッセージ: Conventional Commits
- ブランチ戦略: GitHub Flow
- 設計変更: ADRで記録（`docs/design/ADR-*.md`）
```

---

## 4. origin.md テンプレート

```markdown
# 設計成果物の出自情報

## ソース
- **リポジトリ**: {cc-sier-repo-url}
- **組織**: {org-slug}
- **コピー日**: {YYYY-MM-DD}
- **コピー元コミット**: {commit-hash}
- **作業者**: {operator}

## コピーした成果物
| ファイル | コピー元パス | 作成日 |
|---------|------------|--------|
{成果物テーブル}

## 更新ルール
- 設計変更が発生した場合はcc-sier側で更新し、このリポにも反映すること
- このリポで設計を直接変更した場合は、cc-sier側にもフィードバックすること
- origin.md は削除しないこと（設計のトレーサビリティ維持のため）
```

---

## 5. 技術スタック別セットアップ手順テンプレート

### Python + dbt

```markdown
## セットアップ

1. Python 3.10+ をインストール
2. 仮想環境を作成:
   ```bash
   python -m venv .venv
   source .venv/bin/activate
   ```
3. 依存パッケージをインストール:
   ```bash
   pip install -r requirements.txt
   ```
4. `profiles.yml` をローカル環境に合わせて設定
5. dbt の接続テスト:
   ```bash
   dbt debug
   ```
```

### Python + FastAPI

```markdown
## セットアップ

1. Python 3.10+ をインストール
2. 仮想環境を作成:
   ```bash
   python -m venv .venv
   source .venv/bin/activate
   ```
3. 依存パッケージをインストール:
   ```bash
   pip install -r requirements.txt
   ```
4. `.env` ファイルを作成（`.env.example` を参照）
5. 開発サーバーを起動:
   ```bash
   uvicorn src.app.main:app --reload
   ```
```

### Terraform

```markdown
## セットアップ

1. Terraform 1.5+ をインストール
2. クラウドプロバイダの認証を設定
3. 初期化:
   ```bash
   cd terraform/environments/dev
   terraform init
   ```
4. プランの確認:
   ```bash
   terraform plan
   ```
```

### React + TypeScript

```markdown
## セットアップ

1. Node.js 18+ をインストール
2. 依存パッケージをインストール:
   ```bash
   npm install
   ```
3. 開発サーバーを起動:
   ```bash
   npm run dev
   ```
```

### Django

```markdown
## セットアップ

1. Python 3.10+ をインストール
2. 仮想環境を作成:
   ```bash
   python -m venv .venv
   source .venv/bin/activate
   ```
3. 依存パッケージをインストール:
   ```bash
   pip install -r requirements.txt
   ```
4. データベースのマイグレーション:
   ```bash
   python manage.py migrate
   ```
5. 開発サーバーを起動:
   ```bash
   python manage.py runserver
   ```
```
