# ワークフロー一覧

## wf-daily-digest

- **名称**: 日次ニュース巡回・ダイジェスト生成
- **トリガー**: 「ニュース収集」「巡回」「daily digest」「今日のニュース」「情報収集」
- **実行方式**: agent-teams
- **チーム構成**:
  - team-lead: secretary（統合・ダイジェスト生成）
  - teammate: tech-researcher（技術スタック系ソースの巡回）
  - teammate: retail-domain-researcher（小売ドメイン系ソースの巡回）
- **入力**: `.companies/domain-tech-collection/docs/info-source-master.md`
- **ステップ**:
  1. `info-source-master.md` の優先度「高」ソースを中心に WebFetch で巡回
  2. 各テイメイトがカテゴリ別に記事タイトル・要約を収集
  3. チームリード（秘書）がカテゴリ別に統合ダイジェストを生成
- **成果物**:
  - `.companies/domain-tech-collection/docs/daily-digest/YYYY-MM-DD.md`
- **Git運用**: ブランチ＋PR
- **Issue作成**: あり（ラベル: `org:domain-tech-collection`, `type:daily-digest`）
- **スケジュール**: Cron 毎日 10:00

## wf-source-master-refresh

- **名称**: 情報ソースマスタ月次更新
- **トリガー**: 「マスタ更新」「ソース見直し」「source refresh」
- **実行方式**: agent-teams
- **チーム構成**:
  - team-lead: secretary（統合・判断）
  - teammate: tech-researcher（技術系ソースの有効性確認・新規候補調査）
  - teammate: retail-domain-researcher（小売系ソースの有効性確認・新規候補調査）
- **入力**: `.companies/domain-tech-collection/docs/info-source-master.md`
- **ステップ**:
  1. 既存ソースのURL有効性を確認
  2. 新規有力ソース候補を調査
  3. 優先度の見直し（直近の情報価値に基づく）
  4. `info-source-master.md` を更新
- **成果物**:
  - `.companies/domain-tech-collection/docs/info-source-master.md`（更新）
- **Git運用**: ブランチ＋PR
- **Issue作成**: あり
- **スケジュール**: 毎月1日に手動実行推奨
