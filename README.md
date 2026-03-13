# OpenClaw Delegation Patterns

Production-grade delegation and subagent handoff protocols for OpenClaw.

## Overview

This repository documents battle-tested patterns for delegating work to subagents in OpenClaw. It covers everything from when to delegate to atomic task design, progress tracking, and failsafe testing.

## Philosophy

**Orchestrator-Led Pattern**: The main agent handles all file operations while subagents focus on reasoning and generating output. Subagents report back to the main agent, who updates files and communicates results to the user.

**Core Principles**:
- Atomic tasks: One subagent run, one well-defined objective
- Progress tracking: File-based state machine for reliability
- Failsafe first: Backup → verify → change → verify → rollback if needed
- Token budgeting: Select models based on task complexity

## Quick Start

### 1. Choose Your Model

| Task Type | Model | Invocation |
|-----------|-------|------------|
| Quick summary | minimax-m2.5:free | `model: kilocode/minimax/minimax-m2.5:free` |
| Fast reasoning | glm-4.7 | `model: zai/glm-4.7` |
| Coding | qwen3-coder | `agentId: qwen3-coder` |
| Analysis | kimik2thinking | `agentId: kimik2thinking` |
| Heavy reasoning | deepseek-reasoner | `agentId: deepseek-reasoner` |

### 2. Follow the Checklist

Before delegating:
- [ ] Task fits a delegation role
- [ ] Model selected correctly
- [ ] Task is atomic (single objective)
- [ ] Success criteria defined
- [ ] Timeout set appropriately

### 3. Use Progress Tracking

Every subagent task should have a progress file:
```json
{
  "task_id": "example-task",
  "state": "in-progress",
  "progress": 50,
  "last_updated": "2026-03-13T10:00:00Z"
}
```

## Documentation

- [Delegation Fundamentals](docs/delegation-fundamentals.md) - Core concepts and when to delegate
- [Subagent Handoff Protocol](docs/subagent-handoff-protocol.md) - File-based progress tracking
- [Delegation Enforcement](docs/delegation-enforcement.md) - Pre-delegation checklists
- [Failsafe Testing](docs/failsafe-testing.md) - Backup/verify/rollback patterns
- [Quota Management](docs/quota-management.md) - Token budgeting and model selection
- [Orchestrator Pattern](docs/orchestrator-pattern.md) - Main agent handles files

## Templates

- [Delegation Prompt](templates/delegation-prompt.md) - Template for spawning subagents
- [Progress Tracking Schema](templates/progress-tracking-schema.md) - JSON schema for progress files

## Examples

- [Coding Delegation](examples/coding-delegation.md) - Real-world coding scenario
- [Research Delegation](examples/research-delegation.md) - Research delegation scenario

## Scripts

- [delegate-enforcer.sh](scripts/delegate-enforcer.sh) - Automatic model selection

## Related Resources

This project complements [openclaw-runbook](https://github.com/ether-btc/openclaw-runbook), which covers operational procedures and deployment patterns.

## Community

Built by the OpenClaw community. Contributions welcome—see CONTRIBUTING.md for details.

## License

MIT License - See LICENSE file for details.
