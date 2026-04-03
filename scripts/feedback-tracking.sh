#!/bin/bash
# feedback-tracking.sh — Staff Engineer feedback tracking CLI
# Usage: feedback-tracking.sh [create|update|close|log] <project> [args...]

set -euo pipefail

PROJECT="${1:-}"
ACTION="${2:-}"
shift 2 || true

FEEDBACK_FILE="$HOME/.openclaw/workspace/results/${PROJECT}/feedback-tracking.json"
CHECKPOINT_FILE="$HOME/.openclaw/workspace/results/${PROJECT}/checkpoint.json"

init() {
    mkdir -p "$(dirname "$FEEDBACK_FILE")"
    cat > "$FEEDBACK_FILE" <<EOF
{
  "project": "${PROJECT}",
  "review_cycle": 1,
  "reviewer": "Staff Engineer (kimik2thinking)",
  "review_session": "",
  "status": "OPEN",
  "items": [],
  "summary": "",
  "reviewed_at": "$(date -Iseconds)",
  "closed_at": null
}
EOF
    echo "Created: $FEEDBACK_FILE"
}

add_item() {
    local id="$1" source="$2" description="$3" priority="${4:-MEDIUM}"
    local assigned_to="${5:-orchestrator}"

    local items
    items=$(jq --arg id "$id" --arg source "$source" --arg desc "$description" \
        --arg priority "$priority" --arg assigned "$assigned_to" \
        '.items += [{
            id: $id,
            source: $source,
            description: $desc,
            priority: $priority,
            assigned_to: $assigned,
            status: "OPEN",
            resolution_note: null,
            addressed_at: null
        }]' "$FEEDBACK_FILE")
    echo "$items" | jq '.' > "$FEEDBACK_FILE"
}

update_status() {
    local item_id="$1" new_status="$2" resolution="${3:-}"
    local addressed_at
    [[ "$new_status" == "ADDRESSED" ]] && addressed_at="$(date -Iseconds)" || addressed_at="null"

    local items
    items=$(jq --arg id "$item_id" --arg status "$new_status" \
        --arg resolved "$resolution" --argaddr "$addressed_at" \
        '.items |= map(if .id == $id then
            .status = $status |
            .resolution_note = $resolved |
            .addressed_at = ($addressed_at | if . == "null" then null else . end)
        else . end)' "$FEEDBACK_FILE")
    echo "$items" | jq '.' > "$FEEDBACK_FILE"
}

close_review() {
    local summary="${1:-}"
    local tmp
    tmp=$(mktemp "${FEEDBACK_FILE}.XXXXXX") || return 1
    jq --arg status "CLOSED" --arg summary "$summary" \
        --arg closed "$(date -Iseconds)" \
        '.status = $status | .summary = $summary | .closed_at = $closed' \
        "$FEEDBACK_FILE" > "$tmp" && mv "$tmp" "$FEEDBACK_FILE" || {
        rm -f "$tmp"
        echo "Error: failed to update $FEEDBACK_FILE" >&2
        return 1
    }
}

set_cycle() {
    local cycle="$1"
    local tmp
    tmp=$(mktemp "${FEEDBACK_FILE}.XXXXXX") || return 1
    jq --arg cycle "$cycle" '.review_cycle = ($cycle | tonumber)' \
        "$FEEDBACK_FILE" > "$tmp" && mv "$tmp" "$FEEDBACK_FILE" || {
        rm -f "$tmp"
        echo "Error: failed to update $FEEDBACK_FILE" >&2
        return 1
    }
}

log_to_memory-system() {
    local event="$1"
    $HOME/.openclaw/workspace/scripts/memory-system-cli.sh log_event "$event" review 2>/dev/null || true
}

case "${ACTION}" in
    init)
        init
        ;;
    add-item)
        add_item "$@"
        ;;
    update-status)
        update_status "$@"
        ;;
    close)
        close_review "$@"
        log_to_memory-system "Staff Engineer review CLOSED for ${PROJECT}"
        ;;
    set-cycle)
        set_cycle "$@"
        ;;
    show)
        cat "$FEEDBACK_FILE"
        ;;
    *)
        echo "Usage: feedback-tracking.sh <project> [init|add-item|update-status|close|set-cycle|show] [args...]"
        echo "  init <project>                     — create feedback-tracking.json"
        echo "  add-item <id> <source> <desc> [HIGH|MED|LOW] — add feedback item"
        echo "  update-status <id> <OPEN|ADDRESSED|REJECTED> [note] — update item"
        echo "  close <project> [summary]           — close review, log to MemorySystem"
        echo "  set-cycle <project> <N>            — increment review cycle"
        echo "  show <project>                     — display tracking file"
        ;;
esac
