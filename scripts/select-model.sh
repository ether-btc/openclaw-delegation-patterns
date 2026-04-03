#!/bin/bash
#
# select-model.sh — Model router for delegation
# Usage: source this script, then call select_model "<task_description>"
#
# Decision tree (in order):
#   1. Multimodal input? → gemini-flite
#   2. Large context (>2000 lines, >10 files)? → GLM-5.1
#   3. Quick task? → deepseek32
#   4. General review/summary? → qwen35
#   5. Pure code, score <10? → qwen3-coder
#   6. Pure code, score >=10? → minimax-hs (fast + large context)
#   7. Unknown domain/research? → kimik2thinking
#   8. Default → qwen35
#
# Score = (files × 1.5) + (lines × 0.1) + (unknown × 5); threshold > 10
# Score > 10 → kimik2thinking (research/analysis route)
#
# Available models: qwen3-coder, kimik2thinking, deepseek32, qwen35,
#                   gemini-flite, minimax-hs, GLM-5.1, GLM-4.7, Minimax
#   source scripts/select-model.sh && select_model "fix bug in 3 files"
#   select_model "analyze this codebase"  # -> kimik2thinking
#   select_model "screenshot of error"   # -> gemini-flite
#   select_model "heartbeat check"      # -> GLM-4.7

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ─── Detection helpers ─────────────────────────────────────────────────────────

count_files_in_task() {
    echo "$1" | grep -oiE '[a-zA-Z0-9_/-]+\.(md|ts|js|py|sh|bash|json|yaml|yml|go|rs|lua|toml|cfg|ini|conf|html|css|sql)' | wc -l
}

count_code_lines_estimate() {
    echo "$1" | grep -oiE '[0-9]+[-\s]*(lines?|LOC|code|LoC)?' | grep -oE '[0-9]+' | sort -rn | head -1 || echo "0"
}

is_unknown_domain() {
    local task="$1"
    for kw in "research" "analyze" "audit" "review" "unknown" "figure out" "investigate" "plan" "design architecture"; do
        if echo "$task" | grep -qi "$kw"; then
            return 0
        fi
    done
    return 1
}

is_quick_task() {
    local task="$1"
    for kw in "status" "check if" "is X" "simple" "quick" "just" "look up" "find" "list"; do
        if echo "$task" | grep -qi "$kw"; then
            return 0
        fi
    done
    return 1
}

is_general_review() {
    local task="$1"
    for kw in "review" "summarize" "document" "read and" "assess" "summarise"; do
        if echo "$task" | grep -qi "$kw"; then
            return 0
        fi
    done
    return 1
}

is_pure_code() {
    local task="$1"
    for kw in "write" "implement" "fix" "refactor" "add" "create" "build"; do
        if echo "$task" | grep -qi "$kw"; then
            return 0
        fi
    done
    return 1
}

is_multimodal() {
    local task="$1"
    for kw in "screenshot" "image" "ocr" "scan" "photo" "picture" "screenshot" "error screen"; do
        if echo "$task" | grep -qi "$kw"; then
            return 0
        fi
    done
    return 1
}

is_large_context() {
    local task="$1"
    for kw in "large codebase" "full repo" "many files" "entire project" "whole codebase" "all files"; do
        if echo "$task" | grep -qi "$kw"; then
            return 0
        fi
    done
    return 1
}

# ─── Main router ──────────────────────────────────────────────────────────────

select_model() {
    local TASK="${1:-}"
    local FORCE_MODEL="${2:-}"

    if [[ -z "$TASK" ]]; then
        echo "Usage: select_model \"task description\" [force_model]" >&2
        echo "  Models: qwen3-coder, kimik2thinking, deepseek32, GLM-4.7, qwen35, gemini-flite, minimax-hs, GLM-5.1" >&2
        return 1
    fi

    # Force override
    if [[ -n "$FORCE_MODEL" ]]; then
        echo "$FORCE_MODEL"
        return 0
    fi

    # 1. Multimodal → gemini-flite
    if is_multimodal "$TASK"; then
        echo "gemini-flite"
        return 0
    fi

    # 2. Large context → GLM-5.1 (200k)
    if is_large_context "$TASK"; then
        echo "GLM-5.1"
        return 0
    fi

    # 3. Quick tasks → GLM-4.7 (lightweight heartbeat-friendly)
    if is_quick_task "$TASK"; then
        echo "GLM-4.7"
        return 0
    fi

    # 4. General review/summary → qwen35
    if is_general_review "$TASK"; then
        echo "qwen35"
        return 0
    fi

    # 5. Pure code generation
    if is_pure_code "$TASK"; then
        local files
        files=$(count_files_in_task "$TASK")
        local lines
        lines=$(count_code_lines_estimate "$TASK")
        local unknown=0
        is_unknown_domain "$TASK" && unknown=1

        # Score = (files × 1.5) + (lines × 0.1) + (unknown × 5); threshold > 10
        local score
        score=$(echo "$files * 1.5 + $lines * 0.1 + $unknown * 5" | bc 2>/dev/null | cut -d. -f1) || score=0
        score=${score:-0}
        # Guard against non-numeric score (bc unavailable or expression error)
        [[ "$score" =~ ^[0-9]+$ ]] || score=0

        if [[ $score -gt 10 ]] || [[ $unknown -eq 1 && $files -gt 3 ]]; then
            # Large scope or unknown domain -> minimax-hs (fast + large context)
            echo "minimax-hs"
        else
            # Small scope pure code -> qwen3-coder
            echo "qwen3-coder"
        fi
        return 0
    fi

    # 6. Unknown domain / research → kimik2thinking
    if is_unknown_domain "$TASK"; then
        echo "kimik2thinking"
        return 0
    fi

    # 7. Catch-all → qwen35
    echo "qwen35"
    return 0
}

# If sourced, functions available. If executed directly, run selection.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    select_model "$@"
fi
