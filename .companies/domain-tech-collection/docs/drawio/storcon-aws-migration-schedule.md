---
diagram_id: storcon-aws-migration-schedule
title: ストコンAWS移行 統合スケジュール（ガントチャート）
type: 業務フロー
project: ストコンAWS移行
created: 2026-04-18
author: SAS-Sasao
source_tool: drawio-mcp-server (open_drawio_xml)
html_path: docs/drawio/storcon-aws-migration-schedule.html
drawio_path: docs/drawio/storcon-aws-migration-schedule.drawio
related_notes:
  - wbs-4-1-1-migration-pm-overview
  - wbs-5-2-aws-migration-best-practices
  - wbs-4-2-1-retail-pm-wave-rollout
---

# ストコンAWS移行 統合スケジュール — 生成メタデータ

## 作図意図

WBS 4.2.1 ノート生成後の壁打ちで、既存3本のノートが語っていた移行期間感（MAP 3 フェーズ / ロールアウト 3 フェーズ / wave 7 段階）が **別々の時間軸で書かれていて整合が取れていない** ことが判明した。

- 5-2 ノート: 「M1-6 パイロット」 → Mobilize と Pilot が混ざっていた
- 4-1-1 ノート: 「参画直後キャッチアップ」 → 個人活動として書かれていたが、実態は Assess フェーズの PM 稼働
- 4-2-1 ノート: wave 7 段階 27-28 ヶ月 → 5-2 の 30 ヶ月 と齟齬

これらを 1 本の時間軸（2026/06-2029/03）に統合し、PM 参画月から完了までの見取り図として可視化する。

## データモデル

- 横軸: 月単位（34 ヶ月、1 月 40px）
- 縦軸: 11 フェーズ・wave ロー
- 色: フェーズ種別（Assess/Mobilize/Pilot/Wave/Hypercare）
- 凍結期間オーバーレイ:
  - 年末年始（赤、opacity 55）: 2026/12-2027/01、2027/12-2028/01、2028/12-2029/01
  - 軽凍結（黄、opacity 40）: 2月決算、5月GW、8月お盆

## 参考

- [WBS 4-1-1 大規模移行PMの全体像](../secretary/learning-notes/wbs-4-1-1-migration-pm-overview.md)
- [WBS 5-2 AWS移行ベストプラクティス](../secretary/learning-notes/wbs-5-2-aws-migration-best-practices.md)
- [WBS 4-2-1 コンビニ/小売業界PM特有事項](../secretary/learning-notes/wbs-4-2-1-retail-pm-wave-rollout.md)

## 使い方

1. PM 参画（2026/06）後の Assess フェーズで 6R 判定比率・1 wave あたり店舗数・凍結期間の厳格度を実測
2. 本図を基に wave 設計を具体化し、実プロジェクトの WBS（PMOマスタースケジュール）に展開
3. 凍結期間と重なる wave（wave 3, 6, 7）は安定化期間を延長し、リスクバッファを明示する
