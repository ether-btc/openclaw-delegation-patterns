# Subagent Compaction Resilience

How to ensure subagent results are never lost to compaction, timeout, or delivery failure.

## The Problem

When a subagent runs and its session hits the auto-compaction threshold, the session continues — but **output delivery can fail**. The subagent produces results, the session ends, and the parent orchestrator never receives the completion event.

**What compaction does NOT do:** It does not delete messages. It summarizes older messages into a `compaction` entry. The transcript persists and grows.

**What actually fails:** The completion event from subagent → orchestrator can be lost. If the subagent produced output but never delivered it, that output is orphaned unless we have a recovery mechanism.

## The Failure Mode

```
Subagent Session
    │
    ├─ Phase 1 complete → writes to result sink ✅
    ├─ Phase 2 complete → writes to result sink ✅
    ├─ Final result     → produced but completion event LOST ❌
    │
    └─ Compaction fires (session survives) — not the problem

Orchestrator
    │
    ├─ Spawns subagent
    └─ Waits for completion event... never arrives ❌
```

## The Solution: Result Sink + Transcript Recovery

### Layer 1 — Result Sink (append-only JSONL)

Subagents write incremental results to `results/sink.jsonl`:

```bash
bash $WORKSPACE/scripts/subagent-result-sink.sh \
    --phase "research" \
    --status "complete" \
    --content "findings..."
```

```json
{"phase": "research", "status": "complete", "content": "...", "written_at": "2026-03-25T14:30:00Z"}
{"phase": "final", "status": "final", "content": "...final output...", "written_at": "2026-03-25T14:35:00Z"}
```

**Why it works:** The sink is on the filesystem. Compaction only affects the transcript (model context). The sink persists regardless.

### Layer 2 — Transcript Recovery

If the result sink wasn't written (subagent crashed before sink write), recover from the transcript:

```bash
bash $WORKSPACE/scripts/subagent-recover-transcript.sh \
    ~/.openclaw/agents/main/sessions/<subagent-session-id>.jsonl
```

**Extraction strategy (3 patterns):**
1. Explicit result markers: `Final:`, `Result:`, `Verdict:`, `Summary:`
2. Last assistant message with `stopReason: "stop"` + text content
3. Last assistant message with substantial text (≥100 chars) as fallback

**Important:** Prefer raw JSONL transcript files over `sessions_history` API responses. The API can return truncated output (`truncated: true`).

### Layer 3 — File Write Audit

If both sink and transcript are empty, audit for files the subagent may have written:

```bash
bash $WORKSPACE/scripts/file-write-audit.sh <project_dir>
```

Uses `git log` or `find -newer` to discover files created during the subagent's runtime.

## Transcript Format

### Raw JSONL (`~/.openclaw/agents/main/sessions/<id>.jsonl`)

```json
{"type": "message", "id": "...", "message": {"role": "assistant", "content": [...], "stopReason": "..."}}
{"type": "compaction", "id": "...", "firstKeptEntryId": "..."}
```

**stopReason values:**
- `stop` → session ended naturally (FINAL)
- `toolUse` → assistant made a tool call (NOT final)
- `error` → error occurred
- `aborted` → session aborted

### sessions_history API output (different structure — can be truncated)

```json
{"messages": [...], "truncated": true, "contentTruncated": true, "bytes": 1668}
```

Messages have `role`, `content`, `stopReason`, `__openclaw.id`, `__openclaw.kind`.

## Orchestrator Recovery Flow

```bash
# After subagent completion event (or detected death):
1. Read results/sink.jsonl  → authoritative for completed phases
2. Call sessions_history(subagentSessionKey) → fallback
3. Run file-write-audit.sh  → tertiary fallback
4. Merge and deliver
```

## Critical Discovery: sessions_history Can Truncate

`sessions_history` API can return `truncated: true` — it does NOT always return the full transcript. **Always prefer raw JSONL transcript files** at `~/.openclaw/agents/main/sessions/<id>.jsonl`. These are always complete.

## Scripts

| Script | Purpose |
|--------|---------|
| `subagent-result-sink.sh` | Append-only result writer for subagents |
| `subagent-recover-transcript.sh` | Extract output from transcript JSONL |
| `subagent-safe-recover.sh` | Orchestrator recovery (sink + transcript + audit) |
| `file-write-audit.sh` | Discover files written by subagent |

## Pre-Flight Checklist

Before spawning a subagent:
- [ ] Task prompt includes result-sink instructions
- [ ] `RESULT_SINK_FILE` env var set to `<project>/results/sink.jsonl`
- [ ] Monitor loop is running or polling is set up
- [ ] Recovery script path is known

## Key Rules

1. **Subagent writes sink, orchestrator reads.** Don't reverse this.
2. **Raw transcript > sessions_history.** Always use the JSONL file when available.
3. **sink is authoritative for completed phases.** Transcript is authoritative for partial in-flight work.
4. **Compaction is benign.** The session survives and continues. The risk is delivery failure.
