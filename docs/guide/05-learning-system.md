# 05 継続学習システム

---

## 設計思想

論文「Memento-Skills: Let Agents Design Agents」の実装です。LLMのパラメータを更新することなく継続学習を実現します。

```
通常の学習:    経験 → パラメータ更新（ファインチューニング）
Memento-Skills: 経験 → Skill ファイル（Markdown）の更新
```

**「進化的なメモリ」として機能するファイル一覧:**

| ファイル | メモリとしての役割 |
|---|---|
| `.task-log/*.md` | エピソードメモリ（過去の実行履歴） |
| `.case-bank/index.json` | 構造化エピソードメモリ |
| `secretary/MEMORY.md` | 作業スタイルの好み・ルーティング傾向 |
| `masters/workflows.md` | 手続き的メモリ（成功した手順） |
| `.claude/agents/*.md` | Subagentの知識・制約（Refinerが更新） |
| `.claude/skills/*/SKILL.md` | Skill定義（Synthesizerが生成） |
| `.conversation-log/*.md` | 会話エピソードメモリ（背景・意図・フレーズ） |

---

## Phase 1: ポリシー評価

### Skill Evaluator（報酬スコア付与）

セッション終了時に `skill-evaluator.sh` が本日完了したタスクを評価します。

| シグナル | 条件 | 点数 |
|---|---|---|
| 基礎点 | status が completed | 60点 |
| artifacts_exist | 成果物ファイルが実際に存在する | +20点 |
| no_excessive_edits | 同一ファイルへのWriteが5回以下 | +20点 |
| no_retry | 「やり直し」等が検出されない | ペナルティなし |

スコアは 0.0〜1.0 に正規化して task-log に追記します。

| スコア | 意味 | 活用 |
|---|---|---|
| 0.7 以上 | 高品質 | Skill生成・ワークフロー登録の候補 |
| 0.4〜0.7 | 普通 | Case Bankに記録するが特別扱いしない |
| 0.4 未満 | 低品質 | constraints への注意事項追記 |

### Case Bank（構造化エピソードメモリ）

`rebuild-case-bank.sh` が task-log 全件を走査して `.case-bank/index.json` を再構築します。

```json
{
  "cases": [
    {
      "id": "20260319-143000-dwh-design",
      "state": {
        "request_keywords": ["DWH", "設計", "メダリオン"],
        "request_head": "A社のDWH設計をやって"
      },
      "action": {
        "subagent": "data-architect",
        "mode": "subagent",
        "artifact_count": 3
      },
      "reward": 0.9,
      "outcome": {
        "files_written": [".companies/jutaku-dev-team/docs/data/models/architecture.md"]
      }
    }
  ]
}
```

---

## Phase 2: スタイル学習

### MEMORY.md の更新

`docs/secretary/MEMORY.md` に出力スタイルとルーティング先読みを記録します。

| 検出条件 | 記録内容 |
|---|---|
| 「ASCII図」が3回以上 | `ASCII図を必ず添付する` |
| 「比較表」が3回以上 | `比較表をセットで出力する` |
| 「短く」が3回以上 | `簡潔な出力を好む` |

### ワークフロー自動生成

高報酬パターン（3件以上・平均reward≥0.7）を `masters/workflows.md` に自動追記します。

---

## Phase 3: 自律進化

### Skill Synthesizer

**「手順書がないのに繰り返している作業」を検出してSkillを自動生成します。**

検出条件:
- mode が `direct`（Skillなしで直接対応）
- artifact_count ≥ 2（成果物がある）
- reward ≥ 0.5（品質が担保されている）
- 同じ request_head が3件以上
- 既存Skillトリガーとの重複 ≤ 50%

生成先: `.claude/skills/{slug}/SKILL.md` → PR 経由でレビュー

### Subagent Refiner

**実績データで既存Subagentの説明文を精緻化します。**（前回更新から3件以上新規ケースでトリガー）

追記される3セクション:
- `refined_capabilities`: 高報酬ケースから導出した得意領域
- `output_format`: 過去ケースの実際の出力先ディレクトリ
- `constraints`: 低報酬ケースから導出した注意事項

### Subagent Spawner

**対応Subagentがない繰り返し作業に新規Subagentを生成します。**

検出条件: direct mode かつ artifact_count ≥ 2 かつ 3件以上 かつ avg_reward ≥ 0.5 かつ 既存Agentに同名なし

生成先: `.claude/agents/{slug}.md` → PR 経由でレビュー

---

## Read フェーズ：次のセッションへの反映

秘書の起動時に Case Bank を読み込み、類似ケースの高報酬パターンを Stateful Prompt として注入します。

```
【過去の類似ケース（Case Bank より）】
- 「A社のDWH設計をやって」→ data-architect（subagent）報酬:0.90
高報酬ケースと同じルーティングを優先すること。
```

照合ロジック: request_keywords の重複率 ≥ 0.3 で「類似」と判定（API コストゼロ）。

---

## 全フェーズのデータフロー

```
セッション実行
    ↓ PostToolUse
.interaction-log/YYYY-MM-DD.md に記録

セッション終了（Stop hook）
    ├── capture-conversation.sh → .conversation-log/ に会話MD保存（マスキング済み）
    ├── .session-summaries/ に統計JSON
    ├── GitHub Issue に会話サマリーを含めて投稿
    ├── [Phase 1] task-log に reward スコア付与
    ├── [Phase 1] .case-bank/index.json を再構築
    ├── [Phase 3] 新規SKILL.md の PR
    └── [Phase 3] Agent更新の PR

/company-evolve（定期 or /company-report 後自動）
    ├── enrich-case-bank.sh → 会話ログから意図・フレーズを抽出してCase Bank補強
    ├── [Phase 2] MEMORY.md 更新
    ├── [Phase 2] workflows.md 追記
    ├── [Phase 3] skill-synthesizer 再実行
    └── [Phase 3] subagent-refiner 再実行

次のセッション起動
    → 秘書が .case-bank/index.json を Read
    → Stateful Prompt として注入
    → より精度の高いルーティング
```

---

## ファイルのGit管理方針

| ファイル | Git管理 | 理由 |
|---|---|---|
| `.task-log/*.md` | ✅ | 成果物・履歴として保存 |
| `masters/workflows.md` | ✅ | チーム共有する知識 |
| `agents/*.md` | ✅ | レビュー経由で更新 |
| `skills/*/SKILL.md` | ✅ | レビュー経由で更新 |
| `.interaction-log/` | ❌ | 生ログは大きく個人的 |
| `.session-summaries/` | ❌ | 中間データ |
| `.case-bank/` | ❌ | ローカル学習データ |
| `.conversation-log/*.md` | ❌ | 会話内容・プライバシー保護のためローカルのみ |
