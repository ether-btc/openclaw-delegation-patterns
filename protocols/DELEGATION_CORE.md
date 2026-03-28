# DELEGATION_CORE — Lean Delegation Rules

**What this is:** The one-stop reference for timeout guidelines, error handling, rollback, and chunking rules.
**Where it lives:** `memory/protocols/DELEGATION_CORE.md`
**Source:** Consolidated from `delegation-failsafe.md`, `autonomous-project-management-pattern.md`

---

## Timeout Guidelines

| Task Type | Default | Max |
|-----------|---------|-----|
| Quick (single tool call) | 30s | 60s |
| Fact lookup / simple read | 60s | 120s |
| Code (<50 lines) | 60s | 120s |
| Code (50-200 lines) | 180s | 300s |
| **Script build + test cycle** | **300s** | **480s** |
| Code (>200 lines) → SPLIT | — | — |
| Analysis / research | 180s | 300s |
| Multi-phase project | Per phase | Per phase |

**Rule:** If a task can be split, split it. Don't give one subagent more than 480s of work.

**Script-build task rule:** A script-build task (write + test + fix cycles) is NOT the same as pure code generation. It involves iterations. Default: 300s. Only use 480s if the task explicitly includes test-fix-debug cycles.

**Mid-task checkpoint rule:** Any subagent running >180s must write its current state to the progress file before the timeout. If a subagent times out mid-task, the progress file should contain enough to continue from where it stopped.

---

## Chunking Rules

**Trigger — split if task involves:**
- Reading or writing >5 files
- Analyzing >500 lines of code
- Producing >3 distinct output sections
- Multiple phases with different focus areas

**How to split:**
- Each chunk = one subagent task
- Each chunk = one progress file
- Orchestrator tracks parent progress
- Chunks can run parallel if independent

---

## Error Classification

### Category A: Recoverable → Retry
- Timeout → retry with higher timeout (see escalation table below)
- Rate limit → backoff 60s, retry
- Partial success → complete manually, keep good parts

**Timeout escalation table:**
| If this happens | Do this |
|-----------------|---------|
| First timeout on a new task | Retry at 2x original timeout |
| Second timeout on same task | Orchestrator takes over — write/test/fix directly |
| Timeout during test-fix cycle | Orchestrator reads partial output from progress file, completes the cycle |
| Timeout on a subagent that was writing a file | Check if file exists → if yes, test it; if no, rewrite |

**Rule of thumb:** If a subagent times out twice on the same task, stop delegating it — complete it yourself. Repeated timeouts mean the task is too complex for the subagent's context window or the task definition needs simplification.

### Category B: Non-Recoverable → Rollback
- Code broken → `git checkout`
- Context overflow → reduce scope, restart smaller
- Model unavailable → use fallback model
- Permission denied → fix, restore original

### Category C: Fatal → Alert Human
- Data loss
- Security breach
- Infinite loop (kill subagent, discard state)

---

## Rollback Protocol

### Before any subagent run:
- `git stash` if uncommitted work exists
- Document known good state
- Set rollback point

### After subagent run:
- Verify output quality
- Run tests if applicable
- Check for regressions

### Rollback triggers:
- Tests fail
- Code doesn't compile
- Output below quality threshold
- Human rejects

---

## Git Safety

**Before git operations:**
- Verify repo exists and remote URL is valid
- Check working directory is clean (or stash)
- Verify sufficient disk space

**Max failures before abort:** 3 consecutive failures → abort and report

---

## Fallback Models

**Rule: Only use models from `openclaw models list`. All fallback models must be confirmed available.**

| Primary | Fallback |
|---------|----------|
| qwen3-coder | minimax/MiniMax-M2.7 |
| kimik2thinking | deepseek32 |
| deepseek32 | kimik2thinking |
| Any unavailable | qwen3-coder |

**Available models on this system (from `openclaw models list`):**
- `nvidia/moonshotai/kimi-k2.5` (kimik25)
- `zai/glm-4.7` (GLM) — currently exhausted until ~2026-03-27 04:10
- `nvidia/moonshotai/kimi-k2-thinking` (kimik2thinking)
- `nvidia/qwen/qwen3.5-397b-a17b` (qwen35)
- `nvidia/qwen/qwen3-coder-480b-a35b-instruct` (qwen3-coder)
- `nvidia/deepseek-ai/deepseek-v3.2` (deepseek32)
- `google/gemini-2.5-flash-lite`
- `minimax/MiniMax-M2.7-highspeed`
- `minimax/MiniMax-M2.7`

---

## Key Rules for Orchestrator

1. **Orchestrator writes.** Subagent produces → I write files. Never expect subagent to write to disk.
2. **Template first.** Check PROJECT_REGISTRY → match task type → select template before spawning.
3. **Progress file before spawn.** Always create progress file before `sessions_spawn`.
4. **Chunk big tasks.** If >5 files or >500 lines, split into atomic sub-tasks.
5. **Post-delegation verification is mandatory.** See ORCHESTRATOR_VERIFY.md after every subagent completion.
