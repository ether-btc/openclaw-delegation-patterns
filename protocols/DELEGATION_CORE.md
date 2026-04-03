# DELEGATION_CORE — Lean Delegation Rules

**What this is:** The one-stop reference for timeout guidelines, error handling, rollback, and chunking rules.
**Where it lives:** `memory/protocols/DELEGATION_CORE.md`
**Source:** Consolidated from `delegation-failsafe.md`, `autonomous-project-management-pattern.md`

---

## Timeout Guidelines

| Task Type | Default | Max | Model Guidance |
|-----------|---------|-----|----------------|
| Quick (single tool call) | 30s | 60s | Any fast model |
| Fact lookup / simple read | 60s | 120s | deepseek32, kimik25, minimax-hs |
| Code (<50 lines) | 60s | 120s | qwen3-coder |
| Code (50-200 lines) | 180s | 300s | qwen3-coder |
| **Script build + test cycle** | **300s** | **480s** | qwen3-coder |
| Code (>200 lines) → SPLIT | — | — | Use Minimax for large context |
| Analysis / research | 180s | 300s | kimik2thinking, qwen35 |
| Large context load | 300s | 480s | Minimax, GLM-5.1 |
| Multimodal analysis | 180s | 300s | gemini-flite |
| Fast burst (speed priority) | 60s | 120s | minimax-hs |
| Architecture / design | 300s | 480s | kimik2thinking |

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

## Pre-Handoff Briefing (Frozen Inference)

**Problem:** Subagents suffer a blank-slate tax — spawning with zero context, spending tokens on reconnaissance before useful work begins.

**Solution:** Orchestrator pre-digests context into a briefing doc. Subagent reads briefing → executes. No reconnaissance required.

**Complex task scoring matrix:**
| Factor | Formula | Notes |
|--------|---------|-------|
| File count | ×3 | Files touched by task |
| Line count | ×0.5 | Total lines across files |
| Cross-reference density | ×5 | Inter-file references (imports, calls, shared configs) |
| Context dependency | ×4 | Requires understanding state beyond the files themselves |

**Score = (files×3) + (lines×0.5) + (xrefs×5) + (context×4)**
- **≥10** = complex task → briefing **required**
- **<10** = simple task → briefing optional

**Briefing template:** `memory/templates/subagent-briefing.md`

**Mandatory before every complex subagent spawn:**
1. Orchestrator writes briefing doc (use template)
2. Orchestrator self-certifies all 3:
   - Does briefing include explicit success criteria?
   - Are scope boundaries explicitly defined (in/out)?
   - Are file dependencies and cross-references mapped?
3. If any answer is "no" → complete the briefing before spawning
4. Attach briefing to spawn or write to `results/<project>/briefing.md`

**Anti-pattern:** Subagent spawns on complex task (≥10) without briefing → orchestrator absorbs blank-slate tax, defeating the delegation optimization.

---

### Category A: Recoverable → Retry
- Timeout → retry with higher timeout (see escalation table below)
- Rate limit → backoff 60s, retry
- Partial success → complete manually, keep good parts

**Timeout escalation table (enforced by timeout-recovery.sh + delegate-with-checkpoint.sh):**
| retry_count | escalation | Action | Exit code |
|-------------|-----------|--------|-----------|
| 0 | RETRY | First timeout → retry at 2x original (cap 480s) | 0 (spawn retry) |
| 1 | ORCHESTRATOR_TAKEOVER | Second timeout → orchestrator completes directly | 2 |
| ≥2 | EXHAUSTED | Orchestrator must finish without further delegation | 3 |

**Checkpoint schema (checkpoint.json):**
```json
"timeout": {
  "original_timeout_seconds": 300,  // base — never compounds on retry
  "retry_count": 0,                 // 0=fresh, 1=first-retry, 2=takeover
  "escalation": "RETRY",            // RETRY | ORCHESTRATOR_TAKEOVER | EXHAUSTED
  "triggered": false
},
"orchestrator_takeover": false      // durable signal (written before exit 2)
```
Legacy `recovery.retry_count` auto-migrated to `timeout.retry_count` on first read.

**Atomic ops:** All checkpoint R/W use `flock -x` (exclusive lock). Prevents race conditions.

**Reset (required after any resolution event):**
After task complete, orchestrator takeover, or user abort:
```bash
timeout-recovery.sh --project X --checkpoint /path/to/checkpoint.json --reset
```
This clears `retry_count → 0` — without it, all future delegations on that project BLOCK permanently.

**Exit codes:**
- `timeout-recovery.sh`: 0=retry spawned, 2=orchestrator takeover, 3=escalation exhausted
- `delegate-with-checkpoint.sh`: 4=escalation exhausted, block spawn

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

| Primary | Fallback 1 | Fallback 2 | Fallback 3 |
|---------|-----------|-----------|-----------|
| qwen3-coder | Minimax | GLM | kimik2thinking |
| kimik2thinking | deepseek32 | qwq32b (last resort) | qwen35 |
| deepseek32 | kimik25 | qwq32b (last resort) | qwen35 |
| qwen35 | GLM-5.1 | Minimax | kimik2thinking |
| gemini-flite | openrouter-free | — | — |
| minimax-hs | kimik25 | deepseek32 | qwq32b (last resort) |
| GLM-5.1 | Minimax | GLM | — |
| Minimax | GLM | GLM-5.1 | — |
| qwq32b | kimik2thinking | qwen35 | — |
| openrouter-free | gemini-flite | — | — |

**GLM-5.1 quota fallback:** On quota error → MiniMax-M2.7 (configured default)

**Emergency fallback:** If all chains exhausted → MiniMax-M2.7

**Available models on this system (openclaw models list, 2026-03-30):**
- `zai/glm-5.1` (GLM51) — Primary orchestrator
- `zai/glm-4.7` (GLM)
- `minimax/MiniMax-M2.7` (Minimax)
- `minimax/MiniMax-M2.7-highspeed` (minimax-hs)
- `nvidia/moonshotai/kimi-k2-thinking` (kimik2thinking)
- `nvidia/moonshotai/kimi-k2.5` (kimik25)
- `nvidia/qwen/qwen3.5-397b-a17b` (qwen35)
- `nvidia/qwen/qwen3-coder-480b-a35b-instruct` (qwen3-coder)
- `nvidia/qwen/qwq-32b` (qwq32b) — last resort fallback only
- `nvidia/deepseek-ai/deepseek-v3.2` (deepseek32)
- `google/gemini-2.5-flash-lite` (gemini-flite) — multimodal
- `kilocode/openrouter/free` (openrouter-free) — multimodal fallback

**Excluded (poor performance):** corethink, nemotron

---

## Key Rules for Orchestrator

1. **Orchestrator uses GLM-5.1** as primary (200k context). Fallback to Minimax or GLM.
2. **Orchestrator writes.** Subagent produces → I write files. Never expect subagent to write to disk.
3. **Template first.** Check PROJECT_REGISTRY → match task type → select template before spawning.
4. **Progress file before spawn.** Always create progress file before `sessions_spawn`.
5. **Chunk big tasks.** If >5 files or >500 lines, split into atomic sub-tasks.
6. **Post-delegation verification is mandatory.** See ORCHESTRATOR_VERIFY.md after every subagent completion.
