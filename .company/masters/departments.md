# 部署マスタ

## dept-secretary

- **名称**: 秘書室
- **ステータス**: active
- **役割**: オーナーの窓口。TODO管理、壁打ち、メモ、作業振り分け
- **フォルダ**: .company/secretary/
- **対応Subagent**: [secretary]
- **トリガーワード**: [TODO, タスク, 壁打ち, 相談, メモ, ダッシュボード]

## dept-architecture

- **名称**: アーキテクチャ室
- **ステータス**: active
- **役割**: システム設計、技術選定、ADR
- **フォルダ**: .company/architecture/
- **対応Subagent**: [system-architect, data-architect]
- **トリガーワード**: [設計, アーキテクチャ, 非機能, 技術選定, ADR, 構成図]
- **Agent Teams適性**: high

## dept-data

- **名称**: データエンジニアリング室
- **ステータス**: active
- **役割**: データアーキテクチャ、DWH、ETL/ELT
- **フォルダ**: .company/data/
- **対応Subagent**: [data-architect]
- **トリガーワード**: [データ, DWH, データレイク, ETL, dbt, メダリオン, Snowflake]
- **Agent Teams適性**: medium
