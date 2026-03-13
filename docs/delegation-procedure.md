# Delegation Procedure

## Purpose
Standard procedure for invoking subagents using Charon's delegation matrix.

## Pre-Delegation Checklist

Before spawning any subagent, verify:

- [ ] Task fits one of the 6 delegation roles
- [ ] Correct model selected from delegation matrix
- [ ] Progress file exists at `memory/projects/<name>/progress.md`
- [ ] Task is atomic (single, well-defined objective)
- [ ] Success criteria defined
- [ ] Timeout appropriate for task complexity
- [ ] Context bounds defined (max tokens if applicable)
- [ ] Git operations use safe patterns (see delegation-failsafe.md)

## Atomic Task Design

### What Makes a Task Atomic?
- Single objective
- Independent of other tasks
- Complete within one subagent run
- Clear success/failure criteria

### Task Size Guidelines

| Task Size | Example | Model |
|-----------|---------|-------|
| Micro (<50 tokens) | Summarize 1 file | minimax-m2.5:free |
| Small (<200 tokens) | Fix 1 bug | qwen3-coder |
| Medium (<500 tokens) | Refactor 1 module | qwen3-coder |
| Large (<1000 tokens) | Implement feature | qwen3-coder + kimik2thinking |
| Complex (>1000 tokens) | Design system | deepseek-reasoner + qwen3-coder |

## Git Operation Guidelines

### Git Operation Timeouts

To prevent hanging operations and context bloat, enforce strict timeouts:

| Operation | Recommended Timeout | Max Timeout |
|-----------|---------------------|-------------|
| git clone | 60s                 | 120s        |
| git fetch | 30s                 | 60s         |
| git pull  | 30s                 | 60s         |
| git push  | 60s                 | 120s        |
| git checkout | 15s              | 30s         |
| git status | 5s                 | 15s         |

Usage in subagents:
```bash
# Example with timeout enforcement
timeout 60s git clone https://github.com/user/repo.git || {
    echo "Operation timed out or failed"
    exit 1
}
```

### Context Budget Warnings

Git operations can consume significant context through:
- Command output (especially on large repositories)
- Error messages and stack traces
- Retry attempts multiplying context usage

Best practices:
- Redirect verbose output: `git clone --quiet`
- Limit log output: `git log --oneline -10`
- Use grep to filter relevant information
- Truncate large outputs before including in context

For operations expected to generate large outputs:
```bash
# Capture only essential information
git log --oneline -5 > recent_commits.txt
git status --porcelain > status_summary.txt
```

## Invocation Template

```
sessions_spawn with:
  model: <from delegation matrix>
  runtime: subagent
  task: <atomic task description>
  progress_file: memory/projects/<project>/progress.md
  timeout: <appropriate for task size>
```

### Example

```bash
sessions_spawn(
  model="nvidia/qwen/qwen3-coder-480b-a35b-instruct",
  runtime="subagent",
  task="Fix the login bug in auth.js. See memory/projects/auth-fix/prompt.md",
  label="auth-fix",
  mode="run",
  timeoutSeconds=300
)
```

## Verification

### Post-Delegation Check

1. Check progress file: `cat memory/projects/<name>/progress.md`
2. Verify completion status: COMPLETE / FAILED / TIMEOUT
3. Review output quality
4. If failed: classify error (see delegation-failsafe.md)

### Quality Gates

- [ ] Progress file updated
- [ ] Output meets success criteria
- [ ] No TODOs left in code
- [ ] Tests pass (if applicable)

### Verification Reminder System

After a subagent completes a task, use the verification reminder system to track what needs verification:

```bash
# Run verification check
./scripts/verify-completion-reminder.sh

# Or with specific workspace
WORKSPACE=/home/pi/.openclaw/workspace ./scripts/verify-completion-reminder.sh
```

**What it checks:**
1. Tasks marked as "just completed" or with COMPLETE status
2. Missing "Verification Required" sections in progress.md
3. Incomplete verification checkboxes

**When to run:**
- During heartbeats
- Before starting new delegation tasks
- Daily/weekly via cron

**Cron example** (every morning at 9 AM):
```bash
0 9 * * * cd /home/pi/.openclaw/workspace && ./scripts/verify-completion-reminder.sh >> /var/log/verification-reminders.log 2>&1
```

**Progress file template:**
Copy `memory/projects/TEMPLATE-progress.md` when creating new projects. It includes the verification section by default.

---

*Reference: delegation-best-practices-research.md*
*Part of: PROJECT-DELEGATION-BEST-PRACTICES-001*
