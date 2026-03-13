#!/bin/bash
#
# Delegate Enforcer Script
# Validates and routes delegation to appropriate model/agent
#
# Usage: ./delegate-enforcer.sh <task-description> <model-type>
#
# Exit codes:
#   0 - Success
#   1 - Invalid input/error
#

set -e

# Validate arguments
if [ $# -lt 2 ]; then
    echo "Error: Missing required parameters" >&2
    echo "Usage: $0 <task-description> <model-type>" >&2
    echo "" >&2
    echo "Valid model types:" >&2
    echo "  coding           → agentId: qwen3-coder" >&2
    echo "  reasoning        → agentId: kimik2thinking" >&2
    echo "  quick            → model: kilocode/minimax/minimax-m2.5:free" >&2
    echo "  fast-reasoning   → model: zai/glm-4.7" >&2
    echo "  heavy-reasoning  → agentId: deepseek-reasoner" >&2
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
        AGENT_ID="qwen3-coder"
        echo "agentId: $AGENT_ID"
        ;;
    reasoning)
        AGENT_ID="kimik2thinking"
        echo "agentId: $AGENT_ID"
        ;;
    quick)
        MODEL="kilocode/minimax/minimax-m2.5:free"
        echo "model: $MODEL"
        ;;
    fast-reasoning)
        MODEL="zai/glm-4.7"
        echo "model: $MODEL"
        ;;
    heavy-reasoning)
        AGENT_ID="deepseek-reasoner"
        echo "agentId: $AGENT_ID"
        ;;
    *)
        echo "Error: Invalid model type: $MODEL_TYPE" >&2
        echo "" >&2
        echo "Valid model types:" >&2
        echo "  coding           → agentId: qwen3-coder" >&2
        echo "  reasoning        → agentId: kimik2thinking" >&2
        echo "  quick            → model: kilocode/minimax/minimax-m2.5:free" >&2
        echo "  fast-reasoning   → model: zai/glm-4.7" >&2
        echo "  heavy-reasoning  → agentId: deepseek-reasoner" >&2
        exit 1
        ;;
esac

exit 0
