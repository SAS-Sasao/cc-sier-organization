---
task_id: "20260328-231620-diagram-ai-dev-knowledge-platform"
org: "domain-tech-collection"
operator: "SAS-Sasao"
status: completed
mode: direct
started: "2026-03-28T23:16:20+09:00"
completed: "2026-03-28T23:20:00+09:00"
request: "AWSベッドロックを使用し、ドメイン知識や開発ナレッジ、社内のメンバー情報などのナレッジを溜め、それを利用してAI駆動開発の精度と効率を底上げするようなアーキテクチャを書いてほしい"
subagent: "secretary"
issue_number: null
pr_number: null
reward: 0.90
---

## 実行計画

- 描画対象: AI駆動開発ナレッジプラットフォーム（Bedrock RAG）
- 使用AWSサービス: Bedrock, OpenSearch Serverless, S3, Lambda, Step Functions, EventBridge, API Gateway, CloudFront, WAF, Cognito, DynamoDB, CloudWatch
- MCP Server: awslabs.aws-diagram-mcp-server, aws-knowledge-mcp-server

## architecture-review (attempt 1/3)

| # | 観点 | 判定 | 指摘事項 |
|---|------|------|---------|
| 1 | サービス互換性 | Pass | Bedrock ↔ OpenSearch Serverless はネイティブ統合。全接続パターンが標準 |
| 2 | データフロー整合性 | Pass | 取り込みフローとクエリフローが明確に分離。循環参照なし |
| 3 | セキュリティ | Pass | WAF + CloudFront + Cognito の多層防御 |
| 4 | 可用性・耐障害性 | Pass | 全サービスがサーバーレス/マネージド。SPOF なし |
| 5 | コスト効率 | Pass | 全て従量課金。不要な重複なし |
| 6 | ユーザー要望との一致 | Pass | ドメイン知識・開発ナレッジ・メンバー情報の3種を個別管理、Bedrock RAGで統合 |

総合判定: Pass (6/6)

## 成果物

- `docs/diagrams/ai-dev-knowledge-platform.png` — 構成図PNG
- `docs/diagrams/ai-dev-knowledge-platform.html` — 詳細ページ（凡例付き）
- `docs/diagrams/ai-dev-knowledge-platform.yaml` — CloudFormation テンプレート
- `docs/diagrams/ai-dev-knowledge-platform-iac.html` — IaCビューア
- `docs/diagrams/index.html` — 一覧ページ更新
- `.companies/domain-tech-collection/docs/diagrams/ai-dev-knowledge-platform.md` — ソースコード

## judge

| 軸 | スコア | 根拠 |
|---|---|---|
| completeness | 9/10 | 3種のナレッジを個別管理、取り込み・クエリ・定期同期の全フローをカバー。IaCも生成済み |
| accuracy | 9/10 | AWS Knowledge MCP 6軸レビュー Pass。Bedrock+OpenSearch Serverlessのネイティブ統合を採用 |
| clarity | 9/10 | 凡例・データフロー・レイヤー構成・活用シーン・設計ポイントの5セクションで構造化 |

total: 0.90

## iac-validation

- cfn-lint: 初回3エラー（Lambda Role未定義）→ IAM Role追加で修正
- IaCビューア: generate-iac-viewer.py で生成完了
