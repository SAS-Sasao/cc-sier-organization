---
title: StoreComputer Migration - UML Component Diagram
type: UML Component
project: ストコン移行
wbs: "3.1.1"
tool: open_drawio_xml
created: 2026-04-01
---

# StoreComputer Migration - UML Component Diagram

AWS版構成図（storcon-vpc-architecture）をクラウドベンダー非依存のUMLコンポーネント図として再設計。

## 対応関係

| UML (本図) | AWS版 |
|-----------|-------|
| RDBMS (Auto-Scaling) | Aurora Serverless v2 |
| Key-Value Store | DynamoDB |
| In-Memory Cache | ElastiCache Redis |
| Object Storage | S3 |
| Store API Server | Fargate |
| Batch Processor | Fargate |
| Async Processor | Lambda |
| Load Balancer | ALB |
| CDN | CloudFront |
| WAF | AWS WAF |
| Dedicated Line | Direct Connect |
| NAT | NAT Gateway |
| DNS | Route 53 |
| Monitoring | CloudWatch |

## 関連

- AWS版構成図: [storcon-vpc-architecture](../../../docs/diagrams/storcon-vpc-architecture.html)
- IaCソースコード: [storcon-vpc-architecture-iac](../../../docs/diagrams/storcon-vpc-architecture-iac.html)
