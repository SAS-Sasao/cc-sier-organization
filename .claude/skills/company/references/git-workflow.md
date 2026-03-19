# Gitワークフロー詳細定義

このファイルは `/company` Skill のセクション 3.6 が参照する、Gitワークフローの詳細定義です。
SKILL.md は概要のみを記載し、判断ロジック・コマンド・テンプレートはすべてこのファイルに集約します。

---

## 1. ファイル生成有無の判定基準

Gitワークフローを実行するかどうかは、作業の種別で判断します。

### Gitワークフローが必要な作業（ブランチ作成 → コミット → PR）

- ドキュメント生成（設計書、ADR、議事録、ポストモーテム等）
- TODOリスト・進捗ファイルの作成・更新
- マスタファイルの新規作成・更新（オンボーディング含む）
- 部署フォルダ・CLAUDE.md の追加・変更
- SIer特化テンプレートを使ったファイル出力全般

### Gitワークフローが不要な作業（ブランチ作成しない）

- 壁打ち・アイデア出し（ファイル出力なし）
- ダッシュボード表示・状態確認
- 口頭相談・質問への回答
- 既存ファイルの閲覧・読み上げ
- 組織選択・切り替え操作

**判定に迷う場合の原則**: 「`.companies/{org-slug}/` 配下に新規または更新ファイルが生まれるか？」で判断する。Yes ならワークフローを実行する。

---

## 2. ブランチ命名規則

### フォーマット

```
{org-slug}/{type}/{YYYY-MM-DD}-{summary}
```

### type の選択肢

| type | 使用場面 |
|------|---------|
| `design` | 設計書・アーキテクチャ文書の作成 |
| `docs` | 一般的なドキュメント作成・更新 |
| `todo` | TODOリスト・タスク管理ファイルの操作 |
| `feat` | 新機能・新部署・新ワークフローの追加 |
| `fix` | 既存ドキュメントの誤り修正 |
| `admin` | マスタ変更・組織設定変更 |
| `spike` | 技術調査・検証 |

### summary の命名ルール

- 英数字とハイフンのみ使用（日本語不可）
- 3〜5単語程度の簡潔な説明
- 日本語の内容は英語に意訳する

### 命名例

```
a-sha-dwh/design/2026-03-19-medallion-architecture
shakai-it/docs/2026-03-20-kickoff-minutes
hyojunka/admin/2026-03-21-add-architecture-dept
shakai-it/todo/2026-03-19-sprint-1-tasks
a-sha-dwh/feat/2026-03-22-add-quality-check-workflow
```

---

## 3. 作業前手順

### ステップ 1: ブランチ状態の確認

```bash
git branch --show-current
```

- `main` 以外のブランチにいる場合: 「現在 `{branch}` ブランチにいます。このまま続けますか？ それとも main に戻りますか？」とユーザーに確認する。
- 未コミットの変更がある場合: 「未コミットの変更があります。stash しますか？」と確認してから進む。

確認コマンド:

```bash
git status --short
```

### ステップ 2: stash（必要な場合）

```bash
git stash push -m "work-in-progress before {branch-name}"
```

### ステップ 3: ブランチ作成と切り替え

```bash
git checkout -b {branch-name}
```

---

## 4. 作業後手順

### ステップ 1: 組織ディレクトリのみをステージング

```bash
git add .companies/{org-slug}/
```

他の組織や `.companies/.active` への意図しない変更を含めないよう、組織ディレクトリを明示指定します。
ただし `.companies/.active` を更新した場合は個別に追加します:

```bash
git add .companies/.active
```

### ステップ 2: コミット

#### コミットメッセージのフォーマット

```
{type}: {概要} [{org-slug}]
```

#### コミットメッセージの例

```
design: メダリオンアーキテクチャ設計書を作成 [a-sha-dwh]
docs: キックオフ議事録を追加 [shakai-it]
admin: アーキテクチャ室を追加 [hyojunka]
todo: スプリント1 TODOリストを作成 [shakai-it]
feat: 品質チェックワークフローを追加 [a-sha-dwh]
```

#### 実行コマンド

```bash
git commit -m "{type}: {概要} [{org-slug}]"
```

### ステップ 3: リモートへプッシュ

```bash
git push origin {branch-name}
```

### ステップ 4: PR 作成

gh CLI で PR を作成します。以下のテンプレートを使用します:

```bash
gh pr create \
  --title "{type}: {概要} [{org-slug}]" \
  --body "$(cat <<'EOF'
## 組織情報

- **組織名**: {org_name}
- **組織ID**: {org-slug}

## 変更概要

{作業内容の説明を2〜3文で記述}

## 変更ファイル

{主要な変更ファイルを箇条書きで列挙}

## レビューポイント

- [ ] 成果物の内容が依頼と一致しているか
- [ ] ファイルパスが `.companies/{org-slug}/` 配下に収まっているか
- [ ] マスタへの変更がある場合、整合性が保たれているか
EOF
)"
```

### ステップ 5: ユーザーへの報告

PR 作成後、以下の形式でユーザーに報告します:

```
作業が完了しました。

ブランチ: {branch-name}
PR: {PR の URL}

{成果物の簡単なサマリー}

PR をレビューしてマージしてください。
```

### ステップ 6: main に戻る

```bash
git checkout main
```

---

## 5. Agent Teams 使用時の Git 操作手順

Agent Teams を使う場合、Git 操作の責任はチームリード（通常は secretary Subagent）が持ちます。

### チームリードの役割

1. **ブランチ作成**: 作業開始前にチームリードがブランチを作成する
2. **ブランチ名の通知**: 各テイメイトに「ブランチ `{branch-name}` 上で作業すること」を明示して指示する
3. **成果物の統合確認**: 全テイメイトの完了後、`.companies/{org-slug}/` 配下を確認する
4. **まとめてコミット**: 全成果物を 1 コミットにまとめる（または論理的に分割して複数コミット）
5. **PR 作成**: 本文に各テイメイトの作業内容を記述する

### テイメイトへの指示テンプレート

```
{agent-name}エージェントを使って、{依頼内容}を実行してください。
成果物は .companies/{org-slug}/docs/{dept}/{path} に保存してください。
ブランチ {branch-name} 上で作業していることを前提としてください。
git 操作（add/commit/push/PR）はチームリードが一括で行うため、
テイメイトは git 操作を実行しないでください。
```

### Agent Teams 用 PR 本文テンプレート

```
## 組織情報

- **組織名**: {org_name}
- **組織ID**: {org-slug}

## チーム編成

| テイメイト | 担当作業 |
|-----------|---------|
| {agent-name-1} | {作業内容} |
| {agent-name-2} | {作業内容} |

## 変更概要

{作業全体のサマリー}

## 変更ファイル

{主要な変更ファイルを箇条書きで列挙}

## レビューポイント

- [ ] 各テイメイトの成果物が整合しているか
- [ ] 成果物の内容が依頼と一致しているか
- [ ] ファイルパスが `.companies/{org-slug}/` 配下に収まっているか
```

---

## 6. エラーハンドリング

### push 失敗時

**原因: リモートブランチが既に存在する（別セッションで作成済み）**

```bash
git push --set-upstream origin {branch-name}
```

それでも失敗する場合はユーザーに報告し、手動対応を依頼します:
```
push に失敗しました。ローカルの変更は保存されています。
ブランチ名: {branch-name}
手動で git push を実行してください。
```

**原因: 認証エラー**

gh CLI の認証状態を確認するよう案内します:
```
git push に失敗しました（認証エラー）。
「gh auth status」で認証状態を確認してください。
```

### コンフリクト発生時

1. コンフリクトが発生したファイルを特定して報告
2. 自動解決は試みず、ユーザーに手動解決を依頼
3. コンフリクト解決後のコマンドを案内:

```bash
# コンフリクト解決後
git add .companies/{org-slug}/
git commit -m "fix: コンフリクトを解決 [{org-slug}]"
git push origin {branch-name}
```

### stash からの復元

作業前に stash した場合、main に戻った後に復元します:

```bash
git stash pop
```

---

## 7. マイグレーション手順（`.company/` → `.companies/{org-slug}/`）

既存の `.company/` ディレクトリを新しいマルチ組織構造に移行します。

### 前提確認

1. `.company/masters/organization.md` が存在するか確認
2. オーナー名・事業内容を読み取り、org-slug を推定する
   - 推定ルール: オーナー名や事業内容から英語キーワードを抽出し、kebab-case に変換
   - 例: オーナー「田中さん」事業「A社DWH」→ `a-sha-dwh`（ユーザーに確認必須）

### 移行手順

```bash
# 1. 移行用ブランチを作成
git checkout -b migration/company-to-companies

# 2. .companies/ ディレクトリを作成
mkdir -p .companies

# 3. .company/ を .companies/{org-slug}/ に移動
mv .company .companies/{org-slug}

# 4. .companies/.active を作成
echo "{org-slug}" > .companies/.active

# 5. 移行結果をコミット
git add .companies/ .companies/.active
git add -u .company/   # 削除を記録
git commit -m "chore: .company/ を .companies/{org-slug}/ に移行"

# 6. PR 作成
gh pr create \
  --title "chore: マルチ組織構造へのマイグレーション [{org-slug}]" \
  --body "既存の .company/ を .companies/{org-slug}/ に移行しました。"

# 7. main に戻る
git checkout main
```

### 移行後の確認チェックリスト

- [ ] `.companies/{org-slug}/masters/` 配下の全マスタファイルが存在する
- [ ] `.companies/.active` に正しい org-slug が書かれている
- [ ] `.company/` が削除されている（またはバックアップ済み）
- [ ] `/company` を実行して運営モードに入れることを確認
