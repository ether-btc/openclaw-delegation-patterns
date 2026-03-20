#!/bin/bash
#
# Chunk Analyzer
# Analyzes tasks to determine chunking strategy and create chunk manifests
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOKEN_ESTIMATOR="$SCRIPT_DIR/token-estimator.sh"

# Chunk storage
CHUNK_DIR="${CHUNK_DIR:-$HOME/.openclaw/workspace/memory/chunks}"

# Default strategies
STRATEGY_SEQUENTIAL="sequential"  # A→B→C - ordered dependencies
STRATEGY_PARALLEL="parallel"      # A|B|C - independent tasks
STRATEGY_PIPELINE="pipeline"       # A→B→C - output feeds input

# Analyze task to determine if chunking is needed
analyze_task() {
    local task="$1"
    local context="${2:-}"
    
    # Get token estimate
    local token_result
    if [ -n "$context" ] && [ -f "$context" ]; then
        token_result=$("$TOKEN_ESTIMATOR" check "$task" "$context")
    else
        token_result=$("$TOKEN_ESTIMATOR" check "$task")
    fi
    
    local status=$(echo "$token_result" | cut -d: -f1)
    local tokens=$(echo "$token_result" | cut -d: -f2)
    local threshold=$(echo "$token_result" | cut -d: -f3)
    
    # Also check complexity (1-10)
    local complexity=$("$TOKEN_ESTIMATOR" complexity "$task")
    
    echo "TOKENS:$tokens"
    echo "THRESHOLD:$threshold"
    echo "COMPLEXITY:$complexity"
    
    # Chunk needed if: tokens exceed threshold OR complexity is high (7+)
    if [ "$status" = "CHUNK_NEEDED" ] || [ "$complexity" -ge 7 ]; then
        echo "CHUNKING:RECOMMENDED"
        return 0
    fi
    return 1
}

# Determine best chunking strategy based on task analysis
determine_strategy() {
    local task="$1"
    
    # Keywords that indicate dependencies (sequential)
    local sequential_keywords="then|after|following|based on|depending on|once|next"
    if echo "$task" | grep -qiE "$sequential_keywords"; then
        echo "$STRATEGY_SEQUENTIAL"
        return
    fi
    
    # Keywords that indicate pipeline (output feeds input)
    local pipeline_keywords="use output|feed into|chain|compose|pipeline|transform"
    if echo "$task" | grep -qiE "$pipeline_keywords"; then
        echo "$STRATEGY_PIPELINE"
        return
    fi
    
    # Keywords that indicate parallel (independent)
    local parallel_keywords="and|also|additionally|separately|independent|each|every"
    if echo "$task" | grep -qiE "$parallel_keywords"; then
        echo "$STRATEGY_PARALLEL"
        return
    fi
    
    # Default: sequential if no clear indicator
    echo "$STRATEGY_SEQUENTIAL"
}

# Create chunk manifest
create_manifest() {
    local task_id="$1"
    local task="$2"
    local strategy="$3"
    local num_chunks="$4"
    
    mkdir -p "$CHUNK_DIR/$task_id"
    
    cat > "$CHUNK_DIR/$task_id/manifest.json" <<EOF
{
    "task_id": "$task_id",
    "original_task": "$task",
    "strategy": "$strategy",
    "num_chunks": $num_chunks,
    "created": "$(date -Iseconds)",
    "status": "pending",
    "chunks": []
}
EOF
    
    echo "$CHUNK_DIR/$task_id/manifest.json"
}

# Split task into chunks based on strategy
split_task() {
    local task_id="$1"
    local task="$2"
    local strategy="$3"
    local num_chunks="${4:-3}"
    
    local manifest=$(create_manifest "$task_id" "$task" "$strategy" "$num_chunks")
    
    case "$strategy" in
        "$STRATEGY_SEQUENTIAL")
            split_sequential "$task_id" "$task" "$num_chunks" "$manifest"
            ;;
        "$STRATEGY_PARALLEL")
            split_parallel "$task_id" "$task" "$num_chunks" "$manifest"
            ;;
        "$STRATEGY_PIPELINE")
            split_pipeline "$task_id" "$task" "$num_chunks" "$manifest"
            ;;
        *)
            echo "ERROR: Unknown strategy: $strategy"
            return 1
            ;;
    esac
}

# Split for sequential execution
split_sequential() {
    local task_id="$1"
    local task="$2"
    local num_chunks="$3"
    local manifest="$4"
    
    # Create sequential chunks
    local chunk_size=$(( (${#task} + num_chunks - 1) / num_chunks ))
    
    for i in $(seq 1 $num_chunks); do
        local start=$(( (i - 1) * chunk_size ))
        local length=$chunk_size
        
        # Find word boundaries
        if [ $i -lt $num_chunks ]; then
            local next_space=$(echo "${task:start}" | grep -ob ' ' | head -1 | cut -d: -f1)
            [ -n "$next_space" ] && length=$next_space
        fi
        
        local chunk_text="${task:start:length}"
        [ -z "$chunk_text" ] && continue
        
        # Add context about being part of sequence
        if [ $i -gt 1 ]; then
            chunk_text="[Part $i of $num_chunks] Previous parts completed. $chunk_text"
        else
            chunk_text="[Part $i of $num_chunks] $chunk_text"
        fi
        
        echo "$chunk_text" > "$CHUNK_DIR/$task_id/chunk_$i.txt"
        
        # Update manifest
        local temp=$(mktemp)
        jq ".chunks += [{\"id\": $i, \"file\": \"chunk_$i.txt\", \"status\": \"pending\"}]" "$manifest" > "$temp" && mv "$temp" "$manifest"
    done
    
    echo "Created $num_chunks sequential chunks in $CHUNK_DIR/$task_id/"
}

# Split for parallel execution
split_parallel() {
    local task_id="$1"
    local task="$2"
    local num_chunks="$3"
    local manifest="$4"
    
    # Split by sentences or logical divisions
    local IFS='.'
    local -a parts=()
    
    # Try to split by conjunctions or natural breaks
    echo "$task" | sed 's/\(and\)/\n/g; s/\(also\)/\n/g; s/\(additionally\)/\n/g' | while read -r part; do
        [ -n "$part" ] && parts+=("$part")
    done
    
    # If we couldn't split naturally, divide by characters
    if [ ${#parts[@]} -lt 2 ]; then
        local chunk_size=$(( (${#task} + num_chunks - 1) / num_chunks ))
        for i in $(seq 1 $num_chunks); do
            local start=$(( (i - 1) * chunk_size ))
            local chunk_text="[Chunk $i of $num_chunks (parallel)] ${task:start:chunk_size}"
            echo "$chunk_text" > "$CHUNK_DIR/$task_id/chunk_$i.txt"
            
            local temp=$(mktemp)
            jq ".chunks += [{\"id\": $i, \"file\": \"chunk_$i.txt\", \"status\": \"pending\"}]" "$manifest" > "$temp" && mv "$temp" "$manifest"
        done
    else
        local i=1
        for part in "${parts[@]}"; do
            [ -n "$part" ] || continue
            local chunk_text="[Chunk $i of ${#parts[@]} (parallel)] $part"
            echo "$chunk_text" > "$CHUNK_DIR/$task_id/chunk_$i.txt"
            
            local temp=$(mktemp)
            jq ".chunks += [{\"id\": $i, \"file\": \"chunk_$i.txt\", \"status\": \"pending\"}]" "$manifest" > "$temp" && mv "$temp" "$manifest"
            i=$((i + 1))
        done
    fi
    
    echo "Created $num_chunks parallel chunks in $CHUNK_DIR/$task_id/"
}

# Split for pipeline execution
split_pipeline() {
    local task_id="$1"
    local task="$2"
    local num_chunks="$3"
    local manifest="$4"
    
    # Pipeline: each chunk's output feeds into the next
    for i in $(seq 1 $num_chunks); do
        if [ $i -eq 1 ]; then
            local chunk_text="[Pipeline Step 1 of $num_chunks] START: $task"
        elif [ $i -eq $num_chunks ]; then
            local chunk_text="[Pipeline Step $i of $num_chunks] FINAL: Complete the task using previous outputs."
        else
            local chunk_text="[Pipeline Step $i of $num_chunks] Continue from previous output. Process and pass forward."
        fi
        
        echo "$chunk_text" > "$CHUNK_DIR/$task_id/chunk_$i.txt"
        
        local temp=$(mktemp)
        jq ".chunks += [{\"id\": $i, \"file\": \"chunk_$i.txt\", \"status\": \"pending\"}]" "$manifest" > "$temp" && mv "$temp" "$manifest"
    done
    
    echo "Created $num_chunks pipeline chunks in $CHUNK_DIR/$task_id/"
}

# Get chunk status
get_status() {
    local task_id="$1"
    local manifest="$CHUNK_DIR/$task_id/manifest.json"
    
    if [ ! -f "$manifest" ]; then
        echo "ERROR: No manifest found for $task_id"
        return 1
    fi
    
    jq -r '.status' "$manifest"
}

# Update chunk status
update_chunk_status() {
    local task_id="$1"
    local chunk_id="$2"
    local status="$3"
    local manifest="$CHUNK_DIR/$task_id/manifest.json"
    
    local temp=$(mktemp)
    jq ".chunks |= map(if .id == $chunk_id then .status = \"$status\" else . end)" "$manifest" > "$temp" && mv "$temp" "$manifest"
}

# Main
case "${1:-}" in
    analyze)
        analyze_task "${2:-}" "${3:-}"
        ;;
    strategy)
        determine_strategy "${2:-}"
        ;;
    split)
        split_task "${2:-}" "${3:-}" "${4:-}" "${5:-3}"
        ;;
    status)
        get_status "${2:-}"
        ;;
    update)
        update_chunk_status "${2:-}" "${3:-}" "${4:-}"
        ;;
    *)
        echo "Usage: $0 {analyze|strategy|split|status|update} [args...]"
        exit 1
        ;;
esac
