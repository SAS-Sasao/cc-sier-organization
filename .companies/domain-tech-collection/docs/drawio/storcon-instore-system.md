---
title: StoreComputer - In-Store System Architecture
type: UML Component
project: ストコン移行
wbs: "2.1.3"
tool: open_drawio_xml
created: 2026-04-01
---

# StoreComputer - In-Store System Architecture

コンビニエンスストアの店舗内システム構成をUMLコンポーネント図として設計。ストアコンピューターを中心ハブとし、POS端末・決済端末・EOS/EOB通信・温度管理モジュールを統合制御する構成を可視化。

## 主要構成要素

| カテゴリ | 要素 | 説明 |
|----------|------|------|
| アクター | Store Manager / Store Staff / Delivery Driver / Customer | 店舗に関与する4種の人物 |
| ハブ | Store Computer | 店舗内全システムの統合制御ハブ |
| サービス | EOS/EOB / Order / Inventory / Inspection / Settlement / Temperature Monitor | 業務モジュール群 |
| データ | Local DB / Master Cache / Sales Journal / Temperature Log | 店舗内データストア |
| ハードウェア | POS Terminal / Payment Terminal / Handy Terminal / Digital Signage | 店舗設置端末 |
| 外部 | HQ Cloud | 本部クラウド（マスタ配信・売上集約） |

## 設計の特徴

- ストコンをハブとする星形トポロジー（本部回線障害時のローカル自律運転を可能に）
- EOS/EOBの双方向通信（店舗発注 + 本部推奨発注）
- 決済端末のPOS分離設計（マルチ決済ブランド対応）
- 温度監視のデジタル化（HACCP対応・食品衛生法準拠）

## 関連

- AWS版構成図: [storcon-vpc-architecture](../../../docs/diagrams/storcon-vpc-architecture.html)
- UMLコンポーネント図（クラウド側）: [storcon-uml-component](../../../docs/drawio/storcon-uml-component.html)
