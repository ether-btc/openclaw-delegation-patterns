#!/bin/bash
#
# select-model.sh — Weighted scoring model router
# Usage: source this script, then call select_model "<task_description>"
#
# Score = (file_count × 1.5) + (code_lines × 0.1) + (unknown_domain_boost × 5)
# Score > 10 → kimik2thinking
# Otherwise → qwen3-coder (code) or qwen35 (general) or deepseek32 (quick)
#
# Examples:
#   source scripts/select-model.sh && select_model "write a 300-line script"
#   select_model "fix bug in 3 files" qwen3-coder  # override
#
# Outputs: model name (qwen3-coder, kimik2thinking, deepseek32, qwen35)

set -euo pipefail

# shellcheck disable=SC2034  # SCRIPT_DIR reserved for future use
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# WORKSPACE removed (was unused)

# ─── Detection helpers ─────────────────────────────────────────────────────────

count_files_in_task() {
    # Count explicit file/directory mentions in task
    echo "$1" | grep -oiE '[a-zA-Z0-9_/-]+\.(md|ts|js|py|sh|bash|json|yaml|yml|go|rs|lua|toml|cfg|ini|conf|html|css|sql)' | wc -l
}

count_code_lines_estimate() {
    # Extract numeric estimates of code lines from task
    # Matches: "400 lines", "400-line", "400LOC", "400 lines of code"
    echo "$1" | grep -oiE '[0-9]+[-\s]*(lines?|LOC|code|LoC)?' | grep -oE '[0-9]+' | sort -rn | head -1 || echo "0"
}

is_unknown_domain() {
    # Keywords suggesting unknown/new domain
    local task="$1"
    for kw in "research" "analyze" "audit" "review" "unknown" "figure out" "investigate" "plan" "design architecture"; do
        if echo "$task" | grep -qi "$kw"; then
            return 0  # true — unknown domain
        fi
    done
    return 1  # false — known domain
}

is_quick_task() {
    local task="$1"
    for kw in "status" "check if" "is X" "simple" "quick" "just" "look up" "find"; do
        if echo "$task" | grep -qi "$kw"; then
            return 0
        fi
    done
    return 1
}

is_general_review() {
    local task="$1"
    for kw in "review" "summarize" "document" "read and" "assess"; do
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

# ─── Main scoring ─────────────────────────────────────────────────────────────

select_model() {
    local TASK="${1:-}"
    local FORCE_MODEL="${2:-}"

    if [[ -z "$TASK" ]]; then
        echo "Usage: select_model \"task description\" [force_model]" >&2
        echo "  Models: qwen3-coder, kimik2thinking, deepseek32, qwen35" >&2
        return 1
    fi

    # Force override — for explicit model requests
    if [[ -n "$FORCE_MODEL" ]]; then
        echo "$FORCE_MODEL"
        return 0
    fi

    # Quick tasks → deepseek32
    if is_quick_task "$TASK"; then
        echo "deepseek32"
        return 0
    fi

    # General review/summary → qwen35
    if is_general_review "$TASK"; then
        echo "qwen35"
        return 0
    fi

    # Pure code generation, known domain, small scope → qwen3-coder
    if is_pure_code "$TASK"; then
        local files
        files=$(count_files_in_task "$TASK")
        local lines
        lines=$(count_code_lines_estimate "$TASK")
        local unknown=0
        is_unknown_domain "$TASK" && unknown=1

        # Score = (files × 1.5) + (lines × 0.1) + (unknown × 5)
        # Scaled ×10: score10 = files*15 + lines_scaled + unknown*50
        # lines_scaled = lines × 1 (since 0.1 × 10 = 1)
        local score10=$(( files * 15 + lines + unknown * 50 ))

        if [[ $score10 -gt 100 ]] || [[ $unknown -eq 1 && $files -gt 3 ]]; then
            echo "kimik2thinking"
        else
            echo "qwen3-coder"
        fi
        return 0
    fi

    # Default: unknown domain → kimik2thinking
    if is_unknown_domain "$TASK"; then
        echo "kimik2thinking"
        return 0
    fi

    # Catch-all: qwen35 for general reasoning
    echo "qwen35"
    return 0
}

# If sourced, all functions are available. If executed directly, run selection.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    select_model "$@"
fi
