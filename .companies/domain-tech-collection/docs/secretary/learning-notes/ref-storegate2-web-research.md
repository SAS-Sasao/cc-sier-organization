# storeGATE2 Web 調査レポート — 補足資料

**作成日**: 2026-04-12
**作成者**: tech-researcher subagent（Web 検索ベース）
**種別**: 補足資料（既存ノートに不足していた情報の補完）
**関連 WBS**: 2.5.9 BluStellar リテール向けシナリオ / 2.5.4 ストコン AWS 移行技術 Deep Dive

---

## 1. 製品概要

**storeGATE2** は NECネクサソリューションズ株式会社が提供する小売業向けクラウド型本部・店舗システム。2007年9月に ASP サービスとして販売開始され、2021年6月に Oracle Cloud Infrastructure（OCI）上でのクラウドサービスとして本格稼働を開始した。

現在の製品ラインナップ:
- **storeGATE2（本部・管理システム）**: 販売・仕入・在庫・発注・集配信・マスタ管理を担う本部側基幹システム
- **storeGATE2 POS（NeoSarf/POS）**: 店舗側の POS アプリケーション。ハードウェアフリーでクラウド提供
- **storeGATE/L（2023年6月〜）**: storeGATE2 の後継。専門小売業向けに特化・軽量化

---

## 2. 技術アーキテクチャ

### 2-1. クラウド基盤（2021年 OCI 移行後）

| 項目 | 内容 |
|------|------|
| クラウドプロバイダー | **Oracle Cloud Infrastructure（OCI）** |
| データベース | **Oracle Autonomous Database Dedicated（ATP）** |
| リージョン | Oracle Cloud 東京リージョン |
| 冗長性 | 専有型環境（Dedicated） |
| スケーリング | オートスケーリング（設定 vCPU の最大 3 倍まで無停止スケールアップ） |

### 2-2. パフォーマンス比較

| 指標 | オンプレ時代 | OCI 移行後 |
|------|-------------|-----------|
| 売上トランザクション処理 | 17 件/秒 | 約 100 件/秒（約 6 倍） |

### 2-3. ネットワーク（ASP 時代の旧構成）

- NECネクサソリューションズの Clovernet（マネージド VPN サービス）を利用した ASP センタ接続

### 2-4. POS 側アーキテクチャ

- サーバ環境・アプリケーションはクラウド提供
- ハードウェアフリー（Windows タブレット・他社ハードウェア対応）
- オフラインモード対応（現金会計・返品・精算が可能）
- プラグイン構造（拡張可能な独自アーキテクチャ）

---

## 3. 機能一覧

### 3-1. 本部側機能（storeGATE2 / storeGATE/L）

| 機能カテゴリ | 主な機能 |
|---|---|
| 販売管理 | 全店舗の販売情報リアルタイム把握・集計、売上照会 |
| 仕入管理 | 仕入先管理、帳合管理（店舗別売価・発注先・原価設定） |
| 在庫管理 | 他店在庫のリアルタイム参照、チェーン全体の在庫軽減 |
| 発注管理 | 自動発注（在庫定点型・売上補充型・販売予測型の 3 パターン） |
| 商品マスタ管理 | JAN コード、カラー・サイズ・セグメント・セット管理 |
| 本部店舗間連携 | 新商品案内・マニュアル・販売指示の集配信、店舗業務処理状況監視 |
| 分析機能 | 売上データ分析、在庫状況確認、発注計画最適化 |
| インターフェース | API / FTP / CSV 対応の汎用インターフェース |

### 3-2. 店舗側機能（storeGATE2 POS / NeoSarf/POS）

| 機能カテゴリ | 主な機能 |
|---|---|
| POS レジ | 有人・フルセルフ・対面セミセルフを 1 アプリで提供（ワンタッチ切替） |
| 決済対応 | 現金・クレジット・交通系 IC・QR コード決済・デビット・プリペイド・スマートフォン決済 |
| 免税対応 | J-TaxFree システム連携、POS のみで免税販売完結 |
| 顧客管理 | 顧客番号管理、ポイント付与・利用・交換、購買履歴 |
| 在庫管理 | 店舗内在庫確認（タブレット操作でその場で確認） |
| マルチデバイス | POS 専用機・PC・Windows タブレット対応、他社製ハードウェア動作可 |
| 顔認証 | NEC「Bio-IDiom Services ID 連携」による顔認証決済 |

---

## 4. 導入事例

| 企業名 | 業種 | 主な成果 |
|---|---|---|
| リーガルコーポレーション | 靴小売・卸売（REGAL ブランド） | 据え置き POS → iPad 化。店内どこでも在庫確認・接客・決済完結 |
| トゥモローランド | アパレル（メンズ・ウィメンズ） | タブレット PC 上で稼働。NeoSarf/POS + storeGATE2 + CPSS-CRM |

---

## 5. 料金体系

| 項目 | 内容 |
|------|------|
| 提供形態 | 月額サービス（サブスクリプション） |
| 料金体系 | 利用者・端末台数に制約されない料金体系 |
| 導入期間 | 標準 6 カ月程度 |
| 具体的な価格 | 非公開（個別見積もり制） |

---

## 6. storeGATE シリーズ比較

| 比較軸 | storeGATE（初代、2002年〜） | storeGATE2（2007年〜） | storeGATE/L（2023年6月〜） |
|---|---|---|---|
| 提供開始 | 2002年11月 | 2007年9月（ASP）→ 2021年6月（OCI 移行） | 2023年6月 |
| 提供形態 | オンプレ型 / パッケージ | ASP → クラウド（OCI） | クラウド（月額） |
| 本部機能 | なし（店舗システムのみ） | **本部管理機能を初搭載**（集配信・マスタ管理） | 本部・店舗業務を一括管理するオールインワン |
| CVS 機能 | なし | CVS マーチャンダイジング機能を応用 | 専門小売業特化（CVS 向けではない） |
| ターゲット | 小売業全般 | 専門店・小売店・CVS | ドラッグストア・雑貨店・アパレル等 |
| DB 基盤 | 未確認 | Oracle Autonomous Database Dedicated（OCI） | 未確認（storeGATE2 基盤を継承の可能性） |
| 位置付け | — | — | storeGATE2 の後継・進化版（軽量化） |

---

## 7. NeoSarf/POS との連携方式

公式には **「storeGATE2 POS（NeoSarf/POS）」** と一体表記される密結合製品。

| 連携形態 | 詳細 |
|---------|------|
| データ連携 | POS → 本部: 売上データリアルタイム送信。本部 → POS: 商品マスタ・売価・企画情報を集配信 |
| API 方式 | 標準/汎用インターフェース（API / FTP / CSV） |
| 拡張連携 | CRM（CPSS-CRM）、EC（NeoSarf/DM）、顔認証（Bio-IDiom）、J-TaxFree と標準連携 |
| OMO 対応 | NeoSarf シリーズ全体で OMO 連携基盤を構成（EC / CRM / POS 統合） |

---

## 8. ストコン移行案件への示唆

### 8-1. storeGATE2 は OCI ベース — AWS 移行の直接参照には限界あり

storeGATE2 のクラウド基盤は OCI + Oracle Autonomous Database であり、ストコンの AWS 移行とはクラウドプロバイダーが異なる。参照できるのは業務機能設計・月額モデル・本部-店舗間データフローであり、インフラ構成の直接参照は不適切。

| 参照できる | 参照できない |
|-----------|-------------|
| 本部-店舗間の業務機能設計 | クラウド基盤（OCI vs AWS） |
| 月額制への移行モデル | AWS 固有のサービス設計 |
| 発注管理の 3 パターン設計 | コンビニ特有の AI.CO 連携 |
| リアルタイム売上連携の仕組み | 14,663 店舗規模のスケーラビリティ |
| オフラインモード設計思想 | KDDI IP-VPN / WAKONX 連携 |

### 8-2. storeGATE/L が後継 — storeGATE2 の新規提案は減少傾向

2023 年以降は storeGATE/L が後継製品として位置付けられている。ストコン移行提案時に storeGATE2 を参照する場合は、最新の storeGATE/L も含めた文脈で語る必要がある。

### 8-3. 参画前に確認すべき追加項目

| 確認項目 | 理由 | 優先度 |
|---------|------|-------|
| ローソン向けに storeGATE2/L の検討実績はあるか | 提案の前例有無で難易度が変わる | 高 |
| storeGATE2 の OCI → AWS 移行検討はあるか | NEC グループ内でのクラウド戦略の方向性把握 | 中 |
| NECネクサソリューションズとの協業体制 | storeGATE の知見をストコン案件に活かせるか | 中 |

---

## Sources

1. NECネクサソリューションズ storeGATE2 POS: https://www.nec-nexs.com/sl/retail/storegate2pos.html
2. NECネクサソリューションズ storeGATE/L: https://www.nec-nexs.com/sl/retail/storegate_l.html
3. NECネクサソリューションズ storeGATE/L 機能詳細: https://www.nec-nexs.com/sl/retail/storegate_l/system/
4. NECネクサソリューションズ 導入事例（リーガル）: https://www.nec-nexs.com/solution/case/regal.html
5. NEC 公式 NeoSarf/POS: https://jpn.nec.com/neosarf/pos/index.html
6. NECソリューションイノベータ NeoSarf/POS: https://www.nec-solutioninnovators.co.jp/ss/retail/products/neosarf-pos/summary/
7. MyNavi Tech+（OCI 導入事例）: https://news.mynavi.jp/techplus/article/techp5731/
8. EnterpriseZine（OCI 導入事例）: https://enterprisezine.jp/news/detail/14923
9. LNEWS（storeGATE2 ASP サービス発売記事、2007年）: https://www.lnews.jp/backnumber/2007/08/24516.html
10. NeoSarf/POS LP: https://www.nec-nexs.com/lp/retail/storegate2pos.html

---

*この資料は Web 検索ベースの調査結果であり、NEC 社内資料と異なる可能性がある。参画後に NEC 社内ポータル（BluStellar Hub 等）で最新情報を確認すること。*
