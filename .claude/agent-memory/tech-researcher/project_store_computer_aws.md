---
name: ストアコンピューターAWS移行調査
description: コンビニストアコンピューターのオンプレ→AWS移行に関する技術スタック調査を実施済み
type: project
---

コンビニエンスストア向けストアコンピューターのAWS移行技術スタック調査を完了。

**Why:** 2026年6月参画予定者の事前学習ロードマップと技術選定根拠の整理が目的。

**How to apply:** 同様の小売・店舗系クラウド移行案件の調査では、本レポートの技術選定表・移行パターンを参照ベースとして活用できる。

主要判断:
- コンピュート: Lift&Shift時はEC2、その後ECS/Fargateへ段階移行
- DB: トランザクションはAurora、高頻度アクセスはDynamoDB、キャッシュはElastiCache Redis
- 移行パターン: ストラングラーフィグ（段階的マイクロサービス化）を推奨
- オフライン耐性: 店舗固有の重要要件（ローカルキャッシュ + 差分同期パターン）
- 資格優先順位: SAA → SAP → Database Specialty の順
- 成果物パス: `.companies/domain-tech-collection/docs/research/store-computer-aws-migration-tech.md`
