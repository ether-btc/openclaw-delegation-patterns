# FEEDBACK_TRACKING.md — Staff Engineer Feedback Protocol

**Purpose:** Track implementation of Staff Engineer feedback per project cycle.

## File Locations

| Project Type | Feedback File |
|--------------|---------------|
| Self-audit | `results/<project>/feedback-tracking.json` |
| CHARON-CLAW | `feedback-tracking.json` (project root) |

## Schema (feedback-tracking.json)

```json
{
  "project": "project-name",
  "review_cycle": "cycle-identifier",
  "date_reviewed": "YYYY-MM-DD",
  "reviewer": "code-reviewer|staff-engineer|user",
  "approval_status": "pending|approved|rejected|partial",
  "feedback_items": [
    {
      "id": "FB-NN",
      "phase": "A-G",
      "issue": "description",
      "severity": "HIGH|MEDIUM|LOW",
      "remediation": "what was done",
      "implemented_by": "charon",
      "implemented_date": "YYYY-MM-DD",
      "verified": false
    }
  ],
  "checkpoints": [
    {
      "date": "YYYY-MM-DD",
      "feedback_addressed": false,
      "code_reviewed": false,
      "staff_engineer_approved": false
    }
  ],
  "next_review": "YYYY-MM-DD"
}
```

## Workflow

1. **Review Phase:** Code reviewer / Staff Engineer identifies issues
2. **Implementation:** Charon implements fixes
3. **Verification:** Code reviewer audits implementation
4. **Approval:** Staff Engineer signs off
5. **Close:** Set checkpoint flags to `true`

## Policy

- **Unaddressed HIGH severity:** Blocks project closure
- **Code review required:** Before Staff Engineer approval
- **Traceability:** Every feedback item links to specific finding
