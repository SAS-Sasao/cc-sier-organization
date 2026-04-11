# AWSコスト見積パターン

> Source: [awslabs/agent-plugins](https://github.com/awslabs/agent-plugins) deploy-on-aws (Apache-2.0)
> 用途: ダイアグラム生成後、アーキテクチャのコスト概算を自動付与する

---

## 見積フロー

1. ダイアグラムで使用されているAWSサービスを特定
2. 各サービスのコストを下表から参照（または `awspricing` MCP で取得）
3. Dev / Prod の月額概算を算出
4. 詳細ページの「コスト概算」セクションに記載

## Service Codes（awspricing MCP 用）

| Service | Code | Notes |
|---------|------|-------|
| Fargate | `AmazonECS` | Filter by `usagetype` containing "Fargate" |
| Aurora PostgreSQL | `AmazonRDS` | Filter: `databaseEngine` = "Aurora PostgreSQL" |
| Aurora MySQL | `AmazonRDS` | Filter: `databaseEngine` = "Aurora MySQL" |
| RDS PostgreSQL | `AmazonRDS` | Filter: `databaseEngine` = "PostgreSQL" |
| Amazon DocumentDB | `AmazonDocDB` | MongoDB-compatible managed database |
| ALB | `AWSELB` | Application Load Balancer |
| S3 | `AmazonS3` | Storage and requests |
| CloudFront | `AmazonCloudFront` | CDN distribution |
| Amplify | `AWSAmplify` | Hosting, build minutes |
| Lambda | `AWSLambda` | Requests and duration |
| DynamoDB | `AmazonDynamoDB` | On-demand or provisioned |
| Secrets Manager | `AWSSecretsManager` | Per secret per month |
| ElastiCache | `AmazonElastiCache` | Serverless or node-based |
| OpenSearch | `AmazonES` | Serverless or managed |
| Kinesis | `AmazonKinesis` | Data Streams / Firehose |
| SQS | `AWSQueueService` | Standard / FIFO |
| SNS | `AmazonSNS` | Pub/Sub messaging |
| Step Functions | `AWSStepFunctions` | Standard / Express |
| ECS (EC2 launch) | `AmazonECS` | EC2-backed containers |
| EKS | `AmazonEKS` | Kubernetes cluster ($0.10/hr) |
| Redshift Serverless | `AmazonRedshift` | RPU-hour based |
| Glue | `AWSGlue` | DPU-hour based |
| MSK Serverless | `AmazonMSK` | Cluster-hour + storage |

## 為替レート

コスト概算の日本円換算には以下のレートを使用する。レートは定期的に更新すること。

| 基準日 | USD/JPY |
|--------|---------|
| 2026-03-30 | 150 |

> **注意**: 実際の請求はUSD建て。日本円はあくまで参考値として表示する。
> レート更新時はこのファイルの値を変更し、既存の詳細ページは再生成不要（概算のため）。

## クイックリファレンス見積（ap-northeast-1 基準）

### Compute

| 構成 | Dev (月額) | Prod (月額) | 前提 |
|------|-----------|------------|------|
| Fargate (0.5 vCPU, 1GB) | ~$20 | — | 24/7稼働 |
| Fargate (1 vCPU, 2GB) | — | ~$40 | 24/7稼働 |
| Lambda | ~$0-5 | ~$5-50 | 100万〜1000万req/月 |
| Amplify Hosting | ~$0-5 | ~$15-40 | Free Tier適用 |

### Database

| 構成 | Dev (月額) | Prod (月額) | 前提 |
|------|-----------|------------|------|
| Aurora Serverless v2 (0.5-2 ACU) | ~$50-100 | — | 低負荷 |
| Aurora Serverless v2 (2-8 ACU) | — | ~$200-400 | 中負荷 |
| DynamoDB On-Demand | ~$5-20 | ~$20-100 | 100万read/write/月 |
| ElastiCache Serverless | ~$25-50 | ~$90+ | 最小ECPUベース |
| DocumentDB Serverless (0.5-2 DCU) | ~$35-120 | — | 10GB storage |
| DocumentDB Serverless (2-8 DCU) | — | ~$130-400 | 100GB, multi-AZ |
| Redshift Serverless | ~$50-200 | ~$200-800 | RPU利用時間依存 |

### Networking / CDN

| 構成 | Dev (月額) | Prod (月額) | 前提 |
|------|-----------|------------|------|
| ALB | ~$20 | ~$25-50 | LCU利用量依存 |
| CloudFront | ~$1-5 | ~$20-100 | 転送量依存 |
| NAT Gateway | ~$35 | ~$35-100 | 1 AZ + 転送量 |
| API Gateway (REST) | ~$3-10 | ~$10-50 | 100万〜1000万req/月 |

### Storage / Messaging

| 構成 | Dev (月額) | Prod (月額) | 前提 |
|------|-----------|------------|------|
| S3 (100GB) | ~$2-3 | ~$2-5 | Standard class |
| SQS | ~$0-1 | ~$1-10 | 100万msg/月 |
| SNS | ~$0-1 | ~$1-5 | 100万pub/月 |
| Secrets Manager | ~$0.40/secret | 同左 | — |

### Analytics / Data

| 構成 | Dev (月額) | Prod (月額) | 前提 |
|------|-----------|------------|------|
| Glue (ETL) | ~$5-50 | ~$50-500 | DPU利用時間依存 |
| Kinesis Data Streams (1 shard) | ~$15 | ~$15-75 | シャード数依存 |
| MSK Serverless | ~$50-150 | ~$150-500 | クラスタ時間+ストレージ |

## 構成パターン別の概算

| パターン | Dev (月額) | Prod (月額) |
|---------|-----------|------------|
| Web App (Fargate + Aurora + ALB) | ~$90-120 | ~$265-490 |
| Web App (Fargate + DocumentDB + ALB) | ~$75-175 | ~$195-490 |
| Serverless API (Lambda + APIGW + DynamoDB) | ~$8-35 | ~$35-200 |
| Static Site (S3 + CloudFront) | ~$3-10 | ~$25-55 |
| Static Site (Amplify) | ~$0-5 | ~$15-40 |
| Data Pipeline (Glue + S3 + Redshift) | ~$55-255 | ~$255-1,305 |
| Event-Driven (Lambda + SQS + DynamoDB) | ~$5-25 | ~$25-160 |
| Streaming (Kinesis + Lambda + S3) | ~$20-70 | ~$20-180 |

## 表示フォーマット

詳細ページの「コスト概算」セクションに以下を記載する。
USD と JPY の両方を表示すること（JPY は本ファイル「為替レート」セクションのレートで換算）。

```html
<div class="section">
  <h2>コスト概算</h2>
  <p class="cost-note">ap-northeast-1 (東京) リージョン基準の月額概算。実際の費用は利用量により変動します。<br>
  為替レート: $1 = {RATE}円（参考値）</p>
  <table>
    <thead>
      <tr><th>サービス</th><th>構成</th><th>Dev (月額)</th><th>Prod (月額)</th></tr>
    </thead>
    <tbody>
      <tr><td>{サービス名}</td><td>{構成詳細}</td><td>${Dev_USD} ({Dev_JPY}円)</td><td>${Prod_USD} ({Prod_JPY}円)</td></tr>
      ...
    </tbody>
    <tfoot>
      <tr><th colspan="2">合計</th><th>${Dev合計} (約{Dev合計_JPY}円)</th><th>${Prod合計} (約{Prod合計_JPY}円)</th></tr>
    </tfoot>
  </table>
  <p><strong>前提条件</strong>: {24/7稼働、転送量想定 等}</p>
  <p><strong>コスト最適化のポイント</strong>: {Savings Plans、Reserved Instances、スケジュール停止 等}</p>
</div>
```

### レンジ表示の場合

コストがレンジ（$70-100）の場合は以下の形式:

```
$70-100 (約10,500-15,000円)
```

小数点以下は切り捨て。千円未満はカンマ区切りで表示。
