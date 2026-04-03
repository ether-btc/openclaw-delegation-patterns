#!/bin/bash
# scripts/plan-mode-check.sh
# Determines if a task requires planning mode
# Returns: "PLAN_MODE" or "DIRECT_EXECUTION"

set -euo pipefail

# Configuration
WORKSPACE="${OC_WORKSPACE:-$HOME/.openclaw/workspace}"
LOG_FILE="$WORKSPACE/memory/plan-mode-detection.log"
TASK="${1:-}"

# Helper functions
log_decision() {
    local mode="$1"
    local reason="$2"
    local timestamp
    timestamp=$(date -Iseconds)
    echo "[$timestamp] $mode | $reason | Task: $(echo "$TASK" | head -c 100)..." >> "$LOG_FILE"
}

count_bullet_points() {
    local count
    count=$(echo "$TASK" | grep -cE '^\s*[-*]\s+' 2>/dev/null)
    echo "${count:-0}"
}

count_paragraphs() {
    echo "$TASK" | awk 'BEGIN{p=0} NF>0{p++} /^$/{if(NF>0)p++} END{print p}' | tr -d ' '
}

count_sentences() {
    local count
    count=$(echo "$TASK" | grep -oE '[.!?]+' 2>/dev/null | wc -l | tr -d ' ')
    echo "${count:-0}"
}

check_keywords() {
    local keywords="$1"
    for keyword in $keywords; do
        if echo "$TASK" | grep -qiE "\b$keyword\b"; then
            return 0  # Found
        fi
    done
    return 1  # Not found
}

# Detection logic
main() {
    if [ -z "$TASK" ]; then
        log_decision "DIRECT_EXECUTION" "Empty task"
        echo "DIRECT_EXECUTION"
        return 0
    fi

    # Check 1: User override (highest priority)
    if check_keywords "quick fix no plan needed skip plan --direct"; then
        log_decision "DIRECT_EXECUTION" "User override"
        echo "DIRECT_EXECUTION"
        return 0
    fi

    # Check 2: Low complexity
    if check_keywords "what is how do i check status read file tell me"; then
        log_decision "DIRECT_EXECUTION" "Low complexity"
        echo "DIRECT_EXECUTION"
        return 0
    fi

    # Initialize score
    score=0
    reasons=()

    # Check 3: Bullet points
    bullet_count=$(count_bullet_points | tr -d ' ')
    if [ "$bullet_count" -ge 3 ]; then
        score=$((score + 2))
        reasons+=("3+ bullet points ($bullet_count)")
    fi

    # Check 4: Paragraphs
    paragraph_count=$(count_paragraphs | tr -d ' ')
    if [ "$paragraph_count" -gt 1 ]; then
        score=$((score + 1))
        reasons+=(">1 paragraph ($paragraph_count)")
    fi

    # Check 5: Sentences
    sentence_count=$(count_sentences | tr -d ' ')
    if [ "$sentence_count" -gt 5 ]; then
        reasons+=(">5 sentences ($sentence_count)")
    fi

    # Check 6: Keywords (complexity)
    if check_keywords "build implement refactor architecture design create system multi-step complex"; then
        score=$((score + 1))
        reasons+=("Complexity keyword")
    fi

    # Check 7: User explicit request
    if check_keywords "multi-step complex task needs planning"; then
        score=$((score + 2))
        reasons+=("User explicit request")
    fi

    # Decision
    if [ $score -ge 1 ]; then
        log_decision "PLAN_MODE" "Score: $score, Reasons: ${reasons[*]}"
        echo "PLAN_MODE"
    else
        log_decision "DIRECT_EXECUTION" "Score: $score, Simple task"
        echo "DIRECT_EXECUTION"
    fi
}

# Run main function
main "$@"
