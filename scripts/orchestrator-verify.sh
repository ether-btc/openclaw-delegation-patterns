#!/bin/bash
#
# orchestrator-verify.sh
# =======================
# Orchestrator tool: verify subagent results BEFORE declaring done.
# Checks checkpoint.json for files_created and verifies they exist.
#
# Usage:
#   ./scripts/orchestrator-verify.sh --project <name> [--phase <name>]
#
# Exit codes:
#   0 = all files verified
#   1 = some files missing (results incomplete)
#   2 = checkpoint missing or unreadable
#
# Orchestrator workflow (MUST follow this order):
#   1. Read checkpoint.json → get files_created
#   2. Verify each file exists in results/
#   3. If all exist → orchestrator copies to workspace, DONE
#   4. If some missing → identify which phases completed, redo only missing
#   5. NEVER assume subagent did nothing — always check first

set -euo pipefail

# ─── Arguments ────────────────────────────────────────────────────────────────

PROJECT=""
# shellcheck disable=SC2034  # PHASE reserved for future phase-gated verification
PHASE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --project)
            PROJECT="$2"
            shift 2
            ;;
        --phase)
            # shellcheck disable=SC2034  # PHASE reserved for future use
            PHASE="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

if [[ -z "$PROJECT" ]]; then
    echo "Usage: $0 --project <name> [--phase <name>]" >&2
    exit 1
fi

# ─── Paths ───────────────────────────────────────────────────────────────────

WORKSPACE="$HOME/.openclaw/workspace"
CHECKPOINT_FILE="$WORKSPACE/memory/projects/$PROJECT/checkpoint.json"

# ─── Verify checkpoint exists ─────────────────────────────────────────────────

if [[ ! -f "$CHECKPOINT_FILE" ]]; then
    echo "WARN: No checkpoint found for project '$PROJECT'" >&2
    echo "  Expected: $CHECKPOINT_FILE" >&2
    exit 2
fi

# ─── Get files_created from checkpoint ───────────────────────────────────────

echo "─── Orchestrator Verify ───"
echo "Project: $PROJECT"
echo "Checkpoint: $CHECKPOINT_FILE"
echo ""

# Read files_created as array
FILES=$(jq -r '.files_created // [] | join("\n")' "$CHECKPOINT_FILE" 2>/dev/null || echo "")

if [[ -z "$FILES" || "$FILES" == "null" ]]; then
    echo "WARN: No files recorded in checkpoint" >&2
    echo "  Either subagent hasn't written results yet,"
    echo "  or result-sink.sh wasn't used." >&2
    exit 2
fi

# ─── Verify each file ─────────────────────────────────────────────────────────

MISSING=()
PRESENT=()

while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    FULL_PATH="$WORKSPACE/$file"
    if [[ -f "$FULL_PATH" ]]; then
        size=$(wc -c < "$FULL_PATH")
        PRESENT+=("$file (${size}B)")
        echo "  ✓ $file"
    else
        MISSING+=("$file")
        echo "  ✗ MISSING: $file"
    fi
done <<< "$FILES"

echo ""

# ─── Report ───────────────────────────────────────────────────────────────────

if [[ ${#MISSING[@]} -eq 0 ]]; then
    echo "Result: ALL ${#PRESENT[@]} files verified ✓"
    echo ""
    echo "Next step: Orchestrator copies from results/ to workspace."
    exit 0
else
    echo "Result: ${#MISSING[@]} files MISSING (${#PRESENT[@]} present)"
    echo ""
    echo "Missing files:"
    printf '  - %s\n' "${MISSING[@]}"
    echo ""
    echo "Options:"
    echo "  1. Subagent may have died before writing — check session_history"
    echo "  2. Redo only the missing phases directly"
    echo "  3. NEVER assume everything failed — ${#PRESENT[@]} files are good"
    exit 1
fi
