# PIPELINE RUNNER — Retry & Escalation Logic

This document defines how the Coordinator manages the feedback loop when agents fail.

## Core Rule

**Never fix bad output. Diagnose, reset, fix, re-run.**

When any stage fails, the output is DISCARDED. The fix goes into the INPUTS (spec, task description, context), and the pipeline re-runs from the appropriate stage.

## Retry Flow

```
Task assigned
    │
    ▼
┌─ SCOUT writes spec ◄──────────────────────┐
│       │                                     │
│       ▼                                     │
│  BUILDER implements                         │
│       │                                     │
│       ▼                                     │
│  GATEKEEPER (lint/type/test)                │
│       │                                     │
│       ├── FAIL → feed errors to Scout ──────┘  (attempt++)
│       │                                     
│       ▼                                     
│  REVIEWER checks diff                      │
│       │                                     │
│       ├── REJECT → feed reasons to Scout ───┘  (attempt++)
│       │                                     
│       ▼                                     
│  QA writes & runs tests                    │
│       │                                     │
│       ├── FAIL → feed failures to Scout ────┘  (attempt++)
│       │
│       ▼
│  ✅ MERGE
└──────────
```

## Attempt Tracking

Each task tracks:
```json
{
  "taskId": "task-001",
  "description": "Add vendor signup endpoint",
  "attempts": [
    {
      "attempt": 1,
      "scout": { "status": "complete", "specFile": "specs/task-001-v1.md" },
      "builder": { "status": "complete", "branch": "task/task-001-v1" },
      "gatekeeper": { "status": "pass" },
      "reviewer": { "status": "rejected", "reasons": ["..."] },
      "qa": null
    },
    {
      "attempt": 2,
      "scout": { "status": "complete", "specFile": "specs/task-001-v2.md" },
      "builder": { "status": "complete", "branch": "task/task-001-v2" },
      "gatekeeper": { "status": "pass" },
      "reviewer": { "status": "approved" },
      "qa": { "status": "pass", "tests": 7 }
    }
  ],
  "maxAttempts": 3,
  "status": "merged"
}
```

## 3-Strike Rule

After **3 failed attempts** at the same stage for the same task:

1. **STOP** the pipeline for this task
2. **Compile a report** for Rob containing:
   - Original task description
   - All 3 spec versions (what changed each time)
   - All 3 rejection/failure reasons
   - Pattern analysis: what keeps going wrong?
   - Coordinator's assessment: is this a task decomposition problem? Missing context? Architecture gap?
3. **Notify Rob** via Slack DM with the report
4. **Wait for Rob's input** before retrying

## What Changes on Retry

### On Gatekeeper Failure:
- Feed the exact error output (lint errors, type errors, test failures) into the Scout's next spec
- Scout adds explicit handling for whatever the gatekeeper caught
- Example: "MyPy error on line 42: Argument 1 has type str, expected int" → Scout adds type annotation requirements to spec

### On Reviewer Rejection:
- Feed the reviewer's rejection reasons (with file:line references) into the Scout
- Scout updates the spec to explicitly address each rejection point
- The NEW spec includes a "Previous Rejection" section so the builder knows what to avoid

### On QA Failure:
- Feed the failing test details (expected vs actual, tracebacks) into the Scout
- Scout updates the spec's acceptance criteria to be more precise
- Scout may add edge cases that were missed

## Anti-Pattern: DO NOT

- ❌ Ask the builder to "fix" the code from the last attempt
- ❌ Manually patch the output to pass review
- ❌ Lower quality standards to get a pass
- ❌ Skip review or QA "just this once"
- ❌ Re-run the same spec hoping for a different result

## Escalation Message Format

When notifying Rob after 3 strikes:

```
🚨 Pipeline paused — task-001: "Add vendor signup endpoint"

3 attempts failed at [STAGE].

**Attempt 1:** [rejection reason summary]
**Attempt 2:** [rejection reason summary]  
**Attempt 3:** [rejection reason summary]

**Pattern:** [what keeps going wrong]
**My assessment:** [coordinator's diagnosis]

Options:
1. I can try with different task decomposition
2. This might need architectural guidance from you
3. [other suggestions]

Full reports: [link to spec files]
```
