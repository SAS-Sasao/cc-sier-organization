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

## 新しい組織を作る

```
/company-admin
→「新しい組織を作りたい。org-slug は b-corp-renewal-project。
  B社の既存システム刷新プロジェクト用。AWSメイン。」
```

自動作成されるもの:

```
.companies/b-corp-renewal-project/
├── CLAUDE.md
├── masters/
│   ├── customers/
│   ├── roles.md
│   └── workflows.md
└── docs/
    └── secretary/
```

---

## 組織を切り替える

```
/company b-corp-renewal-project
```

---

## 組織をまたいだ知識共有

| 共有される | 場所 |
|---|---|
| Subagentの定義 | `.claude/agents/*.md` |
| Skillの定義 | `.claude/skills/*/SKILL.md` |
| Hooksスクリプト | `.claude/hooks/*.sh` |

Case Bank は組織ごとに独立しています。ただし Skill Synthesizer が生成した SKILL.md と Subagent Spawner が生成した agent.md は全組織で共有されます。
