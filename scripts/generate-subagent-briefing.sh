#!/bin/bash
# generate-subagent-briefing.sh — Scaffold a subagent briefing doc
# Usage: generate-subagent-briefing.sh --project <name> --task "<desc>" [--files "f1 f2 ..."] [--lines N] [--xrefs N] [--context N]
# Output: results/<project>/briefing.md (template filled, orchestrator completes intent/scope)

set -euo pipefail

PROJECT=""
TASK=""
FILES=""
LINES=0
XREFS=0
CONTEXT=0

while [[ $# -gt 0 ]]; do
  case $1 in
    --project) PROJECT="$2"; shift 2 ;;
    --task) TASK="$2"; shift 2 ;;
    --files) FILES="$2"; shift 2 ;;
    --lines) LINES="$2"; shift 2 ;;
    --xrefs) XREFS="$2"; shift 2 ;;
    --context) CONTEXT="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$PROJECT" ]] || [[ -z "$TASK" ]]; then
  echo "Usage: $0 --project <name> --task '<description>' [--files 'f1 f2'] [--lines N] [--xrefs N] [--context N]" >&2
  exit 1
fi

RESULTS_DIR="$HOME/.openclaw/workspace/results/$PROJECT"
mkdir -p "$RESULTS_DIR"

# Auto-calculate complexity score
if [[ -z "$FILES" ]]; then
  FILE_COUNT=0
else
  FILE_COUNT=$(echo "$FILES" | tr ' ' '\n' | wc -l)
fi
[[ "$LINES" == "" ]] && LINES=0
[[ "$XREFS" == "" ]] && XREFS=0
[[ "$CONTEXT" == "" ]] && CONTEXT=0

# Auto-count lines from files BEFORE scoring (must precede SCORE calculation)
if [[ -n "$FILES" ]]; then
  TOTAL_LINES=0
  for f in $FILES; do
    if [[ -f "$HOME/.openclaw/workspace/$f" ]]; then
      L=$(wc -l < "$HOME/.openclaw/workspace/$f" 2>/dev/null || echo 0)
      TOTAL_LINES=$(( TOTAL_LINES + L ))
    fi
  done
  [[ $TOTAL_LINES -gt 0 ]] && LINES=$TOTAL_LINES
fi

SCORE=$(( FILE_COUNT * 3 + LINES + XREFS * 5 + CONTEXT * 4 ))
BRIEFING_REQUIRED="YES"
[[ $SCORE -lt 10 ]] && BRIEFING_REQUIRED="NO (score <10)"

DATE=$(date +%Y-%m-%d)

# Build file map table
FILE_MAP=""
if [[ -n "$FILES" ]]; then
  for f in $FILES; do
    FILE_MAP+="| $f | | |\n"
  done
fi

cat > "$RESULTS_DIR/briefing.md" << EOF
# Briefing: $PROJECT

**Project:** \`results/$PROJECT/\`  
**Created by:** Orchestrator (via generate-subagent-briefing.sh)  
**Date:** $DATE  
**Score:** $SCORE (files×3=$(( FILE_COUNT * 3)) + lines×1=$LINES + xrefs×5=$(( XREFS * 5 )) + context×4=$(( CONTEXT * 4 )))  
**Briefing required:** $BRIEFING_REQUIRED

---

## 1. Intent

**What problem are we solving?**  
_\(Orchestrator: fill this — be specific, not "fix scripts" but the actual issue\)_

**Why does this matter?**  
_\(Orchestrator: fill this — what breaks without this?\)_

---

## 2. Success Criteria

- [ ] **\(Deliverable 1\)** — _defined, measurable_
- [ ] **\(Deliverable 2\)** — _defined, measurable_

**Success test:** _\(Orchestrator: how will you know this is done and correct?\)_

---

## 3. Scope Boundaries

**In scope (do these):**
- [ ] _\(Orchestrator: list\)_
- [ ] _\(Orchestrator: list\)_

**Out of scope (do NOT do these):**
- [ ] _\(Orchestrator: list\)_
- [ ] _\(Orchestrator: list\)_

---

## 4. File Map & Dependencies

**Files to touch:**
| File | Role in this task | Cross-refs to |
|------|-------------------|---------------|
$FILE_MAP| _(orchestrator fills)_ | _(orchestrator fills)_ |

**Existing known-good state:**  
_\(Orchestrator: list files that must not be broken\)_

**Dependencies:**  
_\(Orchestrator: list scripts/libs this task depends on\)_

---

## 5. Key Decisions (Frozen)

**Already decided (do not revisit):**
- [ ] _\(Decision 1\)_ — reason: _\(why this choice\)_
- [ ] _\(Decision 2\)_ — reason: _\(why this choice\)_

**Open questions for subagent:**  
_\(Orchestrator: list only genuinely ambiguous items\)_

---

## 6. Orchestrator Self-Certification

Before spawning, answer all three:

- [ ] **Does briefing include explicit success criteria?** (Section 2)
- [ ] **Are scope boundaries explicitly defined (in/out)?** (Section 3)
- [ ] **Are file dependencies and cross-references mapped?** (Section 4)

**If any answer is "no" — briefing is incomplete. Fill in the gap before spawning.**

---

## 7. Handoff Instructions

**Spawn command:** \`delegate-with-checkpoint.sh --project $PROJECT --task "<task>"\`

**Subagent task prompt:**
\`\`\`
Read briefing.md first. Then execute.

Task: $TASK
Output: results/$PROJECT/
Success criteria: (from Section 2)
\`\`\`

---

## 8. Post-Spawn Checklist

- [ ] Briefing self-certified (Section 6 — all 3 "yes")
- [ ] Checkpoint initialized: \`timeout-recovery.sh --project $PROJECT --init\`
- [ ] Progress file exists: \`results/$PROJECT/progress.md\`
- [ ] Subagent spawned
- [ ] Monitor timeout per DELEGATION_CORE.md
EOF

echo "Briefing scaffold written to: $RESULTS_DIR/briefing.md"
echo "Score: $SCORE | Briefing required: $BRIEFING_REQUIRED"
echo "Orchestrator: fill in italic sections before spawning."
