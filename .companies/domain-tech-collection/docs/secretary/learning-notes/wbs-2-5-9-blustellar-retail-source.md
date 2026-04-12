# BluStellar リテール向けシナリオ/オファリング Deep Dive

調査日: 2026-04-10
ソース: ai-war-room 壁打ちセッション + ウェブ調査
関連: [NEC中期経営計画調査](nec-midterm-plan-research-2026-04-09.md) / [cotomi & Agentic AI](cotomi-agentic-ai-deep-dive-2026-04-10.md) / [財務ブレイクダウン](nec-midterm-plan-financial-breakdown-2026-04-10.md)

---

## 1. BluStellarの3層構造

| 層 | 規模 | 内容 | たとえ |
|---|---|---|---|
| **BluStellar Products & Services** | 約500種 | 単体プロダクト（POS、顔認証、AI分析など） | 「部品」 |
| **BluStellar Offerings** | 約150セット | 顧客ニーズに合わせてパッケージ化 | 「セット商品」 |
| **BluStellar Scenario** | 約32セット | 経営課題軸で束ねて「型化」 | 「提案の型」 |

CDO吉崎氏: *「オファリングをシナリオに集約した。価値はNECが決めるのではなく、顧客が決める」*

**重要な数字**: シナリオ/オファリングの売上構成比を **33%（現在）→ 63%（次期中計目標）** に引き上げる方針。シナリオ型はベース事業より **利益率が3〜5%高い**（IR Day Q&Aで開示）。つまり、BluStellar語で提案できることが社内評価に直結する。

---

## 2. 5つの経営アジェンダと8つのシナリオグループ

### 経営アジェンダ

1. **社会とビジネスのイノベーション** (Social & Business Innovation)
2. **顧客体験変革** (Customer Experience)
3. **業種変革** (Industry Transformation)
4. **組織・人材変革** (Organization & Talent)
5. **デジタルプラットフォーム変革** (Digital Platform)

### 8つのシナリオグループ

| # | シナリオグループ名 | 確認できた具体シナリオ例 | リテールとの関連度 |
|---|---|---|---|
| 1 | Social Business Innovation | データドリブン経営 | **高** — 個店データ活用 |
| 2 | Customer eXperience | 顧客理解の高度化による新たなカスタマーサービス体験創出と収益拡大 | **最高** — OMO・顧客体験 |
| 3 | Process Innovation | コンタクトセンター業務高度化から始まる顧客体験価値向上 | 中 — 本部業務 |
| 4 | モダナイゼーション系 | 業務システム/IT基盤の最適で安全安心なモダナイゼーション | **高** — 基幹刷新 |
| 5 | IT運用系 | ハイブリッドIT環境の運用DXによる業務プロセスの改善 | 中 — 運用効率化 |
| 6 | セキュリティ系 | 事業成長を支え続けるセキュリティ経営改革 | 低〜中 |
| 7 | AI系 | AI、生成AIを活用して高度化する経営課題を解決 | **最高** — 映像AI・発注AI |
| 8 | ネットワーク系 | DX活用に適したネットワーク&セキュリティ環境の提供 | 低 |

### シナリオの内訳

- **業種共通**: 16セット（モダナイゼーション、IT運用DX、セキュリティ、CX改革など）
- **業種別**: 14セット（金融、製造、**流通**、航空宇宙、通信、官公庁、医療、大学、警察など）

→ リテール配属者として最も関連するのは **#2 CX** と **#7 AI** の業種別シナリオ。

---

## 3. NEC リテールDXの全体コンセプト: "Smart Retail CX"

NECは流通・小売向けDXを **"Smart Retail CX"** として体系化。3つの柱がある:

| 柱 | 内容 | 具体的なソリューション |
|---|---|---|
| **作業負荷 50% 削減** | 映像AI・自動発注・棚管理の効率化 | 映像認識AI+LLM、棚定点観測 |
| **買い物の魅力 2倍** | OMO、レジレス、没入型購買体験 | Bio-IDiom顔認証決済、NeoSarf/POS |
| **不正・現金ゼロ** | 顔認証決済、キャッシュレス化 | Bio-IDiom、デジタルストアプラットフォーム |

---

## 4. 主要ソリューションのBluStellarマッピング

| ソリューション | 概要 | BluStellar層 | マッピング先 |
|---|---|---|---|
| **NeoSarf/POS** | 有人/フルセルフ/セミセルフ対応POS。ハードウェアフリー設計で汎用端末対応。顔認証連携可能 | Products & Services | 業種別(流通) |
| **storeGATE2** | クラウド型店舗本部システム（月額制、アセット削減） | Products & Services | モダナイゼーション / 業種別 |
| **storeGATE/L** | 専門小売業向け本部&店舗クラウド（販売・仕入・在庫・発注を一体化） | Products & Services | 業種別(流通) |
| **NEC 映像分析基盤 (EVA)** | カメラ入力・映像処理の共通基盤 + 複数分析ユニットを柔軟に組合せ | Products & Services | AI系 / CX |
| **人物行動分析サービス** | EVA上で動作。映像から複数人のマルチタスク行動認識・群衆行動分析 | Products & Services | AI系 / 業種別 |
| **Bio-IDiom / 顔認証決済** | NIST世界1位の顔認証。大阪・関西万博でも多数店舗採用 | Products & Services | CX / 業種別 |
| **NEC 棚定点観測サービス** | 固定カメラ映像からAIが棚の陳列状況を可視化。イオンリテール、東急ストアが先行採用 | Products & Services → Offerings | 業種別(流通) |
| **Digital Store Platform** | Smart Retail CXの情報システム基盤。データ透明性、リアルタイム対応 | Offerings | 業種別(流通) |
| **映像認識AI + LLM**（ローソン実証） | 従業員の作業映像をAI分類 → LLMがレポート自動作成 | Products & Services(先端) | AI系 / 業種別 |

**重要ポイント**: ローソン案件で使われている映像認識AI + LLMは、BluStellarの **AI系シナリオ × 業種別(流通)シナリオの交差点** に位置する。

---

## 5. BluStellar リテール事例

### 事例A: セブン-イレブン 次世代店舗システム（最重要・最大規模）

- **規模**: 全国21,000店舗、約30万台のモバイル端末/タブレット、約40万人の従業員
- **推定規模**: 500億円・3,000人体制
- **技術**: 国内コンビニ初のフルクラウド型業務システム（Google Cloud基盤）+ マイクロサービスアーキテクチャ + NEC顔認証 + ServiceNow ITSM + Omnissa Workspace ONE
- **BluStellar連携**: 公式に「BluStellarのアプローチに基づき、構想立案から運用までサポート」と明記
- **意義**: シナリオチェーン型（コンサル→構築→運用の一気通貫）の最大成功事例

### 事例B: ローソン × NEC 映像認識AI実証（配属先直結）

- **時期**: 2025年10月、埼玉県1店舗
- **仕組み**: 店舗カメラ → 映像認識AIが作業分類 → LLMがテキスト化 → レポート自動作成
- **目標**: 店舗作業**30%削減**（2030年目標）
- **次フェーズ**: 2026年度（入社時期）に本格展開の可能性高い

### 事例C: ダイアナ（女性靴ブランド）— CXシナリオの適用例

- **課題**: 売上停滞、リピート購入顧客の減少
- **施策**: BluStellar ScenarioによるOMO戦略。LINE・EC・実店舗の顧客データ統合 → PDCAサイクル構築
- **目標**: 2回目購入率の10%向上
- **意義**: リテール業種別CXシナリオの公開事例。ローソンのPontaデータ活用にも応用可能なパターン

### その他

- ローソン × ターゲティング広告AI: 商品購入率**約12倍**に向上
- コーナン全国420店舗: NeoSarf/POS導入（3,400台）
- その他: コジマ、大丸松坂屋百貨店、小田急電鉄、イオンリテール、東急ストアなど

---

## 6. BluStellar 2（2026年度〜）の進化

| 項目 | BluStellar 1（現行） | BluStellar 2（2026年度〜） |
|---|---|---|
| AI基盤 | 生成AI（cotomi） | **Agentic AI**（自律型エージェント） |
| シナリオ数 | 30 → 32 | 順次拡充、業種別を深化 |
| データ活用 | 業種共通のソリューション | **個社データ + 特化型Agent** |
| グローバル | 国内中心 | 「BluStellar Global」フル展開 |
| グループ展開 | NEC本体 | NESIC/ネクサ/フィールディングに展開開始 |

### Agentic AIの3段階進化

- **2024年**: Action変革（個々のタスク効率化）
- **2025年**: Process変革（特化型Agentによるプロセス全体の変革）
- **2026年〜**: **Business変革**（マルチAgent連携による事業変革）← **入社タイミングがここ**

→ 詳細は [cotomi & Agentic AI Deep Dive](cotomi-agentic-ai-deep-dive-2026-04-10.md) 参照

---

## 7. 提案のフレーミング — BluStellarで案件を語る方法

### 提案の流れ

```
1. 経営課題の特定（コンサルティング起点）
   ↓
2. 該当するBluStellar Scenario の選択（32シナリオから）
   ↓  
3. シナリオ内のオファリング組み合わせ（150セットから最適化）
   ↓
4. 必要なProducts & Services の選定（500+商材から）
   ↓
5. 構築・運用・保守（End to End）
```

### 3つの提案拡大パターン

| パターン | 説明 | ローソンでの具体例 |
|---|---|---|
| **シナリオチェーン** | コンサル→構築→運用を一気通貫 | 映像AI分析コンサル → システム構築 → 運用保守契約 |
| **シナリオ横展開** | 成功した型を別クライアントへ | セブン案件の知見 → ローソンへ横展開 |
| **シナリオ発展** | 1つの施策から隣接テーマへ | 映像AI作業分析 → 客動線分析 → 棚割り最適化 → OMO |

### 自社プロダクト比率の強化方針

現在BluStellarの約40%がサードパーティ製品。次期中計で **NEC自社プロダクト比率を引き上げる** 方針。

→ 提案書でNEC製品（NeoSarf、顔認証、cotomi、EVAなど）を組み込むインセンティブが強まる。

---

## 8. クライアントゼロ（Client Zero）の具体事例

自社を「ゼロ番目のクライアント」として先端技術を導入し、成功も失敗もデータ化して顧客に還元するアプローチ。

| 事例 | 内容 | 効果 |
|---|---|---|
| 経営コックピット | ファイナンス・SCM・セキュリティ等の全情報を集約 | リードタイム **96.7%削減** |
| IT運用DX | 約1,000システムを一元管理 | 問い合わせ **26%減**、解決時間 **57%短縮** |
| NECプラットフォームズ（製造・SCM） | Industrial IoT Platform を国内4拠点に導入 | 初年度 **2%損益改善**、2034年まで **420% ROI** |
| 食品・飲料マーケティング | AIでコピー＆動画コンテンツ生成 | 動画視聴数 **125%増** |

---

## 9. 実践的インプリケーション

### 映像認識AI弾込めとの接続

[映像認識AI × 売上向上 弾込めリサーチ](video-ai-sales-uplift-ammo-2026-04-09.md) で策定した3層提案をBluStellar語に翻訳すると:

| 弾込めの提案 | BluStellar語での翻訳 |
|---|---|
| Layer 1: 客動線ヒートマップ | **AI系シナリオ** × **CXシナリオ** のオファリング。Products: EVA + 人物行動分析サービス |
| Layer 2: 個店別ゴールデンゾーン × 棚割り | **業種別(流通)シナリオ** のオファリング。Products: EVA + 人物行動分析 + 棚定点観測 |
| Layer 3: データドリブン店舗レイアウト | **シナリオ発展型** の大型提案。CXシナリオ + AI系シナリオの複合。KDDI顧客データ基盤との連携 |

### BluStellar語の翻訳フレーズ

| こう言いたい時 | BluStellar語 |
|---|---|
| 「映像AIで店舗業務を効率化したい」 | 「AI系シナリオで、EVAと映像認識AIのオファリングを組み合わせた店舗作業DXの提案」 |
| 「顧客の動線を分析して売上を上げたい」 | 「CXシナリオで、人物行動分析とヒートマップのオファリングによる顧客体験変革」 |
| 「セブンでやったことをローソンでもやりたい」 | 「セブン案件のシナリオ横展開。ローソン固有の経営課題に合わせたシナリオカスタマイズ」 |
| 「小さく始めて大きく育てたい」 | 「シナリオ発展型のアプローチ。Layer 1で実績を作り、隣接シナリオへ拡張」 |

### セブン案件との関係性

セブン次世代店舗システムはBluStellarリテールシナリオの**最大の成功事例**。ローソン向け提案の「型」の基盤になるが、**そのまま横展開ではなくローソン固有の経営課題に合わせたシナリオ化**が求められる。

ローソン固有の要素:
- KDDI連携によるPonta経済圏の顧客データ基盤
- AI.CO（次世代発注システム）が既に全店導入済み
- カンパニー制による地域別意思決定体制
- 店舗運営支援AI（天井カメラ8〜12台）が既に稼働

---

## Sources

### BluStellar体系
- [BluStellar Scenario公式ページ](https://jpn.nec.com/dx/scenario/index.html)
- [IR Day 2025 BluStellar戦略PDF](https://jpn.nec.com/ir/pdf/library/251113/blustellar_scenario.pdf)
- [クラウドWatch: BluStellarシナリオ軸へシフト](https://cloud.watch.impress.co.jp/docs/news/1666872.html)
- [日経特集: 8つのシナリオグループ](https://ps.nikkei.com/nec2405/vol4.html)
- [クラウドWatch: IR Day 2025](https://cloud.watch.impress.co.jp/docs/column/ohkawara/2063931.html)
- [BluStellarとは 公式](https://jpn.nec.com/dx/BluStellar_concept/index.html)

### リテールDX
- [NEC リテールDX(Smart Retail CX)公式](https://jpn.nec.com/retail/index.html)
- [NeoSarf/POS 公式](https://jpn.nec.com/neosarf/pos/index.html)
- [storeGATE/L](https://www.nec-nexs.com/sl/retail/storegate_l.html)
- [NEC 映像分析基盤 EVA](https://jpn.nec.com/video-analytics/eva/index.html)
- [NEC 棚定点観測サービス](https://jpn.nec.com/press/202403/20240311_02.html)
- [Smart Retail CX フューチャーストア白書](https://jpn.nec.com/nvci/retail/trendwp/index.html)
- [Digital Store Platform 技術論文](https://jpn.nec.com/techrep/journal/g20/n01/200117.html)

### 事例
- [セブン-イレブン次世代店舗システム](https://jpn.nec.com/press/202505/20250522_01.html)
- [ローソン×NEC 映像認識AI実証](https://jpn.nec.com/press/202510/20251030_02.html)
- [BluStellar Scenario事例(ダイアナ含む)](https://cloud.watch.impress.co.jp/docs/news/2087118.html)
- [NEC 流通DX事例一覧](https://jpn.nec.com/retail/work/index.html)

### BluStellar戦略・拡大
- [BluStellar DXブランド・成功事例共有](https://cloud.watch.impress.co.jp/docs/news/1611440.html)
- [BluStellar SIer→Value Driver加速](https://cloud.watch.impress.co.jp/docs/news/2087118.html)
- [週刊BCN+ BluStellar 1兆円事業](https://www.weeklybcn.com/journal/news/detail/20250605_210243.html)
- [BluStellar DX事業強化](https://bizzine.jp/article/detail/11627)

### クライアントゼロ
- [NECのCIOが語るクライアントゼロ企業変革](https://www.cio.com/article/4037782/)
- [クライアントゼロ 公式ページ](https://jpn.nec.com/dx/internaldx/index.html)
- [クライアントゼロ運用DXナレッジ](https://wisdom.nec.com/ja/feature/dxmanagement/2025082702/index.html)
- [NECプラットフォームズ IoT導入事例](https://jpn.nec.com/manufacture/monozukuri/iot/case/necplatforms/index.html)
