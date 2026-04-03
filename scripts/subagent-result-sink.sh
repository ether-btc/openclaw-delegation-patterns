#!/bin/bash
#
# subagent-result-sink.sh
# ========================
# Result sink for subagents — enforces "orchestrator writes" mechanically.
# Subagents write HERE only. Orchestrator copies to workspace.
#
# Usage:
#   ./scripts/subagent-result-sink.sh --project <name> --phase <name> [--data '<json>']
#   ./scripts/subagent-result-sink.sh --project <name> --phase <name> --file <path>
#
# Output:
#   ~/.openclaw/workspace/results/<project>/<phase>.jsonl
#   Updates: memory/projects/<project>/checkpoint.json (files_created)
#
# Exit codes:
#   0 = success
#   1 = error (missing args, write failure)
#
# CONSTRAINT (embed in every subagent task prompt):
#   You may NOT use write/edit tools on any path under:
#     ~/.openclaw/workspace/
#   EXCEPT: You MAY write to: ~/.openclaw/workspace/results/<project>/
#   After completing work: write results to results/<project>/<phase>.jsonl
#   Then say "COMPLETE" — the orchestrator will read results/ and copy to workspace.

set -euo pipefail

# ─── Arguments ───────────────────────────────────────────────────────────────

PROJECT=""
PHASE=""
DATA=""
FILE_PATH=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --project)
            PROJECT="$2"
            shift 2
            ;;
        --phase)
            PHASE="$2"
            shift 2
            ;;
        --data)
            DATA="$2"
            shift 2
            ;;
        --file)
            FILE_PATH="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

# ─── Validate ─────────────────────────────────────────────────────────────────

if [[ -z "$PROJECT" || -z "$PHASE" ]]; then
    echo "Usage: $0 --project <name> --phase <name> [--data '<json>' | --file <path>]" >&2
    exit 1
fi

if [[ -z "$DATA" && -z "$FILE_PATH" ]]; then
    echo "ERROR: Either --data or --file required" >&2
    exit 1
fi

# ─── Paths ────────────────────────────────────────────────────────────────────

WORKSPACE="$HOME/.openclaw/workspace"
RESULT_DIR="$WORKSPACE/results/$PROJECT"
RESULT_FILE="$RESULT_DIR/${PHASE}.jsonl"
CHECKPOINT_FILE="$WORKSPACE/memory/projects/$PROJECT/checkpoint.json"

# ─── Create result directory ─────────────────────────────────────────────────

mkdir -p "$RESULT_DIR"

# Sanitize project and phase to prevent path traversal
PROJECT_SANITIZED=$(echo "$PROJECT" | sed 's/[^a-zA-Z0-9_-]/_/g')
if [[ "$PROJECT" != "$PROJECT_SANITIZED" ]]; then
    echo "WARNING: PROJECT sanitized: '$PROJECT' → '$PROJECT_SANITIZED'" >&2
    PROJECT="$PROJECT_SANITIZED"
fi
PHASE_SANITIZED=$(echo "$PHASE" | sed 's/[^a-zA-Z0-9_.-]/_/g')
if [[ "$PHASE" != "$PHASE_SANITIZED" ]]; then
    echo "WARNING: PHASE sanitized: '$PHASE' → '$PHASE_SANITIZED'" >&2
    PHASE="$PHASE_SANITIZED"
fi
RESULT_FILE="$RESULT_DIR/${PHASE}.jsonl"

# ─── Write data ──────────────────────────────────────────────────────────────

if [[ -n "$DATA" ]]; then
    # Validate JSON before writing
    if ! echo "$DATA" | jq . > /dev/null 2>&1; then
        echo "ERROR: --data is not valid JSON" >&2
        exit 1
    fi
    # Add timestamp if not present
    if ! echo "$DATA" | jq -e '.timestamp' > /dev/null 2>&1; then
        DATA=$(echo "$DATA" | jq --arg t "$(date -Iseconds)" '. + {timestamp: $t}')
    fi
    echo "$DATA" >> "$RESULT_FILE"
else
    # Copy from file
    if [[ ! -f "$FILE_PATH" ]]; then
        echo "ERROR: --file not found: $FILE_PATH" >&2
        exit 1
    fi
    # Each line of the file becomes a JSONL entry
    # shellcheck disable=SC2094  # FILE_PATH (input) ≠ RESULT_FILE (output)
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Try to parse as JSON; if not, wrap as string
        if echo "$line" | jq . > /dev/null 2>&1; then
            echo "$line" | jq --arg t "$(date -Iseconds)" '. + {timestamp: $t, _source: "'"$(basename "$FILE_PATH")"'"}' >> "$RESULT_FILE"
        fi
    done < "$FILE_PATH"
fi

# ─── Update checkpoint ────────────────────────────────────────────────────────

RESULT_REL="results/$PROJECT/${PHASE}.jsonl"

if [[ -f "$CHECKPOINT_FILE" ]]; then
    # Append result file to files_created if not already present (use --arg to handle any chars in path)
    if ! jq --arg f "$RESULT_REL" 'select(.files_created | index($f) | not) | .files_created += [$f]' \
        -- "$CHECKPOINT_FILE" > "${CHECKPOINT_FILE}.tmp" 2>/dev/null; then
        # If jq select returns empty (already present), just touch checkpoint
        touch "$CHECKPOINT_FILE"
    else
        mv "${CHECKPOINT_FILE}.tmp" "$CHECKPOINT_FILE"
    fi
else
    # No checkpoint yet — create minimal one
    cat > "$CHECKPOINT_FILE" << EOF
{
  "project": "$PROJECT",
  "created_at": "$(date -Iseconds)",
  "files_created": ["$RESULT_REL"],
  "state": "running"
}
EOF
fi

echo "Result sink: $RESULT_FILE ($(wc -l < "$RESULT_FILE") entries)"
