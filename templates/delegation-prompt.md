# Delegation Prompt Template

Template for spawning subagents with clear, consistent instructions.

## When to Use

Use this template every time you spawn a subagent to ensure consistent, reliable delegation.

## Template

```markdown
## Task: [Brief one-line description]

## Context
[Provide relevant background - what has led to this task, what's already been done, constraints to consider]

## Your Role
You are working as a specialist assistant. I am your orchestrator/project lead.

## What To Do
1. [Specific action 1]
2. [Specific action 2]
3. [Specific action 3]

## What NOT To Do
- Do NOT write to progress files yourself
- Do NOT update project tracking files
- Do NOT modify orchestration state
- Do NOT try to coordinate with other subagents
- Do NOT include tool call syntax in your response

Your job is execution and reporting. MY job is tracking and coordination.

## Expected Output
[Describe what you expect back - code, analysis, findings, etc.]

## Report Format
When complete, report back:

```markdown
## Task Complete

**Work Done:** [Brief description of what you accomplished]

**Results:** [Your findings, data, or outputs]

**Files Created:** [List any code/content - I will create the files]

**Recommendations:** [Any suggestions or next steps]
```

## Timeout
[Specify timeout based on task complexity]

## Example Usage

### Coding Task
```markdown
## Task: Implement user authentication module

## Context
Building a new feature for the project. Need a basic auth module with login/logout.

## Your Role
You are a coding specialist.

## What To Do
1. Create auth.py with login/logout functions
2. Include password hashing using bcrypt
3. Add session management

## Expected Output
Python code for the auth module.

## Timeout: 180 seconds
```

### Research Task
```markdown
## Task: Research caching strategies

## Context
Optimizing performance for the main application. Need to understand best practices.

## Your Role
You are a research specialist.

## What To Do
1. Identify 3-5 caching strategies suitable for web apps
2. Compare pros/cons of each
3. Recommend best approach for our use case

## Expected Output
Summary with recommendations.

## Timeout: 120 seconds
```

---

## Key Principles

1. **No tool syntax** - Don't tell subagent to use `write`, `read`, etc.
2. **Clear scope** - Specific actions, not vague goals
3. **Expected output** - Define what "done" looks like
4. **Orchestrator handles files** - Subagent provides content, orchestrator creates files
