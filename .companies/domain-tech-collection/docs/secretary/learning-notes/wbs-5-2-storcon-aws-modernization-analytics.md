# ストコンAWS移行 モダナイゼーション＆データ分析 技術調査レポート

- **調査目的**: ストコンAWS移行のLift後Shiftフェーズ＆データ分析基盤に必要なAWSサービス知識の収集
- **作成日**: 2026-03-26
- **作成者**: tech-researcher
- **補完対象**: [storcon-aws-tech-deep-dive-2026-03-25.md](../../retail-domain/industry-reports/storcon-aws-tech-deep-dive-2026-03-25.md)（DMS/MGN/Outposts/IoT/DirectConnect/TransitGateway/MAP/Landing Zone等カバー済み）
- **業務シナリオ**: [storcon-modernization-business-scenarios-2026-03-26.md](../../retail-domain/industry-reports/storcon-modernization-business-scenarios-2026-03-26.md)（小売ドメイン室作成）

---

## 目次

1. [モダナイゼーション領域](#1-モダナイゼーション領域)
   - 1-1. [コンテナサービス（ECS / Fargate / EKS）](#1-1-コンテナサービスecs--fargate--eks)
   - 1-2. [サーバーレスコンピューティング（Lambda / Step Functions / EventBridge）](#1-2-サーバーレスコンピューティングlambda--step-functions--eventbridge)
   - 1-3. [モダナイゼーション戦略パターン](#1-3-モダナイゼーション戦略パターン)
2. [データ分析領域](#2-データ分析領域)
   - 2-1. [データレイク / データウェアハウス（Redshift / S3 / Athena / Lake Formation）](#2-1-データレイク--データウェアハウス)
   - 2-2. [ETL / データ統合（Glue / Firehose / Zero-ETL）](#2-2-etl--データ統合)
   - 2-3. [リアルタイム分析（Kinesis / Flink / OpenSearch）](#2-3-リアルタイム分析)
   - 2-4. [BI / 可視化 / AI・ML（QuickSight / SageMaker / Bedrock）](#2-4-bi--可視化--aiml)
3. [サービス選定ガイド](#3-ストコン移行におけるサービス選定ガイド)
4. [学習ロードマップ](#4-学習ロードマップ)
5. [参考リソース一覧](#5-参考リソース一覧)

---

## 1. モダナイゼーション領域

Lift&Shift（MGNでの移行）完了後、クラウドネイティブ化を進める「Shift」フェーズで必要なサービス群。

### 1-1. コンテナサービス（ECS / Fargate / EKS）

#### Amazon ECS（Elastic Container Service）

**公式**: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/

AWS独自のコンテナオーケストレーションサービス。Kubernetes不要でコンテナワークロードを管理。

| 項目 | 詳細 |
|------|------|
| 起動タイプ | EC2 / Fargate / ECS Managed Instances |
| 東京リージョン | 利用可能 |
| 課金 | EC2: インスタンス課金 / Fargate: vCPU+メモリの秒単位課金 |

**ストコンでの活用シナリオ**:
- **本部アプリサーバー群のコンテナ化**: MGNで移行したEC2上のアプリケーションを段階的にDockerコンテナ化し、ECSで管理。発注処理・在庫管理・売上集計等の各サービスを個別タスク定義として運用
- **バッチ処理のコンテナ化**: 日次精算・月次集計等のバッチジョブをECSタスクとして実行。スケジュール実行はEventBridge Schedulerと連携
- **Blue/Greenデプロイ**: 本部アプリの無停止更新。CodeDeployと連携してトラフィック切替

**ECS Express Mode（App Runner後継）**:
- AWS App Runnerは2026年4月1日から新規顧客の受付を停止。既存顧客は継続利用可能
- 後継として **ECS Express Mode** が提供。App Runnerと同等のシンプルさでECSの高度な機能にアクセス可能
- ストコン案件ではApp Runnerではなく **ECS Express Mode** を採用すべき
- 参考: https://aws.amazon.com/blogs/containers/migrating-from-aws-app-runner-to-amazon-ecs-express-mode/

**PMとして知っておくべきポイント**:
- ECS Managed Instancesは複数タスクが同一インスタンスで稼働するため、セキュリティモデルがFargateと異なる。PCI DSS関連の処理は **Fargate での分離** を推奨
- タスク定義のCPU/メモリ設定は全店舗のピーク時（昼食時の発注集中等）を考慮して設定

#### AWS Fargate

**公式**: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/AWS_Fargate.html

サーバーレスコンテナ実行環境。EC2インスタンスの管理が不要。

**ストコンでの活用シナリオ**:
- **スパイク処理**: 全店一斉発注時のバースト対応。Fargateの自動スケーリングで数万店舗からの同時リクエストを処理
- **セキュリティ分離**: 決済関連のコンテナをFargateで実行し、タスクレベルでの分離を実現
- **コスト最適化**: 常時稼働の本部サーバーはEC2起動タイプ、スパイク対応部分はFargateのハイブリッド構成

**Fargate vs EC2 選択基準（ストコン向け）**:

| 観点 | Fargate推奨 | EC2推奨 |
|------|-----------|---------|
| ワークロード | スパイク型、バッチ | 常時稼働、GPUが必要 |
| 管理負荷 | OS/パッチ管理不要 | カスタマイズが必要な場合 |
| コスト | 短時間・変動負荷 | 長時間稼働（RI/Savings Plan適用） |
| セキュリティ | タスク分離が必要 | 共有インスタンスで十分 |

#### Amazon EKS（Elastic Kubernetes Service）

**公式**: https://docs.aws.amazon.com/eks/latest/userguide/

マネージドKubernetesサービス。OSSエコシステムとの互換性が高い。

**ストコンでの活用シナリオ**:
- **ハイブリッドクラウド**: EKS Anywhereを使って店舗側エッジとクラウド側の統一管理（ただしOutposts/Local Zonesとの比較検討が必要）
- **マイクロサービスメッシュ**: AWS App Meshとの連携でサービス間通信の可観測性・トラフィック制御を実現

**ECS vs EKS 選択基準**:

| 観点 | ECS推奨 | EKS推奨 |
|------|---------|---------|
| チームスキル | AWSネイティブ志向 | K8s経験者がいる |
| エコシステム | AWSサービス統合優先 | CNCF/OSSツール活用 |
| マルチクラウド | 不要 | 将来的に検討 |
| 運用負荷 | 低（AWSマネージド） | 中〜高（K8s知識必要） |
| ハイブリッド | ECS Anywhere | EKS Anywhere |

**PM判断のポイント**:
- ストコン移行チームにKubernetes経験者が豊富にいるかどうかが最大の判断基準
- 新規採用であれば **ECS + Fargate** がラーニングカーブと運用負荷の両面で有利
- 既存のK8s資産やCI/CDパイプラインがある場合は **EKS** を選択
- 参考: https://docs.aws.amazon.com/decision-guides/latest/modern-apps-strategy-on-aws-how-to-choose/modern-apps-strategy-on-aws-how-to-choose.html

---

### 1-2. サーバーレスコンピューティング（Lambda / Step Functions / EventBridge）

#### AWS Lambda

**公式**: https://docs.aws.amazon.com/lambda/latest/dg/

イベント駆動のサーバーレスコンピュート。リクエスト単位課金。

| 項目 | 詳細 |
|------|------|
| 最大実行時間 | 15分 |
| メモリ | 128MB〜10,240MB |
| コンテナイメージ | 最大10GB |
| 同時実行数 | デフォルト1,000（引き上げ可能） |
| 東京リージョン | 利用可能 |

**ストコンでの活用シナリオ**:

1. **在庫アラート処理**: 在庫データがDynamoDBに書き込まれた際、DynamoDB StreamsからLambdaを起動し閾値判定→SNSで店舗通知
2. **POS取引データのリアルタイム変換**: Kinesis Data Streamsからの売上データを受け取り、フォーマット変換してS3/Redshiftへ投入
3. **マスタデータ配信**: 商品マスタ更新時にLambdaが全店舗向けのキャッシュ（ElastiCache）を更新
4. **廃棄予測通知**: 消費期限管理データの日次チェックをEventBridge Schedulerで起動
5. **画像処理**: 店舗カメラの棚画像をRekognitionで品切れ検知（将来的）

**注意事項**:
- 15分制限があるため、全国集計バッチ等の長時間処理には不適。Step Functionsと組み合わせて分割するか、ECSタスクを使用
- コールドスタートのレイテンシ（数百ms〜数秒）が発注リアルタイム処理のSLAに影響しないか確認が必要
- Provisioned Concurrencyでコールドスタートを回避可能（追加コスト）
- 全国数万店舗の同時イベントでは同時実行数の上限引き上げ申請が必須

#### AWS Step Functions

**公式**: https://docs.aws.amazon.com/step-functions/latest/dg/

ワークフローオーケストレーションサービス。Lambda等のAWSサービスを視覚的に連携。

| ワークフロータイプ | 特徴 | ストコン適用 |
|------------------|------|------------|
| Standard | 長時間実行（最大1年）、実行履歴あり、監査向き | 発注→在庫引当→配送指示の一連フロー |
| Express | 高スループット（秒あたり10万以上）、短時間 | POS取引の即座処理 |

**ストコンでの活用シナリオ**:

1. **発注ワークフロー**:
```
[推奨発注量計算（Lambda）]
  → [在庫引当チェック（Lambda）]
  → [Choice: 在庫あり / なし]
    → [発注データ生成（Lambda）]
    → [本部送信（Lambda → SQS）]
    → [発注完了通知（SNS）]
```

2. **日次精算ワークフロー**:
```
[POS締め処理（Lambda）]
  → [Parallel]
    → [売上集計（Lambda）]
    → [入金突合（Lambda）]
    → [在庫差異チェック（Lambda）]
  → [精算レポート生成（Lambda）]
  → [本部送信（Lambda）]
```

3. **マスタ配信ワークフロー**:
```
[マスタ変更検知]
  → [Distributed Map: 全店舗に配信]
    → [各店舗のキャッシュ更新（Lambda）]
  → [配信結果集計]
  → [未達店舗リトライ]
```

**PMとして知っておくべきポイント**:
- Standardワークフローは**1状態遷移ごとに課金**。ループが多いとコスト増大
- Express ワークフローはログベース課金で高頻度処理に向く
- Distributed Map Stateで大規模並列処理（全店舗への一斉処理等）が可能
- エラーハンドリング（自動リトライ、Catch/Fallback）が組み込みで提供。発注失敗時のリカバリフロー設計に活用

#### Amazon EventBridge

**公式**: https://docs.aws.amazon.com/eventbridge/latest/userguide/

サーバーレスイベントバス。イベント駆動アーキテクチャの中核。

**ストコンでの活用シナリオ**:

1. **イベントルーティング**: 店舗からのイベント（発注完了・売上締め・在庫アラート等）をEventBridgeで受信し、適切なサービスへルーティング
2. **SaaS統合**: 外部サービス（物流パートナー、決済代行等）からのWebhookをEventBridgeで統合
3. **スケジュール実行**: EventBridge Schedulerで定時バッチ（日次精算、発注締め、マスタ配信）を起動
4. **イベントアーカイブ**: 全イベントをアーカイブし、障害時のリプレイや監査に活用

**イベント駆動アーキテクチャのメリット（ストコン観点）**:
- 疎結合: 発注システムと在庫システムが直接連携せず、イベントを介して非同期連携。一方のシステム障害が他方に波及しない
- 拡張性: 新しいサービス（例: AI需要予測）を既存システムに手を加えずにイベント購読で追加可能
- 可観測性: 全イベントがログとして残るため、業務フローの追跡が容易

---

### 1-3. モダナイゼーション戦略パターン

#### Strangler Fig パターン

**公式**: https://docs.aws.amazon.com/prescriptive-guidance/latest/modernization-decomposing-monoliths/strangler-fig.html

モノリスを段階的にマイクロサービスに移行するパターン。ガジュマルの木が宿主の木を覆いながら成長する様子に由来。

**3ステップ**:
1. **Transform**: 新機能をマイクロサービスとして実装
2. **Coexist**: プロキシ（API Gateway等）でトラフィックを新旧に振り分け
3. **Eliminate**: 旧機能を廃止し新サービスに完全移行

**ストコンへの適用**:

```
[Phase 1: Lift & Shift]
  MGNでオンプレ→EC2に移行（既存deep-diveレポート参照）

[Phase 2: Strangler Fig 開始]
  API Gatewayをプロキシとして前段に配置
  ↓
  新規機能・変更頻度の高い機能からマイクロサービス化
  ↓ 例: 推奨発注エンジン → Lambda + Step Functions で新規実装
  ↓ 例: 売上ダッシュボードAPI → ECS Fargate で新規実装
  ↓ 旧モノリスのエンドポイントをAPI Gatewayでルーティング

[Phase 3: 段階的移行]
  発注ドメイン → 在庫ドメイン → 売上ドメイン → ...
  各ドメインをマイクロサービス化するごとに旧機能を廃止

[Phase 4: モノリス完全廃止]
  全機能が新アーキテクチャに移行完了
```

#### AWS Migration Hub Refactor Spaces

**公式**: https://docs.aws.amazon.com/migrationhub-refactor-spaces/latest/userguide/

Strangler Figパターンをマネージドで実装するサービス。

- **Environment**: リファクタリング対象のアプリケーション群を管理する論理コンテナ
- **Application**: 既存のモノリスと新しいマイクロサービスを接続
- **Route**: URLパスベースでトラフィックをモノリス/マイクロサービスに振り分け

**ストコンでの利用メリット**:
- API Gatewayのルーティング設定を手動で管理する必要がなくなる
- ルート単位でトラフィックの切り替え・ロールバックが容易
- 移行進捗のダッシュボード可視化

#### ドメイン分解パターン

**公式**: https://docs.aws.amazon.com/prescriptive-guidance/latest/modernization-decomposing-monoliths/welcome.html

AWS Prescriptive Guidanceが推奨する6つの分解パターン:

| パターン | 説明 | ストコンでの適用候補 |
|---------|------|-------------------|
| ビジネスケイパビリティ分解 | ビジネス機能単位で分割 | 発注/在庫/売上/従業員管理 |
| サブドメイン分解（DDD） | ドメイン駆動設計の境界付けられたコンテキスト | 発注コンテキスト/在庫コンテキスト |
| トランザクション分解 | ビジネストランザクション単位 | 発注処理/精算処理/返品処理 |
| Service per Team | チーム単位 | 発注チーム/分析チーム |
| Strangler Fig | 段階的置換 | 上記参照 |
| Branch by Abstraction | 抽象化レイヤーで分岐 | DBアクセス層の段階的切替 |

**ストコン推奨アプローチ**:
1. **DDD（サブドメイン分解）** でドメイン境界を定義（業務シナリオレポート参照）
2. **Strangler Fig** で段階的に移行
3. 変更頻度が高く、独立性が高いドメインから着手（推奨: 発注ドメイン → 売上分析ドメイン）

**PM視点の判断基準**:
- 一度に全体をマイクロサービス化しようとしない。 **1ドメインずつ**、6〜12ヶ月単位で移行
- 分割の境界を誤ると「分散モノリス」（結合度が高いマイクロサービス群）に陥る。ドメインエキスパート（本部業務担当者）とのセッションが必須
- 商品マスタ等の共有データは **イベント駆動のデータ同期** で各サービスにレプリケーション。直接DB共有は避ける

---

## 2. データ分析領域

ストコンが生成する膨大なPOS・発注・在庫データの分析基盤。

### 2-1. データレイク / データウェアハウス

#### Amazon Redshift / Redshift Serverless

**公式**: https://docs.aws.amazon.com/redshift/latest/mgmt/

ペタバイト規模のクラウドデータウェアハウス。

| 項目 | Redshift Provisioned | Redshift Serverless |
|------|---------------------|---------------------|
| 管理負荷 | クラスター管理が必要 | フルマネージド |
| スケーリング | ノード追加・Concurrency Scaling | 自動スケーリング |
| 課金 | ノード単位（時間課金） | RPU（Redshift Processing Unit）秒単位課金 |
| ストコン適用 | 大規模常時分析 | アドホック分析・PoC |
| 東京リージョン | 利用可能 | 利用可能 |

**主要機能（ストコン向け）**:

1. **ストリーミング取り込み（Streaming Ingestion）**: Kinesis Data StreamsやMSKから直接Redshiftに低レイテンシで取り込み。POS売上データのニアリアルタイム分析に最適
2. **Zero-ETL統合**: Aurora MySQL/PostgreSQL、DynamoDB等からRedshiftへETLパイプラインなしで自動同期。発注DB・在庫DBのリアルタイム分析が可能
3. **Redshift Spectrum**: S3上のデータ（過去のPOS履歴等）をRedshiftからSQL直接クエリ。ホット/ウォーム/コールドのデータ階層化に活用
4. **データ共有（Data Sharing）**: 本部分析チームと各エリアチームでRedshiftクラスターを分離しつつデータを共有
5. **Materialized Views**: 頻繁に使う集計（日別売上サマリー等）を実体化ビューで高速化

**ストコンでの活用シナリオ**:
- **本部売上分析DWH**: 全国POSデータの集約・分析。商品別/店舗別/時間帯別の多次元分析
- **需要予測用データマート**: SageMakerと連携した需要予測モデルのトレーニングデータ提供
- **経営ダッシュボード**: QuickSightと連携した全店売上・在庫のリアルタイムモニタリング

**参考**: https://aws.amazon.com/blogs/big-data/architecture-patterns-to-optimize-amazon-redshift-performance-at-scale/

#### Amazon S3 + Lake Formation

**S3公式**: https://docs.aws.amazon.com/AmazonS3/latest/userguide/
**Lake Formation公式**: https://docs.aws.amazon.com/lake-formation/latest/dg/

**S3をデータレイクのストレージ基盤**として使用し、**Lake Formationでガバナンス**（アクセス制御・データカタログ・監査）を管理。

**Amazon S3 Tables（Apache Iceberg）**:
- re:Invent 2024で発表。S3上にApache Icebergテーブルを直接管理
- 従来の自己管理Icebergと比較して **クエリスループット3倍、TPS10倍**
- ストコンの大量POSデータのタイムトラベル（過去時点のデータ参照）やスキーマ進化に最適

**Amazon S3 Metadata**:
- S3オブジェクトのメタデータを自動キャプチャし、クエリ可能なテーブルとして提供
- データレイク内のPOSファイル管理（いつ・どの店舗から・どのフォーマットで取り込まれたか）に活用

**ストコンデータレイクの階層設計**:

```
s3://storcon-datalake/
├── raw/                     ← 生データ（POS、発注、在庫）
│   ├── pos-transactions/    ← Kinesis Firehose から直接投入
│   ├── order-data/          ← バッチ取り込み
│   └── inventory-snapshots/ ← 日次スナップショット
├── curated/                 ← Glue ETL で変換・クレンジング済み
│   ├── pos-curated/         ← Parquet形式、パーティション済み
│   ├── order-curated/
│   └── inventory-curated/
├── analytics/               ← 分析用データマート
│   ├── daily-sales-summary/
│   ├── demand-forecast-features/
│   └── store-benchmark/
└── archive/                 ← 長期保存（S3 Glacier）
    └── pos-archive/         ← 7年保管義務対応
```

#### Amazon Athena

**公式**: https://docs.aws.amazon.com/athena/latest/ug/

S3上のデータに標準SQLで直接クエリ。サーバーレス、スキャンデータ量課金。

**ストコンでの活用シナリオ**:
- **アドホック分析**: 特定キャンペーンの効果検証、特定店舗の異常調査等をSQLで即座に実行
- **過去データの探索**: S3 Glacier Instant Retrievalからの低頻度分析
- **フェデレーテッドクエリ**: Athena Federated Queryで DynamoDB / RDS / OpenSearch 等の複数ソースを横断クエリ
- **Redshift Data Catalog連携**: Redshift内のデータもAthenaからクエリ可能（SageMaker Lakehouse統合）

**コスト最適化のポイント**:
- Parquet/ORC等の列指向フォーマットにすることでスキャン量を大幅削減
- 日付/店舗ID等でパーティションを切ることでクエリコスト低減
- 高頻度クエリはRedshiftへ、低頻度のアドホックはAthenaという使い分け

---

### 2-2. ETL / データ統合

#### AWS Glue

**公式**: https://docs.aws.amazon.com/glue/latest/dg/

フルマネージドETLサービス。Data Catalog、Crawlers、ETL Jobs、Triggersで構成。

**主要コンポーネントとストコン活用**:

| コンポーネント | 機能 | ストコン活用 |
|-------------|------|------------|
| Data Catalog | メタデータストア（テーブル定義等） | 全データソースの統合カタログ |
| Crawlers | スキーマ自動検出 | S3上のPOSデータの自動スキーマ検出 |
| ETL Jobs (Spark) | 分散データ変換 | POS生データ→Parquet変換・クレンジング |
| Glue Studio | ビジュアルETLエディタ | 非エンジニアによるETLジョブ作成 |
| DataBrew | ノーコードデータ準備 | データアナリストによるデータ品質確認 |
| Glue Streaming ETL | ストリーミング変換 | Kinesis→S3のリアルタイム変換 |

**Glue 5.0の新機能**（re:Invent 2024）:
- パフォーマンス向上、セキュリティ強化
- SageMaker Unified Studio / SageMaker Lakehouse対応
- 生成AIによるSparkジョブトラブルシューティング

**ストコンETLパイプライン設計**:

```
[データソース]                    [Glue ETL]                     [ターゲット]
POS取引データ（CSV/JSON）    →   Crawlerでスキーマ検出         →  S3 (Parquet)
                              →   ETL Job: クレンジング・型変換  →  Redshift
発注データ（Oracle DB）      →   JDBC接続で抽出               →  S3 (Parquet)
                              →   ETL Job: 正規化・結合         →  Redshift
在庫スナップショット         →   S3イベントトリガー            →  S3 (Iceberg)
マスタデータ（商品/店舗）    →   Data Catalog管理              →  Lake Formation
```

**PMとして知っておくべきポイント**:
- GlueはDPU（Data Processing Unit）単位課金。大規模ETLのコスト見積もりにはDPU時間の概算が必要
- Glue Streaming ETLはマイクロバッチ（Spark Structured Streaming）。真のリアルタイムには Flink を検討
- Data Catalogは他のサービス（Athena、Redshift Spectrum、EMR）と共有。一度整備すれば横断利用可能

#### Amazon Data Firehose（旧Kinesis Data Firehose）

**公式**: https://docs.aws.amazon.com/firehose/latest/dev/

ストリーミングデータをS3/Redshift/OpenSearch等にロードする最も簡単な方法。

**ストコンでの活用シナリオ**:
- **POS→S3**: POS取引データをFirehose経由でS3に自動蓄積。バッファリング（サイズ/時間指定）でコスト最適化
- **POS→Redshift**: ストリーミング取り込みでニアリアルタイムDWH投入
- **ログ→OpenSearch**: 店舗機器ログ・アプリログをFirehose経由でOpenSearchに投入

**Firehose vs Kinesis Data Streams**:

| 観点 | Firehose | Kinesis Data Streams |
|------|----------|---------------------|
| 管理 | フルマネージド | シャード管理が必要 |
| レイテンシ | 60秒〜 | ミリ秒〜 |
| 消費者 | AWS宛先に限定 | 任意のコンシューマー |
| ストコン用途 | S3/Redshiftへの蓄積 | リアルタイム処理パイプライン |

#### Zero-ETL統合

**公式**: https://docs.aws.amazon.com/redshift/latest/mgmt/zero-etl-using.html

ETLパイプラインを構築せずにデータソースからRedshiftへ自動同期。

**対応ソース（2025年時点）**:
- Amazon Aurora MySQL-Compatible Edition
- Amazon Aurora PostgreSQL-Compatible Edition
- Amazon RDS for MySQL
- Amazon DynamoDB
- SaaSアプリ（Salesforce、SAP、ServiceNow、Zendesk等）

**ストコンでの活用シナリオ**:
- **Aurora→Redshift**: ストコン移行後のAurora（発注DB・在庫DB）をZero-ETLでRedshiftに同期。リアルタイム分析をGlue ETLなしで実現
- **DynamoDB→Redshift**: 店舗イベントデータ（DynamoDB）をRedshiftで分析

**PMとして知っておくべきポイント**:
- Zero-ETLは **ニアリアルタイム**（秒〜分単位の遅延）。真のリアルタイム（ミリ秒）が必要な場合はKinesis経由
- GlueベースのETLが不要になるが、データ変換（クレンジング・エンリッチメント）が必要な場合はGlueと併用
- 全てのテーブルではなく選択的に同期可能。コスト管理の観点から必要テーブルのみ同期推奨

---

### 2-3. リアルタイム分析

#### Amazon Kinesis Data Streams

**公式**: https://docs.aws.amazon.com/streams/latest/dev/

フルマネージドのリアルタイムデータストリーミングサービス。

**ストコンでの活用シナリオ**:

```
[全国数万店舗のPOS]
  → Kinesis Data Streams（取引イベントのストリーム）
    → Consumer 1: Lambda（異常取引検知）
    → Consumer 2: Firehose → S3（データレイク蓄積）
    → Consumer 3: Firehose → Redshift（DWH投入）
    → Consumer 4: Flink（リアルタイム集計）
```

**キャパシティ設計（ストコン規模）**:
- 全国5万店舗 × 1店舗あたり平均1,000取引/日 = 5,000万取引/日
- ピーク時（昼食時 11:00-13:00）: 全日の約25% が2時間に集中 → 約17,000 取引/秒
- 1取引あたり平均1KB → ピーク時約17MB/秒
- **On-Demandモード** を推奨: シャード管理不要でスパイクに自動対応

#### Amazon Managed Service for Apache Flink

**公式**: https://docs.aws.amazon.com/managed-flink/latest/java/

Apache Flinkのマネージドサービス。ストリーミングデータのリアルタイム分析。

**ストコンでの活用シナリオ**:
1. **リアルタイム売上集計**: 全店舗のPOSデータを1分間ウィンドウで集計し、ダッシュボードへ
2. **異常検知**: 5分間のスライディングウィンドウで売上パターンの異常（急激な売上増減、不正取引パターン）を検知
3. **在庫アラート**: 在庫変動ストリームを監視し、発注点割れをリアルタイム検知
4. **需要予測入力**: 直近の売上トレンドをリアルタイムで計算し、需要予測モデルのフィーチャーとして提供

**Flink vs Glue Streaming ETL**:

| 観点 | Flink | Glue Streaming |
|------|-------|----------------|
| レイテンシ | ミリ秒〜秒 | 秒〜分（マイクロバッチ） |
| 複雑な処理 | ウィンドウ集計、パターンマッチ、CEP | 基本的なETL変換 |
| ストコン用途 | 異常検知、リアルタイム集計 | データ変換・ロード |
| コスト | KPU単位の時間課金 | DPU単位の時間課金 |

#### Amazon OpenSearch Service

**公式**: https://docs.aws.amazon.com/opensearch-service/latest/developerguide/

全文検索・ログ分析・リアルタイムダッシュボードのマネージドサービス。

**ストコンでの活用シナリオ**:
1. **店舗機器ログ分析**: ストコン端末・POS端末・ネットワーク機器のログ集約・可視化。Cluster Insightsダッシュボードで一元監視
2. **商品検索**: 数万SKUの商品マスタの全文検索・ファセット検索
3. **リアルタイム異常ダッシュボード**: OpenSearch DashboardsでPOS異常・在庫差異をリアルタイム可視化
4. **セキュリティログ**: AWS Security Lakeとの連携でセキュリティイベントの分析

**OpenSearch Serverless**:
- クラスター管理不要のサーバーレスオプション
- ペタバイト規模のワークロードに対応
- ベクトルエンジン搭載でML検索・生成AIアプリにも活用可能
- ストコン商品検索のセマンティック検索（「おにぎり系」で全おにぎり商品をヒット等）に将来的に活用

---

### 2-4. BI / 可視化 / AI・ML

#### Amazon QuickSight

**公式**: https://docs.aws.amazon.com/quicksight/latest/user/

サーバーレスBIサービス。ダッシュボード・レポート・埋め込み分析。

**ストコンでの活用シナリオ**:

1. **本部経営ダッシュボード**:
   - 全店売上リアルタイムモニタリング（Redshiftストリーミング取り込みと連携）
   - 商品カテゴリ別売上トレンド
   - エリア別パフォーマンス比較

2. **店舗別分析レポート**:
   - 単品売上ランキング
   - 在庫回転率
   - 廃棄率推移
   - 人時売上高

3. **需要予測可視化**:
   - SageMaker予測結果のビジュアライゼーション
   - What-if分析（「気温が5度下がったら温かい商品の需要は？」）

4. **埋め込み分析**:
   - QuickSight Q（自然言語クエリ）: 「先月の東京エリアのおにぎりの売上は？」
   - QuickSightダッシュボードをストコン管理画面に埋め込み

**主要機能**:
- **SPICE**: インメモリ計算エンジン。定期リフレッシュでRedshift負荷を軽減
- **シナリオ分析**: re:Invent 2024で発表。What-ifシミュレーション
- **ピクセルパーフェクトレポート**: 定型帳票（日報・月報）の自動生成・配信
- **Amazon Q Business連携**: 構造化データと非構造化データの統合インサイト

**課金モデル**:
- Author: ダッシュボード作成者（月額$24/ユーザー）
- Reader: 閲覧者（セッション課金$0.30/30分、上限$5/月）
- ストコン規模（本部50人 + エリア200人閲覧）の概算: 約$2,200/月

#### Amazon SageMaker Canvas

**公式**: https://docs.aws.amazon.com/sagemaker/latest/dg/canvas.html

ノーコードMLサービス。コーディング不要で予測モデルを構築。

**ストコンでの活用シナリオ**:

1. **需要予測（Time Series Forecasting）**:
   - 入力: 過去の売上データ（SKU別×店舗別×日別）+ 外部要因（天気、曜日、イベント）
   - 出力: 1日〜30日先の需要予測
   - 予測インターバル: 1日単位
   - SageMaker Canvasは自動で6つのアルゴリズムをアンサンブルし最適モデルを選択
   - **分位点予測**: P10/P50/P90の確率的予測で発注量の安全在庫計算に活用
   - 参考: https://aws.amazon.com/blogs/machine-learning/solve-forecasting-challenges-for-the-retail-and-cpg-industry-using-amazon-sagemaker-canvas/

2. **廃棄予測**:
   - 消費期限・売上トレンド・天候予報から廃棄リスクの高い商品を予測
   - 値引き販売のタイミング最適化

3. **What-if分析**:
   - 「新商品Aを導入した場合の売上インパクト」を入力変数を変えてシミュレーション

**PMとして知っておくべきポイント**:
- SageMaker Canvasは **本部の非エンジニア（MD担当、バイヤー等）** が自分で予測モデルを構築できる点が最大の価値
- ただしデータ品質が予測精度に直結。ETLパイプラインでのデータクレンジングが前提
- 本格的なMLパイプライン（自動再学習、A/Bテスト等）は SageMaker AI（旧SageMaker Studio）で構築

#### Amazon Bedrock

**公式**: https://docs.aws.amazon.com/bedrock/latest/userguide/

フルマネージド生成AIサービス。複数のファンデーションモデルをAPIで利用。

**ストコンでの活用シナリオ（将来的）**:

1. **発注推奨理由の自然言語説明**:
   - 「明日は近隣で花火大会があるため、飲料の発注量を通常の150%に増加することを推奨します」
   - 需要予測モデルの出力をBedrockで自然言語化

2. **店舗運営アシスタント**:
   - 店長向けチャットボット: 「今週の売れ筋は？」「廃棄が多い商品は？」
   - RAG（Retrieval Augmented Generation）でストコンデータ + 業務マニュアルを参照

3. **本部分析アシスタント**:
   - 「先月のおにぎりカテゴリで前年比が下がった店舗の共通点は？」
   - RedshiftのデータをBedrockで自然言語分析

4. **マニュアル生成・Q&A**:
   - 業務マニュアルの自動生成・更新
   - 新人向けFAQボット

**PMとして知っておくべきポイント**:
- Bedrockは「将来的な付加価値」であり、移行初期フェーズでは優先度低
- データ分析基盤（Redshift/S3/Glue）が整った後のPhase 3以降で検討
- 生成AIの社内利用ポリシー（データのAIサービスへの送信可否）の事前確認が必要

---

## 3. ストコン移行におけるサービス選定ガイド

### フェーズ別サービスマトリックス

| フェーズ | 期間目安 | 主要サービス | 目的 |
|---------|---------|-------------|------|
| **Phase 1: Lift & Shift** | 〜6ヶ月 | MGN, DMS, SCT, Direct Connect | オンプレ→AWS移行 |
| **Phase 2: 基盤整備** | 6〜12ヶ月 | S3, Glue, Redshift, Kinesis, Firehose | データレイク/DWH構築 |
| **Phase 3: モダナイゼーション開始** | 12〜24ヶ月 | ECS/Fargate, Lambda, Step Functions, EventBridge, API Gateway | マイクロサービス化（Strangler Fig） |
| **Phase 4: 高度分析** | 18〜30ヶ月 | QuickSight, SageMaker Canvas, Athena, Flink | BI・ML・リアルタイム分析 |
| **Phase 5: AI活用** | 24ヶ月〜 | Bedrock, OpenSearch Serverless | 生成AI、セマンティック検索 |

### データパイプライン別サービス選定

| データ種別 | 取り込み | 変換/ETL | 蓄積 | 分析 |
|-----------|---------|---------|------|------|
| POS取引（リアルタイム） | Kinesis Data Streams | Flink / Lambda | S3 + Redshift | QuickSight |
| POS取引（バッチ） | Firehose | Glue ETL | S3 (Parquet) | Athena / Redshift |
| 発注データ | Zero-ETL (Aurora→Redshift) | — | Redshift | QuickSight |
| 在庫スナップショット | Glue JDBC | Glue ETL | S3 (Iceberg) | Athena |
| 機器ログ | Firehose | — | OpenSearch | OpenSearch Dashboards |
| マスタデータ | Glue Crawler | Glue Data Catalog | Lake Formation | Athena / Redshift |
| 需要予測 | — | SageMaker Pipeline | S3 | SageMaker Canvas |

### コスト意識の判断フレームワーク

| 判断ポイント | 低コスト選択 | 高機能選択 |
|------------|------------|-----------|
| DWH | Redshift Serverless（PoC・小規模） | Redshift Provisioned + RI（大規模常時） |
| ETL | Glue（マネージド・従量課金） | EMR（大規模・長時間バッチ） |
| クエリ | Athena（アドホック・低頻度） | Redshift（高頻度・高速） |
| BI | QuickSight Reader（閲覧者多数） | QuickSight Author（分析者育成） |
| リアルタイム | Firehose（遅延許容） | Kinesis + Flink（ミリ秒応答） |

---

## 4. 学習ロードマップ

### Must（参画前に理解必須）

| サービス | 学習内容 | 推定時間 |
|---------|---------|---------|
| ECS / Fargate | タスク定義、サービス、デプロイ戦略 | 4時間 |
| Lambda | イベントソース、同時実行、制限事項 | 3時間 |
| Step Functions | ステートマシン設計、Standard vs Express | 2時間 |
| Redshift | テーブル設計、ストリーミング取り込み、Zero-ETL | 4時間 |
| Glue | Data Catalog、ETLジョブ、Crawler | 3時間 |
| Kinesis Data Streams | シャード、プロデューサー/コンシューマー | 2時間 |
| Strangler Fig パターン | AWS Prescriptive Guidance の理解 | 2時間 |

### Should（参画後早期に深めるべき）

| サービス | 学習内容 | 推定時間 |
|---------|---------|---------|
| EventBridge | イベントルール、スケジューラー、アーカイブ | 2時間 |
| QuickSight | ダッシュボード設計、SPICE、埋め込み | 3時間 |
| Lake Formation | アクセス制御、データカタログガバナンス | 2時間 |
| Athena | フェデレーテッドクエリ、パフォーマンス最適化 | 2時間 |
| S3 Tables (Iceberg) | テーブルフォーマット、タイムトラベル | 2時間 |
| Flink | ウィンドウ処理、異常検知パターン | 3時間 |
| SageMaker Canvas | 需要予測モデル構築の流れ | 2時間 |

### Nice-to-have（余裕があれば）

| サービス | 学習内容 | 推定時間 |
|---------|---------|---------|
| EKS | K8s基礎、ECS比較、ハイブリッド | 4時間 |
| Bedrock | モデル選定、RAG構築、プロンプト設計 | 3時間 |
| OpenSearch | クラスター設計、Dashboards、Serverless | 2時間 |
| Refactor Spaces | Strangler Figのマネージド実装 | 1時間 |
| Data Firehose | 動的パーティショニング、変換 | 1時間 |

---

## 5. 参考リソース一覧

### モダナイゼーション

| リソース | URL |
|---------|-----|
| コンテナサービス選択ガイド | https://docs.aws.amazon.com/whitepapers/latest/containers-on-aws/containers-services-on-aws.html |
| モダンアプリ戦略の選び方 | https://docs.aws.amazon.com/decision-guides/latest/modern-apps-strategy-on-aws-how-to-choose/modern-apps-strategy-on-aws-how-to-choose.html |
| Strangler Fig パターン | https://docs.aws.amazon.com/prescriptive-guidance/latest/modernization-decomposing-monoliths/strangler-fig.html |
| モノリス分解ガイド | https://docs.aws.amazon.com/prescriptive-guidance/latest/modernization-decomposing-monoliths/welcome.html |
| App Runner→ECS Express Mode移行 | https://aws.amazon.com/blogs/containers/migrating-from-aws-app-runner-to-amazon-ecs-express-mode/ |
| EKSでのマイクロサービスモダナイゼーション | https://docs.aws.amazon.com/architecture-diagrams/latest/modernize-applications-with-microservices-using-amazon-eks/modernize-applications-with-microservices-using-amazon-eks.html |
| Lambda ワークフロー管理 | https://docs.aws.amazon.com/lambda/latest/dg/workflow-event-management.html |
| Step Functions + Lambda | https://docs.aws.amazon.com/lambda/latest/dg/with-step-functions.html |

### データ分析

| リソース | URL |
|---------|-----|
| Redshift パフォーマンス最適化パターン | https://aws.amazon.com/blogs/big-data/architecture-patterns-to-optimize-amazon-redshift-performance-at-scale/ |
| AWS分析サービス概要 | https://docs.aws.amazon.com/whitepapers/latest/aws-overview/analytics.html |
| Glue ベストプラクティス | https://docs.aws.amazon.com/whitepapers/latest/aws-glue-best-practices-build-efficient-data-pipeline/aws-glue-product-family.html |
| Glue ETL ガイド | https://docs.aws.amazon.com/prescriptive-guidance/latest/serverless-etl-aws-glue/aws-glue-etl.html |
| サーバーレス分析パイプライン | https://docs.aws.amazon.com/whitepapers/latest/aws-serverless-data-analytics-pipeline/consumption-layer-1.html |
| Modern Data アーキテクチャ | https://docs.aws.amazon.com/whitepapers/latest/derive-insights-from-aws-modern-data/derive-insights-with-inside-out-data-movement.html |
| re:Invent 2024 分析アップデート | https://aws.amazon.com/blogs/big-data/top-analytics-announcements-of-aws-reinvent-2024/ |
| SageMaker Canvas 小売需要予測 | https://aws.amazon.com/blogs/machine-learning/solve-forecasting-challenges-for-the-retail-and-cpg-industry-using-amazon-sagemaker-canvas/ |
| Kinesis Data Streams | https://aws.amazon.com/kinesis/data-streams/ |

### アーキテクチャ全般

| リソース | URL |
|---------|-----|
| リアクティブシステム on AWS | https://docs.aws.amazon.com/whitepapers/latest/reactive-systems-on-aws/service-introduction.html |
| Redshift Data Catalog連携 (Lake Formation) | https://docs.aws.amazon.com/lake-formation/latest/dg/managing-namespaces-datacatalog.html |

---

## 付記: 東京リージョン（ap-northeast-1）利用可否

| サービス | 東京リージョン | 備考 |
|---------|-------------|------|
| ECS / Fargate | 利用可能 | ECS Express Mode含む |
| EKS | 利用可能 | |
| Lambda | 利用可能 | |
| Step Functions | 利用可能 | Standard / Express 両対応 |
| EventBridge | 利用可能 | Scheduler含む |
| Redshift / Serverless | 利用可能 | |
| S3 / S3 Tables | 利用可能 | S3 Tablesは要確認 |
| Athena | 利用可能 | フェデレーテッドクエリ含む |
| Lake Formation | 利用可能 | |
| Glue | 利用可能 | Glue 5.0含む |
| Kinesis Data Streams | 利用可能 | |
| Data Firehose | 利用可能 | |
| Managed Apache Flink | 利用可能 | |
| OpenSearch Service | 利用可能 | Serverless含む |
| QuickSight | 利用可能 | |
| SageMaker Canvas | 利用可能 | |
| Bedrock | 利用可能 | モデルにより差異あり |
| Refactor Spaces | 利用可能 | |
