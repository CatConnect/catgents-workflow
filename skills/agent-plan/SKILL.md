---
name: "agent-plan"
description: "Plan a feature by decomposing it into bounded specs, then dispatching each spec to a dedicated subagent — requirements, architecture, and task breakdown run in parallel with isolated context per spec"
compatibility: "Requires agent-init to be run first"
metadata:
  author: "catconnect"
  version: "2.0.0"
---

## Design Principles

**Parallel Bounded-Context Planning**: instead of a single agent analyzing the whole feature, this skill:

1. Decomposes the feature into N independent **specs** (bounded contexts)
2. Dispatches each spec to a subagent via the `Agent` tool with **minimal, isolated context**
3. Runs independent specs **in parallel**; specs with dependencies sequence after their parents
4. **Synthesizes** all outputs into a unified, cross-spec plan

**Why this works:**

- *Lost in the Middle* (Liu et al., 2023): LLM performance degrades for information in the middle of long contexts — isolated subagent context keeps relevant information at the top of the window, not buried
- *AutoGen* (Wu et al., 2023): specialized agents with focused roles outperform a single generalist agent on complex multi-step tasks
- DDD *Bounded Context*: each spec maps to a single domain concern with explicit interfaces — prevents semantic drift and error cascade across subagents
- *Minimal Context Principle*: each subagent receives only what it needs to do its job; it reads files itself rather than receiving content dumps

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Pre-Execution Checks

1. Verify `.agents/config.json` exists — run `/agent-init` if missing
2. Parse feature description from `$ARGUMENTS`
3. If empty: ERROR "No feature description provided"

---

## Clarification Protocol (mandatory throughout all phases)

**Never assume architecture. Always ask.**

Before making any decision that involves technology, design patterns, data structures, or tradeoffs, the orchestrator must surface the question to the user and wait for an answer. This applies at every phase.

**Examples of decisions that require user confirmation:**
- Which database, framework, library, or third-party service to use
- Whether to create a new table/collection or extend an existing one
- REST vs. event-based vs. GraphQL communication between specs
- Whether a spec should be synchronous or async
- Which existing code patterns or modules to follow
- Whether to break backward compatibility
- Any tradeoff between performance, simplicity, and correctness

**How to surface questions:**
1. After each subagent completes its output, read its `## Open Questions` section
2. Collect all open questions across all specs in the current phase
3. Present them to the user grouped by spec **before** proceeding to the next phase:

```
Before I proceed to [next phase], I need your input on:

**spec-<id>: <concern>**
- Q1: <question — one concrete tradeoff or decision>
- Q2: ...

**spec-<id>: <concern>**
- Q3: ...

Please answer each before I continue.
```

4. Incorporate the user's answers into the subagent prompts for the next phase as explicit constraints

**Rule**: if a subagent makes an architectural assumption (e.g., "I'll use Redis for the queue") without evidence it exists in the project, flag it as an open question instead of accepting it.

---

## Phase 0: Spec Decomposition

**Goal**: Identify the minimal set of bounded specs that cover the feature.

**Decomposition rules:**
- Each spec addresses a single domain concern (data model, API endpoint, UI component, auth rule, background job, infra)
- A spec's public contract (inputs/outputs) is the only coupling point with other specs — no shared internals
- Each spec can be implemented and verified independently
- Maximum 6 specs per feature; if more are needed, ask the user to split the feature
- If the feature naturally fits a single focused scope, use 1 spec

**Write decomposition to `.agents/<feature-slug>/decomposition.json`:**

```json
{
  "feature": "<feature-slug>",
  "description": "<one-sentence summary>",
  "specs": [
    {
      "id": "spec-<slug>",
      "domain": "<data|api|ui|auth|job|infra>",
      "concern": "<one sentence: exactly what this spec covers>",
      "depends_on": ["<spec-id>"],
      "contract": {
        "inputs": ["<what this spec consumes from other specs — contracts only, not internals>"],
        "outputs": ["<what this spec exposes for other specs to consume>"]
      },
      "context_files": ["<paths to most relevant existing files — max 5>"]
    }
  ]
}
```

After writing the decomposition, present the spec list to the user in a compact table and proceed without waiting for confirmation unless there is genuine ambiguity.

---

## Phase 1: Requirements — Parallel Subagent Dispatch

**Batching rule**: group specs into execution batches where no spec in a batch depends on another spec in the same batch. Within each batch, dispatch all specs **simultaneously** using parallel `Agent` tool calls (multiple Agent calls in a single response).

**For each spec, spawn one Agent with exactly this prompt structure (substitute values):**

```
You are a requirements analyst for a single bounded spec.

Feature context: <feature description from $ARGUMENTS>
Your spec ID: <spec.id>
Your spec concern: <spec.concern>
Your spec domain: <spec.domain>
Inputs this spec consumes from other specs: <spec.contract.inputs>
Outputs this spec must expose: <spec.contract.outputs>

Read these existing files to understand current code before writing:
<spec.context_files, one per line — if a file does not exist, skip it>

Your task — stay strictly within your spec's concern:
1. Extract functional requirements (WHAT, not HOW)
2. Write user stories in format: As a <role>, I want <action> so that <value>
3. Define acceptance criteria — each must be binary (pass/fail), specific, observable
4. List constraints: technical, security, performance, regulatory
5. Flag EVERY open question or architectural assumption as an explicit item in ## Open Questions — never silently decide; if you don't know, ask

Write output to: docs/specs/<feature>/<spec.id>/requirements.md

Output format:
# Requirements: <spec.concern>
## User Stories
## Functional Requirements
## Acceptance Criteria
## Constraints
## Open Questions
```

**Do NOT include** in subagent prompts: other specs' requirements, file contents (subagent reads directly), or instructions to modify files outside `docs/specs/<feature>/<spec.id>/`.

**After all subagents in a batch complete**, read each output and verify:
- [ ] Requirements are testable — binary assertions, not vague goals like "should be fast"
- [ ] No HOW — no implementation decisions embedded in requirements
- [ ] Acceptance criteria are specific and measurable
- [ ] Scope is bounded to this spec's concern only
- [ ] Open questions are explicit items, not silent assumptions

If a spec fails quality: re-dispatch that spec's subagent with a correction note before advancing. Maximum 2 correction rounds per spec before escalating to user.

---

## Phase 2: Architecture — Parallel Subagent Dispatch

Same batching and parallelism rules as Phase 1. Run after Phase 1 is fully complete.

**For each spec, spawn one Agent:**

```
You are a system architect for a single bounded spec.

Read these files before designing — all reads first, then design:
- docs/specs/<feature>/<spec.id>/requirements.md  ← your spec's requirements
- <any relevant existing architecture docs in docs/design/>
- <spec.context_files>

Your spec: <spec.concern>
Other specs' public contracts (interfaces only — do not redesign their internals):
<for each spec.id in this spec's depends_on:>
  - <spec.id>: outputs = <spec.contract.outputs>

Your task — design components for THIS spec only:
1. List components with their responsibilities
2. Define data models: fields, types, constraints, relations, required migrations
3. Define this spec's public API contract: routes, events, or exports it exposes
4. Map integration points: how this spec consumes other specs' contracts
5. Document key technical decisions with rationale (why, not just what)
6. Security and performance considerations specific to this spec

CRITICAL: if you encounter a decision involving technology choice, design pattern, or tradeoff — DO NOT decide. Add it to ## Open Questions with a clear description of the options and tradeoffs. The user will answer before this architecture is accepted.

Write output to: docs/design/<feature>/<spec.id>/architecture.md

Output format:
# Architecture: <spec.concern>
## Components
## Data Model
## Public API Contract
## Integration Points
## Technical Decisions
## Security & Performance
## Open Questions
```

**Quality check per subagent output:**
- [ ] All acceptance criteria from Phase 1 are covered by at least one component
- [ ] Data model has no TBD fields — every field has a type and constraint
- [ ] Integration points reference only other specs' `contract.outputs`, not their internals
- [ ] Every technical decision includes a rationale

---

## Phase 3: Task Breakdown — Parallel Subagent Dispatch

Same batching rules. Run after Phase 2 is fully complete.

**For each spec, spawn one Agent:**

```
You are a technical planner for a single bounded spec.

Read these files first:
- docs/design/<feature>/<spec.id>/architecture.md  ← your spec's architecture
- docs/specs/<feature>/<spec.id>/requirements.md   ← your spec's requirements

Your task: break this spec's architecture into atomic implementation tasks.

Rules:
- Each task must be 1–4 hours of focused coding work (S = < 1h, M = 1–4h; split any L)
- Order tasks by internal dependency (a task that uses an interface must come after the task that creates it)
- Each task has at least 2 binary acceptance criteria
- Tasks are scoped to files listed in files_to_touch — do not leave it empty
- Each task references its spec ID for cross-spec traceability

Write output to: docs/tasks/<feature>/<spec.id>/tasks.md

Repeat this block for each task:
## task-<n>: <slug>
- spec: <spec.id>
- size: S | M  (never L — split L tasks)
- depends_on: [<task-slugs within this spec>]
- description: <what to implement — concrete, not vague>
- files_to_touch: [<file paths>]
- acceptance_criteria:
  - [ ] <binary check>
  - [ ] <binary check>
```

**Quality check:**
- [ ] No L-sized tasks (every L must be split before this phase passes)
- [ ] Every task has at least 2 acceptance criteria
- [ ] Dependencies form a DAG — verify there are no cycles
- [ ] All architecture components from Phase 2 are covered by at least one task

---

## Phase 4: Cross-Spec Synthesis

After all Phase 3 subagents complete:

1. Read all `docs/tasks/<feature>/*/tasks.md`
2. Build a cross-spec dependency graph: a task in spec-B that consumes spec-A's API contract must sequence after the task in spec-A that creates that contract
3. Topologically sort all tasks into execution batches
4. Write unified plan to `docs/tasks/<feature>/plan.md`:

```markdown
# Execution Plan: <feature>

## Specs
| ID | Domain | Concern |
|----|--------|---------|

## Execution Batches
Each batch lists tasks that can run in parallel. A batch starts only when all tasks in the previous batch are complete.

### Batch 1
- spec-X / task-1
- spec-Y / task-1

### Batch 2
...

## Cross-Spec Sequencing
| Task | Must complete before |
|------|----------------------|

## Risk Summary
Top risks from open questions across all specs:
1. ...

## Estimate
| Size | Count |
|------|-------|
| S    | N     |
| M    | N     |
| Total tasks | N |
```

---

## Quality Gate

```
## Planning Quality Score: [X]/100

### Completeness (40 pts)
- [ ] All specs have requirements docs (10)
- [ ] All specs have architecture docs (15)
- [ ] All specs have task breakdowns, no L tasks (15)

### Quality (40 pts)
- [ ] Requirements are testable — no vague goals (10)
- [ ] Architecture is complete — no TBD data models (10)
- [ ] Tasks are atomic — M or S only (10)
- [ ] Cross-spec dependencies are resolved in plan.md (10)

### Documentation (20 pts)
- [ ] Unified plan.md produced with execution batches (10)
- [ ] All artifact cross-references are valid paths (10)
```

**Threshold**: 85/100 to report ready for `/agent-implement`

If score < 85: identify failing specs, re-dispatch targeted correction subagents. Maximum 3 correction rounds before escalating to the user with a specific list of unresolved issues.

---

## Output

Report to user:
- Specs decomposed: N
- Per-spec artifacts: `docs/specs/<feature>/`, `docs/design/<feature>/`, `docs/tasks/<feature>/`
- Unified plan: `docs/tasks/<feature>/plan.md`
- Quality Score: [X]/100
- Next step: `/agent-implement <feature>`
