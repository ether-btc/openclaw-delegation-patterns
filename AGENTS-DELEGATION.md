# Delegation Enforcement (Mandatory)

## Golden Rule

**Orchestrator-Led Pattern ONLY**

All delegation MUST follow:
1. Subagents execute work, report back to me
2. I handle all file updates and tracking  
3. Clear separation: execution vs coordination
4. Single source of truth for progress

**Progress-file nuance (not prohibited — structured correctly):**
- ✅ Subagent writes **checkpoint state** (phase, progress %, current step) → orchestrator reads
- ✅ Orchestrator is sole source of truth for **what gets committed** to memory
- ❌ Subagent writes **final deliverables** directly → orchestrator must extract and own
- ❌ Subagent updates shared memory files without orchestrator mediation

The result-sink pattern: subagent appends to `results/sink.jsonl`, orchestrator reads and merges on completion.

---

## Model Matrix

| Task Type | Model | Format | Status |
|-------------|--------|--------|--------|
| Coding | `agentId: qwen3-coder` | Orchestrator-led | ✅ Works |
| Reasoning | `agentId: kimik2thinking` | Orchestrator-led | ✅ Works |
| Quick tasks | `model: minimax/MiniMax-M2.7` | Orchestrator-led | ✅ Works |
| Fast reasoning | `model: zai/glm-4.7` | Orchestrator-led | ✅ Works |

**Format Rule:**
- ✅ `agentId:` → Agent wrapper (qwen3-coder, kimik2thinking, nvidia/deepseek-ai/deepseek-v3.2)
- ✅ `model:` → Provider-integrated (zai/glm-4.7, minimax/MiniMax-M2.7)
- ❌ NEVER use full model IDs like `nvidia/qwen/qwen3-coder-480b-a35b-instruct`

---

## Mandatory References

- **Full protocol:** `memory/delegation-protocol-enforcement.md`
- **Spawn template:** `memory/prompts/subagent-orchestrator-led.md`
- **Enforcement script:** `scripts/delegate-enforcer.sh`

---

*Updated: 2026-03-11*
*This is MANDATORY. Violation = degraded reliability.*
