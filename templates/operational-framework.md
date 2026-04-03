# Operational Framework — Project Kickoff Prompt

_Use this to trigger a structured, multi-phase project with full orchestration._

---

## Prompt Template

```
I'd like to set up a [PROJECT TYPE] project: [ONE-LINE DESCRIPTION].

Apply the operational framework:
1. Plan mode first — scope, chunk, get approval before building
2. Delegate to subagents (one task each, right model for the job)
3. Staff Engineer review at every phase gate
4. Verify before marking done — evidence required
5. Capture lessons after corrections
6. Demand elegance — challenge your own work before presenting

Deliver the phased plan for my approval. Then execute phase by phase.
```

---

## What This Activates (Agent Internal Protocol)

### Phase 0 — Planning (Plan Mode)
- Scope the project: boundaries, deliverables, acceptance criteria
- Break into atomic phases (≤5 files, ≤500 lines per chunk per CHUNKING.md)
- Select models per delegation matrix
- Write plan to `memory/projects/<name>/PLAN.md`
- **Gate:** User approves plan before any execution

### Phase 1..N — Execution
- Pre-flight: run `pre-delegation-checklist.sh` (7 checks, blocking)
- Spawn subagents via `delegate-with-checkpoint.sh` ONLY
- Each subagent writes to `results/<project>/` — orchestrator copies to workspace
- Monitor via `monitor-subagent.sh` + timeout escalation protocol
- **Phase headers:** Use `memory/templates/project-phase-headers.md` — three tiers for different visibility levels
- **Gate:** Staff Engineer review (GLM-5.1 or kimik2thinking) at each phase boundary
- **Gate:** User sign-off on major decisions

### Phase Final — Verification & Delivery
- Run `verify-handoff.sh` — all deliverables exist and are non-empty
- Run `elegance-check.sh --min-score 70` on code deliverables
- Write final report to `memory/projects/<name>/FINAL-report.md`
- Capture lessons to `memory/lessons/`
- Commit everything with descriptive messages

### Continuous — Self-Improvement
- After any correction: write lesson to `memory/lessons/`
- After any timeout: check disk for partial output before restarting
- After any failure: RCA before retry
- Review lessons at session start

---

## Model Selection (Quick Reference)

| Task Type | Model | Why |
|-----------|-------|-----|
| Code generation | qwen3-coder | Purpose-built, fast |
| Code review / synthesis | GLM-5.1 | Strategic Analyst, 0% review failure |
| Deep research / multi-file analysis | kimik2thinking | 0% failure, handles complexity |
| Quick lookups / parallel tasks | deepseek32 | Fast, cheap |
| General analysis | qwen35 | Balanced |

**Bypass rule:** ≤3 tool calls → orchestrator handles directly, no delegation.

---

## Anti-Patterns (Auto-Blocked)

- ❌ Subagent writing directly to workspace (results/ only)
- ❌ Skipping pre-flight checklist
- ❌ "Done" without file-in-workspace evidence
- ❌ qwen3-coder for reviews (13% failure rate)
- ❌ Second timeout on same task without orchestrator takeover
- ❌ Temporary fixes without root cause analysis

---

## Example Usage

```
Set up a self-audit architecture project: comprehensive review of all
workspace scripts, protocols, and delegation patterns with remediation.

Apply the operational framework.
```

```
Build a monitoring dashboard: daily health checks for the RPi infrastructure,
with Telegram alerts on failure.

Apply the operational framework.
```
