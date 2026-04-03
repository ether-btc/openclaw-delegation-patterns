#!/bin/bash
#
# timeout-recovery.sh
# ====================
# Handles timeout escalation: retry at 2x → orchestrator takeover → exhausted
# Uses atomic flock operations on checkpoint to prevent race conditions.
#
# Escalation states:
#   retry_count == 0 → FIRST TIMEOUT  → retry at 2x (max 480s) → exit 0
#   retry_count == 1 → SECOND TIMEOUT → orchestrator takes over  → exit 2
#   retry_count >= 2 → EXHAUSTED      → orchestrator completes   → exit 3
#
# Exit codes:
#   0 = retry spawned successfully
#   2 = ORCHESTRATOR TAKEOVER (second timeout — orchestrator must act)
#   3 = ESCALATION EXHAUSTED (orchestrator must complete directly)
#
# Usage:
#   timeout-recovery.sh \
#     --project PROJECT \
#     --session-id SESSION_ID \
#     --checkpoint CHECKPOINT_FILE \
#     [--timeout SECONDS]
#
# Reset (call after successful subagent completion):
#   timeout-recovery.sh --project PROJECT --checkpoint C --reset

set -euo pipefail

# ─── Constants ────────────────────────────────────────────────────────────────
MAX_TIMEOUT=480   # per DELEGATION_CORE.md — absolute max for any subagent task
LOCK_WAIT=5       # seconds to wait for checkpoint lock

# ─── Arguments ────────────────────────────────────────────────────────────────

PROJECT=""
SESSION_ID=""
CHECKPOINT_FILE=""
TIMEOUT=""
RESET=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --project)     PROJECT="$2";        shift 2 ;;
        --session-id) SESSION_ID="$2";      shift 2 ;;
        --checkpoint) CHECKPOINT_FILE="$2"; shift 2 ;;
        --timeout)    TIMEOUT="$2";         shift 2 ;;
        --reset)      RESET=true;           shift   ;;
        *)            echo "Unknown: $1";   exit 1  ;;
    esac
done

# ─── Logging ──────────────────────────────────────────────────────────────────

log_json() {
    # Structured JSON log — always write to stderr (stdout is for session ID)
    local level="$1"; shift
    local msg="$*"
    echo "{\"ts\":\"$(date -Iseconds)\",\"project\":\"$PROJECT\",\"level\":\"$level\",\"msg\":$(jq -n --arg m "$msg" '$m')}" >&2
}

log() { log_json "INFO" "$@"; }
log_warn() { log_json "WARN" "$@"; }
log_error() { log_json "ERROR" "$@"; }

# ─── Validate ─────────────────────────────────────────────────────────────────

if [[ -z "$PROJECT" || -z "$CHECKPOINT_FILE" ]]; then
    echo "Usage: $0 --project P --checkpoint C [--session-id S] [--timeout N] [--reset]" >&2
    exit 1
fi

WORKSPACE="$HOME/.openclaw/workspace"
PROJECT_DIR="$WORKSPACE/memory/projects/$PROJECT"
PROGRESS_FILE="$PROJECT_DIR/progress.md"

# ─── Reset ───────────────────────────────────────────────────────────────────
# Call with --reset after successful completion or explicit abort.
# Clears retry_count so future tasks are not blocked.

if [[ "$RESET" == "true" ]]; then
    RESET_BEFORE="unknown"
    (
        flock -x -w "$LOCK_WAIT" 200 || { echo "LOCK_FAILED" >&2; exit 1; }
        if [[ -f "$CHECKPOINT_FILE" ]]; then
            RESET_BEFORE=$(jq -r '.timeout.retry_count // -1' "$CHECKPOINT_FILE")
            jq '.timeout.retry_count = 0 | .timeout.escalation = "RETRY" | .timeout.triggered = false | .orchestrator_takeover = false' \
                "$CHECKPOINT_FILE" > "${CHECKPOINT_FILE}.tmp" && mv "${CHECKPOINT_FILE}.tmp" "$CHECKPOINT_FILE"
        fi
    ) 200>>"$CHECKPOINT_FILE"
    echo "{\"ts\":\"$(date -Iseconds)\",\"project\":\"$PROJECT\",\"level\":\"INFO\",\"msg\":\"Reset timeout.retry_count: $RESET_BEFORE → 0\"}" >&2
    exit 0
fi

# ─── Main escalation path ──────────────────────────────────────────────────────

if [[ -z "$SESSION_ID" ]]; then
    echo "Usage: --session-id required for escalation" >&2
    exit 1
fi

# Atomic read → enforce → write
escalation_result=$(
    (
        flock -x -w "$LOCK_WAIT" 200 || { echo "LOCK_FAILED"; exit 0; }

        # ── Read checkpoint ──────────────────────────────────────────────────
        if [[ ! -f "$CHECKPOINT_FILE" ]]; then
            log_warn "Checkpoint missing: $CHECKPOINT_FILE — treating as retry_count=0"
            echo "RETRY_COUNT=0"
            echo "ESCALATION=RETRY"
            echo "ORIGINAL_TIMEOUT=300"
            echo "ACTION=RETRY"
            exit 0
        fi

        # Backward compat: migrate legacy recovery.retry_count if needed
        if ! jq -e '.timeout.retry_count' "$CHECKPOINT_FILE" > /dev/null 2>&1; then
            legacy_migration=$(jq -r '.recovery.retry_count // 0' "$CHECKPOINT_FILE")
            jq ".timeout //= {} | .timeout.retry_count = $legacy_migration | .timeout.escalation = \"RETRY\"" \
                "$CHECKPOINT_FILE" > "${CHECKPOINT_FILE}.tmp" && mv "${CHECKPOINT_FILE}.tmp" "$CHECKPOINT_FILE"
            log_warn "Migrated legacy retry_count=$legacy_migration to timeout.retry_count"
        fi

        RETRY_COUNT=$(jq -r '.timeout.retry_count // 0' "$CHECKPOINT_FILE")
        ORIGINAL_TIMEOUT=$(jq -r '.timeout.original_timeout_seconds // 0' "$CHECKPOINT_FILE")
        ESCALATION=$(jq -r '.timeout.escalation // "RETRY"' "$CHECKPOINT_FILE")

        echo "RETRY_COUNT=$RETRY_COUNT"
        echo "ESCALATION=$ESCALATION"
        echo "ORIGINAL_TIMEOUT=$ORIGINAL_TIMEOUT"

        # ── Enforce escalation tier ─────────────────────────────────────────

        if [[ "$RETRY_COUNT" -ge 2 || "$ESCALATION" == "EXHAUSTED" ]]; then
            # Tier 3: Exhausted
            jq '.timeout.escalation = "EXHAUSTED" | .timeout.retry_count += 1' \
                "$CHECKPOINT_FILE" > "${CHECKPOINT_FILE}.tmp" && mv "${CHECKPOINT_FILE}.tmp" "$CHECKPOINT_FILE"
            log_error "ESCALATION EXHAUSTED — retry_count=$RETRY_COUNT — orchestrator must complete"
            echo "ACTION=EXHAUSTED"
            exit 0
        fi

        if [[ "$RETRY_COUNT" -eq 1 || "$ESCALATION" == "ORCHESTRATOR_TAKEOVER" ]]; then
            # Tier 2: Second timeout — orchestrator takeover
            # Write durable ORCHESTRATOR_TAKEOVER flag BEFORE exiting
            jq '.timeout.escalation = "ORCHESTRATOR_TAKEOVER" | .timeout.retry_count = 2 | .orchestrator_takeover = true' \
                "$CHECKPOINT_FILE" > "${CHECKPOINT_FILE}.tmp" && mv "${CHECKPOINT_FILE}.tmp" "$CHECKPOINT_FILE"
            log_warn "SECOND TIMEOUT — ORCHESTRATOR_TAKEOVER written to checkpoint — exiting 2"
            echo "ACTION=ORCHESTRATOR_TAKEOVER"
            exit 0
        fi

        # Tier 1: First timeout — retry at 2x
        CURRENT_TIMEOUT="${TIMEOUT:-$ORIGINAL_TIMEOUT}"
        if [[ "$CURRENT_TIMEOUT" -eq 0 ]]; then
            CURRENT_TIMEOUT=300
        fi

        # Preserve original timeout for potential future resets
        if [[ "$ORIGINAL_TIMEOUT" -eq 0 ]]; then
            ORIGINAL_TIMEOUT=$CURRENT_TIMEOUT
        fi

        NEW_TIMEOUT=$((CURRENT_TIMEOUT * 2))
        [[ "$NEW_TIMEOUT" -gt $MAX_TIMEOUT ]] && NEW_TIMEOUT=$MAX_TIMEOUT

        jq --arg new_t "$NEW_TIMEOUT" --arg orig_t "$ORIGINAL_TIMEOUT" \
            '.timeout.escalation = "RETRY" | .timeout.retry_count = 1 |
             .timeout.original_timeout_seconds = (if (.timeout.original_timeout_seconds | tonumber) == 0 then ($orig_t | tonumber) else .timeout.original_timeout_seconds end) |
             .timeout.time_remaining_seconds = ($new_t | tonumber) | .timeout.triggered = true' \
            "$CHECKPOINT_FILE" > "${CHECKPOINT_FILE}.tmp" && mv "${CHECKPOINT_FILE}.tmp" "$CHECKPOINT_FILE"

        log "FIRST TIMEOUT — retry_count=0→1, timeout ${CURRENT_TIMEOUT}s → ${NEW_TIMEOUT}s (2x, max 480s)"
        echo "NEW_TIMEOUT=$NEW_TIMEOUT"
        echo "ACTION=RETRY"
        exit 0

    ) 200>>"$CHECKPOINT_FILE"
)

# Parse escalation result
eval "$escalation_result"

# ─── Route on action ──────────────────────────────────────────────────────────

case "$ACTION" in
    LOCK_FAILED)
        log_error "Could not acquire checkpoint lock — giving up"
        exit 3
        ;;
    EXHAUSTED)
        log_json "INFO" "{\"action\":\"exhausted\",\"retry_count\":$RETRY_COUNT}"
        exit 3
        ;;
    ORCHESTRATOR_TAKEOVER)
        log_json "INFO" "{\"action\":\"orchestrator_takeover\",\"checkpoint\":\"$CHECKPOINT_FILE\"}"
        exit 2
        ;;
    RETRY)
        if [[ -z "${NEW_TIMEOUT:-}" ]]; then
            log_error "RETRY action but NEW_TIMEOUT not set"
            exit 3
        fi
        ;;
esac

# ─── Kill subagent ─────────────────────────────────────────────────────────────

log "Killing subagent $SESSION_ID..."
subagents kill "$SESSION_ID" 2>/dev/null || log_warn "Subagent $SESSION_ID already gone"

# ─── Update progress ─────────────────────────────────────────────────────────

mkdir -p "$PROJECT_DIR"
cat > "$PROGRESS_FILE" << EOF
# Task: $(jq -r '.task' "$CHECKPOINT_FILE" 2>/dev/null || echo "Unknown")
## Status
- State: RETRY_PENDING
- Updated: $(date -Iseconds)
- retry_count: 1
- New timeout: ${NEW_TIMEOUT}s
- Escalation: RETRY (2x)
## Recovery
- Original session: $SESSION_ID
- Retrying at ${NEW_TIMEOUT}s (2x)
EOF

# ─── Spawn recovery subagent ────────────────────────────────────────────────

AGENT_ID=$(jq -r '.agent_id // "kimik2thinking"' "$CHECKPOINT_FILE" 2>/dev/null || echo "kimik2thinking")
log "Spawning recovery subagent: $AGENT_ID timeout ${NEW_TIMEOUT}s..."

RECOVERY_TASK="## Recovery Task: Resume from Checkpoint

Project: $PROJECT
Checkpoint: $CHECKPOINT_FILE
Timeout: ${NEW_TIMEOUT}s (2x from original)

**Rules:**
1. \`cat $CHECKPOINT_FILE | jq '.'\` — read state
2. Resume from progress.phase / progress.step / progress.percent
3. Update progress.md every 2 minutes (MANDATORY)
4. Write outputs to: $PROJECT_DIR/
5. Say COMPLETE when done

**Checkpoint state:**
- phase: \$(jq -r '.progress.phase' '$CHECKPOINT_FILE')
- step: \$(jq -r '.progress.step' '$CHECKPOINT_FILE')
- percent: \$(jq -r '.progress.percent' '$CHECKPOINT_FILE')

**⚠️ This is a timeout retry. Resume from checkpoint — do not restart.**"

SESSION_OUTPUT=$(sessions_spawn \
    agentId:"$AGENT_ID" \
    --task "$RECOVERY_TASK" \
    --cwd "$PROJECT_DIR" \
    --timeout "$NEW_TIMEOUT" \
    --cleanup delete \
    2>&1)

NEW_SESSION_ID=$(echo "$SESSION_OUTPUT" | grep -oP '(?<=sessionId["\s:]+)[a-f0-9-]+' || echo "")

if [[ -z "$NEW_SESSION_ID" ]]; then
    log_error "Failed to extract new session ID"
    exit 1
fi

# Atomic write of new session ID
(
    flock -x -w "$LOCK_WAIT" 200 || exit 1
    jq --arg sid "$NEW_SESSION_ID" \
        '.subagent_session_id = $sid | .timeout.retry_count = 1' \
        "$CHECKPOINT_FILE" > "${CHECKPOINT_FILE}.tmp" && mv "${CHECKPOINT_FILE}.tmp" "$CHECKPOINT_FILE"
) 200>>"$CHECKPOINT_FILE"

log_json "INFO" "{\"action\":\"retry_spawned\",\"new_session\":\"$NEW_SESSION_ID\",\"timeout\":$NEW_TIMEOUT}"
echo "$NEW_SESSION_ID"
exit 0
