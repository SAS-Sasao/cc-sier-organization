#!/usr/bin/env python3
"""
IaCコードビューアHTML生成スクリプト

CloudFormation YAMLファイルからシンタックスハイライト付きの
スタンドアロンHTMLビューアを生成する。

Usage:
    python3 generate-iac-viewer.py <yaml_file> <title> [--status Pass|Fail]

Example:
    python3 generate-iac-viewer.py docs/diagrams/serverless-web-app.yaml "Serverless Web App"
    python3 generate-iac-viewer.py docs/diagrams/foo.yaml "Foo Architecture" --status Fail

注意:
    - シェルスクリプト経由ではなく、必ず python3 で直接実行すること
    - bash ヒアドキュメント内での実行禁止（$1/$2 がシェル変数展開される）
"""

import json
import sys
import os
from datetime import date


def generate_iac_html(yaml_path: str, title: str, status: str = "Pass") -> str:
    """YAML ファイルからIaCビューアHTMLを生成する"""

    basename = os.path.splitext(os.path.basename(yaml_path))[0]

    with open(yaml_path, "r", encoding="utf-8") as f:
        yaml_content = f.read()

    line_count = len(yaml_content.splitlines())
    raw_json = json.dumps(yaml_content)
    today = date.today().isoformat()
    status_class = "pass" if status == "Pass" else "fail"

    # JavaScript の $1, $2 等はPython文字列内なのでシェル展開されない
    html = f'''<!DOCTYPE html>
<html lang="ja">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>{title} - IaC Source Code</title>
<style>
:root {{ --bg:#f8f9fa; --bg2:#fff; --text:#1a1a2e; --blue:#4361ee; --border:rgba(0,0,0,.08); --muted:#6c757d; --shadow:rgba(0,0,0,.06);
        --code-bg:#1e1e2e; --code-text:#cdd6f4; --line-num:#6c7086; --kw:#cba6f7; --str:#a6e3a1; --comment:#6c7086; --key:#89b4fa; --val:#fab387; --bool:#f38ba8; }}
@media (prefers-color-scheme: dark) {{
  :root {{ --bg:#0d1117; --bg2:#161b22; --text:#e6edf3; --border:rgba(255,255,255,.08); --muted:#8b949e; --shadow:rgba(0,0,0,.3); }}
}}
* {{ box-sizing:border-box; margin:0; padding:0; }}
body {{ background:var(--bg); color:var(--text); font-family:system-ui,sans-serif; padding:32px; max-width:1200px; margin:0 auto; }}
.top-bar {{ display:flex; flex-wrap:wrap; align-items:center; justify-content:space-between; margin-bottom:20px; gap:12px; }}
.back-btn {{ color:var(--blue); text-decoration:none; font-size:.88rem; }}
.back-btn:hover {{ text-decoration:underline; }}
.dl-btn {{ display:inline-block; padding:8px 16px; background:var(--blue); color:#fff; border-radius:8px; text-decoration:none; font-size:.84rem; font-weight:500; transition:opacity .2s; }}
.dl-btn:hover {{ opacity:.85; }}
.copy-btn {{ display:inline-flex; align-items:center; gap:6px; padding:6px 14px; background:rgba(255,255,255,.08); color:var(--code-text); border:1px solid rgba(255,255,255,.15); border-radius:6px; font-size:.78rem; font-family:inherit; cursor:pointer; transition:all .2s; }}
.copy-btn:hover {{ background:rgba(255,255,255,.15); }}
.copy-btn.copied {{ background:#16a34a; color:#fff; border-color:#16a34a; }}
.copy-btn svg {{ width:14px; height:14px; fill:currentColor; }}
h1 {{ font-size:1.3rem; margin-bottom:8px; }}
.meta {{ color:var(--muted); font-size:.85rem; margin-bottom:20px; display:flex; flex-wrap:wrap; gap:16px; align-items:center; }}
.badge {{ display:inline-block; padding:3px 10px; border-radius:4px; font-size:.75rem; font-weight:600; }}
.badge-pass {{ background:#d1fae5; color:#065f46; }}
.badge-fail {{ background:#fee2e2; color:#991b1b; }}
@media (prefers-color-scheme: dark) {{
  .badge-pass {{ background:#064e3b; color:#6ee7b7; }}
  .badge-fail {{ background:#7f1d1d; color:#fca5a5; }}
}}
.code-container {{ background:var(--code-bg); border-radius:12px; overflow:hidden; box-shadow:0 4px 16px var(--shadow); margin-bottom:24px; }}
.code-header {{ background:rgba(255,255,255,.05); padding:12px 20px; display:flex; justify-content:space-between; align-items:center; border-bottom:1px solid rgba(255,255,255,.08); }}
.code-header .filename {{ color:var(--code-text); font-size:.85rem; font-family:'SF Mono',Consolas,monospace; }}
.code-header .lines {{ color:var(--line-num); font-size:.78rem; }}
.code-scroll {{ overflow-x:auto; padding:16px 0; }}
.code-table {{ border-collapse:collapse; width:100%; }}
.code-table td {{ padding:0; vertical-align:top; font-family:'SF Mono',Consolas,'Courier New',monospace; font-size:.82rem; line-height:1.65; }}
.code-table .ln {{ width:1%; white-space:nowrap; padding:0 16px 0 20px; color:var(--line-num); text-align:right; user-select:none; border-right:1px solid rgba(255,255,255,.06); }}
.code-table .code {{ padding:0 20px; color:var(--code-text); white-space:pre; }}
.hl-comment {{ color:var(--comment); font-style:italic; }}
.hl-key {{ color:var(--key); }}
.hl-str {{ color:var(--str); }}
.hl-kw {{ color:var(--kw); }}
.hl-bool {{ color:var(--bool); }}
.hl-ref {{ color:#f9e2af; }}
.info {{ background:var(--bg2); border:1px solid var(--border); border-radius:12px; padding:20px; box-shadow:0 2px 8px var(--shadow); }}
.info h2 {{ font-size:1rem; margin-bottom:8px; }}
.info p {{ font-size:.88rem; color:var(--muted); line-height:1.6; }}
.updated {{ margin-top:24px; font-size:.78rem; color:var(--muted); }}
</style>
</head>
<body>
<div class="top-bar">
  <a href="./{basename}.html" class="back-btn">&larr; 構成図に戻る</a>
  <div><a href="./{basename}.yaml" class="dl-btn" download>YAMLをダウンロード</a></div>
</div>
<h1>{title} - CloudFormation Template</h1>
<div class="meta">
  <span>生成日: {today}</span>
  <span class="badge badge-{status_class}">検証: {status}</span>
  <span>{line_count} 行</span>
</div>
<div class="code-container">
  <div class="code-header">
    <span class="filename">{basename}.yaml</span>
    <div style="display:flex;align-items:center;gap:12px">
      <span class="lines">{line_count} lines</span>
      <button class="copy-btn" onclick="copyYaml(this)">
        <svg viewBox="0 0 24 24"><path d="M16 1H4c-1.1 0-2 .9-2 2v14h2V3h12V1zm3 4H8c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h11c1.1 0 2-.9 2-2V7c0-1.1-.9-2-2-2zm0 16H8V7h11v14z"/></svg>
        <span>Copy</span>
      </button>
    </div>
  </div>
  <div class="code-scroll"><table class="code-table"><tbody id="code-body"></tbody></table></div>
</div>
<div class="info">
  <h2>CloudFormation テンプレートについて</h2>
  <p>このテンプレートは構成図のアーキテクチャを CloudFormation で実装した参照コードです。
  サンプル値（<code># TODO</code> コメント付き）は実運用時に変更してください。
  暗号化・最小権限・パブリックアクセスブロックはデフォルトで有効化されています。</p>
</div>
<p class="updated">Powered by AWS IaC MCP Server</p>
<script>
const raw = {raw_json};
const lines = raw.split("\\n");
const tbody = document.getElementById("code-body");
lines.forEach((line, i) => {{
  const tr = document.createElement("tr");
  const lnTd = document.createElement("td");
  lnTd.className = "ln"; lnTd.textContent = i + 1;
  const codeTd = document.createElement("td");
  codeTd.className = "code"; codeTd.innerHTML = highlight(line);
  tr.appendChild(lnTd); tr.appendChild(codeTd); tbody.appendChild(tr);
}});
function copyYaml(btn) {{
  navigator.clipboard.writeText(raw).then(() => {{
    btn.classList.add("copied");
    btn.querySelector("span").textContent = "Copied!";
    btn.querySelector("svg").innerHTML = '<path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z"/>';
    setTimeout(() => {{
      btn.classList.remove("copied");
      btn.querySelector("span").textContent = "Copy";
      btn.querySelector("svg").innerHTML = '<path d="M16 1H4c-1.1 0-2 .9-2 2v14h2V3h12V1zm3 4H8c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h11c1.1 0 2-.9 2-2V7c0-1.1-.9-2-2-2zm0 16H8V7h11v14z"/>';
    }}, 2000);
  }});
}}
function highlight(line) {{
  let h = line.replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;");
  if (/^\\s*#/.test(h)) return '<span class="hl-comment">' + h + '</span>';
  h = h.replace(/(#.*)$/, '<span class="hl-comment">$1</span>');
  h = h.replace(/(!(?:Ref|Sub|GetAtt|Select|Join|If|Equals|FindInMap|Split|ImportValue|GetAZs|Condition|Not|And|Or))/g, '<span class="hl-ref">$1</span>');
  h = h.replace(/^(\\s*)(AWSTemplateFormatVersion|Description|Parameters|Mappings|Conditions|Resources|Outputs|Rules|Metadata|Transform)(:)/, '$1<span class="hl-kw">$2</span>$3');
  h = h.replace(/(AWS::[A-Za-z0-9]+::[A-Za-z0-9]+)/g, '<span class="hl-kw">$1</span>');
  h = h.replace(/^(\\s*)([A-Za-z_][A-Za-z0-9_]*)(:)/gm, '$1<span class="hl-key">$2</span>$3');
  return h;
}}
</script>
</body>
</html>'''
    return html


def main():
    if len(sys.argv) < 3:
        print("Usage: python3 generate-iac-viewer.py <yaml_file> <title> [--status Pass|Fail]")
        sys.exit(1)

    yaml_path = sys.argv[1]
    title = sys.argv[2]
    status = "Pass"

    if "--status" in sys.argv:
        idx = sys.argv.index("--status")
        if idx + 1 < len(sys.argv):
            status = sys.argv[idx + 1]

    if not os.path.exists(yaml_path):
        print(f"Error: {yaml_path} not found")
        sys.exit(1)

    basename = os.path.splitext(os.path.basename(yaml_path))[0]
    output_path = os.path.join(os.path.dirname(yaml_path), f"{basename}-iac.html")

    html = generate_iac_html(yaml_path, title, status)
    with open(output_path, "w", encoding="utf-8") as f:
        f.write(html)

    line_count = len(open(yaml_path).readlines())
    print(f"Generated: {output_path} ({line_count} lines of YAML)")


if __name__ == "__main__":
    main()
