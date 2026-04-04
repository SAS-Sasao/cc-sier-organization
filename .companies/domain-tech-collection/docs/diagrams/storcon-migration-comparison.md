# StoreCon Migration: On-Premise to AWS

## メタデータ

| 項目 | 値 |
|------|-----|
| ファイル名 | storcon-migration-comparison |
| 案件 | コンビニストコンAWS移行 |
| 領域 | Migration |
| 生成日 | 2026-04-04 |
| MCP Server | Python diagrams (uvx) |
| 公開URL | [GitHub Pages](https://sas-sasao.github.io/cc-sier-organization/diagrams/storcon-migration-comparison.html) |

## 使用AWSサービス

- Amazon CloudFront
- AWS WAF
- Amazon Cognito
- Amazon API Gateway
- Amazon ECS Fargate (Ordering / Inventory / Sales / Staff)
- Amazon SQS (FIFO)
- AWS Lambda
- AWS Step Functions
- Amazon Aurora Serverless v2
- Amazon DynamoDB
- Amazon ElastiCache (Redis)
- Amazon Redshift Serverless
- Amazon S3
- Amazon S3 Glacier
- Amazon CloudWatch
- AWS CloudTrail
- AWS Direct Connect
- Amazon VPC (Multi-AZ)
- AWS DMS / SCT (Migration Tools)

## On-Premise コンポーネント

- EOS/EOB Order Management (Server)
- Oracle Database
- SQL Server DWH
- Store Computer

## ソースコード（Python diagrams DSL）

```python
with Diagram('StoreComputer Migration On-Premise to AWS', show=False,
             filename='storcon-migration-comparison',
             graph_attr={'fontsize': '14', 'pad': '0.5'}):

    with Cluster('On-Premise (Current)'):
        store_sc = Server('Store Computer')
        hq_eos = Server('EOS Order Mgmt')
        hq_oracle = Oracle('Oracle DB')
        hq_mssql = MSSQL('SQL Server DWH')

    with Cluster('Migration Tools'):
        dms = DMS('DMS / SCT')

    with Cluster('AWS Cloud (Target)'):
        with Cluster('Edge and Security'):
            cf = CloudFront('CloudFront')
            waf = WAF('WAF')
            cognito = Cognito('Cognito')

        apigw = APIGateway('API Gateway')

        with Cluster('Microservices - ECS Fargate'):
            svc_order = Fargate('Ordering')
            svc_inv = Fargate('Inventory')
            svc_sales = Fargate('Sales')
            svc_staff = Fargate('Staff')

        with Cluster('Async Processing'):
            sqs = SQS('SQS FIFO')
            lmb = Lambda('Lambda')
            sf = StepFunctions('Step Functions')

        with Cluster('Data Layer - Multi-AZ'):
            aurora = Aurora('Aurora')
            dynamo = Dynamodb('DynamoDB')
            redis = ElastiCache('ElastiCache Redis')
            redshift = Redshift('Redshift DWH')

        with Cluster('Storage'):
            s3 = S3('S3')
            glacier = S3Glacier('Glacier')

        with Cluster('Observability'):
            cw = Cloudwatch('CloudWatch')
            ct = Cloudtrail('CloudTrail')

        with Cluster('Network'):
            dx = DirectConnect('Direct Connect')
            vpc = VPC('VPC Multi-AZ')

    # On-Prem flows
    store_sc >> Edge(color='gray', style='dashed') >> hq_eos
    hq_eos >> Edge(color='darkblue', style='bold') >> hq_oracle

    # Migration flows
    hq_oracle >> Edge(color='darkorange', style='bold', label='DB Migration') >> dms
    hq_mssql >> Edge(color='darkorange', style='bold', label='DWH Migration') >> dms
    dms >> Edge(color='darkorange', style='bold') >> aurora
    dms >> Edge(color='darkorange', style='dashed') >> redshift

    # Edge -> API
    cf >> Edge(color='darkgreen', style='bold') >> waf >> Edge(color='darkgreen', style='bold') >> apigw
    cognito >> Edge(color='red', style='dashed', label='Auth') >> apigw

    # API -> Microservices
    apigw >> Edge(color='darkgreen', style='bold') >> svc_order
    apigw >> Edge(color='darkgreen') >> svc_inv
    apigw >> Edge(color='darkgreen') >> svc_sales
    apigw >> Edge(color='darkgreen') >> svc_staff

    # Async
    svc_order >> Edge(color='purple', style='dashed') >> sqs
    sqs >> Edge(color='purple') >> lmb
    svc_sales >> Edge(color='purple', style='dashed') >> sf

    # Data
    svc_order >> Edge(color='teal') >> aurora
    svc_inv >> Edge(color='teal') >> dynamo
    svc_inv >> Edge(color='teal', style='dashed') >> redis
    svc_sales >> Edge(color='teal') >> aurora
    lmb >> Edge(color='teal') >> s3
    s3 >> Edge(color='gray', style='dashed') >> glacier

    # Monitoring
    svc_order >> Edge(color='gray', style='dashed') >> cw
    dx >> Edge(color='darkblue', style='bold') >> vpc
```
