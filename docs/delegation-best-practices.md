# Delegation Best Practices Research

## Introduction

Effective delegation in AI agent systems requires understanding the strengths and optimal use cases for each specialized model. This research provides a framework for delegating tasks to different AI models.

## General Delegation Principles

### Task Assessment and Routing

1. **Capability Matching**: Match task complexity and domain to model strengths
2. **Cost Considerations**: Use appropriate tier for the task
3. **Context Requirements**: Match language, latency, and quality needs

### Implementation Patterns

1. **Handoff Pattern**: Dynamic delegation where agents assess tasks and transfer to specialists
2. **Tool Usage Pattern**: Using agents as specialized tools for bounded subtasks
3. **Context Isolation Pattern**: Delegating complex multi-step tasks while maintaining focus

### ⚠️ Subagent Prompt Rules (MANDATORY)

**NEVER include tool call syntax in subagent prompts.**
- Plain language task descriptions ONLY
- Main agent handles ALL file operations (read, write, edit)
- Including tool examples causes confusion → 100% failure rate

**Example WRONG:**
```
Use functions.read to read AGENTS.md, then functions.write to update...
```

**Example CORRECT:**
```
Review AGENTS.md and summarize the delegation matrix.
```

## Best Practices by Model Type

### Free Models
- Summarization
- Simple question answering
- Basic text processing
- Quick information extraction

### Budget Models
- Fast code generation
- Simple debugging
- Quick analysis
- Translation

### Standard Models
- Complex code generation
- Code review
- Multi-file refactoring
- Detailed analysis

### Premium/Reasoning Models
- Complex debugging
- System design
- Mathematical reasoning
- Chain-of-thought tasks
- Critical outputs

## Optimization Strategies

### Cost Control
- Route tasks to appropriately priced models
- Use free models for simple tasks
- Reserve premium for complex tasks

### Performance Tuning
- Match model capabilities to task requirements
- Use fallback models when primary fails

### Error Handling
- Implement fallback mechanisms
- Classify errors appropriately
- Use checkpoint/rollback

## Conclusion

Effective delegation involves:
1. Matching task requirements to model capabilities
2. Managing costs appropriately
3. Implementing proper failsafe mechanisms
4. Monitoring and optimizing over time

---

*Part of AI Agent Project Tracker*
