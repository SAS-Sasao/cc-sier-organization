# AWS移行ベストプラクティス — 大規模小売システム（ストコン）対応版

- **調査対象**: 大規模小売システムのAWS移行ベストプラクティス（フレームワーク・段階的移行・データ移行・テスト・コスト最適化）
- **WBS**: 5.2 AWS移行技術レポートの拡充
- **作成日**: 2026-04-12
- **作成者**: tech-researcher
- **前提**: 約14,663店舗規模のオンプレシステムをAWSへ移行する想定。既存調査（wbs-5-2-storcon-aws-migration-tech.md）の深掘り版

---

## 目次

1. [AWS移行フレームワーク概要](#1-aws移行フレームワーク概要)
2. [7R戦略のストコン適用マッピング](#2-7r戦略のストコン適用マッピング)
3. [AWS Migration Acceleration Program (MAP)](#3-aws-migration-acceleration-program-map)
4. [段階的移行戦略（フェーズ設計）](#4-段階的移行戦略フェーズ設計)
5. [Blue/Green vs カナリアリリース vs ローリングアップデート](#5-bluegreen-vs-カナリアリリース-vs-ローリングアップデート)
6. [切り戻し計画（ロールバック設計）](#6-切り戻し計画ロールバック設計)
7. [データ移行戦略（DMS・CDC・ゼロダウンタイム）](#7-データ移行戦略dmscdc-ゼロダウンタイム)
8. [テスト戦略](#8-テスト戦略)
9. [コスト最適化戦略](#9-コスト最適化戦略)
10. [ストコン案件 PM視点の論点整理](#10-ストコン案件-pm視点の論点整理)
11. [Sources](#11-sources)

---

## 1. AWS移行フレームワーク概要

### 1-1. AWS Migration Hub

AWS Migration Hub は、複数の移行ツールを横断して移行プロジェクトを一元管理するコントロールプレーン。

```
[AWS Migration Hub]
  ├── 移行ステータスの統合ダッシュボード
  ├── 各移行ツールの進捗トラッキング
  │     ├── Application Migration Service (MGN)
  │     ├── Database Migration Service (DMS)
  │     └── Server Migration Service (SMS / 非推奨)
  ├── Migration Hub Refactor Spaces（マイクロサービス化支援）
  └── Migration Hub Strategy Recommendations（移行戦略の自動推奨）
```

**ストコン案件での活用ポイント**

| 機能 | 活用シーン |
|------|----------|
| ダッシュボード | 14,663店舗分のサーバー・DBのリプレース進捗を PMO が一覧把握 |
| Strategy Recommendations | Application Discovery Service のデータを取り込み、7R の自動推奨（Rehost/Replatform等）を生成 |
| Refactor Spaces | ストラングラーフィグパターンでの段階的マイクロサービス化を管理 |

### 1-2. Application Migration Service (MGN)

旧称 CloudEndure Migration。オンプレサーバーをほぼダウンタイムなしで AWS に移行するサービス。

**移行の仕組み**

```
[オンプレサーバー]
       |
  (エージェントインストール)
       |
  ブロックレベルで継続的レプリケーション
       |
[AWS ステージングエリア]
  └── 低スペック EC2 + EBS (レプリカ保持)
       |
  カットオーバー指示 (数分でスピンアップ)
       |
[AWS 本番EC2]
  └── ボリュームがそのまま起動
```

**主な特徴**

- エージェントベースのリアルタイム・ブロックレプリケーション
- テストインスタンスの起動で事前動作確認が可能
- 本番カットオーバー時の停止時間: 数分〜十数分
- 対応OS: Windows Server 2003以降、RHEL/CentOS/Ubuntu など幅広く対応

**ストコン案件での位置づけ**

Phase 1 の Lift & Shift では、本部サーバー群（発注管理、商品マスタ等の集中系）を MGN で EC2 へリフトするのが最速アプローチ。14,663店舗の端末は移行対象外（AWS からクラウドAPIを呼ぶクライアント）のため、サーバー数は数十〜百台規模の見込み。

### 1-3. Application Discovery Service (ADS)

オンプレ環境のサーバー構成情報・依存関係を自動探索するサービス。Migration Hub Strategy Recommendations の入力データになる。

| 探索方式 | 方法 | 取得情報 |
|---------|------|---------|
| エージェントベース | サーバーにエージェントをインストール | CPU/メモリ/ディスク使用率、実行プロセス、ネットワーク通信先、依存関係 |
| エージェントレス | VMware vCenter に接続 | VM一覧、基本スペック（依存関係は取得不可） |

ストコン案件では移行計画立案前にエージェントベースの ADS を実行し、**サーバー間の依存関係マップ**を作成することが推奨される。これにより「一緒に移行すべきサーバーのグループ（移行ウェーブ）」を科学的に決定できる。

---

## 2. 7R戦略のストコン適用マッピング

前回調査（wbs-5-2-storcon-aws-migration-tech.md）の7R概要をストコン固有の構成要素に適用した詳細マッピング。

### 2-1. 構成要素別 7R マッピング表

| 構成要素 | 現状 | 推奨7R | 理由 | 優先度 |
|---------|------|-------|------|--------|
| 発注管理アプリ（本部集中系） | オンプレJava/Tomcat | Rehost → Replatform | 初期はEC2へLift&Shift、その後ECS/Fargateへコンテナ化 | 高 |
| 商品マスタDB（Oracle） | オンプレOracle RAC | Replatform | Aurora PostgreSQLへ。SCTで80〜90%自動変換 | 最高 |
| 発注トランザクションDB（MySQL） | オンプレMySQL | Replatform | Aurora MySQLへ（互換性が高く変換コスト小） | 最高 |
| 売上集計バッチ | オンプレシェルスクリプト+RDBMS | Refactor | AWS BatchまたはStep Functionsで再実装。可観測性向上 | 中 |
| ファイル転送（店舗↔本部） | FTPサーバー | Repurchase/Refactor | S3 + Lambda による Event-Driven に刷新 | 中 |
| レガシー精算システム（旧世代） | COBOL/AS400 | Retain → Retire | 短期はRetain、中期でSaaSへ切替を検討 | 低 |
| 店舗内ローカルDB（SQLite等） | 店舗端末ローカル | Retain | オフライン耐性の根幹。クラウド化対象外 | - |
| 監視・運用ツール（Nagios等） | オンプレ監視 | Replace（Repurchase） | CloudWatch + Datadog/New Relic に移行 | 中 |
| 本部DC → AWS 接続 | 専用線なし（VPN） | Retain → Direct Connect | 移行中はVPN、本番後はDirect Connectへ切替 | 高 |

### 2-2. 移行ウェーブの考え方

移行ウェーブとは「一括で移行するサーバーグループ」の単位。ADS の依存関係マップをもとに設計する。

```
Wave 1 (低リスク・独立系)
  └── 監視ツール、ログ集約、バックアップサーバー
      ─ 本番稼働に直接影響しないシステム

Wave 2 (中リスク・参照系)
  └── 商品マスタ参照API、在庫照会、レポートサーバー
      ─ 読み取り中心でロールバックが容易

Wave 3 (高リスク・トランザクション系)
  └── 発注処理サーバー、決済連携、店舗API Gateway
      ─ 慎重な移行計画と長いパラレル運用が必要

Wave 4 (最高リスク・カットオーバー)
  └── 全店舗への本番切り替え
      ─ メンテナンスウィンドウ活用、深夜帯
```

---

## 3. AWS Migration Acceleration Program (MAP)

### 3-1. MAPとは

AWS MAP（Migration Acceleration Program）は、エンタープライズ規模の AWS 移行を支援する包括的プログラム。AWSパートナー（NEC、富士通、アクセンチュア等）を通じて提供される。

**MAP の3フェーズ構成**

```
Phase 1: Assess（評価・計画） ─ 2〜4週間
  ├── Migration Readiness Assessment (MRA) の実施
  ├── TCO分析（オンプレ vs AWS のコスト比較）
  ├── 移行対象範囲の確定
  └── 移行リスクの洗い出し
        ↓
Phase 2: Mobilize（準備・基盤構築） ─ 2〜6ヶ月
  ├── AWS Landing Zone の構築（アカウント設計、ネットワーク、セキュリティ）
  ├── CI/CDパイプラインの整備
  ├── 運用チームのトレーニング
  └── パイロット移行の実施（小規模なシステムで移行プロセスを検証）
        ↓
Phase 3: Migrate & Modernize（本移行・近代化） ─ 6〜18ヶ月
  ├── ウェーブ単位での移行実行
  ├── 移行後の最適化（Right Sizing、RI購入）
  └── モダナイゼーション（コンテナ化、マイクロサービス化）
```

### 3-2. MAP の財務インセンティブ

MAP 認定パートナー経由での移行では、AWS から **移行クレジット** が付与される。

| 規模 | クレジット目安 | 条件 |
|-----|-------------|------|
| SMB | 数千〜数万ドル | MRAスコア60点以上 |
| エンタープライズ（本案件規模） | 数十万〜数百万ドル | MAP Partner による実施、TCO分析提出 |

ストコン案件クラスの規模（数十〜百台サーバー、複数DBの移行）は MAP のエンタープライズ枠に該当する可能性が高い。PM として調達フェーズでパートナーに MAP 適用可否を確認することが重要。

### 3-3. Landing Zone（AWS Control Tower）

MAP の Mobilize フェーズで必ず構築する基盤アーキテクチャ。

```
[AWS Organizations]
  ├── 管理アカウント
  │     └── AWS Control Tower（ランディングゾーン管理）
  ├── セキュリティ OU
  │     ├── Log Archive アカウント（全ログの集約）
  │     └── Security Tooling アカウント（Security Hub, GuardDuty, Config）
  ├── Infrastructure OU
  │     └── Shared Services アカウント（DNS, ネットワーク共有）
  └── Workloads OU
        ├── 本番アカウント（Production）
        ├── ステージングアカウント（Staging）
        └── 開発アカウント（Development）
```

**マルチアカウント戦略のメリット**
- 本番・開発の障害影響範囲をアカウントで分離
- コスト配分が明確（アカウント単位で請求額を把握）
- セキュリティ境界の強制（IAM Permission Boundary）

---

## 4. 段階的移行戦略（フェーズ設計）

### 4-1. ストコン案件の3フェーズロールアウト設計

全国14,663店舗への展開を一括で行うのはリスクが高い。パイロット → 地域展開 → 全国展開の段階的アプローチが必須。

```
┌────────────────────────────────────────────────────────────────┐
│  フェーズ1: パイロット店舗移行  （目安: M1〜M6）                   │
│  対象: 5〜20店舗（実験的なロケーション選定）                       │
│  目的: 技術的な実現可能性の検証 / 運用手順の確立                   │
│  成功基準: 新旧同等のレスポンス / インシデントゼロ継続 / ロールバック訓練 │
└──────────────────────────┬─────────────────────────────────────┘
                           │ Go/No-Go ゲート
                           │（5者承認: CIO/IT部長/店舗運営責任者/商品部責任者/セキュリティ担当）
                           ▼
┌────────────────────────────────────────────────────────────────┐
│  フェーズ2: 地域展開（ウェーブ移行）  （目安: M7〜M18）             │
│  対象: 1〜3都道府県単位でウェーブ（例: 関東→近畿→中部 の順）        │
│  目的: 規模拡大時の問題検出 / 運用手順の全国展開前最終確認          │
│  成功基準: 各ウェーブで障害率 < 0.1% / 切り戻し件数ゼロ           │
└──────────────────────────┬─────────────────────────────────────┘
                           │ Go/No-Go ゲート
                           │（同5者承認 + スポンサーCFO承認）
                           ▼
┌────────────────────────────────────────────────────────────────┐
│  フェーズ3: 全国展開  （目安: M19〜M30）                           │
│  対象: 残りの全店舗（複数ウェーブで並列展開）                       │
│  目的: 全店舗の AWS 化完了 / オンプレ環境の段階的廃止              │
│  成功基準: SLA 99.9% 以上 / オンプレコスト削減確認               │
└────────────────────────────────────────────────────────────────┘
```

### 4-2. パイロット店舗の選定基準

| 選定基準 | 内容 | ストコンでの考慮点 |
|---------|------|-----------------|
| 技術的代表性 | 移行対象システムを全て稼働している店舗 | 発注・POS連携・決済・温度管理を全て使う店舗 |
| 地理的孤立性 | 障害が他店舗に波及しにくいロケーション | 本部から近く、担当SEが駆けつけやすいエリア |
| 店長・SVの協力度 | 新システムの試験に積極的な現場 | IT リテラシーが高い店長の店舗を優先 |
| トラフィック代表性 | 極端な多客・過疎でない平均的な店舗 | 都市部の標準的な日販を持つ店舗 |
| ロールバック容易性 | 切り戻し時の影響が最小化できる店舗 | 新旧並走できるネットワーク帯域のある店舗 |

### 4-3. ウェーブ設計のポイント

```
ウェーブサイズの設計原則:
  ├── 1ウェーブあたり 500〜1,000店舗以下（管理可能な単位）
  ├── 各ウェーブの移行後に 2〜4週間の安定化期間を設ける
  └── 前ウェーブの課題解決を確認してから次ウェーブを開始

ウェーブ間の判断基準（Go 条件）:
  ├── 前ウェーブのインシデント件数が閾値以下
  ├── 平均レスポンスタイムが旧システム比 ±10% 以内
  ├── ロールバック手順が 30分以内で完了できることを確認済み
  └── 店舗オペレーターからの問合せ件数が安定推移している
```

---

## 5. Blue/Green vs カナリアリリース vs ローリングアップデート

### 5-1. 3つのデプロイ戦略の比較

| 戦略 | 仕組み | ダウンタイム | リソースコスト | ロールバック速度 | ストコン適用場面 |
|------|--------|-----------|-------------|--------------|--------------|
| **Blue/Green** | 旧環境(Blue)と新環境(Green)を並走。DNS切り替えで瞬時に移行 | ほぼゼロ | 2倍（一時的） | 数分（DNS切り戻し） | 大規模カットオーバー時（フェーズ切り替えのタイミング） |
| **カナリアリリース** | トラフィックの一部（1〜10%）のみ新バージョンに流す | ゼロ | 最小 | 数分（割合を0に戻す） | 発注APIの新バージョン段階的展開 |
| **ローリングアップデート** | 旧インスタンスを少しずつ入れ替え（ECS のデフォルト） | ゼロ | 追加なし | 数分〜数十分 | アプリケーションの継続的デプロイ（日常運用） |
| **Recreate** | 旧を全停止してから新を起動 | あり（数分〜） | 最小 | 不要（問題時は旧バージョン再デプロイ） | 開発環境、テスト環境 |

### 5-2. Blue/Green デプロイメントの実装

AWS での Blue/Green の主な実装パターン:

```
パターン1: Route 53 + ALB による DNS 切り替え
  Blue環境: ALB-Blue → ECS Service Blue → Aurora (Primary)
  Green環境: ALB-Green → ECS Service Green → Aurora (Primary)
  ─ Route 53 の Weighted Routing で段階的にトラフィックを移行
  ─ 最終的に Route 53 の重みを 0:100 に切り替えてカットオーバー

パターン2: CodeDeploy ECS Blue/Green
  ─ ECS サービスのターゲットグループを切り替える
  ─ CodeDeploy が自動的に新旧の切り替えとロールバックを管理
  ─ デフォルト設定: 5分間の検証ウィンドウ後に旧タスクを終了

パターン3: ALB Target Group の切り替え（最も簡単）
  ALB
  ├── Target Group Blue (旧 ECS サービス)
  └── Target Group Green (新 ECS サービス)
  ─ ALB のリスナールールの重みを変更するだけ
```

**ストコン案件推奨パターン**: Route 53 Weighted Routing + ALB

理由: 段階的なトラフィック移行（1% → 10% → 50% → 100%）が可能で、店舗数単位でのカナリア展開と組み合わせやすい。

### 5-3. カナリアリリースの具体的な段階設計

```
全国展開時のカナリアリリース段階設計（例）:

Step 1 (0.1%): 14.7店舗 ≒ 15店舗に新APIを適用
  ─ モニタリング: 30分間、エラーレート・レスポンスタイムを観察
  ─ 問題なければ Step 2 へ

Step 2 (1%): 147店舗に拡大
  ─ モニタリング: 2時間観察
  ─ 問題なければ Step 3 へ

Step 3 (10%): 1,466店舗に拡大
  ─ モニタリング: 24時間観察（1日分のビジネスサイクルをカバー）
  ─ 問題なければ Step 4 へ

Step 4 (50%): 7,332店舗
  ─ モニタリング: 48時間観察
  ─ Go/No-Go 判断後 100% へ

Step 5 (100%): 全14,663店舗
```

---

## 6. 切り戻し計画（ロールバック設計）

### 6-1. ロールバック設計の原則

「移行後に問題が発生した場合、確実に旧環境へ戻せる」ことが大規模移行の大前提。

**ロールバック設計の5原則**

```
原則1: 旧環境は本番移行後も一定期間（最低30日）保持する
原則2: ロールバックの所要時間を事前に計測・記録する（目標: 30分以内）
原則3: ロールバック手順はRunbookとして文書化し、誰でも実行できる状態にする
原則4: 定期的なロールバック訓練を実施する（少なくともパイロット前に1回）
原則5: データ移行後のロールバックではデータの整合性確保が最難関（後述）
```

### 6-2. レイヤー別ロールバック手順

| レイヤー | ロールバック方法 | 所要時間目安 | ストコンでの注意点 |
|---------|--------------|------------|-----------------|
| **DNS層** | Route 53 の Weighted Routing を 100:0 に戻す | 1〜5分（TTL依存） | TTL を短め（60秒）に設定しておく |
| **アプリ層** | ECS の Target Group を Blue に戻す / CodeDeploy のロールバック実行 | 3〜10分 | 新バージョンで作成されたセッションデータの扱いを定義 |
| **DB層** | Aurora のクラスターエンドポイントを旧 DB に向け直す | 5〜30分 | 最難関。新DBに書き込まれたデータの扱いが問題 |
| **データ移行後** | CDC の逆同期（新DB→旧DBに差分を流す）またはポイントインタイムリカバリ | 30分〜数時間 | 設計段階で「ロールバック可能なタイムリミット」を定義する |

### 6-3. DB ロールバックのデータ整合性問題

移行後に旧DBへ切り戻す場合、**新DB（Aurora）で発生したトランザクションをどう扱うか**が最難関。

```
アプローチ1: デュアルライト期間の延長
  ─ 本番切り替え後も旧DBと新DBの両方に書き込み続ける
  ─ ロールバック時は旧DBが全データを保持している
  ─ デメリット: パフォーマンス低下、コスト増、複雑性増加

アプローチ2: CDC逆同期の事前準備
  ─ 新DB(Aurora)→旧DB(オンプレ)の逆方向 DMS レプリケーションを事前に設定
  ─ ロールバック時に逆レプリケーションを実行して差分を同期後に切り替え
  ─ デメリット: スキーマ変換がある場合は逆変換が必要で複雑

アプローチ3: ロールバック・デッドライン方式
  ─ 「移行後X時間以内のみロールバック可能」と事前定義
  ─ デッドライン後は新DBで継続するか、データを再構築するか判断
  ─ ストコン案件での推奨: 本番切り替えから 72時間をロールバック可能期限とする
```

---

## 7. データ移行戦略（DMS・CDC・ゼロダウンタイム）

### 7-1. AWS Database Migration Service (DMS) の詳細

DMS はソースDBとターゲットDBを接続し、スキーマ変換とデータレプリケーションを行う。

**DMS の主要コンポーネント**

```
[ソースDB]       [DMS レプリケーションインスタンス]       [ターゲットDB]
  Oracle   ─────→  Full Load Task ─────────────────→  Aurora PostgreSQL
  MySQL    ─────→  CDC Task（Change Data Capture） ─→  Aurora MySQL
  SQL Server ───→  Full Load + CDC Task ────────────→  Aurora
```

| タスク種別 | 動作 | ユースケース |
|---------|------|------------|
| **Full Load** | ソースの全データをターゲットへ一括コピー | 初期移行（深夜メンテウィンドウ中に実施） |
| **CDC のみ** | ソースの変更差分（INSERT/UPDATE/DELETE）をターゲットへレプリケーション | Full Load 後の継続同期 |
| **Full Load + CDC** | Full Load 後に自動的に CDC に切り替え | ゼロダウンタイム移行の基本パターン（推奨） |

### 7-2. ゼロダウンタイム移行の手順（Full Load + CDC）

ストコン案件のような 24/365 システムで使うゼロダウンタイム移行の標準手順。

```
Step 1: 事前準備（D-14〜D-7）
  ├── DMS レプリケーションインスタンスをプロビジョニング
  ├── ソース DB でバイナリログ（MySQL）/ WAL（PostgreSQL）/ Supplement Logging（Oracle）を有効化
  └── SCT でスキーマを変換（Oracleの場合）

Step 2: Full Load 開始（D-7〜D-1）
  ├── DMS Full Load タスク実行（業務への影響: ソースDBに軽い負荷）
  ├── 大容量テーブルは並列ロード（LOB設定に注意）
  └── Full Load 完了後、自動的に CDC モードへ移行

Step 3: CDCによる差分同期（D-1〜D-Day）
  ├── ソース DB の変更がリアルタイムでターゲットに反映
  ├── レプリケーション遅延（Lag）を CloudWatch で監視
  └── Lag が 10秒以内になったことを確認してカットオーバーGo

Step 4: カットオーバー（D-Day、深夜）
  ├── アプリケーション→新DB への接続文字列を切り替え
  ├── DMS タスクを停止（ソースへの書き込み停止）
  └── 移行後の動作確認（30分間モニタリング）

Step 5: CDCの逆同期設定（保険）
  └── 万が一のロールバック用に新DB→旧DBの逆レプリケーションを起動
```

### 7-3. 商品マスタ等の大容量データの移行戦略

コンビニの商品マスタは数十万レコード、発注・売上の履歴データは数億〜数十億レコードに達する場合がある。

| データ分類 | レコード規模（想定） | 移行方針 | ツール |
|---------|----------------|---------|-------|
| 商品マスタ | 数十万件 | DMS Full Load（通常速度で数時間以内） | DMS |
| 店舗マスタ | 14,663件 | DMS Full Load（数分） | DMS |
| 発注トランザクション（直近3年） | 数億件 | Parallel Full Load + CDC | DMS（LOB設定要確認）|
| 発注トランザクション（過去5年〜10年） | 数十億件以上 | S3 経由バルクロード（アーカイブ） | Snowball + S3 + DMS |
| 売上集計データ | 数十億件 | S3 + Redshift COPY コマンド | DataSync + Glue |

**LOB データの扱い注意点**

商品マスタに商品画像（BLOB）が格納されている場合は DMS の LOB 設定が必要:

```
DMS タスク設定:
  LOBモード: Limited LOB Mode（最大LOBサイズを指定、例: 32KB）
  ─ 指定サイズを超えるLOBはNULLに変換される（事前に最大サイズを確認すること）

または:
  LOBモード: Full LOB Mode（全LOBを移行するが速度が大幅低下）
  ─ 商品画像はS3に移行し、DBはS3パスを参照する設計に変更推奨
```

### 7-4. CDC の仕組みと設定要件

CDC（Change Data Capture）は DB のトランザクションログを解析して変更差分を取得する技術。

```
[ソースDB のトランザクションログ]
  MySQL:      binlog (ROW形式で有効化が必要)
  PostgreSQL: WAL (wal_level=logical に設定)
  Oracle:     Supplemental Logging (ALL COLUMNS)
  SQL Server: MS-CDC の有効化

[DMS がログを読み取り、ターゲットに適用]
  INSERT → ターゲットにINSERT
  UPDATE → ターゲットにUPDATE
  DELETE → ターゲットにDELETE（または論理削除フラグ更新）
```

**DDL変更（テーブル追加・カラム追加）への対応**

CDC 期間中にソース DB でスキーマ変更が発生すると CDC が停止することがある。対策:

- 移行期間中のスキーマ変更禁止（変更凍結）をステークホルダーと合意する
- DMS の「DDL文の処理」設定を「無視」または「エラーを記録して継続」に設定する
- ストコン案件では移行フェーズ中のスキーマ変更を変更管理委員会（CCB）で厳格に管理する

---

## 8. テスト戦略

### 8-1. 大規模移行のテストピラミッド

```
              ┌─────────────┐
              │  UAT/本番検証 │  ← 少数（高コスト、本番同等環境）
              │（受入テスト）  │
            ┌─┴─────────────┴─┐
            │  性能・負荷テスト  │  ← 中程度（自動化、定期実施）
            │  障害注入テスト   │
          ┌─┴─────────────────┴─┐
          │   統合テスト（E2E）   │  ← 中程度（パイプライン組込み）
        ┌─┴───────────────────────┴─┐
        │     単体テスト・回帰テスト    │  ← 多数（完全自動化）
        └───────────────────────────┘
```

### 8-2. 性能テスト（14,663店舗の同時接続シミュレーション）

**シミュレーション設計の前提値**

| パラメーター | 値 | 根拠 |
|------------|---|------|
| 総店舗数 | 14,663店舗 | 案件規模 |
| 同時接続ピーク率 | 80%（11,730店舗が同時接続） | 発注締め切り時間帯 |
| 1店舗あたりのRPS | 5〜10 req/sec（ピーク時） | 業務パターン分析 |
| 想定ピークRPS | 最大 117,300 req/sec | 11,730店舗 × 10 RPS |
| レスポンスタイム目標 | p95 < 500ms、p99 < 1,000ms | 旧システムの性能基準 |
| 可用性目標 | 99.95%以上（月間ダウンタイム 21分以内） | SLA要件 |

**性能テストの実施ステップ**

```
Step 1: 基準値取得テスト（移行前）
  └── 旧オンプレ環境に対して同等の負荷をかけ、現状の性能基準を記録

Step 2: コンポーネントテスト（移行後・個別）
  ├── Aurora の IOPS・接続数・レイテンシをDBベンチマーク（sysbench等）で計測
  └── ECS サービスの CPU・メモリ使用率を確認

Step 3: 統合負荷テスト（移行後・全体）
  ├── AWS上の新システムに対し、Apache JMeter / k6 / Locust で14,663店舗相当の負荷をシミュレート
  ├── テストシナリオ: 発注処理・商品マスタ参照・在庫照会の混合シナリオ
  └── スパイクテスト: 通常の3倍の負荷を数分間投入

Step 4: 長時間安定性テスト（Soak Test）
  └── 通常負荷の80%で24〜72時間継続し、メモリリーク・コネクションリークを検出
```

**負荷テストツールの選択**

| ツール | 特徴 | ストコンでの推奨用途 |
|-------|------|------------------|
| **Apache JMeter** | GUI操作、多機能、無料 | 機能テスト兼用の統合テスト |
| **k6 (Grafana Labs)** | コード記述（JavaScript）、軽量、CI統合容易 | CI/CDパイプライン組込み負荷テスト |
| **Locust** | Pythonで記述、分散テスト対応 | カスタムシナリオの記述が多い場合 |
| **AWS Distributed Load Testing** | AWSネイティブ、スケールアウト容易 | AWS環境に閉じた大規模テスト |

### 8-3. 障害注入テスト（Chaos Engineering with AWS FIS）

AWS FIS（Fault Injection Simulator）を使い、意図的に障害を発生させてシステムの回復力を確認する。

**テスト対象と注入する障害の例**

| テスト対象 | 注入する障害 | 期待する挙動 | FIS アクション |
|---------|-----------|------------|--------------|
| EC2/ECS インスタンス | CPUスパイク（100%占有） | Auto Scaling が新インスタンスを起動しトラフィック継続 | aws:ec2:cpu-stress |
| EC2/ECS インスタンス | インスタンス停止 | ALBがヘルスチェック失敗を検知し、残インスタンスへルーティング | aws:ec2:stop-instances |
| Aurora DB | フェイルオーバー強制実行 | 60秒以内にスタンバイが昇格し、接続が自動復旧 | aws:rds:failover-db-cluster |
| ネットワーク | AZ間ネットワーク遅延注入（+200ms） | レイテンシ悪化でアラート発火、自動スケールアウト | aws:network:disrupt-connectivity |
| ECS タスク | ランダムタスク終了 | ECSサービスが自動的に新タスクを起動 | aws:ecs:stop-task |

**FIS 実験テンプレートの設計例**

```json
{
  "description": "Aurora フェイルオーバー耐久テスト",
  "targets": {
    "aurora-cluster": {
      "resourceType": "aws:rds:cluster",
      "selectionMode": "COUNT(1)"
    }
  },
  "actions": {
    "failover": {
      "actionId": "aws:rds:failover-db-cluster",
      "parameters": {},
      "targets": { "Clusters": "aurora-cluster" }
    }
  },
  "stopConditions": [
    {
      "source": "aws:cloudwatch:alarm",
      "value": "storcon-critical-error-rate-alarm"
    }
  ]
}
```

**注意点**: FIS は本番環境で実行しないこと。ステージング環境（本番同等構成）での実施が原則。初回はブレーカーアラームを必ず設定して、テストが想定外に拡大しないよう安全策を入れる。

### 8-4. UAT（受入テスト）の設計

**UAT参加者の構成**

| 参加者 | 確認観点 | テストシナリオ例 |
|-------|---------|--------------|
| 店舗オペレーター（SV・店長） | 業務フローの違和感、操作感の変化 | 通常発注、緊急発注、棚卸、廃棄登録 |
| 本部MD担当 | 商品マスタ反映速度、発注データの正確性 | 新商品登録→店舗反映確認（リードタイム） |
| IT部門 | システム間連携、セキュリティ、ログ確認 | EDI連携、POS連携、監査ログ出力 |
| 情報セキュリティ担当 | セキュリティ要件の充足確認 | 不正アクセスシミュレーション、暗号化確認 |

**UAT期間の設計**

```
UAT フェーズ設計:
  ├── Phase 1: 機能確認 UAT（2週間）
  │     ─ 全業務フローを新システムで実施できることを確認
  │     ─ 旧システムとの出力差分（帳票、データ）を突合
  ├── Phase 2: 並行運用 UAT（4週間）
  │     ─ 旧旧システムと新システムを並走させ、出力結果を比較
  │     ─ 差異があれば原因を特定して修正
  └── Phase 3: パイロット UAT（本番環境・実店舗）
        ─ パイロット店舗の実業務データで最終確認
        ─ カットオーバー判断の材料
```

---

## 9. コスト最適化戦略

### 9-1. 購入オプションの比較

| 購入オプション | 概要 | 割引率（オンデマンド比） | 適用条件 | ストコンでの用途 |
|-------------|------|------------------|---------|--------------|
| **オンデマンド** | 使った分だけ時間課金 | 0%（基準） | なし | 開発・検証環境、ピーク対応の追加分 |
| **Reserved Instances (RI)** | 1年または3年の使用を予約 | 最大72%（3年・前払い） | 1〜3年の確約 | 常時稼働するアプリサーバー・DBサーバー |
| **Savings Plans** | コンピュート使用量を確約（柔軟） | 最大66%（Compute） | 1〜3年の使用量確約 | ECS/Lambda/EC2 をまたいだ柔軟な割引 |
| **Spot Instances** | 空きキャパシティを入札で利用 | 最大90%オフ | 中断可能なワークロード | バッチ処理、負荷テスト |

**RI vs Savings Plans の選択基準**

```
RI を選ぶべきケース:
  ├── 特定のインスタンスタイプを長期間固定使用（Aurora db.r6g.xlarge など）
  ├── DBインスタンスは RDS RI のみが対象（Savings Plans 対象外）
  └── RIの方が割引率が高い場合（インスタンスタイプ固定のEC2）

Savings Plans を選ぶべきケース:
  ├── ECS/Fargate + Lambda + EC2 を混在使用する場合
  ├── インスタンスタイプを将来変更する可能性がある
  └── リージョンをまたいで使用する可能性がある
```

**ストコン案件での推奨購入戦略**

| リソース | 推奨オプション | 理由 |
|---------|-------------|------|
| Aurora Primary（本番） | RDS Reserved Instance（1年）| DBは Savings Plans 対象外、1年で実績確認後3年へ |
| ECS/Fargate（APIサーバー） | Compute Savings Plans（1年） | コンテナ数・インスタンスタイプが変動する |
| バッチ処理（AWS Batch） | Spot Instances | 中断可能、コスト最大90%削減 |
| 開発・検証環境 | オンデマンド | 夜間停止で実コストを削減 |
| ElastiCache（Redis） | Reserved（1年） | 安定した使用量、割引効果大 |

### 9-2. コスト見積もりフレームワーク（AWS Pricing Calculator 活用）

**月額ランニングコストの試算構造**

```
総コスト = コンピュート + データベース + ストレージ + ネットワーク + その他

コンピュート（ECS/Fargate）:
  ─ 本番: 常時6タスク（vCPU: 4, Memory: 8GB）× $0.04/vCPU-hour × 24h × 30日
  ─ 非本番: 常時2タスク（開発/ステージング）

データベース（Aurora MySQL）:
  ─ Primary: db.r6g.2xlarge × 1インスタンス（RI適用後の実効単価）
  ─ Reader: db.r6g.xlarge × 2インスタンス（読み取り分散）
  ─ Aurora Serverless v2 は管理系APIに使用

ストレージ（S3）:
  ─ 商品マスタバックアップ・ログアーカイブ：数TB/月
  ─ S3 Standard → Intelligent-Tiering で自動コスト最適化

ネットワーク:
  ─ 店舗→AWS間のデータ転送量（アウトバウンド）が最大コスト要因
  ─ API Gateway の呼び出し数（14,663店舗 × 1日100回 ≒ 1.5億回/月）
```

**月額コスト試算（参考値）**

| カテゴリ | サービス | 月額試算 | 前提 |
|---------|---------|---------|------|
| コンピュート | ECS/Fargate（本番6タスク） | 約 8万円 | Savings Plans適用後 |
| DB | Aurora MySQL Multi-AZ | 約 15万円 | db.r6g.xlarge RI 1年前払い |
| DB | ElastiCache Redis | 約 3万円 | cache.r6g.large RI |
| ストレージ | S3（Standard + Glacier） | 約 2万円 | 10TB想定 |
| ネットワーク | API Gateway（1.5億リクエスト/月） | 約 8万円 | HTTP API料金 |
| ネットワーク | データ転送アウト | 約 3万円 | 1TB/月想定 |
| セキュリティ | WAF + Shield Standard | 約 5万円 | WAF WebACL 1個 |
| 監視 | CloudWatch（メトリクス+ログ） | 約 3万円 | カスタムメトリクス50個 |
| **合計** | | **約 47万円/月** | 最小構成・RI適用後 |

※ 本番・DR・開発/検証の全環境合計では 1.5〜2倍の規模感（70〜100万円/月）になる可能性。前回調査のDB合計78万円/月（RI未適用）と合わせて精査が必要。

### 9-3. コスト最適化の継続的改善サイクル

```
月次コストレビューのサイクル:
  ├── AWS Cost Explorer で前月比・前年同月比を確認
  ├── AWS Trusted Advisor で「未使用リソース」「過剰プロビジョニング」を検出
  ├── AWS Compute Optimizer でインスタンスサイズの最適化推奨を確認
  └── Savings Plans/RI の購入を検討（使用率 70%超が目安）

Cost Allocation タグ戦略:
  ├── Environment: production / staging / development
  ├── Component: api / batch / database / cache
  ├── BusinessUnit: order-management / inventory / reporting
  └── Wave: pilot / wave1 / wave2 / national
```

---

## 10. ストコン案件 PM視点の論点整理

移行プロジェクトに PM として参画する際に、特に重要な判断ポイントを整理する。

### 論点1: MAP 適用の判断タイミングとパートナー選定

MAP（Migration Acceleration Program）の移行クレジットを得るには、**移行開始前に MAP 認定パートナーと契約すること**が前提となる。プロジェクト発足直後の調達フェーズで、NEC・富士通・アクセンチュアなど複数の MAP 認定パートナーに MAP 適用可否と移行クレジット見積もりを照会すること。数百万ドル規模のクレジットがつく可能性があり、プロジェクト総予算への影響が大きい。

### 論点2: カットオーバーのタイムウィンドウ設計

コンビニは 24/365 営業のため「完全なシステム停止」が許容されない。発注締め切り時間帯（23時〜翌2時）と日次精算時間帯（深夜）を避けた「メンテナンスウィンドウ」を設計する必要がある。**実際に使えるメンテナンスウィンドウは毎日朝 4時〜6時の 2時間程度**と想定され、この時間内に完了できない移行作業は複数日に分割する計画が必要。Blue/Green とカナリアを組み合わせ「店舗ごとに段階切り替え」することでウィンドウを不要にする設計も検討価値がある。

### 論点3: データの切り捨て vs 完全移行の判断

数十億件の過去トランザクションデータを全量移行するか、一定年数でカットオフするかはコストとリスクに直結する。AWS Snowball での物理輸送が必要になる可能性（TB〜PBオーダー）もあるため、移行フェーズ計画前に「何年分のデータを移行するか」をクライアントと合意しておく。参考として、5年分のトランザクション → S3 アーカイブ（Glacier）、直近1年分 → Aurora もしくは Redshift での即時参照可能な状態、という2段階保管が一般的。

### 論点4: CDC 期間中のスキーマ変更凍結の調整

DMS の CDC が動いている期間（数ヶ月に及ぶ）は、ソース DB へのスキーマ変更（ALTER TABLE 等）が CDC を破壊するリスクがある。この期間、クライアントの通常業務でのシステム改修・機能追加が制限されることを**プロジェクト開始前にステークホルダーへ説明し合意を得ること**が必須。変更管理委員会（CCB）の設置と「変更凍結ポリシー」の策定を移行計画フェーズの成果物に含める。

### 論点5: オフライン耐性の要件定義と AWS 構成の整合性確認

店舗のネットワーク障害時にもストコンが動作し続けるオフライン耐性は、AWS 移行後も維持しなければならない非機能要件。クラウド化によって「すべての処理がクラウド API 依存になる」設計はアンチパターン。移行後も店舗端末のローカルキャッシュ（SQLite）とクラウド間の差分同期パターンを維持する設計が必要で、これは AWS Architecture の SA と連携して非機能要件として要件定義書に明記する必要がある。PM として設計フェーズのレビューでこの観点を必ず確認すること。

---

## 11. Sources

| カテゴリ | 参照先 |
|---------|--------|
| AWS Migration Hub 概要 | [AWS Migration Hub ドキュメント](https://docs.aws.amazon.com/migrationhub/latest/ug/whatishub.html) |
| Application Migration Service | [MGN ユーザーガイド](https://docs.aws.amazon.com/mgn/latest/ug/what-is-application-migration-service.html) |
| Application Discovery Service | [ADS ドキュメント](https://docs.aws.amazon.com/application-discovery/latest/userguide/what-is-appdiscovery.html) |
| AWS MAP プログラム | [Migration Acceleration Program](https://aws.amazon.com/migration-acceleration-program/) |
| AWS Control Tower / Landing Zone | [Control Tower ドキュメント](https://docs.aws.amazon.com/controltower/latest/userguide/what-is-control-tower.html) |
| DMS ユーザーガイド | [AWS Database Migration Service](https://docs.aws.amazon.com/dms/latest/userguide/Welcome.html) |
| DMS CDC 設定 | [DMS CDC 要件](https://docs.aws.amazon.com/dms/latest/userguide/CHAP_Task.CDC.html) |
| AWS FIS ドキュメント | [AWS Fault Injection Simulator](https://docs.aws.amazon.com/fis/latest/userguide/what-is.html) |
| AWS Prescriptive Guidance（移行戦略） | [Prescriptive Guidance - Migration](https://aws.amazon.com/prescriptive-guidance/?apg-all-cards.sort-by=item.additionalFields.sortDate&apg-all-cards.sort-order=desc&awsf.apg-new-filter=*all&awsf.apg-content-type-filter=*all&awsf.apg-category-filter=categories%23migration-transfer) |
| AWS Well-Architected Framework（信頼性ピラー） | [Reliability Pillar Whitepaper](https://docs.aws.amazon.com/wellarchitected/latest/reliability-pillar/welcome.html) |
| Blue/Green Deployment on AWS | [AWS Prescriptive Guidance - Blue/Green](https://docs.aws.amazon.com/prescriptive-guidance/latest/blue-green-deployments/welcome.html) |
| Savings Plans | [AWS Savings Plans ドキュメント](https://docs.aws.amazon.com/savingsplans/latest/userguide/what-is-savings-plans.html) |
| Reserved Instances | [EC2 Reserved Instances](https://aws.amazon.com/ec2/pricing/reserved-instances/) |
| AWS Cost Explorer | [Cost Explorer ドキュメント](https://docs.aws.amazon.com/cost-management/latest/userguide/ce-what-is.html) |
| 小売業界のAWS活用事例 | [AWS 小売業界ソリューション](https://aws.amazon.com/jp/solutions/case-studies/retail/) |
| 7R 移行戦略解説 | [AWS 7 R's Migration Strategies](https://aws.amazon.com/blogs/enterprise-strategy/6-strategies-for-migrating-applications-to-the-cloud/) |

---

*本レポートはtech-researcherが2026-04-12時点の情報をもとに作成しました。*
*既存調査 wbs-5-2-storcon-aws-migration-tech.md および wbs-4-1-1-migration-pm-overview.md の内容を踏まえた拡充版です。*
*AWSサービスの料金・仕様は変動するため、最新情報はAWS公式ドキュメントおよびAWS Pricing Calculatorで確認してください。*
