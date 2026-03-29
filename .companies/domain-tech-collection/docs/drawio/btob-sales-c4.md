# BtoB販売管理システム C4モデル（L1/L2/L3）

- **図の種類**: C4モデル
- **ツール**: `open_drawio_xml`
- **作成日**: 2026-03-29
- **作成者**: SAS-Sasao

## 概要

BtoB向け販売管理システムの概要アーキテクチャ。DDD（ドメイン駆動設計）の思想に基づき、
6つの境界コンテキストをモジュラモノリスとして構成。将来のマイクロサービス移行を見据えた
Schema-per-Module分離とドメインイベント駆動アーキテクチャを採用。

## アーキテクチャ特徴

- **モジュラモノリス**: Spring Boot / Kotlin on ECS Fargate
- **DDD Bounded Contexts**: 受注・顧客・商品・在庫・出荷・請求の6モジュール
- **通信パターン**: 同期（Internal API）＋非同期（Amazon SQS ドメインイベント）
- **データ分離**: PostgreSQL Schema-per-Module
- **AWS構成**: ECS Fargate, API Gateway, ALB, Cognito, SQS, RDS, ElastiCache, S3

## 公開先

- 詳細ページ: [docs/drawio/btob-sales-c4.html](../../../docs/drawio/btob-sales-c4.html)
- draw.io XML: [docs/drawio/btob-sales-c4.drawio](../../../docs/drawio/btob-sales-c4.drawio)
