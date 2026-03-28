# DELEGATION-SURVIVAL.md — Post-Reset Subagent Recovery

**Purpose:** When you wake up after a session reset, detect and recover active subagent monitoring.

**Trigger:** On every session startup, step 5 of Session Startup calls `sessions_list`.

---

## When You Find Active Subagents

### Step 1: Inventory

Call `sessions_list(kinds=["subagent"])` and note:
- Session key
- Label (project association)
- Status (running, done, timeout)
- Last activity timestamp
- Child session of main (main session shows childSessions[])

### Step 2: Match to Project

For each active subagent:
1. Extract label (e.g., `correlation-plugin-source-search`)
2. Look for `memory/projects/*/` directories with matching name
3. Read `progress.md` if it exists
4. Check `checkpoint.json` for last recorded state

### Step 3: Assess State

**If subagent is DONE:**
- Extract final completion report from `sessions_history`
- Update `progress.md` to COMPLETED
- Verify deliverables per "Trust ≠ Verify" protocol
- Done — no recovery needed

**If subagent is RUNNING:**
- Check `sessions_history` for last message
- Look for: streaming glitch pattern, completion report, progress update, or stuck state
- **If glitching (e.g., "Let" loop):** Steer immediately with correction prompt
- **If no progress report:** Steer with progress request
- **If stuck for >5 minutes after steering:** Kill and restart

**If subagent is orphaned (no progress.md, no project directory):**
- Kill it — it was spawned without tracking infrastructure
- Log the gap in today's memory file
- Restart task properly if still needed

---

## Streaming Glitch Response

**Pattern:** Subagent outputs "Let" or single-word responses repeatedly, each followed by an exec command that varies slightly.

**This is a streaming truncation bug.** The model is producing full responses but they get cut off at "Let" due to output length limits.

**Immediate response:**
```
subagents steer {SESSION_KEY} << 'EOF'
### Streaming Glitch Detected

I see you're producing truncated responses (output cuts at "Let"). 

Please:
1. Stop the current command
2. Report what you were trying to do
3. Use a MORE SPECIFIC exec command — narrow down what you're searching for

Example fix: Instead of `find ~ -name "*.ts"`, use `find ~/.openclaw/extensions -name "*.ts" 2>/dev/null`

Continue working after reporting.
EOF
```

**If glitch persists after steering:** Kill subagent, restart with more constrained task.

---

## Recovery Checklist

When resuming after reset:

- [ ] Called `sessions_list` — active subagents identified
- [ ] Each active subagent matched to project directory
- [ ] `progress.md` exists → state recovered
- [ ] Subagent status assessed: DONE / RUNNING / GLITCHING / ORPHANED
- [ ] If RUNNING: `sessions_history` checked for last message
- [ ] If GLITCHING: steered or killed within 5 minutes
- [ ] If ORPHANED: killed, gap logged
- [ ] Checkpoint updated for all active subagents

---

## Example Recovery Flow

```
Session starts → sessions_list → finds "correlation-plugin-source-search" running
       ↓
progress.md exists at memory/projects/correlation-plugin-integration/progress.md
       ↓
sessions_history shows: last message = "Let" + find command (glitch pattern)
       ↓
Steer: "You're glitching. Stop. Report what you found."
       ↓
Subagent responds with completion report → Update progress.md to COMPLETED
       ↓
Verify: Read correlation-rules.json at expected path → exists → DONE
```

---

## Anti-Patterns (Don't Do These)

❌ **Don't ignore active subagents** — they consume resources and produce no output
❌ **Don't spawn new subagent for same task** — first recover, then decide
❌ **Don't wait >5 minutes** — if glitched, steer or kill promptly
❌ **Don't assume "running" = "making progress"** — check history
❌ **Don't skip progress.md update after recovery** — document the recovery itself

---

## Why This Exists

Session resets happen. They don't kill subagents. Without this protocol:
- Subagents run to timeout without monitoring
- Progress is lost
- Work is duplicated
- Glitch patterns go uncorrected

This protocol ensures continuity across resets.

---

*Protocol version: 1.0 | Created: 2026-03-24 | Root cause: RC-2, RC-3, RC-4*
