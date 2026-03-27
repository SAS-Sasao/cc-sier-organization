# StoreCon AWS Migration - DWH Architecture

## メタデータ

| 項目 | 値 |
|------|-----|
| ファイル名 | storcon-dwh-architecture |
| 案件 | コンビニストコンAWS移行 |
| 領域 | DWH / データ基盤 |
| 生成日 | 2026-03-27 |
| MCP Server | awslabs.aws-diagram-mcp-server |
| 公開URL | [GitHub Pages](https://sas-sasao.github.io/cc-sier-organization/diagrams/storcon-dwh-architecture.html) |

## 使用AWSサービス

- Amazon S3 (Raw / Processed / Curated)
- AWS DMS (Database Migration Service)
- Amazon Kinesis Data Streams
- Amazon Kinesis Data Firehose
- AWS Glue (ETL)
- AWS Glue Data Catalog
- AWS Lake Formation
- Amazon Redshift
- Amazon Athena
- Amazon QuickSight

## ソースコード（Python diagrams DSL）

```python
with Diagram("StoreCon AWS Migration - DWH Architecture", show=False, direction="LR", filename="storcon-dwh-architecture", graph_attr={"fontsize": "16", "pad": "0.5"}):

    # Data Sources (On-premises)
    with Cluster("On-Premises (Store)"):
        pos = EC2("POS Terminal")
        storcon = EC2("Store Computer")

    # Data Ingestion
    with Cluster("Data Ingestion"):
        dms = DMS("Database\nMigration Service")
        kinesis = KinesisDataStreams("Kinesis\nData Streams")
        firehose = KinesisDataFirehose("Kinesis\nData Firehose")

    # Data Lake
    with Cluster("Data Lake (S3)"):
        with Cluster("Storage Tiers"):
            s3_raw = S3("Raw Data")
            s3_processed = S3("Processed Data")
            s3_curated = S3("Curated Data")

        with Cluster("ETL & Governance"):
            glue = Glue("AWS Glue\n(ETL)")
            catalog = GlueDataCatalog("Glue Data\nCatalog")
            lakeformation = LakeFormation("Lake\nFormation")

    # DWH & Analytics
    with Cluster("DWH & Analytics"):
        redshift = Redshift("Amazon\nRedshift")
        athena = Athena("Amazon\nAthena")

    # BI
    with Cluster("Visualization"):
        quicksight = Quicksight("Amazon\nQuickSight")

    # Batch flow
    storcon >> Edge(label="Batch", color="darkblue", style="bold") >> dms >> s3_raw
    # Realtime flow
    pos >> Edge(label="Realtime", color="darkgreen", style="bold") >> kinesis >> firehose >> s3_raw

    # Data lake internal
    s3_raw >> glue >> s3_processed
    s3_processed >> glue >> s3_curated
    glue >> catalog
    lakeformation >> catalog

    # Analytics
    s3_curated >> redshift >> quicksight
    s3_curated >> athena >> quicksight
```
