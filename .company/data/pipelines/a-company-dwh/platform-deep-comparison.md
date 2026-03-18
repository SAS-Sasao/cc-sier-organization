# DWHプラットフォーム深掘り比較書
## Azure Synapse Analytics vs Databricks (on Azure)

## 文書情報

| 項目 | 内容 |
|------|------|
| 作成日 | 2026-03-18 |
| 対象案件 | A社基幹システムDWH構築 |
| クライアント | A社（製造業・中堅企業） |
| 前提資料 | platform-comparison.md（3候補初期比較）|
| 本書の目的 | 実データ量・SharePointコネクタ詳細に基づく Synapse vs Databricks 深掘り比較 |
| ステータス | 初版 |

---

## 前提条件

| 項目 | 値 |
|------|----|
| Year 1 データ量 | 100 GB |
| Year 3 データ量 | 約 500 GB（年間 +200 GB ペース） |
| Year 5 データ量 | 約 1 TB |
| クエリ頻度 | 日次バッチ（翌朝 9:00 SLA）+ Power BI 参照（同時 10 ユーザー以下） |
| データソース | SharePoint Online（REST API / Microsoft Graph API） |
| ETL/ELT ツール | Azure Data Factory + dbt |
| BI ツール | Power BI |
| IaC | Terraform |
| 運用体制 | 2〜3 名 |
| 為替レート前提 | **1 USD = 150 JPY**（2025-2026 年想定、Azure 公式 USD 建て料金を換算） |

> 料金根拠: Azure 公式価格ページ（Japan East リージョン、2025 年 Q4 時点）
> Databricks は Azure Marketplace 経由の on-Azure 価格を使用

---

## 1. コスト詳細比較

### 1-1. Azure Synapse Analytics コスト試算

#### 料金単価（Japan East）

| コンポーネント | 単価 | 備考 |
|--------------|------|------|
| Serverless SQL Pool | $5.00 / TB クエリ処理 | = 約 ¥750 / TB |
| Dedicated SQL Pool DW100c | $1.2068 / 時間 | = 約 ¥181 / 時間（停止時無料） |
| Dedicated SQL Pool DW200c | $2.4136 / 時間 | = 約 ¥362 / 時間 |
| ADLS Gen2 ホット層 | $0.023 / GB / 月 | = 約 ¥3.45 / GB / 月 |
| ADLS Gen2 クール層 | $0.01 / GB / 月 | = 約 ¥1.5 / GB / 月 |
| ADLS Gen2 アーカイブ層 | $0.002 / GB / 月 | = 約 ¥0.3 / GB / 月 |
| ADF データ移動（クラウド IR） | $0.25 / DIU-時間 | ¥37.5 / DIU-時間 |
| ADF パイプライン実行 | $1.00 / 1,000 回 | ¥150 / 1,000 回 |
| データ転送（同一リージョン） | 無料 | ADF ↔ ADLS ↔ Synapse |
| データ転送（インターネット向け） | $0.087 / GB（最初 10 TB）| SPO → Azure は同テナント内のため実質無料 |

#### Synapse コスト試算表（月額）

**Year 1（データ量 100 GB 到達時点）**

| コンポーネント | 想定使用量 | 月額（USD） | 月額（JPY） |
|--------------|-----------|------------|------------|
| Serverless SQL Pool（日次バッチ） | 100 GB × 30 日 = 3 TB / 月のスキャン | $15.00 | ¥2,250 |
| Serverless SQL Pool（Power BI クエリ） | 同時 10 ユーザー、1 クエリ 10 GB スキャン × 20 回 / 日 = 6 TB / 月 | $30.00 | ¥4,500 |
| ADLS Gen2 ストレージ（ホット） | 100 GB × $0.023 | $2.30 | ¥345 |
| ADF パイプライン（日次 1 実行） | 30 回 / 月 × 1 アクティビティ 10 DIU-時間 | $7.50 | ¥1,125 |
| ADF パイプライン実行回数 | 30 回 / 月 | $0.03 | ¥5 |
| **月額合計（Serverless 主体）** | | **$54.83** | **¥8,225** |
| Dedicated SQL Pool DW100c（非推奨: 常時稼働） | 744 時間 × $1.2068 | $898 | ¥134,700 |
| Dedicated SQL Pool DW100c（推奨: 8 時間/日稼働） | 240 時間 × $1.2068 | $290 | ¥43,500 |

**Year 3（データ量 500 GB 到達時点）**

| コンポーネント | 想定使用量 | 月額（USD） | 月額（JPY） |
|--------------|-----------|------------|------------|
| Serverless SQL Pool（日次バッチ） | 500 GB × 30 日 = 15 TB / 月のスキャン | $75.00 | ¥11,250 |
| Serverless SQL Pool（Power BI クエリ） | 10 TB / 月スキャン（データ増加分） | $50.00 | ¥7,500 |
| ADLS Gen2 ストレージ（ホット 200 GB + クール 300 GB） | (200 × $0.023) + (300 × $0.01) | $7.60 | ¥1,140 |
| ADF パイプライン（日次 1 実行） | 30 回 × 20 DIU-時間（データ増加） | $15.00 | ¥2,250 |
| ADF パイプライン実行回数 | 30 回 / 月 | $0.03 | ¥5 |
| **月額合計（Serverless 主体）** | | **$147.63** | **¥22,145** |

**Year 5（データ量 1 TB 到達時点）**

| コンポーネント | 想定使用量 | 月額（USD） | 月額（JPY） |
|--------------|-----------|------------|------------|
| Serverless SQL Pool（日次バッチ） | 1 TB × 30 日 = 30 TB / 月スキャン | $150.00 | ¥22,500 |
| Serverless SQL Pool（Power BI クエリ） | 20 TB / 月スキャン | $100.00 | ¥15,000 |
| ADLS Gen2 ストレージ（ホット 300 GB + クール 400 GB + アーカイブ 300 GB） | (300 × $0.023) + (400 × $0.01) + (300 × $0.002) | $11.50 | ¥1,725 |
| ADF パイプライン（日次 1 実行） | 30 回 × 40 DIU-時間 | $30.00 | ¥4,500 |
| ADF パイプライン実行回数 | 30 回 / 月 | $0.03 | ¥5 |
| **月額合計（Serverless 主体）** | | **$291.53** | **¥43,730** |
| Dedicated SQL Pool DW200c（Power BI 高速化目的、8 時間/日）| 240 時間 × $2.4136 | $579 | ¥86,850 |

---

### 1-2. Databricks (on Azure) コスト試算

#### 料金単価（Azure East Japan）

| コンポーネント | 単価 | 備考 |
|--------------|------|------|
| SQL Warehouse（Small: 2 DBU/時間）Standard | $0.22 / DBU / 時間 | = 約 ¥33 / DBU |
| SQL Warehouse（Small: 2 DBU/時間）Premium | $0.40 / DBU / 時間 | = 約 ¥60 / DBU |
| All-Purpose Cluster（Standard）| $0.15 / DBU / 時間 | = 約 ¥22.5 / DBU |
| All-Purpose Cluster（Premium）| $0.30 / DBU / 時間 | = 約 ¥45 / DBU |
| VM コスト（別途加算）Standard_DS3_v2 | $0.196 / 時間 | = 約 ¥29.4 / 時間 |
| ADLS Gen2 | Synapse と同一 | 共有ストレージ |
| ADF（Databricks 連携） | Synapse と同一 | ADF を共用する場合 |

> Databricks の実コストは DBU + VM コストの合算。SQL Warehouse は VM コスト込みの DBU 単価が適用されるケースもある。以下では公式ドキュメントに基づき DBU + VM を分離して計上する。

#### Databricks コスト試算表（月額）

**Year 1（データ量 100 GB 到達時点）**

| コンポーネント | 想定使用量 | 月額（USD） | 月額（JPY） |
|--------------|-----------|------------|------------|
| SQL Warehouse Small（Premium）バッチ処理 | 2 DBU/時 × 2 時間/日 × 30 日 = 120 DBU | $48.00 | ¥7,200 |
| SQL Warehouse 用 VM（Standard_DS3_v2） | 2 時間/日 × 30 日 = 60 時間 | $11.76 | ¥1,764 |
| SQL Warehouse Small（Power BI DirectQuery） | 2 DBU/時 × 4 時間/日 × 30 日 = 240 DBU | $96.00 | ¥14,400 |
| Power BI 用 VM | 4 時間/日 × 30 日 = 120 時間 | $23.52 | ¥3,528 |
| ADLS Gen2 ストレージ（ホット 100 GB） | $2.30 | $2.30 | ¥345 |
| ADF パイプライン（日次） | Synapse と同等 | $7.53 | ¥1,130 |
| Databricks Premium 管理費（Unity Catalog 等） | 固定なし（DBU 上乗せ分で計上済み） | $0 | ¥0 |
| **月額合計（Premium SQL Warehouse）** | | **$189.11** | **¥28,367** |
| Standard Tier 採用時（$0.22/DBU） | DBU コスト × 55% | **$112.41** | **¥16,862** |

**Year 3（データ量 500 GB 到達時点）**

| コンポーネント | 想定使用量 | 月額（USD） | 月額（JPY） |
|--------------|-----------|------------|------------|
| SQL Warehouse Small（バッチ処理） | 2 DBU/時 × 5 時間/日 × 30 日 = 300 DBU | $120.00 | ¥18,000 |
| SQL Warehouse 用 VM | 5 時間/日 × 30 日 = 150 時間 | $29.40 | ¥4,410 |
| SQL Warehouse Small（Power BI） | 2 DBU/時 × 6 時間/日 × 30 日 = 360 DBU | $144.00 | ¥21,600 |
| Power BI 用 VM | 6 時間/日 × 30 日 = 180 時間 | $35.28 | ¥5,292 |
| ADLS Gen2 ストレージ（ホット + クール） | $7.60 | $7.60 | ¥1,140 |
| ADF パイプライン | $15.03 | $15.03 | ¥2,255 |
| **月額合計（Premium）** | | **$359.31** | **¥53,897** |
| Standard Tier 採用時 | | **$213.31** | **¥31,997** |

**Year 5（データ量 1 TB 到達時点）**

| コンポーネント | 想定使用量 | 月額（USD） | 月額（JPY） |
|--------------|-----------|------------|------------|
| SQL Warehouse Medium（バッチ処理: 4 DBU/時）| 4 DBU/時 × 8 時間/日 × 30 日 = 960 DBU | $384.00 | ¥57,600 |
| SQL Warehouse 用 VM | 8 時間/日 × 30 日 = 240 時間 | $47.04 | ¥7,056 |
| SQL Warehouse Small（Power BI） | 2 DBU/時 × 8 時間/日 × 30 日 = 480 DBU | $192.00 | ¥28,800 |
| Power BI 用 VM | 8 時間/日 × 30 日 = 240 時間 | $47.04 | ¥7,056 |
| ADLS Gen2 ストレージ（階層化） | $11.50 | $11.50 | ¥1,725 |
| ADF パイプライン | $30.03 | $30.03 | ¥4,505 |
| **月額合計（Premium）** | | **$722.61** | **¥108,392** |
| Standard Tier 採用時 | | **$434.61** | **¥65,192** |

---

### 1-3. コスト比較サマリー表

#### 月額比較

| 時点 | Synapse（Serverless 主体） | Synapse（Dedicated 併用） | Databricks（Standard） | Databricks（Premium） |
|------|--------------------------|--------------------------|----------------------|----------------------|
| Year 1（100 GB） | **¥8,225** | ¥51,725 | ¥16,862 | ¥28,367 |
| Year 3（500 GB） | **¥22,145** | ¥22,145 + Dedicated | ¥31,997 | ¥53,897 |
| Year 5（1 TB） | ¥43,730 | ¥43,730 + ¥86,850 | ¥65,192 | ¥108,392 |

#### 年額比較

| 時点 | Synapse（Serverless 主体） | Databricks（Standard） | Databricks（Premium） | Synapse 対 Databricks Premium 差額 |
|------|--------------------------|----------------------|----------------------|------------------------------------|
| Year 1 | **¥98,700** | ¥202,344 | ¥340,404 | Synapse が ¥241,704 安い |
| Year 3 | **¥265,740** | ¥383,964 | ¥646,764 | Synapse が ¥381,024 安い |
| Year 5 | **¥524,760** | ¥782,304 | ¥1,300,704 | Synapse が ¥775,944 安い |

#### 5年間 TCO 試算

以下は各年の年額を線形補間して合算した概算値。

| 年 | Synapse（Serverless） | Databricks（Standard） | Databricks（Premium） |
|----|----------------------|----------------------|----------------------|
| Year 1 | ¥98,700 | ¥202,344 | ¥340,404 |
| Year 2（~300 GB） | ¥155,000 | ¥270,000 | ¥455,000 |
| Year 3 | ¥265,740 | ¥383,964 | ¥646,764 |
| Year 4（~750 GB） | ¥390,000 | ¥570,000 | ¥960,000 |
| Year 5 | ¥524,760 | ¥782,304 | ¥1,300,704 |
| **5年間 TCO** | **¥1,434,200** | **¥2,208,612** | **¥3,702,872** |
| **Synapse 比** | - | 1.54 倍 | 2.58 倍 |

> TCO にはセットアップ・移行工数は含まない。Synapse の Dedicated Pool を Power BI 高速化目的で Year 4 以降に追加する場合は +¥870,000 程度が加算される。

---

### 1-4. コスト最適化オプション

#### Synapse: Serverless vs Dedicated の選択

| 観点 | Serverless 主体 | Dedicated 主体（DW100c） |
|------|----------------|------------------------|
| 月額（Year 1） | ¥8,225 | ¥43,500〜¥134,700 |
| 向いているユース | バッチ処理 + 散発的なクエリ | 常時 DirectQuery（高コンカレンシー） |
| Power BI との相性 | Import モード推奨（DirectQuery は遅延あり） | DirectQuery 推奨（列ストアインデックス最適化） |
| A社での判断 | **A社規模では Serverless 主体が最適**。Power BI は Import モード + スケジュール更新で対応 | Year 5 以降、同時接続が増えた場合に限定活用を検討 |

#### Databricks: Reserved Instance / Committed Use の効果

| 割引プラン | 割引率 | 向いているケース |
|-----------|--------|----------------|
| Azure Reserved VM Instances（1 年） | VM コストに対して ~40% 割引 | SQL Warehouse の VM が主要コストになる Year 3 以降 |
| Azure Reserved VM Instances（3 年） | VM コストに対して ~60% 割引 | プラットフォームが確定後に長期利用を決定した場合 |
| Databricks Committed Use（AWS のみ） | Azure では現時点で非対応 | - |

Reserved VM 適用例（Year 5 Databricks Standard）:
- VM コスト: ¥14,561/月 → 1 年予約適用で ¥8,737/月（▲40%）
- ただし DBU コスト（¥50,631/月）には割引不適用
- TCO 改善効果: 5 年間で概算 +¥300,000 節約（VM 部分のみ）

#### ストレージ階層化による節約効果

| 対象データ | 推奨ティア | 単価（/GB/月） | 節約効果（Year 5 時点） |
|-----------|-----------|--------------|----------------------|
| 直近 6 ヶ月のデータ（300 GB） | ホット | $0.023 | ベースライン |
| 6 ヶ月〜2 年のデータ（400 GB） | クール | $0.01 | ¥2,460/月の節約 |
| 2 年超のデータ（300 GB） | アーカイブ | $0.002 | ¥1,962/月の節約 |
| **階層化合計節約額** | | | **¥4,422/月 = 年間 ¥53,064** |

> アーカイブ層はリストア時に ¥0.023/GB のコストが発生するため、参照頻度が低いデータに限定適用すること。

---

## 2. SharePoint Online コネクタ詳細比較

### 2-1. 認証方式

#### 認証方式比較表

| 認証観点 | Synapse Pipeline（ADF 互換） | Databricks（カスタム実装） |
|---------|----------------------------|--------------------------|
| 推奨認証方式 | サービスプリンシパル（クライアントシークレット or 証明書） | サービスプリンシパル（MSAL ライブラリ経由） |
| 証明書認証 | ADF の「Service Principal Certificate」認証タイプで GUI 設定可 | MSAL の `ClientCertificateCredential` を使いコード実装要 |
| クライアントシークレット | ADF の「Service Principal Key」認証タイプで GUI 設定可 | MSAL の `ClientSecretCredential` を使いコード実装要 |
| シークレット管理 | Azure Key Vault 連携（ADF から直接参照可、GUI 操作のみ） | Databricks Secret Scope（Key Vault バックエンド設定要） |
| Azure AD アプリ登録 | 必要 | 必要（同一手順） |

#### Azure AD アプリ登録の必要権限

| 権限名 | タイプ | 用途 | 付与方法 |
|-------|--------|------|---------|
| `Sites.Read.All` | Application | SharePoint サイト全体の読み取り | 管理者の同意（Admin Consent）必須 |
| `Files.Read.All` | Application | ドキュメントライブラリのファイル読み取り | 管理者の同意必須 |
| `User.Read` | Delegated | ユーザー情報の読み取り（省略可） | 不要なら外す |

> **注意**: `Sites.Read.All` はテナント全体の SharePoint へのアクセスを許可する広範な権限であるため、セキュリティ審査が必要。特定サイトのみに制限したい場合は **Sites.Selected** 権限（Graph API 経由でサイト単位許可）を使用することを推奨する。

#### 証明書認証 vs クライアントシークレット認証

| 比較軸 | 証明書認証 | クライアントシークレット |
|--------|-----------|----------------------|
| セキュリティ | 高（秘密鍵をネットワーク送信しない） | 中（シークレット文字列を送信） |
| 有効期限管理 | 証明書の有効期限管理が必要（最大 2 年） | シークレットの有効期限管理が必要（最大 2 年） |
| ADF での設定難度 | 中（証明書のアップロード手順が必要） | 低（Key Vault から直接参照） |
| Databricks での設定難度 | 高（証明書ファイルの安全な配置が必要） | 中（Secret Scope への登録のみ） |
| A社への推奨 | 本番環境で推奨（セキュリティ要件が高い場合） | **開発・PoC 段階では採用しやすい** |

---

### 2-2. データ取得方式

#### Graph API delta クエリのサポート状況

差分取り込み（変更のあったアイテムのみ取得）は、全件再取得と比べてパイプライン実行時間・コストを大幅に削減できる重要な機能である。

| 比較軸 | Synapse Pipeline（ADF コネクタ） | Databricks（カスタム実装） |
|--------|--------------------------------|--------------------------|
| delta クエリ対応の有無 | **条件付き対応（2024 年現在）** | コード実装により完全対応可 |
| ADF SPO List コネクタの delta 対応詳細 | ADF 組み込みの SharePoint Online List コネクタ自体は delta クエリを直接サポートしていない。ワークアラウンドとして「最終更新日時フィルタ（Modified > 前回実行日時）」を使った疑似差分取り込みが一般的 | Graph API の `GET /sites/{id}/lists/{id}/items/delta` を直接呼び出し、`deltaToken` を ADLS または Databricks テーブルに保存する実装が可能 |
| 変更追跡の信頼性 | 中（更新日時フィルタは削除済みアイテムを検出できない） | 高（delta クエリは削除・変更・追加をすべて検出） |
| 実装コード量 | なし（GUI 設定のみ） | Python / PySpark コード 100〜200 行程度 |

#### SharePoint REST API vs Microsoft Graph API

| 比較軸 | SharePoint REST API | Microsoft Graph API |
|--------|--------------------|--------------------|
| ADF での対応 | SharePoint Online File コネクタ（REST ベース） | SharePoint Online List コネクタ（Graph API ベース） |
| delta クエリ | 非対応 | `/items/delta` で対応 |
| 認証 | サービスプリンシパル対応 | サービスプリンシパル対応 |
| リスト操作 | `_api/lists/{guid}/items` | `/sites/{id}/lists/{id}/items` |
| ファイル取得 | `_api/web/GetFileByServerRelativeUrl` | `/sites/{id}/drive/items/{id}/content` |
| ADF 推奨 | ファイル（Excel, CSV）取得時 | リストアイテム取得時 |

#### リストアイテムの取得制限（5,000 件問題）

SharePoint のリスト表示しきい値は **5,000 件**。この制限を超えるリストを取得する際の対処方法：

| 対処方法 | Synapse Pipeline（ADF） | Databricks（カスタム） |
|---------|------------------------|-----------------------|
| Graph API `$top` + `@odata.nextLink` ページネーション | ADF の SPO List コネクタが自動でページネーション処理するため **対応不要** | コード上で `@odata.nextLink` を取得し、ループ処理を実装する必要あり（実装工数 0.5 日） |
| インデックス列でのフィルタリング | ADF コネクタで `$filter` クエリを指定可 | Graph API の `$filter` パラメータをコードで設定 |
| View-based の取得 | ADF でビュー ID を指定可 | API パラメータで対応可 |
| 対応容易さ | **高（自動ページネーション）** | 中（コード実装要） |

#### 添付ファイル・メタデータの取得可否

| データ種別 | ADF SPO List コネクタ | ADF SPO File コネクタ | Databricks（Graph API） |
|-----------|----------------------|----------------------|------------------------|
| リストアイテム（テキスト/数値列） | 取得可 | - | 取得可 |
| 添付ファイル（バイナリ） | 取得不可（メタデータのみ） | 取得可（ドキュメントライブラリのファイル） | 取得可 |
| カスタム列メタデータ | 取得可（展開フィールドで指定） | 一部対応（ドキュメントライブラリのプロパティ） | 取得可（`$expand` で展開） |
| バージョン履歴 | 取得不可 | 取得不可 | 取得可（`/versions` API） |
| 選択フィールド（Choice） | 取得可 | - | 取得可 |
| 参照フィールド（Lookup） | `$expand` で取得可 | - | `$expand` で取得可 |

---

### 2-3. コネクタの成熟度評価

#### ADF SharePoint Online List コネクタの制約（既知の制限事項）

| 制約事項 | 詳細 | 影響度 |
|---------|------|--------|
| delta クエリ非対応 | 差分取り込みを行う場合は「更新日時フィルタ」を使う疑似差分になる。削除済みレコードは検出不可 | 中（削除追跡が不要なユースケースでは問題なし） |
| 添付ファイル取得不可 | List コネクタはアイテムのメタデータのみ取得。バイナリファイルが必要な場合は File コネクタを別途設定 | 低（A 社の想定では主にリストデータを扱うため問題なし） |
| 大量データ時のパフォーマンス | 数万〜数十万件のリストを取得する場合、1 アクティビティでの実行時間が長くなる。並列パーティション設定（パーティション数最大 4）で緩和可 | 低（A 社規模では問題なし） |
| SharePoint Server（オンプレ）非対応 | SharePoint Online 専用。オンプレ SharePoint には SharePoint Server コネクタが別途必要 | 対象外（A 社は SPO） |
| 証明書認証のUI対応 | 証明書認証は ADF の GUI から直接設定可能。ただし証明書の JSON 化（PFX → Base64）が必要 | 低（一度設定すれば再操作不要） |
| トークンリフレッシュ自動化 | ADF がサービスプリンシパルのトークン取得・リフレッシュを自動管理。実装上の考慮不要 | なし（メリット） |

#### ADF SharePoint Online File コネクタとの違い

| 項目 | List コネクタ | File コネクタ |
|------|-------------|--------------|
| 対象 | SharePoint リスト（構造化データ） | ドキュメントライブラリ（Excel, CSV, PDF 等） |
| 出力形式 | JSON / Parquet（ADF が自動変換） | バイナリ / テキスト（Excel は ADF が変換） |
| 認証 | サービスプリンシパル / OAuth2 | サービスプリンシパル / OAuth2 |
| delta 対応 | 疑似差分（更新日時フィルタ） | なし（全件取得が基本） |
| A 社での活用 | 主要（業務データのリスト取得） | 補助（Excel 形式の帳票取得時） |

#### Databricks での SharePoint 接続実装パターン

| 実装パターン | 概要 | 成熟度 | 推奨度 |
|------------|------|--------|--------|
| MSAL + requests + PySpark | `msal` ライブラリで Graph API 認証トークンを取得し、`requests` で REST 呼び出し。結果を DataFrame に変換 | 高（広く採用されている標準パターン） | A 社規模では最適 |
| spark-sharepoint（OSS） | Apache Spark 用 SharePoint コネクタ（GitHub 上の非公式ライブラリ）| 低（メンテナンス状況が不安定） | 非推奨 |
| Databricks 公式 SharePoint コネクタ | 現時点（2026 年 3 月）で Databricks 公式コネクタは存在しない | - | 非対応 |
| ADF → ADLS → Databricks | ADF の SPO コネクタで ADLS に格納後、Databricks で ADLS を読み込む構成 | 高（ADF の信頼性を活用） | Databricks 採用時でも ADF を併用するなら有力 |

**MSAL + requests 実装イメージ:**

```python
import msal
import requests
from pyspark.sql import SparkSession

# シークレットは Databricks Secret Scope から取得
tenant_id = dbutils.secrets.get("keyvault-scope", "sp-tenant-id")
client_id = dbutils.secrets.get("keyvault-scope", "sp-client-id")
client_secret = dbutils.secrets.get("keyvault-scope", "sp-client-secret")

# MSAL でトークン取得
app = msal.ConfidentialClientApplication(
    client_id=client_id,
    client_credential=client_secret,
    authority=f"https://login.microsoftonline.com/{tenant_id}"
)
result = app.acquire_token_for_client(scopes=["https://graph.microsoft.com/.default"])
token = result["access_token"]

# Graph API でリストアイテム取得（ページネーション対応）
site_id = "your-site-id"
list_id = "your-list-id"
url = f"https://graph.microsoft.com/v1.0/sites/{site_id}/lists/{list_id}/items?$expand=fields"
headers = {"Authorization": f"Bearer {token}"}
items = []
while url:
    resp = requests.get(url, headers=headers).json()
    items.extend(resp.get("value", []))
    url = resp.get("@odata.nextLink")  # ページネーション

# PySpark DataFrame に変換
df = spark.createDataFrame(items)
df.write.format("delta").mode("overwrite").save("/mnt/adls/bronze/sharepoint/")
```

> delta クエリを使う場合は `url = f".../items/delta"` から開始し、`@odata.deltaLink` を ADLS の状態管理テーブルに保存する実装が必要。

---

### 2-4. 差分取り込みの実装難易度

| 比較軸 | Synapse Pipeline（ADF） | Databricks（MSAL + 独自実装） |
|--------|------------------------|-----------------------------|
| 実装アプローチ | 更新日時フィルタ（`Modified ge @{pipeline().TriggerTime}` を ADF パラメータで設定） | Graph API delta クエリ + deltaToken の永続化 |
| 削除レコードの検出 | 非対応（全件再取得 or 論理削除フラグ依存） | 対応（delta クエリは `@removed` で削除を通知） |
| 実装工数 | 0.5 日（ADF GUI 設定） | 2〜3 日（コード + テスト） |
| 運用保守 | ADF が自動管理 | deltaToken の保存・復元ロジックを自前管理 |
| 信頼性 | 中（更新日時が変わらない更新は取り込み漏れリスク） | 高（Graph API 側が変更を保証） |

---

### 2-5. 実装工数見積もり

#### Synapse Pipeline（ADF GUI ベース）

| 作業項目 | 工数 | 備考 |
|---------|------|------|
| Azure AD アプリ登録・権限付与 | 0.5 日 | 管理者承認待ち時間は含まない |
| ADF Linked Service 設定（SPO, ADLS） | 0.5 日 | GUI 操作のみ |
| ADF パイプライン設計（Copy Activity） | 1 日 | データマッピング含む |
| 差分取り込み（更新日時フィルタ）設定 | 0.5 日 | パラメータ化対応 |
| Key Vault 連携・シークレット設定 | 0.5 日 | |
| テスト・デバッグ | 1 日 | ADF のデバッグモードで実行確認 |
| **合計** | **4 日** | 並走作業で最短 3 日も可 |

#### Databricks（カスタムコード実装）

| 作業項目 | 工数 | 備考 |
|---------|------|------|
| Azure AD アプリ登録・権限付与 | 0.5 日 | ADF と同一手順 |
| Databricks Secret Scope 設定（Key Vault バックエンド） | 1 日 | Terraform での自動化を含む場合 |
| MSAL + Graph API コード実装 | 2 日 | ページネーション・エラーハンドリング含む |
| delta クエリ実装（deltaToken 管理） | 1.5 日 | 状態管理テーブル設計含む |
| PySpark DataFrame 変換・Delta Lake 書き込み | 1 日 | |
| Databricks Job スケジューリング設定 | 0.5 日 | |
| テスト・デバッグ | 2 日 | ユニットテスト + 統合テスト |
| **合計** | **8.5 日** | 慣れた開発者で最短 6 日 |

#### テスト・デバッグのしやすさ

| 観点 | Synapse Pipeline（ADF） | Databricks |
|------|------------------------|-----------|
| デバッグ機能 | ADF の「デバッグ実行」機能でパイプライン全体またはアクティビティ単位で確認可。失敗時のエラーメッセージが GUI 上に表示される | Databricks Notebook でのインタラクティブ実行。セル単位でのデバッグが容易 |
| ログの見やすさ | Azure Monitor + ADF 実行履歴（GUI）で視覚的に確認しやすい | Spark UI + クラスタログ（エンジニアリング知識が必要） |
| 再実行 | GUI 上のボタン 1 つで再実行可 | Notebook 再実行または Job の再トリガーが必要 |
| 少人数チームへの適合 | 高（SQL / Python の深い知識なしに設定・確認可） | 低〜中（Spark / Python の知識が前提） |

---

## 3. 総合判断と推奨の更新

### 3-1. 深掘り結果サマリー

| 比較軸 | 深掘り前の評価 | 深掘り後の評価 | 変化 |
|--------|--------------|--------------|------|
| コスト（Year 1〜3） | Synapse ≈ Databricks | Synapse が **2〜3 倍安い** | Synapse 有位が拡大 |
| コスト（Year 5） | 概算のみ | Synapse が **1.5〜2.5 倍安い** | Synapse 有位が拡大 |
| SPO コネクタ成熟度 | Synapse が優位 | Synapse が優位（但し delta クエリ非対応の制約を確認） | 維持 |
| 差分取り込みの信頼性 | 未評価 | Databricks（delta クエリ）が高い | Databricks に利点 |
| 実装工数 | Synapse が低い | Synapse 4 日 vs Databricks 8.5 日 | Synapse 有位が拡大 |
| 少人数運用 | Synapse が優位 | Synapse が優位（確認） | 維持 |

### 3-2. Synapse 推奨の妥当性検証

**初期比較での Synapse 推奨は妥当であることが深掘りによって確認された。**

特に以下の点で推奨を支持する根拠が強化された：

1. **コスト差が想定以上に大きい**: 初期比較では「同等コスト」と評価していたが、実データ量・クエリパターンで試算すると 5 年 TCO で Synapse が Databricks Premium の 39% のコストに収まる。少人数チームの案件において年間 ¥80〜260 万円の差は意思決定に直結する。

2. **SharePoint コネクタの差が実装工数に直結**: ADF の SPO List コネクタは GUI だけで設定できるため、4 日で稼働できる。Databricks は 8.5 日かかり、かつ Spark / Python エンジニアが必要になる。A 社の 2〜3 名チームで Databricks を選択した場合、ビルド・保守に占めるエンジニアリング工数の割合が高くなる。

3. **delta クエリ非対応は許容可能**: Synapse（ADF）の SPO コネクタは delta クエリに対応していない制約があるが、A 社の SharePoint データで「削除追跡」が業務要件に含まれない場合は更新日時フィルタで十分。削除追跡が必須であれば、ADF カスタムアクティビティ（Web Activity で Graph API 直接呼び出し）で補完可能であり、Databricks に乗り換えるほどの理由にはならない。

### 3-3. Databricks が有利になる損益分岐点

| 条件 | Databricks が有利になる閾値 | A 社での該当見込み |
|------|--------------------------|-----------------|
| データ量 | **10 TB 超**（大規模 ETL でのスケールメリットが出るため） | 5 年後 1 TB = 非該当 |
| 同時接続ユーザー | **50 ユーザー超**（SQL Warehouse の Auto-Scale メリットが発現） | 10 ユーザー = 非該当 |
| リアルタイム処理 | **Streaming / Kafka 連携が必要な場合** | バッチのみ = 非該当 |
| ML / AI 統合 | **MLflow + 特徴量ストア + モデルサービング** が DWH と統合される場合 | 現時点で要件なし |
| マルチクラウド | **Azure + 他クラウドの横断分析** が必要な場合 | Azure 専用 = 非該当 |
| Delta Lake 活用 | **ACID トランザクション・タイムトラベルを大規模に活用** する場合 | Synapse Serverless も Delta 形式を読み取り可能 |

**結論: A 社の 5 年ロードマップ（〜1 TB、〜10 ユーザー）では Databricks が有利になる損益分岐点に達しない。**

### 3-4. A社の5年ロードマップを考慮した推奨

#### 最終推奨: **Azure Synapse Analytics（Serverless SQL Pool 主体）**

| フェーズ | 推奨構成 | 理由 |
|---------|---------|------|
| Year 1〜2（〜300 GB） | Serverless SQL Pool のみ | 最小コスト（月額 ¥1〜2 万）、Power BI は Import モード |
| Year 3〜4（〜700 GB） | Serverless 主体 + 必要に応じて Dedicated DW100c を時間限定起動 | Power BI の応答改善が必要になれば Dedicated を 1 日 8 時間稼働で追加 |
| Year 5 以降（1 TB〜） | 利用状況に応じて再評価。同時接続増・ML 要件が追加された場合に Databricks 移行を検討 | ストレージは ADLS Gen2 共通のためコネクタ交換コストは低い |

#### ロードマップ上の留意事項

1. **Delta Lake 形式での格納を Day 1 から推奨**: ADLS Gen2 上のデータを最初から Delta 形式で保存しておくことで、将来 Databricks に移行した際のストレージ移行コストがゼロになる。Synapse Serverless は Delta 形式を読み取り可能。

2. **ADF の SPO 差分取り込みロジックに削除追跡が必要になった場合**: ADF の Web Activity で Graph API の delta クエリを直接呼び出すカスタムパイプラインを追加する。Databricks に移行せずとも対応可能。

3. **Power BI の接続モード戦略**: Year 1〜3 は Import モード + 毎朝 7:00 スケジュール更新（9:00 SLA を満たすため）で対応。Year 4 以降に Dedicated Pool を限定稼働させる場合は DirectQuery に切り替えることで最新データへのアクセスが可能になる。

4. **Databricks への移行オプションは排除しない**: ADLS Gen2 + Delta 形式の共通基盤を維持することで、将来的に Databricks 移行のオプションを低コストで保持できる。「Databricks を選ばない」のではなく「今は選ばない」という判断であることをクライアントに明示する。

---

## 4. 比較総括

### 最終スコア（2候補）

| 評価観点 | 重み | Azure Synapse | Databricks | 備考 |
|----------|------|:------------:|:----------:|------|
| コスト（5年 TCO） | 25% | 5 | 2 | Synapse が 2.6 倍安い |
| SPO コネクタ実装容易性 | 20% | 5 | 3 | 工数差 4.5 日 |
| SPO 差分取り込み信頼性 | 10% | 3 | 5 | delta クエリ対応の有無 |
| 少人数チーム運用 | 20% | 5 | 3 | GUI 中心 vs コード中心 |
| Power BI 連携 | 10% | 5 | 4 | Azure ネイティブ統合 |
| 将来スケーラビリティ | 10% | 3 | 5 | 10 TB+ では Databricks が有利 |
| Azure 親和性 / IaC | 5% | 5 | 4 | 単一 Provider vs 二 Provider |
| **加重合計** | 100% | **4.55** | **3.30** | |

### 最終結論

深掘り比較の結果、**初期比較での Synapse 推奨は妥当であり、かつ推奨の確度が高まった**。

Databricks は大規模データ処理・ML 統合・リアルタイム処理において卓越したプラットフォームであるが、A 社の現行要件（100 GB〜1 TB、日次バッチ、10 ユーザー以下）に対しては「高機能すぎる・高コストすぎる・運用難易度が高い」選択肢となる。

**Azure Synapse Analytics（Serverless SQL Pool 主体）**を選定することで：
- 5 年間の追加コストを最小化（TCO 差額 ¥144 万〜¥227 万の削減）
- 少人数チームが習熟しやすい GUI 中心の運用
- SharePoint Online との確立された統合パス
- Azure 単一テナント内でのセキュリティ・監視の一元化

以上の効果が得られる。なお ADLS Gen2 上のデータを Delta 形式で管理することで、将来 Databricks へ移行する際の選択肢を確保しておくことを強く推奨する。

---

*本書は `.company/data/pipelines/a-company-dwh/platform-comparison.md`（初期 3 候補比較）の深掘り版として作成。両書を合わせて最終プラットフォーム選定の判断材料とすること。*
