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
