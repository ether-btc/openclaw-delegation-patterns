# PERSONA_SYNC — Subagent Persona System

**What this is:** How to assign personas to subagents based on delegation matrix.
**Where it lives:** `memory/protocols/PERSONA_SYNC.md`
**Status:** MANDATORY — must sync whenever delegation matrix changes

---

## Canonical Model Names

These are the ONLY valid model identifiers across all protocols and personas:

| Alias | Full Model ID |
|-------|--------------|
| qwen3-coder | nvidia/qwen/qwen3-coder-480b-a35b-instruct |
| kimik2thinking | nvidia/moonshotai/kimi-k2-thinking |
| deepseek32 | nvidia/deepseek-ai/deepseek-v3.2 |
| qwen35 | nvidia/qwen/qwen3.5-397b-a17b |
| GLM51 | zai/glm-5.1 |

## Personas

| Role | Persona File | Model | Use When |
|------|-------------|-------|----------|
| Coding | `memory/personas/qwen3-coder.md` | qwen3-coder | Code generation ONLY (never reviews) |
| Strategic Analyst | `memory/personas/strategic-analyzer.md` | GLM51 | Code review, architecture, synthesis |
| Deep Research | `memory/personas/kimik2thinking.md` | kimik2thinking | Multi-file analysis, Staff Engineer reviews |
| Fast Reasoning | `memory/personas/deepseek32.md` | deepseek32 | Quick analysis, parallel sweeps |
| General Analysis | `memory/personas/premium-mind.md` | qwen35 | Document review, summaries |
| High-Speed Fallback | — | `minimax/MiniMax-M2.7` | Automatic fallback when primary exhausted |

---

## How to Use a Persona

When spawning a subagent, include the persona in the task prompt:

```
Task: [description]
Model: [from matrix above]
Persona: See memory/personas/[persona-file].md

[TASK DETAILS]
```

The persona gives the subagent:
- Role clarity (who they are)
- Working style (how they operate)
- Output standards (what's expected)
- Constraints (what to avoid)

---

## Sync Rule

**MANDATORY:** Whenever the delegation matrix in AGENTS.md changes:
1. Update model IDs in each persona file
2. Verify model IDs match the new matrix
3. Update AGENTS.md delegation matrix table

**Never** change a model ID in AGENTS.md without updating the corresponding persona file.

---

## Verification

```bash
# Check all personas exist
ls memory/personas/*.md

# Check model IDs match AGENTS.md matrix
grep "Model:" memory/personas/*.md
```
