#!/bin/bash
#
# measure-failure-rate.sh
# Parse recent subagent sessions, detect failures, log metrics.
#
# Usage:
#   bash scripts/measure-failure-rate.sh            # all sessions
#   bash scripts/measure-failure-rate.sh --days 7   # last 7 days
#   bash scripts/measure-failure-rate.sh --model qwen3-coder
#
# Output: JSON to stdout + appends to memory/metrics/subagent-failure-rate.jsonl

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="$(cd "$SCRIPT_DIR/.." && pwd)"
METRICS_DIR="$WORKSPACE/memory/metrics"
SESSIONS_FILE="$HOME/.openclaw/agents/main/sessions/sessions.json"
SESSION_DIR="$HOME/.openclaw/agents/main/sessions"
METRICS_LOG="$METRICS_DIR/subagent-failure-rate.jsonl"

DAYS_BACK=0
MODEL_FILTER=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --days) DAYS_BACK="$2"; shift 2 ;;
        --model) MODEL_FILTER="$2"; shift 2 ;;
        --help|-h) echo "Usage: $0 [--days N] [--model MODEL]"; exit 0 ;;
        *) shift ;;
    esac
done

mkdir -p "$METRICS_DIR"

if [[ ! -f "$SESSIONS_FILE" ]]; then
    echo "{\"error\": \"sessions.json not found at $SESSIONS_FILE\"}" >&2
    exit 1
fi

# Calculate cutoff timestamp
SINCE_TS=0
if [[ "$DAYS_BACK" -gt 0 ]]; then
    SINCE_TS=$(date -d "$DAYS_BACK days ago" +%s 2>/dev/null || echo 0)
fi

export SESSIONS_FILE SESSION_DIR DAYS_BACK MODEL_FILTER SINCE_TS METRICS_LOG

python3 - <<'PYEOF'
import json, os
from datetime import datetime
from collections import defaultdict

SESSIONS_FILE = os.environ.get('SESSIONS_FILE', '')
SESSION_DIR = os.environ.get('SESSION_DIR', '')
SINCE_TS = int(os.environ.get('SINCE_TS', '0'))
MODEL_FILTER = os.environ.get('MODEL_FILTER', '')
DAYS_BACK = int(os.environ.get('DAYS_BACK', '0'))

with open(SESSIONS_FILE) as f:
    sessions = json.load(f)

subagents = {k: v for k, v in sessions.items() if 'subagent' in k}

filtered = {}
for key, val in subagents.items():
    updated_at = val.get('updatedAt', 0) / 1000
    if SINCE_TS > 0 and updated_at < SINCE_TS:
        continue
    model = val.get('model', '')
    if MODEL_FILTER and MODEL_FILTER not in model:
        continue
    filtered[key] = val

def detect_failures(session_id):
    """Returns list of failure type strings. Empty list = success."""
    failures = []
    path = os.path.join(SESSION_DIR, f"{session_id}.jsonl")
    if not os.path.exists(path):
        return ["FILE_NOT_FOUND"]
    try:
        with open(path) as f:
            content = f.read()
    except Exception as e:
        return [f"READ_ERROR({str(e)[:20]})"]
    lines = content.strip().split('\n') if content.strip() else []
    # Signal: compaction occurred
    if '"type": "compaction"' in content:
        cnt = content.count('"type": "compaction"')
        failures.append(f"COMPACTION({cnt})")
    # Signal: garbage output patterns
    if content.count('"-1"') > 5:
        failures.append("GARBLED(-1 spam)")
    if content.count('<system>') > 3 or content.count('<pre><code>') > 3:
        failures.append("GARBLED(nested tags)")
    # Signal: empty session
    if len(lines) < 3:
        failures.append("EMPTY_SESSION")
    # Signal: abort/truncation in last message
    for line in reversed(lines):
        try:
            obj = json.loads(line)
            if obj.get('type') == 'message':
                msg = obj.get('message', {})
                err = msg.get('errorMessage', '')
                stop = msg.get('stopReason', '')
                if 'abort' in err.lower() or 'abort' in stop.lower():
                    failures.append("ABORTED")
                elif 'length' in stop.lower():
                    failures.append("LENGTH_TRUNCATED")
                break
        except:
            pass
    return failures if failures else ["OK"]

total = len(filtered)
failed = 0
failure_types = defaultdict(int)
failure_models = defaultdict(lambda: {"total": 0, "failed": 0})
recent = []

for key, val in sorted(filtered.items(), key=lambda x: x[1].get('updatedAt', 0), reverse=True):
    session_id = val.get('sessionId', '')
    model = val.get('model', 'unknown')
    updated = val.get('updatedAt', 0)
    status = val.get('status', 'unknown')
    failures = detect_failures(session_id)
    is_fail = any(f != "OK" for f in failures)
    failure_models[model]["total"] += 1
    if is_fail:
        failed += 1
        failure_models[model]["failed"] += 1
        for f in failures:
            if f != "OK":
                failure_types[f] += 1
        recent.append({
            "session_id": session_id[-8:],
            "model": model.split('/')[-1],
            "status": status,
            "failures": [f for f in failures if f != "OK"],
            "updated": datetime.fromtimestamp(updated/1000).isoformat() if updated else None,
        })

result = {
    "timestamp": datetime.now().isoformat(),
    "total": total,
    "successful": total - failed,
    "failed": failed,
    "failure_rate_pct": round(failed / total * 100, 1) if total > 0 else 0.0,
    "failures_by_type": dict(failure_types),
    "failures_by_model": {k: dict(v) for k, v in failure_models.items()},
    "recent_failures": recent[:10],
    "model_filter": MODEL_FILTER or "all",
    "days_back": DAYS_BACK,
}

METRICS_LOG = os.environ.get('METRICS_LOG', '/tmp/failure-rate.jsonl')
print(json.dumps(result, indent=2))
with open(METRICS_LOG, 'a') as f:
    f.write(json.dumps(result) + '\n')
PYEOF

echo "Metrics appended to: $METRICS_LOG"
