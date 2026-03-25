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

| Role | Model | Alias | Best For |
|------|-------|-------|----------|
| Coding | `nvidia/qwen/qwen3-coder-480b-a35b-instruct` | `qwen3-coder` | Implementation, refactoring |
| Deep reasoning | `nvidia/moonshotai/kimi-k2-thinking` | `kimik2thinking` | Analysis, debugging, planning |
| General reasoning | `nvidia/moonshotai/kimi-k2.5` | `kimik25` | Reasoning, analysis |
| Quick tasks | `minimax/MiniMax-M2.7` | `minimax` | Fast, lightweight tasks |
| Fast reasoning | `zai/glm-4.7` | `GLM` | Quick analysis (check if exhausted) |
| Heavy reasoning | `nvidia/deepseek-ai/deepseek-v3.2` | `deepseek32` | Chain-of-thought |
| Fast alt | `google/gemini-2.5-flash-lite` | — | Quick tasks, large context |

> **Important:** Always use `model:` parameter in sessions_spawn. Use aliases over full IDs.

## Result-Sink Convention (MANDATORY)

Every subagent MUST write results to a result sink file. This survives compaction and session death:

```bash
# At phase completion:
bash $WORKSPACE/scripts/subagent-result-sink.sh \
    --phase "research" \
    --status "complete" \
    --content "findings..."

# At final completion:
bash $WORKSPACE/scripts/subagent-result-sink.sh \
    --phase "final" \
    --status "final" \
    --content "final output..."
```

The orchestrator reads `results/sink.jsonl` after the subagent completes.

## Atomic Task Design

### What Makes a Task Atomic?

- **Single objective**: One clear goal
- **Independent**: No external dependencies
- **Bounded**: Clear start and end
- **Timeout-defined**: Maximum runtime specified

### Task Size Guidelines

| Size | Example | Model | Timeout |
|------|---------|-------|---------|
| Micro | Summarize 1 file | `qwen35` | 30s |
| Small | Fix 1 bug | `qwen3-coder` | 60s |
| Medium | Refactor 1 module | `qwen3-coder` | 180s |
| Large | Implement feature | `qwen3-coder` | 300s |
| Complex | Design system | `kimik2thinking` | 600s |

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

- [ ] Task fits one of the delegation roles
- [ ] Correct model selected from delegation matrix
- [ ] Progress file created for tracking
- [ ] Task is atomic (single, well-defined objective)
- [ ] Success criteria defined
- [ ] Timeout appropriate for task complexity
- [ ] Git operations use safe patterns

## Main Agent Responsibilities

1. **Spawn**: Create subagent with proper context
2. **Monitor**: Check progress file for updates
3. **Detect issues**: Identify stalled or failed tasks
4. **Receive results**: Collect output from subagent (via result sink)
5. **Verify**: Confirm output meets success criteria
6. **Cleanup**: Remove progress files when done

## Subagent Responsibilities

1. **Understand**: Read task description and context
2. **Track**: Update progress file every 2 minutes
3. **Sink results**: Write incremental results to `results/sink.jsonl`
4. **Execute**: Complete the assigned task
5. **Signal completion**: Mark final result with `--status "final"`

## Common Pitfalls

| Pitfall | Solution |
|---------|----------|
| Over-delegating | Keep simple tasks in-house |
| Under-delegating | Automate repetitive tasks |
| Vague tasks | Define atomic objectives |
| No tracking | Always use progress files + result sink |
| Missing success criteria | Define before delegating |

---

*See also: [Delegation Procedure](delegation-procedure.md), [Quota Management](quota-management.md)*
