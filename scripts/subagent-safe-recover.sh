#!/bin/bash
#==============================================================================
# Subagent Safe Recovery — Orchestrator Result Extraction
#==============================================================================
# Primary recovery path for subagent output after completion event or death.
# Combines: result sink (authoritative) + transcript recovery + file audit.
#
# Usage:
#   subagent-safe-recover.sh <project_dir> <session_key> [transcript_path]
#
# Exit codes:
#   0 — output recovered (always check stdout)
#   1 — partial or no output (check stderr for details)
#
# Output:
#   stdout: recovered content (best effort)
#   stderr: recovery diagnostics
#
# Environment:
#   WORKSPACE         — workspace root
#   RESULT_SINK_FILE  — override sink path (default: <project>/results/sink.jsonl)
#==============================================================================

set -euo pipefail

WORKSPACE="${WORKSPACE:-~/agent-workspace}"
PROJECT_DIR="${1:-}"
SESSION_KEY="${2:-}"
TRANSCRIPT_FILE="${3:-}"

if [[ -z "$PROJECT_DIR" ]]; then
    echo "Error: project_dir required" >&2
    exit 1
fi

# ---- Determine paths --------------------------------------------------------
SINK_FILE="${RESULT_SINK_FILE:-${PROJECT_DIR}/results/sink.jsonl}"
TRANSCRIPT=""
if [[ -z "$TRANSCRIPT_FILE" && -n "$SESSION_KEY" ]]; then
    # Try to resolve transcript path from session key
    SESSIONS_FILE="${HOME}/.openclaw/agents/main/sessions/sessions.json"
    if [[ -f "$SESSIONS_FILE" ]]; then
        TRANSCRIPT=$(jq -r --arg key "$SESSION_KEY" \
            '.[$key].transcriptPath // empty' "$SESSIONS_FILE" 2>/dev/null || true)
    fi
elif [[ -n "$TRANSCRIPT_FILE" ]]; then
    TRANSCRIPT="$TRANSCRIPT_FILE"
fi

echo "[Safe recovery: sink=${SINK_FILE}]" >&2
[[ -n "$TRANSCRIPT" ]] && echo "[Safe recovery: transcript=${TRANSCRIPT}]" >&2

output=""
recovery_status="unknown"

# ---- Layer 1: Result sink (authoritative for completed phases) -------------
if [[ -f "$SINK_FILE" ]]; then
    echo "[Safe recovery: reading result sink]" >&2

    # Read all completed phases (status != "final")
    completed=$(jq -r 'select(.status == "complete") | .content' "$SINK_FILE" 2>/dev/null | grep -v '^null$' || true)
    final=$(jq -r 'select(.status == "final") | .content' "$SINK_FILE" 2>/dev/null | grep -v '^null$' | tail -1 || true)

    if [[ -n "$final" ]]; then
        output="$final"
        recovery_status="sink-final"
        echo "[Safe recovery: found final in sink]" >&2
    elif [[ -n "$completed" ]]; then
        output="$completed"
        recovery_status="sink-partial"
        echo "[Safe recovery: found partial in sink (no final)]" >&2
    else
        # Sink exists but all entries null (subagent wrote but content was empty)
        recovery_status="sink-empty"
        echo "[Safe recovery: sink exists but all content null]" >&2
    fi
else
    echo "[Safe recovery: no sink file found]" >&2
fi

# ---- Layer 2: Transcript recovery (fallback) ---------------------------------
if [[ -z "$output" && -n "$TRANSCRIPT" && -f "$TRANSCRIPT" ]]; then
    echo "[Safe recovery: falling back to transcript]" >&2

    # Use subagent-recover-transcript.sh
    if transcript_output=$("${WORKSPACE}/scripts/subagent-recover-transcript.sh" "$TRANSCRIPT" /dev/stderr 2>&1); then
        if [[ -n "$transcript_output" ]]; then
            output="$transcript_output"
            recovery_status="${recovery_status}+transcript"
            echo "[Safe recovery: transcript recovery succeeded]" >&2
        fi
    else
        echo "[Safe recovery: transcript recovery failed or found nothing]" >&2
    fi
fi

# ---- Layer 3: File write audit (tertiary fallback) --------------------------
if [[ -z "$output" ]]; then
    echo "[Safe recovery: falling back to file write audit]" >&2

    if audit_output=$("${WORKSPACE}/scripts/file-write-audit.sh" "$PROJECT_DIR" 2>&1); then
        if [[ -n "$audit_output" ]]; then
            output="[File write audit results]\n$audit_output"
            recovery_status="${recovery_status}+audit"
            echo "[Safe recovery: file audit produced results]" >&2
        fi
    fi
fi

# ---- Final verdict ----------------------------------------------------------
if [[ -n "$output" ]]; then
    echo "[Safe recovery: status=${recovery_status}]" >&2
    printf '%s' "$output"
    exit 0
else
    echo "[Safe recovery: COMPLETELY FAILED — no output from any layer]" >&2
    echo "[Safe recovery: consider respawning subagent]" >&2
    exit 1
fi
