# Subagent Research Template

**Use for:** Fact-finding, comparisons, pattern analysis, investigating topics.

---

## Task: Research: {{TOPIC}}

**Project:** {{PROJECT_NAME}}
**Created:** {{CREATED_AT}}
**Timeout:** 180s default | 300s max

---

## Objective

{{WHAT_TO_FIND_OR_DETERMINE}}

---

## Research Questions

1. {{specific question 1}}
2. {{specific question 2}}
3. {{specific question 3}}

---

## Constraints

- Use web search if needed
- Cite sources
- Don't speculate — state what you know vs what you infer
- Keep total findings under 800 words

---

## Output Format

Provide findings in this structure so the orchestrator can write to disk:

```
## Research Summary
[2-3 sentence overview]

## Finding 1: [Topic]
[Detail with source if applicable]

## Finding 2: [Topic]
[Detail with source if applicable]

## Finding 3: [Topic]
[Detail with source if applicable]

## Open Questions
[Any remaining uncertainties]

## Recommended Next Steps
[If any]
```

**Do not write to disk.** Report findings in your response. Orchestrator writes to file.

---

*Template: memory/templates/subagent-research.md*
