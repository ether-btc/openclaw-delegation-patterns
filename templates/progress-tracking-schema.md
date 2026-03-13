# Progress Tracking Schema

JSON schema for progress files with state machine: todo → in-progress → complete.

## Overview

Progress tracking enables reliable status monitoring across delegation tasks. This schema defines a standardized format for progress files.

## State Machine

```
┌──────────┐    Start     ┌─────────────┐    Complete    ┌──────────┐
│   TODO   │ ──────────→ │ IN_PROGRESS │ ────────────→ │ COMPLETE │
└──────────┘              └─────────────┘               └──────────┘
                              ↑                              │
                              │         Checkpoint         │
                              └────────────────────────────┘
                                    (can resume)
```

## JSON Schema

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Task Progress",
  "type": "object",
  "required": ["task", "status", "updated"],
  "properties": {
    "task": {
      "type": "string",
      "description": "Task name or description"
    },
    "status": {
      "type": "string",
      "enum": ["TODO", "IN_PROGRESS", "COMPLETED", "FAILED", "CHECKPOINTED"],
      "description": "Current state in the workflow"
    },
    "updated": {
      "type": "string",
      "format": "date-time",
      "description": "ISO8601 timestamp of last update"
    },
    "version": {
      "type": "integer",
      "default": 1,
      "description": "Schema version"
    },
    "progress": {
      "type": "object",
      "properties": {
        "phase": {
          "type": "string",
          "description": "Current phase name"
        },
        "completed": {
          "type": "integer",
          "minimum": 0,
          "description": "Number of completed items"
        },
        "total": {
          "type": "integer",
          "minimum": 0,
          "description": "Total number of items"
        },
        "percent": {
          "type": "integer",
          "minimum": 0,
          "maximum": 100,
          "description": "Percentage complete"
        }
      }
    },
    "eta": {
      "type": "object",
      "properties": {
        "started": {
          "type": "string",
          "format": "date-time",
          "description": "When task started"
        },
        "estimated": {
          "type": "string",
          "format": "date-time",
          "description": "Estimated completion time"
        }
      }
    },
    "lastActivity": {
      "type": "object",
      "properties": {
        "time": {
          "type": "string",
          "format": "date-time"
        },
        "step": {
          "type": "string",
          "description": "Step name"
        },
        "details": {
          "type": "string",
          "description": "Brief description"
        }
      }
    }
  }
}
```

## Example Progress File

```json
{
  "task": "Implement user authentication",
  "status": "IN_PROGRESS",
  "updated": "2026-03-11T14:30:00Z",
  "version": 1,
  "progress": {
    "phase": "Writing auth module",
    "completed": 2,
    "total": 5,
    "percent": 40
  },
  "eta": {
    "started": "2026-03-11T14:00:00Z",
    "estimated": "2026-03-11T15:00:00Z"
  },
  "lastActivity": {
    "time": "2026-03-11T14:30:00Z",
    "step": "Writing login function",
    "Details": "Implementing password verification"
  }
}
```

## State Transitions

| From | To | Trigger |
|------|----|---------|
| TODO | IN_PROGRESS | Task started |
| IN_PROGRESS | COMPLETED | Task finished successfully |
| IN_PROGRESS | FAILED | Task failed |
| IN_PROGRESS | CHECKPOINTED | Mid-task checkpoint saved |
| CHECKPOINTED | IN_PROGRESS | Task resumed |
| FAILED | IN_PROGRESS | Task retry |

## File Naming Convention

```
progress-[task-name].json
```

Example: `progress-auth-module.json`

## Orchestrator Responsibility

The **orchestrator** (main agent) owns progress files:
- Creates initial TODO state
- Updates to IN_PROGRESS when spawning
- Updates to COMPLETED/FAILED when done
- Subagents report activity; orchestrator updates

---

## Related Documents

- [delegation-prompt.md](delegation-prompt.md) - Spawn template
- [orchestrator-pattern.md](../docs/orchestrator-pattern.md) - Core pattern
