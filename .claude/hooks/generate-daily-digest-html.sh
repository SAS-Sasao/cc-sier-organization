#!/usr/bin/env bash
# generate-daily-digest-html.sh — 日次ダイジェストMD → HTML変換（GitHub Pages用）
set -uo pipefail

ORG_SLUG="${1:-}"
if [[ -z "$ORG_SLUG" ]]; then
  [[ -f ".companies/.active" ]] || { echo "No active org" >&2; exit 1; }
  ORG_SLUG=$(tr -d '[:space:]' < ".companies/.active")
fi

ORG_DIR=".companies/${ORG_SLUG}"
[[ -d "$ORG_DIR" ]] || { echo "Org not found: ${ORG_SLUG}" >&2; exit 1; }

DIGEST_DIR="${ORG_DIR}/docs/daily-digest"
[[ -d "$DIGEST_DIR" ]] || { echo "No daily-digest dir: ${DIGEST_DIR}" >&2; exit 1; }

OUTPUT_DIR="docs/daily-digest"
mkdir -p "$OUTPUT_DIR"
OUTPUT="${OUTPUT_DIR}/index.html"

echo "Generating daily digest HTML for ${ORG_SLUG}..."

python3 - "$DIGEST_DIR" "$ORG_SLUG" "$OUTPUT" <<'PYEOF'
import sys, re, os
from pathlib import Path
from datetime import datetime

digest_dir = Path(sys.argv[1])
org_slug = sys.argv[2]
output_path = Path(sys.argv[3])
now = datetime.now().strftime("%Y-%m-%d %H:%M")

# ============================================================
# Phase 1: MD file collection & parse
# ============================================================

md_files = sorted(digest_dir.glob("*.md"), reverse=True)
if not md_files:
    print("No digest files found.")
    sys.exit(1)

def md_inline(text):
    """Convert inline markdown: links, bold, code"""
    # bold links: **[text](url)**
    text = re.sub(r'\*\*\[([^\]]+)\]\(([^)]+)\)\*\*',
                  r'<a href="\2" target="_blank" rel="noopener"><strong>\1</strong></a>', text)
    # links: [text](url)
    text = re.sub(r'\[([^\]]+)\]\(([^)]+)\)',
                  r'<a href="\2" target="_blank" rel="noopener">\1</a>', text)
    # bold
    text = re.sub(r'\*\*(.+?)\*\*', r'<strong>\1</strong>', text)
    # inline code
    text = re.sub(r'`([^`]+)`', r'<code>\1</code>', text)
    return text

def convert_table(lines):
    """Convert markdown table lines to HTML table"""
    if len(lines) < 2:
        return ""
    html = ['<div class="table-wrap"><table>']
    header_done = False
    for line in lines:
        cells = [c.strip() for c in line.strip().strip('|').split('|')]
        if all(re.match(r'^[-:]+$', c) for c in cells):
            header_done = True
            continue
        tag = 'th' if not header_done else 'td'
        row_cells = ''.join(f'<{tag}>{md_inline(c)}</{tag}>' for c in cells)
        if not header_done:
            html.append(f'<thead><tr>{row_cells}</tr></thead><tbody>')
        else:
            html.append(f'<tr>{row_cells}</tr>')
    html.append('</tbody></table></div>')
    return '\n'.join(html)

def convert_list_block(lines):
    """Convert markdown list lines to HTML ul"""
    html = ['<ul>']
    for line in lines:
        content = re.sub(r'^[-*]\s+', '', line.strip())
        content = re.sub(r'^\d+\.\s+', '', content)
        html.append(f'<li>{md_inline(content)}</li>')
    html.append('</ul>')
    return '\n'.join(html)

def md_body_to_html(body):
    """Convert a section body to HTML"""
    lines = body.split('\n')
    result = []
    buf = []
    mode = None  # 'table', 'list', None

    def flush():
        nonlocal buf, mode
        if mode == 'table' and buf:
            result.append(convert_table(buf))
        elif mode == 'list' and buf:
            result.append(convert_list_block(buf))
        buf = []
        mode = None

    for line in lines:
        stripped = line.strip()

        # h3
        m = re.match(r'^###\s+(.+)$', stripped)
        if m:
            flush()
            result.append(f'<h3>{md_inline(m.group(1))}</h3>')
            continue

        # hr
        if re.match(r'^---+$', stripped):
            flush()
            result.append('<hr>')
            continue

        # table row
        if stripped.startswith('|') and stripped.endswith('|'):
            if mode != 'table':
                flush()
                mode = 'table'
            buf.append(stripped)
            continue

        # list item
        if re.match(r'^[-*]\s+', stripped) or re.match(r'^\d+\.\s+', stripped):
            if mode != 'list':
                flush()
                mode = 'list'
            buf.append(stripped)
            continue

        # blockquote
        if stripped.startswith('>'):
            flush()
            content = stripped.lstrip('> ').strip()
            result.append(f'<blockquote>{md_inline(content)}</blockquote>')
            continue

        # empty line
        if not stripped:
            flush()
            continue

        # paragraph text
        flush()
        result.append(f'<p>{md_inline(stripped)}</p>')

    flush()
    return '\n'.join(result)

def parse_digest(md_path):
    """Parse a single digest MD file"""
    text = md_path.read_text(encoding="utf-8", errors="ignore")
    date_str = md_path.stem  # YYYY-MM-DD

    # Title
    title_m = re.match(r'^#\s+(.+)$', text, re.MULTILINE)
    title = title_m.group(1).strip() if title_m else f"日次ダイジェスト {date_str}"

    # Header blockquote lines
    header_lines = re.findall(r'^>\s*(.+)$', text, re.MULTILINE)

    # Split by ## sections
    parts = re.split(r'^## ', text, flags=re.MULTILINE)
    sections = []
    for part in parts[1:]:  # skip before first ##
        split = part.split('\n', 1)
        sec_title = split[0].strip()
        sec_body = split[1] if len(split) > 1 else ""
        sections.append({
            "title": sec_title,
            "html": md_body_to_html(sec_body),
        })

    # Extract highlights (numbered list items from ハイライト section)
    highlights = []
    for sec in sections:
        if 'ハイライト' in sec['title'] or '注目' in sec['title']:
            hl_matches = re.findall(r'^\d+\.\s+\*\*(.+?)\*\*\s*[—–-]\s*(.+)$',
                                     text, re.MULTILINE)
            if not hl_matches:
                hl_matches = re.findall(r'^\d+\.\s+(.+)$', text, re.MULTILINE)
                highlights = [m.strip() for m in hl_matches[:5]]
            else:
                highlights = [f"<strong>{m[0]}</strong> — {m[1]}" for m in hl_matches[:5]]
            break

    # Count articles (table rows with links, or bold-link list items)
    article_count = len(re.findall(r'\[([^\]]+)\]\(https?://[^)]+\)', text))

    return {
        "date": date_str,
        "title": title,
        "header_lines": header_lines,
        "sections": sections,
        "highlights": highlights,
        "article_count": article_count,
    }

digests = [parse_digest(f) for f in md_files]
total_articles = sum(d["article_count"] for d in digests)
avg_articles = round(total_articles / len(digests)) if digests else 0

# ============================================================
# Phase 2: HTML generation
# ============================================================

def build_tabs_html():
    tabs = []
    for i, d in enumerate(digests):
        active = ' active' if i == 0 else ''
        tabs.append(f'<button class="tab-btn{active}" data-date="{d["date"]}" onclick="switchTab(\'{d["date"]}\')">{d["date"]}</button>')
    return '\n'.join(tabs)

def build_panels_html():
    panels = []
    for i, d in enumerate(digests):
        display = 'block' if i == 0 else 'none'
        header_html = ''.join(f'<div class="meta-line">{md_inline(h)}</div>' for h in d["header_lines"])
        sections_html = ''.join(
            f'<div class="digest-section"><h2>{md_inline(s["title"])}</h2>{s["html"]}</div>'
            for s in d["sections"]
        )
        hl_html = ''
        if d["highlights"]:
            hl_items = ''.join(f'<li>{h}</li>' for h in d["highlights"])
            hl_html = f'<div class="highlights-card card"><h3>ハイライト</h3><ol>{hl_items}</ol></div>'

        panels.append(f'''<div id="digest-{d["date"]}" class="digest-panel" style="display:{display}">
<div class="digest-meta card">{header_html}
<div class="meta-line"><strong>記事数:</strong> {d["article_count"]}件</div></div>
{hl_html}
{sections_html}
</div>''')
    return '\n'.join(panels)

dates_json = ', '.join(f'"{d["date"]}"' for d in digests)
latest_date = digests[0]["date"] if digests else ""

html = f'''<!DOCTYPE html>
<html lang="ja">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>日次ダイジェスト — {org_slug}</title>
<style>
:root {{
  --bg: #f8f9fa; --card-bg: #fff; --text: #212529; --muted: #6c757d;
  --border: #dee2e6; --shadow: rgba(0,0,0,0.08);
  --blue: #0d6efd; --yellow: #ffc107; --red: #dc3545; --green: #198754;
  --accent: #4361ee;
}}
@media (prefers-color-scheme: dark) {{
  :root {{
    --bg: #1a1a2e; --card-bg: #16213e; --text: #e0e0e0; --muted: #9e9e9e;
    --border: #2a2a4a; --shadow: rgba(0,0,0,0.3);
    --blue: #4dabf7; --yellow: #ffd43b; --red: #ff6b6b; --green: #51cf66;
    --accent: #748ffc;
  }}
}}
* {{ margin:0; padding:0; box-sizing:border-box; }}
body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
       background: var(--bg); color: var(--text); padding: 24px; max-width: 1200px; margin: 0 auto; }}

/* Navigation */
.nav {{ display: flex; gap: 12px; margin-bottom: 20px; }}
.nav a {{ color: var(--blue); text-decoration: none; font-size: 0.85rem; }}
.nav a:hover {{ text-decoration: underline; }}

/* Header */
h1 {{ font-size: 1.5rem; margin-bottom: 4px; }}
.subtitle {{ color: var(--muted); font-size: 0.85rem; margin-bottom: 24px; }}

/* Summary cards */
.summary-grid {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(160px, 1fr)); gap: 12px; margin-bottom: 24px; }}
.summary-card {{ background: var(--card-bg); border: 1px solid var(--border);
                 border-radius: 12px; padding: 16px; box-shadow: 0 2px 8px var(--shadow); }}
.summary-label {{ font-size: 0.75rem; color: var(--muted); text-transform: uppercase; letter-spacing: 0.5px; }}
.summary-value {{ font-size: 1.8rem; font-weight: 700; margin-top: 2px; }}
.summary-value.blue {{ color: var(--blue); }}
.summary-value.green {{ color: var(--green); }}

/* Tab bar */
.tab-bar {{ display: flex; gap: 6px; overflow-x: auto; padding-bottom: 8px; margin-bottom: 24px;
            scrollbar-width: thin; -webkit-overflow-scrolling: touch; }}
.tab-btn {{ background: var(--card-bg); border: 1px solid var(--border); border-radius: 8px;
            padding: 8px 16px; font-size: 0.85rem; cursor: pointer; white-space: nowrap;
            color: var(--text); transition: all 0.2s; }}
.tab-btn:hover {{ border-color: var(--accent); }}
.tab-btn.active {{ background: var(--accent); color: #fff; border-color: var(--accent); }}

/* Cards */
.card {{ background: var(--card-bg); border: 1px solid var(--border);
         border-radius: 12px; padding: 20px; margin-bottom: 16px;
         box-shadow: 0 2px 8px var(--shadow); }}

/* Digest meta */
.digest-meta {{ margin-bottom: 16px; }}
.meta-line {{ font-size: 0.85rem; color: var(--muted); padding: 2px 0; }}

/* Highlights */
.highlights-card {{ border-left: 4px solid var(--accent); }}
.highlights-card h3 {{ font-size: 1rem; margin-bottom: 12px; color: var(--accent); }}
.highlights-card ol {{ padding-left: 20px; }}
.highlights-card li {{ margin-bottom: 8px; font-size: 0.9rem; line-height: 1.5; }}

/* Sections */
.digest-section {{ margin-bottom: 24px; }}
.digest-section h2 {{ font-size: 1.15rem; margin-bottom: 12px; padding-bottom: 8px;
                       border-bottom: 2px solid var(--border); }}
.digest-section h3 {{ font-size: 0.95rem; margin: 16px 0 8px 0; color: var(--muted); }}
.digest-section p {{ font-size: 0.9rem; line-height: 1.6; margin-bottom: 8px; }}
.digest-section ul {{ padding-left: 20px; margin-bottom: 12px; }}
.digest-section li {{ font-size: 0.9rem; line-height: 1.6; margin-bottom: 6px; }}
.digest-section blockquote {{ border-left: 3px solid var(--border); padding: 8px 16px;
                               margin: 8px 0; color: var(--muted); font-size: 0.85rem; }}
.digest-section hr {{ border: none; border-top: 1px solid var(--border); margin: 16px 0; }}

/* Tables */
.table-wrap {{ overflow-x: auto; margin: 8px 0 16px; }}
.table-wrap table {{ width: 100%; border-collapse: collapse; font-size: 0.85rem; }}
.table-wrap th {{ background: var(--border); padding: 8px 12px; text-align: left;
                  font-weight: 600; white-space: nowrap; }}
.table-wrap td {{ padding: 8px 12px; border-bottom: 1px solid var(--border);
                  vertical-align: top; }}
.table-wrap tr:hover td {{ background: rgba(67, 97, 238, 0.04); }}
.table-wrap a {{ color: var(--blue); text-decoration: none; }}
.table-wrap a:hover {{ text-decoration: underline; }}

/* Inline */
a {{ color: var(--blue); }}
code {{ background: var(--border); padding: 1px 5px; border-radius: 3px; font-size: 0.85em; }}
strong {{ font-weight: 600; }}

/* Footer */
.footer {{ margin-top: 40px; font-size: 0.78rem; color: var(--muted); text-align: center; }}

/* Responsive */
@media (max-width: 600px) {{
  body {{ padding: 16px; }}
  .summary-grid {{ grid-template-columns: repeat(2, 1fr); }}
  .tab-btn {{ padding: 6px 12px; font-size: 0.8rem; }}
}}
</style>
</head>
<body>

<div class="nav">
  <a href="../">← トップに戻る</a>
  <a href="../secretary/{org_slug}/dashboard.html">ダッシュボード →</a>
</div>

<h1>日次ダイジェスト</h1>
<p class="subtitle">{org_slug} ｜ 全{len(digests)}件 ｜ 最終更新: {now}</p>

<div class="summary-grid">
  <div class="summary-card">
    <div class="summary-label">総記事数</div>
    <div class="summary-value blue">{total_articles}</div>
  </div>
  <div class="summary-card">
    <div class="summary-label">最新日付</div>
    <div class="summary-value">{latest_date}</div>
  </div>
  <div class="summary-card">
    <div class="summary-label">ダイジェスト数</div>
    <div class="summary-value green">{len(digests)}</div>
  </div>
  <div class="summary-card">
    <div class="summary-label">平均記事数/日</div>
    <div class="summary-value">{avg_articles}</div>
  </div>
</div>

<div class="tab-bar">
{build_tabs_html()}
</div>

{build_panels_html()}

<div class="footer">
  Generated by cc-sier wf-daily-digest ｜ {now} ｜ ← → キーで日付切替
</div>

<script>
const dates = [{dates_json}];

function switchTab(date) {{
  document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
  document.querySelectorAll('.digest-panel').forEach(p => p.style.display = 'none');
  const btn = document.querySelector('.tab-btn[data-date="' + date + '"]');
  const panel = document.getElementById('digest-' + date);
  if (btn) btn.classList.add('active');
  if (panel) panel.style.display = 'block';
  history.replaceState(null, '', '#' + date);
  btn?.scrollIntoView({{ behavior: 'smooth', block: 'nearest', inline: 'center' }});
}}

// Init: hash or latest
const hash = location.hash.slice(1);
if (hash && dates.includes(hash)) switchTab(hash);

// Keyboard nav
document.addEventListener('keydown', e => {{
  const cur = document.querySelector('.tab-btn.active')?.dataset.date;
  const idx = dates.indexOf(cur);
  if (e.key === 'ArrowLeft' && idx < dates.length - 1) switchTab(dates[idx + 1]);
  if (e.key === 'ArrowRight' && idx > 0) switchTab(dates[idx - 1]);
}});
</script>

</body>
</html>'''

# ============================================================
# Phase 3: Write output
# ============================================================

output_path.parent.mkdir(parents=True, exist_ok=True)
output_path.write_text(html, encoding="utf-8")
size_kb = round(output_path.stat().st_size / 1024, 1)
print(f"Generated: {output_path} ({size_kb} KB, {len(digests)} digests, {total_articles} articles)")
PYEOF

# --- Update docs/index.html to add digest card ---
python3 - "$ORG_SLUG" <<'PYEOF2'
import sys, re
from pathlib import Path

org_slug = sys.argv[1]
index_path = Path("docs/index.html")
if not index_path.exists():
    print("docs/index.html not found, skipping card insertion")
    sys.exit(0)

html = index_path.read_text(encoding="utf-8", errors="ignore")

# Remove existing digest card if present
html = re.sub(r'\s*<a href="\./daily-digest/[^"]*"[^>]*class="card"[^>]*>.*?</a>',
              '', html, flags=re.DOTALL)

digest_card = '''
    <a href="./daily-digest/index.html" class="card" style="border:2px solid #198754;">
      <div class="org-name">日次ダイジェスト</div>
      <div class="org-label">技術・小売ニュース巡回 →</div>
    </a>'''

# Insert before closing </div> of .grid
html = re.sub(r'(</div>\s*<p class="updated")',
              f'{digest_card}\n\\1', html, count=1)

index_path.write_text(html, encoding="utf-8")
print("Updated: docs/index.html (digest card added)")
PYEOF2

echo "Done."
