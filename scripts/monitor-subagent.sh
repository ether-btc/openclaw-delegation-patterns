#!/bin/bash
#
# monitor-subagent.sh
#
# Monitors a subagent's progress.md and triggers recovery if timeout approaching
#
# Usage:
#   ./scripts/monitor-subagent.sh --session-id SESSION_ID --project PROJECT [options]
#
# Options:
#   --timeout SECONDS         Total timeout (default: 300)
#   --check-interval SECONDS  Check every N seconds (default: 30)
#   --stale-threshold SECONDS Progress is stale after N seconds (default: 120)
#   --recovery-threshold PCT  Trigger recovery at PCT of timeout (default: 90)
#   --once                    Run once and exit (for cron/manual use)
#   --verbose                 Enable verbose logging

set -euo pipefail

# Default values
SESSION_ID=""
PROJECT=""
TIMEOUT=300
CHECK_INTERVAL=30
STALE_THRESHOLD=120
RECOVERY_THRESHOLD=90
ONCE=false
VERBOSE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --session-id)
            SESSION_ID="$2"
            shift 2
            ;;
        --project)
            PROJECT="$2"
            shift 2
            ;;
        --timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        --check-interval)
            CHECK_INTERVAL="$2"
            shift 2
            ;;
        --stale-threshold)
            STALE_THRESHOLD="$2"
            shift 2
            ;;
        --recovery-threshold)
            RECOVERY_THRESHOLD="$2"
            shift 2
            ;;
        --once)
            ONCE=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Validate required arguments
if [[ -z "$SESSION_ID" || -z "$PROJECT" ]]; then
    echo "Usage: $0 --session-id SESSION_ID --project PROJECT [options]"
    exit 1
fi

# Paths
WORKSPACE="$HOME/.openclaw/workspace"
PROJECT_DIR="$WORKSPACE/memory/projects/$PROJECT"
PROGRESS_FILE="$PROJECT_DIR/progress.md"
CHECKPOINT_FILE="$PROJECT_DIR/checkpoint.json"

# Logging
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date -Iseconds)
    echo "[$timestamp] [$level] $message"
}

log_debug() {
    [[ "$VERBOSE" == "true" ]] && log "DEBUG" "$@"
}

log_info() {
    log "INFO" "$@"
}

log_warn() {
    log "WARN" "$@"
}

log_error() {
    log "ERROR" "$@"
}

# Check if files exist
check_files() {
    if [[ ! -f "$PROGRESS_FILE" ]]; then
        log_warn "progress.md not found: $PROGRESS_FILE"
        return 1
    fi
    if [[ ! -f "$CHECKPOINT_FILE" ]]; then
        log_warn "checkpoint.json not found: $CHECKPOINT_FILE"
        return 1
    fi
    return 0
}

# Get last update time from progress.md
get_progress_age() {
    local last_update
    last_update=$(grep -oP '(?<=^## Last Activity\n- Time: )[0-9-]{10}T[0-9:]{8}' "$PROGRESS_FILE" 2>/dev/null || echo "")

    if [[ -z "$last_update" ]]; then
        echo "9999999999"  # Very large number (stale)
        return
    fi

    local last_ts
    last_ts=$(date -d "$last_update" +%s 2>/dev/null || echo "0")
    local now_ts
    now_ts=$(date +%s)
    echo $((now_ts - last_ts))
}

# Get elapsed time from checkpoint
get_elapsed_time() {
    local created
    created=$(jq -r '.created_at' "$CHECKPOINT_FILE" 2>/dev/null || echo "")

    if [[ -z "$created" || "$created" == "null" ]]; then
        echo "0"
        return
    fi

    local created_ts
    created_ts=$(date -d "$created" +%s 2>/dev/null || echo "0")
    local now_ts
    now_ts=$(date +%s)
    echo $((now_ts - created_ts))
}

# Check if recovery should be triggered
should_trigger_recovery() {
    local elapsed=$1
    local recovery_threshold_seconds
    recovery_threshold_seconds=$((TIMEOUT * RECOVERY_THRESHOLD / 100))

    if [[ $elapsed -ge $recovery_threshold_seconds ]]; then
        log_info "Recovery threshold reached (${elapsed}s >= ${recovery_threshold_seconds}s)"
        return 0
    fi
    return 1
}

# Trigger recovery
trigger_recovery() {
    log_info "Triggering recovery for session $SESSION_ID"

    # Update checkpoint with timeout triggered
    log_info "Updating checkpoint with timeout_triggered=true"
    RECOVERY_TS=$(date -Iseconds)
    jq --arg triggered "true" --arg ts "$RECOVERY_TS" \
        '.timeout_triggered = $triggered | .recovery_triggered_at = $ts' \
        "$CHECKPOINT_FILE" > "${CHECKPOINT_FILE}.tmp"
    mv "${CHECKPOINT_FILE}.tmp" "$CHECKPOINT_FILE"

    # Run timeout recovery script
    log_info "Calling timeout-recovery.sh"
    "$WORKSPACE/scripts/timeout-recovery.sh" \
        --project "$PROJECT" \
        --session-id "$SESSION_ID" \
        --checkpoint "$CHECKPOINT_FILE" \
        --verbose
}

# Single check iteration
do_check() {
    log_debug "Checking progress for session $SESSION_ID"

    # Check files exist
    if ! check_files; then
        log_warn "Required files missing, skipping check"
        return
    fi

    # Get progress age
    local progress_age
    progress_age=$(get_progress_age)
    log_debug "Progress age: ${progress_age}s (threshold: ${STALE_THRESHOLD}s)"

    if [[ $progress_age -gt $STALE_THRESHOLD ]]; then
        log_warn "Progress is stale (${progress_age}s > ${STALE_THRESHOLD}s)"

        # Check subagent session status via sessions.json (with jq retry for concurrent writes)
        log_debug "Checking subagent session status in sessions.json..."
        local subagent_status="unknown"
        local sessions_file="$HOME/.openclaw/agents/main/sessions/sessions.json"

        for attempt in 1 2 3; do
            if subagent_status=$(jq -r --arg key "agent:main:subagent:${SESSION_ID}" \
                '.[$key].status // "session_not_found"' \
                "$sessions_file" 2>/dev/null); then
                break
            fi
            log_debug "jq retry $attempt on sessions.json concurrent write"
            sleep 1
        done

        log_debug "Subagent session status: ${subagent_status}"

        if [[ "$subagent_status" == "session_not_found" || \
              "$subagent_status" == "failed" || \
              "$subagent_status" == "done" || \
              "$subagent_status" == "timeout" ]]; then
            log_warn "Subagent session is ${subagent_status} — triggering recovery"
            trigger_recovery
            return
        fi
    else
        log_debug "Progress is fresh (${progress_age}s <= ${STALE_THRESHOLD}s)"
    fi

    # Check if we should trigger recovery based on time
    local elapsed
    elapsed=$(get_elapsed_time)
    log_debug "Elapsed time: ${elapsed}s"

    if should_trigger_recovery "$elapsed"; then
        trigger_recovery
    fi
}

# Main loop
main() {
    log_info "Starting monitor for session $SESSION_ID (project: $PROJECT)"
    log_info "Timeout: ${TIMEOUT}s, Check interval: ${CHECK_INTERVAL}s, Recovery threshold: ${RECOVERY_THRESHOLD}%"

    if [[ "$ONCE" == "true" ]]; then
        log_info "Running once..."
        do_check
        log_info "Check complete"
        exit 0
    fi

    while true; do
        do_check
        sleep "$CHECK_INTERVAL"
    done
}

# Run main
main
