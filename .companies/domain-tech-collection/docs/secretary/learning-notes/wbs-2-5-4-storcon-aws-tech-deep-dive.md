# ストアコンピューター AWS移行 技術スタック深堀り調査レポート

- **調査目的**: 2026年6月参画予定のストコンAWS移行案件に向け、PM視点での技術理解の深化
- **作成日**: 2026-03-25
- **作成者**: retail-domain-researcher
- **前提資料**: `store-computer-aws-migration-tech.md`（技術スタック概要・2026-03-21）

---

## 目次

1. [調査概要（目的・手法・既存資料との差分）](#1-調査概要)
2. [移行に重要なAWSサービス詳細](#2-移行に重要なawsサービス詳細)
3. [移行ベストプラクティス](#3-移行ベストプラクティス)
4. [ネットワーク・エッジ戦略](#4-ネットワークエッジ戦略)
5. [データ移行戦略](#5-データ移行戦略)
6. [学習ロードマップ（Must/Should/Nice-to-have）](#6-学習ロードマップ)
7. [参考リソース一覧](#7-参考リソース一覧)

---

## 1. 調査概要

### 目的

既存資料（`store-computer-aws-migration-tech.md`）は各AWSサービスの概要・ユースケース一覧を網羅している。本レポートはその**次のレイヤー**として、以下に集中する。

- 移行フェーズで実際に直面する設定ポイント・落とし穴
- サービス間の組み合わせパターンと選択根拠
- PMとして意思決定・レビューに必要な技術的判断基準
- 東京リージョン（ap-northeast-1）での利用可否・特記事項

### 手法

- AWS公式ドキュメント（docs.aws.amazon.com）の深読み
- AWS Well-Architected Framework レビュー
- 移行専門サービス（DMS/MGN/SCT）の詳細仕様確認
- 小売・店舗システム向けリファレンスアーキテクチャの分析

### 既存資料との差分

| 既存資料でカバー済み | 本レポートで追加する内容 |
|-------------------|----------------------|
| 各サービスの概要と代表ユースケース | DMS/MGNの具体的な移行手順・設定オプション |
| 7R移行戦略の概要説明 | MAP（Migration Acceleration Program）の活用法 |
| ネットワーク構成の概念図 | Transit Gateway / Direct Connect の具体的設計パターン |
| IoT Core / Outposts の1行説明 | Greengrass v2 の店舗実装パターン詳細 |
| 東京リージョン利用を前提として記述 | 主要サービスの東京リージョン利用可否・制約 |

---

## 2. 移行に重要なAWSサービス詳細

### 2-1. AWS Database Migration Service (DMS)

**公式ドキュメント**: https://docs.aws.amazon.com/dms/latest/userguide/Welcome.html

#### ストコン移行における位置付け

ストコンが持つオンプレDBは大多数がOracle Database または SQL Server（Windows Server上）で構築されている。これをAWS Aurora（MySQL/PostgreSQL互換）へ移行する際のコアツールがDMSである。

#### DMSの内部構造

```
[オンプレ / ソースDB]
   Oracle / SQL Server / DB2 / etc.
         |
   [DMS レプリケーションインスタンス]  ← EC2ベースの専用VM
         |
   [ターゲットDB]
   Aurora MySQL / Aurora PostgreSQL / DynamoDB / Redshift等
```

DMSは以下の2段階で動作する：

1. **フルロード（Full Load）**: ソースDBの全データを一括コピー（移行開始時の初期ロード）
2. **CDC（Change Data Capture）**: フルロード完了後、ソースDBの変更分（INSERT/UPDATE/DELETE）をリアルタイムに追跡してターゲットDBに反映

#### 重要な設定オプション

| 設定項目 | 選択肢 | ストコン推奨 | 理由 |
|---------|--------|------------|------|
| レプリケーションインスタンスサイズ | dms.r6g.large〜dms.r6g.4xlarge | dms.r6g.xlarge | 全国数万店分の初期ロード対応 |
| マルチAZ | あり/なし | あり | 移行期間中のDMS障害を回避 |
| ロードタイプ | Full Load / CDC / Full Load + CDC | Full Load + CDC | カットオーバー直前まで差分同期を継続 |
| LOB（Large Object）扱い | Limited LOB / Full LOB / Inline LOB | Limited LOB | 大容量BLOBが少ない場合はパフォーマンス優先 |

#### CDCのソース設定（Oracleの場合）

OracleをソースとするCDCには **LogMiner** または **Binary Reader** の2方式がある。

| 方式 | 仕組み | メリット | デメリット |
|-----|--------|---------|-----------|
| LogMiner | OracleのARCHIVELOGを読む | 設定が容易 | スループット上限あり（大規模環境では不足） |
| Binary Reader | Oracle REDOログを直接読む | 高スループット | DMS設定が複雑。Oracle Advanced Security Optionが不要 |

**ストコン推奨**: 全国数万店舗からのCDCが必要なため、大規模環境では **Binary Reader** を選択。ただしOracle DBAとの事前調整が必須。

#### Schema Conversion Tool (SCT) との連携

DMSはデータ移行ツールであり、**スキーマ（テーブル定義・プロシージャ・トリガー）の変換はSCTが担う**。

```
SCT（スキーマ変換）→ DMS（データ移行）の順序
1. SCTでOracleスキーマをAurora MySQL/PostgreSQL向けに変換
   → 自動変換できないPL/SQL手続きは「変換レポート」として抽出
   → 変換できなかった部分は手動でSQL書き換えが必要（工数の主因）
2. SCT変換済みスキーマをターゲットDBに適用
3. DMSでフルロード + CDCを実行
```

**PMとして知っておくべき落とし穴**:
- Oracleストアドプロシージャ・パッケージはSCTでの自動変換率が低い（複雑なPL/SQLほど手動対応が増える）
- 変換工数の見積もりにSCTの「評価レポート」機能を活用すること（事前にソースDB接続して自動評価→移行難易度スコアが出力される）
- DMSのレプリケーションインスタンスはVPCの**プライベートサブネット**に配置し、ソースDB・ターゲットDB両方への経路を確保する必要がある

#### 参考: 東京リージョン（ap-northeast-1）でのDMS利用可否

DMS（DMSレプリケーションインスタンス）は ap-northeast-1 で利用可能。対応ソースDBは下表の通り。

| ソースDB | DMS対応 | CDC対応 |
|---------|---------|---------|
| Oracle 11g〜21c | 対応 | 対応（LogMiner / Binary Reader） |
| SQL Server 2012〜2022 | 対応 | 対応（MS-CDC） |
| MySQL 5.7〜8.0 | 対応 | 対応（binlog） |
| PostgreSQL 9.4〜15 | 対応 | 対応（pglogical / test_decoding） |
| DB2 LUW 9.7〜11.5 | 対応 | 対応 |

**参考URL**: https://docs.aws.amazon.com/dms/latest/userguide/CHAP_Source.html

---

### 2-2. AWS Application Migration Service (MGN)

**公式ドキュメント**: https://docs.aws.amazon.com/mgn/latest/ug/what-is-application-migration-service.html

#### ストコン移行における位置付け

DMS がDBのデータ移行ツールであるのに対し、MGNは**サーバー丸ごと（OS+ミドルウェア+アプリケーション）をAWSへ移行**するツール。ストコンの本部システム（アプリサーバー群）のLift&Shift初期フェーズで活用する。

#### MGNの動作原理

```
[オンプレ アプリサーバー]
  Windows Server / Linux
  　　↓ AWS Replication Agent インストール（エージェント型）
[AWS MGN サービス]
  ブロックレベルのリアルタイムレプリケーション
  　　↓
[AWS ステージングエリア（低コストEC2）]
  データのバッファリング
  　　↓ カットオーバー時にスナップショット変換
[本番EC2インスタンス]
  本番スペックのEC2として起動
```

**MGNとSMS（旧サービス）の違い**: AWS Server Migration Service（SMS）は2022年3月に新規利用停止、MGNが後継。MGNはブロックレベルの継続レプリケーションにより**カットオーバー時のダウンタイムを分単位に短縮**できる。

#### 重要な設定と手順

**Phase 1: レプリケーション設定**
- 各オンプレサーバーにAWS Replication Agentをインストール
- エージェントが自動でMGNサービスに接続し、ブロックデバイスのレプリケーション開始
- レプリケーション状態は MGN コンソールで一元管理

**Phase 2: テストカットオーバー**
- 本番移行前に「テスト起動」を実施。AWS側でEC2が起動し動作確認できる
- テスト起動中も元サーバーはレプリケーション継続（本番影響なし）

**Phase 3: 本番カットオーバー**
- メンテナンスウィンドウ（コンビニの場合 深夜2〜4時が候補）にカットオーバーを実行
- MGNがレプリケーションを停止し、最終スナップショットからEC2を本番起動
- DNS/ロードバランサーの向き先を新EC2に変更して切り替え完了

**PMとして知っておくべき重要事項**:
- MGNは**Windows Server 2012 R2以降、主要Linuxディストリビューション**に対応（非常に古いOS = Windows Server 2008等は事前確認が必要）
- Agentインストールには対象サーバーへの管理者権限が必要。情報セキュリティ部門との事前調整が必須
- 移行後のEC2インスタンスタイプ選定に「MGN Post-launch Settings」でSystem Managerを使った自動設定が可能
- ストコンの本部アプリは**ステートフルな処理**（セッション保持等）が多いため、カットオーバー直前の動作確認リストの事前作成が重要

**参考URL**: https://docs.aws.amazon.com/mgn/latest/ug/Launching-test-instances.html

---

### 2-3. AWS Outposts / Local Zones

**公式ドキュメント**: https://docs.aws.amazon.com/outposts/latest/userguide/what-is-outposts.html

#### ストコンでの現実的な活用シーン

**AWS Outposts（フルラック型）**: AWSのサーバーラックをオンプレ/コロケーションに設置。AWS APIをそのままオンプレで利用可能。

**ストコンでの適合シーン**:
- 地域DCへの設置（全国数十か所の地域物流センターにOutpostsを設置し、店舗との低レイテンシを確保）
- 金融・POSデータのデータレジデンシー要件がある場合（国内DC内にデータを置きつつAWS管理基盤を使いたい）
- コロケーション施設（IDCフロンティア、エクイニクス等）への設置

**Outpostsが非現実的なシーン**:
- 全国各店舗への1台ずつ設置（コスト面で不採算）
- 設置スペースが確保できない小型店舗

**Outposts Rack vs. Outposts Servers**:

| タイプ | 容量 | 最小単位 | 価格帯 | 適合場面 |
|-------|------|---------|--------|---------|
| Outposts Rack | 42U フルラック | 1ラック（大容量） | 数百万円/月〜 | 地域DC・大規模コロケーション |
| Outposts Servers (1U/2U) | 小型 | 1台 | 数万円/月〜 | 中規模店舗バックヤード、エッジロケーション |

**Local Zones**（東京エリアでの活用）:
- 大阪 Local Zone: なし（2026年3月時点で未提供）
- 東京リージョン自体が ap-northeast-1（東京）に3AZあり、国内での低レイテンシは概ねカバー
- **コンビニ案件でLocal Zonesが必要になるシーンは限定的**

**参考URL**: https://aws.amazon.com/outposts/rack/ / https://aws.amazon.com/outposts/servers/

---

### 2-4. Amazon MSK (Managed Streaming for Apache Kafka) / Kinesis

**MSK公式ドキュメント**: https://docs.aws.amazon.com/msk/latest/developerguide/what-is-msk.html
**Kinesis公式ドキュメント**: https://docs.aws.amazon.com/kinesis/latest/APIReference/Welcome.html

#### MSK vs. Kinesis — ストコン移行での選択判断

既存資料ではKinesisの概要は記載済み。本レポートでは**MSKとKinesisの使い分け判断基準**を深堀りする。

| 比較軸 | Amazon MSK (Kafka) | Amazon Kinesis Data Streams |
|-------|-------------------|---------------------------|
| プロトコル | Apache Kafka互換 | AWS独自 |
| 既存Kafkaの移行 | 設定変更のみで移行可 | アプリ書き換えが必要 |
| メッセージ保持期間 | デフォルト7日（最大無制限） | デフォルト24時間（最大365日） |
| スループット上限 | パーティション数で水平スケール | シャード数で制御（1シャード=1MB/s入力） |
| コスト構造 | ブローカーインスタンス課金 | シャード時間+データ量課金 |
| 運用複雑性 | 高（Kafka知識が必要） | 低（AWSマネージド） |
| ストコンでの用途 | 既存Kafkaベースの本部システム移行 | 新規構築の店舗→クラウドデータパイプライン |

**ストコン移行での推奨パターン**:

- **新規構築**: Amazon Kinesis Data Streams + Kinesis Data Firehose（シンプル・運用コスト低）
- **既存KafkaクラスターのAWS移行**: Amazon MSK（アプリの書き換えが最小）
- **大規模イベントストリーミング（イベント数十万/秒超）**: Amazon MSK（Kafkaのパーティション分割でスケール）

#### MSKの具体的設定（ストコン本部システム向け）

```
[MSK クラスター設計例]
- ブローカー数: 3（Multi-AZ。ap-northeast-1 の 3AZ に分散）
- ブローカータイプ: kafka.m5.large（中規模）〜 kafka.m5.4xlarge（大規模）
- ストレージ: 1 TB × 3ブローカー（必要に応じてAuto Scaling有効化）
- トピック例:
  - store-orders（発注データ）
  - store-pos-events（POS売上イベント）
  - store-inventory（在庫更新イベント）
  - master-sync（商品マスタ同期）
```

**MSK Serverless（2022年GA）**: ブローカー管理不要のサーバーレスKafka。スループットが変動する場合や、Kafkaクラスター管理スキルがチームにない場合に適している。

**参考URL**: https://docs.aws.amazon.com/msk/latest/developerguide/msk-configuration.html

---

### 2-5. AWS IoT Core / IoT Greengrass

**IoT Core公式ドキュメント**: https://docs.aws.amazon.com/iot/latest/developerguide/what-is-aws-iot.html
**Greengrass公式ドキュメント**: https://docs.aws.amazon.com/greengrass/v2/developerguide/what-is-iot-greengrass.html

#### ストコン移行でのIoT活用シーン

コンビニ店舗にはPOS端末・セルフレジ・温度センサー（冷蔵庫/冷凍ケース）・電力メーター・デジタルサイネージ等の多数のデバイスが設置されている。

**AWS IoT Core**: クラウド側のMQTTブローカー。デバイスからのデータ受信・ルーティング・Rules Engineによる処理振り分けを担う。

**AWS IoT Greengrass v2**: 店舗端末（Raspberry Pi、産業用Linux機器等）にインストールするエッジランタイム。店舗ネットワーク障害時もローカル処理を継続できる。

#### Greengrass v2 の店舗実装パターン

```
[店舗内]
┌─────────────────────────────────────────────────────┐
│  POS端末      冷蔵ケース温度センサー    電力メーター │
│    │               │                     │          │
│    └───────────────┴─────────────────────┘          │
│                    │ MQTT (ローカル)                 │
│         [Greengrass v2 コア デバイス]               │
│           (店舗バックヤードの Linux PC)              │
│            ↑ ローカル推論（Lambda関数として動作）    │
│            ↑ オフライン時はローカルキャッシュで処理  │
└─────────────────────────────────────────────────────┘
                    │ MQTT over TLS (HTTPS)
              [AWS IoT Core]
                    │
           ┌────────┴────────┐
    [Kinesis]        [Lambda / Rules Engine]
    (ストリーミング)     (アラート、DB書き込み)
           │
    [Timestream / S3 / DynamoDB]
```

**Greengrass v2 コンポーネント**:
- **Stream Manager**: センサーデータをローカルでバッファリングし、クラウドへの転送を管理。ネットワーク障害時は自動的にローカルに蓄積し、復旧後に再送信
- **Shadow Service**: デバイスの「状態（Shadow）」をローカルとクラウドで同期。ネットワーク断絶中はローカルShadowを参照
- **Secret Manager Integration**: デバイス証明書・APIキーをSecretsManagerで安全管理

**セキュリティの重要点**:
- IoTデバイス認証は **X.509証明書**ベース（IDとパスワードではなく）
- 証明書のローテーションスケジュールを事前に計画すること（数万デバイスの一斉ローテーションは計画的管理が必要）
- デバイスポリシーは最小権限原則（発注デバイスは発注トピックのみ発行可等）

**参考URL**: https://docs.aws.amazon.com/greengrass/v2/developerguide/greengrass-nucleus-component.html

---

### 2-6. AWS Direct Connect

**公式ドキュメント**: https://docs.aws.amazon.com/directconnect/latest/UserGuide/Welcome.html

#### ストコン移行でDirect Connectが必要な場面

VPNはインターネット経由であり、帯域保証・レイテンシ安定性に限界がある。以下の要件がある場合はDirect Connectを検討する。

| 要件 | VPNで対応可か | Direct Connect推奨場面 |
|-----|-------------|---------------------|
| 帯域幅 < 1Gbps | 対応可 | 1Gbps超が必要な場合 |
| レイテンシ変動許容 | 対応可 | レイテンシ安定性が必須（決済系等） |
| 本部DC〜AWS間の大規模データ転送 | コスト高 | 月数TB超のデータ転送で必須 |
| 移行期間中のハイブリッド接続 | リスクあり | 移行期間中の安定接続が必要な場合 |

#### Direct Connectの接続形態

```
[コンビニ本部DC]
      │ 専用回線（1Gbps / 10Gbps）
[AWS Direct Connect ロケーション]
  （東京: Equinix TY2, TY4, TY8 等）
      │ Virtual Interface (VIF)
[AWS VPC / Transit Gateway]
```

**接続タイプ**:

| タイプ | 特徴 | 推奨場面 |
|-------|------|---------|
| 専用接続（Dedicated）| 1/10/100Gbps 単独占有 | 大規模・高帯域が必要な場合 |
| ホスト型接続（Hosted）| 50Mbps〜10Gbps パートナー経由 | 中規模・導入コスト抑制 |

**東京のDirect Connect ロケーション（ap-northeast-1向け）**:
- Equinix TY2（東京）
- Equinix TY4（東京）
- Equinix TY8（東京）
- AT TOKYO CC1（東京）
- Colt Tokyo（東京）

**Direct Connect Gateway（DXG）の活用**: 1本のDirect Connect接続から複数リージョンのVPCに接続できる。東京リージョン+大阪リージョン（DR用）へ1本の専用線から接続可能。

**参考URL**: https://docs.aws.amazon.com/directconnect/latest/UserGuide/direct-connect-gateways-intro.html

---

### 2-7. AWS Transit Gateway

**公式ドキュメント**: https://docs.aws.amazon.com/vpc/latest/tgw/what-is-transit-gateway.html

#### 多店舗環境でのネットワーク設計課題

コンビニのAWS環境では以下のVPCが典型的に必要になる。

```
[環境別VPC]
  VPC-prod-app（本番アプリケーション）
  VPC-prod-db（本番DB専用）
  VPC-staging（ステージング環境）
  VPC-mgmt（運用管理・踏み台サーバー）
  VPC-security（WAF・ログ収集）
  VPC-shared-services（共有サービス: DNS、NTP等）
```

Transit Gatewayなしで全VPCをピアリングすると、VPC数がNの場合 N×(N-1)/2 の接続が必要になり管理が複雑化する。

#### Transit Gatewayによる集約設計

```
[Transit Gateway: ハブ and スポーク]

  VPC-prod-app ──┐
  VPC-prod-db  ──┤
  VPC-staging  ──┼── [Transit Gateway] ──── [Direct Connect Gateway]
  VPC-mgmt     ──┤                     └─── [VPN（バックアップ回線）]
  VPC-security ──┘
                       ↓
                [オンプレ 本部DC]
```

**ルートテーブルの分離設計**:

Transit Gatewayは複数のルートテーブルを持てる。セキュリティゾーン分離に活用。

```
ルートテーブル1: 本番用
  → prod-app VPC, prod-db VPC のみ相互通信許可
ルートテーブル2: 管理用
  → mgmt VPCから全VPCへのアクセス許可
ルートテーブル3: オンプレ接続用
  → Direct Connectアタッチメント → 全VPCへのルート
```

**Network Manager**: Transit Gatewayを使ったネットワーク全体のトポロジーを可視化するツール。多VPC環境の運用管理に推奨。

**コスト留意点**:
- Transit Gatewayは**アタッチメント時間課金 + データ処理量課金**
- VPC間通信が多い場合はVPC Peeringの方がコスト低になるケースも
- 東京リージョン: $0.07/時間（アタッチメント1件あたり）+ $0.02/GB（データ処理）

**参考URL**: https://docs.aws.amazon.com/vpc/latest/tgw/tgw-route-tables.html

---

## 3. 移行ベストプラクティス

### 3-1. AWS Migration Acceleration Program (MAP)

**公式URL**: https://aws.amazon.com/migration-acceleration-program/

MAPはAWSが提供する大規模移行支援プログラム。**ストコンのような大規模エンタープライズ移行案件では必ず確認すべきプログラム**。

#### MAPの3フェーズ構造

```
[Phase 1: Assess（評価）]  約4〜8週間
  - AWS Migration Evaluator（旧: TSO Logic）でコスト評価
  - Application Portfolio Assessment でアプリ棚卸し
  - 成果物: 移行ビジネスケース（ROI試算）
        ↓
[Phase 2: Mobilize（準備）]  約3〜6ヶ月
  - AWS Landing Zone (Control Tower) の構築
  - CI/CDパイプライン・セキュリティ基盤の整備
  - パイロット移行（代表的なシステムを先行移行）
  - 移行ファクトリー（反復移行の自動化）の構築
        ↓
[Phase 3: Migrate & Modernize（移行・モダナイズ）]
  - 本格移行実行（移行ファクトリーで量産）
  - 移行後のモダナイズ（コンテナ化・サーバーレス化）
```

**MAP の資金援助**:
- AWS Funding（パートナーへの技術支援費用補助）
- MigrationHub Refactor Spaces（移行中のトラフィック管理支援）

PMとして: **SIerとしてMAPパートナー認定を取得している**か確認すること。パートナー認定があることで顧客へのAWS補助金申請が可能になる。

### 3-2. AWS Landing Zone / Control Tower

**公式ドキュメント**: https://docs.aws.amazon.com/controltower/latest/userguide/what-is-control-tower.html

大規模移行では最初に**マルチアカウント設計**を確立することが重要。コンビニ本部+店舗システムでは以下が典型構成。

```
[AWS Organizations]
├── Root
│   ├── Security OU（セキュリティ・ログ集約）
│   │   ├── Log Archive アカウント（CloudTrail/Config ログ集約）
│   │   └── Security Tooling アカウント（GuardDuty/SecurityHub 集約）
│   ├── Production OU
│   │   ├── Production アカウント（本番環境）
│   │   └── DR アカウント（大阪リージョンDR）
│   ├── Non-Production OU
│   │   ├── Staging アカウント
│   │   └── Development アカウント
│   └── Sandbox OU
│       └── 開発者個人サンドボックス
```

**Control Tower のガードレール（Guardrails）**:
- 強制的ガードレール（Mandatory）: 無効化不可。例: CloudTrail有効化、MFA強制
- 強く推奨ガードレール（Strongly Recommended）: 例: S3パブリックアクセス禁止、EBSデフォルト暗号化
- 選択的ガードレール（Elective）: 環境に応じて選択

### 3-3. Well-Architected Framework — 小売向け重点ポイント

**信頼性ピラーの具体的実装（ストコン向け）**:

| 要件 | AWSベストプラクティス | 具体的設定 |
|-----|-------------------|---------|
| RTO < 30分 | Multi-AZ + Auto Scaling | RDS Multi-AZ + ECS Auto Scaling + Route 53 ヘルスチェック |
| RPO < 5分 | Aurora の継続的バックアップ | RDS自動バックアップ（1分間隔PITR）+ Aurora Global Database |
| 24/365稼働 | AZ障害耐性設計 | 各AZに最低2タスク、AZ障害時の自動フェイルオーバー |
| 全国店舗の同時アクセス | キューイングによる流量制御 | SQS + Lambda/ECS のバックプレッシャー設計 |

**コスト最適化の実践（PMが把握すべき）**:

| サービス | コスト最適化手法 | 削減率目安 |
|---------|--------------|----------|
| EC2/RDS | リザーブドインスタンス（1年/3年） | 30〜60% OFF |
| EC2（バッチ処理） | Spot Instance | 最大90% OFF |
| RDS Aurora | Aurora I/O-Optimized（高I/Oワークロード） | I/O課金を定額に |
| S3 | Intelligent-Tiering（アクセス頻度不明なデータ） | 最大70% OFF |
| Lambda | Compute Savings Plans | 最大17% OFF |

---

## 4. ネットワーク・エッジ戦略

### 4-1. 多店舗環境の通信設計パターン

コンビニのネットワーク設計には以下の特殊性がある。

- 全国数万店舗が同じクラウドエンドポイントに接続
- 各店舗は NURO光、フレッツ等のインターネット回線（専用線は一般的でない）
- 一部店舗でのネットワーク障害が他店舗に影響しない設計が必須

#### 推奨パターン: インターネット経由 + API Gateway

```
[各店舗] ── Internet ── [CloudFront] ── [API Gateway] ── [ALB] ── [ECS]
  ↑                        ↑
 HTTPS/TLS 1.2+        エッジキャッシュ（マスタデータ配信に有効）
 クライアント証明書認証    DDoS保護（AWS Shield）
```

**店舗認証の設計**:
- 各店舗に発行した**クライアント証明書**でmTLS認証（API Gatewayのmutual TLS機能）
- 証明書のシリアル番号を店舗IDに紐付け、不正な店舗端末からのアクセスを遮断

#### 店舗ネットワーク障害時の設計（重要）

```
[正常時]   店舗端末 ←HTTPS→ クラウドAPI
           ↓                 ↓
        リアルタイム同期    商品マスタ最新版

[障害時]   店舗端末 ← ローカルキャッシュ参照
           ↓
        オフライン発注（ローカルキューに蓄積）
        ↓
[復旧後]   差分同期処理（再接続時に自動実行）
           重複排除処理（冪等性キーで二重発注防止）
```

**冪等性キーの設計**（重要）:
- 各発注トランザクションに `{店舗ID}-{日付}-{シーケンス番号}` の一意キーを付与
- SQS FIFOの `MessageDeduplicationId` に設定することで二重処理を防止
- DynamoDBの条件付き書き込みで冪等性チェック

### 4-2. CloudFront + API Gateway によるエッジ最適化

コンビニの商品マスタ（数十万SKU）の更新データをAPIで全店舗に配信する場合、無策ではAPIサーバーへの負荷が集中する。

**CloudFrontキャッシュ戦略**:

| コンテンツ種別 | キャッシュ設定 | TTL | 更新方法 |
|-------------|------------|-----|---------|
| 商品マスタ（変更頻度: 日次） | キャッシュあり | 24時間 | バージョン番号ベースのURL（キャッシュ無効化不要） |
| 価格情報（変更頻度: 日次〜週次） | キャッシュあり | 12時間 | CloudFront Invalidation |
| 在庫カウント（変更頻度: リアルタイム） | キャッシュなし | 0 | 常にオリジンへルーティング |
| 発注API（書き込み系） | キャッシュなし | 0 | 常にオリジンへルーティング |

---

## 5. データ移行戦略

### 5-1. ダウンタイム最小化の具体的手順

ストコンの本番移行でダウンタイムを最小化するための段階的アプローチ。

```
Step 1: DMS フルロード（事前実施、業務影響なし）
  期間: 1〜3週間（データ量による）
  内容: オンプレDBの全データをRDS/Auroraへ一括コピー
  影響: なし（業務は旧DBで継続）

Step 2: DMS CDC（継続的差分同期）
  期間: 数週間〜数ヶ月（並行運用期間）
  内容: フルロード完了後、ソースDBの変更をリアルタイム反映
  影響: なし（ラグは通常数秒〜数分以内）

Step 3: テスト切り替え
  内容: 本番DBへのトラフィックは旧DBのまま、テストクエリを新DBに流して一致確認
  ツール: AWS DMS テーブル統計・検証レポート

Step 4: カットオーバー（ダウンタイム: 5〜30分が目標）
  23:00 メンテナンス開始アナウンス
  23:05 新規書き込みをメンテナンスページで停止
  23:07 CDC ラグが0になるのを確認
  23:10 アプリの接続先をAurora（新DB）に変更
  23:15 動作確認
  23:20 メンテナンス解除・全店舗からのアクセス再開
```

### 5-2. デュアルライト（並行書き込み）パターン

カットオーバー直前の安全網として、アプリ側で旧DBと新DBに同時書き込みする期間を設ける。

```python
# デュアルライトの概念コード
def write_order(order_data):
    # 旧DB（必須）
    legacy_db.insert(order_data)

    # 新DB（非同期・失敗しても業務継続）
    try:
        aurora.insert(order_data)
    except Exception as e:
        logger.error(f"Dual write failed: {e}")
        # アラートを出すが業務は継続
```

**注意点**: デュアルライト期間を長く取りすぎると、2つのDBの整合性管理コストが増大する。目安は**1〜2週間以内**に完了すること。

### 5-3. 大規模データの移行手法

| データ量 | 推奨手法 | 期間目安 |
|---------|---------|---------|
| < 1TB | DMS フルロード (Direct) | 1〜3日 |
| 1〜10TB | S3経由エクスポート/インポート | 3〜7日 |
| 10〜100TB | AWS DataSync + DMS CDC | 1〜2週間 |
| 100TB超 | AWS Snow Family（Snowball）+ DMS CDC | 2〜4週間 |

**Redshiftへの歴史データ移行（DWH構築）**:

```sql
-- S3からのCOPYコマンド（Redshift高速ロード）
COPY sales_history
FROM 's3://bucket/sales-data/2020-2025/'
IAM_ROLE 'arn:aws:iam::123456789:role/RedshiftCopyRole'
FORMAT AS PARQUET;
-- ※ Parquet形式を使うと圧縮効率が高く転送量・コストを削減できる
```

### 5-4. DMS タスク監視とトラブルシューティング

**CloudWatchで監視すべき主要メトリクス**:

| メトリクス | 説明 | 警戒値の目安 |
|----------|------|------------|
| `CDCLatencySource` | ソースDBからの読み取り遅延（秒） | > 60秒でアラート |
| `CDCLatencyTarget` | ターゲットDBへの書き込み遅延（秒） | > 60秒でアラート |
| `FreeableMemory` | レプリケーションインスタンスの空きメモリ | < 200MBでアラート |
| `CDCThroughputRowsSource` | 毎秒処理する行数 | 上限の80%超でスケールアップ検討 |

---

## 6. 学習ロードマップ

### Must（参画前に理解必須）

PMとして技術的な意思決定・レビューを行うために最低限必要な知識。

| 優先順位 | トピック | 習得目標レベル | 推奨リソース |
|---------|---------|-------------|------------|
| 1 | AWS DMS の仕組み・設定オプション | 設計レビューができる | [DMS Getting Started](https://docs.aws.amazon.com/dms/latest/userguide/CHAP_GettingStarted.html) |
| 2 | AWS MGN の移行手順（フェーズ管理） | テスト/本番カットオーバーの判断基準を理解 | [MGN ベストプラクティス](https://docs.aws.amazon.com/mgn/latest/ug/best-practices.html) |
| 3 | Transit Gateway によるマルチVPC設計 | 設計図を読んでレビューできる | [TGW 設計ガイド](https://docs.aws.amazon.com/vpc/latest/tgw/transit-gateway-appliance-scenario.html) |
| 4 | AWS Migration Acceleration Program (MAP) | プログラム活用の判断・顧客提案ができる | [MAP 概要](https://aws.amazon.com/migration-acceleration-program/) |
| 5 | マルチアカウント設計（Control Tower） | アカウント設計の承認ができる | [Control Tower Workshop](https://catalog.workshops.aws/control-tower) |
| 6 | DMS CDC とカットオーバー計画 | ダウンタイム最小化の設計を評価できる | 本資料 5章 |
| 7 | IoT Greengrass v2 の店舗実装概念 | デバイス管理の設計を理解できる | [Greengrass v2 開発者ガイド](https://docs.aws.amazon.com/greengrass/v2/developerguide/) |

### Should（参画後早期に深めるべき）

参画後1〜3ヶ月以内に理解を深めることで、プロジェクト推進の質が上がるもの。

| 優先順位 | トピック | 習得目標レベル | 推奨リソース |
|---------|---------|-------------|------------|
| 1 | MSK vs. Kinesis の使い分け | 技術提案・選定根拠の評価ができる | [Amazon MSK vs. Amazon Kinesis 比較](https://aws.amazon.com/msk/faqs/) |
| 2 | Direct Connect 設計パターン | 帯域・コスト見積もりができる | [Direct Connect ユーザーガイド](https://docs.aws.amazon.com/directconnect/latest/UserGuide/) |
| 3 | AWS Well-Architected Review 実施方法 | 定期レビューをファシリテートできる | [Well-Architected Tool](https://docs.aws.amazon.com/wellarchitected/latest/userguide/) |
| 4 | Step Functions によるバッチ設計 | 複雑なバッチフロー設計の評価 | [Step Functions ベストプラクティス](https://docs.aws.amazon.com/step-functions/latest/dg/concepts-best-practices.html) |
| 5 | コスト最適化（Savings Plans / RI） | 月次コストレビューができる | [Cost Optimization Hub](https://docs.aws.amazon.com/cost-management/latest/userguide/cost-optimization-hub.html) |
| 6 | Aurora Global Database （DR設計） | 大阪リージョンDR構成の評価ができる | [Aurora Global DB](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-global-database.html) |

### Nice-to-have（余裕があれば）

案件に余裕が生まれた段階、または将来の専門性強化のために。

| トピック | 理由 | 推奨リソース |
|---------|------|------------|
| AWS Outposts の詳細設計 | 地域DC統合への対応として将来的に必要 | [Outposts ユーザーガイド](https://docs.aws.amazon.com/outposts/latest/userguide/) |
| Amazon SageMaker (需要予測) | 移行後のモダナイズフェーズで活用 | [SageMaker 入門](https://docs.aws.amazon.com/sagemaker/latest/dg/whatis.html) |
| AWS Glue （ETL・DWH連携） | Redshiftへのデータパイプライン構築 | [Glue 開発者ガイド](https://docs.aws.amazon.com/glue/latest/dg/what-is-glue.html) |
| Amazon QuickSight | 売上分析ダッシュボードの構築 | [QuickSight 入門](https://docs.aws.amazon.com/quicksight/latest/user/getting-started.html) |
| AWS IoT Greengrass コンポーネント開発 | エッジ開発の自走力 | [Greengrass コンポーネント開発](https://docs.aws.amazon.com/greengrass/v2/developerguide/develop-greengrass-components.html) |
| CDK (Cloud Development Kit) | IaCの設計レビュー力向上 | [CDK Workshop](https://cdkworkshop.com/) |

---

## 7. 参考リソース一覧

### AWS公式ドキュメント

| サービス/トピック | URL |
|----------------|-----|
| AWS DMS ユーザーガイド | https://docs.aws.amazon.com/dms/latest/userguide/Welcome.html |
| AWS DMS ソースDB一覧 | https://docs.aws.amazon.com/dms/latest/userguide/CHAP_Source.html |
| AWS DMS Getting Started | https://docs.aws.amazon.com/dms/latest/userguide/CHAP_GettingStarted.html |
| AWS Schema Conversion Tool | https://docs.aws.amazon.com/SchemaConversionTool/latest/userguide/CHAP_Welcome.html |
| AWS MGN ユーザーガイド | https://docs.aws.amazon.com/mgn/latest/ug/what-is-application-migration-service.html |
| AWS MGN ベストプラクティス | https://docs.aws.amazon.com/mgn/latest/ug/best-practices.html |
| AWS Outposts Rack | https://docs.aws.amazon.com/outposts/latest/userguide/what-is-outposts.html |
| AWS Outposts Servers | https://docs.aws.amazon.com/outposts/latest/server-userguide/what-is-outposts.html |
| Amazon MSK 開発者ガイド | https://docs.aws.amazon.com/msk/latest/developerguide/what-is-msk.html |
| Amazon MSK Serverless | https://docs.aws.amazon.com/msk/latest/developerguide/serverless.html |
| Amazon Kinesis Data Streams | https://docs.aws.amazon.com/kinesis/latest/APIReference/Welcome.html |
| AWS IoT Core 開発者ガイド | https://docs.aws.amazon.com/iot/latest/developerguide/what-is-aws-iot.html |
| AWS IoT Greengrass v2 | https://docs.aws.amazon.com/greengrass/v2/developerguide/what-is-iot-greengrass.html |
| AWS Direct Connect ユーザーガイド | https://docs.aws.amazon.com/directconnect/latest/UserGuide/Welcome.html |
| Direct Connect Gateway | https://docs.aws.amazon.com/directconnect/latest/UserGuide/direct-connect-gateways-intro.html |
| AWS Transit Gateway ユーザーガイド | https://docs.aws.amazon.com/vpc/latest/tgw/what-is-transit-gateway.html |
| Transit Gateway ルートテーブル | https://docs.aws.amazon.com/vpc/latest/tgw/tgw-route-tables.html |
| AWS Control Tower ユーザーガイド | https://docs.aws.amazon.com/controltower/latest/userguide/what-is-control-tower.html |
| AWS Well-Architected Framework | https://docs.aws.amazon.com/wellarchitected/latest/framework/welcome.html |
| Aurora Global Database | https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-global-database.html |

### 移行プログラム・ベストプラクティス

| リソース | URL |
|---------|-----|
| AWS Migration Acceleration Program (MAP) | https://aws.amazon.com/migration-acceleration-program/ |
| AWS Migration Hub | https://docs.aws.amazon.com/migrationhub/latest/ug/whatishub.html |
| AWS Migration Evaluator | https://aws.amazon.com/migration-evaluator/ |
| AWS Well-Architected Tool | https://docs.aws.amazon.com/wellarchitected/latest/userguide/ |
| Cost Optimization Hub | https://docs.aws.amazon.com/cost-management/latest/userguide/cost-optimization-hub.html |

### ハンズオン・ワークショップ

| リソース | URL |
|---------|-----|
| AWS Control Tower Workshop | https://catalog.workshops.aws/control-tower |
| AWS DMS Workshop | https://catalog.workshops.aws/dms |
| AWS Migration Immersion Day | https://catalog.workshops.aws/migration-immersion-day |
| AWS CDK Workshop | https://cdkworkshop.com/ |

### 小売業界向け参考資料

| リソース | URL |
|---------|-----|
| AWS 小売業向けソリューション一覧 | https://aws.amazon.com/retail/ |
| AWS 小売業 ケーススタディ | https://aws.amazon.com/solutions/case-studies/retail/ |
| AWS re:Invent 小売業セッション（録画） | https://reinvent.awsevents.com/ |

---

## 付記: 東京リージョン（ap-northeast-1）主要サービス利用可否

| サービス | ap-northeast-1 対応 | 備考 |
|---------|-------------------|------|
| AWS DMS | 対応 | 全ソースDB対応 |
| AWS MGN | 対応 | - |
| AWS Outposts Rack | 対応（注文設置型） | Equinix TY、AT TOKYO等のコロケーション対応 |
| AWS Outposts Servers | 対応 | - |
| Amazon MSK | 対応 | MSK Serverlessも対応 |
| Amazon Kinesis Data Streams | 対応 | オンデマンドモード対応 |
| AWS IoT Core | 対応 | - |
| AWS IoT Greengrass v2 | 対応 | - |
| AWS Direct Connect | 対応 | 東京 DX ロケーション多数 |
| AWS Transit Gateway | 対応 | マルチリージョンピアリングも対応 |
| Amazon Aurora | 対応 | Global Database（東京〜大阪）対応 |
| AWS Control Tower | 対応 | - |
| Amazon MSK Serverless | 対応 | - |

---

*本レポートは retail-domain-researcher が 2026-03-25 に作成。*
*AWS公式ドキュメントは頻繁に更新されるため、参画前に最新情報を確認すること。*
*特にサービス料金・制限値（Quotas）は変動するため、AWS公式の最新料金ページで確認すること。*
