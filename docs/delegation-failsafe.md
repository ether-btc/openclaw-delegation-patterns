# Delegation Failsafe

## Purpose
Error classification and rollback criteria for subagent delegation.

## Atomic Task Definition

An atomic task is:
- Self-contained (no external dependencies)
- Reversible (can rollback)
- Bounded (clear start/end)
- Timeout-defined (max runtime specified)

## Error Classification

### Category A: Recoverable Errors

| Error Type | Action | Rollback |
|------------|--------|----------|
| Timeout | Retry with higher timeout | None needed |
| Rate limit | Backoff, retry | None needed |
| Partial success | Complete manually | Keep successful parts |

### Category B: Non-Recoverable Errors

| Error Type | Action | Rollback |
|------------|--------|----------|
| Code broken | Revert changes | git checkout |
| Context overflow | Reduce scope | Restart smaller |
| Model unavailable | Fall to backup | Use fallback |
| Permission denied | Fix permissions | Restore |

### Category C: Fatal Errors

| Error Type | Action | Rollback |
|------------|--------|----------|
| Data loss | Alert human | Full restore |
| Security breach | Disable | Isolate |
| Infinite loop | Kill | Discard |

## Rollback Criteria

### Before Subagent Run

- [ ] Backup current state
- [ ] Document known good state
- [ ] Set rollback point

### After Subagent Run

- [ ] Verify output quality
- [ ] Run tests
- [ ] Check for regressions

## Fallback Models

Have backup models ready:

| Primary | Fallback |
|---------|----------|
| Premium model | Standard model |
| Reasoning model | Fast model |
| Complex model | Simple model |

## Checkpoint Protocol

Before delegation:
```bash
# Create checkpoint
git stash
```

After failure:
```bash
# Restore
git stash pop
```

---

*Part of AI Agent Project Tracker*
