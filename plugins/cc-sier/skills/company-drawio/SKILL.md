---
name: company-drawio
description: >
  draw.io MCP Server を使用してアプリケーション構成図・ER図・フローチャート・
  シーケンス図等の汎用ダイアグラムを生成し、L0機械レビュー → L1構造ゲート →
  L2独立レビュー → PR自動マージまでを統合実行する。
  「ER図」「フローチャート」「シーケンス図」「業務フロー」「draw.io」
  「ネットワーク図」「C4モデル」「/company-drawio」と言われたときに使用する。
  ※ AWS構成図は /company-diagram を使用すること。
---

# draw.io ダイアグラム統合実行 Skill

draw.io MCP Server（`@drawio/mcp`）を使い、汎用ダイアグラムの「生成 → 3層レビュー → PR自動マージ」を 1 コマンドで完走する。

## 1. 適用条件

- `.companies/.active` に org-slug が存在する
- `drawio`（`@drawio/mcp`）が `.mcp.json` に設定済み
- `Node.js` / `npx` がインストール済み
- `.claude/skills/company-drawio/references/review-drawio.js` が存在する
- git status が clean（dirty なら中断）

---

## 2. AWS Diagram MCP との使い分け

| 用途 | 使用 Skill |
|---|---|
| AWS構成図（AWSアイコン付き） | `/company-diagram` |
| ER図・テーブル設計 | **本 Skill（/company-drawio）** |
| フローチャート・業務フロー | **本 Skill** |
| シーケンス図 | **本 Skill** |
| ネットワーク図（非AWS） | **本 Skill** |
| C4モデル・システム概要図 | **本 Skill** |
| 組織図・階層構造 | **本 Skill** |

---

## 3. 9フェーズ概要

| Phase | 名称 | 中断条件 |
|---|---|---|
| 0 | ヒアリング | `--yes` でスキップ |
| 1 | 前処理（branch / task-log） | git dirty |
| 2 | MCP 生成（open_drawio_{mermaid|csv|xml}） | 生成失敗 |
| 3 | ファイル配置（.drawio + HTML + index + .md） | - |
| 4 | L0 機械レビュー（review-drawio.js） | 1回自動修正後も貫通検出 |
| 5 | L1 セルフ構造ゲート（4セクション + 禁則 + ファイル網羅） | 1回自動修正後もfail |
| 6 | L2 独立レビュー（fresh general-purpose + XML/HTML整合性） | composite<0.85 がリトライ後も継続 |
| 7 | PR作成 & 自動マージ | gh pr merge失敗 |
| 8 | task-log & Issue & 報告 | - |

---

## 4. Phase 0: ヒアリング

依頼が不明確な場合のみ以下を確認する。`--yes` 指定時はスキップしてデフォルト値で進む。

```
Q1: どんな図を作りますか？（ER図、フローチャート、シーケンス図 等）
Q2: 含めたい要素は？（テーブル名、処理ステップ、アクター 等）
Q3: 図の名前は？（英語 kebab-case 推奨）
```

---

## 5. Phase 1: 前処理

```
1. .active → {org-slug}
2. git config user.name → {operator}
3. git status --porcelain が空でなければ中断
4. {date} = YYYY-MM-DD, {task-id} = YYYYMMDD-HHMMSS-drawio-{name}
5. {branch} = {org-slug}/feat/{date}-add-drawio-{name}
6. git checkout -b {branch}
7. .task-log/{task-id}.md を YAML フロントマターで作成
    subagents: [mcp-drawio-server, general-purpose-reviewer]
```

---

## 6. Phase 2: MCP 生成

### 6.1 MCP ツールの使い分け

| ツール | 入力形式 | 推奨用途 |
|---|---|---|
| `open_drawio_mermaid` | Mermaid 記法 | フローチャート、シーケンス図、ER図、状態遷移図 |
| `open_drawio_csv` | CSV | 組織図、ネットワークトポロジ、階層構造 |
| `open_drawio_xml` | draw.io XML | 精密なレイアウト、複雑なアーキテクチャ図 |

**選択基準**:
- シンプルなフロー・シーケンス図 → `open_drawio_mermaid`
- 階層・ツリー構造 → `open_drawio_csv`
- 精密な配置・スタイル制御 → `open_drawio_xml`

### 6.2 エッジ設計方針（貫通回避、Phase 4 で検証）

**原則: waypoint ではなくノード配置とエッジスタイルで貫通を回避する。**

- **層間エッジ**（コンテナをまたぐ接続）→ **直線**（`edgeStyle` を指定しない）
- **層内エッジ**（同一コンテナ内の隣接ノード間）→ `edgeStyle=orthogonalEdgeStyle`

```
NG: edgeStyle=orthogonalEdgeStyle を層間エッジに使う → 曲がり角が中間ノードを貫通する
OK: 層間は直線、層内の隣接ノード間のみ orthogonal
```

**ノード配置の原則**:
- 同一コンテナ内でエッジが中間ノードをスキップしない配置にする
- 接続先が隣接するよう並び順を調整する（例: A→B→C なら A,B,C の順）
- 分岐がある場合は 2 列配置
- 層間で多対一の接続は、ターゲットを接続元の中央高さに配置

### 6.3 swimlane 使用時の注意

`shape=swimlane` を使う場合は `startSize` の絶対座標オフセットを考慮すること（memory: feedback_drawio_swimlane_offset）。外部システムは swimlane 下方に配置する。

---

## 7. Phase 3: ファイル配置

```
docs/drawio/
├── {filename}.drawio              ← draw.io XML（必須）
├── {filename}.html                ← 詳細ページ（必須、4セクション）
├── index.html                     ← カード追記 + 件数更新
└── {filename}.png                 ← エクスポート画像（任意）

.companies/{org-slug}/docs/drawio/
└── {filename}.md                  ← ソースメタデータ・Mermaid/XMLコード
```

### 7.1 `.drawio` ファイル保存の注意

- `open_drawio_xml` 使用時: XML をそのまま `docs/drawio/{filename}.drawio` に保存
- `open_drawio_mermaid` 使用時: 同等の XML を `open_drawio_xml` でも生成し `.drawio` として保存する

### 7.2 詳細ページの必須4セクション

1. **draw.ioビューア** — Mermaid プレビュー + XMLダウンロードボタン
2. **概要** — 図の目的・対象システム・スコープ
3. **構成要素** — テーブル形式（要素名 / 種類 / 説明）
4. **設計のポイント** — 設計判断・トレードオフ（2〜4項目）

### 7.3 HTML 内 Mermaid 埋め込み禁則（Phase 4/5/6 で検証）

- `<pre class="mermaid">` 内には**絵文字を使わない**（🌙🌅☀️等 → `★` 等 ASCII 文字で代替）
- `\n`（改行エスケープ）を使わない。ノードテキストの区切りは半角スペース
- `""`（ダブルクォート2つ）を使わない（`"` で代替）
- `〜`（全角チルダ）は使用可
- draw.io MCP に渡す Mermaid ソース（`.md` ファイル）では絵文字・`\n` を自由に使ってよい。**制約は HTML 埋め込み時のみ**

### 7.4 一覧ページ（index.html）のカード追記

`<div class="grid">` 内にカードを追記する:

```html
<a href="./{filename}.html" class="card">
  <div class="card-body">
    <div class="card-icon">{アイコン}</div>
    <div class="card-title">{図タイトル}</div>
    <div class="card-meta">
      <span class="tag tag-project">{案件名}</span>
      <span class="tag tag-type">{図の種類}</span>
    </div>
    <div class="card-desc">{1行の説明}</div>
    <div class="card-date">{YYYY-MM-DD}</div>
  </div>
</a>
```

件数表示（`<p class="count">` の**右側の数字のみ**）も更新する。左側の `<span id="match-count">` は JS が自動制御。

### 7.5 図の種類別アイコン

| 図の種類 | アイコン | tag-type 色 |
|---|---|---|
| ER図 | 🗄️ | `#8b5cf6`（紫） |
| フローチャート | 🔀 | `#3b82f6`（青） |
| シーケンス図 | 🔄 | `#22c55e`（緑） |
| ネットワーク図 | 🌐 | `#06b6d4`（シアン） |
| 業務フロー | 📋 | `#f59e0b`（オレンジ） |
| C4モデル | 🏗️ | `#ef4444`（赤） |
| 組織図 | 👥 | `#6b7280`（グレー） |
| その他 | 📊 | `#6b7280`（グレー） |

---

## 8. Phase 4: L0 機械レビュー（エッジ貫通検出）

```bash
node .claude/skills/company-drawio/references/review-drawio.js docs/drawio/{filename}.drawio
```

| exit code | 意味 | アクション |
|---|---|---|
| 0 | 問題なし | Phase 5 へ |
| 1 | 貫通検出 | 検出ログを秘書にフィードバック → 1回自動修正 → 再実行 |
| 2 | ファイルエラー | Phase 2 の配置ミス。Phase 3 からやり直し1回 |

**致命判定**: 1回リトライ後も exit 1 なら中断して報告。L2 の s2 スコアにこの結果を反映させる。

---

## 9. Phase 5: L1 セルフ構造ゲート

| チェック項目 | 方法 |
|---|---|
| HTML 4セクション全存在 | grep で `draw.ioビューア`, `<h2>概要</h2>`, `<h2>構成要素</h2>`, `<h2>設計のポイント</h2>` |
| `.drawio` ファイル存在 | ls で `docs/drawio/{filename}.drawio` |
| index.html カード追記 | grep で `{filename}.html` リンク存在 |
| 件数更新 | `<p class="count">` 右側数字が +1 |
| Mermaid 埋め込み禁則 | grep で `<pre class="mermaid">` 内の絵文字・`\n`・`""` を検出 |
| `.md` メタデータ存在 | ls で `.companies/{org}/docs/drawio/{filename}.md` |

fail → 1回自動修正 → 再チェック → それでも fail なら中断。

---

## 10. Phase 6: L2 独立レビュー

**fresh `general-purpose` agent** を起動し、`.drawio` XML と HTML を Read ツールで実際に読み込ませて整合性評価する。

### 起動方法

```
Agent(
  description: "drawio L2 review",
  subagent_type: "general-purpose",
  prompt: <references/review-prompt.md の内容 + 以下の情報>
    - 詳細HTMLパス
    - .drawio XMLパス
    - 一覧 index.html パス
    - 図の種類（ER図/フローチャート等）
    - Phase 4 の review-drawio.js 実行結果（exit code + ログ）
)
```

### 採点 6軸（詳細は `references/review-prompt.md`）

| # | 軸 | 致命 |
|---|---|---|
| s1 | 構造準拠（HTML 4セクション） | - |
| s2 | **エッジ貫通**（review-drawio.js 結果を反映） | ★ |
| s3 | XML/HTML 整合性（ノードと構成要素表の一致） | - |
| s4 | 設計ポイントの具体性 | - |
| s5 | 一覧ページ更新（カード + 件数 + アイコン色） | - |
| s6 | **HTML 埋め込み禁則**（絵文字・\n・""） | ★ |

**判定**:
- 致命軸 (s2, s6) が `< 0.5` → composite 強制 0, fail
- それ以外は等重み平均 `≥ 0.85` で pass
- fail → 1回自動修正 → 再レビュー → それでも fail なら **auto-merge 中止**

---

## 11. Phase 7: PR作成 & 自動マージ

```bash
git add docs/drawio/ .companies/{org-slug}/docs/drawio/ .companies/{org-slug}/.task-log/
git commit -m "feat: draw.io図 {name} を追加 [{org-slug}] by {operator}"
git push origin {branch}
gh pr create --title "feat: draw.io図 {name} [{org-slug}]" --body "$(PR本文)"
gh pr merge --auto --squash --delete-branch
```

### PR 本文に必ず含める項目

- L0/L1/L2 全スコアと致命軸判定
- draw.io MCP が返却したエディタ URL（`https://app.diagrams.net/...`）を `## draw.io エディタ` セクションに記載
  - レビュアーがワンクリックで図を確認・編集できるように

**注意**: 成果物はすべて `docs/drawio/` 配下（GitHub Pages 配信先）にあるため、マージ後の main 直コミットは不要。

---

## 12. Phase 8: task-log & Issue & 報告

### task-log 更新（YAML フロントマター必須）

```yaml
---
task_id: "{task-id}"
status: completed
mode: "direct"
started: "..."
completed: "..."
request: "{ユーザー依頼原文}"
issue_number: {n}
pr_number: {n}
subagents: [mcp-drawio-server, general-purpose-reviewer]
l0_gate: pass
l0_retries: {0|1}
l1_gate: pass
l1_retries: {0|1}
l2_composite: 0.00
l2_retries: {0|1}
l2_scores:
  s1_structure: 0.00
  s2_edge_penetration: 0.00
  s3_xml_html_consistency: 0.00
  s4_design_points_specificity: 0.00
  s5_index_update: 0.00
  s6_html_violations: 0.00
---
```

### Issue 作成

```bash
gh issue create \
  --title "[{org-slug}] draw.io図 {name}" \
  --label "org:{org-slug},mode:direct,type:drawio,dept:secretary" \
  --body "$(Issue本文)"
```

### 最終報告フォーマット

```
✅ draw.io図 {name} を公開しました！

L0エッジ貫通:    PASS（retry {0|1}）
L1構造ゲート:    PASS（retry {0|1}）
L2独立レビュー:  composite {score}（retry {0|1}）

PR:     {pr_url} (merged)
Issue:  {issue_url}
図URL:  https://sas-sasao.github.io/cc-sier-organization/drawio/{filename}.html
```

---

## 13. オプションフラグ

| フラグ | 既定 | 効果 |
|---|---|---|
| `--force` | off | 同名ファイル既存時に上書き |
| `--no-merge` | off | PR 作成まで実行し、`gh pr merge` をスキップ |
| `--dry-run` | off | Phase 6 まで実行、Phase 7 以降スキップ |
| `--yes` | off | Phase 0 ヒアリングをスキップしデフォルト値で進行 |

---

## 14. エラー時の中断ポリシー

- 各 Phase で fail → task-log を `status: blocked` で保存
- ユーザーへの報告に Phase 名・原因・手動復旧コマンドを含める
- 部分作成済みのブランチ / PR は削除しない
- MCP 呼び出し失敗時は 1 回リトライ。それでも失敗なら Phase 2 を中断報告

---

## 15. 参照ファイル

| ファイル | 用途 |
|---|---|
| `references/review-prompt.md` | L2 独立レビュアー採点プロンプト（6軸、JSON出力） |
| `references/review-drawio.js` | L0 エッジ貫通検出スクリプト（Phase 4） |
| `.claude/skills/company/references/task-log-template.md` | task-log / Issue の共通スキーマ |
