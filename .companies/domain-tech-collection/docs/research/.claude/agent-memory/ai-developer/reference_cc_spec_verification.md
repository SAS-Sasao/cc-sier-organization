---
name: cc-spec-verification
description: Claude Code 仕様の一次情報は code.claude.com/docs/en/{page}.md（末尾 .md で素の Markdown が返る）。scratchpad の cc-spec-reference.md には実証済みの誤りが 4 件ある
metadata:
  type: reference
---

Claude Code の hooks / skills / subagents 仕様を確認するときは、`https://code.claude.com/docs/en/hooks.md`・`sub-agents.md`・`skills.md` のように **URL 末尾に `.md` を付けて curl する**と、素の Markdown が 200 で返る（hooks 約 3,200 行 / sub-agents 約 1,250 行）。HTML を取ると Next.js のスクリプトタグだらけで読めない。

中間生成物の仕様サマリ（例: scratchpad の `cc-spec-reference.md`）には**実証済みの誤りが 4 件**ある。2026-08-01 に公式ドキュメントと照合して確認:

1. **§1.1 が `Stop` を `Blockable = No` としているのは誤り。** 公式 "Exit code 2 behavior per event" は `Stop` = Yes（"Prevents Claude from stopping"）。同リファレンス §1.4 が正しい
2. **§1.3 の stdin フィールド一覧が不完全。** `stop_hook_active` は Stop / SubagentStop の入力として実在する。「リファレンスに無い＝存在しない」と結論してはいけない
3. **§1.7 の "run sequentially (not parallel)" は逆。** 公式 "Hook handler fields" は `All matching hooks run in parallel, and identical handlers are deduplicated automatically`。同一イベントの hook は**並列**に走る
4. **§2.1 の Subagent フロントマターに `when_to_use` が載っているのは誤り。** 公式 "Supported frontmatter fields" は 16 種（name / description / tools / disallowedTools / model / permissionMode / maxTurns / skills / mcpServers / hooks / memory / background / effort / isolation / color / initialPrompt）で `when_to_use` は無い。**Skill のフロントマターには実在する**ので取り違えやすい

その他、公式にあってリファレンスに無い重要事項: Stop は **8 回連続ブロックで Claude Code がターンを強制終了**する。`Stop` / `UserPromptSubmit` / `PostToolBatch` 等は **matcher 非対応で、書いても silently ignored**。

**How to apply:** 3 は設計に実害が出る（同一イベントに破壊的な検査 hook と読み取り hook を同居させると、後者が中間状態を読む）。hook 設計では「同一イベント配下は全て読み取り専用」を不変条件に置き、破壊的検査は Skill / CI など逐次性が保証された契機へ移す。仕様がサマリ文書由来のときは必ず `.md` エンドポイントで裏を取り、根拠として設計書に引用する。関連: [[loop-design-nfr05-denominator]]
