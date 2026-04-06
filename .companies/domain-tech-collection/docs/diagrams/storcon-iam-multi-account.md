# StoreCon IAM Multi-Account Architecture

## メタデータ

| 項目 | 値 |
|------|-----|
| ファイル名 | storcon-iam-multi-account |
| 案件 | コンビニストコンAWS移行 |
| 領域 | Security / IAM |
| 生成日 | 2026-04-06 |
| MCP Server | awslabs.aws-diagram-mcp-server |
| 公開URL | [GitHub Pages](https://sas-sasao.github.io/cc-sier-organization/diagrams/storcon-iam-multi-account.html) |
| WBS | 3.1.1 AWS基礎（IAM） |

## 使用AWSサービス

- AWS Organizations (SCP)
- AWS IAM Identity Center (SSO)
- Amazon Cognito (User Pool / Identity Pool)
- AWS IAM (Roles: StrConAppRole, ProdOpsRole, StagingRole, DevRole)
- AWS KMS (Customer Managed Key)
- AWS Secrets Manager
- AWS CloudTrail
- Amazon GuardDuty
- AWS Security Hub

## ソースコード（Python diagrams DSL）

```python
with Diagram("StoreCon IAM Multi-Account Architecture", show=False, direction="LR", filename="storcon-iam-multi-account", graph_attr={"fontsize": "14", "pad": "0.5"}):

    # External Actors
    with Cluster("Actors"):
        ops = Users("HQ Operations")
        devs = Users("Developers")
        store = TraditionalServer("Store Computer\n(56,000)")

    # Identity & Governance Layer
    with Cluster("Identity & Governance"):
        sso = SingleSignOn("IAM Identity\nCenter (SSO)")
        cognito = Cognito("Cognito\n(Device Auth)")
        org = Organizations("Organizations")
        scp = IAMPermissions("SCP\n(Region Lock)")

    # Production Account
    with Cluster("Production Account"):
        with Cluster("IAM Roles"):
            app_role = IAMRole("StrConAppRole\n(Instance Profile)")
            ops_role = IAMRole("ProdOpsRole\n(Read / Deploy)")
        secrets = SecretsManager("Secrets\nManager")
        kms = KMS("KMS\n(CMK)")

    # Non-Prod Accounts
    with Cluster("Staging / Dev Accounts"):
        stg_role = IAMRole("StagingRole")
        dev_role = IAMRole("DevRole\n(PowerUser)")

    # Security & Log Account
    with Cluster("Log & Security Account"):
        trail = Cloudtrail("CloudTrail\n(All Accounts)")
        guard = Guardduty("GuardDuty")
        hub = SecurityHub("Security Hub")

    # Human access via SSO
    ops >> Edge(label="SSO Login", color="darkblue", style="bold") >> sso
    devs >> Edge(label="SSO Login", color="darkblue", style="bold") >> sso

    sso >> Edge(label="AssumeRole", color="darkgreen", style="dashed") >> ops_role
    sso >> Edge(label="AssumeRole", color="darkgreen") >> stg_role
    sso >> Edge(label="AssumeRole", color="darkgreen") >> dev_role

    # Device access via Cognito
    store >> Edge(label="Device Auth", color="purple", style="bold") >> cognito
    cognito >> Edge(label="STS Token", color="purple", style="dashed") >> app_role

    # Role to resource access
    app_role >> Edge(color="gray", style="dashed") >> secrets
    app_role >> Edge(color="gray", style="dashed") >> kms

    # Governance
    org >> Edge(label="SCP Deny", color="red", style="bold") >> scp

    # Audit
    ops_role >> Edge(label="Audit Log", color="darkorange", style="dashed") >> trail
    guard >> Edge(color="darkorange", style="dashed") >> hub
```

## アーキテクチャレビュー

| # | 観点 | 判定 | 備考 |
|---|------|------|------|
| 1 | サービス互換性 | Pass | Organizations→SCP, SSO→AssumeRole, Cognito→STS全て統合可能 |
| 2 | データフロー整合性 | Pass | Human→SSO→Role, Device→Cognito→STS→Role, Audit→CloudTrail→Hub |
| 3 | セキュリティ | Pass | SCP+MFA, 56K台にはIoT Core/X.509も候補だがCognitoも妥当 |
| 4 | 可用性 | Pass | IAM/Organizations/SSOはグローバルサービスで高可用 |
| 5 | コスト効率 | Pass | SSO無料、Cognito MAU課金（56K規模で月$33程度） |
| 6 | 要望一致 | Pass | マルチアカウント+ロール+デバイス認証+監査の学習要件を網羅 |

**総合: Pass (6/6)**
