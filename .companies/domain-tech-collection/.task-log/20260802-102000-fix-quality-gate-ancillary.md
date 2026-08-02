---
task_id: "20260802-102000-fix-quality-gate-ancillary"
org: "domain-tech-collection"
operator: "SAS-Sasao"
status: completed
mode: "direct"
started: "2026-08-02T10:20:00"
completed: "2026-08-02T10:26:00"
request: "（/company-cycle で発見した品質ゲート誤検知）修正して。クローズもして"
issue_number: 719
pr_number: null
subagents: []
l0_gate: null
l0_retries: 0
l1_gate: null
l1_retries: 0
l2_composite: null
l2_retries: 0
---

## 背景

`/company-spawn` で作成した `retail-stats-tracker` の `docs/design/origin.md` に対し、
品質ゲートが設計書チェックリストを適用して Fail 判定を出した（Issue #719）。

`origin.md` はトレーサビリティ文書（出自・コピー元との対応表・未決事項の引き継ぎ）であり
設計書ではないため、「システム構成図」「データフロー」「エラー処理方針」等を求めるのは誤り。

## 原因

`.claude/hooks/quality-gate.sh` の by-type 判定が**パスに `design` を含むだけで設計書と判定**していた。

```bash
elif [[ "$FILE_PATH" == */design* ]] || [[ "$FILE_PATH" == */architecture* ]]; then
```

`/company-spawn` は設計書を `docs/design/` に配置する標準フローなので、
同ディレクトリに置かれる README・index・origin 等の付随文書がすべて誤検知対象になる。
**スポーンのたびに再発する構造的な問題**だった。

## 修正内容

by-type 判定の前に付随文書の除外を追加。`_default.md`（汎用チェックリスト）は引き続き適用する。

```bash
IS_ANCILLARY=false
case "$(basename "$FILE_PATH")" in
  origin.md|README.md|readme.md|index.md|INDEX.md|CHANGELOG.md|LICENSE.md|CONTRIBUTING.md|MEMORY.md)
    IS_ANCILLARY=true
    ;;
esac

if [[ "$IS_ANCILLARY" == false ]]; then
  # 既存の by-type 判定
fi
```

## 検証

| ファイル | 付随判定 | by-type 適用 | 期待 |
|---|---|---|---|
| `docs/design/origin.md` | true | なし | ✅ 誤検知が解消 |
| `docs/design/README.md` | true | なし | ✅ |
| `docs/design/implementation-design.md` | false | `design.md` | ✅ 設計書は引き続き検査される |

`bash -n` による構文チェックも pass。

## 検証中に発見した別の問題（本 PR では未対応）

**ファイル名に種別語を含む文書は by-type が適用されていない。**

判定パターン `*/requirements*` は「`/` の直後に `requirements` が来る」ことを要求するため、
`docs/research/retail-stats-tracker-requirements.md` のように
**ファイル名の途中に種別語がある場合はマッチしない**。

つまり cc-sier 側の要件定義書は、これまで by-type チェックリストで検査されていなかった。

対応を見送った理由: パターンを `*requirements*` に緩めると、
**これまで検査対象外だった多数の既存ファイルが一斉に検査対象になり、大量の誤検知 Issue が起票されうる**。
影響範囲の見積もりが必要で、誤検知の解消とは別タスクとして扱うべきと判断した。

## reward
（post-merge hook が自動追記）
