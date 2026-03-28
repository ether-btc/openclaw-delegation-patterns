# OpenClaw Delegation Patterns

Production-grade delegation and subagent handoff protocols for OpenClaw. Battle-tested across 115+ subagent sessions with measured failure rates.

## Overview

This repository documents how to delegate work to subagents in OpenClaw reliably. It covers task decomposition, model selection, progress tracking, timeout handling, and post-completion verification.

### Key Metrics (baseline, 2026-03-28)

| Model | Sessions | Failure Rate |
|-------|----------|-------------|
| kimik2thinking | 16 | 0% |
| qwen3-coder | 46 | 13% |
| MiniMax-M2.7 | 16 | 0% |
| **Overall** | **107** | **8.4%** |

Target: <5% failure rate through chunking and model-matching.

## Philosophy

**Orchestrator Pattern**: One agent sees everything and routes work to specialists. The orchestrator writes files; subagents produce output. Not a democracy — one brain, multiple hands.

**Core Principles**:
- **Bypass rule:** ≤3 tool calls → orchestrator handles directly (no delegation overhead)
- **Chunking:** Every subagent gets ≤5 tool calls, ≤3 files to read, one output artifact
- **Result sink:** Subagents write to `results/<project>/` only — orchestrator copies to workspace
- **Verify before trust:** Check `results/` before assuming subagent failed (compaction kills delivery)

## Model Selection Matrix

| Role | Model Alias | Full Model ID | Use For |
|------|------------|---------------|---------|
| Coding | qwen3-coder | `nvidia/qwen/qwen3-coder-480b-a35b-instruct` | Code generation ONLY (never reviews) |
| Strategic Analyst | GLM51 | `zai/glm-5.1` | Code review, architecture, synthesis |
| Deep Research | kimik2thinking | `nvidia/moonshotai/kimi-k2-thinking` | Multi-file analysis, Staff Engineer reviews |
| Fast Reasoning | deepseek32 | `nvidia/deepseek-ai/deepseek-v3.2` | Quick lookups, parallel sweeps |
| General Analysis | qwen35 | `nvidia/qwen/qwen3.5-397b-a17b` | Document review, summaries |

**Rule:** qwen3-coder for code generation ONLY. Never assign reviews — 13% failure rate on multi-file analysis tasks.

## Quick Start

### 1. Survey → Decide → Chunk → Delegate

Before any delegation:
1. **Survey** the terrain (how many files? what complexity?)
2. **Decide** — can I do this directly? (bypass if ≤3 tool calls)
3. **Chunk** — split into atomic tasks (≤5 calls, ≤3 files each)
4. **Delegate** — assign to right model with result-sink constraint

### 2. Pre-Delegation Checklist

Run `scripts/pre-delegation-checklist.sh` before every delegation. It enforces:
- Task is atomic and well-defined
- Model selected correctly
- Result-sink constraint in task prompt
- Checkpoint created for multi-phase work

### 3. Post-Completion Verification

After subagent reports done:
1. Check `results/<project>/` — compaction may have killed delivery
2. Verify output quality
3. Copy results to workspace (orchestrator writes)
4. Run `scripts/orchestrator-verify.sh`

## Protocols

| Protocol | Purpose |
|----------|---------|
| [DELEGATION_CORE](protocols/DELEGATION_CORE.md) | Timeouts, error classification, fallback models, rollback |
| [CHUNKING](protocols/CHUNKING.md) | Task decomposition rules, hard limits, anti-patterns |
| [SCOPING-BEFORE-DELEGATION](protocols/SCOPING-BEFORE-DELEGATION.md) | Survey → Decide → Chunk → Delegate sequence |
| [ORCHESTRATOR_VERIFY](protocols/ORCHESTRATOR_VERIFY.md) | Post-completion verification (mandatory) |
| [HANDOFF_PROTOCOL](protocols/HANDOFF_PROTOCOL.md) | Progress tracking, state machine, stalled recovery |
| [PERSONA_SYNC](protocols/PERSONA_SYNC.md) | Model aliases, persona assignments, sync rules |
| [DELEGATION-SURVIVAL](protocols/DELEGATION-SURVIVAL.md) | Post-reset subagent recovery, streaming glitch handling |
| [Subagent Delegation](protocols/subagent-delegation-protocol.md) | qwen3-coder specific rules, context management |

## Templates

| Template | Use When |
|----------|----------|
| [Result Sink Task](templates/subagent-task-with-result-sink.md) | Default — subagent writes to results/ only |
| [Progress Task](templates/subagent-task-with-progress.md) | Multi-phase tasks with checkpoint tracking |
| [Research](templates/subagent-research.md) | Fact-finding, comparisons, pattern analysis |
| [Code Analysis](templates/subagent-code-analysis.md) | Code review, architecture assessment |
| [Compaction Audit](templates/subagent-compaction-audit.md) | Pre-delegation compactness checks |

## Scripts

| Script | Lines | Purpose |
|--------|-------|---------|
| `delegate-with-checkpoint.sh` | 299 | Canonical spawn path with auto-recall + checkpoint |
| `pre-delegation-checklist.sh` | 191 | 7-check gate (blocking on failure) |
| `timeout-recovery.sh` | 330 | Timeout escalation + auto-verify |
| `verify-handoff.sh` | 113 | Post-completion file verification |
| `orchestrator-verify.sh` | 122 | Result extraction + workspace copy |
| `measure-failure-rate.sh` | 163 | Subagent failure rate metrics |
| `select-model.sh` | 142 | Weighted model router |
| `compactness-score.sh` | 172 | Task complexity scoring |
| `patrol-check.sh` | 148 | Zombie/stuck subagent detection |

## Timeout Guidelines

| Task Type | Default | Max |
|-----------|---------|-----|
| Quick (single tool call) | 30s | 60s |
| Fact lookup / simple read | 60s | 120s |
| Code (<50 lines) | 60s | 120s |
| Code (50-200 lines) | 180s | 300s |
| Script build + test | 300s | 480s |
| Analysis / research | 180s | 300s |

**Escalation:** First timeout → 2× retry. Second timeout → orchestrator takes over directly.

## Hard Limits (Never Exceed)

| Limit | Value |
|-------|-------|
| Tool calls per chunk | ≤5 |
| Files read per chunk | ≤3 |
| File writes per chunk | ≤1 |
| Code lines per chunk | ≤200 |
| Chunk timeout | ≤300s (480s for script-build only) |
| Parallel subagents | ≤4 per wave |

## Community

Built by the OpenClaw community. Contributions welcome — see [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## Related Projects

- [openclaw-runbook](https://github.com/ether-btc/openclaw-runbook) — Operational procedures and deployment patterns
- [openclaw-correlation-plugin](https://github.com/ether-btc/openclaw-correlation-plugin) — Memory correlation rules for OpenClaw

## License

MIT License — See LICENSE file for details.
