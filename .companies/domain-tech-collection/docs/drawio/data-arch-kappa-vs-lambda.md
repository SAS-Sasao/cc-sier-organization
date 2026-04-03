# Lambda vs Kappa アーキテクチャ比較

- **種類**: UML Architecture
- **作成日**: 2026-04-03
- **作成者**: SAS-Sasao
- **ツール**: draw.io MCP (`open_drawio_xml`)
- **draw.ioファイル**: [data-arch-kappa-vs-lambda.drawio](../../../docs/drawio/data-arch-kappa-vs-lambda.drawio)
- **HTMLページ**: [data-arch-kappa-vs-lambda.html](../../../docs/drawio/data-arch-kappa-vs-lambda.html)

## 概要

大規模データ処理の2大アーキテクチャパターン（Lambda / Kappa）を同一キ��ンバス上で
並列比較するUMLスタイルの構成図。UMLアクター、シリンダー（DB）、コンポーネント（処理エンジン）を
適切に使い分け、全データフローを可視化。

## 主要コンポーネント

### Lambda Architecture
- Apache Kafka (Message Broker)
- Batch Layer: Hadoop HDFS → Apache Spark → Batch Views (Druid/HBase)
- Speed Layer: Apache Flink/Storm → Real-time Views (Redis/Cassandra)
- Serving Layer: Presto/Trino (Merge Views)

### Kappa Architecture
- Apache Kafka (Immutable Log / Long Retention)
- Stream Processor: Apache Flink / Kafka Streams
- Serving Store: Elasticsearch / Cassandra
- Reprocessing: Log Replay from offset 0
