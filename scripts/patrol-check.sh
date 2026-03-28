#!/usr/bin/env bash
# patrol-check.sh — OpenMOSS-inspired Patrol Agent
# Dedicated monitoring: detect stuck sessions and trigger recovery
# Run via HEARTBEAT.md every N heartbeats, or standalone
#
# What it patrols:
#   1. Subagent sessions with no activity for >15 min → stuck detection
#   2. Sessions in "running" state but no progress → zombie detection
#   3. Recent completions with failures → error flagging
#
# Actions on detection:
#   - Log to memory/patrol-log.json
#   - Optionally alert via agentmail
#   - Optionally auto-kill stuck sessions
#
# Usage: patrol-check.sh [--kill] [--alert]
#   --kill  : auto-kill sessions confirmed stuck (>30 min inactive)
#   --alert  : send agentmail alert if critical stuck found

set -euo pipefail

KILL_MODE=false
ALERT_MODE=false
PATROL_LOG="$HOME/.openclaw/workspace/memory/patrol-log.json"
STUCK_THRESHOLD_MIN=15
ZOMBIE_THRESHOLD_MIN=30
# AGENTMAIL_READY removed (was unused — patrol-check does not send email directly)

# ── Args ──────────────────────────────────────────────────────────────────────
for arg in "$@"; do
    case "$arg" in
        --kill)  KILL_MODE=true ;;
        --alert) ALERT_MODE=true ;;
    esac
done

# ── Helpers ─────────────────────────────────────────────────────────────────
log()  { echo "[patrol] $(date '+%Y-%m-%d %H:%M:%S') $*"; }
now_ts() { date +%s; }
mins_since() { echo $(( ($(now_ts) - $1) / 60 )); }

# ── Load sessions ─────────────────────────────────────────────────────────────
SESSIONS_FILE="$HOME/.openclaw/agents/main/sessions/sessions.json"
if [ ! -f "$SESSIONS_FILE" ]; then
    log "⚠️  Sessions file not found: $SESSIONS_FILE"
    exit 0
fi

# ── Patrol: Check running sessions ─────────────────────────────────────────────
log "Starting patrol sweep..."

STUCK_COUNT=0
ZOMBIE_COUNT=0
ALERTS=()

# Get all session keys
SESSION_KEYS=$(jq -r 'keys[]' "$SESSIONS_FILE" 2>/dev/null || echo "")

for key in $SESSION_KEYS; do
    # Skip non-agent sessions
    if ! echo "$key" | grep -q "agent:main"; then
        continue
    fi

    # Get session state
    STATE=$(jq -r ".[\"$key\"].state // \"unknown\"" "$SESSIONS_FILE" 2>/dev/null)
    LAST_ACTIVITY=$(jq -r ".[\"$key\"].lastActivity // 0" "$SESSIONS_FILE" 2>/dev/null)
    LABEL=$(jq -r ".[\"$key\"].label // \"unknown\"" "$SESSIONS_FILE" 2>/dev/null)
    SESSION_ID=$(jq -r ".[\"$key\"].sessionId // \"unknown\"" "$SESSIONS_FILE" 2>/dev/null)

    if [ "$STATE" = "unknown" ] || [ "$LAST_ACTIVITY" = "0" ]; then
        continue
    fi

    INACTIVE_MINS=$(mins_since "$LAST_ACTIVITY")

    case "$STATE" in
        running)
            if [ "$INACTIVE_MINS" -ge "$ZOMBIE_THRESHOLD_MIN" ]; then
                log "🚨 ZOMBIE: $key (label=$LABEL, inactive=${INACTIVE_MINS}min)"
                ZOMBIE_COUNT=$((ZOMBIE_COUNT + 1))
                ALERTS+=("ZOMBIE session: $LABEL (${INACTIVE_MINS}min inactive)")
                
                if [ "$KILL_MODE" = "true" ]; then
                    log "   → Killing zombie session: $key"
                    # Remove from sessions.json
                    jq "del(.[\"$key\"])" "$SESSIONS_FILE" > /tmp/sessions_patrol.json && \
                        mv /tmp/sessions_patrol.json "$SESSIONS_FILE"
                    # Remove transcript
                    [ -f "$HOME/.openclaw/agents/main/sessions/${SESSION_ID}.jsonl" ] && \
                        rm -f "$HOME/.openclaw/agents/main/sessions/${SESSION_ID}.jsonl"
                fi
            elif [ "$INACTIVE_MINS" -ge "$STUCK_THRESHOLD_MIN" ]; then
                log "⚠️  STUCK: $key (label=$LABEL, inactive=${INACTIVE_MINS}min)"
                STUCK_COUNT=$((STUCK_COUNT + 1))
                ALERTS+=("STUCK session: $LABEL (${INACTIVE_MINS}min inactive)")
            fi
            ;;
    esac
done

# ── Log patrol results ────────────────────────────────────────────────────────
mkdir -p "$(dirname "$PATROL_LOG")"
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

if [ ${#ALERTS[@]} -gt 0 ]; then
    ALERTS_JSON=$(printf '"%s",' "${ALERTS[@]}" | sed 's/,$//')
    PATROL_ENTRY="{\"timestamp\":\"$TIMESTAMP\",\"stuck\":$STUCK_COUNT,\"zombies\":$ZOMBIE_COUNT,\"alerts\":[$ALERTS_JSON]}"
else
    PATROL_ENTRY="{\"timestamp\":\"$TIMESTAMP\",\"stuck\":$STUCK_COUNT,\"zombies\":$ZOMBIE_COUNT,\"alerts\":[]}"
fi

if [ -f "$PATROL_LOG" ]; then
    TEMP=$(mktemp)
    jq ". + [$PATROL_ENTRY]" "$PATROL_LOG" 2>/dev/null | \
        jq ".[-100:]" > "$TEMP" && mv "$TEMP" "$PATROL_LOG"
else
    echo "[$PATROL_ENTRY]" > "$PATROL_LOG"
fi

# ── Alert via agentmail if critical ──────────────────────────────────────────
if [ "$ALERT_MODE" = "true" ] && [ "$ZOMBIE_COUNT" -gt 0 ]; then
    log "📧 Sending patrol alert..."
    # Agentmail alert would go here — requires Mkra's agentmail inbox
    # For now, log that we would alert
    log "   → Would alert: $ZOMBIE_COUNT zombies found"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════"
echo "  PATROL REPORT"
echo "═══════════════════════════════════════"
echo "  Timestamp:  $TIMESTAMP"
echo "  Stuck:       $STUCK_COUNT (${STUCK_THRESHOLD_MIN}-${ZOMBIE_THRESHOLD_MIN} min inactive)"
echo "  Zombies:     $ZOMBIE_COUNT (>${ZOMBIE_THRESHOLD_MIN} min inactive)"
echo "  Kill mode:   $KILL_MODE"
echo "  Alert mode:  $ALERT_MODE"
if [ ${#ALERTS[@]} -gt 0 ]; then
    echo ""
    echo "  Alerts:"
    for a in "${ALERTS[@]}"; do
        echo "    • $a"
    done
fi
echo "═══════════════════════════════════════"
echo "  Patrol log: $PATROL_LOG"
echo "  Logged: $(echo "$PATROL_ENTRY" | jq -c .)"
