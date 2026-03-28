#!/bin/bash

# verify-handoff.sh — Deterministic post-subagent completion verification
# Usage: ./verify-handoff.sh --project PROJECT --session-id SESSION_ID [--type TYPE]
#
# Exit codes:
#   0 = all files verified
#   1 = files missing (orchestrator must extract from session_history)
#   2 = error (missing tool, bad JSON, checkpoint missing)

set -e

# Default values
PROJECT=""
SESSION_ID=""
TYPE=""

# Parse command line arguments
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
        --type)
            TYPE="$2"
            shift 2
            ;;
        *)
            echo "Error: Unknown parameter: $1" >&2
            exit 2
            ;;
    esac
done

# Check if required parameters are provided
if [[ -z "$PROJECT" || -z "$SESSION_ID" ]]; then
    echo "Error: Missing required parameters --project or --session-id" >&2
    exit 2
fi

# Skip verification for script-build tasks
if [[ "$TYPE" == "script-build" ]]; then
    echo "Skipping verification for script-build task"
    exit 0
fi

# Check jq availability
if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq is required but not installed" >&2
    exit 2
fi

# Check if checkpoint.json exists
CHECKPOINT_FILE="memory/projects/$PROJECT/checkpoint.json"
if [[ ! -f "$CHECKPOINT_FILE" ]]; then
    echo "Error: checkpoint file not found: $CHECKPOINT_FILE" >&2
    exit 2
fi

# Extract expected files from checkpoint.json with diagnostic
EXPECTED_FILES=$(jq -r '.context.files_created[]' "$CHECKPOINT_FILE" 2>&1)
JQ_EXIT=$?

if [[ $JQ_EXIT -ne 0 ]]; then
    # Distinguish failure modes
    if ! jq -e '.' "$CHECKPOINT_FILE" >/dev/null 2>&1; then
        echo "Error: checkpoint.json is not valid JSON" >&2
    elif ! jq -e '.context.files_created' "$CHECKPOINT_FILE" >/dev/null 2>&1; then
        echo "Error: checkpoint.json missing .context.files_created key" >&2
    else
        echo "Error: jq extraction failed: $EXPECTED_FILES" >&2
    fi
    exit 2
fi

if [[ -z "$EXPECTED_FILES" || "$EXPECTED_FILES" == "null" ]]; then
    echo "Error: .context.files_created[] is empty or null in checkpoint.json" >&2
    exit 2
fi

# Check each expected file
MISSING_FILES=()
while IFS= read -r file; do
    if [[ -n "$file" && "$file" != "null" ]]; then
        if [[ ! -f "$file" ]]; then
            echo "Missing file: $file" >&2
            MISSING_FILES+=("$file")
        else
            echo "Found file: $file"
        fi
    fi
done < <(echo "$EXPECTED_FILES")

# If any files are missing, attempt sessions_history fallback before exiting
if [[ ${#MISSING_FILES[@]} -gt 0 ]]; then
    echo "Attempting sessions_history fallback verification..." >&2
    if sessions_history "$SESSION_ID" --limit 1 >/dev/null 2>&1; then
        echo "sessions_history accessible — session completed, files may need extraction" >&2
        exit 1
    else
        echo "sessions_history inaccessible — cannot verify session state" >&2
        exit 2
    fi
fi

# All files verified successfully
echo "All files verified successfully"
exit 0
