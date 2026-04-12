# NEC cotomi & Agentic AI 戦略 Deep Dive

調査日: 2026-04-10
ソース: ai-war-room 壁打ちセッション + ウェブ調査
関連: [NEC中期経営計画](nec-midterm-plan-research-2026-04-09.md) / [BluStellar Deep Dive](blustellar-retail-deep-dive-2026-04-10.md)

---

## 1. cotomi 技術詳細

### 1.1 モデルの進化とバージョン

| 時期 | バージョン | 概要 |
|------|-----------|------|
| 2023-07 | cotomi v1 | 初代モデル。130億パラメータ。開発コードネーム「SAKURA」。100人以上の社内メンバーで正式名を決定 |
| 2024-04 | cotomi Pro / cotomi Light | アーキテクチャ刷新＋学習データ更新。Proは高精度、Lightは高速に特化 |
| 2024-12 | cotomi v2 | 推論精度・速度を両方強化。Japanese MT-BenchでClaude/GPT-4/Qwen水準に到達 |
| 2025-07 | cotomi v3 | Pro/Fastの2モデル構成を一本化。「Fast並みの速度 × Pro並みの性能」。エージェント機能を大幅強化 |
| 2025-08 | cotomi Act | Webブラウザ自動操作エージェント技術。WebArenaベンチマークで人間超え80.4%達成 |
| 2025-12 | cotomi Act ソリューション提供開始 | 暗黙知の自動抽出・組織資産化のソリューションを商用展開 |

### 1.2 技術仕様

**パラメータ数:**
- 初代: **130億（13B）** — GPT-4の約1,750億の13分の1
- 1,000億（100B）クラスの大規模モデルも並行開発中（発表済み、提供時期未定）

**コンテキスト長:**
- v3: **最大128Kトークン**（日本語20万文字超に対応）

**日本語最適化の技術:**
- 大規模日本語辞書（トークナイザ）搭載 — 日本語テキストの効率的なトークン化
- 自己教師あり学習（Self-Supervised Learning）で大量の日本語テキストから自律的にパターン学習
- 業界特有の専門用語の理解に強み

**推論速度（GPT-4比）:**
- cotomi Pro: **GPT-4比5倍以上高速**（GPU2枚の標準サーバで）
- cotomi Light: **GPT-4比15倍以上高速**
- cotomi v2: **GPT-4o比2倍高速**、**Qwen比6倍高速**
- GPU計算効率は従来比2倍に向上

### 1.3 ベンチマーク結果

| ベンチマーク | cotomi の成績 |
|-------------|-------------|
| Japanese MT-Bench | Claude, GPT-4, Qwenに匹敵する精度（v2以降） |
| WebArena | cotomi Act: 80.4%（人間78.2%を上回る世界初の成績） |
| ガバメントAI選定 | デジタル庁「Gennai」プラットフォーム向けにcotomi v3が選定（2026-03） |

**GPT-4との比較まとめ:**
- 日本語処理: cotomiが優位
- 推論速度: cotomiが圧倒的に優位（5〜15倍高速）
- セキュリティ（データ主権）: cotomiが優位（オンプレ対応）
- コスト安定性: cotomiが優位
- 英語処理・複雑な論理推論: GPT-4系が優位
- 汎用的な知識量: GPT-4系が優位

### 1.4 提供形態と価格

**提供形態は3パターン:**

| 形態 | 内容 | 特徴 |
|------|------|------|
| **Managed API** | クラウド型API提供 | 対話機能・検索機能。NECの国産クラウド上で運用 |
| **Appliance Server** | オンプレミス型 | Express5800/R120j-2M for cotomi（GPU1〜2枚構成）。推論モデルと推論+ファインチューニングモデルの2タイプ |
| **さくらのAI Engine** | さくらインターネット経由のAPI | OpenAI API互換。データ処理が国内完結。2025-12よりcotomi v3提供開始 |

**価格:**
- 一般公開の料金表はなし（法人向け個別見積もり）
- cotomi単体での個人利用は不可
- コンサルティングサービスと組み合わせた提供が基本

**オンプレミスの強み:**
- 機密データを外部クラウドに送信しない
- ファインチューニングも自社環境内で実施可能
- 業務特化型モデルの構築が短期間で可能
- GPU2枚の現実的なコストで運用可能

### 1.5 ファインチューニング・業界特化

cotomiの最大の差別化ポイントは **「個社向け・業界特化モデルの構築が低コスト・短期間で可能」** という点。

**対応済み/推進中の業界:**
- 金融（地域金融機関向け共同研究会を運営、20社参加）
- 製造（PLM「Obbligato」への生成AI統合）
- 自治体（北九州市「AI会計室」、ガバメントAI選定）
- 医療
- 法律
- リテール（ローソン映像認識AI実証）

---

## 2. cotomi 導入事例・ユースケース

### 2.1 NEC社内（クライアントゼロ）

NEC Generative AI Service (NGS) として2023年5月から社内展開。

| 指標 | 実績 |
|------|------|
| 利用者数 | 約2.5万人 |
| 日次利用回数 | 約1万回/日 |
| 資料作成時間 | **50%削減** |
| 議事録作成 | 平均30分→**約5分** |
| コンタクトセンターFAQ作成 | 工数**75%削減** |
| オペレータ回答時間 | **35%削減**見込み |
| 脅威インテリジェンス | 検知ルール実装工数**80%削減** |
| レピュテーションリスク分析 | 工数**80%削減** |
| ソースコード作成 | コスト**80%削減** |
| 経営管理リードタイム | **96.7%削減** |

### 2.2 金融業界

- **地域金融機関 生成AI共同研究会**: NEC + 金融機関10社（2024-08設立）→ 20社に拡大
- Azure OpenAI ServiceとcotomiをRAG検証で併用
- 社内規定類の情報検索、バーチャル上長モデル、顧客応対に活用
- 2025年: 「Agentic AI共同研究会」に発展

### 2.3 自治体

- **北九州市**: cotomiベースの「AI会計室」構築。会計事務の規定・マニュアルをRAGで学習
- **デジタル庁 ガバメントAI**: cotomi v3が「Gennai」プラットフォーム向け国内LLMとして選定（2026-03）。約18万人の政府職員への展開用

### 2.4 製造業

- PLM「Obbligato」にcotomiを統合
- 法規制変更への対応、技能伝承の要約
- 匠の熟練技のナレッジ継承支援（RAG活用）

### 2.5 リテール / ローソン関連

**NEC × ローソン 映像認識AI実証（2025-10〜11）:**
- 店舗カメラ映像 → 映像認識AIが作業項目に分類 → **LLMが作業工程・所要時間をテキスト化** → レポート自動作成
- 目標: 店舗作業**30%削減**（2030年目標）
- 実証は埼玉県1店舗で実施

**KDDI × ローソン（並行して進行中）:**
- AI×ロボットによる店舗DX（品出しロボ、在庫解析）
- AIグラスによる業務効率化
- 同じく2030年の作業30%削減が目標

> **注目ポイント**: NEC側の映像認識AI実証でLLMが使われているが、cotomi名義では公表されていない。入社後に「このLLMはcotomiか外部モデルか」を確認すべきポイント。

### 2.6 その他

- ECサイトの商品レビュー分析自動化 → マーケティング戦略の迅速化・リピート率向上
- コールセンター自動応答 → 対応時間短縮・顧客満足度向上
- 大塚商会との協業:「美琴 powered by cotomi」提供開始
- 税番判定支援ツール

---

## 3. NEC Agentic AI 戦略

### 3.1 ロードマップ

| 年度 | フェーズ | 内容 |
|------|---------|------|
| 2024 | Action変革 | 生成AIによる個々のアクション効率化 |
| 2025 | Process変革 | **特化型Agent**（個社データ＋専門Agent）によるプロセス全体の変革 |
| 2026〜 | Business変革 | **マルチAgent連携**による事業レベルの変革 |

### 3.2 NEC AI Agentの仕組み

1. ユーザーが業務リクエストを入力
2. cotomiが**タスクを自律的に分解**
3. 各タスクに**最適なAI/ITサービスを自動選択**
4. **業務プロセスを設計し自動実行**

**特徴:**
- テンプレート型の自動化ではなく「自律的」な判断
- 動的にワークフローを再設計し、反復改善
- 欠けている機能を自己実装する能力
- 2025-01から順次提供（経営計画、HR、マーケティング領域から）

### 3.3 cotomi Act（Web自動操作エージェント）

- **暗黙知の自動抽出**: ブラウザ操作ログから業務ノウハウを自動抽出・組織資産化
- **WebArenaベンチマーク**: タスク成功率**80.4%**（人間78.2%を上回る世界初）
- **対象業務**: 経費精算、受発注、審査業務など判断が必要な業務
- **提供**: 2026-01よりソリューション提供開始

### 3.4 営業支援ソリューション（NEC Document Automation）

- Agentic AI活用の営業支援「NEC Document Automation - for Proposals」
- 議事録・標準提案書から**提案書とディスカッションシートを自動生成**
- NEC欧州研究所のAIオーケストレーション技術が中核
- 2025-11にクライアントゼロ（社内利用）開始 → 2026-03下旬にBluStellar経由で外販

### 3.5 15業務領域への展開

NECはAgentic AIを**15業務領域**に展開予定:
- セキュリティ運用
- 経営計画
- HR（人材管理）
- マーケティング戦略
- 営業支援
- コンタクトセンター
- その他（詳細は順次公開）

### 3.6 MCP（Model Context Protocol）準拠

- cotomiがMCP準拠に対応（2025年発表）
- **Boxとのパートナーシップ**: 国内ISVとして初のベータプログラム参加
- 企業サービスとの連携を容易化

### 3.7 NECネッツエスアイ: AI Agent Readyプロジェクト

- AIエージェントの安全・安心な運用のためのインフラ設計と構築を提供
- AIエージェント導入の障害解決を目指す

---

## 4. 外部LLM vs cotomi の使い分け

### 4.1 NECの公式スタンス: 「cotomi first」ではない

NEC山田氏（cotomi責任者）の発言:
> 「AIを売っているのではなく、**DXを売っている**」

→ cotomiが最適でない場面では**他のAIを採用する方針**。社内でも複数のLLM活用を推進。

### 4.2 実際の使い分けパターン

| ユースケース | 推奨LLM | 理由 |
|-------------|---------|------|
| 日本語業務（社内RAG、規定検索等） | cotomi | 日本語精度＋速度＋データ主権 |
| 英語中心の業務、複雑な論理推論 | GPT-4/Claude | 英語性能・汎用知識量で優位 |
| Microsoft 365連携 | Azure OpenAI (Copilot) | MS製品との統合 |
| 機密性の高いデータ処理 | cotomi (オンプレ) | データが外に出ない |
| 業界特化のファインチューニング | cotomi | 低コスト・短期間でカスタマイズ可能 |
| Webブラウザ業務の自動化 | cotomi Act | WebArenaで人間超え |

### 4.3 金融機関での実例

地域金融機関 生成AI共同研究会では、**Azure OpenAI Service と cotomi を両方使った**RAG検証を実施。どちらかに統一するのではなく、ユースケースに応じて使い分ける方針。

### 4.4 Microsoft パートナーシップ

- NECはMicrosoftと40年以上の戦略的パートナーシップ
- Azure を Preferred Cloud Platform として採用
- 社内コミュニケーションは **Microsoft Teams**
- **NEC Generative AI Service (NGS)** は Azure OpenAI Service（GPT-3.5, GPT-4）とcotomiの両方を採用
- つまり: **cotomiとAzure OpenAIは共存モデル**

### 4.5 NVIDIAとの協業

- NVIDIAとの協業で推論速度が**最大2倍向上**
- GPU最適化でcotomiの実行環境を強化

---

## 5. NEC AI開発ツール・プラットフォーム

### 5.1 NEC Generative AI Service (NGS)

- 2023-05から社内展開
- **LLM選択**: Azure OpenAI Service (GPT-3.5/4) + cotomi
- **RAG**: LlamaIndex採用。Office文書・PDFを登録して活用
- **「Myデータサービス」**: 社内情報をRAGで活用する機能
- 利用者2.5万人、1日1万回の利用

### 5.2 cotomi Appliance Server

- Express5800/R120j-2M for cotomi
- GPU1〜2枚構成でオンプレミス運用
- **推論モデル**と**推論+ファインチューニングモデル**の2タイプ
- システム構成ガイドがNEC公式で公開（PDF）

### 5.3 さくらのAI Engine

- さくらインターネットとの協業
- **OpenAI API互換**のAPIサービス
- データ処理が日本国内で完結
- ベクターDB（RAG用）も提供
- 2025-12よりcotomi v3の提供開始

### 5.4 NEC AI Agent プラットフォーム

- cotomiをベースにした自律型AIエージェント
- タスク分解 → AI/ITサービス選択 → 自動実行
- チャート/図表の理解技術も搭載
- MCP準拠で外部サービス連携

### 5.5 NEC Generative AI変革オフィス

- 2023-05設立。CIO/CISO直下のバーチャル組織
- 部門横断で生産性向上を推進
- 生成AIの社内活用ルール策定・推進

### 5.6 スキルとの接点

| NEC側の技術 | 活かし方 |
|-------------|---------|
| RAG（LlamaIndex） | 社内RAGの改善提案・実装支援ができる |
| OpenAI API互換（さくらAI Engine） | cotomi APIの活用・PoC開発が即座にできる |
| Python基盤の開発 | AIサービスのバックエンド開発に直結 |
| MCP準拠 | MCPベースのAgent連携に知見がある |
| Webエージェント（cotomi Act） | リテール業務の自動化提案に活用可能 |

---

## 6. 入社後のポジショニング戦略

### cotomi × ローソンで打てる手

1. **映像認識AI実証のフォローアップ**: 2025-10の実証結果を踏まえた次フェーズ（2026年中）で、LLM側の改善提案ができるポジション
2. **店舗業務のRAG化**: ローソンのマニュアル・規定をcotomiでRAG化 → 店長・SVの問い合わせ対応を自動化する提案
3. **cotomi Actの店舗業務適用**: 発注業務や本部報告などのWebブラウザ操作をcotomi Actで自動化する提案

### 入社前に頭に入れておくべきキーワード

- BluStellar / BluStellar 2 / BluStellar Scenario
- cotomi v3 / cotomi Act / MCP準拠
- Agentic AI / 特化型Agent → マルチAgent連携
- NEC Generative AI Service (NGS) / クライアントゼロ
- Express5800/R120j-2M for cotomi（オンプレ）
- NEC Document Automation
- ガバメントAI「Gennai」

---

## Sources

### cotomi技術
- [NEC公式 cotomiページ](https://jpn.nec.com/LLM/cotomi.html)
- [cotomi Pro/Light 開発プレスリリース (2024-04)](https://jpn.nec.com/press/202404/20240424_01.html)
- [cotomi v2 性能強化プレスリリース (2024-11)](https://jpn.nec.com/press/202411/20241127_02.html)
- [cotomi v3 エージェント性能強化 (Cloud Watch)](https://cloud.watch.impress.co.jp/docs/news/2029970.html)
- [cotomi v3 ガバメントAI選定 (2026-03)](https://jpn.nec.com/press/202603/20260309_03.html)
- [cotomi Wikipedia](https://ja.wikipedia.org/wiki/Cotomi)
- [cotomi技術解説 (debono)](https://debono.jp/7148)
- [cotomi vs GPT-4 差別化 (SBbit)](https://www.sbbit.jp/article/cont1/140881)
- [cotomi v3 ガバメントAI分析 (Innovatopia)](https://innovatopia.jp/ai/ai-news/82524/)
- [NEC LLM開発技術](https://jpn.nec.com/rd/technologies/202308/index.html)

### cotomi Act / AIエージェント
- [cotomi Act 開発プレスリリース (2025-08)](https://jpn.nec.com/press/202508/20250827_02.html)
- [cotomi Act ソリューション提供開始 (2025-12)](https://jpn.nec.com/press/202512/20251203_01.html)
- [NEC AI Agent プレスリリース (2024-11)](https://jpn.nec.com/press/202411/20241127_01.html)
- [NEC AI Agent ページ](https://jpn.nec.com/LLM/AIagent.html)
- [cotomi Act WebArena分析 (Ledge.ai)](https://ledge.ai/articles/nec_cotomi_act_web_agent_implicit_knowledge)

### Agentic AI / BluStellar
- [NEC AI・DX戦略 2026展望](https://wa2.ai/ai-news/nec-ai-dx-blustellar-2026-trend)
- [NEC IR Day 2025 BluStellar (Cloud Watch)](https://cloud.watch.impress.co.jp/docs/column/ohkawara/2063931.html)
- [BluStellar DX事業強化 (2025-05)](https://jpn.nec.com/press/202505/20250530_01.html)
- [BluStellar エージェント型AI (EnterpriseZine)](https://enterprisezine.jp/news/detail/22081)
- [Agentic AI 営業支援 (2025-11)](https://jpn.nec.com/press/202511/20251127_01.html)
- [NECソリューションイノベータ 2026年頭所感](https://www.nec-solutioninnovators.co.jp/company/blog/2026/01/index.html)

### 外部LLM共存 / Microsoft
- [NEC × Microsoft 戦略的パートナーシップ (2021)](https://news.microsoft.com/ja-jp/2021/07/13/210713-microsoft-and-nec-expand-strategic-partnership/)
- [地域金融機関 生成AI共同研究会 (2024-08)](https://jpn.nec.com/press/202408/20240816_01.html)
- [Agentic AI共同研究会 (PrTimes)](https://prtimes.jp/main/html/rd/p/000001014.000078149.html)

### プラットフォーム / RAG
- [NEC Generative AI Service (NGS) 技術論文](https://jpn.nec.com/techrep/journal/g23/n02/230208.html)
- [NGS 社内活用事例](https://jpn.nec.com/LLM/Inhouse_case1.html)
- [クライアントゼロの挑戦 (DIG UP! NEC)](https://web.nec-careers.com/digup/article/5310/)
- [NEC Generative AI Service ラインナップ拡充 (2024-04)](https://jpn.nec.com/press/202404/20240424_02.html)
- [さくらのAI Engine cotomi v3提供開始 (2025-12)](https://www.sakura.ad.jp/corporate/information/announcements/2025/12/02/1968222225/)
- [cotomi Appliance Server](https://jpn.nec.com/gpu/cotomi/index.html)

### ローソン関連
- [NEC × ローソン 映像認識AI実証 (2025-10)](https://jpn.nec.com/press/202510/20251030_02.html)
- [ローソン店舗AI・ロボット導入 (日経)](https://www.nikkei.com/article/DGXZQOUC133K80T10C26A2000000/)
- [KDDI × ローソン AI×ロボット店舗DX](https://newsroom.kddi.com/news/detail/kddi_nr-796_4174.html)
