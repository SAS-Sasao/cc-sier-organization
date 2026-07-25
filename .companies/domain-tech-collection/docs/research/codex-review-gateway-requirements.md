# Codex レビューゲートウェイ 要件定義書

## セカンドオピニオン・レビューゲートウェイ — Codex App Server 組み込み Web サービス

| 項目 | 内容 |
|------|------|
| ドキュメント種別 | 要件定義書 v0.1（ドラフト） |
| 作成日 | 2026-07-25 |
| 作成者 | 秘書室（オーナー壁打ちに基づく） |
| 対象システム | codex-review-gateway（仮称） |
| ステータス | レビュー待ち |

---

## 1. 概要

### 1.1 背景

- cc-sier の 3 層レビュー（L0 機械 / L1 セルフ構造 / L2 独立 LLM）は L2 を Claude の fresh agent が担っており、同一ベンダーモデル内での評価に閉じている
- OpenAI Codex の App Server（`codex app-server` サブコマンド）は、エージェント本体を JSON-RPC 2.0 over stdio で外部公開しており、Web サービスのバックエンドから子プロセスとして組み込み可能
- 「別ベンダーの独立レビュアーによるセカンドオピニオン」を機械的に取得できるゲートウェイを作ることで、authoring bias / 単一モデルバイアスの両方を排除した品質担保を実現する

### 1.2 目的

1. GitHub PR を対象に、Codex による独立コードレビュー・採点を自動実行する Web サービスを構築する
2. 採点結果を構造化 JSON（6 軸 + composite）で返し、既存の 3 層レビュー基盤や CI と接続可能にする
3. Codex App Server プロトコル（スレッド管理・ターンストリーミング・承認フロー）の実践習得を副次目的とする

### 1.3 スコープ

| 区分 | 内容 |
|------|------|
| スコープ内 | PR レビュー実行、6 軸採点、GitHub 連携（Webhook / PR コメント）、レビュー履歴管理、プロンプトテンプレート管理、Web UI |
| スコープ外（v0.1） | マルチテナント SaaS 化、Claude 側レビューの実行（突き合わせは結果 JSON の取り込みのみ）、コード修正の自動適用、WebSocket transport（experimental のため） |

### 1.4 システム構成概要

```
[ブラウザ]                    [バックエンド (コンテナ)]
  Web UI  ──HTTPS──▶  API サーバー ──spawn──▶ codex app-server (子プロセス)
                          │                     │  JSON-RPC 2.0 / stdio (JSONL)
GitHub ──Webhook──▶       │                     │  read-only sandbox
                          │◀──採点JSON回収──────┘
                          ├──▶ DB (レビュー履歴・設定)
                          └──▶ GitHub API (PR コメント投稿)
```

- レビュー 1 件 = app-server プロセス 1 spawn（ステートレス運用）。実行後は破棄し、スレッド常駐管理を回避する
- Codex 認証は API キー（サーバーサイド前提。ChatGPT サインインは使用しない）

---

## 2. 機能要件

### 2.1 レビュー実行系

| ID | 機能名 | 内容 | 優先度 |
|----|--------|------|--------|
| FR-01 | Webhook 受付 | GitHub Webhook（pull_request: opened / synchronize）を受信し、レビュージョブを起票する | 必須 |
| FR-02 | 手動レビュー実行 | Web UI から任意の PR URL を指定してレビューを実行できる | 必須 |
| FR-03 | 差分取得 | GitHub API で PR の diff・変更ファイル・PR メタ情報（タイトル / 本文 / ベースブランチ）を取得する | 必須 |
| FR-04 | Codex レビュー実行 | `codex app-server` を read-only サンドボックスで spawn し、diff + レビュープロンプトを投入。ターン完了まで実行する | 必須 |
| FR-05 | 構造化採点 | レビュー結果を 6 軸採点 JSON（s1〜s6 / composite / verdict / findings / fix_suggestions）で回収する。JSON パース失敗時は 1 回だけ再指示リトライする | 必須 |
| FR-06 | タイムアウト制御 | レビュー実行に上限時間を設け、超過時はプロセスを kill しステータスを timeout として記録する | 必須 |
| FR-07 | 同時実行制御 | 同時レビュー数に上限（既定 3）を設け、超過分はキューイングする | 必須 |
| FR-08 | 承認フロー拒否 | app-server からのコマンド実行承認リクエストは全拒否ポリシーで応答する（read-only レビューのため実行系操作は不要） | 必須 |

### 2.2 結果出力系

| ID | 機能名 | 内容 | 優先度 |
|----|--------|------|--------|
| FR-09 | PR コメント投稿 | 採点サマリー（6 軸スコア表 + 主要 findings）を PR コメントとして投稿する。再レビュー時は既存コメントを更新する | 必須 |
| FR-10 | 結果 API | レビュー結果 JSON を返す REST API を提供する（CI / 外部ツールからの取得用） | 必須 |
| FR-11 | セカンドオピニオン突き合わせ | 外部（Claude L2 等）の採点 JSON を API で受け付け、Codex 採点との軸別差分・composite 乖離を算出して表示する | 高 |
| FR-12 | 乖離アラート | 突き合わせで composite 乖離が閾値（既定 0.15）を超えた場合、PR コメントおよび UI 上で警告表示する | 中 |

### 2.3 管理系

| ID | 機能名 | 内容 | 優先度 |
|----|--------|------|--------|
| FR-13 | リポジトリ登録 | レビュー対象リポジトリの登録・無効化。Webhook シークレットの設定を含む | 必須 |
| FR-14 | プロンプトテンプレート管理 | レビュープロンプト（採点軸定義を含む）の作成・編集・バージョン管理。リポジトリごとに適用テンプレートを選択できる | 高 |
| FR-15 | レビュー履歴閲覧 | 過去のレビュー結果を一覧・詳細で閲覧できる。リポジトリ / 期間 / verdict でフィルタできる | 必須 |
| FR-16 | ユーザー認証 | GitHub OAuth によるログイン。登録リポジトリへの read 権限を持つユーザーのみ利用可能 | 必須 |
| FR-17 | 監査ログ | レビュー実行・設定変更・API アクセスを監査ログとして記録する | 中 |
| FR-18 | コスト可視化 | レビューごとのトークン消費・API コスト概算を記録し、月次集計を表示する | 中 |

---

## 3. 非機能要件

| ID | 分類 | 要件 | 目標値 |
|----|------|------|--------|
| NFR-01 | 性能 | 1 レビューの完了時間（Webhook 受信 → PR コメント投稿） | 中規模 diff（〜500 行）で 5 分以内 |
| NFR-02 | 性能 | Web UI の画面応答 | 主要画面 1.5 秒以内 |
| NFR-03 | 可用性 | サービス稼働率（個人〜チーム利用前提） | 99%（営業時間帯） |
| NFR-04 | 可用性 | レビュー失敗時のリトライ | 自動 1 回。以後は failed として記録し UI から手動再実行可能 |
| NFR-05 | セキュリティ | コード分離 | レビュー対象コードはレビュー実行中のみ一時ワークスペースに保持し、完了後に削除。app-server はコンテナ + read-only ファイルシステムで隔離 |
| NFR-06 | セキュリティ | 承認ポリシー | コマンド実行承認は全拒否。ネットワークアクセスはモデル API への egress のみ許可 |
| NFR-07 | セキュリティ | シークレット管理 | Codex API キー / GitHub App 秘密鍵 / Webhook シークレットは Secrets Manager 相当で管理。環境変数直書き禁止 |
| NFR-08 | セキュリティ | 通信 | 全通信 TLS。Webhook は署名検証（X-Hub-Signature-256）必須 |
| NFR-09 | スケーラビリティ | 同時レビュー | プロセスプールなしの spawn-per-review 方式で同時 3 件。将来はワーカーコンテナ水平分割で拡張 |
| NFR-10 | コスト | モデル API 費用 | 1 レビューあたり上限トークン数を設定（超過時は diff を要約投入にフォールバック）。月次予算アラートを設定 |
| NFR-11 | 保守性 | プロトコル互換 | App Server プロトコルのバージョン差異を吸収するアダプタ層を設け、Codex CLI 更新の影響を局所化する。CLI バージョンはピン留めする |
| NFR-12 | 監査 | ログ保持 | レビューログ・監査ログは 1 年保持。個人情報・顧客コードのログ出力は禁止 |
| NFR-13 | 運用 | 死活監視 | ジョブキュー滞留・プロセス異常終了・API エラー率を監視し通知する |

---

## 4. データ定義

### 4.1 エンティティ一覧

| エンティティ | 役割 | 主なライフサイクル |
|-------------|------|-------------------|
| User | GitHub OAuth ユーザー | ログイン時作成 |
| Repository | レビュー対象リポジトリ | 管理画面で登録 |
| PromptTemplate | レビュープロンプト（採点軸定義含む） | バージョン追加のみ（immutable） |
| ReviewRequest | レビュージョブ（1 PR イベント = 1 件） | queued → running → completed / failed / timeout |
| ReviewResult | Codex 採点結果 | ReviewRequest 完了時に 1 件生成 |
| ExternalReview | 外部レビュー結果（Claude L2 等の突き合わせ用） | API 受付時に生成 |
| AuditLog | 操作・実行の監査証跡 | 追記のみ |

### 4.2 主要テーブル定義

#### users

| カラム | 型 | 制約 | 説明 |
|--------|-----|------|------|
| id | uuid | PK | |
| github_login | varchar | unique, not null | GitHub ユーザー名 |
| github_user_id | bigint | unique, not null | GitHub 数値 ID |
| role | enum | not null | admin / member |
| created_at / updated_at | timestamptz | not null | |

#### repositories

| カラム | 型 | 制約 | 説明 |
|--------|-----|------|------|
| id | uuid | PK | |
| full_name | varchar | unique, not null | 例: SAS-Sasao/cc-sier-organization |
| webhook_secret_ref | varchar | not null | シークレット参照キー（値は保存しない） |
| prompt_template_id | uuid | FK → prompt_templates | 適用テンプレート |
| enabled | boolean | not null, default true | |
| created_at / updated_at | timestamptz | not null | |

#### prompt_templates

| カラム | 型 | 制約 | 説明 |
|--------|-----|------|------|
| id | uuid | PK | |
| name | varchar | not null | 例: default-6axis |
| version | int | not null | name + version で unique |
| body | text | not null | レビュープロンプト本文 |
| axes_schema | jsonb | not null | 採点軸定義（軸 ID / 名称 / 致命軸フラグ） |
| created_by | uuid | FK → users | |
| created_at | timestamptz | not null | 既存行は更新せず新バージョンを追加 |

#### review_requests

| カラム | 型 | 制約 | 説明 |
|--------|-----|------|------|
| id | uuid | PK | |
| repository_id | uuid | FK, not null | |
| pr_number | int | not null | |
| head_sha | varchar | not null | レビュー対象コミット |
| trigger | enum | not null | webhook / manual / api |
| status | enum | not null | queued / running / completed / failed / timeout |
| prompt_template_id | uuid | FK, not null | 実行時に確定したテンプレート |
| requested_by | uuid | FK → users, nullable | manual 実行時のみ |
| started_at / finished_at | timestamptz | nullable | |
| error_detail | text | nullable | 失敗時の要因 |
| created_at | timestamptz | not null | |

#### review_results

| カラム | 型 | 制約 | 説明 |
|--------|-----|------|------|
| id | uuid | PK | |
| review_request_id | uuid | FK, unique, not null | 1:1 |
| scores | jsonb | not null | {s1: 0.95, ... s6: 1.0} |
| composite | numeric(3,2) | not null | 0.00–1.00 |
| verdict | enum | not null | pass / fail |
| critical_triggered | boolean | not null | |
| findings | jsonb | not null | 指摘事項配列（file / line / severity / message） |
| fix_suggestions | jsonb | not null | 修正提案配列 |
| tokens_input / tokens_output | int | not null | コスト集計用 |
| model | varchar | not null | 実行モデル ID |
| raw_response_ref | varchar | nullable | 生ログの保存先参照（オブジェクトストレージ） |
| created_at | timestamptz | not null | |

#### external_reviews

| カラム | 型 | 制約 | 説明 |
|--------|-----|------|------|
| id | uuid | PK | |
| review_request_id | uuid | FK, not null | 突き合わせ対象 |
| source | varchar | not null | 例: claude-l2 |
| scores | jsonb | not null | 同一スキーマの採点 JSON |
| composite | numeric(3,2) | not null | |
| verdict | enum | not null | |
| divergence | numeric(3,2) | not null | Codex composite との乖離（絶対値） |
| created_at | timestamptz | not null | |

#### audit_logs

| カラム | 型 | 制約 | 説明 |
|--------|-----|------|------|
| id | bigserial | PK | |
| actor | varchar | not null | ユーザー ID または system |
| action | varchar | not null | 例: review.execute, template.create |
| target | varchar | nullable | 対象リソース識別子 |
| detail | jsonb | nullable | |
| created_at | timestamptz | not null | |

### 4.3 ER 概要

```
users ──< review_requests >── repositories ──> prompt_templates
              │ 1:1                                    ▲
              ├── review_results                       │（バージョン固定参照）
              └──< external_reviews
audit_logs（独立・追記のみ）
```

### 4.4 データ保持ポリシー

| データ | 保持期間 | 備考 |
|--------|---------|------|
| レビュー結果（scores / findings） | 1 年 | 履歴・傾向分析用 |
| 生レスポンスログ | 90 日 | オブジェクトストレージ、以後自動削除 |
| レビュー対象コード（一時ワークスペース） | レビュー実行中のみ | 完了・失敗を問わず即時削除 |
| 監査ログ | 1 年 | |

---

## 5. フロント定義

### 5.1 画面一覧

| ID | 画面名 | 主な用途 | 優先度 |
|----|--------|---------|--------|
| SC-01 | ログイン | GitHub OAuth 開始 | 必須 |
| SC-02 | ダッシュボード | 直近レビューの状況一覧・実行中ジョブ・コストサマリー | 必須 |
| SC-03 | レビュー詳細 | 1 レビューの採点・findings・突き合わせ結果の閲覧 | 必須 |
| SC-04 | レビュー履歴 | 全レビューの検索・フィルタ一覧 | 必須 |
| SC-05 | リポジトリ設定 | 対象リポジトリの登録・Webhook 設定・テンプレート割当 | 必須 |
| SC-06 | プロンプトテンプレート管理 | テンプレートの閲覧・新バージョン作成・差分表示 | 高 |
| SC-07 | 手動レビュー実行 | PR URL 指定での実行（モーダルでも可） | 必須 |

### 5.2 画面遷移

```
SC-01 ログイン
   └─▶ SC-02 ダッシュボード
          ├─▶ SC-03 レビュー詳細（一覧の行クリック）
          ├─▶ SC-04 レビュー履歴 ─▶ SC-03
          ├─▶ SC-05 リポジトリ設定 ─▶ SC-06 テンプレート管理
          └─▶ SC-07 手動レビュー実行（モーダル）─▶ SC-03（実行後）
```

### 5.3 主要画面の構成要素

#### SC-02 ダッシュボード

| 要素 | 内容 |
|------|------|
| 実行中ジョブカード | running / queued のレビューをリアルタイム表示（ステータスポーリング 5 秒間隔） |
| 直近レビューテーブル | リポジトリ / PR / verdict / composite / 乖離 / 実行日時。verdict は pass / fail の文字列表示 |
| コストサマリー | 当月トークン消費・概算費用・予算に対する消化率 |
| 乖離アラート | 突き合わせ乖離が閾値超のレビューを警告カードで表示 |

#### SC-03 レビュー詳細

| 要素 | 内容 |
|------|------|
| ヘッダ | PR リンク / head SHA / 実行日時 / ステータス / 使用テンプレート（バージョン付き） |
| 採点レーダー・スコア表 | 6 軸スコア + composite + critical_triggered。ExternalReview がある場合は 2 系列重ね表示 |
| findings リスト | severity 降順。file:line リンクで GitHub の該当行へ遷移 |
| fix_suggestions | 修正提案の一覧（コピー可能なコードブロック） |
| 突き合わせパネル | 軸別の Codex vs 外部レビューの差分表・乖離値 |
| 操作 | 再レビュー実行ボタン / PR コメント再投稿ボタン |

#### SC-05 リポジトリ設定

| 要素 | 内容 |
|------|------|
| リポジトリ一覧 | full_name / enabled / 適用テンプレート / 直近レビュー日時 |
| 登録フォーム | full_name 入力 → Webhook 設定手順の表示（シークレットは登録時のみ一度表示） |
| テンプレート割当 | プルダウンでテンプレート（name + version）を選択 |

### 5.4 UI 全般方針

| 項目 | 方針 |
|------|------|
| 技術スタック | SPA（React + TypeScript）+ REST API。状態管理は軽量（TanStack Query 相当）で足りる規模 |
| リアルタイム性 | v0.1 はポーリング。ストリーミング表示（レビュー進行ログ）は v0.2 で SSE を検討 |
| レスポンシブ | デスクトップ優先。タブレット幅まで対応、モバイル最適化はスコープ外 |
| 表示言語 | 日本語 UI。findings 等モデル出力は原文（英語混在）のまま表示 |
| アクセシビリティ | スコア・verdict は色 + テキストの冗長表現（色のみでの判定表現を禁止） |
| エラー表示 | 失敗レビューは error_detail の要約と再実行導線を必ず表示（silent fail 禁止） |

---

## 6. 外部インターフェース

| IF | 相手 | 方式 | 内容 |
|----|------|------|------|
| IF-01 | GitHub | Webhook（受信） | pull_request イベント。署名検証必須 |
| IF-02 | GitHub | REST API（送信） | diff 取得 / PR コメント投稿。GitHub App としてインストール |
| IF-03 | Codex App Server | JSON-RPC 2.0 / stdio | 子プロセス spawn。スレッド作成 → プロンプト投入 → ターン完了イベント受信 → 応答回収。承認リクエストは全拒否応答 |
| IF-04 | 外部レビュアー（Claude L2 等） | REST API（受信） | 採点 JSON の受け付け（POST /api/reviews/{id}/external） |
| IF-05 | CI（GitHub Actions 等） | REST API（提供） | レビュー結果取得（GET /api/reviews?pr=...）。ゲート判定に利用 |

---

## 7. 前提・制約・リスク

| # | 種別 | 内容 | 対応方針 |
|---|------|------|---------|
| 1 | 前提 | Codex CLI がバックエンドコンテナに同梱され、API キー認証で動作すること | CLI バージョンをピン留めし、更新はアダプタ層のテスト通過後に反映 |
| 2 | 制約 | App Server プロトコルは公式クライアント優先で進化するため、破壊的変更があり得る | NFR-11 のアダプタ層 + プロトコル疎通のスモークテストを CI に組み込む |
| 3 | 制約 | WebSocket transport は experimental | v0.1 では stdio のみ採用 |
| 4 | リスク | 大規模 diff でトークン上限・タイムアウトに達する | diff 分割 / 要約フォールバック（NFR-10）。上限超過は結果に partial フラグを付与 |
| 5 | リスク | 顧客コードを外部モデル API に送信することの契約上の制約 | 対象リポジトリ登録を承認制にし、送信先・保持期間を利用規約に明記。顧客案件コードは登録禁止を初期ポリシーとする |
| 6 | リスク | 採点 JSON の形式逸脱（パース失敗） | スキーマバリデーション + 1 回再指示リトライ（FR-05）。失敗時は failed として人間レビューへフォールバック |

---

## 8. 今後の進め方（参考）

1. 本要件のレビュー・フィックス（v0.2 で API 仕様・採点軸の詳細定義を追加）
2. App Server プロトコル疎通の PoC（spawn → 採点 JSON 回収の最小ループ）
3. アーキテクチャ設計（AWS 構成想定なら `/company-diagram` で構成図化）
4. MVP 実装（FR-01〜FR-10 + SC-02/03）
