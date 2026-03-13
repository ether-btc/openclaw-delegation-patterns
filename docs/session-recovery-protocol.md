# Session Recovery Protocol

**Mandatory: Run on every session start before accepting user input**

## Session Recovery Checklist

### ON SESSION START (after /new, crash, or reset):

1. **Run recovery script:**
   ```bash
   scripts/session-checkpoint.sh recover
   ```

2. **Check incomplete subagents:**
   ```bash
   subagents list
   ```

3. **Identify active projects:**
   ```bash
   ls -t memory/projects/*/progress.md 2>/dev/null | head -5
   ```

4. **Report to human:**
   - What was in progress
   - What's unfinished
   - Any blockers

5. **Create daily note entry** documenting recovery state

## Session Start Sequence

1. Read SOUL.md (essence)
2. Read USER.md (purpose)
3. Read memory/YYYY-MM-DD.md (recent context)
4. **Run recovery check** ← NEW
5. Greet human

## When Recovery Fails

- If checkpoint unavailable: Start fresh, note gap in memory
- If subagents stuck: Kill or reassign
- Report honestly: "No checkpoint found, starting fresh"

---

*Created: 2026-03-05 | Based on subagent analysis of session continuity gaps*
