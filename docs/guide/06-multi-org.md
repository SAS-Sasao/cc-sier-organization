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

**どちらも `/company`（引数なし）1つで完結します。**

```
/company
```

実行するとメニューが表示されます。

| メニュー選択 | 動作 |
|---|---|
| 既存組織を選択 | その組織に切り替え |
| 新規組織を作成 | 4問の対話フローで新規作成 |

**新規作成時のフロー:**
1. `/company` を実行
2. 「新規組織を作成」を選択
3. 4問の対話に回答（組織名・名前・事業内容・初期部署）
4. 以下が自動生成される

```
.companies/{org-slug}/
├── CLAUDE.md
├── masters/
│   ├── organization.md
│   ├── departments.md
│   ├── roles.md
│   └── workflows.md
└── docs/
    └── secretary/
        ├── inbox/
        ├── todos/
        └── notes/
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
