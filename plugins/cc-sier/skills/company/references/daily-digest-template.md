# 日次ダイジェスト テンプレート

## 出力ファイルパス

```
.companies/{org-slug}/docs/daily-digest/YYYY-MM-DD.md
```

## ダイジェスト生成フォーマット

```markdown
# Daily Digest — {YYYY-MM-DD}

> 情報ソースマスタに基づく日次巡回レポート

---

## A. 小売ドメイン

### A1. 業界ニュース
- **[記事タイトル](URL)** — 要約（1〜2文）
- **[記事タイトル](URL)** — 要約（1〜2文）

### A2. EC・オムニチャネル
- ...

### A3. 物流・SCM
- ...

（該当カテゴリのみ記載。記事がないカテゴリは省略）

---

## B. 技術スタック

### B1. クラウド・インフラ
- **[記事タイトル](URL)** — 要約（1〜2文）

### B2. データ基盤・DWH
- ...

### B3. AI/ML
- ...

### B4. アーキテクチャ・設計
- ...

### B5. 国内テックブログ
- ...

（該当カテゴリのみ記載。記事がないカテゴリは省略）

---

## 注目トピック

特に重要度が高い記事やトレンドがあれば、1〜3件をピックアップして背景・影響を補足。

---

_巡回対象: info-source-master.md 優先度「高」+ 一部「中」_
_生成: {YYYY-MM-DD} {HH:MM}_
```

## 巡回ルール

### 対象ソースの選定

1. `info-source-master.md` セクションC「日次収集の優先度ガイド」を参照
2. 優先度「高」は必ず巡回
3. 優先度「中」は時間に余裕があれば巡回（週次チェック推奨のため、曜日ローテーションも可）
4. 優先度「低」はスキップ（月次・年次レポートは発行時のみ）

### WebFetch の実行

1. 各ソースのトップページまたはRSSフィードURLを WebFetch
2. 当日または直近の新着記事を抽出
3. 記事タイトル・URL・概要をカテゴリ別に整理

### 品質基準

- 記事は当日〜直近2日以内のものを優先
- 1カテゴリあたり最大5件程度に絞る（情報過多を防ぐ）
- 重複排除（同一トピックを複数ソースで報じている場合は代表1件にまとめる）
- 記事がないカテゴリは「該当なし」ではなく、セクション自体を省略

## Git運用（main直接コミット）

```bash
# 1. mainブランチであることを確認
git checkout main

# 2. ダイジェストファイルを追加
git add .companies/{org-slug}/docs/daily-digest/YYYY-MM-DD.md

# 3. コミット
git commit -m "docs: daily digest YYYY-MM-DD [{org-slug}] by {operator}"

# 4. プッシュ
git push origin main
```

## Issue 作成

```bash
gh issue create \
  --title "Daily Digest: YYYY-MM-DD" \
  --label "org:{org-slug},type:daily-digest" \
  --body "## Daily Digest — YYYY-MM-DD

### サマリー
- 小売ドメイン: {N}件
- 技術スタック: {M}件

### 注目トピック
{注目トピックの概要}

### ファイル
[daily-digest/YYYY-MM-DD.md](https://github.com/SAS-Sasao/cc-sier-organization/blob/main/.companies/{org-slug}/docs/daily-digest/YYYY-MM-DD.md)
"
```
