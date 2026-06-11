---
name: "agent-implement"
description: "The pounce — reads plan.md and dispatches each independent task batch as parallel cats, each one focused only on its own prey (task acceptance criteria, architecture, and relevant files)"
compatibility: "Requires agent-plan to be run first"
metadata:
  author: "catconnect"
  version: "2.0.0"
---

## How Cats Pounce

A cat doesn't think about the whole mouse while pouncing on the tail. It focuses entirely on the part in front of it.

`agent-implement` works the same way: each task gets its own cat with only the context it needs — not the full plan, not other tasks' code, not the entire codebase. One cat, one task, complete focus.

**Why one cat per task:**
- Each task cat's context window contains only its acceptance criteria and relevant files — no irrelevant API surface to hallucinate against
- Parallel dispatch of independent tasks reduces total wall-clock time proportionally to concurrency
- Failures are isolated — one cat missing doesn't cascade to the rest of the hunt

## User Input

```text
$ARGUMENTS
```

Feature name from `$ARGUMENTS`. If empty, detect from the most recently modified `docs/tasks/*/plan.md`.

## Pre-Pounce Checks

1. Find `docs/tasks/<feature>/plan.md` — if missing: ERROR "No hunt plan found. Run `/agent-plan <feature>` first."
2. Read `plan.md` to load execution batches
3. Identify the **current batch**: first batch containing at least one incomplete task
4. A task is complete when its spec's `tasks.md` marks it `[x]`

---

## The Hunt Loop

Repeat for each batch until all prey is caught.

### Dispatch: Parallel Cat Batch 🐱

For each task in the current batch, spawn one cat simultaneously (parallel `Agent` calls in a single response).

**Per-task cat prompt:**

```
You are a hunter cat with one task to complete.

Task: <task.slug>
Territory: <task.spec>
Size: <task.size>
Your prey: <task.description>

Sniff these files before writing any code:
- docs/design/<feature>/<task.spec>/architecture.md  ← your territory's architecture
- docs/specs/<feature>/<task.spec>/requirements.md   ← your territory's requirements
- <each path in task.files_to_touch — read current state before touching>

Your acceptance criteria — verify each explicitly before reporting the hunt complete:
<task.acceptance_criteria as a checklist>

Rules:
- Touch only the files listed in files_to_touch — do not wander into other territories
- Read before writing — follow existing patterns, naming, and style
- Do not add abstractions, error handling, or features not required by your acceptance criteria
- Write focused tests for the business rules your task introduces
- If you find a conflict or a missing dependency, report it — do not silently work around it

After the pounce:
1. Run the most relevant test or build command available
2. Report:
   - Files touched (list)
   - Command run and output summary
   - Acceptance criteria: each one marked PASS or FAIL with one-line evidence
3. If any criterion is FAIL or UNCLEAR, describe the gap — do not declare the hunt complete
```

**Never pass** to cats: other tasks' code, the full plan, or file contents (cats sniff files themselves).

### Quality Check per Cat 🔍

After each cat reports, verify:
- [ ] All acceptance criteria explicitly PASS or FAIL (not "assumed" or skipped)
- [ ] Files touched match `task.files_to_touch` — flag territory violations
- [ ] No new lint or type errors (cat must include run output)
- [ ] Tests were run, not just written

**If a cat fails**: re-dispatch with the failing criteria listed and a note on what was observed. Maximum 2 correction rounds before pausing and asking the user what to do.

### Advance 🐾

After all cats in the current batch pass quality:

1. Update each spec's `tasks.md` — mark completed tasks `[x]`
2. Move to the next batch
3. Repeat until all prey is caught

---

## After the Hunt

When all batches are done:

1. Run the full test suite
2. Run linter and type checker
3. Read `docs/specs/<feature>/*/requirements.md` and verify every acceptance criterion against the actual implemented code
4. Declare the hunt complete

---

## The Nine Lives Check (Quality Gate)

```
## Implementation Quality Score: [X]/100

### Code Quality (40 pts)
- [ ] Follows existing territory conventions (10)
- [ ] No unintended border crossings (10)
- [ ] No security vulnerabilities introduced (10)
- [ ] Tests cover new business rules (10)

### Verification (30 pts)
- [ ] Tests pass (10)
- [ ] Linter/type check passes (10)
- [ ] No regressions in existing tests (10)

### Traceability (30 pts)
- [ ] Every acceptance criterion explicitly verified PASS/FAIL (15)
- [ ] All task docs marked [x] (15)
```

**Threshold**: 80/100 — below this, failing cats go back for another round. Maximum 3 rounds before escalating to user.

---

## Output

Report to user:
- 🎯 Prey caught: N / total tasks
- 🐾 Files touched: [list]
- 🧪 Test results: pass/fail summary
- 😺 Acceptance criteria: per territory, how many verified
- ⚠️ Remaining issues (if any)
- 🚀 Next: code review or deploy
