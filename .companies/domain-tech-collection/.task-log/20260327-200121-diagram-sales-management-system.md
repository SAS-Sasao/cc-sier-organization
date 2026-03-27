---
task_id: "20260327-200121-diagram-sales-management-system"
org: "domain-tech-collection"
operator: "SAS-Sasao"
status: completed
mode: direct
subagent: "company-diagram"
started: "2026-03-27T20:01:21+09:00"
completed: "2026-03-27T20:02:00+09:00"
request: "毎月のAWS費用20万程度のアプリケーション運用を行うための構成図を考えてほしい。アプリケーションは販売管理システムで利用者数50～70人程。CI/CDはgithub actionsを使用する想定"
issue_number: null
pr_number: null
---

## 実行計画

- 描画対象: 月額約20万円・50-70名向け販売管理システムのコスト最適化AWS構成
- 使用AWSサービス: Route53, CloudFront, WAF, S3, ALB, ECS Fargate, Aurora Serverless v2, Cognito, ECR, NAT Gateway, Secrets Manager, CloudWatch, SNS
- CI/CD: GitHub Actions → ECR → ECS（AWS外CI/CDでコスト削減）
- ツール: AWS Diagram MCP Server（awslabs.aws-diagram-mcp-server）

## 成果物

| ファイル | 説明 |
|---------|------|
| `docs/diagrams/sales-management-system.png` | 構成図PNG |
| `docs/diagrams/sales-management-system.html` | 詳細ページ（概要・データフロー・レイヤー構成・コスト概算・設計ポイント） |
| `docs/diagrams/index.html` | 一覧ページ更新（カード追加、6件に更新） |

## 実行ログ

1. MCP Server で list_icons（network, security, devtools）を取得
2. generate_diagram で Sales Management System on AWS を生成（1回で成功）
3. PNG を docs/diagrams/ にコピー
4. 詳細HTML（sales-management-system.html）を新規作成（月額コスト概算テーブル付き）
5. 一覧HTML（index.html）にカード追記、件数更新

## judge

### 評価基準

| 軸 | スコア | 評価 |
|----|--------|------|
| Completeness | 5/5 | PNG構成図・詳細HTML（概要/4種データフロー/レイヤー構成/月額コスト概算/設計ポイント）・一覧HTML更新の全成果物を生成。Edge→CDN→App→DB→Monitoring + Auth + CI/CDの全レイヤーを網羅。月額コスト概算テーブルを追加し実務的価値を向上 |
| Accuracy | 5/5 | 50-70名規模に適したサービス選定（ECS Fargate 2タスク、Aurora Serverless v2 0.5-2 ACU、Cognito無料枠内）。月額$173-223（約2.6-3.3万円）の概算は20万円予算に対して妥当。GitHub Actions→ECR→ECSのCI/CDフローも正確 |
| Clarity | 5/5 | 構成図はVPC内のPublic/Private Subnet分離を表現。HTMLは4種のフロー図（User/API/CI-CD/Auth）で理解しやすい。コスト概算テーブルがサービス別で予算検討に直結 |

### 総合スコア: 5.0/5.0

### reward: 0.95

### 備考
- コスト概算テーブルを追加し、「月額20万円」の要件に対する具体的な数値回答を提供
- graph_attrを使わない学習を継続適用し1回で生成成功
