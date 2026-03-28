---
task_id: "20260328-160000-diagram-serverless-web-app"
org: "domain-tech-collection"
operator: "SAS-Sasao"
status: completed
mode: direct
started: "2026-03-28T16:00:00+09:00"
completed: "2026-03-28T16:15:00+09:00"
request: "未生成分野のダイアグラムでおすすめの領域を見繕って対応してほしい"
issue_number: null
pr_number: null
---

## 実行計画

- 描画対象: サーバーレスWebアプリケーション構成
- 使用AWSサービス: CloudFront, S3, API Gateway, Lambda, DynamoDB, Cognito, SQS, SNS, CloudWatch
- MCP Server: awslabs.aws-diagram-mcp-server
- 既存7構成図を分析し、未カバーの「サーバーレス」領域を選定

## 成果物

- [x] docs/diagrams/serverless-web-app.png
- [x] docs/diagrams/serverless-web-app.html
- [x] docs/diagrams/index.html（カード追加・件数8件に更新）

## judge
```yaml
completeness: 9
accuracy: 8
clarity: 9
total: 0.87
failure_reason: ""
judge_comment: "CloudFront/APIGateway/Lambda/DynamoDB/Cognito/SQS/SNS/EventBridge/StepFunctions/CloudWatch等の主要サーバーレスサービスを網羅。データフロー4パターン（同期API・静的配信・非同期・イベント駆動）をHTMLで詳細解説。LR方向指定だが複雑さにより一部レイアウトが非線形になった点のみ軽微な減点。"
judged_at: "2026-03-28T16:15:00+09:00"
```
