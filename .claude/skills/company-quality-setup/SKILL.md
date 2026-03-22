---
name: company-quality-setup
description: >
  アクティブな組織に品質チェックリスト（masters/quality-gates/）を配置する。
  「品質ゲートを設定して」「チェックリストをセットアップ」「/company-quality-setup」
  と言われたときに使用する。
  既にファイルが存在する場合は上書き確認を行う。
---

# 品質ゲートセットアップ Skill

## 1. 起動時の確認

1. `.companies/.active` から org-slug を取得する
2. テンプレートのパスを確認する
   - `TEMPLATE_DIR=".claude/skills/company-quality-setup/templates"`
3. 配置先のパスを決定する
   - `DEST_DIR=".companies/{org-slug}/masters/quality-gates"`

## 2. 既存ファイルの確認

以下の bash コマンドで既存ファイルの有無を確認する。

```bash
DEST_DIR=".companies/{org-slug}/masters/quality-gates"
if [ -d "$DEST_DIR" ] && [ "$(ls -A $DEST_DIR 2>/dev/null)" ]; then
  echo "EXISTS"
else
  echo "EMPTY"
fi
```

**EXISTS の場合（既にファイルがある）:**

以下のメッセージをユーザーに表示して確認を求める。

```
masters/quality-gates/ には既にファイルが存在します。

現在のファイル:
{既存ファイルの一覧を表示}

上書きすると既存のカスタマイズが失われます。
どうしますか？

1. 上書きする（テンプレートで全て置き換え）
2. 存在しないファイルだけ追加する（既存ファイルは維持）
3. キャンセル
```

ユーザーの回答に応じて処理を分岐する。

**EMPTY の場合（ファイルがない）:**
確認なしにそのまま Step 3 に進む。

## 3. テンプレートのコピー

選択に応じて以下を実行する。

### 「1. 上書きする」の場合

```bash
TEMPLATE_DIR=".claude/skills/company-quality-setup/templates"
DEST_DIR=".companies/{org-slug}/masters/quality-gates"

rm -rf "$DEST_DIR"
cp -r "$TEMPLATE_DIR" "$DEST_DIR"
```

### 「2. 存在しないファイルだけ追加する」の場合

```bash
TEMPLATE_DIR=".claude/skills/company-quality-setup/templates"
DEST_DIR=".companies/{org-slug}/masters/quality-gates"

# テンプレートの全ファイルを走査して、存在しないものだけコピー
find "$TEMPLATE_DIR" -type f | while read src; do
  rel="${src#$TEMPLATE_DIR/}"
  dest="$DEST_DIR/$rel"
  if [ ! -f "$dest" ]; then
    mkdir -p "$(dirname $dest)"
    cp "$src" "$dest"
    echo "追加: $rel"
  else
    echo "スキップ（既存）: $rel"
  fi
done
```

## 4. 完了報告

```
✅ 品質ゲートをセットアップしました！

組織: {org-slug}
配置先: masters/quality-gates/

配置されたファイル:
  _default.md                    （共通チェック）
  by-type/requirements.md        （要件定義書）
  by-type/design.md              （設計書）
  by-type/proposal.md            （提案書）
  by-type/report.md              （報告書）
  by-type/adr.md                 （ADR）
  by-customer/_template.md       （顧客別テンプレート）

次のステップ:
- 顧客を登録すると by-customer/{slug}.md が自動生成されます（/company-admin）
- チェック内容を組織の実情に合わせて編集してください
- 品質ゲートは docs/ 配下の .md を保存するたびに自動で動作します
```

## 5. 注意事項

- テンプレートの編集は `.claude/skills/company-quality-setup/templates/` を直接編集する
- 組織ごとのカスタマイズは `masters/quality-gates/` 側を編集する
- by-customer/ 配下は `/company-admin` での顧客登録時に自動生成されるため、
  `_template.md` の内容を整えておくと各顧客ファイルの品質が上がる
