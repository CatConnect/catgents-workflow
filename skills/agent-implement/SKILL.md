---
name: "agent-implement"
description: "Implement planned features by reading plan.md and dispatching each independent task batch to parallel subagents — each subagent receives only its task's acceptance criteria, architecture, and relevant files"
compatibility: "Requires agent-plan to be run first"
metadata:
  author: "catconnect"
  version: "2.0.0"
---

## Design Principles

Same bounded-context philosophy as `agent-plan`: each task gets a subagent with exactly the context it needs. The orchestrator manages sequencing via `plan.md`, dispatches parallel batches, collects outputs, and runs quality gates.

**Why subagents per task:**
- A task subagent's context window contains only its task description, acceptance criteria, and relevant files — not the full plan and not other tasks' code
- This keeps the subagent's attention on its specific acceptance criteria, reducing hallucination on irrelevant API surface
- Parallel dispatch of independent tasks reduces total wall-clock time proportionally to concurrency

## User Input

```text
$ARGUMENTS
```

Feature name is taken from `$ARGUMENTS`. If empty, detect from the most recently modified `docs/tasks/*/plan.md`.

## Pre-Execution Checks

1. Locate `docs/tasks/<feature>/plan.md` — if not found: ERROR "Run `/agent-plan <feature>` first"
2. Read `plan.md` to load execution batches
3. Identify the **current batch**: first batch containing at least one incomplete task
4. A task is complete if its spec's `tasks.md` marks it `[x]`

---

## Execution Loop

Repeat for each batch in order until all batches are complete.

### Dispatch: Parallel Subagent Batch

For each task in the current batch, spawn one Agent simultaneously (parallel calls in a single response).

**Per-task subagent prompt:**

```
You are an implementer for a single atomic task.

Task: <task.slug>
Spec: <task.spec>
Size: <task.size>
Description: <task.description>

Read these files before writing any code:
- docs/design/<feature>/<task.spec>/architecture.md  ← your spec's architecture
- docs/specs/<feature>/<task.spec>/requirements.md   ← your spec's requirements
- <each path in task.files_to_touch — read current state before editing>

Your acceptance criteria (verify each explicitly before reporting done):
<task.acceptance_criteria as a checklist>

Rules:
- Edit only the files listed in files_to_touch; do not touch other files
- Follow existing patterns, naming, and style in the codebase — read before writing
- Do not add abstractions, error handling, or features not required by acceptance criteria
- Write focused tests for the business rules this task introduces
- If you find a conflict with existing code or a missing dependency, report it — do not silently work around it

After implementing:
1. Run the most relevant test or build command available
2. Report:
   - Files changed (list)
   - Command run and output summary
   - Acceptance criteria: for each criterion, state PASS or FAIL with one-line evidence
3. If any criterion is FAIL or UNCLEAR, describe the gap — do not mark the task complete
```

**Do NOT pass** to subagents: other tasks' code, the full plan, or file contents (subagent reads files directly).

### Quality Gate per Task

After each subagent reports, verify:
- [ ] All acceptance criteria are explicitly checked as PASS or FAIL (not assumed or skipped)
- [ ] Files changed match `task.files_to_touch` (flag scope creep)
- [ ] No new lint or type errors were introduced (subagent must report the run output)
- [ ] Tests were run, not just written

**If a task fails quality**: re-dispatch that specific subagent with the failing criteria listed and a note on what was observed. Maximum 2 correction rounds per task before pausing and asking the user how to proceed.

### Advance

After all tasks in the current batch pass quality:

1. Update each spec's `tasks.md` — mark completed tasks `[x]`
2. Move to the next batch
3. Repeat

---

## Completion

When all batches are done:

1. Run the full test suite for the project
2. Run linter and type checker
3. Read `docs/specs/<feature>/*/requirements.md` and verify each acceptance criterion against the implemented code
4. Write final report

---

## Quality Gate

```
## Implementation Quality Score: [X]/100

### Code Quality (40 pts)
- [ ] Follows existing conventions (10)
- [ ] No unintended scope changes (10)
- [ ] No security issues introduced (10)
- [ ] Tests cover new business rules (10)

### Verification (30 pts)
- [ ] Tests pass (10)
- [ ] Linter/type check passes (10)
- [ ] No regressions in existing tests (10)

### Traceability (30 pts)
- [ ] Every acceptance criterion is explicitly verified (15)
- [ ] All task docs updated to [x] (15)
```

**Threshold**: 80/100 to mark implementation complete

If score < 80: identify failing tasks, re-dispatch targeted subagents. Maximum 3 correction rounds before escalating to user.

---

## Output

Report to user:
- Tasks completed: N / total
- Files modified: [list]
- Test results: pass/fail summary
- Acceptance criteria coverage: per spec, how many criteria verified
- Remaining issues (if any)
- Next step: code review or deploy
