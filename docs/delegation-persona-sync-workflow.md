# Workflow: Delegation Matrix → Persona Sync

## Purpose
Ensure personas always reflect the current delegation matrix. Triggered whenever the matrix changes in SOUL.md.

## Trigger
Any change to SOUL.md "Delegation" section

## Process

### Step 1: Detect Change
- When SOUL.md Delegation section is modified
- Identify new/updated model IDs

### Step 2: Sync Personas
For each role in the delegation matrix:

| Role | Action Required |
|------|----------------|
| Coding | Create/update `memory/personas/senior-coder.md` with new model ID |
| Reasoning | Create/update `memory/personas/reasoner.md` with new model ID |
| Fast | Create/update `memory/personas/fast-mind.md` with new model ID |
| Heavy reasoning | Create/update `memory/personas/heavy-reasoner.md` with new model ID |
| Premium | Create/update `memory/personas/premium-mind.md` with new model ID |
| Fast reasoning | Create/update `memory/personas/quick-reasoner.md` with new model ID |

### Step 3: Update AGENTS.md
- Refresh delegation matrix table in AGENTS.md
- Update persona file references

### Step 4: Verification
- Confirm all persona files exist
- Verify model IDs match SOUL.md

## Prompt Template

When reassessing delegation matrix, use this prompt:

```
Reassess delegation models in SOUL.md.

If models changed:
1. Update each persona in memory/personas/ with new model ID:
   - senior-coder.md (Coding)
   - reasoner.md (Reasoning)
   - fast-mind.md (Fast)
   - heavy-reasoner.md (Heavy reasoning)
   - premium-mind.md (Premium)
   - quick-reasoner.md (Fast reasoning)

2. Update AGENTS.md delegation matrix table

3. Verify: ls memory/personas/*-{coder,reasoner,fast,heavy,premium,quick}*.md

Report: Which personas updated?
```

## Automation Note
This workflow is MANDATORY. No delegation matrix change is complete until personas are synced.

---

*Enforced: 2026-03-07*
*Reference: SOUL.md Delegation section*
