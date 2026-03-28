# Subagent Delegation Protocol — Avoiding Context Window Exhaustion

## Authority
This protocol supplements **DELEGATION_CORE.md** (canonical for file ownership, timeout escalation) and **ORCHESTRATOR_VERIFY.md** (mandatory post-completion verification). Where conflicts exist, DELEGATION_CORE.md wins.

## Prerequisite
Orchestrator MUST run `pre-delegation-checklist.sh` before every delegation. Blocking on failure.

## The Problem
qwen3-coder subagents compact when their context window fills faster than the session can process tool results. This happens because:
1. Bootstrap files (AGENTS.md, SOUL.md, etc.) are injected into every subagent session
2. Multiple parallel tool calls (read, exec) stack up simultaneously
3. The subagent prompt competes for space with workspace context

## The Core Principle
**Lean prompt, sequential work, result sink first.**

## File Ownership Rule
Subagents write **exclusively** to `results/<project>/`. Orchestrator is sole writer to all other paths. Checkpoints are pre-created by orchestrator; subagent receives checkpoint ID in task prompt.

## Timeout Escalation
See **DELEGATION_CORE.md** for canonical rules: First timeout → 2x retry. Second timeout → orchestrator completes task directly.

## Post-Completion
After completion announcement, orchestrator runs `orchestrator-verify.sh` before accepting results.

## qwen3-coder Subagent Rules (Mandatory)

### 1. Minimal Bootstrap
When spawning a qwen3-coder subagent, the workspace context injection competes directly with the task. Use `SKIP_BOOTSTRAP=1` in the task prompt OR spawn with a minimal working directory that doesn't include the full workspace bootstrap.

**Pattern:**
```
Set workspace to a clean temp dir, not ~/.openclaw/workspace
OR: explicitly tell the subagent to ignore workspace context files
```

### 2. One Script Per Subagent (Maximum)
Never assign more than 1 script per subagent. qwen3-coder's context fills fast. One lean subagent beats one bloated one.

**Wrong:** "Audit these 7 scripts"
**Right:** "Audit pre-delegation-checklist.sh only"

### 3. Sequential Waves, Not Parallel Flood
- Maximum 4 parallel subagents at once
- Wait for all 4 to complete before spawning the next wave
- If any subagent in a wave compacts, the whole wave should be re-spawned with a LEANER prompt

### 4. Result Sink Before Final Response (MANDATORY)
The subagent MUST write to the result sink BEFORE its final text response. This ensures findings survive compaction.

```bash
bash scripts/subagent-result-sink.sh \
    --phase "wave1-script-audit" \
    --status "final" \
    --content '{"script":"name.sh","findings":"..."}'
```

### 5. Prompt Structure
Keep the subagent prompt under 800 tokens. Include:
- Exact file path to operate on
- Step-by-step instructions (read → exec → exec → result sink)
- Nothing else

**Template:**
```
## Task: Audit <script-name>

Working dir: `~/.openclaw/workspace`

Step 1: read <script-path>
Step 2: exec shellcheck <script-path>
Step 3: exec elegance-check.sh --files <script-path> --min-score 70
Step 4: evaluate 5 criteria
Step 5: write findings to result sink (MANDATORY)

Write to result sink BEFORE final response.
```

### 6. Timeout Selection
- Single script audit: 60-90s
- If subagent is still running at 45s, it's likely stacking tool calls — let it finish
- If it completes in under 30s, the prompt was too lean (could handle more)

### 7. Context Drain Indicators
Watch for these compaction warning signs:
- Tool results being truncated
- Subagent says it "just started"
- Runtime stats show >30s with no output
- Result sink NOT written

### 8. Orchestrator Recovery
If a subagent compacts before delivering:
1. Check the transcript for partial findings
2. If partial: extract what exists, re-spawn with LEANER prompt
3. If empty: just do the work yourself — subagent overhead isn't worth it for small tasks

## Summary
qwen3-coder subagents are viable but require discipline: one-at-a-time, lean prompts, result sink first, sequential waves of ≤4.
