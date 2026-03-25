# Subagent Handoff Protocol

File-based progress tracking and state machine for reliable subagent completion.

## Overview

This protocol enables structured progress reporting and reliable completion detection for subagents. It uses a simple file-based approach that works across different model implementations.

## Result-Sink Convention (MANDATORY)

**Every subagent must write results to a result sink file.** This survives compaction and session death:

```bash
bash $WORKSPACE/scripts/subagent-result-sink.sh \
    --phase "phase-name" \
    --status "complete" \
    --content "findings..."
```

Mark final output with `--status "final"`. The orchestrator reads the sink after completion.

**Progress vs Deliverables:** Subagents writing progress/checkpoint state is fine — this is state tracking, not file operations on behalf of the orchestrator. The prohibition is on subagents writing DELIVERABLES (final reports, code files, etc.) to disk. Those must be extracted by the orchestrator from the result sink.

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
4. Update completion status when done: state=complete, progress=100%
5. Write final output to designated location
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
Expected Output: [path/to/output.md]
Progress File: [path/to/progress.json]
```

### Subagent → Main Agent
```
Every 2 minutes: Update progress file
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

On completion:
```json
{
  "state": "complete",
  "progress": 100,
  "output_file": "path/to/output.md",
  "last_updated": "2026-03-13T10:30:00Z"
}
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
- If state=complete → Read output file

## Stalled Recovery

### Options
1. **Send reminder**: "Are you still working?"
2. **Restart subagent**: Resume from last progress
3. **Mark as failed**: Complete manually

## Testing

### Test Scenario: Simple File Read
```bash
# Create progress tracking
mkdir -p memory/projects/test/read-file
echo '{"task_id": "read-file", "state": "todo", "progress": 0}' > memory/projects/test/read-file/progress.json

# Spawn subagent
# Task: Read example.txt and summarize
# Progress file: memory/projects/test/read-file/progress.json

# Monitor progress
while true; do
  cat memory/projects/test/read-file/progress.json
  sleep 10
done
```

## Integration

This protocol integrates with:
- OpenClaw `sessions_spawn` mechanism
- Delegation matrix in AGENTS.md
- Project progress tracking
- Failsafe testing framework

## Notes

- Lightweight progress tracking (no complex handoff requests)
- Subagents manage their own progress
- Main agent monitors and detects issues
- Compatible with OpenClaw architecture

---

*See also: [Orchestrator Pattern](orchestrator-pattern.md), [Failsafe Testing](failsafe-testing.md)*
