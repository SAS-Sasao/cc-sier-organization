#!/usr/bin/env bash
# .claude/hooks/enrich-case-bank.sh
#
# 会話ログから意図・フレーズ・パターンを抽出して Case Bank を補強する
# /company-evolve から source して enrich_case_bank 関数を呼び出す

set -uo pipefail

enrich_case_bank() {
  local org_slug="$1"
  local conv_log_dir=".companies/${org_slug}/.conversation-log"
  local case_bank=".companies/${org_slug}/.case-bank/index.json"
  local enrich_log=".companies/${org_slug}/.case-bank/enrich-log.json"

  command -v python3 &>/dev/null || return 0
  [[ -f "$case_bank" ]] || return 0
  [[ -d "$conv_log_dir" ]] || return 0

  python3 - "$conv_log_dir" "$case_bank" "$enrich_log" "$org_slug" <<'PYEOF'
import sys, json, re
from pathlib import Path
from collections import defaultdict, Counter
from datetime import datetime

conv_dir    = Path(sys.argv[1])
cb_path     = Path(sys.argv[2])
enrich_path = Path(sys.argv[3])
org_slug    = sys.argv[4]

# ================================================================
# Case Bank 読み込み
# ================================================================
cb_data = json.loads(cb_path.read_text(encoding="utf-8"))
cases = cb_data.get("cases", [])
case_by_date = defaultdict(list)
for c in cases:
    date = c.get("outcome", {}).get("started", "")[:10]
    if date:
        case_by_date[date].append(c)

# ================================================================
# enrich-log（処理済みファイルの管理）
# ================================================================
enrich_log = {"processed": []}
if enrich_path.exists():
    try:
        enrich_log = json.loads(enrich_path.read_text(encoding="utf-8"))
    except Exception:
        pass
processed_files = set(enrich_log.get("processed", []))

# ================================================================
# 会話ログを走査
# ================================================================
all_human_messages = []
phrase_counter = Counter()
intent_patterns = []
workflow_candidates = []

new_processed = []

for md_file in sorted(conv_dir.glob("*.md")):
    if md_file.name in processed_files:
        continue
    new_processed.append(md_file.name)

    text = md_file.read_text(encoding="utf-8", errors="ignore")

    # frontmatter からセッション日付を取得
    date_match = re.search(r'^date:\s*"?([^"\n]+)"?', text, re.MULTILINE)
    session_date = date_match.group(1) if date_match else ""

    # Human の発言を抽出
    human_sections = re.findall(r'## 👤 Human\n\n(.*?)(?=\n---|\Z)', text, re.DOTALL)
    for section in human_sections:
        clean = section.strip()
        if len(clean) < 5:
            continue
        all_human_messages.append({
            "text": clean[:200],
            "date": session_date,
        })

        # フレーズ抽出（日本語の典型的な指示パターン）
        phrases = re.findall(
            r'[\u3040-\u9fff\u4e00-\u9faf]{4,}(?:して|してほしい|したい|お願い|を作|を生成|を実行)',
            clean
        )
        for ph in phrases:
            phrase_counter[ph] += 1

        # 意図パターンの抽出
        # 「〜について」「〜を〜して」などの構造
        intent = re.match(r'^(.{10,60}?)(?:してほしい|したい|お願い|をやって)', clean)
        if intent:
            intent_patterns.append({
                "intent": intent.group(1).strip(),
                "full": clean[:100],
                "date": session_date,
            })

# ================================================================
# Case Bank エントリに会話情報を付加
# ================================================================
enriched_count = 0

for case in cases:
    if case.get("conversation_enriched"):
        continue

    case_date = case.get("outcome", {}).get("started", "")[:10]
    case_request = case.get("state", {}).get("request_head", "")
    case_keywords = set(case.get("state", {}).get("request_keywords", []))

    # 同日の会話から関連メッセージを検索
    related_messages = []
    for msg in all_human_messages:
        if msg["date"] != case_date:
            continue
        msg_text = msg["text"]
        # キーワードの重複率でマッチング
        msg_words = set(re.findall(r'[\u3040-\u9fff\u4e00-\u9faf\w]{2,}', msg_text))
        overlap = len(case_keywords & msg_words) / max(len(case_keywords), 1)
        if overlap >= 0.3 or (case_request and case_request[:10] in msg_text):
            related_messages.append(msg_text[:150])

    if related_messages:
        case["conversation_context"] = related_messages[:3]
        case["conversation_enriched"] = True
        enriched_count += 1

# ================================================================
# よく使うフレーズのトップ10を case_bank のメタデータに追加
# ================================================================
top_phrases = [
    {"phrase": ph, "count": cnt}
    for ph, cnt in phrase_counter.most_common(10)
    if cnt >= 2
]

cb_data["frequent_phrases"] = top_phrases
cb_data["intent_patterns"] = intent_patterns[:20]
cb_data["conversation_enriched_at"] = datetime.now().isoformat(timespec="seconds")
cb_data["cases"] = cases

# ================================================================
# 保存
# ================================================================
cb_path.write_text(json.dumps(cb_data, ensure_ascii=False, indent=2), encoding="utf-8")

enrich_log["processed"].extend(new_processed)
enrich_log["last_run"] = datetime.now().isoformat(timespec="seconds")
enrich_log["total_messages_analyzed"] = len(all_human_messages)
enrich_log["enriched_cases"] = enriched_count
enrich_log["top_phrases"] = top_phrases

enrich_path.parent.mkdir(parents=True, exist_ok=True)
enrich_path.write_text(json.dumps(enrich_log, ensure_ascii=False, indent=2), encoding="utf-8")

print(f"[enrich] 会グ: {len(new_processed)}件処理")
print(f"[enrich] Case Bankエントリ強化: {enriched_count}件")
print(f"[enrich] 頻出フレーズ: {len(top_phrases)}件")
if top_phrases:
    for p in top_phrases[:3]:
        print(f"  - 「{p['phrase']}」({p['count']}回)")

PYEOF
}
