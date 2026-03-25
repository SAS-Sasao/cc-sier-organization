---
task-id: 20260325-210500-storcon-aws-tech-deep-dive
title: ストアコンピューターAWS移行 技術スタック深堀り調査
org: domain-tech-collection
dept: retail-domain
type: docs
status: completed
created-at: 2026-03-25T21:05:00+09:00
---

## タスク概要

ストアコンピューター（ストコン）のAWS移行における技術スタックを深堀り調査し、
PMとして参画する笹尾さんが学習すべき内容をピックアップ。

## 入力情報

- 既存概要資料: `.companies/domain-tech-collection/docs/research/store-computer-aws-migration-tech.md`
- 既存ドメイン知識: `.companies/domain-tech-collection/docs/retail-domain/store-computer-domain-knowledge.md`
- 参画時期: 2026年6月（PMとして）
- 前提知識: AWS基礎（IAM, VPC, EC2, S3）学習中

## 実施内容

既存資料（概要レベル）と重複しない、より実践的・具体的な情報を以下のサービスについて調査:

1. AWS DMS — OracleからAurora移行のCDC設定詳細、SCTとの連携手順、落とし穴
2. AWS MGN — サーバー移行の3フェーズ手順、カットオーバー設計
3. AWS Outposts / Local Zones — 多店舗環境での現実的な活用判断
4. Amazon MSK vs. Kinesis — 使い分け判断基準と具体的設定
5. AWS IoT Greengrass v2 — 店舗デバイス管理の実装パターン
6. AWS Direct Connect — 東京DCロケーション・接続形態
7. AWS Transit Gateway — 多VPC環境の設計パターン、コスト考慮点

また移行ベストプラクティスとして:
- MAP（Migration Acceleration Program）の3フェーズ構造
- Control Tower によるマルチアカウント設計
- Well-Architected Review の小売向け重点ポイント

## 成果物

- `.companies/domain-tech-collection/docs/retail-domain/industry-reports/storcon-aws-tech-deep-dive-2026-03-25.md`

## 学習ロードマップ サマリー

### Must（参画前必須）
1. DMS の仕組み・設定オプション（CDC/フルロード）
2. MGN の移行フェーズ管理（カットオーバー判断基準）
3. Transit Gateway によるマルチVPC設計
4. MAP プログラムの活用方法
5. Control Tower マルチアカウント設計
6. DMS CDC とカットオーバー計画詳細
7. IoT Greengrass v2 の店舗実装概念

### Should（参画後早期）
MSK vs. Kinesis選定、Direct Connect設計、Well-Architected Review実施、コスト最適化

### Nice-to-have
Outposts詳細、SageMaker、Glue、QuickSight、CDK
