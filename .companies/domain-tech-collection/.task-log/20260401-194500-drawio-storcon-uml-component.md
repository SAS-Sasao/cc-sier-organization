---
task_id: "20260401-194500-drawio-storcon-uml-component"
org: "domain-tech-collection"
operator: "SAS-Sasao"
status: completed
mode: direct
subagent: secretary
started: "2026-04-01T09:45:28Z"
completed: "2026-04-01T10:10:00Z"
request: "AWS構成図をクラウドベンダー非依存のUML方式で作成。DB/人/バッチ/プログラムに適切な図形を使用"
issue_number: null
pr_number: null
reward: null
---

## 実行サマリー

AWS版storcon-vpc-architectureをベンダー非依存のUMLコンポーネント図として再設計。
draw.io XMLで適切なUML図形を使用（アクター、矩形、シリンダー、ドキュメント型）。

## 実行計画

- 描画対象: ストコン移行の論理アーキテクチャ（ベンダー非依存）
- ツール: open_drawio_xml（精密なレイアウト制御が必要なため）
- UML図形: umlActor（人）、rectangle（サービス/バッチ）、cylinder3（DB）、document（ストレージ）
- エッジ貫通レビュー: 3回の修正を経てPass

## 成果物

- `docs/drawio/storcon-uml-component.drawio` — draw.io XMLソース
- `docs/drawio/storcon-uml-component.html` — 詳細ページ（学習ポイント5項目付き）
- `docs/drawio/index.html` — 一覧更新（11件目）
- `.companies/domain-tech-collection/docs/drawio/storcon-uml-component.md` — ソースメタデータ

## judge

### completeness: 5/5
- AWS版の全コンポーネントをベンダー非依存に抽象化
- UML標準の図形を適切に使い分け（アクター、矩形、シリンダー、ドキュメント）
- AWS版との対応表をソースメタデータに記載
- 学習ポイント5項目を付与

### accuracy: 5/5
- AWS版構成図との論理的対応が正確
- 4層アーキテクチャ（Edge/Network/App/Data）の分離が適切
- エッジ貫通レビュー Pass（0件）

### clarity: 5/5
- 色分けによるコンポーネント種別の視認性
- 凡例でエッジ色と用途を明示
- 学習ポイントで「論理設計 vs 物理設計」「Polyglot Persistence」等の概念を解説
