---
name: マルチ組織対応リファクタリング
description: 全18 Subagentファイルへのマルチ組織対応（.company/ → .companies/{org-slug}/）適用と、Gitワークフロー統合の追加
type: project
---

全18ファイル（secretary.md + 17 Subagent）をマルチ組織対応に改修済み（2026-03-19）。

**Why:** プラグインに「マルチ組織対応」「成果物格納ルール統一」「Gitワークフロー統合」の3機能を追加するため。

**How to apply:**
- パス規則は `.companies/{org-slug}/` 配下に統一。旧 `.company/` は廃止済み
- secretary.md に Gitワークフロー（ブランチ→作業→コミット→PR）セクションが追加されており、壁打ち・ダッシュボード・質問応答はGit不要と明記
- 全17 Subagentの末尾に「成果物格納ルール」セクションが追加済み
- secretary.md の起動時動作は `.companies/.active` ファイルから org-slug を読み取る方式に変更
