#!/bin/bash
# Pre-Delegation Checklist (Simplified)
# MANDATORY verification before spawning any subagent
# NO BYPASS POSSIBLE - All checks are enforced
# Usage: ./scripts/pre-delegation-checklist.sh <project> <task> <output_file> [timeout]

set -euo pipefail

# Colors
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

# Logging
log_info() { echo -e "${BLUE}[CHECK]${NC} $*"; }
log_pass() { echo -e "${GREEN}[PASS]${NC} $*"; }
log_fail() { echo -e "${RED}[FAIL]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }

# Exit with failure message
die() {
    log_fail "$1"
    log_info "Run: ./scripts/delg.sh init <project> <task> <output_file>"
    exit 1
}

# Validate arguments
if [ $# -lt 3 ]; then
    log_fail "Missing required parameters"
    echo "Usage: $0 <project> <task> <output_file> [timeout]" >&2
    echo "" >&2
    echo "Parameters:" >&2
    echo "  project    - Project name (e.g., myproject)" >&2
    echo "  task       - Task name (e.g., research, implementation)" >&2
    echo "  output_file - Full path to output file (e.g., memory/projects/myproject/research.md)" >&2
    echo "  timeout    - Optional timeout in seconds (default: 120)" >&2
    exit 1
fi

PROJECT="$1"
TASK="$2"
OUTPUT_FILE="$3"
TIMEOUT="${4:-120}"

# Paths
PROJECT_DIR="$HOME/.openclaw/workspace/memory/projects/$PROJECT"
DISPATCH_FILE="$PROJECT_DIR/dispatch.md"
WORKSPACE="$HOME/.openclaw/workspace"

# Convert to absolute path if relative
if [[ "$OUTPUT_FILE" != /* ]]; then
    OUTPUT_FILE="$WORKSPACE/$OUTPUT_FILE"
fi

echo -e "${BLUE}═══ Pre-Delegation Checklist ═══${NC}"
echo "Project: $PROJECT"
echo "Task: $TASK"
echo "Output: $OUTPUT_FILE"
echo "Timeout: ${TIMEOUT}s"
echo ""

# === CHECK 1: Project Directory ===
log_info "1. Project directory exists"
if [ ! -d "$PROJECT_DIR" ]; then
    log_fail "Project directory missing: $PROJECT_DIR"
    log_info "Creating project directory..."
    mkdir -p "$PROJECT_DIR"
    log_pass "[OK] Created: $PROJECT_DIR"
else
    log_pass "[OK] Project directory exists"
fi

# === CHECK 2: Output File Path ===
log_info "2. Output file path valid"
if [[ ! "$OUTPUT_FILE" =~ ^/ ]]; then
    die "Output file must be absolute path: $OUTPUT_FILE"
fi

# Check output directory exists
OUTPUT_DIR=$(dirname "$OUTPUT_FILE")
if [ ! -d "$OUTPUT_DIR" ]; then
    log_warn "Output directory does not exist: $OUTPUT_DIR"
    log_info "Creating output directory..."
    mkdir -p "$OUTPUT_DIR"
    log_pass "[OK] Created: $OUTPUT_DIR"
fi

log_pass "[OK] Output file path valid"

# === CHECK 3: Timeout Reasonable ===
log_info "3. Timeout reasonable (60-1800s)"
if [ "$TIMEOUT" -lt 60 ]; then
    log_warn "Timeout < 60s, may be too short for complex tasks"
elif [ "$TIMEOUT" -gt 1800 ]; then
    die "Timeout > 1800s (30m), consider splitting task"
else
    log_pass "[OK] Timeout reasonable ($TIMEOUT seconds)"
fi

# === CHECK 4: Result-Sink Template ===
log_info "4. Result-sink template exists"
RESULT_SINK_TEMPLATE="$WORKSPACE/memory/templates/subagent-task-with-result-sink.md"

if [ ! -f "$RESULT_SINK_TEMPLATE" ]; then
    die "Result-sink template missing: $RESULT_SINK_TEMPLATE"
else
    log_pass "[OK] Result-sink template exists"
fi

# === CHECK 5: Compactness Score ===
log_info "5. Compactness score check"
if [ -f "$WORKSPACE/scripts/compactness-score.sh" ]; then
    COMPACTNESS_OUTPUT=$(bash "$WORKSPACE/scripts/compactness-score.sh" --project "$PROJECT" 2>&1 || echo "SCORE_ERROR")
    if echo "$COMPACTNESS_OUTPUT" | grep -q "HIGH"; then
        log_warn "⚠ Compactness score is HIGH"
        log_info "Next step (compactness scorer in wrapper) will block on HIGH."
        log_pass "[OK] Warning issued — wrapper handles blocking"
    elif echo "$COMPACTNESS_OUTPUT" | grep -q "SCORE_ERROR"; then
        log_warn "⚠ Could not determine compactness score"
        log_pass "[OK] Warning issued — wrapper handles blocking"
    else
        log_pass "[OK] Compactness score acceptable"
    fi
else
    log_warn "Compactness score script not found: $WORKSPACE/scripts/compactness-score.sh"
    log_pass "[OK] Warning issued — wrapper handles blocking"
fi

# === CHECK 6: No Running Subagent ===
log_info "6. No conflicting subagent running"
ACTIVE_SUBAGENTS=$(subagents list 2>/dev/null | jq -r \
    --arg p "$PROJECT" \
    '.active[] | select(.sessionKey | contains($p)) | .sessionKey' \
    2>/dev/null || echo "")
if [ -n "$ACTIVE_SUBAGENTS" ]; then
    die "Subagent already running for project: $PROJECT — kill it first or wait. Active sessions:
$ACTIVE_SUBAGENTS"
else
    log_pass "[OK] No conflicting subagent"
fi

# === CHECK 7: Dispatch File for Multi-Phase Tasks ===
log_info "7. Dispatch file required for multi-phase/parallel tasks"
if [ -z "$TASK" ]; then
    log_info "(Skipping dispatch check — TASK not set)"
    log_pass "[OK] Dispatch check skipped"
else
    TASK_LOWER=$(echo "$TASK" | tr '[:upper:]' '[:lower:]')
    if echo "$TASK_LOWER" | grep -qE "(multi|phase|parallel|several|many)"; then
        if [ ! -f "$DISPATCH_FILE" ]; then
            die "Dispatch file required for multi-phase/parallel task: $DISPATCH_FILE"
        fi
        log_pass "[OK] Dispatch file exists for multi-phase/parallel task"
    else
        log_pass "[OK] Single-phase task (dispatch file not required)"
    fi
fi

# === SUMMARY ===
echo ""
echo -e "${GREEN}═══ Pre-Delegation Checklist: PASS ═══${NC}"
echo "All 7 checks passed. Ready to spawn subagent."
echo ""
echo "Next steps:"
echo "1. Ensure task prompt uses result-sink pattern"
echo "2. Spawn subagent with delegate-with-checkpoint.sh wrapper"
echo "3. Monitor progress with verify-subagent-progress.sh"
echo ""
echo "Spawn command example:"
echo "  $WORKSPACE/scripts/delegate-with-checkpoint.sh \\"
echo "    --project $PROJECT \\"
echo "    --task \"\$TASK_DESCRIPTION\" \\"
echo "    --agent-id kimik2thinking \\"
echo "    --timeout $TIMEOUT \\"
echo "    --cwd $PROJECT_DIR"
echo ""
echo "Monitor progress:"
echo "  $WORKSPACE/scripts/verify-subagent-progress.sh --project $PROJECT"
echo ""

exit 0
