# Research Delegation Example

A real-world example of delegating research tasks to a subagent in OpenClaw.

## Scenario

You need to research the current state of AI coding assistants and their pricing models for a project decision.

## Delegation Setup

### Task Definition
```
Topic: AI Coding Assistants - Pricing & Features Comparison
Scope: Claude, GPT-4, Cursor, Windsurf, Amazon Q
Output: research/ai-coding-assistants.md
```

### Model Selection
| Factor | Choice |
|--------|--------|
| Task type | Research |
| Depth | Comprehensive |
| Model | kimik2thinking or qwen3a22b |

### Prompt
```
Research AI coding assistants. For each (Claude, GPT-4, Cursor, Windsurf, Amazon Q):
- Current pricing (monthly/annual)
- Key features
- Target audience
- Recent updates (2025-2026)

Format as markdown table, then summarize pros/cons.
Output to: research/ai-coding-assistants.md
```

## Execution

### Main Agent Actions
1. Spawn subagent with task
2. Monitor for completion (progress file or wait)
3. Receive results
4. Update workspace files
5. Report to user

### Subagent Actions
1. Research each tool via web search
2. Compile findings
3. Write output file
4. Report completion

## Results

### Expected Output (research/ai-coding-assistants.md)

```markdown
# AI Coding Assistants - Pricing & Features

| Tool | Pricing | Key Features | Target |
|------|---------|--------------|--------|
| Claude | $20-35/mo | Sonnet 4.5, artifacts | Pro devs |
| GPT-4 | $20/mo | Codex, ChatGPT | General |
| Cursor | $10-20/mo | IDE integration | Devs |
| Windsurf | $15/mo | AI pairs | Teams |
| Amazon Q | $15-25/mo | AWS integration | Enterprise |

## Summary
[Pros/Cons for each]
```

## Key Patterns Used

1. **Atomic Task** - Single research objective
2. **Clear Output** - Specific file path
3. **Model Selection** - Research-focused model
4. **Format Guidance** - Markdown table specified

## Common Pitfalls

| Pitfall | Prevention |
|---------|------------|
| Too broad | Specify exact tools to research |
| No format | State output format in prompt |
| Vague output | Give exact file path |

## Related

- [Delegation Fundamentals](../docs/delegation-fundamentals.md)
- [Subagent Handoff Protocol](../docs/subagent-handoff-protocol.md)
- [Orchestrator Pattern](../docs/orchestrator-pattern.md)
