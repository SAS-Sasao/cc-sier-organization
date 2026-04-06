# WBS 3.1.1 AWS基礎 — IAM + VPC 学習ノート

**学習日**: 2026-04-06
**WBS**: 3.1.1 AWS基礎（IAM, VPC, EC2, S3）
**カバー範囲**: IAM + VPC（本セッション）/ EC2 + S3（次回）
**教材**: [aws-basics-handson-roadmap.md](../../research/aws-basics-handson-roadmap.md)

---

## IAM — 要点まとめ

### PMとして押さえるべきポイント

1. **マルチアカウント戦略は必須**
   - 本番/ステージング/開発/ログを別アカウントに分離
   - アカウントは「爆発半径（Blast Radius）」を制限する最強の境界
   - AWS Organizations + Control Tower で管理

2. **IAMロール > IAMユーザー**
   - EC2/Lambda等のサービスには IAMロール（Instance Profile）を使う
   - アクセスキーの埋め込みはアンチパターン
   - 人間のアクセスは SSO + AssumeRole が標準

3. **SCP（Service Control Policy）は天井**
   - Organizations レベルで適用される最上位ポリシー
   - IAMポリシーでAllowしてもSCPでDenyなら実行不可
   - リージョン制限、危険操作の禁止に使う

4. **ストコン案件でのデバイス認証**
   - 56,000台の店舗端末 → Cognito User Pool + Identity Pool
   - STS一時認証情報を発行し、アクセスキー配布リスクをゼロに
   - IoT Core + X.509証明書も候補（大規模デバイス向け）

### SAA頻出テーマ
- 最小権限の原則（ワイルドカード * を避ける）
- クロスアカウントアクセス（AssumeRole + 信頼ポリシー）
- IAMロール vs ユーザーの使い分け
- SCP vs IAMポリシーの優先順位

### 構成図
- [StoreCon IAM Multi-Account Architecture](https://sas-sasao.github.io/cc-sier-organization/diagrams/storcon-iam-multi-account.html)

---

## VPC — 要点まとめ

### PMとして押さえるべきポイント

1. **3層サブネット設計**
   - Public: ALB, NAT Gateway（インターネットに面する）
   - Private: ECS Fargate, Lambda（インターネットから直接到達不可）
   - Data: Aurora, ElastiCache（Appからのみアクセス可）
   - サブネットのPublic/Private区分は「ルートテーブル」で決まる（名前ではない）

2. **マルチAZで可用性確保**
   - 2 AZ（ap-northeast-1a, 1c）にまたがる冗長構成
   - Aurora: Writer(AZ-a) + Reader(AZ-c) の自動レプリケーション
   - NAT Gateway: 各AZに1台（単一NAT = SPOF）

3. **VPC Endpointでコスト削減**
   - S3 Gateway Endpoint: 無料、ルートテーブルで制御
   - Interface Endpoint: ENI+PrivateLink経由、時間+データ課金
   - S3通信量が多いストコンでは必須の最適化

4. **Security Groupの3層チェーン**
   - SG-ALB: 443 inbound from Internet
   - SG-App: 8080 from SG-ALB only
   - SG-Data: 3306/6379 from SG-App only
   - ソースにSG IDを指定することで、動的IPに依存しない

5. **ハイブリッド接続**
   - Direct Connect: 専用線、低遅延、帯域保証
   - Site-to-Site VPN: インターネット経由、バックアップ回線
   - 56,000店舗のデータ量を考慮すると専用線が必須

### SAA頻出テーマ
- Public vs Private Subnetの区分方法
- NAT Gateway vs NAT Instance
- Security Group vs NACL（ステートフル vs ステートレス）
- VPC Peering vs Transit Gateway
- Gateway Endpoint vs Interface Endpoint

### 構成図
- [StoreCon VPC Multi-AZ Architecture](https://sas-sasao.github.io/cc-sier-organization/diagrams/storcon-vpc-multi-az.html)

---

## 次回の学習予定

- **EC2**: インスタンスタイプ選定、Auto Scaling、EBS設計
- **S3**: ストレージクラス、ライフサイクル、バケットポリシー
- EC2 + S3 のストコン向け構成図を追加作成予定

---

## チェックリスト

### IAM
- [x] IAMユーザー・グループ・ロール・ポリシーの違いを図で説明できる
- [x] 「EC2がS3にアクセスするときなぜアクセスキーが不要か」をIAMロールで説明できる
- [x] シングルアカウントとマルチアカウントのトレードオフを述べられる
- [x] SCPが「最大権限の天井」であることを説明できる
- [x] ストコン案件で「本部と店舗の権限分離」をどう実現するか説明できる

### VPC
- [x] Public SubnetとPrivate Subnetの違いをルートテーブルで説明できる
- [x] NAT Gatewayの役割と料金構造を説明できる
- [x] Security GroupとNACLの違いを説明できる
- [x] VPC Endpoint (Gateway / Interface) の使い分けを説明できる
- [x] マルチAZ構成でSPOFがないことを確認できる
