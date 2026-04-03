#!/bin/bash
# shellcheck disable=SC2317  # log_debug/log_warn/log_error chain false positive
#
# verify-subagent-progress.sh
#
# Verifies subagent progress: checks progress.md existence and freshness
#
# Usage:
#   ./scripts/verify-subagent-progress.sh --project PROJECT [options]
#
# Options:
#   --session-id SESSION_ID   Optional session ID for context
#   --stale-threshold SECONDS Progress is stale after N seconds (default: 120)
#   --verbose                 Enable verbose logging
#
# Exit codes:
#   0 - All checks passed
#   1 - Progress file missing
#   2 - Progress file stale
#   3 - Invalid progress format

set -euo pipefail

# Default values
PROJECT=""
SESSION_ID=""
STALE_THRESHOLD=120
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
        --stale-threshold)
            STALE_THRESHOLD="$2"
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
if [[ -z "$PROJECT" ]]; then
    echo "Usage: $0 --project PROJECT [options]"
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

# Check 1: Progress file exists
check_progress_exists() {
    log_info "Check 1: Verifying progress.md exists"

    if [[ ! -f "$PROGRESS_FILE" ]]; then
        log_error "progress.md not found: $PROGRESS_FILE"
        return 1
    fi

    log_info "✅ progress.md exists"
    return 0
}

# Check 2: Progress file has valid format
check_progress_format() {
    log_info "Check 2: Verifying progress.md format"

    local required_sections=("Status" "Progress" "Last Activity")

    for section in "${required_sections[@]}"; do
        if ! grep -q "^## $section" "$PROGRESS_FILE"; then
            log_error "Missing required section: $section"
            return 1
        fi
    done

    # Check for State field
    if ! grep -q "^- State:" "$PROGRESS_FILE"; then
        log_error "Missing State field"
        return 1
    fi

    # Check for Last Activity Time field
    if ! grep -q "^- Time:" "$PROGRESS_FILE"; then
        log_error "Missing Last Activity Time field"
        return 1
    fi

    log_info "✅ progress.md has valid format"
    return 0
}

# Check 3: Progress is fresh (not stale)
check_progress_freshness() {
    log_info "Check 3: Verifying progress freshness (stale threshold: ${STALE_THRESHOLD}s)"

    local last_update
    last_update=$(grep -oP '(?<=^## Last Activity\n- Time: )[0-9-]{10}T[0-9:]{8}' "$PROGRESS_FILE" 2>/dev/null || echo "")

    if [[ -z "$last_update" ]]; then
        log_error "Could not extract last update time from progress.md"
        return 1
    fi

    local last_ts
    last_ts=$(date -d "$last_update" +%s 2>/dev/null || echo "0")
    local now_ts
    now_ts=$(date +%s)
    local age
    age=$((now_ts - last_ts))

    log_debug "Last update: $last_update (age: ${age}s)"

    if [[ $age -gt $STALE_THRESHOLD ]]; then
        log_error "progress.md is stale (${age}s > ${STALE_THRESHOLD}s)"
        return 1
    fi

    log_info "✅ progress.md is fresh (age: ${age}s)"
    return 0
}

# Check 4: Progress state is valid
check_progress_state() {
    log_info "Check 4: Verifying progress state"

    local state
    state=$(grep -oP '(?<=^- State: )[A-Z]+' "$PROGRESS_FILE" 2>/dev/null || echo "")

    if [[ -z "$state" ]]; then
        log_error "Could not extract state from progress.md"
        return 1
    fi

    log_debug "State: $state"

    case "$state" in
        RUNNING|COMPLETED|FAILED|CHECKPOINTED|RECOVERING|STARTING)
            log_info "✅ State is valid: $state"
            return 0
            ;;
        *)
            log_error "Invalid state: $state"
            return 1
            ;;
    esac
}

# Print progress summary
print_progress_summary() {
    log_info "========================================"
    log_info "PROGRESS SUMMARY"
    log_info "========================================"

    echo ""
    cat "$PROGRESS_FILE"
    echo ""
}

# Main verification flow
main() {
    log_info "========================================"
    log_info "SUBAGENT PROGRESS VERIFICATION"
    log_info "========================================"
    log_info "Project: $PROJECT"
    if [[ -n "$SESSION_ID" ]]; then
        log_info "Session ID: $SESSION_ID"
    fi
    log_info "Progress file: $PROGRESS_FILE"
    log_info "Stale threshold: ${STALE_THRESHOLD}s"
    log_info "========================================"

    # Run checks
    local failed=0

    if ! check_progress_exists; then
        failed=1
        echo ""
        log_error "VERIFICATION FAILED: progress.md missing"
        exit 1
    fi

    if ! check_progress_format; then
        failed=3
    fi

    if ! check_progress_state; then
        failed=3
    fi

    if ! check_progress_freshness; then
        failed=2
    fi

    # Print summary
    print_progress_summary

    # Final result
    if [[ $failed -eq 0 ]]; then
        echo ""
        log_info "========================================"
        log_info "VERIFICATION PASSED"
        log_info "========================================"
        exit 0
    else
        echo ""
        log_error "========================================"
        log_error "VERIFICATION FAILED (exit code: $failed)"
        log_error "========================================"

        case $failed in
            1)
                log_error "Reason: Progress file missing"
                ;;
            2)
                log_error "Reason: Progress file stale"
                ;;
            3)
                log_error "Reason: Invalid progress format"
                ;;
        esac

        exit $failed
    fi
}

# Run main
main
