# Subagent Handoff Protocol

File-based progress tracking and state machine for reliable subagent completion.

## Overview

This protocol enables structured progress reporting and reliable completion detection for subagents. It uses a simple file-based approach that works across different model implementations.

## How It Works

### For Main Agent
1. Spawn subagent with task description
2. Monitor progress file for updates
3. Check completion status in progress file
4. Detect stalled subagents (>10 min without progress)
5. Receive final results on completion

### For Subagent
1. Read task and understand requirements
2. Initialize progress file with: state=todo, progress=0%
3. Update progress every 2 minutes with: state=in-progress, progress=X%
4. Update checkpoint on phase completion: state=in-progress, progress=X%, current_phase="..."
5. Append final results to result sink (`results/sink.jsonl`) — do NOT write final output files directly
6. Update progress file to final state on exit

## Progress File Schema

Every task gets its own progress file: `memory/projects/[project-name]/[task-name]-progress.json`

```json
{
  "task_id": "example-task",
  "state": "todo|in-progress|paused|complete|failed",
  "progress": 0-100,
  "last_updated": "ISO-8601 timestamp",
  "current_phase": "Phase name",
  "output_file": "path/to/output.md",
  "error": "error message if any"
}
```

## State Machine

```
todo → in-progress → paused → complete
        ↓         ↓
    checkpoint   checkpoint
        ↓
    failed (error: "message")
```

## Communication Protocol

### Main Agent → Subagent
```
Task: [description]
Result Sink: [path/to/results/sink.jsonl]
Progress File: [path/to/progress.json]
```

### Subagent → Main Agent
```
Every 2 minutes: Update progress file
On phase complete: Append to result sink
On final: Mark progress complete + append "FINAL:" entry to result sink
```

Progress update example:
```json
{
  "state": "in-progress",
  "progress": 50,
  "current_phase": "Implementing feature",
  "last_updated": "2026-03-13T10:00:00Z"
}
```

Result sink append (per phase):
```json
{"phase": "research", "status": "complete", "content": "...", "written_at": "2026-03-13T10:00:00Z"}
```

On final completion:
```json
{"phase": "final", "status": "final", "content": "...final output...", "written_at": "2026-03-13T10:30:00Z"}
```

## Implementation

### Step 1: Create Project Structure
```bash
mkdir -p memory/projects/[project]/[task]/
touch memory/projects/[project]/[task]-progress.json
```

### Step 2: Initialize Progress File
```json
{
  "task_id": "example-task",
  "state": "todo",
  "progress": 0,
  "last_updated": null,
  "current_phase": null,
  "output_file": null,
  "error": null
}
```

### Step 3: Spawn Subagent
Provide the subagent with:
- Task description
- Progress file path
- Expected output location

### Step 4: Monitor Progress
Check progress file every 2-3 minutes for:
- State changes (todo → in-progress → complete)
- Progress updates (25%, 50%, 75%, 100%)
- Stalled detection (>10 min no update)

### Step 5: Detect Stalled

If state=in-progress and >10 min no update:
```
State: stalled
Last updated: [timestamp]
Action: Send reminder or restart subagent
```

## Error Handling

### Subagent Errors
If subagent encounters error:
```json
{
  "state": "failed",
  "progress": 50,
  "error": "error message",
  "last_updated": "2026-03-13T10:30:00Z"
}
```

### Main Agent Detection
Check progress file:
- If state=failed → Error recovery flow
- If state=stalled → Stalled recovery flow
- If state=complete → Read result sink (`results/sink.jsonl`) for final output; orchestrator owns what gets committed

## Stalled Recovery

### Options
1. **Send reminder**: "Are you still working?"
2. **Restart subagent**: Resume from last progress
3. **Mark as failed**: Complete manually

## Testing

### Test Scenario: Simple File Read
```bash
# Create project structure
mkdir -p memory/projects/test/read-file/results
echo '{"task_id": "read-file", "state": "todo", "progress": 0}' > memory/projects/test/read-file/progress.json
touch memory/projects/test/read-file/results/sink.jsonl

# Spawn subagent
# Task: Read example.txt and summarize
# Progress file: memory/projects/test/read-file/progress.json
# Result sink: memory/projects/test/read-file/results/sink.jsonl

# Monitor progress
while true; do
  cat memory/projects/test/read-file/progress.json
  sleep 10
done

# On completion, read result sink:
cat memory/projects/test/read-file/results/sink.jsonl
```

## Integration

This protocol integrates with:
- OpenClaw `sessions_spawn` mechanism
- Delegation matrix in AGENTS.md
- Project progress tracking
- Failsafe testing framework

## Result Sink Pattern

The result sink is the authoritative output log. Subagent appends structured JSONL entries; orchestrator reads on completion.

```bash
# Subagent writes:
bash $WORKSPACE/scripts/subagent-result-sink.sh \
    --phase "research" \
    --status "complete" \
    --content "findings..."

# Orchestrator reads:
cat memory/projects/[project]/results/sink.jsonl
```

**Key rules:**
- Subagent writes sink, orchestrator reads and merges — never reverse
- Progress file is for state; result sink is for output
- Orchestrator is sole authority on what gets committed to memory

## Notes

- Lightweight progress tracking (no complex handoff requests)
- Subagents manage checkpoint state; orchestrator owns deliverables
- Main agent monitors and detects issues
- Compatible with OpenClaw architecture

---

*See also: [Orchestrator Pattern](orchestrator-pattern.md), [Failsafe Testing](failsafe-testing.md)*
