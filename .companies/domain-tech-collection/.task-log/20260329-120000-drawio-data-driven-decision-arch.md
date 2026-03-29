---
task-id: 20260329-120000-drawio-data-driven-decision-arch
org: domain-tech-collection
mode: direct
dept: secretary
type: feat
operator: SAS-Sasao
subagent: none (direct orchestration)
status: completed
reward: 0.82
judge_summary: "要件充足9/10, 図品質8/10, UML準拠7/10, HTML品質9/10"
created: 2026-03-29
---

# draw.io図生成: データドリブン意思決定基盤 UMLコンポーネント図

## 依頼内容

UML方式で、ERP・CRM・SKILL_HUB・SharePoint・Redmineから情報を収集し、
MDM・データレイク・DWHで蓄積、BIツール・AI/MLで分析して
経営者・PM・管理職、マーケティング部、営業部がデータドリブンな意思決定を行える仕組みの図を作成。

## 実施内容

1. draw.io XMLで5層UMLコンポーネント図を設計（open_drawio_xml使用）
2. 層間エッジは直線、層内エッジはorthogonalEdgeStyleで貫通回避
3. レビュースクリプト通過確認
4. HTML詳細ページ（Mermaid.jsプレビュー＋draw.ioダウンロード）
5. index.html にカード追加
6. ソースメタデータ .md 作成

## 成果物

- `docs/drawio/data-driven-decision-arch.drawio` - draw.io XMLソース
- `docs/drawio/data-driven-decision-arch.html` - 詳細ページ
- `.companies/domain-tech-collection/docs/drawio/data-driven-decision-arch.md` - メタデータ

## SKILL_HUBの特記事項

- 社内マスタデータ管理WebApp
- SmartHR連携（社員情報同期）、Backlog連携（PJ管理統合）
- RDB（リレーショナル）+ VectorDB（生成AI用）の2ストア構成
