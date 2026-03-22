# 06 マルチ組織運用

---

## 組織とは

`.companies/{org-slug}/` 以下のディレクトリが1つの「組織」です。
顧客単位、部署単位、プロジェクト単位など任意の粒度で作成できます。

```
.companies/
├── .active                      ← 現在のアクティブ組織
├── jutaku-dev-team/
├── standardization-initiative/
└── domain-tech-collection/
```

---

## 新しい組織を作る・切り替える

**どちらも `/company {org-slug}` 1つで完結します。**

| 動作 | 条件 |
|---|---|
| 新規組織を作成 | `.companies/{org-slug}/` が存在しない場合 |
| 既存組織に切り替え | `.companies/{org-slug}/` が既に存在する場合 |

```
# 新規作成（存在しない org-slug を指定するだけ）
/company a-corp-renewal-project

# 切り替え（既存組織）
/company jutaku-dev-team
```

新規作成時に自動生成されるもの:

```
.companies/a-corp-renewal-project/
├── CLAUDE.md
├── masters/
│   ├── customers/
│   ├── roles.md
│   └── workflows.md
└── docs/
    └── secretary/
        ├── todos/
        └── reports/
```

作成後、`/company-admin` でマスタ（顧客情報・役割定義など）を追加していきます。

---

## 組織をまたいだ知識共有

| 共有される | 場所 |
|---|---|
| Subagentの定義 | `.claude/agents/*.md` |
| Skillの定義 | `.claude/skills/*/SKILL.md` |
| Hooksスクリプト | `.claude/hooks/*.sh` |

Case Bank は組織ごとに独立しています。ただし Skill Synthesizer が生成した SKILL.md と Subagent Spawner が生成した agent.md は全組織で共有されます。
