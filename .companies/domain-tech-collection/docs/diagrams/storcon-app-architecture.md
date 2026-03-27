# StoreCon Application Architecture

## メタデータ

| 項目 | 値 |
|------|-----|
| ファイル名 | storcon-app-architecture |
| 案件 | コンビニストコンAWS移行 |
| 領域 | Application |
| 生成日 | 2026-03-27 |
| MCP Server | awslabs.aws-diagram-mcp-server |
| 公開URL | [GitHub Pages](https://sas-sasao.github.io/cc-sier-organization/diagrams/storcon-app-architecture.html) |

## 使用AWSサービス

- Amazon CloudFront
- AWS WAF
- Amazon API Gateway
- Amazon Cognito
- Amazon ECS Fargate (Ordering / Inventory / Sales / Staff)
- Amazon SQS
- AWS Lambda
- Amazon ElastiCache (Redis)
- Amazon Aurora
- Amazon DynamoDB
- Amazon S3
- Amazon CloudWatch
- AWS X-Ray

## 外部サービス

- Store Computer (店舗端末)
- Mobile Client

## ソースコード（Python diagrams DSL）

```python
with Diagram("StoreCon Application Architecture", show=False, direction="LR", filename="storcon-app-architecture", graph_attr={"fontsize": "16", "pad": "0.5"}):

    # Client Layer
    with Cluster("Client (Store)"):
        store = TraditionalServer("Store\nComputer")
        mobile = MobileClient("Mobile\nClient")

    # Edge Layer
    with Cluster("Edge & Security"):
        cf = CloudFront("CloudFront\n(CDN)")
        waf = WAF("WAF\n(Firewall)")

    # API Layer
    with Cluster("API Layer"):
        apigw = APIGateway("API Gateway\n(REST API)")
        cognito = Cognito("Cognito\n(Auth)")

    # Compute Layer - Microservices
    with Cluster("Microservices (ECS Fargate)"):
        with Cluster("Ordering Service"):
            svc_order = ECS("Ordering\nService")
        with Cluster("Inventory Service"):
            svc_inv = ECS("Inventory\nService")
        with Cluster("Sales Service"):
            svc_sales = ECS("Sales\nService")
        with Cluster("Staff Service"):
            svc_staff = ECS("Staff\nService")

    # Async Layer
    with Cluster("Async Processing"):
        sqs = SQS("SQS\n(Message Queue)")
        lmb = Lambda("Lambda\n(Event Handler)")

    # Cache
    with Cluster("Cache"):
        redis = ElastiCache("ElastiCache\n(Redis)")

    # Database Layer
    with Cluster("Database"):
        aurora = Aurora("Aurora\n(Transaction DB)")
        dynamo = Dynamodb("DynamoDB\n(Product Master)")

    # Storage
    with Cluster("Storage"):
        s3 = S3("S3\n(Files / Reports)")

    # Monitoring
    with Cluster("Observability"):
        cw = Cloudwatch("CloudWatch\n(Metrics & Logs)")
        xray = XRay("X-Ray\n(Tracing)")

    # Flow: Client → Edge → API
    store >> Edge(color="darkblue", style="bold") >> cf
    mobile >> Edge(color="darkblue", style="bold") >> cf
    cf >> waf >> apigw
    cognito >> Edge(label="Auth", color="red", style="dashed") >> apigw

    # Flow: API → Microservices
    apigw >> Edge(label="Route", color="darkgreen", style="bold") >> svc_order
    apigw >> Edge(color="darkgreen", style="bold") >> svc_inv
    apigw >> Edge(color="darkgreen", style="bold") >> svc_sales
    apigw >> Edge(color="darkgreen", style="bold") >> svc_staff

    # Flow: Microservices → Async
    svc_order >> Edge(label="Async", color="purple", style="dashed") >> sqs
    svc_sales >> Edge(color="purple", style="dashed") >> sqs
    sqs >> lmb

    # Flow: Microservices → Cache & DB
    svc_order >> redis
    svc_inv >> redis
    redis >> Edge(label="Cache Miss", color="gray", style="dashed") >> dynamo

    svc_order >> aurora
    svc_inv >> aurora
    svc_sales >> aurora
    svc_staff >> aurora

    # Flow: Lambda → Storage
    lmb >> s3
    lmb >> dynamo

    # Monitoring
    svc_order >> Edge(style="dashed", color="gray") >> cw
    svc_inv >> Edge(style="dashed", color="gray") >> xray
    apigw >> Edge(style="dashed", color="gray") >> cw
```
