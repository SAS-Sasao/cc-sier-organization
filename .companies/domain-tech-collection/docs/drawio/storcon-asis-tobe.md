---
title: ストコン移行 As-Is / To-Be 対比図
type: C4 Model
project: ストコン移行
tool: open_drawio_xml
created: 2026-04-04
---

# ストコン移行 As-Is / To-Be 対比図

コンビニエンスストアのストアコンピューターをオンプレミスからAWSクラウドへ移行する際の、現行構成（As-Is）と移行後構成（To-Be）を左右対比で可視化。中央に3フェーズの移行ステップ（Rehost → Replatform → Refactor）と主要コンポーネントの対応マッピングを示す。

## 主要構成要素

| カテゴリ | As-Is（オンプレ） | To-Be（AWS） |
|---------|------------------|-------------|
| アプリケーション | EOS/EOB発注管理（モノリス） | ECS/Fargate マイクロサービス（発注/在庫/売上/従業員） |
| データベース | Oracle / SQL Server | Aurora + DynamoDB + ElastiCache + Redshift |
| バッチ処理 | バッチサーバー（日次精算/棚卸） | Step Functions + AWS Batch |
| DWH | オンプレDWH | Redshift |
| ネットワーク | 専用回線 / VPN | Direct Connect + VPC (Multi-AZ) |
| エッジ/セキュリティ | なし（閉域網で保護） | CloudFront + WAF + Cognito + Route 53 |
| 監視 | なし（個別ツール） | CloudWatch + X-Ray |
| 店舗端末 | 専用HW ストコン + ローカルDB | クラウド接続型ストコン + ローカルDB（オフライン耐性） + IoT Core |

## 移行マッピング

| # | As-Is | To-Be | 手法 |
|---|-------|-------|------|
| 1 | Oracle/SQL Server | Aurora | DMS + SCT |
| 2 | EOS/EOB発注管理 | 発注サービス (ECS) | ストラングラーフィグ + コンテナ化 |
| 3 | DWH | Redshift | S3バルクロード + CDC |

## 設計の特徴

- 3フェーズ段階移行（Rehost → Replatform → Refactor）でリスク最小化
- オフライン耐性のローカルDB維持（差分同期で整合）
- データ層の用途別最適化（ACID / NoSQL / Cache / DWH）
- 温度監視のIoT Core移行（HACCP対応クラウド化）

## 関連

- 店舗内システム構成: [storcon-instore-system](storcon-instore-system.md)
- UMLコンポーネント図: [storcon-uml-component](storcon-uml-component.md)
- AWS構成図: [storcon-app-architecture](../diagrams/storcon-app-architecture.md)
