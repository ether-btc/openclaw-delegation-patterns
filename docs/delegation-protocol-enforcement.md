# Delegation Protocol Enforcement Guide

## Purpose

Ensure all delegation follows consistent, reliable patterns that work across models.

## Golden Rule

**Orchestrator-Led Pattern ONLY**
- Subagents execute work
- Subagents report back to orchestrator
- Orchestrator updates files
- Clear separation: execution vs coordination

**NEVER:** Progress-file approach (subagents updating their own progress files)
- Different models behave differently
- Inconsistent results
- No single source of truth

---

## Delegation Matrix

| Task Type | Model | Pattern | Status |
|-------------|--------|---------|--------|
| Coding tasks | agentId: qwen3-coder | Orchestrator-led | ✅ Reliable |
| Reasoning tasks | agentId: kimik2thinking | Orchestrator-led | ⚠️ Mixed results |
| Quick/summary | model: kilocode/minimax/minimax-m2.5:free | Orchestrator-led | ✅ Reliable |
| Heavy reasoning | agentId: deepseek-reasoner | Orchestrator-led | — |
| Fast reasoning | model: zai/glm-4.7 | Orchestrator-led | ✅ Reliable |

---

## delegate-enforcer.sh Usage

**Recommended: Use before every spawn**

The `scripts/delegate-enforcer.sh` script automates model selection and validation:

### Basic Usage

```bash
./scripts/delegate-enforcer.sh "<task-description>" <model-type>
```

### Parameters

| Parameter | Description | Options |
|-----------|-------------|---------|
| task-description | Plain language description of work | Any text |
| model-type | Type of task | coding, reasoning, quick, fast-reasoning |

### Examples

```bash
# Coding task
./scripts/delegate-enforcer.sh "Implement login form validation" coding

# Reasoning task
./scripts/delegate-enforcer.sh "Debug authentication failure" reasoning

# Quick task
./scripts/delegate-enforcer.sh "Find all TODO comments" quick

# Fast reasoning
./scripts/delegate-enforcer.sh "Review security implications" fast-reasoning
```

### What It Does

1. **Validates** task is atomic (completable in one run)
2. **Selects** correct model from delegation matrix
3. **Applies** orchestrator-led prompt template
4. **Sets timeout** based on task complexity
5. **Tracks** subagent until completion
6. **Verifies** output files exist before trusting completion

### When to Use

**Recommended: Before every spawn**
- Ensures consistent delegation pattern
- Prevents wrong model selection
- Enforces orchestrator-led pattern
- Provides timeout management

### Post-Script Steps

After running delegate-enforcer.sh:
1. Verify output files exist
2. Update project progress file yourself
3. Summarize to user (<2000 chars)
4. Reference full details in progress.md

---

## Spawn Template (Mandatory)

**ALWAYS use this format:**

```markdown
## Task: [brief description]

## Your Role
You are working as a specialist assistant. I am your orchestrator/project lead.

## What To Do
1. Execute task assigned
2. Complete all required work
3. Report your findings back to me in clear format

## What NOT To Do
❌ Do NOT write to progress files yourself
❌ Do NOT update project tracking files
❌ Do NOT modify orchestration state
❌ Do NOT try to coordinate with other subagents

Your job is execution and reporting. MY job is tracking and coordination.

## Report Format
When complete, report back:

```markdown
## Task Complete

**Work Done:** [Brief description]

**Results:**
[Your findings, data, or outputs]

**Files Created/Modified:** [List any files you created or modified]

**Recommendations:** [Any suggestions or next steps]
```

---

## Enforcement Checklist

### Before Spawning
- [ ] Task is atomic (can complete in one run)
- [ ] Progress file NOT required (orchestrator-led)
- [ ] Output file path specified
- [ ] Deadline/timeout defined

### During Execution
- [ ] Subagent accepted
- [ ] No polling (wait for completion event)
- [ ] Tracking child session key

### After Completion
- [ ] Output file verified (if specified)
- [ ] Progress file updated by ME
- [ ] Results documented

---

## Model-Specific Notes

### qwen3-coder
- **Reliability:** ✅ High
- **Use for:** Coding, implementation, file operations
- **Avoid for:** Complex reasoning, ambiguous tasks

### kimik2thinking
- **Reliability:** ⚠️ Mixed
- **Use for:** Analysis, debugging, complex logic
- **Avoid for:** Simple tasks with strict output requirements

### minimax-m2.5:free
- **Reliability:** ✅ High
- **Use for:** Quick tasks, summaries, documentation review
- **Avoid for:** Complex coding, deep reasoning

### deepseek-reasoner
- **Reliability:** Unknown
- **Use for:** Heavy chain-of-thought tasks
- **Avoid for:** Quick tasks

### glm-4.7
- **Reliability:** ✅ High
- **Use for:** Fast reasoning, coordination
- **Avoid for:** Simple execution tasks

---

## Common Pitfalls

### ❌ DON'T DO
1. Don't include tool call examples in prompts (confuses subagents)
2. Don't ask subagents to "remember to update progress file" (they often don't)
3. Don't use progress-file approach for parallel work
4. Don't poll subagents (wait for completion events)
5. Don't use wrong format:
   - Wrong: `model: qwen3-coder`
   - Right: `agentId: qwen3-coder`

### ✅ DO
1. Use orchestrator-led pattern for all delegation
2. Verify model IDs before spawning
3. Let subagents report back, then update files yourself
4. Use completion events (push-based), not polling
5. Document all delegation in project files

---

## Escalation Protocol

If subagent fails:
1. Check error reason
2. Try with simpler task description
3. Try with different model (qwen3-coder preferred)
4. If 3 failures → execute task myself

---

*Last Updated: 2026-03-11*
*Enforcement Level: MANDATORY*
