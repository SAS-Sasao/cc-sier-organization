# エンタープライズデータアーキテクチャ（MDM中心）

- **ファイル名**: enterprise-data-arch
- **図の種類**: C4モデル
- **作成日**: 2026-03-29
- **作成者**: SAS-Sasao
- **ツール**: open_drawio_mermaid
- **関連案件**: 汎用エンタープライズアーキテクチャ

## 概要

ERP・販売管理・会計・人事・CRM等の社内アプリケーションからMDM（マスタデータ管理）を通じてゴールデンレコードを抽出し、データウェアハウス・データレイクを経由してBIツールでインサイトを得る、エンタープライズデータアーキテクチャの全体像。

特定のクラウドサービスに依存しない抽象的な構成図として設計。

## アーキテクチャ層

| 層 | 役割 | 主要コンポーネント |
|---|------|-----------------|
| ソースシステム層 | 業務データの発生源 | ERP, 販売管理, 会計, 人事給与, CRM, SCM, EC/Web, レガシー |
| データ統合層 | データの収集・変換・転送 | CDC, ETL/ELT, API Gateway, メッセージキュー |
| MDM層 | マスタデータの統合管理 | 名寄せ・照合, ゴールデンレコード, データ品質管理, ガバナンス, カタログ |
| データプラットフォーム層 | データの蓄積・加工 | DWH, データレイク, データマート, ストリーム処理 |
| 分析・可視化層 | データの分析・活用 | BIダッシュボード, アドホック分析, ML/AI, アラート |
| 利用者層 | インサイトの消費 | 経営層, 部門担当者, データサイエンティスト, 外部システム |

## Mermaid ソースコード

```mermaid
flowchart LR
    subgraph sources["📦 ソースシステム層"]
        direction TB
        ERP["ERP\n基幹業務"]
        SALES["販売管理\nシステム"]
        ACCT["会計システム"]
        HR["人事給与\nシステム"]
        CRM["CRM\n顧客管理"]
        SCM["SCM\nサプライチェーン"]
        EC["EC / Web\nアプリ"]
        LEGACY["レガシー\nシステム"]
    end

    subgraph integration["🔄 データ統合層"]
        direction TB
        CDC["CDC / Change\nData Capture"]
        ETL["ETL / ELT\nパイプライン"]
        API["API Gateway\nリアルタイム連携"]
        MQ["メッセージ\nキュー"]
    end

    subgraph mdm["🏛️ MDM（マスタデータ管理）"]
        direction TB
        MATCH["名寄せ・照合\nエンジン"]
        GOLDEN["ゴールデンレコード\n（信頼できる唯一の情報源）"]
        QUALITY["データ品質\n管理"]
        GOVERN["データガバナンス\nポリシー管理"]
        CATALOG["データカタログ\nメタデータ管理"]
    end

    subgraph platform["💾 データプラットフォーム層"]
        direction TB
        DWH["データウェアハウス\n構造化データ"]
        LAKE["データレイク\n非構造化・半構造化"]
        MART["データマート\n部門別最適化"]
        STREAM["ストリーム処理\nリアルタイム分析"]
    end

    subgraph analytics["📊 分析・可視化層"]
        direction TB
        BI["BIツール\nダッシュボード・レポート"]
        ADHOC["アドホック分析\nセルフサービスBI"]
        ML["ML / AI\n予測分析・最適化"]
        ALERT["アラート・通知\n閾値監視"]
    end

    subgraph consumers["👤 利用者"]
        direction TB
        EXEC["経営層\n意思決定"]
        DEPT["部門担当者\n業務改善"]
        DS["データサイエンティスト\n高度分析"]
        SYS["外部システム\nAPI連携"]
    end

    ERP --> CDC
    SALES --> CDC
    ACCT --> ETL
    HR --> ETL
    CRM --> API
    SCM --> MQ
    EC --> API
    LEGACY --> ETL

    CDC --> MATCH
    ETL --> MATCH
    API --> MATCH
    MQ --> MATCH

    MATCH --> GOLDEN
    GOLDEN --> QUALITY
    QUALITY --> GOVERN
    GOLDEN --> CATALOG

    GOLDEN --> DWH
    GOLDEN --> LAKE
    DWH --> MART
    LAKE --> STREAM

    DWH --> BI
    MART --> BI
    LAKE --> ADHOC
    STREAM --> ALERT
    LAKE --> ML

    BI --> EXEC
    BI --> DEPT
    ADHOC --> DS
    ML --> DS
    ALERT --> DEPT
    ML --> SYS
```
