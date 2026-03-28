#!/bin/bash
#
# timeout-recovery.sh
#
# Handles timeout recovery: checkpoint, kill, restore, respawn
#
# Usage:
#   ./scripts/timeout-recovery.sh \
#     --project PROJECT \
#     --session-id SESSION_ID \
#     --checkpoint CHECKPOINT_FILE \
#     --agent-id AGENT_ID \
#     [options]
#
# Options:
#   --timeout SECONDS         New timeout (default: use original)
#   --verbose                 Enable verbose logging

set -euo pipefail

# Default values
PROJECT=""
SESSION_ID=""
CHECKPOINT_FILE=""
AGENT_ID=""
TIMEOUT=""
VERBOSE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --project)
            PROJECT="$2"
            shift 2
            ;;
        --session-id)
            SESSION_ID="$2"
            shift 2
            ;;
        --checkpoint)
            CHECKPOINT_FILE="$2"
            shift 2
            ;;
        --agent-id)
            AGENT_ID="$2"
            shift 2
            ;;
        --timeout)
            TIMEOUT="$2"
            shift 2
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
if [[ -z "$PROJECT" || -z "$SESSION_ID" || -z "$CHECKPOINT_FILE" ]]; then
    echo "Usage: $0 --project PROJECT --session-id SESSION_ID --checkpoint CHECKPOINT_FILE [--agent-id AGENT_ID] [--timeout SECONDS]"
    exit 1
fi

# Paths
WORKSPACE="$HOME/.openclaw/workspace"
PROJECT_DIR="$WORKSPACE/memory/projects/$PROJECT"
PROGRESS_FILE="$PROJECT_DIR/progress.md"

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

# Step 1: Update checkpoint with recovery info
update_checkpoint_recovery() {
    log_info "Step 1: Updating checkpoint with recovery info"

    local recovery_timestamp
    recovery_timestamp=$(date -Iseconds)

    # Update checkpoint
    jq --arg rt "$recovery_timestamp" \
        '.timeout_triggered = true | .recovery_triggered_at = $rt | .recovery_status = "in_progress"' \
        "$CHECKPOINT_FILE" > "${CHECKPOINT_FILE}.tmp"
    mv "${CHECKPOINT_FILE}.tmp" "$CHECKPOINT_FILE"

    log_debug "Checkpoint updated: recovery_triggered_at=$recovery_timestamp"
}

# Step 2: Kill the subagent
kill_subagent() {
    log_info "Step 2: Killing subagent $SESSION_ID"

    if subagents kill "$SESSION_ID" 2>&1; then
        log_info "Subagent $SESSION_ID killed successfully"
    else
        log_warn "Failed to kill subagent $SESSION_ID (may have already timed out)"
    fi
}

# Step 3: Update progress.md
update_progress() {
    log_info "Step 3: Updating progress.md"

    local recovery_timestamp
    recovery_timestamp=$(date -Iseconds)

    # Update progress.md with recovery status
    cat > "$PROGRESS_FILE" << EOF
# Task: $(jq -r '.task' "$CHECKPOINT_FILE" 2>/dev/null || echo "Unknown")

## Status
- State: RECOVERING
- Updated: $recovery_timestamp
- Version: 2

## Progress
- Phase: "Timeout Recovery"
- Completed: $(jq -r '.progress.percent // 0' "$CHECKPOINT_FILE" 2>/dev/null)
- Total: 100
- Percent: $(jq -r '.progress.percent // 0' "$CHECKPOINT_FILE" 2>/dev/null)%

## Recovery
- Triggered: $recovery_timestamp
- Original Session: $SESSION_ID
- Recovering from checkpoint: $CHECKPOINT_FILE
- Progress at checkpoint: $(jq -r '.progress.phase // "Unknown"' "$CHECKPOINT_FILE" 2>/dev/null)

## Last Activity
- Time: $recovery_timestamp
- Step: "Recovery - Killing old session, preparing to restore"
- Details: "Timeout recovery triggered, checkpoint updated, old session killed"

## Files Created
$(jq -r '.context.files_created // [] | join("\n")' "$CHECKPOINT_FILE" 2>/dev/null)

## Files Modified
$(jq -r '.context.files_modified // [] | join("\n")' "$CHECKPOINT_FILE" 2>/dev/null)

## Checkpoint Info
- Created: $(jq -r '.created_at' "$CHECKPOINT_FILE" 2>/dev/null)
- Subagent Session ID: $(jq -r '.subagent_session_id' "$CHECKPOINT_FILE" 2>/dev/null)
- Phase: $(jq -r '.progress.phase' "$CHECKPOINT_FILE" 2>/dev/null)
- Step: $(jq -r '.progress.step' "$CHECKPOINT_FILE" 2>/dev/null)
EOF

    log_debug "Progress updated with recovery status"
}

# Step 4: Spawn new subagent with recovery context
spawn_recovered_subagent() {
    log_info "Step 4: Spawning recovered subagent"

    # Get agent ID from checkpoint if not provided
    if [[ -z "$AGENT_ID" ]]; then
        AGENT_ID=$(jq -r '.agent_id // "kimik2thinking"' "$CHECKPOINT_FILE" 2>/dev/null)
        log_debug "Using agent ID from checkpoint: $AGENT_ID"
    fi

    # Get timeout from checkpoint if not provided
    if [[ -z "$TIMEOUT" ]]; then
        TIMEOUT=$(jq -r '.timeout_seconds // 300' "$CHECKPOINT_FILE" 2>/dev/null)
        log_debug "Using timeout from checkpoint: ${TIMEOUT}s"
    fi

    # Prepare recovery task
    local recovery_task
    recovery_task=$(cat << 'EOF'
# Recovery Task: Resume from Checkpoint

You are recovering from a checkpoint. Follow these steps:

1. **Read checkpoint.json:**
   ```bash
   cat checkpoint.json | jq '.'
   ```

2. **Restore state:**
   - Set current phase from `checkpoint.progress.phase`
   - Set current step from `checkpoint.progress.step`
   - Continue from `checkpoint.progress.percent`% complete

3. **Update progress.md:**
   ```markdown
   ## Status
   - State: RUNNING (RECOVERED)
   - Updated: ISO8601 timestamp

   ## Recovery
   - Restored from: checkpoint.json
   - Original Session: [SESSION_ID]
   - Resuming at: Phase [phase], Step [step], [percent]% complete
   ```

4. **Continue task:**
   - Resume from where you left off
   - Update progress every 2 minutes
   - Complete the task

**Important:**
- Progress updates every 2 minutes (MANDATORY)
- Checkpoint signal handling (if signaled again)
- Complete the original task
EOF
)

    # Spawn new subagent
    log_info "Spawning subagent: $AGENT_ID with timeout ${TIMEOUT}s"

    local session_output
    session_output=$(sessions_spawn \
        agentId:"$AGENT_ID" \
        --task "$recovery_task" \
        --cwd "$PROJECT_DIR" \
        --timeout "$TIMEOUT" \
        --cleanup delete \
        2>&1)

    # Extract new session ID
    local new_session_id
    new_session_id=$(echo "$session_output" | grep -oP '(?<=sessionId["\s:]+)[a-f0-9-]+' || echo "")

    if [[ -z "$new_session_id" ]]; then
        log_warn "Could not extract new session ID from output"
        new_session_id="unknown"
    fi

    log_info "New subagent spawned: $new_session_id"

    # Update checkpoint with new session ID
    jq --arg sid "$new_session_id" \
        '.recovery_session_id = $sid | .recovery_status = "completed"' \
        "$CHECKPOINT_FILE" > "${CHECKPOINT_FILE}.tmp"
    mv "${CHECKPOINT_FILE}.tmp" "$CHECKPOINT_FILE"

    log_debug "Checkpoint updated with new session ID: $new_session_id"

    echo "$new_session_id"
}

# Main recovery flow
main() {
    log_info "========================================"
    log_info "TIMEOUT RECOVERY STARTED"
    log_info "========================================"
    log_info "Project: $PROJECT"
    log_info "Session: $SESSION_ID"
    log_info "Checkpoint: $CHECKPOINT_FILE"
    log_info "Agent: $AGENT_ID"
    log_info "========================================"

    # Step 1: Update checkpoint
    update_checkpoint_recovery

    # Step 2: Kill subagent
    kill_subagent

    # Step 3: Update progress
    update_progress

    # Step 4: Spawn recovered subagent
    local new_session_id
    new_session_id=$(spawn_recovered_subagent)

    log_info "========================================"
    log_info "TIMEOUT RECOVERY COMPLETE"
    log_info "========================================"
    log_info "Original session: $SESSION_ID"
    log_info "New session: $new_session_id"
    log_info "Checkpoint: $CHECKPOINT_FILE"
    log_info "========================================"

    # Step 5: Verify expected output files
    log_info "Step 5: Checking expected output files from checkpoint"
    local expected_files
    expected_files=$(jq -r '.context.files_created // [] | join("\n")' "$CHECKPOINT_FILE" 2>/dev/null || echo "")
    if [ -z "$expected_files" ]; then
        log_info "(No files recorded in checkpoint — skipping verification)"
    else
        local missing=0
        while IFS= read -r file; do
            [ -z "$file" ] && continue
            if [ -f "$file" ]; then
                log_pass "✓ Found: $file"
            else
                log_warn "✗ Missing: $file (respawned subagent should create this)"
                ((missing++)) || true
            fi
        done <<< "$expected_files"
        if [ $missing -gt 0 ]; then
            log_warn "$missing output file(s) not yet created — run verify-subagent-progress.sh after recovery completes"
        else
            log_pass "✓ All expected output files present"
        fi
    fi

    log_info "Run verify-subagent-progress.sh --project $PROJECT after recovery completes"

    # Return new session ID
    echo "$new_session_id"
}

# Run main
main
