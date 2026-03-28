# AI-Driven Dev Knowledge Platform

## メタデータ

| 項目 | 値 |
|------|-----|
| ファイル名 | ai-dev-knowledge-platform |
| 案件 | 技術ドメイン収集 |
| 領域 | AI / Knowledge Base |
| 生成日 | 2026-03-28 |
| MCP Server | awslabs.aws-diagram-mcp-server |
| レビュー | aws-knowledge-mcp-server (6軸 Pass) |
| 公開URL | [GitHub Pages](https://sas-sasao.github.io/cc-sier-organization/diagrams/ai-dev-knowledge-platform.html) |

## 使用AWSサービス

- Amazon Bedrock (Claude)
- Amazon OpenSearch Serverless (Vector Store)
- Amazon S3 (Domain Knowledge / Dev Patterns / Member Profiles)
- AWS Lambda (Query Handler / Context Enricher / Chunker)
- AWS Step Functions (Ingestion Orchestrator)
- Amazon EventBridge (Scheduler)
- Amazon API Gateway
- Amazon CloudFront
- AWS WAF
- Amazon Cognito
- Amazon DynamoDB (Session & History)
- Amazon CloudWatch

## ソースコード（Python diagrams DSL）

```python
with Diagram("AI-Driven Dev Knowledge Platform", show=False, direction="LR", filename="ai-dev-knowledge-platform", graph_attr={"fontsize": "16", "pad": "0.5"}):

    # Development Team
    with Cluster("Development Team"):
        dev = User("Developer")
        pm = User("PM / Lead")

    # Knowledge Sources
    with Cluster("Knowledge Sources"):
        wiki = TraditionalServer("Confluence\n/ Wiki")
        repo = TraditionalServer("GitHub\nRepositories")
        design = TraditionalServer("Design Docs\n/ ADR")
        member = GenericDatabase("Member DB\n(Skills / Roles)")

    # Ingestion Pipeline
    with Cluster("Ingestion Pipeline"):
        eb = Eventbridge("EventBridge\n(Scheduler)")
        sfn = StepFunctions("Step Functions\n(Orchestrator)")
        chunker = Lambda("Chunker\n& Processor")

    # Knowledge Store
    with Cluster("Knowledge Store"):
        s3_domain = S3("Domain\nKnowledge")
        s3_dev = S3("Dev Patterns\n& Standards")
        s3_member = S3("Member\nProfiles")

    # Bedrock Knowledge Base
    with Cluster("Bedrock Knowledge Base"):
        bedrock = Bedrock("Amazon Bedrock\n(Claude)")
        opensearch = AmazonOpensearchService("OpenSearch\nServerless\n(Vector Store)")

    # API Layer
    with Cluster("Edge & API"):
        cf = CloudFront("CloudFront")
        waf = WAF("WAF")
        apigw = APIGateway("API Gateway")
        cognito = Cognito("Cognito\n(Auth)")

    # Application
    with Cluster("Application Layer"):
        query_fn = Lambda("Query\nHandler")
        context_fn = Lambda("Context\nEnricher")
        dynamo = Dynamodb("DynamoDB\n(Session &\nHistory)")

    # Observability
    with Cluster("Observability"):
        cw = Cloudwatch("CloudWatch\n(Metrics & Logs)")

    # === Flow 1: Knowledge Ingestion (darkblue, bold) ===
    wiki >> Edge(label="Ingest", color="darkblue", style="bold") >> sfn
    repo >> Edge(color="darkblue", style="bold") >> sfn
    design >> Edge(color="darkblue", style="bold") >> sfn
    sfn >> chunker
    chunker >> Edge(color="darkblue", style="bold") >> s3_domain
    chunker >> Edge(color="darkblue", style="bold") >> s3_dev

    # === Flow 2: Member Sync (purple, bold) ===
    member >> Edge(label="Sync", color="purple", style="bold") >> sfn
    chunker >> Edge(color="purple", style="bold") >> s3_member

    # === Flow 3: Indexing to Vector Store (darkblue) ===
    s3_domain >> Edge(label="Index", color="darkblue") >> opensearch
    s3_dev >> Edge(color="darkblue") >> opensearch
    s3_member >> Edge(color="purple") >> opensearch

    # === Flow 4: Scheduled Trigger (darkorange, dashed) ===
    eb >> Edge(label="Trigger", color="darkorange", style="dashed") >> sfn

    # === Flow 5: RAG Query (darkgreen, bold) ===
    dev >> Edge(color="darkgreen", style="bold") >> cf
    pm >> Edge(color="darkgreen", style="bold") >> cf
    cf >> waf >> apigw
    cognito >> Edge(label="Auth", color="red", style="dashed") >> apigw
    apigw >> Edge(label="Query", color="darkgreen", style="bold") >> query_fn
    query_fn >> Edge(label="Enrich", color="darkgreen", style="bold") >> context_fn
    context_fn >> Edge(label="RAG", color="darkgreen", style="bold") >> bedrock
    bedrock >> Edge(color="darkgreen", style="bold") >> opensearch

    # === Session Management (purple, dashed) ===
    query_fn >> Edge(label="History", color="purple", style="dashed") >> dynamo
    context_fn >> Edge(color="purple", style="dashed") >> dynamo

    # === Monitoring (gray, dashed) ===
    query_fn >> Edge(style="dashed", color="gray") >> cw
    bedrock >> Edge(style="dashed", color="gray") >> cw
```
