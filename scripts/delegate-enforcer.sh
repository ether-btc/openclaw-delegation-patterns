#!/bin/bash
#
# Delegate Enforcer Script
# Validates and routes delegation to appropriate model
#
# Usage: ./delegate-enforcer.sh <task-description> <model-type>
#
# Exit codes:
#   0 - Success (model written to stdout)
#   1 - Invalid input/error
#

set -e

# Validate arguments
if [ $# -lt 2 ]; then
    echo "Error: Missing required parameters" >&2
    echo "Usage: $0 <task-description> <model-type>" >&2
    echo "" >&2
    echo "Valid model types:" >&2
    echo "  coding           → model: qwen3-coder" >&2
    echo "  reasoning        → model: nvidia/moonshotai/kimi-k2-thinking" >&2
    echo "  general          → model: nvidia/moonshotai/kimi-k2.5" >&2
    echo "  quick            → model: minimax/MiniMax-M2.7" >&2
    echo "  fast-reasoning   → model: zai/glm-4.7" >&2
    echo "  heavy-reasoning  → model: nvidia/deepseek-ai/deepseek-v3.2" >&2
    echo "  fast-alt         → model: google/gemini-2.5-flash-lite" >&2
    exit 1
fi

TASK_DESCRIPTION="$1"
MODEL_TYPE="$2"

# Validate task description is not empty
if [ -z "$TASK_DESCRIPTION" ]; then
    echo "Error: Task description cannot be empty" >&2
    exit 1
fi

# Model selection logic based on type
case "$MODEL_TYPE" in
    coding)
        echo "model: qwen3-coder"
        ;;
    reasoning)
        echo "model: nvidia/moonshotai/kimi-k2-thinking"
        ;;
    general)
        echo "model: nvidia/moonshotai/kimi-k2.5"
        ;;
    quick)
        echo "model: minimax/MiniMax-M2.7"
        ;;
    fast-reasoning)
        echo "model: zai/glm-4.7"
        ;;
    heavy-reasoning)
        echo "model: nvidia/deepseek-ai/deepseek-v3.2"
        ;;
    fast-alt)
        echo "model: google/gemini-2.5-flash-lite"
        ;;
    *)
        echo "Error: Invalid model type: $MODEL_TYPE" >&2
        echo "" >&2
        echo "Valid model types:" >&2
        echo "  coding           → model: qwen3-coder" >&2
        echo "  reasoning        → model: nvidia/moonshotai/kimi-k2-thinking" >&2
        echo "  general          → model: nvidia/moonshotai/kimi-k2.5" >&2
        echo "  quick            → model: minimax/MiniMax-M2.7" >&2
        echo "  fast-reasoning   → model: zai/glm-4.7" >&2
        echo "  heavy-reasoning  → model: nvidia/deepseek-ai/deepseek-v3.2" >&2
        echo "  fast-alt         → model: google/gemini-2.5-flash-lite" >&2
        exit 1
        ;;
esac

exit 0
