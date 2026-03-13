# Failsafe Testing

Backup, verify, and rollback patterns for production changes via subagent delegation.

## Purpose

Ensure safe delegation practices with clear recovery paths when things go wrong.

## Error Classification

### Category A: Recoverable Errors

| Error Type | Action | Rollback Needed? |
|------------|--------|------------------|
| Timeout | Retry with higher timeout | No |
| Rate limit | Backoff 60s, retry | No |
| Partial success | Complete manually | Keep successful parts |

### Category B: Non-Recoverable Errors

| Error Type | Action | Rollback |
|------------|--------|----------|
| Code broken | Revert changes | `git checkout` |
| Context overflow | Reduce scope | Restart with smaller task |
| Model unavailable | Fall to backup model | Use fallback |
| Permission denied | Fix permissions | Restore original |

### Category C: Fatal Errors

| Error Type | Action | Rollback |
|------------|--------|----------|
| Data loss | Alert human | Full restore from backup |
| Security breach | Disable subagent | Isolate, audit |
| Infinite loop | Kill subagent | Discard state |

---

## Rollback Criteria

### Before Subagent Run

- [ ] Backup current state: `git stash`
- [ ] Document known good state
- [ ] Set rollback point
- [ ] Verify repository accessibility

### After Subagent Run

- [ ] Verify output quality
- [ ] Run tests if applicable
- [ ] Check for regressions

### Rollback Triggers

Rollback immediately if:
- [ ] Test failures > 0
- [ ] Code doesn't compile
- [ ] Output quality below threshold
- [ ] Human rejects output

---

## Fallback Models

If primary model fails, escalate to:

| Primary | Fallback |
|---------|----------|
| qwen3-coder | minimax-m2.5:free |
| kimik2thinking | deepseek-reasoner |
| deepseek-reasoner | kimik2thinking |
| gpt-5.2 | qwen3-coder |
| glm-4.7 | minimax-m2.5:free |

---

## Timeout Guidelines

| Task Type | Default | Maximum |
|-----------|---------|---------|
| Code (<50 lines) | 60s | 120s |
| Code (50-200 lines) | 180s | 300s |
| Code (>200 lines) | 300s | 600s |
| Analysis | 120s | 300s |
| Research | 180s | 300s |
| Quick task | 30s | 60s |

---

## Git Safety Protocol

### Pre-Flight Checks

Before any git operation:
1. Verify repository exists and is accessible
2. Check working directory is clean
3. Verify remote URL is valid
4. Ensure sufficient disk space

```bash
# Verify repository
gh repo view owner/repo >/dev/null 2>&1 || { echo "Repository not accessible"; exit 1; }

# Check working directory
if ! git diff-index --quiet HEAD --; then
    echo "Uncommitted changes - stash first"
    exit 1
fi
```

### Git Operation Timeouts

| Operation | Recommended | Maximum |
|-----------|-------------|---------|
| git clone | 60s | 120s |
| git fetch | 30s | 60s |
| git pull | 30s | 60s |
| git push | 60s | 120s |
| git checkout | 15s | 30s |
| git status | 5s | 15s |

### Max Failures Before Abort

- Maximum consecutive failures: 3
- After 3 failures: abort and report
- Log all failures with timestamp

---

## Checkpoint Protocol

### Before Delegation
```bash
./scripts/session-checkpoint.sh auto
```

### After Delegation (if failed)
```bash
./scripts/session-checkpoint.sh recover
git stash pop  # if needed
```

---

## Testing Pattern

For any production change:

1. **Backup** - Create checkpoint before changes
2. **Verify** - Confirm current state works
3. **Change** - Execute delegated task
4. **Verify** - Test output quality
5. **Rollback** - If verification fails

```bash
# Full failsafe workflow
./scripts/test-failsafe.sh <project> backup
./scripts/test-failsafe.sh <project> verify
# ... make changes ...
./scripts/test-failsafe.sh <project> verify
# If fail:
./scripts/test-failsafe.sh <project> rollback
```

---

## Related Documents

- [delegation-enforcement.md](delegation-enforcement.md) - Pre-delegation checks
- [delegation-fundamentals.md](delegation-fundamentals.md) - Core concepts
- [quota-management.md](quota-management.md) - Cost control
