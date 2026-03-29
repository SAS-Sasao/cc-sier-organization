# ナレッジポータル データ収集・分類ガイド

## カテゴリ分類ルール

### project（PJ業務）

コミットメッセージまたはtask-logが以下のいずれかに該当:
- `[org-slug]` タグを含み、`.companies/{org}/docs/` 配下のファイルを変更
- task-log の subagent が PM/設計/開発系（project-manager, system-architect, data-architect, backend-developer, frontend-developer, technical-writer 等）
- GitHub Issue のラベルに `dept:` が含まれる（秘書室以外）

### platform（基盤構築）

以下のいずれかに該当:
- `skills/`, `agents/`, `hooks/` 配下のファイルを変更するコミット
- SKILL.md, `.mcp.json`, `settings.json` の変更
- コミットメッセージに「Skill」「MCP」「Hook」「Agent」を含む
- task-log の subagent が devops-coordinator, ci-cd-engineer

### organization（組織管理）

以下のいずれかに該当:
- `masters/` 配下のファイルを変更するコミット
- `/company-admin` 経由のタスク（task-log に workflow: wf-admin 等）
- コミットメッセージに「部署」「ロール」「ワークフロー」を含む

### learning（品質・学習）

以下のいずれかに該当:
- `/company-evolve` 経由のタスク
- `.case-bank/`, `.quality-gate-log/` 関連の変更
- コミットメッセージに「evolve」「learning」「Case Bank」「reward」を含む
- admin ブランチかつ evolve 関連コミット

### discussion（壁打ち・意思決定）

以下のいずれかに該当:
- conversation-log に存在するがtask-logには対応エントリがないセッション
- ファイル生成を伴わないセッション（session-summaries の written_files が空）
- Human発言に「壁打ち」「相談」「どう思う」「検討」等を含む

## data.json スキーマ

```json
{
  "generated_at": "2026-03-29T14:30:00",
  "org_slug": "domain-tech-collection",
  "summary": {
    "total_entries": 150,
    "by_category": {
      "project": 45,
      "platform": 30,
      "organization": 15,
      "learning": 25,
      "discussion": 35
    },
    "date_range": {
      "earliest": "2026-03-10",
      "latest": "2026-03-29"
    }
  },
  "entries": [
    {
      "id": "entry-001",
      "date": "2026-03-29",
      "category": "discussion",
      "title": "新Skill構想の壁打ち（export/handover）",
      "description": "MD→Office変換Skillとナレッジポータルの構想を議論",
      "source": "conversation-log",
      "source_ref": "20260329-abc123.md",
      "tags": ["skill", "export", "handover"],
      "related_files": [],
      "metadata": {}
    },
    {
      "id": "entry-002",
      "date": "2026-03-28",
      "category": "platform",
      "subcategory": "skill",
      "title": "/company-drawio エッジスタイル修正",
      "description": "層間エッジを直線に変更（曲がり線貫通防止）",
      "source": "git-log",
      "source_ref": "abc1234",
      "tags": ["drawio", "edge", "fix"],
      "related_files": [".claude/skills/company-drawio/SKILL.md"],
      "metadata": {
        "commit_hash": "abc1234",
        "commit_type": "fix"
      }
    },
    {
      "id": "entry-003",
      "date": "2026-03-27",
      "category": "project",
      "title": "ストコンDWH設計レビュー",
      "description": "...",
      "source": "task-log",
      "source_ref": "20260327-143000-storcon-dwh-review.md",
      "tags": ["storcon", "dwh", "review"],
      "related_files": ["docs/arch/dwh-design.md"],
      "metadata": {
        "subagent": "data-architect",
        "reward": 0.85,
        "judge_total": 0.9
      }
    }
  ],
  "decisions": [
    {
      "id": "dec-001",
      "date": "2026-03-28",
      "title": "draw.ioエッジスタイルルール",
      "rule": "層間エッジは直線、層内のみorthogonal",
      "reason": "曲がり線が他ノードを貫通する問題が発生",
      "source": "feedback_memory",
      "source_ref": "feedback_drawio_edge_style.md"
    }
  ],
  "tips": [
    {
      "id": "tip-001",
      "title": "Subagent WebFetch制約",
      "content": "SubagentはWebFetchが制限される。秘書が事前取得してプロンプトに注入する。",
      "reward": 0.85,
      "source": "case-bank",
      "source_ref": "case-015"
    }
  ]
}
```

## platform サブカテゴリ

基盤構築タブでは以下のサブカテゴリで表形式表示する:

| サブカテゴリ | 表示列 |
|-------------|--------|
| skill | 日付・Skill名・経緯/理由 |
| mcp | 日付・MCP名・導入理由 |
| hook | 日付・Hook名・目的 |
| agent | 日付・Agent名・変更内容 |
| config | 日付・設定項目・変更内容 |
