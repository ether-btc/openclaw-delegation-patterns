# HANDOFF_PROTOCOL — Progress Tracking & Recovery

**What this is:** How to track subagent progress and recover from failures.
**Where it lives:** `memory/protocols/HANDOFF_PROTOCOL.md`
**Source:** Simplified from `subagent-handoff-protocol.md` (archive)

---

## Progress File Schema

Location: `memory/projects/{project}/{task}-progress.md`

```markdown
# Task: {task-name}

## Status
- State: TODO | RUNNING | COMPLETED | FAILED | CHECKPOINTED
- Updated: {ISO8601 timestamp}

## Progress
- Phase: "{current phase}"
- Completed: {n} / {total}
- Percent: {0-100}%

## Last Activity
- Time: {ISO8601}
- Step: "{what just happened}"
- Details: "{brief description}"

## Files Created
- {list as you create them}

## Files Modified
- {list as you modify them}
```

---

## State Machine

```
TODO → RUNNING → COMPLETED
         ↓
    CHECKPOINTED
         ↓
      FAILED
```

---

## Orchestrator Steps

### Before Spawning
1. Create project dir: `mkdir -p memory/projects/{project}/`
2. Create progress file with state=TODO
3. Select template (PROJECT_REGISTRY)
4. Spawn subagent

### While Running
- Check progress file every 5 min
- **Stalled detection:** No update in 10 min → recovery flow
- Don't expect subagent to write files

### On Completion
1. Read session history for subagent output
2. Write output files (orchestrator's job)
3. Update progress: state=COMPLETED, percent=100%
4. Call `scripts/memory-reinforce-hook.sh` to reinforce accessed memories
5. Report to user

---

## Stalled Recovery

If no progress update >10 min:

1. **Steer subagent** — send check-in message
2. **If no response** — kill and restart from last checkpoint
3. **If repeated stalls** — split remaining work into smaller chunks

---

## Key Principle

**Subagent produces. Orchestrator writes.**

The subagent's job is to do work and report results. My job is to capture those results and write them to disk. I don't wait for a subagent to write a file — I extract the content from session history and write it myself.
