# W1（03/24〜03/28）必読ドキュメント一覧

**作成日**: 2026-03-25
**作成者**: 秘書室
**対象期間**: W1（2026-03-24 〜 2026-03-28）
**マイルストーン**: M1 基礎固め完了（04/11 W3末）

---

## 概要

W1 に割り当てられている WBS タスクと対応するドキュメントの一覧。
既に生成済みのドキュメントにはフルパスを記載し、未生成のものは何を生成すべきか明記する。

---

## 1. WBS 2.1.1: ストコンの全体像理解（5h）

**担当**: 自学
**到達目標**: ストコンが何をしていて、どんなデータが流れているか説明できる

### 必読ドキュメント（生成済み）

| # | ドキュメント | パス | 概要 |
|---|------------|------|------|
| 1 | ストコンドメイン知識 | `.companies/domain-tech-collection/docs/retail-domain/store-computer-domain-knowledge.md` | ストコンの定義・役割・主要機能・システム構成・業務プロセス・用語集を網羅。全6章。**最重要資料** |
| 2 | コンビニ業界構造 深掘り調査 | `.companies/domain-tech-collection/docs/retail-domain/convenience-industry-structure.md` | 業界全体構造、FCモデル、サプライチェーン、IT観点での業界構造、PM留意点。WBS 2.1.R1の成果物 |
| 3 | ストコン最新動向レポート | `.companies/domain-tech-collection/docs/retail-domain/industry-reports/storecomputer-latest-trends-2024-2026.md` | 2024-2026年のクラウド移行事例、エッジコンピューティング、PCI DSS v4.0対応 |
| 4 | ストコン深掘り調査 3/25 | `.companies/domain-tech-collection/docs/retail-domain/industry-reports/storcon-deep-dive-2026-03-25.md` | 3チェーン（セブン/ファミマ/ローソン）のクラウド移行最新状況、POS連携アーキテクチャ詳細 |

### 学習の進め方

1. まず `store-computer-domain-knowledge.md` の **第1章（全体像）** を精読
   - ストコンの定義・役割を自分の言葉で説明できるようにする
   - コンビニ3層構造（本部-店舗-物流）を理解する
   - ストコンの歴史的経緯を把握する
2. 次に `convenience-industry-structure.md` で業界全体の構造を理解
3. 最新動向は `storecomputer-latest-trends-2024-2026.md` と `storcon-deep-dive-2026-03-25.md` で補完
4. 各社のクラウド移行状況を横並びで比較する

### 未生成ドキュメント

| # | 生成すべきもの | 目的 | 担当 |
|---|-------------|------|------|
| - | (なし) | WBS 2.1.1 に必要なドキュメントはすべて生成済み | - |

> **補足**: 3/21作成のTODOリスト（`docs/secretary/todos/2026-03-21.md`）にストコン学習の詳細チェックリストあり。併せて参照。

---

## 2. WBS 3.1.1: AWS基礎 — IAM, VPC, EC2, S3（8h）

**担当**: 自学
**到達目標**: AWSの主要サービスを手を動かして触った経験がある

### 必読ドキュメント（生成済み）

| # | ドキュメント | パス | 概要 |
|---|------------|------|------|
| 1 | AWS移行技術スタック | `.companies/domain-tech-collection/docs/research/store-computer-aws-migration-tech.md` | AWS基本技術スタック（第2章）にIAM/VPC/EC2/S3等の概要あり。ストコン案件での活用ポイント付き |

### 外部リソース（推奨）

| # | リソース | URL/アクセス方法 | 内容 | 所要時間 |
|---|---------|----------------|------|---------|
| 1 | AWS Skill Builder: Cloud Practitioner Essentials | `explore.skillbuilder.aws` で無料受講 | AWS基礎概念（リージョン、AZ、主要サービス概要）。日本語字幕あり | 6h |
| 2 | AWS ハンズオンチュートリアル | `aws.amazon.com/getting-started/hands-on/` | IAMユーザー作成、VPC構築、EC2起動、S3バケット操作の実践 | 2h |
| 3 | AWS Well-Architected Labs | `wellarchitectedlabs.com` | セキュリティ、信頼性等のピラー別ハンズオン | 参考 |

### 学習の進め方

1. `store-computer-aws-migration-tech.md` の **第2章（AWS基本技術スタック）** でサービス概要を把握
2. AWS Skill Builder の Cloud Practitioner Essentials で体系的に学習
3. ハンズオンで実際にリソースを作成・操作
4. ストコン案件での活用シーンと結びつけて理解を深める

### 未生成ドキュメント

| # | 生成すべきもの | 目的 | 担当 |
|---|-------------|------|------|
| 1 | **AWS基礎ハンズオンメモ** | IAM/VPC/EC2/S3のハンズオン実施結果・気づきを記録する学習ノート。ストコン案件での活用ポイントを自分の言葉で記載 | 自学（W1中） |

> **想定パス**: `.companies/domain-tech-collection/docs/secretary/learning-notes/wbs-3-1-1-aws-basics-handson.md`

---

## 3. WBS 4.1.1: 大規模移行PMの全体像（4h）

**担当**: 自学
**到達目標**: SIer案件のPM構造と主要なリスクカテゴリを説明できる

### 必読ドキュメント（生成済み）

| # | ドキュメント | パス | 概要 |
|---|------------|------|------|
| 1 | **PM全体像学習ノート** | `.companies/domain-tech-collection/docs/secretary/learning-notes/wbs-4-1-1-migration-pm-overview.md` | PMO/機能チームPM/ベンダーPMの役割分担、典型的WBS構成、ストコン案件のPM体制イメージ、会議体・エスカレーション・管理帳票テンプレート。**本日生成** |

### 外部リソース（推奨）

| # | リソース | URL/アクセス方法 | 内容 | 所要時間 |
|---|---------|----------------|------|---------|
| 1 | PMBOK第7版 セクション1-3 | 書籍（PMI公式） | PMの原則、パフォーマンス領域の概観 | 2h |
| 2 | IPA「システム移行ガイドライン」 | `ipa.go.jp` で検索 | 日本のSI案件に特化した移行プロジェクトの進め方 | 1h |
| 3 | IPA「ITプロジェクトの失敗事例集」 | `ipa.go.jp` で検索 | 大規模移行の典型的な失敗パターンと教訓 | 1h |

### 学習の進め方

1. 本日生成した `wbs-4-1-1-migration-pm-overview.md` を通読
2. PMBOK第7版の該当セクションで体系的な知識を補完
3. IPA資料で日本のSI案件固有の事情を理解
4. 学習ノート末尾の自己チェックリストで理解度を確認

### 未生成ドキュメント

| # | 生成すべきもの | 目的 | 担当 |
|---|-------------|------|------|
| - | (なし) | 本日の依頼で生成完了 | - |

---

## 4. WBS 1.3: 日次ダイジェスト巡回（継続）

**担当**: 秘書+リサーチ+小売
**到達目標**: 毎日の情報収集を習慣化し、業界・技術動向をキャッチアップ

### 必読ドキュメント（生成済み）

| # | ドキュメント | パス | 概要 |
|---|------------|------|------|
| 1 | 日次ダイジェスト 3/24 | `.companies/domain-tech-collection/docs/daily-digest/2026-03-24.md` | W1初日のダイジェスト |
| 2 | 日次ダイジェスト 3/25 | `.companies/domain-tech-collection/docs/daily-digest/2026-03-25.md` | 本日分。AI/ML・小売動向・EC関連 |
| 3 | 情報ソースマスタ | `.companies/domain-tech-collection/docs/info-source-master.md` | 巡回対象の情報ソース一覧（75+ソース） |

### 残りの日次ダイジェスト

| 日付 | ステータス |
|------|----------|
| 3/26（水） | 未生成 — 当日に自動生成予定 |
| 3/27（木） | 未生成 — 当日に自動生成予定 |
| 3/28（金） | 未生成 — 当日に自動生成予定 |

---

## 5. WBS 2.1.R1: コンビニ業界構造の深掘り調査（小売室担当）

**担当**: 小売ドメイン室
**ステータス**: 完了（3/23, 3/25 の2回実施）

### 生成済みドキュメント

| # | ドキュメント | パス | 概要 |
|---|------------|------|------|
| 1 | コンビニ業界構造 深掘り調査 | `.companies/domain-tech-collection/docs/retail-domain/convenience-industry-structure.md` | 3/23作成。業界全体構造、FCモデル、サプライチェーン、IT構造、トレンド、PM留意点 |
| 2 | ストコン深掘り調査 3/25 | `.companies/domain-tech-collection/docs/retail-domain/industry-reports/storcon-deep-dive-2026-03-25.md` | 3/25作成。3チェーンのクラウド移行最新状況、POS連携アーキテクチャ |

> このタスクは完了済み。成果物は WBS 2.1.1 の学習リソースとして活用する。

---

## 6. 参考ドキュメント（WBS横断）

W1の学習を補完する既存ドキュメント:

| # | ドキュメント | パス | 用途 |
|---|------------|------|------|
| 1 | 参画準備WBS | `.companies/domain-tech-collection/docs/secretary/storcon-preparation-wbs.md` | 全体の学習計画・マイルストーン |
| 2 | 学習スケジュール詳細 | `.companies/domain-tech-collection/docs/secretary/store-computer-learning-schedule.md` | WBSの元資料。Phase別の学習内容詳細 |
| 3 | ストコンドメイン知識 | `.companies/domain-tech-collection/docs/retail-domain/store-computer-domain-knowledge.md` | 全6章のドメイン知識体系 |
| 4 | AWS移行技術スタック | `.companies/domain-tech-collection/docs/research/store-computer-aws-migration-tech.md` | AWS技術スタック全9章 |
| 5 | ストコン最新動向 | `.companies/domain-tech-collection/docs/retail-domain/industry-reports/storecomputer-latest-trends-2024-2026.md` | 2024-2026年のIT/DXトレンド |

---

## 7. W1 未生成ドキュメント サマリー

| # | ドキュメント | WBS | 想定パス | 目的 | 生成方法 |
|---|------------|-----|---------|------|---------|
| 1 | AWS基礎ハンズオンメモ | 3.1.1 | `docs/secretary/learning-notes/wbs-3-1-1-aws-basics-handson.md` | IAM/VPC/EC2/S3のハンズオン実施結果を記録 | 自学で実施後に秘書室が記録支援 |

> **注**: WBS 2.1.1（ストコン全体像）と WBS 4.1.1（PM全体像）は必要なドキュメントがすべて生成済み。
> WBS 3.1.1 のみ、ハンズオン実施後の学習ノート1件が未生成。

---

## W1 学習時間の目安

| WBS | タスク | 目安時間 | 進捗 |
|-----|-------|---------|------|
| 2.1.1 | ストコンの全体像理解 | 5h | 未着手 |
| 3.1.1 | AWS基礎（IAM, VPC, EC2, S3） | 8h | 未着手 |
| 4.1.1 | 大規模移行PMの全体像 | 4h | **学習ノート生成完了** |
| 1.3 | 日次ダイジェスト巡回 | （毎日15分） | 3/24,25 完了 |
| **合計** | | **17h + 日次** | |
