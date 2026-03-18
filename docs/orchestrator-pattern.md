# Orchestrator Pattern

The core delegation pattern where the main agent handles file operations while subagents focus on reasoning and execution.

## Overview

The orchestrator pattern is the foundation of reliable delegation. It establishes a clear separation of concerns:

- **Orchestrator (Main Agent):** Handles coordination, file operations, progress tracking, and user communication
- **Subagent:** Executes tasks and reports findings without touching files directly

## Why Orchestrator-Led?

### Problems with Subagent-Direct Approach

- Different models handle file operations inconsistently
- No single source of truth for progress
- Race conditions in parallel operations
- Difficulty tracking overall status

### Benefits of Orchestrator-Led

- Consistent file management
- Reliable progress tracking
- Clean separation of concerns
- Easier debugging and recovery

---

## Pattern Implementation

### The Flow

```
┌─────────────┐     Spawn      ┌─────────────┐
│ Orchestrator │ ────────────→ │  Subagent   │
│  (Main Agent)│               │             │
└─────────────┘               └─────────────┘
      ↑                               │
      │ Report                        │ Execute
      │ Results                       │
      │                               ▼
      │                        ┌─────────────┐
      └────────────────────── │   Results   │
         Update Files         │   Report    │
                              └─────────────┘
```

### Step-by-Step

1. **Prepare** - Define task, select model, set timeout
2. **Spawn** - Launch subagent with clear instructions
3. **Wait** - Receive completion event (no polling)
4. **Verify** - Check output files exist
5. **Update** - Modify files yourself
6. **Report** - Summarize to user

---

## Key Principles

### 1. No Tool Syntax in Prompts

**❌ Wrong:**
```
Write code to implement login. Use the write tool to create auth.py.
```

**✅ Correct:**
```
Write the code for a login implementation. I'll create the file with your code.
```

### 2. No Progress File Updates by Subagent

Subagents report findings; orchestrator updates tracking.

**❌ Wrong:**
```
Remember to update progress.md when done.
```

**✅ Correct:**
```
Report your findings back to me. I'll handle the progress tracking.
```

### 3. Push-Based, Not Polling

Wait for completion events rather than polling.

**❌ Wrong:**
```
while still running: check status every 10 seconds
```

**✅ Correct:**
```
Wait for completion event, then process results
```

---

## Spawn Template

```markdown
## Task: [Brief Description]

## Your Role
You are working as a specialist assistant. I am your orchestrator/project lead.

## What To Do
1. Execute the assigned task
2. Complete all required work
3. Report your findings back to me in clear format

## What NOT To Do
- Do NOT write to progress files
- Do NOT update project tracking files
- Do NOT modify orchestration state
- Do NOT try to coordinate with other subagents

Your job is execution and reporting. MY job is tracking and coordination.

## Report Format
When complete, report:

**Work Done:** [Brief description]

**Results:** [Your findings, data, or outputs]

**Files Created/Modified:** [List files - orchestrator will create]

**Recommendations:** [Any suggestions or next steps]
```

---

## Verification Rule

**NEVER claim completion without verification.**

Before marking any task complete:
- [ ] Output files exist (verify with `read` or `ls`)
- [ ] Content is correct (spot check key sections)
- [ ] No placeholder content (TODOs, FIXME, etc.)

---

## Anti-Patterns

### ❌ Never Do

1. **Include tool examples in prompts** - Causes confusion
2. **Ask subagent to track progress** - They often forget
3. **Use progress-file for parallel work** - Race conditions
4. **Poll for status** - Resource waste, timing issues
5. **Trust completion claims blindly** - Always verify

### ✅ Always Do

1. Use orchestrator-led pattern exclusively
2. Verify model IDs before spawning
3. Let subagents report, then update files yourself
4. Use push-based completion events
5. Document all delegation

---

## Related Documents

- [delegation-enforcement.md](delegation-enforcement.md) - Validation
- [delegation-fundamentals.md](delegation-fundamentals.md) - Core concepts
- [subagent-handoff-protocol.md](subagent-handoff-protocol.md) - Handoff
- [templates/delegation-prompt.md](templates/delegation-prompt.md) - Spawn template

---

## Lessons from Production Use (2026-03-18)

### Memory System Fix Project

Today we successfully fixed a critical memory system issue using orchestrator-led delegation. Key observations:

#### What Worked

1. **Orchestrator-Led Pattern**
   - Main agent handled all file operations
   - Subagents focused on reasoning/generating output
   - Results written to progress files
   - Single source of truth maintained

2. **Atomic Task Design**
   - Each subagent had one clear objective
   - Progress files tracked state reliably
   - Timeout handling worked (when tasks took too long, we verified manually)

3. **Verification Discipline**
   - Never trust "complete" without verification
   - Check file existence, content
   - Test functionality after subagent returns

#### What We Learned

1. **Subagent Timeouts**
   - Some tasks timed out at 3 minutes
   - Progress file not always written
   - Manual verification needed

2. **Model Selection Matters**
   - `qwen3-coder` for implementation tasks
   - `kimik2thinking` for analysis
   - Different models behave differently with same prompts

3. **Verification is Mandatory**
   - Check output files exist
   - Test functionality independently
   - Trust but verify

#### Anti-Patterns to Avoid

| Anti-Pattern | Problem | Solution |
|--------------|--------|----------|
| Trust "complete" | Tasks reported done but no output | Always verify |
| No progress file | Lost track of task state | Require progress.md |
| Poll for completion | Wastes resources | Trust push-based completion |
| Skip timeout management | Tasks hang forever | Set appropriate timeouts |

#### Code Example: Orchestrator-Led

```javascript
// Main agent (orchestrator)
await sessions_spawn({
  task: "Fix memory search",
  timeoutSeconds: 180
});

// Wait for completion event
// Then verify:
const output = readFile(progressFile);
if (!output.includes("COMPLETE")) {
  // Redelegate or handle failure
}
```

#### Progress File Schema

```markdown
# Task: [Name]
## Status
- State: RUNNING | COMPLETED | FAILED
- Updated: ISO8601

## Progress
- Phase: "[phase]"
- Completed: N
- Total: M

## Last Activity
- Time: ISO8601
- Step: "[what was done]"
```

---

*Added: 2026-03-18 from PROJECT-MEMORY-SYSTEM-FIX*
