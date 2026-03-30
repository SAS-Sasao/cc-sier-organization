# ワークフロー一覧

## wf-daily-digest

- **名称**: 日次ニュース巡回・ダイジェスト生成
- **トリガー**: 「ニュース収集」「巡回」「daily digest」「今日のニュース」「情報収集」
- **実行方式**: agent-teams
- **チーム構成**:
  - team-lead: secretary（統合・ダイジェスト生成）
  - teammate: tech-researcher（技術スタック系ソースの巡回）**subagent_type: general-purpose**
  - teammate: retail-domain-researcher（小売ドメイン系ソースの巡回）**subagent_type: general-purpose**
- **WebFetch注意**: 両teammateはWebFetchが必要なため、Agent起動時に `subagent_type: "general-purpose"` を指定すること。専用型（tech-researcher / retail-domain-researcher）はWebFetchツールを持たない。
- **入力**: `.companies/domain-tech-collection/docs/info-source-master.md`
- **ステップ**:
  1. `info-source-master.md` の優先度「高」ソースを中心に WebFetch で巡回
  2. 各テイメイトがカテゴリ別に記事タイトル・要約・**ソース元URL** を収集
  3. チームリード（秘書）がカテゴリ別に統合ダイジェストを生成
  4. **品質ゲート `by-type/daily-digest.md` を実行し、全項目パスを確認**
- **成果物**:
  - `.companies/domain-tech-collection/docs/daily-digest/YYYY-MM-DD.md`
- **品質ゲート**: `masters/quality-gates/by-type/daily-digest.md`（severity: error）
- **フォーマット**: 品質ゲートの「フォーマットテンプレート」セクションに従うこと（A章=技術テーマ別, B章=小売テーマ別, 記事はテーブル形式, C章はパラグラフ形式）
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

## wf-storcon-research

- **名称**: ストアコンピューター調査・知識収集（高報酬パターンから自動生成）
- **トリガー**: 「ストアコンピューター」「ストコン」「コンビニ」「store computer」「POS」
- **実行方式**: subagent
- **ロール**: retail-domain-researcher（最頻使用Subagent）
- **ステップ**:
  1. ストアコンピューター関連のドメイン知識を調査
  2. 最新トレンド・業界動向を収集
  3. 調査結果をドキュメント化して成果物ディレクトリに保存
- **成果物**:
  - `.companies/domain-tech-collection/docs/retail-domain/`
  - `.companies/domain-tech-collection/docs/retail-domain/industry-reports/`
- **Git運用**: ブランチ＋PR
- **Issue作成**: あり
- **平均報酬**: 1.00
- **検出日**: 2026-03-23

## wf-drawio-architecture

- **名称**: draw.ioアーキテクチャ図生成（高報酬パターンから自動生成）
- **トリガー**: 「draw.io」「C4モデル」「業務フロー」「ER図」「フローチャート」「シーケンス図」「データアーキテクチャ」「MDM」
- **実行方式**: direct
- **ロール**: secretary（/company-drawio Skill直接実行）
- **ステップ**:
  1. 依頼内容からダイアグラム種別を判定（C4/フロー/ER/アーキテクチャ）
  2. 関連ドメイン知識ドキュメントを参照（docs/retail-domain/ 等）
  3. /company-drawio Skill でダイアグラム生成（XML形式推奨）
  4. エッジ貫通レビュースクリプトで品質チェック
  5. ギャラリーページ・メタデータ更新
- **成果物**:
  - `.companies/domain-tech-collection/docs/drawio/`
  - `docs/drawio/*.drawio` / `docs/drawio/*.html`
- **品質チェック**: `review-drawio.js` によるエッジ貫通検出
- **Git運用**: ブランチ＋PR
- **Issue作成**: あり
- **平均報酬**: 0.92
- **検出日**: 2026-03-29
