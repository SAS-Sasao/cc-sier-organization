# StoreCon CI/CD Pipeline

## メタデータ

| 項目 | 値 |
|------|-----|
| ファイル名 | storcon-cicd-pipeline |
| 案件 | コンビニストコンAWS移行 |
| 領域 | CI/CD |
| 生成日 | 2026-03-27 |
| MCP Server | awslabs.aws-diagram-mcp-server |
| 公開URL | [GitHub Pages](https://sas-sasao.github.io/cc-sier-organization/diagrams/storcon-cicd-pipeline.html) |

## 使用AWSサービス

- AWS CodeBuild
- AWS CodeArtifact
- Amazon ECR
- AWS CDK / CloudFormation
- Amazon ECS Fargate (STG / PRD)
- Amazon RDS (STG / PRD)
- Amazon SNS
- Amazon CloudWatch
- AWS CloudTrail
- AWS Secrets Manager
- IAM Role

## 外部サービス

- GitHub (Repository)
- GitHub Actions (CI/CD Trigger)

## ソースコード（Python diagrams DSL）

```python
with Diagram("StoreCon CI/CD Pipeline", show=False, direction="LR", filename="storcon-cicd-pipeline", graph_attr={"fontsize": "16", "pad": "0.5"}):

    # Source
    with Cluster("Source"):
        github = Github("GitHub\nRepository")
        actions = GithubActions("GitHub\nActions")

    # Build & Test
    with Cluster("Build & Test"):
        codebuild = Codebuild("CodeBuild\n(Build & Test)")
        codeartifact = Codeartifact("CodeArtifact\n(Dependencies)")

    # Artifact
    with Cluster("Artifact Registry"):
        ecr = ECR("Amazon ECR\n(Container Images)")

    # IaC
    with Cluster("Infrastructure as Code"):
        cdk = CloudDevelopmentKit("AWS CDK")
        cfn = Cloudformation("CloudFormation\n(Stack Deploy)")

    # Deploy Staging
    with Cluster("Staging Environment"):
        ecs_stg = ECS("ECS Fargate\n(Staging)")
        rds_stg = RDS("RDS\n(Staging)")

    # Approval Gate
    with Cluster("Approval Gate"):
        sns = SNS("SNS\n(Notification)")

    # Deploy Production
    with Cluster("Production Environment"):
        ecs_prd = ECS("ECS Fargate\n(Production)")
        rds_prd = RDS("RDS\n(Production)")

    # Monitoring
    with Cluster("Monitoring & Security"):
        cloudwatch = Cloudwatch("CloudWatch\n(Metrics & Logs)")
        cloudtrail = Cloudtrail("CloudTrail\n(Audit)")
        secrets = SecretsManager("Secrets\nManager")
        iam = IAMRole("IAM Role\n(Least Privilege)")

    # Flow: Source → Build
    github >> Edge(label="Push / PR", color="darkblue", style="bold") >> actions
    actions >> Edge(label="Trigger", color="darkblue") >> codebuild
    codebuild >> codeartifact

    # Flow: Build → Artifact
    codebuild >> Edge(label="Push Image", color="purple", style="bold") >> ecr

    # Flow: IaC
    actions >> Edge(label="IaC Deploy", color="darkorange", style="dashed") >> cdk >> cfn

    # Flow: Deploy Staging
    ecr >> Edge(label="Deploy STG", color="darkgreen", style="bold") >> ecs_stg
    cfn >> ecs_stg
    ecs_stg >> rds_stg

    # Flow: Approval → Production
    ecs_stg >> Edge(label="E2E Test Pass", color="teal") >> sns
    sns >> Edge(label="Approve", color="red", style="bold") >> ecs_prd
    ecr >> ecs_prd
    cfn >> ecs_prd
    ecs_prd >> rds_prd

    # Monitoring
    ecs_stg >> Edge(style="dashed", color="gray") >> cloudwatch
    ecs_prd >> Edge(style="dashed", color="gray") >> cloudwatch
    ecs_prd >> Edge(style="dashed", color="gray") >> cloudtrail

    # Security
    secrets >> Edge(style="dashed", color="gray") >> ecs_stg
    secrets >> Edge(style="dashed", color="gray") >> ecs_prd
    iam >> Edge(style="dashed", color="gray") >> actions
```
