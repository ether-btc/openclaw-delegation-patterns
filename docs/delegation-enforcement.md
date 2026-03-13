# Delegation Enforcement

Ensuring consistent, reliable delegation patterns across all subagent operations.

## Golden Rule: Orchestrator-Led Pattern

The orchestrator-led pattern is the **only approved delegation approach**:

- **Subagents** execute work and report findings
- **Orchestrator** handles all file operations and coordination
- Clear separation: execution vs coordination

**NEVER use:** Progress-file approach (subagents updating their own progress files) — different models behave inconsistently, creating no single source of truth.

---

## Pre-Delegation Checklist

Before spawning any subagent, verify:

- [ ] Task is **atomic** (completable in one run)
- [ ] No external dependencies required
- [ ] Output file path is specified
- [ ] Timeout is defined based on task complexity
- [ ] Correct model selected from delegation matrix
- [ ] Orchestrator-led template will be used

---

## Atomic Task Validation

An atomic task must be:

| Property | Description |
|----------|-------------|
| **Self-contained** | No external dependencies |
| **Reversible** | Can rollback if needed |
| **Bounded** | Clear start and end points |
| **Timeout-defined** | Maximum runtime specified |

### Task Size Guidelines

| Size | Example | Timeout |
|------|---------|---------|
| Small | <50 lines of code | 60-120s |
| Medium | 50-200 lines | 180-300s |
| Large | >200 lines | 300-600s |

---

## Delegation Matrix

| Task Type | Model | Invocation | Reliability |
|-----------|-------|------------|-------------|
| Coding | qwen3-coder | `agentId: qwen3-coder` | ✅ High |
| Reasoning | kimik2thinking | `agentId: kimik2thinking` | ⚠️ Mixed |
| Quick/Summary | minimax-m2.5:free | `model: kilocode/minimax/minimax-m2.5:free` | ✅ High |
| Heavy Reasoning | deepseek-reasoner | `agentId: deepseek-reasoner` | — |
| Fast Reasoning | glm-4.7 | `model: zai/glm-4.7` | ✅ High |

---

## Model-Specific Notes

### qwen3-coder
- **Best for:** Coding, implementation, file operations
- **Avoid:** Complex reasoning, ambiguous tasks
- **Strength:** Reliable code generation

### kimik2thinking
- **Best for:** Analysis, debugging, complex logic
- **Avoid:** Simple tasks with strict output requirements
- **Note:** Results may vary; verify outputs

### minimax-m2.5:free
- **Best for:** Quick tasks, summaries, documentation review
- **Avoid:** Complex coding, deep reasoning
- **Strength:** Fast, free, reliable for simple tasks

### deepseek-reasoner
- **Best for:** Heavy chain-of-thought tasks
- **Avoid:** Quick tasks
- **Note:** Use for complex reasoning only

### glm-4.7
- **Best for:** Fast reasoning, coordination tasks
- **Avoid:** Simple execution tasks
- **Strength:** Quick turnaround

---

## Enforcement Checklist

### Before Spawning
- [ ] Task is atomic
- [ ] Progress file NOT required
- [ ] Output file path specified
- [ ] Deadline/timeout defined
- [ ] Model selected from matrix

### During Execution
- [ ] Subagent accepted task
- [ ] No polling (wait for completion)
- [ ] Tracking child session

### After Completion
- [ ] Output file verified
- [ ] Progress updated by orchestrator
- [ ] Results documented

---

## Common Violations

### ❌ Never Do
1. Include tool call examples in prompts (confuses subagents)
2. Ask subagents to update progress files
3. Use progress-file approach for parallel work
4. Poll subagents (use push-based completion)
5. Use wrong format: `model: qwen3-coder` (wrong) vs `agentId: qwen3-coder` (correct)

### ✅ Always Do
1. Use orchestrator-led pattern
2. Verify model IDs before spawning
3. Let subagents report back, then update files yourself
4. Use completion events, not polling
5. Document all delegation

---

## Escalation Protocol

If subagent fails:
1. Check error reason
2. Retry with simpler task description
3. Try different model (qwen3-coder preferred)
4. After 3 failures → execute task yourself

---

## Related Documents

- [delegation-fundamentals.md](delegation-fundamentals.md) - Core concepts
- [subagent-handoff-protocol.md](subagent-handoff-protocol.md) - Handoff procedure
- [failsafe-testing.md](failsafe-testing.md) - Error handling
- [quota-management.md](quota-management.md) - Cost optimization

---

*Enforcement Level: MANDATORY*
