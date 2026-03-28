# Subagent Code Analysis Template

**Use for:** Code review, architecture analysis, debugging, refactoring assessment.

---

## Task: Analyze {{TARGET}}

**Project:** {{PROJECT_NAME}}
**Created:** {{CREATED_AT}}
**Timeout:** 180s default | 300s max

---

## Target

{{FILE_OR_MODULE_TO_ANALYZE}}

---

## Analysis Questions

1. What does this code do?
2. What are the quality issues? (error handling, naming, complexity, security)
3. What should be improved?
4. How would you refactor it?

---

## Constraints

- Read the actual code
- Be specific — cite line numbers, function names
- Rate quality: Good / Acceptable / Needs Work / Poor
- Provide concrete improvement suggestions

---

## Output Format

```
## Summary
[1-2 sentences on what the code does]

## Quality Rating
[🟢 Good / 🟡 Acceptable / 🟠 Needs Work / 🔴 Poor]

## Issues Found

### [Issue 1]
- Location: {file:line or function name}
- Problem: {specific issue}
- Severity: [High / Medium / Low]
- Suggestion: {how to fix}

### [Issue 2]
[...]

## Recommendations
[Top 3 improvements with rationale]

## Code If Refactoring
[Show refactored version if applicable]
```

**Do not write to disk.** Report analysis in your response. Orchestrator writes to file.

---

*Template: memory/templates/subagent-code-analysis.md*
