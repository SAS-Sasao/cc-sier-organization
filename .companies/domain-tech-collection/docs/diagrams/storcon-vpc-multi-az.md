# StoreCon VPC Multi-AZ Architecture

## メタデータ

| 項目 | 値 |
|------|-----|
| ファイル名 | storcon-vpc-multi-az |
| 案件 | コンビニストコンAWS移行 |
| 領域 | Network / VPC |
| 生成日 | 2026-04-06 |
| MCP Server | awslabs.aws-diagram-mcp-server |
| 公開URL | [GitHub Pages](https://sas-sasao.github.io/cc-sier-organization/diagrams/storcon-vpc-multi-az.html) |
| WBS | 3.1.1 AWS基礎（VPC） |

## 使用AWSサービス

- Amazon VPC (10.0.0.0/16)
- Public Subnet x2 (ALB, NAT Gateway)
- Private Subnet x2 (ECS Fargate)
- Data Subnet x2 (Aurora, ElastiCache)
- Internet Gateway
- NAT Gateway x2 (per AZ)
- Application Load Balancer
- Amazon CloudFront
- AWS WAF
- VPC Endpoint (S3 Gateway, SecretsManager Interface)
- AWS Direct Connect
- Site-to-Site VPN
- Security Groups (ALB / App / Data)

## ソースコード（Python diagrams DSL）

```python
with Diagram("StoreCon VPC Multi-AZ Architecture", show=False, direction="TB", filename="storcon-vpc-multi-az", graph_attr={"fontsize": "14", "pad": "0.5"}):

    store = TraditionalServer("Store Computer\n(56,000)")
    hq = GenericOfficeBuilding("HQ Data Center")
    internet = InternetAlt1("Internet")

    with Cluster("Edge"):
        cf = CloudFront("CloudFront\n(CDN)")
        waf = WAF("WAF\n(Firewall)")

    with Cluster("VPC (10.0.0.0/16)"):
        igw = IGW("Internet\nGateway")

        with Cluster("AZ-a (ap-northeast-1a)"):
            with Cluster("Public Subnet (10.0.1.0/24)"):
                nat_a = NATGateway("NAT\nGateway-a")
                alb_a = ALB("ALB\n(node-a)")
            with Cluster("Private Subnet (10.0.10.0/24)"):
                ecs_a = ECS("ECS Fargate\n(App-a)")
            with Cluster("Data Subnet (10.0.20.0/24)"):
                aurora_a = Aurora("Aurora\n(Writer)")
                redis_a = ElastiCache("ElastiCache\n(Primary)")

        with Cluster("AZ-c (ap-northeast-1c)"):
            with Cluster("Public Subnet (10.0.2.0/24)"):
                nat_c = NATGateway("NAT\nGateway-c")
                alb_c = ALB("ALB\n(node-c)")
            with Cluster("Private Subnet (10.0.11.0/24)"):
                ecs_c = ECS("ECS Fargate\n(App-c)")
            with Cluster("Data Subnet (10.0.21.0/24)"):
                aurora_c = Aurora("Aurora\n(Reader)")
                redis_c = ElastiCache("ElastiCache\n(Replica)")

        with Cluster("VPC Endpoints"):
            ep_s3 = Endpoint("S3\nGateway EP")
            ep_secrets = Endpoint("SecretsManager\nInterface EP")

    with Cluster("Hybrid Connectivity"):
        dx = DirectConnect("Direct Connect\n(1Gbps)")
        vpn = VpnConnection("Site-to-Site\nVPN (Backup)")

    with Cluster("Security Groups"):
        sg_alb = GenericFirewall("SG: ALB\n(443 inbound)")
        sg_app = GenericFirewall("SG: App\n(8080 from ALB)")
        sg_db = GenericFirewall("SG: Data\n(3306/6379 from App)")

    store >> Edge(label="HTTPS", color="darkblue", style="bold") >> cf
    internet >> Edge(color="darkblue", style="bold") >> cf
    cf >> waf >> igw
    igw >> Edge(label="Route", color="darkgreen", style="bold") >> alb_a
    igw >> Edge(label="Route", color="darkgreen", style="bold") >> alb_c
    alb_a >> Edge(label="Forward", color="darkgreen") >> ecs_a
    alb_c >> Edge(label="Forward", color="darkgreen") >> ecs_c
    ecs_a >> Edge(label="Outbound", color="gray", style="dashed") >> nat_a
    ecs_c >> Edge(label="Outbound", color="gray", style="dashed") >> nat_c
    ecs_a >> Edge(label="Read/Write", color="purple", style="bold") >> aurora_a
    ecs_a >> Edge(label="Cache", color="teal") >> redis_a
    ecs_c >> Edge(label="Read", color="purple") >> aurora_c
    ecs_c >> Edge(label="Cache", color="teal") >> redis_c
    aurora_a >> Edge(label="Replication", color="darkorange", style="dashed") >> aurora_c
    redis_a >> Edge(label="Replication", color="darkorange", style="dashed") >> redis_c
    hq >> Edge(label="Dedicated Line", color="red", style="bold") >> dx
    hq >> Edge(label="Backup", color="red", style="dashed") >> vpn
    ecs_a >> Edge(color="gray", style="dashed") >> ep_s3
    ecs_a >> Edge(color="gray", style="dashed") >> ep_secrets
```

## アーキテクチャレビュ���

| # | 観点 | 判定 | 備考 |
|---|------|------|------|
| 1 | サービス互換性 | Pass | VPC+Subnet+NAT+IGW+ALB+ECS+Aurora+ElastiCache全て標準統合 |
| 2 | データフロー整合性 | Pass | Internet→CF→WAF→IGW→ALB→ECS→Aurora/Cache, NAT for outbound |
| 3 | セキュリティ | Pass | 3層SG, Private/Data Subnet分離, VPC Endpoints |
| 4 | 可用性 | Pass | Multi-AZ(1a/1c), 双方向レプリケーション, NAT x2 |
| 5 | コスト効率 | Pass | S3 Gateway EP無料, NAT per AZは可用性のため必須 |
| 6 | 要望一致 | Pass | VPC Multi-AZ+Public/Private/Data+NAT+DX+SG学習要件を網羅 |

**総合: Pass (6/6)**
