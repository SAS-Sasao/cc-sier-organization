# Skill 開発ルール

`plugins/cc-sier/skills/` 配下の Skill 開発ルールと、ランタイム同期の手順。

## SKILL.md の制約

### プログレッシブ・ディスクロージャ

- **1,500〜2,000語以内**に収める
- 詳細テンプレート・HTML スニペット・採点プロンプトは `references/` 配下に外出し
- SKILL.md 本体は「何を・いつ・どう」の概要のみ

### 標準ファイル構成

```
plugins/cc-sier/skills/{skill-name}/
├── SKILL.md                 ← メインファイル（1,500〜2,000語）
└── references/              ← 詳細定義（必要時のみ参照）
    ├── review-prompt.md     ← L2 採点プロンプト（レビュー付きSkill）
    └── *.md                 ← その他テンプレート
```

## plugins/ ↔ .claude/skills/ の同期ルール

### 背景

Claude Code ランタイムは `.claude/skills/` を読む。`plugins/cc-sier/skills/` に追加しただけでは `/` コマンドリストに現れない。

### 同期コマンド

```bash
# 新規 Skill 追加時
cp -r plugins/cc-sier/skills/{new-skill-name} .claude/skills/

# 既存 Skill 更新時
cp plugins/cc-sier/skills/{name}/SKILL.md .claude/skills/{name}/SKILL.md
cp plugins/cc-sier/skills/{name}/references/*.md .claude/skills/{name}/references/

# 同期確認
diff -rq plugins/cc-sier/skills/{name}/ .claude/skills/{name}/
```

### VCS の真ソース

`plugins/cc-sier/skills/` が VCS 真ソース。`.claude/skills/` 側に独自編集を入れない（legacy リファレンスのみ例外）。

## SKILL.md リライト時の取りこぼし防止プロセス

過去に /company-diagram 9フェーズ化リライトで `aws-cost-estimation.md` 参照と 学習ポイントセクション生成を取りこぼし、3 段階（PR #251→#253→#254）ですり抜け修正した経験あり。

### Step 0（最重要）: 既存成果物の必須セクションを grep で抽出

```bash
# HTML 成果物の場合
for f in docs/diagrams/*.html; do
  [[ "$f" == *-iac.html || "$f" == *index.html ]] && continue
  echo "=== $(basename $f) ==="
  grep -o "<h2>[^<]*</h2>" "$f"
done

# MD 成果物の場合
for f in .companies/{org}/docs/daily-digest/*.md; do
  echo "=== $(basename $f) ==="
  grep -E "^##? " "$f"
done
```

**6/10 以上の成果物に共通する見出し = 実質必須セクション**。新 SKILL.md と照合。

### Step 1: 旧 SKILL.md の references/ 参照を抽出

```bash
grep -n "references/" plugins/cc-sier/skills/{name}/SKILL.md
```

### Step 2: references/ の orphan 検出

```bash
for ref in $(ls plugins/cc-sier/skills/{name}/references/); do
  grep -q "$ref" plugins/cc-sier/skills/{name}/SKILL.md && echo "✓ $ref" || echo "✗ $ref (orphan)"
done
```

### Step 3: L2 review-prompt.md の同時更新

SKILL.md の必須セクション変更は **必ず** `references/review-prompt.md` の採点基準にも反映する。片方だけ更新すると L2 レビューが旧仕様で通過してしまう。

### Step 4: 初回実運用前に --dry-run

可能な限り、初回実運用前に `--dry-run` フラグで Phase 5 までを実行し、既存成果物と diff を取る。

## Subagent との関係

- `plugins/cc-sier/agents/` に定義（VCS 真ソース、19種）
- `.claude/agents/` にコピーされランタイムで使用
- 代表: secretary / project-manager / data-architect / tech-researcher / retail-domain-researcher 等

## 関連

- @.claude/rules/review-pattern.md — 3層レビューの標準設計
- @.claude/rules/git-workflow.md — PR・auto-merge
