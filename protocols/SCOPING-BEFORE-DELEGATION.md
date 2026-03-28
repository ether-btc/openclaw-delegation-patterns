# SCOPING-BEFORE-DELEGATION

**When:** Before delegating any task involving archives, multi-file reviews, or parallel subagent work.

**Principle:** Survey → Decide → Chunk → Delegate. Never skip steps.

**Sequence:**
1. **Survey first** (5-10 min): Map the terrain, identify scope, estimate effort
2. **Decide**: Determine what to review, what to skip, what decisions are needed
3. **Compactness gate**: Run `compactness-score.sh`. If HIGH, reduce scope before proceeding to chunk phase.
4. **Chunk**: Split into bounded, atomic tasks (each <5 files, <500 lines, <3 outputs)
5. **Model selection**: Use delegation matrix in AGENTS.md for model selection
6. **Delegate**: Assign specific tasks with clear success criteria

**Examples:** "before reviewing an archive", "before parallel subagent work", "before multi-project audit"

**Rule:** If you haven't scoped it, you can't delegate it.
