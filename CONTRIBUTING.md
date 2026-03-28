# Contributing to OpenClaw Delegation Patterns

## How to Contribute

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/your-feature`)
3. Make your changes
4. Test any scripts with `shellcheck` before submitting
5. Submit a pull request

## Script Standards

- All bash scripts must pass `shellcheck` with zero warnings
- Use `#!/usr/bin/env bash` shebang
- Include usage/help function
- Handle errors explicitly (no `set -e` without trap)

## Protocol Standards

- One concept per protocol file
- Include "When to use" section
- Include "Anti-patterns" section
- Cross-reference related protocols

## Model References

When referencing models, use canonical aliases from PERSONA_SYNC.md:
- `qwen3-coder` (not full model ID)
- `kimik2thinking` (not "kimi-k2-thinking")
- `deepseek32` (not "deepseek-v3.2")

## Filing Issues

When reporting delegation failures, include:
- Model used
- Task description
- Number of tool calls attempted
- Timeout setting
- Error output or behavior observed
