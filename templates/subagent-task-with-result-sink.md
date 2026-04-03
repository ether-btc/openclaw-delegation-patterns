# Subagent Task: {{TASK_NAME}}
**Project:** {{PROJECT_NAME}}
**Created:** {{CREATED_AT}}
**Timeout:** {{TIMEOUT_SECONDS}}s

---

## ⚠️ FILE ACCESS CONSTRAINT (MANDATORY)

You may **ONLY** use `write` or `edit` on paths under:
```
~/.openclaw/workspace/results/{{PROJECT_NAME}}/
```

**CRITICAL:** Using `write` or `edit` on any other path under `~/.openclaw/workspace/` = task failure, immediate stop.

The orchestrator will verify `results/` exists before accepting your completion.
If `results/` is empty when you report COMPLETE, the orchestrator will assume you failed.

All output files → write to `results/{{PROJECT_NAME}}/<phase>.json`
Do NOT write to any other path in `~/.openclaw/workspace/`

---

## Task

{{TASK_NAME}}

---

## Workflow

1. **Read** any files you need (from `~/.openclaw/workspace/`)
2. **Do the work** — produce your outputs
3. **Write results** to `~/.openclaw/workspace/results/{{PROJECT_NAME}}/<phase>.json`
4. **Update checkpoint** with:
   ```bash
   bash ~/.openclaw/workspace/scripts/subagent-result-sink.sh \
     --project {{PROJECT_NAME}} \
     --phase <your-phase-name> \
     --data '<json-output>'
   ```
5. **Say "COMPLETE"** — the orchestrator will read `results/` and copy to workspace

---

## What NOT to Do

- ❌ Do NOT use `write` or `edit` on `~/.openclaw/workspace/memory/`
- ❌ Do NOT use `write` or `edit` on `~/.openclaw/workspace/skills/`
- ❌ Do NOT use `write` or `edit` on `~/.openclaw/workspace/scripts/`
- ❌ Do NOT deliver file contents in your response text
- ❌ Do NOT write to any path under `~/.openclaw/workspace/` except `results/{{PROJECT_NAME}}/`

## What TO Do

- ✅ Read files freely from `~/.openclaw/workspace/`
- ✅ Write outputs to `~/.openclaw/workspace/results/{{PROJECT_NAME}}/`
- ✅ Update checkpoint after writing results
- ✅ Report completion with "COMPLETE"

---

## Phase Headers

For multi-phase work, use headers from `memory/templates/project-phase-headers.md`:
- Short updates → `─── Phase {N} ───`
- Milestones → `───────────◆───────────  PHASE {N}: {TITLE}  ───────────◆───────────`
- Lightweight markers → `· · · Phase {N} · · ·`

## Progress Updates

Update the orchestrator every ~2 minutes with:
```
Progress: [phase], [step], [percent]% — [what you did]
```

If you receive a checkpoint signal (USR1) → write current state to results/ immediately.

---

## CWD
Working directory: `{{CWD}}`
