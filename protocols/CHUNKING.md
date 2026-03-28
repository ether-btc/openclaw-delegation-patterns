# CHUNKING PROTOCOL — Unified Subagent Task Decomposition

**Date:** 2026-03-28
**Synthesized from:** DELEGATION_CORE.md, SCOPING-BEFORE-DELEGATION.md, subagent-compaction-audit.md, orchestrator.md, Staff Engineer review

---

## Core Principle

**If a subagent can fail at something, chunk it smaller or handle it directly.**

Chunking is not about being stingy with delegation — it's about assigning work that each model can reliably complete. A subagent that fails repeatedly is worse than no subagent at all.

---

## The Chunking Decision (BEFORE ANY DELEGATION)

### Step 1: Is This Delegatable?

| Condition | Action |
|-----------|--------|
| Task = 1 tool call | **Orchestrator does it directly** |
| Task = ≤3 tool calls, no discovery | **Orchestrator does it directly** |
| "Is X already Y?" check | **Orchestrator does it directly** |
| Complex multi-file, unknown domain | **Delegate with strict chunking** |
| Pure code generation, single file | **Delegate to qwen3-coder** |

### Step 2: Estimate Complexity

Count expected actions for the subagent:

| Factor | Count | Action |
|--------|-------|--------|
| **Unique files to read** | ___ | If >3 → SPLIT (same file read twice = 1) |
| Tool calls (total) | ___ | If >5 → SPLIT |
| Output sections | ___ | If >3 → SPLIT |
| Code lines to generate | ___ | If >200 → SPLIT |
| Phases (discovery → do → verify) | ___ | If >1 → SPLIT by phase |

### Step 3: Design Chunks

Each chunk must be:
- **Atomic:** one model type, one phase, one output artifact
- **Bounded:** ≤5 tool calls AND ≤3 files read
- **Testable:** clear success criteria before spawning
- **Recoverable:** result goes to `results/<project>/`, not workspace

```
TASK: Build a research report on Topic X

BAD CHUNK (fails):
  "Research Topic X → write 4 files → review all → commit"
  → 20+ tool calls, 4 phases, unknown model fit
  
GOOD CHUNKS (succeed):
  Chunk 1: Research Topic X → kimik2thinking → output: findings.json
  Chunk 2: Write draft report → qwen35 → input: findings.json → output: draft.md
  Chunk 3: Review draft → kimik2thinking → input: draft.md → output: review-notes.md
  Chunk 4: Orchestrator reviews notes, applies fixes, commits
```

---

## Hard Limits (Never Exceed)

| Limit | Value | Rationale |
|-------|-------|-----------|
| Tool calls per chunk | **≤5** | Beyond this, failure rate climbs sharply |
| Files read per chunk | **≤3** | Each read adds ~100-300 tokens to context |
| File writes per chunk | **≤1** | Writes are where compaction kills output |
| Code lines per chunk | **≤200** | More → split into functions |
| Chunk timeout | **≤300s** | 480s only for script-build with test cycles |

**Bypass rule:** Tasks with **≤3 expected tool calls** → orchestrator handles directly. No subagent overhead.

---

## Model-Specific Chunk Constraints

| Model | Max tool calls | Max files read | Best for |
|-------|---------------|----------------|---------|
| qwen3-coder | 5 | 2 | Single-file code, no discovery |
| kimik2thinking | 5 | 3 | Multi-file research, analysis |
| deepseek32 | 3 | 2 | Fast lookups, simple synthesis |
| qwen35 | 5 | 3 | Summaries, document review |

**Rule for qwen3-coder:** Never assign multi-file discovery. If you don't know which files exist → kimik2thinking first.

---

## Chunking Anti-Patterns

These chunk designs reliably fail:

```
❌ "Read all files in directory X and summarize"
   →kimik2thinking can do this in one chunk if ≤3 files
   
❌ "Research topic X, write code Y, test Z"
   → 3 different task types, 3 chunks needed
   
❌ "Fix bugs in 10 files"
   → 10 files = 10 chunks (or group by file type)
   
❌ "Review all markdown files in memory/"
   → Unknown count → survey first, then chunk by subdirectory
   
❌ "Fix subagent that timed out"
   → Orchestrator does it directly — don't re-delegate
```

---

## Survey → Decide → Chunk → Delegate

(from `SCOPING-BEFORE-DELEGATION.md`)

### 1. Survey (Orchestrator)
Understand the terrain before assigning work. Read enough to estimate:
- How many files are relevant?
- How many distinct phases?
- What model fits best?

### 2. Decide
- Can I do this directly? (bypass → orchestrator)
- Can one subagent handle it? (≤5 calls, ≤3 files → delegate)
- Does it need splitting? (→ chunk each phase)

### 3. Chunk
- Each chunk = one model, one phase, one result artifact
- Name chunks explicitly: `chunk-1-discover`, `chunk-2-write`, `chunk-3-review`
- Write chunk plan to `memory/projects/<project>/progress.md`

### 4. Pre-Delegation Audit (from `subagent-compaction-audit.md`)
Before spawning — if ANY answer is RED, STOP and chunk smaller:
- [ ] Dispatch file exists? (multi-phase projects)
- [ ] Checkpoint JSON created?
- [ ] Task fits compactness (≤15 total tool calls)?
- [ ] Result-sink constraint in task prompt?
- [ ] Parent context <80% full?

### 5. Delegate
- Assign each chunk to appropriate model
- Include in each task prompt:
  - What files are in/out
  - What "done" looks like
  - Where to write output (`results/<project>/`)
  - **Result-sink constraint** (no direct workspace writes)

---

## Result-Sink Enforcement

Every subagent task prompt MUST include:

```
CONSTRAINT: Write ALL output to:
  ~/.openclaw/workspace/results/<project>/output.json
  Do NOT write to any path under:
  ~/.openclaw/workspace/
  (Exception: progress.md in the project dir is OK)

After completing your work:
1. Write findings to results/<project>/output.json
2. Say "COMPLETE" in your response text
3. The orchestrator will read output.json and copy to workspace
```

**Why this matters:** Compaction fires → session dies → output is in results/ → orchestrator recovers. Without this, compaction kills the only copy.

---

## Timeout Escalation

| Failure | Action |
|---------|--------|
| First timeout | Retry at 2× original timeout |
| Second timeout (same chunk) | Orchestrator takes chunk direct — stop delegating |
| Timeout during file write | Check results/ first — file may exist |
| Three consecutive failures (any chunk) | Do entire task direct |

---

## Quick Reference Card

```
BEFORE SPAWNING:
├─ Is tool call count ≤3? → DIRECT (no subagent)
├─ Is this pure code, single file? → qwen3-coder
├─ Is this multi-file research? → kimik2thinking
├─ Are tool calls ≤5 AND files ≤3? → SPAWN
└─ More than that? → SPLIT FIRST

AFTER SPAWNING:
├─ Wait for auto-announce (push-based)
├─ If timeout → check results/ before assuming failure
└─ If second timeout → take direct, report why

RESULT-SINK (non-negotiable):
└─ output → results/<project>/ → orchestrator copies
```

---

## Relationship to Other Protocols

- **DELEGATION_CORE.md** — timeout table, error classification, fallback models. This chunking protocol complements it.
- **SCOPING-BEFORE-DELEGATION.md** — Survey → Decide → Chunk → Delegate. This chunking protocol is the "Chunk" step made concrete.
- **subagent-compaction-audit.md** — Pre-delegation audit questions. Use before every spawn.
- **subagent-task-with-progress.md** — Result-sink template. Use for multi-phase tasks.
