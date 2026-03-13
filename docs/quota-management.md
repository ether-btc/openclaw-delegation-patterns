# Quota Management

Token budgeting and model selection for cost-effective delegation.

## Purpose

Optimize delegation costs while maintaining quality through intelligent model selection.

## Token Budget Guidelines

### Per-Task Budget

| Model | Recommended | Maximum |
|-------|-------------|---------|
| minimax-m2.5:free | 2,000 tokens | 4,000 tokens |
| qwen3-coder | 8,000 tokens | 15,000 tokens |
| kimik2thinking | 6,000 tokens | 12,000 tokens |
| deepseek-reasoner | 8,000 tokens | 15,000 tokens |
| glm-4.7 | 4,000 tokens | 8,000 tokens |
| gpt-5.2 | 10,000 tokens | 20,000 tokens |

### Cost Tiers

| Tier | Models | Cost/1K Tokens |
|------|--------|-----------------|
| Free | minimax-m2.5:free | $0.00 |
| Budget | glm-4.7, kimik2thinking | $0.001-0.003 |
| Standard | qwen3-coder | $0.002-0.005 |
| Premium | deepseek-reasoner, gpt-5.2 | $0.01+ |

---

## Model Selection Matrix

### By Task Complexity

| Complexity | Model | Budget |
|------------|-------|--------|
| Trivial (<10 lines) | minimax-m2.5:free | 500 tokens |
| Simple (10-50 lines) | glm-4.7 | 2,000 tokens |
| Moderate (50-200 lines) | qwen3-coder | 5,000 tokens |
| Complex (200-500 lines) | qwen3-coder + kimik2thinking | 10,000 tokens |
| Very Complex (>500 lines) | deepseek-reasoner + qwen3-coder | 15,000 tokens |

### By Domain

| Domain | Primary Model | Fallback |
|--------|---------------|----------|
| Code generation | qwen3-coder | glm-4.7 |
| Code review | kimik2thinking | qwen3-coder |
| Debugging | kimik2thinking | deepseek-reasoner |
| Research | deepseek-reasoner | qwen3-coder |
| Summaries | minimax-m2.5:free | glm-4.7 |
| High-stakes | gpt-5.2 | qwen3-coder |

---

## Routing Rules

Use these decision rules for automatic selection:

```
IF task == "quick summary" → minimax-m2.5:free
IF task == "write code" AND size < 100 lines → glm-4.7
IF task == "write code" AND size >= 100 lines → qwen3-coder
IF task == "debug" → kimik2thinking
IF task == "complex reasoning" → deepseek-reasoner
IF task == "critical" → gpt-5.2
```

---

## Optimization Strategies

### 1. Task Decomposition
- Break large tasks into atomic sub-tasks
- Use smaller models for subtasks
- Combine results with main agent

### 2. Context Optimization
- Pass only relevant context
- Use references not full content
- Summarize before delegating

### 3. Caching
- Reuse outputs from similar tasks
- Store common prompts
- Avoid duplicate work

### 4. Parallel Execution
- Split independent tasks
- Run simultaneously
- Merge results

---

## Monitoring

Track delegation costs:

```bash
# Check recent usage
openclaw status

# View token usage per session
ls ~/.openclaw/agents/main/sessions/*.jsonl | tail -5
```

---

## Budget Alerts

| Threshold | Action |
|-----------|--------|
| 80% of budget | Warning - log for review |
| 100% of budget | Block - require human approval |
| Over budget | Log all costs, report to human |

---

## Related Documents

- [delegation-enforcement.md](delegation-enforcement.md) - Model selection
- [failsafe-testing.md](failsafe-testing.md) - Error handling
- [delegation-fundamentals.md](delegation-fundamentals.md) - Core concepts
