# Subagent Briefing Template

**Purpose:** Eliminate blank-slate tax by pre-digesting context before subagent spawn.
**When to use:** Any task scoring ≥10 on the complex task scoring matrix.
**Rule:** Read this before spawning. Self-certify all 3 checklist items. If any is "no" — incomplete, do not spawn.

---

## Briefing: [Task Name]

**Project:** `results/<project>/`  
**Created by:** Orchestrator  
**Date:** YYYY-MM-DD  
**Score:** [complexity score from matrix] | **Briefing required:** Y/N

---

### 1. Intent

**What problem are we solving?**  
[One paragraph. Be specific — not "fix the scripts" but "fix the unquoted $1 in send-alert.sh which causes arg expansion on whitespace paths."]

**Why does this matter?**  
[What breaks without this? What user/system impact?]

---

### 2. Success Criteria

- [ ] **[Deliverable 1]** — defined, measurable
- [ ] **[Deliverable 2]** — defined, measurable
- [ ] **[Deliverable 3]** — defined, measurable

**Success test:** [How will you know this is done and correct?]

---

### 3. Scope Boundaries

**In scope (do these):**
- [ ]
- [ ]

**Out of scope (do NOT do these):**
- [ ]
- [ ]

---

### 4. File Map & Dependencies

**Files to touch:**
| File | Role in this task | Cross-refs to |
|------|-------------------|---------------|
| | | |

**Existing known-good state:**
- [Any files that must not be broken — e.g., "agent-backup.sh must not change"]

**Dependencies:**
- Scripts/libs this task depends on: [list]
- Configs that must be consistent: [list]

---

### 5. Key Decisions (Frozen)

**Already decided (do not revisit):**
- [Decision 1] — reason: [why this choice]
- [Decision 2] — reason: [why this choice]

**Open questions for subagent:**  
[None — or list only genuinely ambiguous items subagent must resolve]

---

### 6. Orchestrator Self-Certification

Before spawning, answer all three:

- [ ] **Does briefing include explicit success criteria?** (Section 2 — must be measurable)
- [ ] **Are scope boundaries explicitly defined (in/out)?** (Section 3 — must be concrete)
- [ ] **Are file dependencies and cross-references mapped?** (Section 4 — must include cross-refs)

**If any answer is "no" — briefing is incomplete. Fill in the gap before spawning.**

---

### 7. Handoff Instructions

**Spawn command:** `delegate-with-checkpoint.sh --project <name> --task "<task description>"`

**Subagent task prompt:**
```
Read briefing.md first. Then execute.

Task: [concise one-line description from Section 1]
Output: [where to write results — always results/<project>/]
Success criteria: [from Section 2 — quote directly]
```

---

### 8. Post-Spawn Checklist

- [ ] Briefing written and self-certified (above)
- [ ] Checkpoint initialized via `timeout-recovery.sh --project <name> --init`
- [ ] Progress file exists at `results/<project>/progress.md`
- [ ] Subagent spawned
- [ ] Monitor timeout per DELEGATION_CORE.md
