#!/bin/bash
#
# delegate-with-checkpoint.sh
# ============================
# MANDATORY: This is the ONLY permissible spawn path for subagent task work.
# No direct sessions_spawn calls for task work — use this wrapper.
#
# Usage:
#   ./scripts/delegate-with-checkpoint.sh \
#     --project myproject \
#     --task "Implement X" \
#     --agent-id qwen3-coder \
#     --timeout 300 \
#     --cwd /path/to/project
#
# Prerequisites:
#   - Dispatch file: memory/projects/<project>/dispatch.md (only if multi-phase/parallel task)
#   - Progress file: memory/projects/<project>/progress.json
#
# What this does:
#   1. RUNS pre-delegation checklist (blocks if checks fail — NO BYPASS)
#   2. RUNS compactness scorer (blocks if HIGH risk — NO BYPASS)
#   3. Creates checkpoint.json
#   4. Creates subagent-task.md from template
#   5. Auto-recalls relevant memories
#   6. Spawns subagent
#   7. Updates checkpoint with session ID
#
# Exit codes:
#   0  = spawned successfully
#   1  = pre-delegation checklist failed (blocking)
#   2  = compactness scored HIGH (blocking)
#   3  = missing prerequisites

set -euo pipefail

# ─── Default values ───────────────────────────────────────────────────────────

PROJECT=""
TASK=""
AGENT_ID=""
TIMEOUT=300
CWD=""
VERBOSE=false

# ─── Argument parsing ─────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
    case "$1" in
        --project)
            PROJECT="$2"
            shift 2
            ;;
        --task)
            TASK="$2"
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
        --cwd)
            CWD="$2"
            shift 2
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

# ─── Validate required ─────────────────────────────────────────────────────────

if [[ -z "$PROJECT" || -z "$TASK" || -z "$AGENT_ID" ]]; then
    echo "Usage: $0 --project PROJECT --task TASK --agent-id AGENT_ID [--timeout SECONDS] [--cwd DIR]" >&2
    exit 1
fi

# ─── Paths ────────────────────────────────────────────────────────────────────

WORKSPACE="$HOME/.openclaw/workspace"
PROJECT_DIR="$WORKSPACE/memory/projects/$PROJECT"

if [[ -z "$CWD" ]]; then
    CWD="$PROJECT_DIR"
fi

# ─── Logging ──────────────────────────────────────────────────────────────────

log() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo "[$(date -Iseconds)] $1"
    fi
}

# ─── STEP 0: Verify prerequisites ─────────────────────────────────────────────

if [[ ! -d "$PROJECT_DIR" ]]; then
    echo "ERROR: Project directory missing: $PROJECT_DIR" >&2
    echo "Create it first, or check the project name." >&2
    exit 3
fi

# ─── STEP 1: RUN pre-delegation checklist (BLOCKING — NO BYPASS) ──────────────

log "Running pre-delegation checklist..."
if ! bash "$WORKSPACE/scripts/pre-delegation-checklist.sh" \
    "$PROJECT" "$TASK" "$PROJECT_DIR/progress.md" "$TIMEOUT" \
    2>&1; then
    echo ""
    echo "═══════════════════════════════════════════════" >&2
    echo "PRE-DELEGATION CHECKLIST FAILED — blocking spawn" >&2
    echo "═══════════════════════════════════════════════" >&2
    echo "Fix the failures above, then re-run." >&2
    exit 1
fi

# ─── STEP 1b: RUN compactness scorer (BLOCKING — NO BYPASS) ─────────────────

log "Running compactness scorer..."
compact_output=$(bash "$WORKSPACE/scripts/compactness-score.sh" \
    --project "$PROJECT" 2>&1) || true
echo "$compact_output"
if echo "$compact_output" | grep -q "HIGH"; then
    echo ""
    echo "═══════════════════════════════════════════════" >&2
    echo "COMPACTNESS SCORE: HIGH — blocking spawn" >&2
    echo "═══════════════════════════════════════════════" >&2
    echo "Chunk this task, or do it directly." >&2
    exit 2
fi

# ─── STEP 2: Create checkpoint ────────────────────────────────────────────────

log "Creating checkpoint..."
CHECKPOINT_FILE="$CWD/checkpoint.json"

"$WORKSPACE/scripts/create-checkpoint.sh" \
    --project "$PROJECT" \
    --task "$TASK" \
    --subagent-session-id "pending" \
    --cwd "$CWD" > /dev/null

# ─── STEP 3: Create subagent-task.md from template ────────────────────────────

log "Preparing task template..."

TASK_TEMPLATE="$WORKSPACE/memory/templates/subagent-task-with-result-sink.md"
TASK_FILE="$CWD/subagent-task.md"

if [[ ! -f "$TASK_TEMPLATE" ]]; then
    echo "ERROR: Task template missing: $TASK_TEMPLATE" >&2
    exit 3
fi

sed -e "s|{{TASK_NAME}}|$(echo "$TASK" | sed 's/[\/&]/\\&/g')|g" \
    -e "s|{{PROJECT_NAME}}|$PROJECT|g" \
    -e "s|{{CREATED_AT}}|$(date -Iseconds)|g" \
    -e "s|{{TIMEOUT_SECONDS}}|$TIMEOUT|g" \
    -e "s|{{CWD}}|$CWD|g" \
    "$TASK_TEMPLATE" > "$TASK_FILE"

log "Task template written to: $TASK_FILE"

# ─── STEP 3b: Auto-recall relevant memories ───────────────────────────────────

detect_model_tier() {
    case "$AGENT_ID" in
        *minimax*|*GLM*) echo "compact" ;;
        *)               echo "capable" ;;
    esac
}

MODEL_TIER=$(detect_model_tier)
log "Checking for relevant memories..."

RECALLED=$("$WORKSPACE/scripts/memory-auto-recall.sh" \
    "$TASK" --format context --model-tier "$MODEL_TIER" --quiet 2>/dev/null || echo "")

if [[ -n "$RECALLED" ]]; then
    {
      echo ""
      echo "## Relevant Context (auto-recalled)"
      echo "$RECALLED"
    } >> "$TASK_FILE"
    log "Auto-recall: memories appended"
fi

# ─── STEP 3c: Inject self-check for medium-complexity tasks ────────────────────
#
# For tasks expected to have >3 tool calls, append self-check instructions.
# This is Phase 1 of checkpoint enforcement — forces subagent to stop and
# verify state before using more tool calls.
#
# Pattern: "If you've done >3 tool calls, write self-check before continuing."

log "Injecting self-check instructions..."

# Build self-check block via Python (handles special chars cleanly)
python3 - "$PROJECT" "$TASK_FILE" << 'PYEOF'
import sys
project = sys.argv[1]
task_file = sys.argv[2]

block = """
---

## Self-Check Protocol (Mandatory for This Task)

After every 3 tool calls:
1. Write current state to `results/{project}/self-check.json`:
   ```json
   {{"phase": "in_progress", "tool_calls_used": N, "files_read": [], "next_action": "..."}}
   ```
2. If you reach your expected tool call count and task is not done → STOP and report COMPLETE
3. The orchestrator reads self-check.json on timeout and resumes from there

**Why this matters:** Compaction fires without warning. If you haven't checkpointed, your work is lost.
""".format(project=project)

with open(task_file, 'a') as f:
    f.write(block)
PYEOF

log "Self-check injected into task file"

log "Creating progress.md..."
PROGRESS_FILE="$CWD/progress.md"

cat > "$PROGRESS_FILE" << EOF
# Task: $TASK

## Status
- State: STARTING
- Updated: $(date -Iseconds)

## Progress
- Phase: "Spawning"
- Percent: 0%

## Delegation
- Agent: $AGENT_ID
- Timeout: ${TIMEOUT}s
- Checkpoint: $CHECKPOINT_FILE
EOF

# ─── STEP 5: Spawn subagent ───────────────────────────────────────────────────

log "Spawning subagent: $AGENT_ID (timeout ${TIMEOUT}s)..."

TASK_CONTENT=$(cat "$TASK_FILE")

SESSION_OUTPUT=$(sessions_spawn \
    agentId:"$AGENT_ID" \
    --task "$TASK_CONTENT" \
    --cwd "$CWD" \
    --timeout "$TIMEOUT" \
    --cleanup delete \
    2>&1)

SESSION_ID=$(echo "$SESSION_OUTPUT" | grep -oP '(?<=sessionId["\s:]+)[a-f0-9-]+' || echo "")

if [[ -z "$SESSION_ID" ]]; then
    log "Warning: Could not extract session ID"
    SESSION_ID="unknown"
fi

log "Subagent spawned: $SESSION_ID"

# ─── STEP 6: Update checkpoint with session ID ────────────────────────────────

jq --arg sid "$SESSION_ID" \
    '.subagent_session_id = $sid | .state = "running"' \
    "$CHECKPOINT_FILE" > "${CHECKPOINT_FILE}.tmp"
mv "${CHECKPOINT_FILE}.tmp" "$CHECKPOINT_FILE"

# ─── Output ───────────────────────────────────────────────────────────────────

echo ""
echo "════════════════════════════════════"
echo "  DELEGATION SPAWNED"
echo "════════════════════════════════════"
echo "  Project:    $PROJECT"
echo "  Session:   $SESSION_ID"
echo "  Agent:     $AGENT_ID"
echo "  Timeout:   ${TIMEOUT}s"
echo "  Checkpoint: $CHECKPOINT_FILE"
echo "════════════════════════════════════"

echo "$SESSION_ID"
