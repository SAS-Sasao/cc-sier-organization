# SIer 提案書自動化ツール C4モデル（L1/L2/L3）

- **図の種類**: C4モデル（System Context / Container / Component）
- **案件**: 提案書自動化
- **作成日**: 2026-03-29
- **作成者**: SAS-Sasao
- **ツール**: open_drawio_xml
- **ファイル**: [proposal-automation-c4.html](https://sas-sasao.github.io/cc-sier-organization/drawio/proposal-automation-c4.html)

## 概要

SIer業務における提案書作成プロセスを自動化するシステムの全体アーキテクチャ。
C4モデルの3レベル（L1 System Context / L2 Container / L3 Component）を1枚の図で表現。

## C4レベル構成

### L1 System Context
- **営業担当者**: 提案書の作成を依頼
- **PM / 見積担当者**: 見積の確認・承認
- **SharePoint**: 過去提案書・見積書（外部）
- **タレマネシステム**: 人材・スキルDB（外部）— [人材データ統合アーキテクチャ](https://sas-sasao.github.io/cc-sier-organization/drawio/talent-data-arch.html) と連携
- **cc-sier / Claude Code**: 構成図自動生成（外部）
- **Claude API**: LLM推論エンジン（外部）

### L2 Container
- **提案書作成UI** [Next.js SPA]
- **ナレッジ取込** [Python] — SharePoint/MD解析・ベクトル化
- **構成図生成サービス** [Python] — cc-sier API連携
- **体制提案サービス** [Python] — タレマネAPI連携
- **見積エンジン** [Python/FastAPI] — L3で展開
- **実績DB** [PostgreSQL]
- **VectorDB** [pgvector]
- **ドキュメントストア** [S3]

### L3 Component（見積エンジン内部）
- **類似案件検索** [RAG Pipeline] — ベクトル類似度で過去案件検索
- **概算生成** [LLM + Prompt] — 類似案件＋乖離補正でAI見積
- **乖離分析** [Analytics] — 提案額vs実費用の差異計算
- **精度フィードバック** [Learning Loop] — 見積精度の記録・学習
- **テンプレート管理** [Template Engine] — 出力フォーマット制御

## draw.io XML ソース

`open_drawio_xml` で生成。ファイル: `docs/drawio/proposal-automation-c4.drawio`
