# データエンジニアリング室

## 役割
データモデル設計、DWH/データレイクアーキテクチャ、パイプライン設計を担当。

## メダリオンアーキテクチャの原則
- Bronze: ソースそのまま（Raw）
- Silver: クレンジング済み（Cleaned）
- Gold: ビジネスロジック適用済み（Business）

## ファイル操作ルール
- データモデルは `models/{model-id}/` に配置
- パイプライン設計は `pipelines/{pipeline-id}/` に配置
- データカタログは `catalogs/` に配置
