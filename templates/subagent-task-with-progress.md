# Subagent Task Template (Default)

**Use for:** Multi-phase tasks, projects with checkpoints, any task needing progress tracking.

---

## Task: {{TASK_NAME}}

**Project:** {{PROJECT_NAME}}
**Created:** {{CREATED_AT}}
**Timeout:** {{TIMEOUT_SECONDS}}s

---

## Instructions

{{TASK_DETAILS}}

---

## Success Criteria

{{SUCCESS_CRITERIA}}

---

## Deliverables

{{DELIVERABLES}}

---

## Progress Tracking

1. Create progress file: `memory/projects/{{PROJECT}}/progress.md`
2. Update every 2 minutes: state=RUNNING, percent=X%
3. On completion: state=COMPLETED, percent=100%
4. On failure: state=FAILED, write error

**Result Sink Convention (MANDATORY):**
Write all incremental results to `results/sink.jsonl` using the result-sink script:
```
bash $WORKSPACE/scripts/subagent-result-sink.sh \
    --phase "phase-name" \
    --status "complete" \
    --content "your findings here"
```
- Use a descriptive phase name per logical step (e.g., "research", "synthesis", "review")
- Mark your FINAL output with `--status "final"`
- The sink survives compaction and session death — always write to it before your final response

**CRITICAL:** Do not write any deliverable files to disk. Produce your entire output in your response text AND in the result sink. The orchestrator will extract findings and write files. You only write to the progress file for state tracking and to the result sink for output delivery.

**Exception — script-build tasks:** If your task is to build a script and the timeout is ≥300s, you MAY write the script to disk. But you MUST also run tests and report results in your response text. If you time out before running tests, write the current script content to the progress file so the orchestrator can recover it.

---

## Phase Headers

For multi-phase work, use headers from `memory/templates/project-phase-headers.md`:
- Short updates → `─── Phase {N} ───`
- Milestones → `───────────◆───────────  PHASE {N}: {TITLE}  ───────────◆───────────`
- Lightweight markers → `· · · Phase {N} · · ·`

## Output Format

Report everything in your response so the orchestrator can write it to disk:
- Summary (2-3 sentences)
- Key findings (bullets)
- Files read/analyzed (list, don't write)
- Completion status

---

## Review Pipeline (OpenMOSS Reviewer Pattern)

After completing, the orchestrator will run `review-pipeline.sh` on your output:
- **Code tasks:** elegance-check + OCR review
- **Research/analysis:** content quality + length checks
- **Documents:** structure + length + header checks

If the review FAILS, the task goes back to you for rework. If it PASSES, it's delivered.

---

*Template: memory/templates/subagent-task-with-progress.md*
