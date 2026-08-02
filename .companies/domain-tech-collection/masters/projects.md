# プロジェクト一覧

## proj-ai-virtual-office

- **名称**: AI Virtual Office — Claude Code のエージェント活動を CC-SIer 仮想組織のピクセルオフィスとして可視化する Web アプリ
- **ステータス**: active
- **実装リポジトリ**: https://github.com/SAS-Sasao/ai-virtual-office（public）
- **スポーン日**: 2026-07-18
- **スポーン作業者**: SAS-Sasao
- **スポーン元コミット**: 646a417adc87c4adcdbca9bc6c7b054c60fe3916
- **コピーした成果物**: [docs/research/ai-virtual-office-requirements.md → docs/design/requirements.md, docs/research/ai-virtual-office-design.md → docs/design/architecture-design.md, docs/diagrams/ai-virtual-office-aws.drawio → docs/design/aws-architecture.drawio, docs/diagrams/ai-virtual-office-aws.yaml → docs/design/aws-architecture.cfn.yaml]（元ファイルは本リポジトリに温存）
- **コピーしたSubagent**: [game-engine-dev, pipeline-dev, ui-dev, org-adapter-dev]（要件定義 §5.4 準拠の新規生成）
- **技術スタック**: TypeScript / Next.js 15 / pnpm monorepo（apps/web + packages/{protocol, relay, cc-sier-adapter}）
- **次のマイルストーン**: M0 PoC（hooks → ingest → SSE → 最小描画）

## proj-retail-stats-tracker

- **名称**: 小売月次統計トラッカー — 日次ダイジェストの決算・統計章を時系列データ化する静的トレンド可視化サイト
- **ステータス**: active
- **実装リポジトリ**: https://github.com/SAS-Sasao/retail-stats-tracker （private）
- **スポーン日**: 2026-08-02
- **スポーン作業者**: SAS-Sasao
- **スポーン元コミット**: 2da1c48
- **関連 PR / Issue**: PR #710（設計3冊のマージ）/ Issue #711（実装フェーズの判断事項）
- **コピーした成果物**: [docs/research/retail-stats-tracker-requirements.md → docs/design/requirements.md, docs/research/retail-stats-tracker-design.md → docs/design/implementation-design.md, docs/research/retail-stats-tracker-loop-engineering-design.md → docs/design/loop-engineering-design.md, docs/research/retail-stats-tracker-cicd-design.md → docs/design/cicd-design.md, docs/retail-domain/retail-monthly-kpi-catalog.md → docs/design/retail-monthly-kpi-catalog.md]（元ファイルは本リポジトリに温存。**設計原本は cc-sier 側**）
- **コピーしたSubagent**: [system-architect, ai-developer, ci-cd-engineer, retail-domain-researcher]（既存）+ [retail-stats-qa, retail-stats-extractor]（ループ設計 §4.1 準拠の新規生成）
- **技術スタック**: Python（標準ライブラリのみ / unittest）。外部依存を増やさない方針
- **設計レビュー**: L1 pass / L2 composite 0.88 pass（3巡: 0.69 → 0.84 → 0.88）
- **次のマイルストーン**: M1（パッケージ骨格 + カタログローダ）
- **実装前の未決事項**: NFR-05 未達（64/83 = 77.1%、目標 80%）/ U10 複数主体併記 30 件で衝突検出が 0 件しか発火しない
