# OpenClaw Delegation Patterns

Battle-tested protocols, scripts, and templates for AI agent orchestration. Designed to be framework-agnostic — use these patterns with any multi-agent setup.

## Architecture

```
protocols/    → Rules of engagement (how to delegate, verify, recover)
scripts/      → Enforceable tooling (checklists, monitoring, scoring)
templates/    → Copy-paste starting points (task briefs, research, analysis)
```

**Flow:** Survey → Decide → Chunk → Delegate → Monitor → Verify → Merge

## Protocols

| Protocol | Purpose |
|----------|---------|
| **DELEGATION_CORE** | Timeout guidelines, model routing, error handling, pre-handoff briefing |
| **DELEGATION-SURVIVAL** | Failure modes, recovery strategies, rollback procedures |
| **CHUNKING** | When and how to split tasks — file count, line count, complexity thresholds |
| **SCOPING-BEFORE-DELEGATION** | Mandatory scope analysis before spawning subagents |
| **HANDOFF_PROTOCOL** | Input/output contracts between orchestrator and subagents |
| **ORCHESTRATOR_VERIFY** | Post-completion verification checklist |
| **PERSONA_SYNC** | Keeping agent personas consistent across sessions |
| **FEEDBACK_TRACKING** | Staff Engineer review pipeline — track, resolve, close feedback |
| **subagent-delegation-protocol** | The core spawn → monitor → recover lifecycle |

## Scripts

### Delegation Pipeline
| Script | Purpose |
|--------|---------|
| `delegate-with-checkpoint.sh` | Safe spawn with checkpoint file and progress tracking |
| `pre-delegation-checklist.sh` | 13-point verification before any delegation |
| `generate-subagent-briefing.sh` | Auto-generate context-rich briefing docs for subagents |
| `select-model.sh` | Score-based model router (files × 1.5 + lines × 0.1 + unknowns × 5) |

### Monitoring & Recovery
| Script | Purpose |
|--------|---------|
| `monitor-subagent.sh` | Active subagent health monitoring |
| `patrol-check.sh` | Detect stuck/zombie sessions, optional auto-kill |
| `verify-subagent-progress.sh` | Check progress files against expected milestones |
| `timeout-recovery.sh` | Structured recovery from timed-out subagents |
| `subagent-recover-transcript.sh` | Extract useful output from dead subagent transcripts |
| `subagent-safe-recover.sh` | Safe result extraction with rollback on failure |
| `subagent-result-sink.sh` | Collect and validate subagent outputs |

### Quality Gates
| Script | Purpose |
|--------|---------|
| `elegance-check.sh` | Code quality scoring — min threshold enforcement |
| `plan-mode-check.sh` | Determines if a task needs planning before execution |
| `feedback-tracking.sh` | Staff Engineer feedback lifecycle (create/update/close/log) |

### Verification & Metrics
| Script | Purpose |
|--------|---------|
| `verify-handoff.sh` | Deterministic post-completion verification |
| `orchestrator-verify.sh` | Orchestrator-level result validation |
| `compactness-score.sh` | Measure how much useful output per token spent |
| `measure-failure-rate.sh` | Track delegation success/failure ratios over time |

## Templates

| Template | Purpose |
|----------|---------|
| `subagent-task-with-result-sink.md` | Standard task with structured output collection |
| `subagent-task-with-progress.md` | Long-running task with progress file updates |
| `subagent-research.md` | Research & analysis task brief |
| `subagent-code-analysis.md` | Code review/analysis task brief |
| `subagent-compaction-audit.md` | Context compaction quality audit |
| `subagent-briefing.md` | Pre-handoff briefing template (8 sections) |
| `lesson_template.md` | Structured lesson learned format |
| `operational-framework.md` | Operational framework skeleton |
| `project-phase-headers.md` | Phase tracking headers for project docs |

## Model Selection

`select-model.sh` uses a scoring formula:

```
Score = (files × 1.5) + (lines × 0.1) + (unknowns × 5)
```

| Score Range | Strategy |
|-------------|----------|
| ≤ 3 tool calls | Handle directly (no delegation) |
| ≤ 10 | Standard model |
| > 10 | High-capability model |

## Quick Start

1. Copy `protocols/` into your agent's reference docs
2. Copy `scripts/` into your agent's executable path
3. Copy relevant `templates/` for your task types
4. Customize paths and model names in scripts
5. Start with `pre-delegation-checklist.sh` before your first delegation

### Key Rules

- **≤ 3 tool calls** → orchestrator handles directly, no delegation overhead
- **Survey → Decide → Chunk → Delegate** — never skip scoping
- **Subagents write to designated output dirs only** — orchestrator copies to workspace
- **Reported ≠ Complete** — always verify files exist before marking done
- **Timeouts:** Quick 60s | Analysis 180s | Code 300s

## Recovery Patterns

```
Timeout → Check transcript → Extract output → Retry or handle directly
Stuck session → Patrol check → Kill if zombie → Recover from progress file
Failed handoff → Verify progress file → Resume from last checkpoint
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). PRs welcome — please run sanitization checks on any submissions.

## License

MIT
