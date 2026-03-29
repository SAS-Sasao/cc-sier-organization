# タスクログ: draw.io BtoB販売管理システムC4モデル作成

- **task-id**: 20260329-drawio-btob-sales-c4
- **日時**: 2026-03-29
- **担当者**: SAS-Sasao
- **モード**: direct
- **Subagent**: secretary (company-drawio skill)

## 依頼内容

BtoB向け販売管理システムの概要アーキテクチャをC4モデルで作成。
サービスベースアーキテクチャ（DDD × モジュラモノリス × AWS）を想定。

## 実施内容

1. DDD境界コンテキストの設計（受注・顧客・商品・在庫・出荷・請求の6BC）
2. C4モデルの3レベル構成設計（L1 Context / L2 Container / L3 Bounded Context）
3. draw.io XML でダイアグラム作成（open_drawio_xml MCP ツール使用）
4. エッジ貫通レビュー実施・修正（4回の反復で全件クリア）
5. HTML詳細ページ作成（Mermaidプレビュー＋draw.io XMLダウンロード）
6. index.html にカード追加
7. 組織メタデータファイル作成

## 成果物

- `docs/drawio/btob-sales-c4.drawio` — draw.io XMLソース
- `docs/drawio/btob-sales-c4.html` — 詳細ページ
- `docs/drawio/index.html` — 一覧ページ（カード追加）
- `.companies/domain-tech-collection/docs/drawio/btob-sales-c4.md` — メタデータ

## 設計判断

- **モジュラモノリス採用**: 単一デプロイメントで開発・運用コストを抑えつつ、BC単位の独立性を確保
- **Schema-per-Module**: DB分離を段階的に進められる設計（将来のMS化対応）
- **ドメインイベント駆動**: 受注→在庫引当→出荷→請求の業務フローを非同期連鎖で実現
- **外部システム配置**: エッジ貫通回避のため、外部システムをモジュール行より下方に配置
