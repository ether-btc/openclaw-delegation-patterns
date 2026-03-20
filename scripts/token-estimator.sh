#!/bin/bash
#
# Token Estimator
# Estimates token count for task prompts to detect when chunking is needed
#

# Default thresholds
DEFAULT_CHUNK_THRESHOLD="${CHUNK_THRESHOLD:-50000}"  # 50k tokens (conservative)
DEFAULT_WARN_THRESHOLD="${WARN_THRESHOLD:-40000}"     # 40k tokens

# System prompt overhead (minimum expected)
# Includes: system prompt (~5k), tool definitions (~3k), context overhead (~2k)
SYSTEM_PROMPT_OVERHEAD=10000

# Context limits per model (tokens)
declare -A MODEL_LIMITS=(
    ["qwen3-coder"]=32000
    ["kimik2thinking"]=128000
    ["deepseek-reasoner"]=64000
    ["minimax-m2.5:free"]=204800
    ["glm-4.7"]=128000
    ["gpt-5.2"]=204800
)

# Estimate tokens using character heuristic (fallback)
estimate_chars() {
    local text="$1"
    echo "$text" | wc -c | awk '{printf "%.0f", $1/4}'
}

# Estimate tokens using word count (rough approximation)
estimate_words() {
    local text="$1"
    local words=$(echo "$text" | wc -w)
    # Average token is ~0.75 words in English
    echo "$words" | awk '{printf "%.0f", $1/0.75}'
}

# Main estimation function
estimate_tokens() {
    local text="$1"
    local method="${2:-auto}"
    
    # Always use character-based estimation (more accurate for prompts)
    # ~4 characters = 1 token for English text
    local chars=$(echo "$text" | wc -c)
    local tokens=$((chars / 4))
    
    if [ "$method" = "words" ]; then
        # Alternative: word-based
        local words=$(echo "$text" | wc -w)
        tokens=$((words * 133 / 100))  # ~1.33 tokens per word
    fi
    
    # Add system prompt overhead for full prompt estimation
    tokens=$((tokens + SYSTEM_PROMPT_OVERHEAD))
    
    echo "$tokens"
}

# Estimate complexity based on task description (for chunking decision)
estimate_complexity() {
    local text="$1"
    local words=$(echo "$text" | wc -w)
    
    # Heuristic: complex tasks have long descriptions or specific keywords
    local complexity=3  # Base complexity
    
    # Check for complexity indicators (each adds 1-2 points)
    echo "$text" | grep -qiE "analyze|review|audit" && complexity=$((complexity + 2))
    echo "$text" | grep -qiE "refactor|implement|create|build" && complexity=$((complexity + 2))
    echo "$text" | grep -qiE "multiple|all files|repository|comprehensive" && complexity=$((complexity + 2))
    echo "$text" | grep -qiE "test|unit test|integration" && complexity=$((complexity + 1))
    
    # Scale by word count (more words = more complex)
    if [ "$words" -gt 100 ]; then
        complexity=$((complexity + 3))
    elif [ "$words" -gt 50 ]; then
        complexity=$((complexity + 2))
    elif [ "$words" -gt 25 ]; then
        complexity=$((complexity + 1))
    fi
    
    # Return complexity 1-10
    if [ "$complexity" -gt 10 ]; then
        complexity=10
    fi
    
    echo "$complexity"
}

# Check if chunking is needed for a task
check_chunk_needed() {
    local task="$1"
    local context="${2:-}"
    local threshold="${3:-$DEFAULT_CHUNK_THRESHOLD}"
    
    # Combine task and context
    local combined="$task"
    [ -n "$context" ] && [ -f "$context" ] && combined="$combined $(cat "$context")"
    
    local tokens=$(estimate_tokens "$combined")
    
    if [ "$tokens" -gt "$threshold" ]; then
        echo "CHUNK_NEEDED:$tokens:$threshold"
        return 0
    else
        echo "OK:$tokens:$threshold"
        return 1
    fi
}

# Get model-specific threshold
get_model_threshold() {
    local model="$1"
    local limit="${MODEL_LIMITS[$model]:-204800}"
    # Use 80% of model limit as threshold
    echo $((limit * 80 / 100))
}

# Warn if approaching limit
check_warn() {
    local task="$1"
    local model="${2:-minimax-m2.5:free}"
    local threshold=$(get_model_threshold "$model")
    
    local tokens=$(estimate_tokens "$task")
    local warn_threshold=$((threshold * 80 / 100))
    
    if [ "$tokens" -gt "$warn_threshold" ]; then
        echo "WARN:$tokens:$warn_threshold:$threshold"
        return 1
    fi
    echo "OK:$tokens:$warn_threshold"
    return 0
}

# Test mode
if [ "$1" = "test" ]; then
    echo "Token Estimator Test"
    echo "===================="
    test_text="This is a test task with approximately 20 words that should be well under the token threshold."
    tokens=$(estimate_tokens "$test_text")
    echo "Test text: '$test_text'"
    echo "Estimated tokens: $tokens"
    echo "Threshold: $DEFAULT_CHUNK_THRESHOLD"
    result=$(check_chunk_needed "$test_text")
    echo "Result: $result"
    exit 0
fi

# CLI mode
case "$1" in
    estimate)
        estimate_tokens "${2:-}" "${3:-auto}"
        ;;
    check)
        check_chunk_needed "${2:-}" "${3:-}" "${4:-}"
        ;;
    threshold)
        get_model_threshold "${2:-minimax-m2.5:free}"
        ;;
    warn)
        check_warn "${2:-}" "${3:-}"
        ;;
    complexity)
        estimate_complexity "${2:-}"
        ;;
    *)
        echo "Usage: $0 {estimate|check|threshold|warn|complexity} [args...]"
        echo "  estimate <text> [method]     - Estimate tokens in text"
        echo "  check <task> [context] [threshold] - Check if chunk needed"
        echo "  threshold <model>            - Get chunk threshold for model"
        echo "  warn <task> [model]         - Warn if approaching limit"
        echo "  complexity <text>            - Estimate complexity (1-10)"
        exit 1
        ;;
esac
