---
title: データドリブン意思決定基盤 UMLコンポーネント図
type: C4モデル
project: データ基盤
created: 2026-03-29
author: SAS-Sasao
tool: open_drawio_xml
---

# データドリブン意思決定基盤 UMLコンポーネント図

## 概要

ERP・CRM・SKILL_HUB・SharePoint・Redmineから情報を収集し、
MDM・データレイク・DWHで蓄積、BI・AI/MLで分析して
経営者・マーケティング・営業がデータドリブンな意思決定を行う5層アーキテクチャ。

## 構成

| レイヤー | コンポーネント |
|---------|-------------|
| データソース | ERP, CRM, SKILL_HUB(WebApp/RDB+VectorDB/SmartHR+Backlog連携), SharePoint, Redmine |
| データ収集・統合 | ETL/データ連携基盤 |
| データ蓄積 | MDM, DWH, データレイク |
| 分析・活用 | BIツール, AI/MLエンジン |
| 利用者 | 経営者・PM・管理職, マーケティング部, 営業部 |

## draw.io XML (open_drawio_xml)

draw.io XML形式で生成。5層のswimlaneコンテナに各コンポーネントを配置。
層間エッジは直線、層内エッジ（MDM→DWH、データレイク→DWH）はorthogonalEdgeStyle。

## ファイル

- HTML: [docs/drawio/data-driven-decision-arch.html](../../../docs/drawio/data-driven-decision-arch.html)
- draw.io: [docs/drawio/data-driven-decision-arch.drawio](../../../docs/drawio/data-driven-decision-arch.drawio)
