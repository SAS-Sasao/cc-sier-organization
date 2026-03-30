# CRM Enterprise System - UML Component Diagram

- **種類**: UMLコンポーネント図
- **対象**: CRM基幹システム（クラウド非依存）
- **生成日**: 2026-03-30
- **ツール**: draw.io MCP Server (open_drawio_xml)
- **レビュー**: エッジ貫通チェック Pass (0 issues)

## 5層レイヤー構成

| Layer | 構成要素 | 色 |
|-------|---------|-----|
| Client | CRM Users, VPN Client, VPN Gateway | 青 |
| Edge Security | WAF, Load Balancer (L7), TLS Certificate | 黄 |
| Application | App Server (AZ-a/c), Batch Server, Mail Server, Message Queue, REST API | 緑 |
| Data | RDBMS Primary/Replica (PostgreSQL), File Server (Windows SMB), Object Storage, Cache | 赤 |
| Operations | Monitoring, Secret Manager, Key Management, Audit Log | 紫 |

## UML図形の使い分け

| 図形 | 用途 |
|------|------|
| UML Actor | CRM利用者 |
| Component（コンポーネント） | App Server, Batch Server, Mail Server |
| Cylinder（シリンダー） | RDBMS, File Server, Object Storage |
| Hexagon（六角形） | Cache |
| Rounded Rectangle | その他のサービス（VPN, WAF, LB等） |

## draw.ioエディタURL

draw.ioで開く: `docs/drawio/crm-system-uml-component.drawio`
