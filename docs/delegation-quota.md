# Delegation Quota

## Purpose
Token budgeting and model selection for cost-effective delegation.

## Token Budget Guidelines

### Per-Task Budget

| Model Tier | Recommended | Maximum |
|-----------|------------|---------|
| Free | 2,000 tokens | 4,000 tokens |
| Budget | 4,000 tokens | 8,000 tokens |
| Standard | 8,000 tokens | 15,000 tokens |
| Premium | 10,000 tokens | 20,000 tokens |

### Cost Tiers

| Tier | Examples | Cost/1K tokens |
|------|----------|-----------------|
| Free | minimax-free, haiku | $0 |
| Budget | glm-4, flash models | $0.001-0.003 |
| Standard | sonnet, coder models | $0.002-0.005 |
| Premium | opus, reasoning models | $0.01+ |

## Model Selection Matrix

### By Task Complexity

| Complexity | Model Tier | Budget |
|------------|------------|--------|
| Trivial | Free | 500 tokens |
| Simple | Budget | 2,000 tokens |
| Moderate | Standard | 5,000 tokens |
| Complex | Premium | 10,000 tokens |
| Very Complex | Premium+ | 15,000 tokens |

### By Domain

| Domain | Primary Model | Fallback |
|--------|---------------|----------|
| Code generation | Standard coder | Budget |
| Code review | Standard | Budget |
| Debugging | Reasoning | Standard |
| Research | Reasoning | Standard |
| Summaries | Free | Budget |
| Critical | Premium | Standard |

## Optimization Strategies

### 1. Task Decomposition
- Break large tasks into atomic sub-tasks
- Use smaller models for subtasks
- Combine results

### 2. Context Optimization
- Pass only relevant context
- Use references not full content
- Summarize before delegating

### 3. Caching
- Reuse outputs from similar tasks
- Store common prompts

### 4. Routing Rules

```
IF task == "summary" → free
IF task == "write code" AND size < 100 lines → budget
IF task == "write code" AND size >= 100 lines → standard
IF task == "debug" → reasoning
IF task == "complex reasoning" → premium
```

## Monitoring

Track delegation:
- Log token usage per session
- Monitor costs
- Set budget alerts

## Budget Alerts

- Warning at 80% of budget
- Block at 100% (require approval)

---

*Part of AI Agent Project Tracker*
