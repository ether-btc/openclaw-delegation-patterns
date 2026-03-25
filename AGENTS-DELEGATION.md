# Delegation Enforcement (Mandatory)

## Golden Rule

**Orchestrator-Led Pattern ONLY**

All delegation MUST follow:
1. Subagents execute work, report back to me
2. I handle all file updates and tracking
3. Clear separation: execution vs coordination
4. Single source of truth for progress

### Result-Sink Convention (MANDATORY for all subagent tasks)

Subagents MUST write incremental results to `results/sink.jsonl` using the result-sink script. This survives compaction and session death:

```bash
bash $WORKSPACE/scripts/subagent-result-sink.sh \
    --phase "phase-name" \
    --status "complete" \
    --content "your findings here"
```

Mark final output with `--status "final"`. The orchestrator reads the sink after completion.

**Progress files are subagent-owned state — this is fine.** The prohibition is on subagents writing DELIVERABLES. Progress/checkpoint state and result-sink are subagent output mechanisms, not file operations on behalf of the orchestrator.

---

## Model Matrix

| Task Type | Model | Format | Status |
|-----------|-------|--------|--------|
| Coding | `model: qwen3-coder` | Orchestrator-led | ✅ Works |
| Deep reasoning | `model: kimik2thinking` | Orchestrator-led | ✅ Works |
| General analysis | `model: kimik25` | Orchestrator-led | ✅ Works |
| Quick tasks | `model: minimax/MiniMax-M2.7` | Orchestrator-led | ✅ Works |
| Fast reasoning | `model: GLM` | Orchestrator-led | ✅ Works |
| Fast reasoning alt | `model: gemini-2.5-flash-lite` | Orchestrator-led | ✅ Works |

**Format Rule:**
- ✅ `model:` → Use this for ALL model selection in sessions_spawn
- ✅ Model aliases (`qwen3-coder`, `kimik25`, `GLM`) are preferred over full IDs
- ❌ NEVER use full model IDs like `nvidia/qwen/qwen3-coder-480b-a35b-instruct`

**Available models (from `openclaw models list`):**
```
nvidia/moonshotai/kimi-k2.5         alias: kimik25
zai/glm-4.7                         alias: GLM (may be exhausted — check status)
nvidia/moonshotai/kimi-k2-thinking  alias: kimik2thinking
nvidia/qwen/qwen3.5-397b-a17b      alias: qwen35
nvidia/qwen/qwen3-coder-480b-a35b-instruct  alias: qwen3-coder
nvidia/deepseek-ai/deepseek-v3.2   alias: deepseek32
google/gemini-2.5-flash-lite        (no alias)
minimax/MiniMax-M2.7-highspeed
minimax/MiniMax-M2.7               alias: Minimax
```

---

## Mandatory References

- **Full protocol:** `memory/protocols/DELEGATION_CORE.md`
- **Spawn template:** `memory/templates/subagent-task-with-progress.md`
- **Enforcement script:** `scripts/pre-delegation-checklist.sh`
- **Compaction resilience:** `docs/subagent-compaction-resilience.md`

---

*Updated: 2026-03-25*
*This is MANDATORY. Violation = degraded reliability.*
