#!/bin/bash
#==============================================================================
# Subagent Transcript Recovery — Extract Output from Dead Subagent
#==============================================================================
# Recovers the final output from a subagent transcript.
# Handles TWO formats:
#   1. Raw JSONL transcript (from sessions/*.jsonl files) — preferred, always complete
#   2. sessions_history JSON output (from sessions_history tool) — can be truncated
#
# Usage:
#   subagent-recover-transcript.sh <transcript_file> [output_file]
#
# Exit codes:
#   0  — output recovered (result found)
#   1  — no structured result found (check stderr)
#
# Extraction strategy (in order):
#   1. Look for explicit result markers: "Final:", "Result:", "Verdict:", "Summary:"
#   2. Look for last assistant message with stopReason="stop" + text content
#   3. Look for last assistant message with stopReason="toolUse" + substantial text (>=100 chars)
#   4. Report failure with diagnostic info
#
# IMPORTANT: Prefer raw JSONL over sessions_history output. sessions_history
#   can return truncated transcripts (truncated: true / contentTruncated: true).
#   Raw JSONL files are always complete.
#==============================================================================

set -euo pipefail

TRANSCRIPT_FILE="${1:-}"
OUTPUT_FILE="${2:-/dev/stdout}"
WORKSPACE="${WORKSPACE:-~/agent-workspace}"

if [[ -z "$TRANSCRIPT_FILE" || ! -f "$TRANSCRIPT_FILE" ]]; then
    echo "Error: valid transcript file required as first argument" >&2
    exit 1
fi

# Detect format: raw JSONL vs sessions_history JSON
# raw JSONL: first line has .type field (e.g. {"type":"session",...})
# sessions_history JSON: first line has .messages field
detect_format() {
    local first_line
    first_line=$(head -1 "$TRANSCRIPT_FILE" 2>/dev/null || echo "")
    if echo "$first_line" | jq -e '.messages != null' >/dev/null 2>&1; then
        echo "sessions_history"
    elif echo "$first_line" | jq -e '.type != null' >/dev/null 2>&1; then
        echo "raw_jsonl"
    else
        echo "unknown"
    fi
}

FORMAT=$(detect_format "$TRANSCRIPT_FILE")
echo "[Transcript recovery: format=${FORMAT}, file=${TRANSCRIPT_FILE}]" >&2

# Write python extractor to temp file (can't use heredoc with sys.argv)
EXTRACTOR_PY=$(mktemp /tmp/transcript-extractor-XXXXXX.py)
trap 'rm -f "$EXTRACTOR_PY"' EXIT

cat > "$EXTRACTOR_PY" << 'PYEOF'
import json, sys, re

transcript_path = sys.argv[1]
output_path = sys.argv[2] if len(sys.argv) > 2 else None

is_sessions_history = False
assistant_with_text = []

# Read all lines
with open(transcript_path) as f:
    lines = [line.rstrip('\n') for line in f]

first_line = lines[0].strip() if lines else ''

# Detect: sessions_history JSON has .messages at top level
first_obj = json.loads(first_line)
if isinstance(first_obj, dict) and 'messages' in first_obj:
    # sessions_history format — single JSON object with .messages array
    is_sessions_history = True
    data = first_obj
    entries = data.get('messages', [])
    if data.get('truncated'):
        print(f"[WARNING: transcript truncated — {data.get('bytes','?')} bytes]", file=sys.stderr)
elif isinstance(first_obj, dict) and 'type' in first_obj:
    # Raw JSONL — one JSON object per line
    entries = []
    for line in lines:
        line = line.strip()
        if not line:
            continue
        try:
            entries.append(json.loads(line))
        except json.JSONDecodeError:
            pass
else:
    print("Error: unrecognised transcript format", file=sys.stderr)
    sys.exit(1)

if is_sessions_history:
    # sessions_history format: messages have role/content/stopReason directly
    for m in entries:
        if not isinstance(m, dict):
            continue
        kind = m.get('__openclaw', {}).get('kind', '')
        if kind == 'compaction':
            continue
        role = m.get('role', '')
        if role != 'assistant':
            continue
        content = m.get('content', [])
        texts = [c.get('text', '') for c in content if c.get('type') == 'text']
        if texts:
            assistant_with_text.append({
                'id': m.get('__openclaw', {}).get('id', '?'),
                'seq': m.get('__openclaw', {}).get('seq'),
                'stopReason': m.get('stopReason'),
                'full_text': '\n'.join(texts),
                'first_line': texts[0].lstrip() if texts else ''
            })
else:
    # raw JSONL format: entries have type/message/role nesting
    for e in entries:
        if not isinstance(e, dict):
            continue
        if e.get('type') != 'message':
            continue
        msg = e.get('message', {})
        if msg.get('role') != 'assistant':
            continue
        content = msg.get('content', [])
        texts = [c.get('text', '') for c in content if c.get('type') == 'text']
        if texts:
            assistant_with_text.append({
                'id': e.get('id', '?'),
                'stopReason': msg.get('stopReason'),
                'full_text': '\n'.join(texts),
                'first_line': texts[0].lstrip() if texts else ''
            })

print(f"[Extractor: {len(assistant_with_text)} assistant messages with text]", file=sys.stderr)

if not assistant_with_text:
    print("Error: no assistant text messages found in transcript", file=sys.stderr)
    sys.exit(1)

# Pattern 1: explicit result markers
MARKERS = ['^(Final|Result|Verdict|Summary|Completion Report|### )']
for m in assistant_with_text:
    for marker in MARKERS:
        if re.match(marker, m['first_line'], re.IGNORECASE):
            result = m['full_text']
            print(f"[Match: pattern=explicit_marker id={m['id']} len={len(result)}]", file=sys.stderr)
            with open(output_path, 'w') if output_path and output_path != '/dev/stdout' else sys.stdout as f:
                f.write(result)
            sys.exit(0)

# Pattern 2: last stopReason=stop with text
for m in reversed(assistant_with_text):
    if m['stopReason'] == 'stop' and m['full_text'].strip():
        result = m['full_text']
        print(f"[Match: pattern=stop_with_text id={m['id']} len={len(result)}]", file=sys.stderr)
        with open(output_path, 'w') if output_path and output_path != '/dev/stdout' else sys.stdout as f:
            f.write(result)
        sys.exit(0)

# Pattern 3: last substantial text (>=100 chars), stopReason=toolUse
for m in reversed(assistant_with_text):
    if m['stopReason'] in ('toolUse', None) and len(m['full_text']) >= 100:
        result = m['full_text']
        print(f"[Match: pattern=substantial_text id={m['id']} stopReason={m['stopReason']} len={len(result)}]", file=sys.stderr)
        with open(output_path, 'w') if output_path and output_path != '/dev/stdout' else sys.stdout as f:
            f.write(result)
        sys.exit(0)

print("Error: no structured result found", file=sys.stderr)
sys.exit(1)
PYEOF

# Run the extractor
python3 "$EXTRACTOR_PY" "$TRANSCRIPT_FILE" "$OUTPUT_FILE"