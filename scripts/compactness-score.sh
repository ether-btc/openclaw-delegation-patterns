#!/bin/bash
#
# compactness-score.sh
# ====================
# Scores a task's compaction risk BEFORE delegation.
# Blocks HIGH-risk tasks (exit 1) to prevent context overflow.
#
# Usage:
#   bash scripts/compactness-score.sh --project <name> [--parent-context N]
#
# Returns tier: LOW | MEDIUM | HIGH
# Exit 0 = safe to proceed | Exit 1 = HIGH risk (blocked)
#
# Wire into: delegate-with-checkpoint.sh

set -euo pipefail

PROJECT=""
TASK_FILE=""
PARENT_CONTEXT=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --project)
            PROJECT="$2"
            shift 2
            ;;
        --task-file)
            TASK_FILE="$2"
            shift 2
            ;;
        --parent-context)
            PARENT_CONTEXT="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

# Resolve task file from project
if [[ -n "$PROJECT" ]]; then
    PROJECT_DIR="$HOME/.openclaw/workspace/memory/projects/$PROJECT"
    # Prefer dispatch.md, fall back to newest dispatch-*.md
    if [[ -f "$PROJECT_DIR/dispatch.md" ]]; then
        TASK_FILE="$PROJECT_DIR/dispatch.md"
    else
        TASK_FILE=$(find "$PROJECT_DIR" -name "dispatch-*.md" -type f -printf '%T@ %p\n' | sort -k 1 -n | tail -1 | cut -d ' ' -f 2-)
        if [[ -z "$TASK_FILE" ]]; then
            TASK_FILE="$PROJECT_DIR/dispatch.md"  # will trigger DISPATCH_MISSING below
        fi
    fi
fi

if [[ -z "$TASK_FILE" ]]; then
    echo "ERROR: --project or --task-file required" >&2
    exit 1
fi

if [[ ! -f "$TASK_FILE" ]]; then
    echo "DISPATCH_MISSING"
    echo "WARN: Dispatch not found: $TASK_FILE" >&2
    echo "HIGH (dispatch missing — risk unknown)"
    exit 1
fi

# ─── Helpers ─────────────────────────────────────────────────────────────────

# Grep count — returns 0 if file missing or no matches
count_grep() {
    local pattern="$1"
    local count
    count=$(grep -cE -- "$pattern" "$TASK_FILE" 2>/dev/null) || count=0
    count=${count:-0}
    echo "$count"
}

# Safer integer comparison
is_gt() {
    local a="$1"
    local b="$2"
    [[ "$a" =~ ^[0-9]+$ ]] && [[ "$b" =~ ^[0-9]+$ ]] && (( a > b ))
}

# ─── Score ───────────────────────────────────────────────────────────────────

score=0
breakdown=()

add_score() {
    local label="$1"
    local pts="$2"
    score=$((score + pts))
    breakdown+=("  + ${label}: +${pts}")
}

# Factor 1: File write ops (> 3)
writes=$(count_grep '\b(write|create|edit|update|append|put|store)\b')
if is_gt "$writes" 3; then
    excess=$((writes - 3))
    add_score "file_writes(${writes})" $((30 * excess))
fi

# Factor 2: File read ops (> 5)
reads=$(count_grep '\b(read|load|fetch|get|cat|source|import|include)\b')
if is_gt "$reads" 5; then
    excess=$((reads - 5))
    add_score "file_reads(${reads})" $((10 * excess))
fi

# Factor 3: Exec calls (> 5)
execs=$(count_grep '\b(exec|command|bash|script|\\$.*\\$|subprocess)\b')
if is_gt "$execs" 5; then
    excess=$((execs - 5))
    add_score "exec_calls(${execs})" $((20 * excess))
fi

# Factor 4: Large prompt (> 1,500 tokens ≈ 2,000 chars)
chars=$(wc -c < "$TASK_FILE" 2>/dev/null || echo "0")
tokens=$(($(echo "$chars * 3 / 4" | bc 2>/dev/null || echo "0")))
if is_gt "$tokens" 1500; then
    add_score "large_prompt(${tokens}tok)" 25
fi

# Factor 5: Implementation keyword
if grep -qiE '(implement|build\s|create\s)' "$TASK_FILE" 2>/dev/null; then
    add_score "implementation_keyword" 15
fi

# Factor 6: Read-only (reduces risk)
if grep -qiE '(review|analyze|audit|inspect)' "$TASK_FILE" 2>/dev/null; then
    score=$((score - 5))
    breakdown+=("  + readonly_keyword: -5")
fi

# Factor 7: Parent context high
if [[ -n "$PARENT_CONTEXT" ]]; then
    if is_gt "$PARENT_CONTEXT" 140000; then
        add_score "parent_high" 40
    elif is_gt "$PARENT_CONTEXT" 100000; then
        add_score "parent_elevated" 20
    fi
fi

# Factor 8: Subagent already running
if command -v subagents &>/dev/null; then
    active=$(subagents list 2>/dev/null | grep -c '"status": "running"' 2>/dev/null) || active=0
    if is_gt "$active" 0; then
        add_score "active_subagents(${active})" $((25 * active))
    fi
fi

# ─── Tier ────────────────────────────────────────────────────────────────────

if    [[ "$score" -le 30 ]]; then tier="LOW"
elif  [[ "$score" -le 60 ]]; then tier="MEDIUM"
else                              tier="HIGH"
fi

# ─── Output ──────────────────────────────────────────────────────────────────

echo ""
echo "─── Compactness ───────────────────────"
echo "  Project: ${PROJECT:-$(basename "$TASK_FILE")}"
echo "  Score:  ${score} (${tier})"
for b in "${breakdown[@]:-}"; do echo "$b"; done
echo "───────────────────────────────────────"

[[ "$tier" == "HIGH" ]] && exit 1
exit 0
