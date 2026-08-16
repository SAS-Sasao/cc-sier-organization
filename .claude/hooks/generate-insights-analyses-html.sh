#!/usr/bin/env bash
# generate-insights-analyses-html.sh — 知見解析レポート MD → HTML 変換（GitHub Pages 用）
#
#   入力: docs/insights/analyses/*.md
#   出力: docs/insights/analyses/{slug}.html   各レポート
#         docs/insights/analyses/index.html    一覧ページ
#         docs/index.html                      トップページにカード追記（冪等）
#
# 配置根拠: @.claude/rules/artifact-placement.md 「知見解析レポートの例外」
# 呼び出し元: /company-insights-cycle Phase 2
set -euo pipefail

ANALYSES_DIR="docs/insights/analyses"
[[ -d "$ANALYSES_DIR" ]] || { echo "No analyses dir: ${ANALYSES_DIR}" >&2; exit 1; }

REPO_BLOB="https://github.com/SAS-Sasao/cc-sier-organization/blob/main"

echo "Generating insights analyses HTML..."

python3 - "$ANALYSES_DIR" "$REPO_BLOB" <<'PYEOF'
import sys, re, html as htmlmod
from pathlib import Path
from datetime import datetime

analyses_dir = Path(sys.argv[1])
repo_blob = sys.argv[2]
now = datetime.now().strftime("%Y-%m-%d %H:%M")

md_files = sorted(analyses_dir.glob("*.md"))
if not md_files:
    print("No analysis reports found.")
    sys.exit(1)

# ============================================================
# Markdown → HTML
# ============================================================

def esc(t):
    return htmlmod.escape(t, quote=False)

def fix_link(url, slugs):
    """レポート間リンクは .html へ、組織スコープへのリンクは GitHub blob へ向ける。"""
    if url.startswith(("http://", "https://", "#", "mailto:")):
        return url
    # 相対パスに .companies/ が含まれるものはリポジトリを直接見せる
    if ".companies/" in url:
        return f"{repo_blob}/.companies/" + url.split(".companies/", 1)[1]
    # 兄弟レポートへのリンク
    base = url.split("/")[-1]
    if base.endswith(".md") and base[:-3] in slugs:
        return base[:-3] + ".html"
    if url.endswith(".md"):
        return f"{repo_blob}/{url.lstrip('./')}"
    return url

def md_inline(text, slugs):
    """インライン記法。コードスパンを先に退避してから他を適用する。"""
    stash = []

    def keep(m):
        stash.append(m.group(1))
        return f"\x00{len(stash)-1}\x00"

    text = re.sub(r'`([^`]+)`', keep, text)
    text = esc(text)
    text = re.sub(r'\*\*\[([^\]]+)\]\(([^)]+)\)\*\*',
                  lambda m: f'<a href="{fix_link(m.group(2), slugs)}"><strong>{m.group(1)}</strong></a>', text)
    text = re.sub(r'\[([^\]]+)\]\(([^)]+)\)',
                  lambda m: f'<a href="{fix_link(m.group(2), slugs)}">{m.group(1)}</a>', text)
    text = re.sub(r'\*\*(.+?)\*\*', r'<strong>\1</strong>', text)
    text = re.sub(r'(?<![\w*])\*([^*\n]+)\*(?![\w*])', r'<em>\1</em>', text)
    for i, code in enumerate(stash):
        text = text.replace(f"\x00{i}\x00", f'<code>{esc(code)}</code>')
    return text

def convert_table(rows, slugs):
    out = ['<div class="table-wrap"><table>']
    header_done = False
    for line in rows:
        cells = [c.strip() for c in line.strip().strip('|').split('|')]
        if all(re.match(r'^[-:]+$', c) for c in cells if c):
            header_done = True
            continue
        if not header_done:
            out.append('<thead><tr>' + ''.join(f'<th>{md_inline(c, slugs)}</th>' for c in cells) + '</tr></thead><tbody>')
        else:
            out.append('<tr>' + ''.join(f'<td>{md_inline(c, slugs)}</td>' for c in cells) + '</tr>')
    if not header_done:
        out.append('<tbody>')
    out.append('</tbody></table></div>')
    return '\n'.join(out)

def convert_list(items, slugs, ordered):
    tag = 'ol' if ordered else 'ul'
    out = [f'<{tag}>']
    for raw in items:
        content = re.sub(r'^(\s*)([-*]|\d+\.)\s+', '', raw)
        out.append(f'<li>{md_inline(content, slugs)}</li>')
    out.append(f'</{tag}>')
    return '\n'.join(out)

def md_to_html(body, slugs):
    """見出し・表・リスト・引用・コードブロック・段落を扱う。目次用に h2 を返す。"""
    lines = body.split('\n')
    out, buf, mode = [], [], None
    headings = []
    in_code, code_buf = False, []

    def flush():
        nonlocal buf, mode
        if not buf:
            mode = None
            return
        if mode == 'table':
            out.append(convert_table(buf, slugs))
        elif mode in ('ul', 'ol'):
            out.append(convert_list(buf, slugs, mode == 'ol'))
        elif mode == 'quote':
            inner = ' '.join(re.sub(r'^>\s?', '', b) for b in buf)
            out.append(f'<blockquote>{md_inline(inner, slugs)}</blockquote>')
        elif mode == 'p':
            out.append(f'<p>{md_inline(" ".join(buf), slugs)}</p>')
        buf, mode = [], None

    for line in lines:
        stripped = line.strip()

        if stripped.startswith('```'):
            if in_code:
                out.append('<pre><code>' + esc('\n'.join(code_buf)) + '</code></pre>')
                code_buf, in_code = [], False
            else:
                flush()
                in_code = True
            continue
        if in_code:
            code_buf.append(line)
            continue

        m = re.match(r'^(#{2,4})\s+(.+)$', stripped)
        if m:
            flush()
            level = len(m.group(1))
            text = md_inline(m.group(2), slugs)
            if level == 2:
                anchor = f'h{len(headings)}'
                headings.append((anchor, re.sub(r'<[^>]+>', '', text)))
                out.append(f'<h2 id="{anchor}">{text}</h2>')
            else:
                out.append(f'<h{level}>{text}</h{level}>')
            continue

        if re.match(r'^---+$', stripped):
            flush()
            out.append('<hr>')
            continue

        if not stripped:
            flush()
            continue

        if stripped.startswith('|') and stripped.endswith('|'):
            if mode != 'table':
                flush(); mode = 'table'
            buf.append(stripped)
            continue

        if stripped.startswith('>'):
            if mode != 'quote':
                flush(); mode = 'quote'
            buf.append(stripped)
            continue

        if re.match(r'^\d+\.\s+', stripped):
            if mode != 'ol':
                flush(); mode = 'ol'
            buf.append(stripped)
            continue

        if re.match(r'^[-*]\s+', stripped):
            if mode != 'ul':
                flush(); mode = 'ul'
            buf.append(stripped)
            continue

        if mode != 'p':
            flush(); mode = 'p'
        buf.append(stripped)

    if in_code and code_buf:
        out.append('<pre><code>' + esc('\n'.join(code_buf)) + '</code></pre>')
    flush()
    return '\n'.join(out), headings

# ============================================================
# メタ情報の抽出
# ============================================================

def parse_report(path, slugs):
    raw = path.read_text(encoding='utf-8')
    title_m = re.search(r'^#\s+(.+)$', raw, re.M)
    title = title_m.group(1).strip() if title_m else path.stem
    body = raw[title_m.end():] if title_m else raw

    meta = {}
    for k, v in re.findall(r'^\|\s*([^|]+?)\s*\|\s*(.+?)\s*\|$', body, re.M):
        key = k.strip()
        if key in ('ドキュメント種別', '作成日', '作成者', 'ステータス', '対象期間', '母数', '精読', '対象', '依頼', '目的'):
            meta.setdefault(key, re.sub(r'\*\*|`', '', v.strip()))

    content, headings = md_to_html(body, slugs)
    return {
        'slug': path.stem,
        'title': title,
        'meta': meta,
        'content': content,
        'headings': headings,
        'chars': len(raw),
    }

STYLE = """
:root { --bg:#0b1222; --bg2:#131d2f; --bg3:#0f1829; --text:#e2e8f0; --accent:#4361ee;
        --border:#1e293b; --muted:#94a3b8; --code:#fbbf24; }
@media (prefers-color-scheme: light) {
  :root { --bg:#f8fafc; --bg2:#fff; --bg3:#f1f5f9; --text:#0f172a; --accent:#3730a3;
          --border:#e2e8f0; --muted:#475569; --code:#b45309; }
}
* { box-sizing:border-box; }
body { margin:0; background:var(--bg); color:var(--text); line-height:1.85;
       font-family:-apple-system,BlinkMacSystemFont,"Segoe UI","Hiragino Sans","Noto Sans JP",sans-serif; }
.wrap { max-width:960px; margin:0 auto; padding:32px 20px 80px; }
a { color:var(--accent); text-decoration:none; }
a:hover { text-decoration:underline; }
.crumb { font-size:13px; color:var(--muted); margin-bottom:20px; }
h1 { font-size:26px; line-height:1.5; margin:0 0 20px; padding-bottom:14px; border-bottom:2px solid var(--accent); }
h2 { font-size:20px; margin:44px 0 14px; padding-left:11px; border-left:4px solid var(--accent); scroll-margin-top:20px; }
h3 { font-size:17px; margin:30px 0 10px; color:var(--text); }
h4 { font-size:15px; margin:22px 0 8px; color:var(--muted); }
p { margin:12px 0; }
hr { border:0; border-top:1px solid var(--border); margin:32px 0; }
code { background:var(--bg3); color:var(--code); padding:2px 6px; border-radius:4px;
       font-size:.88em; font-family:ui-monospace,SFMono-Regular,Menlo,monospace; word-break:break-all; }
pre { background:var(--bg3); border:1px solid var(--border); border-radius:8px;
      padding:14px 16px; overflow-x:auto; }
pre code { background:none; color:var(--text); padding:0; font-size:13px; }
blockquote { margin:16px 0; padding:12px 18px; background:var(--bg2);
             border-left:4px solid var(--muted); border-radius:0 6px 6px 0; color:var(--muted); }
blockquote strong { color:var(--text); }
ul,ol { padding-left:24px; margin:12px 0; }
li { margin:6px 0; }
.table-wrap { overflow-x:auto; margin:18px 0; -webkit-overflow-scrolling:touch; }
table { border-collapse:collapse; width:100%; font-size:14px; min-width:480px; }
th,td { border:1px solid var(--border); padding:8px 12px; text-align:left; vertical-align:top; }
th { background:var(--bg3); font-weight:600; white-space:nowrap; }
tbody tr:nth-child(even) { background:rgba(148,163,184,.05); }
.toc { background:var(--bg2); border:1px solid var(--border); border-radius:8px; padding:16px 20px; margin:24px 0 36px; }
.toc-title { font-size:13px; color:var(--muted); margin-bottom:8px; letter-spacing:.04em; }
.toc ol { margin:0; padding-left:20px; font-size:14px; }
.metabar { display:flex; flex-wrap:wrap; gap:8px; margin:0 0 24px; }
.tag { font-size:12px; background:var(--bg3); border:1px solid var(--border);
       border-radius:999px; padding:3px 12px; color:var(--muted); }
.grid { display:grid; grid-template-columns:repeat(auto-fill,minmax(300px,1fr)); gap:16px; margin-top:24px; }
.card { display:block; background:var(--bg2); border:1px solid var(--border); border-left:3px solid var(--accent);
        border-radius:8px; padding:18px 20px; transition:.18s; }
.card:hover { transform:translateY(-2px); box-shadow:0 6px 22px rgba(0,0,0,.22); text-decoration:none; }
.card-title { font-size:15px; font-weight:600; color:var(--text); line-height:1.55; margin-bottom:10px; }
.card-meta { font-size:12px; color:var(--muted); }
.updated { margin-top:48px; font-size:12px; color:var(--muted); text-align:center; }
"""

slugs = {p.stem for p in md_files}
reports = [parse_report(p, slugs) for p in md_files]
# 作成日の新しい順。日付が取れないものは末尾へ
reports.sort(key=lambda r: r['meta'].get('作成日', ''), reverse=True)

# ---- 個別ページ ----
for r in reports:
    toc = ''
    if len(r['headings']) >= 3:
        items = ''.join(f'<li><a href="#{a}">{t}</a></li>' for a, t in r['headings'])
        toc = f'<nav class="toc"><div class="toc-title">目次</div><ol>{items}</ol></nav>'
    tags = ''.join(f'<span class="tag">{esc(k)}: {esc(v)}</span>'
                   for k, v in r['meta'].items() if k in ('作成日', 'ドキュメント種別', 'ステータス', '対象期間'))
    page = f"""<!DOCTYPE html>
<html lang="ja">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>{esc(r['title'])} | 知見解析レポート</title>
<style>{STYLE}</style>
</head>
<body>
<div class="wrap">
  <div class="crumb"><a href="../../index.html">トップ</a> › <a href="./index.html">知見解析レポート</a></div>
  <h1>{esc(r['title'])}</h1>
  <div class="metabar">{tags}</div>
  {toc}
  {r['content']}
  <p class="updated">生成: {now} — <a href="../../index.html">トップへ戻る</a></p>
</div>
</body>
</html>
"""
    (analyses_dir / f"{r['slug']}.html").write_text(page, encoding='utf-8')

# ---- 一覧ページ ----
cards = []
for r in reports:
    m = r['meta']
    bits = [b for b in (m.get('作成日'), m.get('ドキュメント種別'), f"{r['chars']:,} 字") if b]
    cards.append(f"""    <a href="./{r['slug']}.html" class="card">
      <div class="card-title">{esc(r['title'])}</div>
      <div class="card-meta">{esc(' ・ '.join(bits))}</div>
    </a>""")

index = f"""<!DOCTYPE html>
<html lang="ja">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>知見解析レポート | cc-sier-organization</title>
<style>{STYLE}</style>
</head>
<body>
<div class="wrap">
  <div class="crumb"><a href="../../index.html">トップ</a> › 知見解析レポート</div>
  <h1>知見解析レポート</h1>
  <p>外部の技術記事を <strong>curl で原文取得して精読し</strong>、主張を自組織の実測値と突き合わせた解析レポート。
  採用するかどうかの判断は
  <a href="{repo_blob}/.companies/domain-tech-collection/docs/insights/catalog.md">知見カタログ</a>
  に集約している。</p>
  <div class="grid">
{chr(10).join(cards)}
  </div>
  <p class="updated">{len(reports)} 件 — 生成: {now}</p>
</div>
</body>
</html>
"""
(analyses_dir / "index.html").write_text(index, encoding='utf-8')

total_kb = round(sum((analyses_dir / f"{r['slug']}.html").stat().st_size for r in reports) / 1024, 1)
print(f"Generated: {len(reports)} reports + index ({total_kb} KB) in {analyses_dir}")
PYEOF

# --- docs/index.html にカードを追記（冪等） ---
python3 - <<'PYEOF2'
import re
from pathlib import Path

index_path = Path("docs/index.html")
if not index_path.exists():
    print("docs/index.html not found, skipping card insertion")
    raise SystemExit(0)

html = index_path.read_text(encoding="utf-8", errors="ignore")

# 既存の解析レポートカードがあれば除去してから入れ直す
html = re.sub(r'\s*<a href="\./insights/analyses/[^"]*"[^>]*class="card"[^>]*>.*?</a>',
              '', html, flags=re.DOTALL)

card = '''
    <a href="./insights/analyses/index.html" class="card" style="border:2px solid #a855f7;">
      <div class="org-name">知見解析レポート</div>
      <div class="org-label">技術記事の精読・実測・採用判断 →</div>
    </a>'''

new_html, n = re.subn(r'(</div>\s*<p class="updated")', f'{card}\n\\1', html, count=1)
if n == 0:
    print("WARNING: グリッド終端を特定できず、カードを挿入できませんでした", flush=True)
    raise SystemExit(1)

index_path.write_text(new_html, encoding="utf-8")
print("Updated: docs/index.html (知見解析レポート card)")
PYEOF2

echo "Done."
