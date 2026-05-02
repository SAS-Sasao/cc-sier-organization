"""Generate AWS migration architecture diagram for cc-sier-organization webapp.

Renders the Phase 4 (AWS migration) future-state architecture as a
deployment diagram using the python `diagrams` package + GraphViz.

Output: cc-sier-webapp-aws-migration.png (working directory)
"""
from diagrams import Diagram, Cluster, Edge
from diagrams.aws.compute import AppRunner, Fargate
from diagrams.aws.network import Route53, CloudFront, ALB
from diagrams.aws.database import Aurora, ElastiCache
from diagrams.aws.storage import S3
from diagrams.aws.security import WAF, Cognito, SecretsManager, KMS
from diagrams.aws.management import Cloudwatch, CloudwatchLogs, ParameterStore
from diagrams.aws.integration import SNS, Eventbridge
from diagrams.aws.ml import Bedrock
from diagrams.aws.general import Users, GenericSamlToken
from diagrams.saas.chat import Slack

with Diagram(
    "CC-SIer WebApp AWS Migration (Phase 4)",
    show=False,
    direction="LR",
    filename="cc-sier-webapp-aws-migration",
    graph_attr={"fontsize": "20", "splines": "spline", "pad": "0.5"},
):
    employees = Users("Employees (30 users)")
    admin = Users("Admin")

    with Cluster("External IdP"):
        entra = GenericSamlToken("Microsoft Entra ID")

    with Cluster("Edge Layer (AWS Global)"):
        dns = Route53("Route 53")
        waf = WAF("AWS WAF")
        cdn = CloudFront("CloudFront CDN")

    with Cluster("Identity Federation"):
        cognito = Cognito("Cognito User Pool OIDC")

    with Cluster("Frontend Tier"):
        front = AppRunner("Next.js 15 on App Runner SSR + Server Actions + SSE Proxy")

    with Cluster("Backend Tier (Private Subnet Multi-AZ)"):
        alb = ALB("Internal ALB")
        with Cluster("ECS Fargate Service"):
            fargate = Fargate("Hono + Claude Agent SDK Container")

    with Cluster("Data Tier (Private Subnet Multi-AZ)"):
        db = Aurora("Aurora PostgreSQL Serverless v2 with pgvector")
        cache = ElastiCache("ElastiCache for Redis Serverless")
        bucket = S3("S3 Artifact Bucket lifecycle 90d")

    with Cluster("AI Service"):
        bedrock = Bedrock("Amazon Bedrock Claude Sonnet 4.6 Opus 4.7")

    with Cluster("Security"):
        secrets = SecretsManager("Secrets Manager")
        kms = KMS("KMS")

    with Cluster("Operations"):
        cwlogs = CloudwatchLogs("CloudWatch Logs 90d retention")
        cwmon = Cloudwatch("CloudWatch Alarms")
        ssm = ParameterStore("SSM Parameter Store KILL_SWITCH")
        eb = Eventbridge("EventBridge Scheduler")
        sns = SNS("SNS Topic")
        slack = Slack("Slack via AWS Chatbot")

    employees >> Edge(label="HTTPS UI", color="#3b82f6") >> dns
    admin >> Edge(label="HTTPS /admin", color="#f59e0b") >> dns
    dns >> Edge(color="#3b82f6") >> waf
    waf >> Edge(color="#3b82f6") >> cdn
    cdn >> Edge(color="#3b82f6") >> front

    front >> Edge(label="OIDC", style="dashed", color="#6366f1") >> cognito
    cognito >> Edge(label="federation", style="dashed", color="#6366f1") >> entra

    front >> Edge(label="HTTPS internal HMAC", color="#9333ea", style="bold") >> alb
    alb >> Edge(color="#9333ea") >> fargate

    front >> Edge(label="Drizzle ORM metadata", color="#3b82f6") >> db
    front >> Edge(label="rate limit check", color="#f59e0b") >> cache

    fargate >> Edge(label="Bedrock InvokeModel", color="#dc2626", style="bold") >> bedrock
    fargate >> Edge(label="run_events INSERT", color="#9333ea") >> db
    fargate >> Edge(label="artifact upload", color="#10b981") >> bucket

    fargate >> Edge(label="get secret", style="dashed", color="#64748b") >> secrets
    db >> Edge(label="encryption", style="dotted", color="#64748b") >> kms
    bucket >> Edge(label="encryption", style="dotted", color="#64748b") >> kms

    fargate >> Edge(label="audit logs", style="dotted", color="#64748b") >> cwlogs
    cwlogs >> Edge(color="#64748b") >> cwmon
    cwmon >> Edge(label="alert", color="#dc2626") >> sns
    sns >> Edge(color="#dc2626") >> slack

    eb >> Edge(label="cron Catalog upsert Case Bank Indexer Blob TTL", style="dashed", color="#10b981") >> fargate
    ssm >> Edge(label="KILL_SWITCH on", color="#dc2626", style="bold") >> fargate
