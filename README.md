# Development Pipeline — Anti-Slop Agent System

A project-agnostic multi-agent development pipeline built on the anti-slop principles:
**"Never fix bad output. Diagnose, reset, fix, re-run."**

## Architecture

```
┌─────────────┐
│ COORDINATOR │  (AVA/Opus) — Decomposes epics into tasks
│   (main)    │
└──────┬──────┘
       │ assigns task
       ▼
┌─────────────┐
│    SCOUT    │  (Claude Sonnet) — Writes detailed specs
│             │  Line numbers, file paths, code snippets, exact scope
└──────┬──────┘
       │ spec document
       ▼
┌─────────────┐
│   BUILDER   │  (Claude Code / Sonnet) — Implements the spec
│             │  One agent, one task, one worktree. No inferring.
└──────┬──────┘
       │ committed code (no push)
       ▼
┌─────────────┐
│ GATEKEEPER  │  (Automated — no LLM) — Linting, types, tests
│             │  ruff, mypy, pytest, eslint, svelte-check
└──────┬──────┘
       │ pass/fail
       ▼
┌─────────────┐
│  REVIEWER   │  (Codex / GPT) — Reviews diff against spec
│             │  Different LLM = different blind spots
└──────┬──────┘
       │ approve / reject with reasons
       ▼
┌─────────────┐
│     QA      │  (Codex / GPT) — Writes & runs tests
│             │  Validates behavior matches spec
└──────┬──────┘
       │ pass → merge to main
       ▼
    ✅ DONE  or  🔄 REJECT → diagnose, fix spec, re-run from scratch
```

## Key Principles
1. **One agent, one task, one prompt** — focused agents produce better results
2. **Per-agent isolation** — git worktrees, never share a checkout
3. **Different LLMs for build vs review** — Claude builds, GPT reviews
4. **Never fix bad output** — diagnose root cause, reset, re-run
5. **Specs leave NO ambiguity** — line numbers, code snippets, exact file paths
6. **Quality gates are automated** — no LLM opinions, just pass/fail
7. **Hard blocks** — builder can't push, reviewer can't edit, scout can't code
