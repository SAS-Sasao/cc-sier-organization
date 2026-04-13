# AWS サービス選定と設計パターン詳細調査 — ストコン移行版

- **調査目的**: WBS 5.2「AWS移行技術レポートの拡充」— コンピューティング・DB・メッセージング・ネットワーク・セキュリティの具体的な設計パターン
- **作成日**: 2026-04-12
- **作成者**: tech-researcher
- **前提レポート**:
  - [wbs-5-2-storcon-aws-migration-tech.md](wbs-5-2-storcon-aws-migration-tech.md) — 技術スタック概要・7Rパターン・運用設計
  - [wbs-5-2-storcon-aws-modernization-analytics.md](wbs-5-2-storcon-aws-modernization-analytics.md) — ECS/EKS/Lambda詳細・データ分析基盤
- **対象案件**: コンビニエンスストア向けストアコンピューター AWS移行（参画予定: 2026年6月）

---

## 目次

1. [コンピューティング選定 — 業務ワークロード別の適材適所](#1-コンピューティング選定)
2. [データベース選定 — データ特性別の設計戦略](#2-データベース選定)
3. [メッセージング・イベント駆動設計](#3-メッセージングイベント駆動設計)
4. [VPC・ネットワーク設計 — 14,663 店舗を支えるアーキテクチャ](#4-vpcネットワーク設計)
5. [セキュリティ設計 — PCI DSS 対応と多層防御](#5-セキュリティ設計)
6. [PM視点のポイント — 移行判断材料 5 選](#6-pm視点のポイント)
7. [設計パターンサマリー（比較表）](#7-設計パターンサマリー比較表)
8. [Sources](#8-sources)

---

## 1. コンピューティング選定

### 1-1. ECS Fargate / Lambda / EKS — 三者の特性整理

既存レポートでは ECS vs Lambda の選択基準を概説した。本節ではストコン固有の業務ワークロード 5 類型に対して、**どのサービスをなぜ選ぶか**の設計判断根拠を深掘りする。

#### 業務ワークロード別 選定マトリクス

| ワークロード種別 | 具体例 | 推奨コンピューティング | 判断根拠 |
|---|---|---|---|
| **常時起動 API** | 発注受付 API、在庫照会 API | ECS Fargate | レイテンシ要件（数十 ms 以内）+ コールドスタートなし |
| **イベント駆動・軽量処理** | DynamoDB Streams トリガー、SNS 受信処理 | Lambda | 実行頻度が低い / 実行時間 15 分以内 / ステートレス |
| **日次大規模バッチ** | 全国売上集計、マスタ一括更新、請求データ生成 | AWS Batch (Fargate 起動) | 並列ジョブ管理 / 数時間を超える実行 / コスト最適 |
| **バッチ・オーケストレーション** | 発注→在庫引当→配送指示のフロー制御 | Step Functions + Lambda | 複数ステップのエラーハンドリングとリトライ |
| **マイクロサービス（将来）** | Kubernetes 資産を活用するドメインサービス | EKS on Fargate | チームに K8s 経験者がいる場合のみ採用 |

#### コンテナ化の判断フレームワーク

何をコンテナ化し、何を Lambda にするかの判断は「**実行時間の長さ**」と「**起動頻度の高さ**」の 2 軸で決まる。

```
                  起動頻度 高
                      |
                      |  Lambda が最適
       Lambda が最適   |  （コールドスタート対策として
       （短時間処理）   |   Provisioned Concurrency を使用）
                      |
短時間 ──────────────────────────────── 長時間
                      |
   ECS Fargate        |  ECS Fargate or
   （常時起動 API）    |  AWS Batch（バッチ処理）
                      |
                  起動頻度 低
```

**ストコン案件の具体的な配置**:

- Lambda: 在庫アラート判定（DynamoDB Streams → Lambda）、廃棄予測通知（EventBridge Scheduler → Lambda）、マスタ差分配信
- ECS Fargate: 発注受付 REST API、精算 API、管理コンソール BFF（Backend for Frontend）
- AWS Batch: 日次売上集計バッチ、月次請求バッチ、全国商品マスタ更新バッチ

#### ECS Fargate の設計詳細 — ストコン向けタスク定義指針

```
[タスク定義のポイント]

CPU / メモリ設定:
  - 発注受付 API: 0.5 vCPU / 1 GB（スパイク時は Auto Scaling で補完）
  - 日次バッチ: 2 vCPU / 4 GB（並列実行数でスループット調整）

ネットワーク:
  - awsvpc モード（Fargate の必須設定）
  - サービスごとに専用 Security Group を割り当て（最小権限）

ロギング:
  - awslogs ドライバー → CloudWatch Logs
  - ログ保持期間: アプリ 30 日 / 監査系 365 日

IAM:
  - タスクロール: サービスごとに専用の IAM Role（S3 / DynamoDB / SQS へのアクセス）
  - 実行ロール: ECR からのイメージ Pull / Secrets Manager 参照用
```

#### Lambda コールドスタート問題への対処

全国 14,663 店舗から業務開始時刻（例: 朝 7 時の発注処理）に同時リクエストが集中する場合、Lambda のコールドスタートが問題になる。

| 対策 | 方法 | コスト |
|---|---|---|
| **Provisioned Concurrency** | 事前に Lambda を温めておく | 予約済み並列数 × 時間で課金（約 $0.015/vCPU-hour） |
| **Lambda SnapStart** | Java ランタイムの起動を数 ms に短縮（Java 21 対応） | 追加コストなし |
| **ECS Fargate へ移行** | コールドスタートがそもそも発生しない | 常時稼働コスト |

**推奨**: 発注受付 API のような SLA 要件が厳しい処理は ECS Fargate に移行。Lambda は補助的な非同期処理に限定することで、コールドスタートリスクを設計段階で排除する。

---

### 1-2. EKS 採用の判断基準

EKS は強力だが、ストコン案件においては**採用コストが高い**。以下の基準で判断する。

| 採用すべき条件 | 採用を避けるべき条件 |
|---|---|
| チームに Kubernetes 経験者（CKA レベル）が 2 名以上いる | AWS ネイティブスタックに統一したい |
| 将来的なマルチクラウド・オンプレ連携が確定している | 移行フェーズ（Lift&Shift 直後）である |
| 既存 K8s クラスターからの移行がある | チームに K8s 運用経験がない |
| CNCF エコシステム（Istio, Argo CD, KEDA 等）を活用したい | 運用チームの教育コストを最小化したい |

**ストコン移行フェーズでの推奨**: Lift&Shift → Replatform（ECS/Fargate）→ 運用安定後に必要性を再評価。最初から EKS を採用するメリットは少ない。

---

## 2. データベース選定

### 2-1. RDS PostgreSQL vs Aurora vs DynamoDB — 業務データ特性ごとの設計

前提レポート（[wbs-3-1-2-aws-database-comparison.md](wbs-3-1-2-aws-database-comparison.md)）で全体比較は完了済み。本節では**データ特性ごとの具体的な設計パターン**に集中する。

#### ストコンデータ分類と推奨 DB の最終整理

```
[ストコンデータ 5 分類]

1. マスタデータ（商品マスタ・店舗マスタ）
   → Aurora PostgreSQL + ElastiCache Redis
   
2. 発注トランザクション
   → Aurora PostgreSQL Multi-AZ（書き込みインスタンス）
   
3. 在庫カウンタ（高頻度更新）
   → DynamoDB（アトミックカウンタ）
   
4. 時系列データ（温度ログ・センサーデータ）
   → Amazon Timestream
   
5. 売上分析・本部BI
   → Redshift Serverless
```

#### Aurora PostgreSQL の設計詳細

Aurora は MySQL 互換と PostgreSQL 互換の 2 種類があるが、ストコン案件で Oracle からの移行を想定する場合は **Aurora PostgreSQL** が有利。

**なぜ Aurora PostgreSQL か**:
- Oracle → PostgreSQL の SQL 互換性は 80〜90%（SCT での自動変換率）
- `pg_cron` 拡張機能による DB 内ジョブスケジューリング
- `pgvector` 拡張による将来の AI 活用（商品推薦ベクトル検索）

**Aurora PostgreSQL 設計のポイント**:

```
[クラスター構成]

Writer インスタンス（1台）
  ↓ 非同期レプリケーション（通常 10ms 以内）
Reader インスタンス（2台 以上）※ Auto Scaling 可能

[読み取り負荷分散]
- アプリ → Writer エンドポイント: 書き込みのみ
- アプリ → Reader エンドポイント: 参照系クエリ（商品マスタ参照等）
- ElastiCache Redis: 頻繁に参照される商品マスタのフロントキャッシュ

[フェイルオーバー]
- RTO: 通常 30 秒以内（Aurora Fast Failover で 5〜10 秒）
- Writer 障害時: Reader が自動昇格
- ストコン要件: 発注締め時間（例: 14:00）のフェイルオーバーリスクを考慮し、
  メンテナンスウィンドウを深夜 02:00〜03:00 に設定
```

**Aurora Serverless v2 の採用基準**:

| 採用すべき場合 | 採用しない場合 |
|---|---|
| アクセスパターンが不規則（管理コンソール系 API） | 常時高負荷の発注・在庫 API |
| 開発・検証環境（夜間停止でコスト削減） | レイテンシ要件が厳しい（スケール時の遅延 1〜2 秒） |
| トラフィック予測が困難な新機能 | RI / Savings Plan で割引を効かせたい |

#### DynamoDB の設計詳細 — 在庫カウンタパターン

DynamoDB は高頻度の在庫更新（1 店舗に複数スタッフが同時に在庫変更する）に最適。

**テーブル設計（シングルテーブル設計）**:

```
パーティションキー: store_id（例: "STORE#10001"）
ソートキー:        entity_type + item_id（例: "INVENTORY#4901234567890"）

属性:
- quantity: Number（在庫数）
- last_updated: String（ISO 8601）
- version: Number（楽観的ロック用）

在庫減算（アトミックカウンタ）:
UpdateItem
  Key: {PK: "STORE#10001", SK: "INVENTORY#4901234567890"}
  UpdateExpression: "SET quantity = quantity - :val"
  ConditionExpression: "quantity >= :val"  ← 在庫マイナス防止
  ExpressionAttributeValues: {":val": 1}
```

**DynamoDB の設計注意点**:

- **ホットパーティション問題**: 人気商品の在庫更新が特定パーティションに集中するリスク。カウンタシャーディング（複数パーティションに分散して合算）で回避
- **Global Tables**: 東京リージョン障害時の大阪リージョンへのフェイルオーバーに活用（ただしストロング一貫性は得られない）
- **キャパシティモード**: 発注締め時間帯のスパイクが予測できる → プロビジョンド + Auto Scaling。予測困難 → オンデマンド（コスト高だがスロットリングなし）

---

### 2-2. マスタデータ管理の最適解

コンビニの商品マスタは全国共通で約 5,000〜20,000 SKU（季節品・地域品を含む）。店舗マスタは 14,663 店舗。

**マスタデータの要件**:
1. **参照速度**: 店舗端末のレスポンス改善のため数 ms 以内での参照
2. **更新頻度**: 商品マスタは週次〜月次での一括更新が中心
3. **整合性**: 全店舗への一斉配信が完了するまでバージョン管理が必要

**推奨パターン: Aurora PostgreSQL + ElastiCache Redis のキャッシュ戦略**

```
[マスタ更新フロー]

本部管理システム
  → Aurora PostgreSQL（マスタの正規化データを保存）
  → DynamoDB Streams or CDC
  → Lambda（変更検知）
  → ElastiCache Redis（店舗向けキャッシュを更新）

[店舗端末の参照フロー]

店舗端末
  → API Gateway → ECS Fargate（マスタ API）
    ↓ キャッシュヒット
    ElastiCache Redis（TTL: 60 分）
    ↓ キャッシュミス（初回 / TTL 切れ）
    Aurora PostgreSQL Reader エンドポイント
    ↓ キャッシュ書き込み
    ElastiCache Redis
```

**ElastiCache Redis の設計パラメータ**:

| パラメータ | 推奨値 | 理由 |
|---|---|---|
| ノードタイプ | cache.r7g.large | メモリ重視（商品マスタ全量を RAM に保持） |
| クラスターモード | Cluster Mode 有効（シャード 3〜6 個） | 14,663 店舗の同時参照に対応 |
| TTL | 3,600 秒（1 時間） | 更新頻度（週次）に対してキャッシュが短すぎず長すぎない |
| 暗号化 | 転送中・保存時ともに有効 | PCI DSS 要件 |
| フェイルオーバー | Multi-AZ + 自動フェイルオーバー | 99.99% 可用性 |

---

### 2-3. 時系列データの保存戦略

店舗内の冷蔵ケース温度ログ・電力消費データ・機器稼働データは時系列データ。

**Amazon Timestream を選ぶ理由**:

| 比較観点 | Aurora PostgreSQL | DynamoDB | Timestream |
|---|---|---|---|
| 時系列専用圧縮 | なし | なし | あり（最大 90% 圧縮） |
| 時間範囲クエリ | インデックス要設計 | スキャンが非効率 | ネイティブサポート |
| 自動データ階層化 | なし | なし | メモリ → S3 自動移動 |
| コスト（1 億レコード/月） | 高（ストレージ課金） | 中 | 低（$0.036/百万書き込み） |
| SQL インターフェース | ○ | × | ○（SQL 互換） |

**Timestream 設計パターン（店舗温度管理）**:

```
センサーデータ収集フロー:

店舗冷蔵ケース（IoT センサー）
  → AWS IoT Core（MQTT over TLS）
  → IoT ルール → Amazon Kinesis Data Streams
  → Lambda（データ変換・バリデーション）
  → Amazon Timestream

クエリ例（過去 24 時間の異常温度検知）:
SELECT store_id, device_id, measure_value::double AS temperature, time
FROM "storcon_iot"."temperature_readings"
WHERE measure_name = 'temperature'
  AND measure_value::double > 8.0  -- 閾値: 8度超で警報
  AND time BETWEEN ago(24h) AND now()
ORDER BY time DESC
```

---

## 3. メッセージング・イベント駆動設計

### 3-1. SQS / SNS / EventBridge / Kinesis — ストコンシナリオ別の使い分け

前提レポートでは各サービスの概要を記載済み。本節では**ストコン固有の 4 データフローパターン**ごとに最適なサービス組み合わせを提示する。

#### パターン A: 店舗→本部 発注データ送信

```
[現行（オンプレ）]
店舗端末 → IP-VPN（KDDI） → 本部 FTP サーバー（夜間バッチ）

[AWS 移行後 — リアルタイム化オプション]
店舗端末
  → HTTPS POST → API Gateway
  → SQS FIFO（発注キュー）   ← 二重発注防止（exactly-once）
  → ECS Fargate（発注処理サービス）
  → Aurora PostgreSQL（発注テーブル）
  → EventBridge（発注完了イベント発火）
  → SNS → 物流パートナー通知 / マスタ在庫更新 / etc.
```

**SQS FIFO を選ぶ理由**:
- 発注処理は **順序保証** と **重複排除** が必須（二重発注は業務上致命的）
- Message Group ID = `{store_id}_{item_id}` で店舗×商品単位の順序を保証
- スループット: 3,000 msg/s（バッチ送信で解決可能）、14,663 店舗の同時発注に対応

**バッチ移行 vs リアルタイム化の判断**:

| 観点 | バッチ維持 | リアルタイム化 |
|---|---|---|
| 実装コスト | 低（SFTPをS3に置き換えるだけ） | 高（API設計・キュー設計が必要） |
| 在庫精度向上 | なし | 高（本部が即時に在庫状況を把握） |
| 店舗端末改修 | 不要 | 必要（HTTP API 対応） |
| 推奨フェーズ | Phase 1（Lift&Shift） | Phase 2〜3（Replatform 以降） |

#### パターン B: 全店舗への商品マスタ配信（Fan-out）

```
本部マスタ更新システム
  → SNS（マスタ更新トピック）
  → SQS（各地域グループのキュー × N）  ← SNS Fan-out パターン
  → Lambda（並列処理）
  → ElastiCache Redis 更新 / 店舗向け S3 プレフィックス更新

[地域グループ分割の理由]
- 14,663 店舗を一度に Lambda で処理すると同時実行数の上限に達する
- 地域（例: 東北 / 関東 / 中部 / ...）単位でグループ化し順次処理
```

#### パターン C: 売上データのリアルタイム集計

```
POS 端末（各店舗）
  → API Gateway → Kinesis Data Streams
    （シャード数: 全国同時書き込みピーク ÷ 1 MB/s で算出）
  → Lambda（フォーマット変換）
  → Kinesis Data Firehose（バッファ 1 分 / 5 MB）
  → S3（生データ保存）→ Glue Catalog → Athena（臨時クエリ）
  → Redshift（売上 DWH への定期ロード）

[リアルタイムアラート]
  Kinesis Data Streams
  → Apache Flink（Kinesis Data Analytics）
  → 異常売上パターン検知（特定商品が急激に売れている = 欠品リスク）
  → EventBridge → SNS → 本部担当者アラート
```

**Kinesis シャード数の設計**:

| 規模 | シャード数 | 書き込み上限 | 想定コスト |
|---|---|---|---|
| 開発環境 | 2 | 2 MB/s, 2,000 records/s | $0.015/時間/シャード × 2 = 約 $22/月 |
| 本番（パイロット 100 店舗） | 10 | 10 MB/s | 約 $110/月 |
| 本番（全国 14,663 店舗） | 100 以上 | 100 MB/s | 約 $1,100/月 |

※ Enhanced Fan-Out を使う場合は追加で $0.015/シャード-時間 + $0.013/GB

#### パターン D: EOS（発注支援システム）バッチ送信の段階的リアルタイム化

EOS（Electronic Ordering System）は現行バッチ（夜間一括）であることが多い。リアルタイム化には段階的移行が現実的。

```
[Step 1: バッチをそのまま S3 に移動]
オンプレ FTP サーバー → S3 バケット（SFTP サーバーレス = AWS Transfer Family）
  → S3 イベント通知 → Lambda（受信処理）

[Step 2: S3 イベント駆動化]
本部システム → S3（発注データドロップ）
  → S3 Event → SQS → ECS Fargate（発注処理）

[Step 3: リアルタイム API 化（Phase 3 以降）]
店舗端末 → REST API（API Gateway）→ SQS FIFO → ECS Fargate
```

---

### 3-2. EventBridge vs SQS vs SNS — 選択フローチャート

```
発火元は複数のサービスが購読するか？
  Yes → SNS（Fan-out）または EventBridge（複雑なルーティング）
  No  → SQS（1:1 メッセージキュー）

ルーティングルールが必要か？（送信先をイベント内容で動的に変える）
  Yes → EventBridge（詳細なフィルタリングルール）
  No  → SNS（シンプルな Fan-out）

スケジュール実行が必要か？
  Yes → EventBridge Scheduler（cron 式で定時バッチ起動）

順序保証・重複排除が必要か？
  Yes → SQS FIFO
  No  → SQS Standard（スループット無制限）

リアルタイムストリーミング（100,000 msg/s 超）が必要か？
  Yes → Kinesis Data Streams
```

---

## 4. VPC・ネットワーク設計

### 4-1. VPC 設計 — マルチ AZ・サブネット分割

#### 基本構成（東京リージョン ap-northeast-1）

```
VPC: 10.0.0.0/16（65,536 アドレス）

[AZ-a: ap-northeast-1a]           [AZ-c: ap-northeast-1c]
  Public Subnet: 10.0.1.0/24        Public Subnet: 10.0.2.0/24
  （NAT Gateway, ALB）               （NAT Gateway, ALB）

  Private App Subnet: 10.0.11.0/24  Private App Subnet: 10.0.12.0/24
  （ECS Fargate タスク）              （ECS Fargate タスク）

  Private DB Subnet: 10.0.21.0/24   Private DB Subnet: 10.0.22.0/24
  （Aurora Primary / Replica）        （Aurora Replica / DynamoDB VPC EP）

  Intra Subnet: 10.0.31.0/24        Intra Subnet: 10.0.32.0/24
  （AWS Batch, 内部処理）             （AWS Batch, 内部処理）
```

**サブネット設計の原則**:

| サブネット種別 | 配置するリソース | インターネットアクセス |
|---|---|---|
| Public | NAT Gateway, ALB, NLB | 直接アクセス可（IGW 経由） |
| Private App | ECS タスク, Lambda（VPC 内）, EC2 | NAT Gateway 経由のみ |
| Private DB | Aurora, ElastiCache, DynamoDB VPC EP | アクセス不可（VPC 内のみ） |
| Intra | AWS Batch, 内部バッチ処理 | NAT Gateway 経由のみ |

**3 層分離の理由（ストコン観点）**:
- DB 層をアプリ層から分離することで、アプリコンテナの侵害が DB に直接到達しない（PCI DSS 要件）
- Security Group でアプリ層 → DB 層の通信のみを許可（ポート 5432/3306 のみ）

---

### 4-2. KDDI IP-VPN との接続設計 — Direct Connect vs Site-to-Site VPN

ストコン案件では、店舗との通信は KDDI が提供する IP-VPN を利用しているケースが多い。本部データセンターと AWS の接続方式を選定する。

#### Direct Connect vs Site-to-Site VPN 比較

| 比較観点 | AWS Direct Connect | AWS Site-to-Site VPN |
|---|---|---|
| 帯域幅 | 1 Gbps / 10 Gbps（専用線） | 最大 1.25 Gbps（ベストエフォート） |
| レイテンシ | 低遅延・安定（物理専用線） | インターネット経由で変動あり |
| 初期コスト | 高（専用線工事費 + ポート費） | 低（ソフトウェア設定のみ） |
| 月額コスト | 高（1 Gbps ポートで約 $220/月 東京 + 転送料） | 低（接続あたり $36/月） |
| 冗長化 | 2 回線で 99.99% SLA | 2 トンネルで冗長 |
| 推奨用途 | 本番移行後の恒常的な接続 | パイロット・移行期の一時的な接続 |

**ストコン案件での推奨構成**:

```
[移行フェーズ（〜12ヶ月）]
本部 DC → Site-to-Site VPN → AWS VPC
  ↓（並行構築）
本部 DC → KDDI回線 → AWS Direct Connect（1 Gbps × 2 回線で冗長化）
  → Direct Connect Gateway
  → Virtual Private Gateway
  → AWS VPC

[本番フェーズ（12ヶ月以降）]
Direct Connect をメイン接続として使用
Site-to-Site VPN をバックアップとして維持（Direct Connect 障害時のフォールバック）
```

**Direct Connect Gateway の活用**:
- 東京リージョンの複数 VPC（本番 / 開発 / 管理）を 1 つの Direct Connect Gateway で一元接続
- Transit Gateway と組み合わせることで、VPC 間ルーティングを Transit Gateway に集約（スパイク対応の拡張性）

---

### 4-3. 14,663 店舗からの同時接続を支えるスケーリング設計

#### 通信ピーク時の設計思想

コンビニの業務ピーク（全国同時発注）は予測可能なスパイク。

```
典型的なピーク時間帯:
  朝 07:00〜09:00: 店舗オープン前の在庫確認・早朝発注
  14:00:           発注締め（弁当・総菜の発注が集中）
  22:00〜23:59:    閉店前精算・日次バッチ開始

ピーク時の同時リクエスト概算:
  14,663 店舗 × 1 発注リクエスト × 10 分で集中 = 約 24 req/s 平均
  ただしスパイク係数 3〜5 倍 = 最大 72〜120 req/s
  ※ 商品 SKU 数を含めると 14,663 店舗 × 30 SKU/発注 = 約 440,000 件/発注締め時間
```

#### API Gateway + ECS Fargate のスケーリング設計

```
[API Gateway]
  - スロットリング設定: 1 アカウントあたりデフォルト 10,000 req/s（引き上げ可能）
  - 使用量プラン: 店舗グループごとにレート制限を設定

[ALB（Application Load Balancer）]
  - クロスゾーン負荷分散: 有効
  - Sticky Session: 無効（ステートレスな API 設計が前提）
  - ヘルスチェック間隔: 10 秒

[ECS Service Auto Scaling]
  - スケールアウト条件: CPU 使用率 70% が 3 分継続
  - スケールイン条件: CPU 使用率 30% が 10 分継続
  - 最小タスク数: 4（2 AZ × 2 タスクで冗長確保）
  - 最大タスク数: 50（ピーク時のキャパシティ上限）
  - スケールアウト速度: Application Auto Scaling の Step Scaling を使用
                        （ターゲット追跡よりスパイク対応が速い）

[スケジュールスケーリング（予測的スケーリング）]
  - 発注締め 30 分前（13:30）にタスク数を最小値の 3 倍に事前拡張
  - 発注締め後 1 時間（15:00）に通常に戻す
```

**SQS によるバックプレッシャー制御**:

全国同時発注のスパイクをそのまま ECS に流すと、スケールアウトが間に合わずエラーが発生するリスクがある。SQS をバッファとして挟むことで均一化する。

```
店舗端末 → API Gateway → SQS FIFO（発注キュー）
                               ↓
                         ECS Fargate（コンシューマー）
                         ※ キューの深さ（ApproximateNumberOfMessagesVisible）
                           に応じて ECS タスク数を Auto Scaling
```

---

### 4-4. マルチリージョン設計とコスト判断

| 構成 | RTO | RPO | 月額コスト増 | ストコン適合 |
|---|---|---|---|---|
| Single Region + Multi-AZ | 1〜5 分 | 〜1 分（Aurora） | ベースライン | 通常要件 |
| Active-Passive（東京 + 大阪） | 15〜30 分 | 〜5 分 | +30〜50% | 厳格な BCP 要件がある場合 |
| Active-Active（東京 + 大阪） | 秒〜分 | ほぼゼロ | +80〜100% | 金融系・超高可用性要件 |

**ストコン移行フェーズでの推奨**: Single Region + Multi-AZ。DR 要件が明確になった後に大阪リージョンへの拡張を検討する。Aurora Global Database を使うと最小限の設定変更でマルチリージョン化可能。

---

## 5. セキュリティ設計

### 5-1. PCI DSS 対応の AWS サービス構成

コンビニでは売上データ・電子マネー決済データを扱う場合がある。PCI DSS（Payment Card Industry Data Security Standard）への対応が求められる。

#### PCI DSS v4.0 要件と AWS サービスの対応

| PCI DSS 要件 | AWS サービス | 設計ポイント |
|---|---|---|
| **要件 1: ネットワーク制御** | VPC Security Group + NACL | カード決済処理は専用 Private Subnet に分離。インバウンドは最小ポートのみ |
| **要件 2: セキュアな設定** | AWS Config Rules + Security Hub | CIS Benchmark ルールを自動チェック。非準拠リソースを即時検出 |
| **要件 3: 保存データ保護** | KMS + Aurora 暗号化 + S3 SSE | AES-256 暗号化必須。KMS CMK（Customer Managed Key）を使用 |
| **要件 4: 転送データ保護** | ACM（TLS 1.2 以上）+ VPC エンドポイント | API Gateway は HTTPS 必須。VPC 内通信も TLS 化 |
| **要件 5: マルウェア対策** | Amazon Inspector + GuardDuty | EC2/ECS の脆弱性スキャン。GuardDuty は悪意あるトラフィックを ML で検知 |
| **要件 6: セキュリティシステム開発** | CodePipeline + SAST（Snyk/Semgrep） | CI/CD パイプラインに静的解析を組み込み |
| **要件 7: アクセス制御** | IAM 最小権限 + IAM Access Analyzer | 未使用の権限を自動検出。サービスロールは定期的に見直し |
| **要件 8: ユーザー認証** | IAM Identity Center（SSO）+ MFA | 管理コンソールへのアクセスは MFA 必須 |
| **要件 10: ログ記録・監視** | CloudTrail + CloudWatch Logs + SIEM | 全 API コールをログ。CloudTrail は S3 に 7 年保存 |
| **要件 11: セキュリティテスト** | Amazon Inspector（継続的スキャン） | ECR イメージの脆弱性を Push 時に自動スキャン |
| **要件 12: 情報セキュリティポリシー** | AWS Artifact | AWS コンプライアンスレポートをダウンロード可能 |

#### PCI DSS 対応のネットワーク分離設計

```
[PCI スコープ（決済データを扱う範囲）]
  Private DB Subnet（カードデータ保存: Aurora + 暗号化）
  Private App Subnet（決済処理: ECS Fargate / タスクレベル分離）

[PCI 非スコープ]
  その他全てのサービス（発注・在庫・売上集計等）

[重要原則]
  - PCI スコープのリソースは専用 VPC または専用サブネットに分離
  - スコープとスコープ外のリソースが同一 Security Group を共有しない
  - ECS: PCI 処理は Fargate のみ（EC2 起動タイプは共有インスタンスのため不可）
```

---

### 5-2. WAF / Shield / GuardDuty の位置付け

#### WAF（Web Application Firewall）

```
配置位置: ALB または API Gateway の前段

[ストコン向け WAF ルールセット]
  - AWS Managed Rules（AWSManagedRulesCommonRuleSet）: 基本的な SQLi / XSS 対策
  - AWS Managed Rules（AWSManagedRulesKnownBadInputsRuleSet）: 既知の攻撃パターン
  - IP レート制限（IP レートベースルール）: 1 IP から 2,000 req/5 分を超えたらブロック
    ※ 店舗 IP アドレス帯は除外リストに追加（正常な大量リクエスト）
  - Geo 制限: 海外 IP からの管理コンソールアクセスをブロック

[WAF ログ]
  → Kinesis Data Firehose → S3（90 日保存）
  → 攻撃パターンの分析・レポートに活用
```

#### Shield（DDoS 防御）

| プラン | 費用 | 主な機能 | ストコン推奨 |
|---|---|---|---|
| **Shield Standard** | 無料（全 AWS アカウントに自動適用） | L3/L4 DDoS 自動防御 | 最低限として必ず有効 |
| **Shield Advanced** | $3,000/月（12 ヶ月コミット）| L7 DDoS、24/7 DDoS レスポンスチーム、コスト保護 | 大規模アタックリスクがある場合 |

**推奨**: 移行フェーズは Shield Standard。本番稼働後、セキュリティインシデントのリスク評価結果に応じて Shield Advanced を検討する。

#### GuardDuty の活用パターン

GuardDuty は ML を使って異常を自動検知する。ストコン案件での具体的なアラートシナリオ:

| 検知シナリオ | GuardDuty 検知タイプ | 対応アクション |
|---|---|---|
| EC2/コンテナが不正な外部サーバーに通信 | `UnauthorizedAccess:EC2/TorIPCaller` | 該当タスクを自動停止（Lambda + EventBridge） |
| 深夜に大量の発注データをダウンロード | `Exfiltration:S3/AnomalousBehavior` | S3 バケットポリシーを即時制限 |
| IAM ユーザーが通常と異なるリージョンから操作 | `UnauthorizedAccess:IAMUser/ConsoleLogin` | Slack 通知 + MFA 再要求 |
| クリプトマイニングツールの実行 | `CryptoCurrency:EC2/BitcoinTool` | インスタンス隔離 |

**GuardDuty → EventBridge → Lambda の自動対応フロー**:

```
GuardDuty（検知）
  → EventBridge（イベント受信）
  → Lambda（重大度に応じた自動対応）
    - Low: CloudWatch Logs に記録
    - Medium: Security Hub + Slack 通知
    - High: 該当リソースの自動停止 + PagerDuty エスカレーション
```

---

### 5-3. 暗号化戦略（at-rest / in-transit）

#### at-rest（保存時暗号化）

| データストア | 暗号化方式 | KMS キー管理 |
|---|---|---|
| Aurora PostgreSQL | AWS KMS による透過的暗号化（AES-256） | CMK（Customer Managed Key）推奨 |
| DynamoDB | AWS 所有キーまたは CMK | PCI スコープデータは CMK 必須 |
| S3（発注データ・売上データ） | SSE-KMS（AES-256） | CMK + キーローテーション（年次）有効化 |
| ElastiCache Redis | 転送中暗号化 + 保存時暗号化 | AWS 所有キーで可（キャッシュは短命データ） |
| EBS（EC2 用） | AWS KMS CMK | デフォルト暗号化を AWS アカウントレベルで有効化 |

**KMS CMK 設計のポイント**:

```
[CMK 設計原則]
  - 用途別に CMK を分離（DB 用 / S3 用 / 管理用）
  - キーポリシーで使用できるサービスロールを明示的に制限
  - キーローテーション: 自動（年次）を有効化
  - クロスアカウント共有: 原則不可（例外は申請・承認プロセスを経て）

[コスト]
  CMK 1 キーあたり $1/月 + API コール $0.03/10,000 件
  ストコン案件想定（5〜10 キー）: 約 $5〜10/月（無視できるレベル）
```

#### in-transit（転送時暗号化）

| 通信経路 | 暗号化方式 | 最低要件 |
|---|---|---|
| 店舗端末 → API Gateway | HTTPS（TLS 1.2 以上） | TLS 1.2 必須、1.0/1.1 は AWS デフォルトで無効化済み |
| ALB → ECS タスク | HTTPS（ACM 証明書）またはHTTP（VPC 内通信） | PCI スコープは VPC 内でも HTTPS |
| ECS タスク → Aurora | SSL/TLS（PostgreSQL の ssl=require） | 接続文字列に `sslmode=verify-full` を指定 |
| ECS タスク → ElastiCache | TLS（in-transit encryption 有効化） | Redis 6.x 以降で標準サポート |
| AWS DirectConnect / VPN | MACsec（Direct Connect）または IPSec（VPN） | Direct Connect の物理層でも暗号化を追加 |

---

## 6. PM視点のポイント — 移行判断材料 5 選

### PM-1: コンピューティングのロードマップを段階化する

一気に全てをサーバーレス・コンテナ化しようとするとスコープが肥大化して失敗する。**フェーズ分け**が重要。

| フェーズ | コンピューティング構成 | 期間目安 |
|---|---|---|
| Phase 1（Lift&Shift） | EC2（MGN で移行したまま） | 3〜6 ヶ月 |
| Phase 2（Replatform） | ECS Fargate + Lambda（コンテナ化） | 6〜12 ヶ月 |
| Phase 3（Modernize） | Step Functions + Kinesis（イベント駆動化） | 12〜24 ヶ月 |
| Phase 4（Optimize） | EKS（必要であれば）+ Spot Instance 活用 | 24 ヶ月以降 |

**PM として抑えるべき**: Phase 1 → Phase 2 への移行タイミングの判断基準を事前に設定しておく（例: EC2 の利用コストが一定額を超えたら、または安定稼働 6 ヶ月後に移行検討を開始）。

### PM-2: データベース移行の「ロールバック不可点」を把握する

DMS でのデータ移行中は旧 DB への書き込みを維持しつつ新 DB に同期する「デュアルライト期間」がある。この期間終了後（カットオーバー後）は旧 DB へのロールバックが困難になる。

```
カットオーバー判断の Go / No-Go 基準:
  - 移行後 DB のレプリケーション遅延: 5 秒以内
  - 移行後 DB の整合性チェック: 全テーブルの件数・チェックサムが一致
  - アプリケーションの動作確認: ステージング環境で全機能テスト通過
  - 運用チームの体制: 24 時間対応できる人員が確保できていること
```

### PM-3: KDDI との接続は早期に交渉・発注する

Direct Connect の開通は、回線発注から物理敷設まで **3〜6 ヶ月のリードタイム**がかかる。移行プロジェクトのクリティカルパスになりやすい。

**アクションアイテム**:
1. 移行開始の 6 ヶ月前に KDDI と Direct Connect の見積もり依頼
2. AWS Direct Connect パートナー（KDDI は APN パートナー）経由で発注
3. 開通まではサイト間 VPN でパイロット移行を先行実施

### PM-4: セキュリティ・コンプライアンスのスコープを早期に確定する

PCI DSS 対応が必要かどうかは**プロジェクト開始時に確定**しておかないと、後からアーキテクチャを変更するコストが甚大になる。

**確認事項チェックリスト**:
- [ ] クレジットカード決済データ（PAN: Primary Account Number）をストコンシステムで保持するか？
- [ ] 電子マネー（Suica / nanaco 等）のトランザクションデータが含まれるか？
- [ ] 決済代行会社（PAY.JP / SBペイメントサービス等）との連携があるか？
- [ ] 個人情報保護法対応（会員データの保持）が必要か？

PCI DSS 対象となる場合、**QSA（Qualified Security Assessor）による審査**が必要で、アーキテクチャ確定後に 3〜6 ヶ月の審査期間が発生する。

### PM-5: 14,663 店舗への展開はウェーブ方式で行う

一斉展開は不具合発生時のリスクが高すぎる。段階的なウェーブ展開（Canary Release）を計画する。

```
推奨ウェーブ展開計画:

Wave 0 - 検証（〜移行前 3 ヶ月）
  対象: 社内テスト環境 + 直営 10 店舗
  目的: アーキテクチャの動作確認・負荷テスト

Wave 1 - パイロット（移行 1〜3 ヶ月）
  対象: 特定都市の 100 店舗（地域・業態をバランス良く選定）
  判断基準: 発注エラー率 < 0.1% / レイテンシ P99 < 500ms / 障害件数ゼロ

Wave 2 - 広域展開（移行 3〜6 ヶ月）
  対象: 全国 3,000 店舗（Wave 1 の知見を反映）
  判断基準: Wave 1 と同じ KPI を維持

Wave 3 - 全国展開（移行 6〜12 ヶ月）
  対象: 残り全 14,563 店舗
  判断基準: Wave 2 の KPI 維持 + 運用チームの対応能力確認
```

---

## 7. 設計パターンサマリー（比較表）

### コンピューティング選定 最終推奨

| ワークロード | 推奨 | 代替 | 採用しない |
|---|---|---|---|
| 常時起動 REST API（発注・在庫） | ECS Fargate | EC2 + ASG | Lambda（コールドスタート） |
| イベント駆動・軽量処理 | Lambda | ECS Fargate | EKS（オーバースペック） |
| 大規模日次バッチ | AWS Batch（Fargate） | ECS（スケジュール） | Lambda（15 分制限） |
| バッチフロー制御 | Step Functions | Lambda | なし |
| マルチクラウド・K8s 資産活用 | EKS on Fargate | EKS on EC2 | ECS（K8s 資産非互換） |

### DB選定 最終推奨

| データ種別 | 推奨 DB | 補完 | 採用しない |
|---|---|---|---|
| 発注トランザクション（ACID） | Aurora PostgreSQL Multi-AZ | RDS PostgreSQL | DynamoDB（RDB 整合性非対応） |
| 商品マスタ（読み取り重視） | Aurora PostgreSQL + ElastiCache | Aurora Serverless v2 | DynamoDB（複雑な JOIN 不可） |
| 在庫カウンタ（高頻度更新） | DynamoDB（アトミックカウンタ） | Aurora（競合率が低い場合） | RDS（行ロック競合） |
| 時系列（温度・センサー） | Amazon Timestream | DynamoDB + TTL | Aurora（時系列最適化なし） |
| 売上分析・BI | Redshift Serverless | Athena + S3 | Aurora（分析クエリが遅い） |

### メッセージング選定 最終推奨

| ユースケース | 推奨 | 理由 |
|---|---|---|
| 発注処理（順序・重複排除） | SQS FIFO | 二重発注防止必須 |
| マスタ配信 Fan-out | SNS → SQS | 複数の購読者に配信 |
| イベントルーティング | EventBridge | フィルタリングルール |
| スケジュールバッチ | EventBridge Scheduler | cron 実行 |
| 売上ストリーミング | Kinesis Data Streams | 高スループット・順序保証 |

### ネットワーク接続 最終推奨

| 接続パターン | 推奨 | 期間 |
|---|---|---|
| 本部 DC → AWS（恒常的） | Direct Connect 1 Gbps × 2 系統 | 本番移行後 |
| 本部 DC → AWS（移行期） | Site-to-Site VPN（DR 兼務） | 移行フェーズ |
| 店舗 → AWS（インターネット） | HTTPS over API Gateway（WAF 付き） | 全期間 |
| VPC 内サービス間通信 | VPC エンドポイント（プライベートリンク） | 全期間（インターネット回避） |

---

## 8. Sources

以下の公式ドキュメント・ガイダンスを参照した（知識カットオフ 2025年8月時点の情報）。

| カテゴリ | リソース | URL |
|---|---|---|
| コンテナ | Amazon ECS Developer Guide | https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ |
| コンテナ | AWS Fargate User Guide | https://docs.aws.amazon.com/AmazonECS/latest/userguide/what-is-fargate.html |
| コンテナ | ECS vs EKS 判断ガイド | https://docs.aws.amazon.com/decision-guides/latest/modern-apps-strategy-on-aws-how-to-choose/ |
| DB | Amazon Aurora User Guide | https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/ |
| DB | Amazon DynamoDB Developer Guide | https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/ |
| DB | Amazon Timestream Developer Guide | https://docs.aws.amazon.com/timestream/latest/developerguide/ |
| メッセージング | Amazon SQS Developer Guide | https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/ |
| メッセージング | Amazon EventBridge User Guide | https://docs.aws.amazon.com/eventbridge/latest/userguide/ |
| メッセージング | Amazon Kinesis Data Streams Developer Guide | https://docs.aws.amazon.com/streams/latest/dev/ |
| ネットワーク | Amazon VPC User Guide | https://docs.aws.amazon.com/vpc/latest/userguide/ |
| ネットワーク | AWS Direct Connect User Guide | https://docs.aws.amazon.com/directconnect/latest/UserGuide/ |
| ネットワーク | AWS Transit Gateway Guide | https://docs.aws.amazon.com/vpc/latest/tgw/ |
| セキュリティ | AWS WAF Developer Guide | https://docs.aws.amazon.com/waf/latest/developerguide/ |
| セキュリティ | Amazon GuardDuty User Guide | https://docs.aws.amazon.com/guardduty/latest/ug/ |
| セキュリティ | AWS Shield Developer Guide | https://docs.aws.amazon.com/waf/latest/developerguide/shield-chapter.html |
| セキュリティ | AWS KMS Developer Guide | https://docs.aws.amazon.com/kms/latest/developerguide/ |
| セキュリティ | AWS Security Hub User Guide | https://docs.aws.amazon.com/securityhub/latest/userguide/ |
| コンプライアンス | AWS PCI DSS コンプライアンス | https://aws.amazon.com/compliance/pci-dss-level-1-faqs/ |
| Well-Architected | AWS Well-Architected Framework | https://docs.aws.amazon.com/wellarchitected/latest/framework/welcome.html |
| 移行 | AWS Prescriptive Guidance（Strangler Fig） | https://docs.aws.amazon.com/prescriptive-guidance/latest/modernization-decomposing-monoliths/ |
| モダナイゼーション | AWS Migration Hub Refactor Spaces | https://docs.aws.amazon.com/migrationhub-refactor-spaces/latest/userguide/ |
| スケーリング | Application Auto Scaling User Guide | https://docs.aws.amazon.com/autoscaling/application/userguide/ |

---

*本レポートは tech-researcher が 2026-04-12 時点の情報をもとに作成しました。*
*前提レポート（wbs-5-2-storcon-aws-migration-tech.md / wbs-5-2-storcon-aws-modernization-analytics.md）の内容との重複を避け、設計判断の根拠・具体的な設計パターン・PM 視点のアクションに特化しています。*
*AWS サービスは頻繁に更新されるため、最新情報は AWS 公式ドキュメントで確認してください。*
