# Delegation Fundamentals

Core concepts for effective delegation in OpenClaw.

## When to Delegate

### Criteria for Delegation

| Criteria | Action |
|----------|--------|
| Task takes >2-3 minutes | ✅ Spawn subagent |
| Task is parallelizable | ✅ Spawn multiple |
| Task requires different expertise | ✅ Delegate to specialist |
| Task <30 seconds | ❌ Inline processing |
| Context continuity critical | ❌ Inline processing |

### Delegation Benefits

1. **Parallelism**: Multiple subagents can work simultaneously
2. **Specialization**: Match task to best-suited model
3. **Focus**: Main agent handles coordination, subagents handle execution
4. **Reliability**: Progress tracking enables reliable completion detection

## Delegation Matrix

| Role | Model | Invocation | Best For |
|------|-------|------------|----------|
| Coding | qwen3-coder | `agentId: qwen3-coder` | Implementation, refactoring |
| Reasoning | kimik2thinking | `agentId: kimik2thinking` | Analysis, debugging |
| Fast | minimax-m2.5:free | `model: kilocode/minimax/minimax-m2.5:free` | Quick tasks |
| Fast Reasoning | glm-4.7 | `model: zai/glm-4.7` | Quick analysis |
| Heavy Reasoning | deepseek-reasoner | `agentId: deepseek-reasoner` | Chain-of-thought |
| Premium | gpt-5.2 | blockrun | Critical tasks |

## Atomic Task Design

### What Makes a Task Atomic?

- **Single objective**: One clear goal
- **Independent**: No external dependencies
- **Bounded**: Clear start and end
- **Timeout-defined**: Maximum runtime specified

### Task Size Guidelines

| Size | Example | Model | Timeout |
|------|---------|-------|---------|
| Micro | Summarize 1 file | minimax-m2.5:free | 30s |
| Small | Fix 1 bug | qwen3-coder | 60s |
| Medium | Refactor 1 module | qwen3-coder | 180s |
| Large | Implement feature | qwen3-coder | 300s |
| Complex | Design system | deepseek-reasoner | 600s |

### ❌ Bad Task Definitions

- "Fix the bugs in the auth system" (too vague, multiple bugs)
- "Improve performance" (undefined success criteria)
- "Write tests for everything" (no bounds)

### ✅ Good Task Definitions

- "Fix the null pointer exception in auth.js line 42"
- "Reduce API response time from 500ms to <200ms"
- "Add unit tests for User.authenticate() method"

## Pre-Delegation Checklist

Before spawning any subagent, verify:

- [ ] Task fits one of the 6 delegation roles
- [ ] Correct model selected from delegation matrix
- [ ] Progress file exists for tracking
- [ ] Task is atomic (single, well-defined objective)
- [ ] Success criteria defined
- [ ] Timeout appropriate for task complexity
- [ ] Git operations use safe patterns

## Context Transfer

When delegating, provide:
1. **Task description**: What needs to be done
2. **Expected output**: Where results go
3. **Success criteria**: How to measure completion
4. **Relevant context**: Files, links, prior work

## Main Agent Responsibilities

1. **Spawn**: Create subagent with proper context
2. **Monitor**: Check progress file for updates
3. **Detect issues**: Identify stalled or failed tasks
4. **Receive results**: Collect output from subagent
5. **Verify**: Confirm output meets success criteria
6. **Cleanup**: Remove progress files when done

## Subagent Responsibilities

1. **Understand**: Read task description and context
2. **Track**: Update progress file every 2 minutes
3. **Execute**: Complete the assigned task
4. **Report**: Write output to designated location
5. **Signal completion**: Update progress to complete

## Common Pitfalls

| Pitfall | Solution |
|---------|----------|
| Over-del | Keepegating simple tasks in-house |
| Under-delegating | Automate repetitive tasks |
| Vague tasks | Define atomic objectives |
| No tracking | Always use progress files |
| Missing success criteria | Define before delegating |

---

*See also: [Delegation Procedure](delegation-procedure.md), [Quota Management](quota-management.md)*
