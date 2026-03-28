# Subagent Compaction Audit Prompt
**Use before every subagent spawn.**  
**If any check fails → orchestrator does the work directly.**

---

## Pre-Delegation Audit (run before `sessions_spawn`)

Answer these 7 questions. If ANY answer is RED → do NOT spawn subagent.

### Q1: Is there a dispatch file?
- [ ] YES: dispatch file exists in `memory/projects/<project>/`
- [ ] NO: **STOP** — create dispatch file first

### Q2: Was pre-delegation-checklist.sh run?
- [ ] YES: script output shows all 13 checks passed
- [ ] NO: **STOP** — run `bash scripts/pre-delegation-checklist.sh <project> <task> <output>`

### Q3: Is there a checkpoint JSON?
- [ ] YES: `memory/projects/<project>/checkpoint.json` exists and has `files_created: []`
- [ ] NO: **STOP** — create via `bash scripts/create-checkpoint.sh --project <name> --task "<desc>"`

### Q4: Does the task fit the subagent compactness criterion?
Count expected tool calls:
- File writes (edit/write): max **3** for a subagent
- File reads: max **5** (read once, not repeatedly)
- Exec calls: max **5**
- Total expected tool calls: max **15**

If any exceeds → **chunk the task** or do it directly.

### Q5: Will the subagent write workspace files directly?
- [ ] NO (good): task says "write to results/ only, I will copy to workspace"
- [ ] YES (bad): **STOP** — rewrite task to use result sink pattern

### Q5b: Is the task prompt under 1,500 tokens?
- [ ] YES: proceed
- [ ] NO: trim the task — remove redundant context, examples, boilerplate

### Q6: Is timeout-recovery.sh wired?
- [ ] YES: delegation will use `bash scripts/delegate-with-checkpoint.sh`
- [ ] NO: **STOP** — use the checkpoint wrapper

### Q7: Parent session health
- [ ] Parent context tokens < 80% of limit (or reserveTokens < 30%)
- [ ] Parent has no active subagents already running

If parent is >80% full → **compact parent first**, then spawn.

---

## Post-Spawn Monitoring (while subagent runs)

Every 60 seconds, check:
```
# Is subagent still alive?
bash scripts/monitor-subagent.sh --session-id <id> --check-alive

# How fast is context growing?
# Look at last session_history entry for contextTokens
# If growth > 500 tokens/min → checkpoint immediately
```

### Compaction Warning Signs
- More than 20 tool calls in first 3 minutes
- Exec tool calls returning ANSI-heavy output (color codes indicate large output)
- Subagent starts doing "retry" patterns (read → fail → read → succeed)
- contextTokens growing faster than 300 tok/min

### If Warning Signs Appear
1. Send checkpoint signal to subagent (if it supports checkpointing)
2. Kill subagent immediately — don't let it accumulate more context
3. Recover what exists in checkpoint.json
4. Orchestrator completes the remaining work directly

---

## Orchestrator "Don't Write Files" Enforcement

### The Problem
Subagents ignore "do not write files" instruction when they feel like it.

### The Mechanical Solution

**Subagent task prompt must include:**
```
CONSTRAINT: You may NOT use the write or edit tools on any path under:
  ~/.openclaw/workspace/
Exception: You MAY write to:
  ~/.openclaw/workspace/results/<project>/

After completing your work:
1. Write ALL outputs to ~/.openclaw/workspace/results/<project>/output.json
2. Update checkpoint.json with files_created + phase_complete: true
3. Do NOT deliver file contents in your response text
4. Simply say "COMPLETE" when done — I will read results/
```

**Orchestrator workflow:**
```
1. Spawn subagent with result-sink constraint
2. On subagent completion:
   a. Read results/<project>/output.json
   b. Copy/transform to actual workspace destination
   c. Verify files exist before declaring done
3. If subagent dies but checkpoint shows files_created:
   a. Verify files in results/
   b. Only re-do if files are missing or corrupt
```

---

## Compaction Recovery Protocol

If subagent dies unexpectedly:

```
1. IMMEDIATELY: Read checkpoint.json
2. If files_created.length > 0:
   a. Verify each file exists in results/
   b. If all exist → orchestrator copies to workspace, DONE
   c. If some missing → identify which phases completed, redo only missing
3. If checkpoint empty or missing:
   a. Try sessions_history on dead subagent
   b. If results found → extract and write
   c. If no results → orchestrator does work directly
4. NEVER assume subagent did nothing — always check first
```

---

## The Self-Audit Checklist (Print This)

```
BEFORE SPAWNING SUBAGENT:
□ Dispatch file exists
□ Pre-delegation checklist passed (all 13 checks)
□ Checkpoint JSON created
□ Task fits compactness criterion (≤15 tool calls)
□ Result-sink constraint in task prompt (no direct workspace writes)
□ Task prompt < 1,500 tokens
□ timeout-recovery.sh will be used
□ Parent context < 80% full
□ No other subagents running in parent

AFTER SPAWNING:
□ Monitor context growth every 60s
□ Watch for retry patterns
□ Kill at first compaction warning sign
□ On death: check checkpoint BEFORE assuming failure
```
