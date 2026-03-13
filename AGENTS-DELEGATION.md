# Delegation Enforcement (Mandatory)

## Golden Rule

**Orchestrator-Led Pattern ONLY**

All delegation MUST follow:
1. Subagents execute work, report back to me
2. I handle all file updates and tracking  
3. Clear separation: execution vs coordination
4. Single source of truth for progress

**NEVER progress-file approach** (subagents updating their own files):
- Different models behave differently
- Inconsistent results
- No single source of truth

---

## Model Matrix

| Task Type | Model | Format | Status |
|-------------|--------|--------|--------|
| Coding | `agentId: qwen3-coder` | Orchestrator-led | ✅ Works |
| Reasoning | `agentId: kimik2thinking` | Orchestrator-led | ✅ Works |
| Quick tasks | `model: kilocode/minimax/minimax-m2.5:free` | Orchestrator-led | ✅ Works |
| Fast reasoning | `model: zai/glm-4.7` | Orchestrator-led | ✅ Works |

**Format Rule:**
- ✅ `agentId:` → Agent wrapper (qwen3-coder, kimik2thinking, deepseek-reasoner)
- ✅ `model:` → Provider-integrated (zai/glm-4.7, kilocode/minimax/minimax-m2.5:free)
- ❌ NEVER use full model IDs like `nvidia/qwen/qwen3-coder-480b-a35b-instruct`

---

## Mandatory References

- **Full protocol:** `memory/delegation-protocol-enforcement.md`
- **Spawn template:** `memory/prompts/subagent-orchestrator-led.md`
- **Enforcement script:** `scripts/delegate-enforcer.sh`

---

*Updated: 2026-03-11*
*This is MANDATORY. Violation = degraded reliability.*
