---
name: "agent-plan"
description: "Stalk the feature — decomposes it into bounded specs (territories), then dispatches a dedicated cat per spec in parallel for requirements, architecture, and task breakdown"
compatibility: "Requires agent-init to be run first"
metadata:
  author: "catconnect"
  version: "2.0.0"
---

## How Cats Hunt

A cat never charges blindly. It maps the territory, studies the prey from a distance, then pounces at exactly the right moment with complete focus.

`agent-plan` works the same way:

1. **Territorial Mapping** — decompose the feature into N bounded specs (one domain concern per cat)
2. **The Stalk** — dispatch a dedicated cat per spec via the `Agent` tool with minimal, isolated context
3. **Parallel Hunting** — independent specs hunt simultaneously; specs with dependencies wait for their prey
4. **The Pride** — synthesize all outputs into a unified cross-spec plan

**Why one cat per spec:**

- *Lost in the Middle* (Liu et al., 2023): cats don't get distracted by irrelevant scents — isolated context keeps the prey at the top of the window
- *AutoGen* (Wu et al., 2023): specialized hunters outperform a single generalist on complex multi-step tasks
- DDD *Bounded Context*: each cat owns one territory with explicit borders — no territorial disputes, no cross-spec contamination
- *Minimal Context*: each cat sniffs only the files it needs; it reads them itself rather than being handed a content dump

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Pre-Hunt Checks

1. Verify `.agents/config.json` exists — run `/agent-init` if the litter box isn't set up
2. Parse feature description from `$ARGUMENTS`
3. If empty: ERROR "No prey selected. Provide a feature description to hunt."

---

## Clarification Protocol (mandatory throughout all phases) 🔔

**Cats don't assume. Cats ask.**

Before any decision involving technology, design patterns, data structures, or tradeoffs — the orchestrator must surface the question to the user and wait for an answer. Every phase.

**Decisions that always require user confirmation:**
- Which database, framework, library, or third-party service to use
- Whether to create a new table/collection or extend an existing one
- REST vs. event-based vs. GraphQL communication between specs
- Synchronous vs. asynchronous behavior
- Which existing code patterns or modules to follow
- Whether to break backward compatibility
- Any tradeoff between performance, simplicity, and correctness

**How to ask:**

1. After each batch of subagents completes, read each output's `## Open Questions` section
2. Collect all questions across specs from the current phase
3. Present them to the user **before** proceeding to the next phase:

```
🐱 Before I move to [next phase], I need your input:

**spec-<id>: <concern>**
- Q1: <concrete question — one tradeoff or decision>
- Q2: ...

**spec-<id>: <concern>**
- Q3: ...

Please answer each so I can continue the hunt.
```

4. Incorporate the user's answers as explicit constraints in the next-phase subagent prompts

**Rule**: if a cat assumes an architectural decision (e.g., "I'll use Redis for the queue") without evidence it exists in the project, flag it as an open question — don't accept the assumption silently.

---

## Phase 0: Territorial Mapping 🗺️

**Goal**: identify the minimal set of bounded territories that cover the feature.

**Mapping rules:**
- Each spec owns a single domain concern (data model, API endpoint, UI component, auth rule, background job, infra)
- A spec's public contract (inputs/outputs) is the only border crossing between territories — no shared internals
- Each spec can be implemented and verified independently
- Maximum 6 specs per feature; if more are needed, ask the user to split the feature
- If the feature fits a single focused scope, one territory is fine

**Write the map to `.agents/<feature-slug>/decomposition.json`:**

```json
{
  "feature": "<feature-slug>",
  "description": "<one-sentence summary>",
  "specs": [
    {
      "id": "spec-<slug>",
      "domain": "<data|api|ui|auth|job|infra>",
      "concern": "<one sentence: exactly what this cat's territory covers>",
      "depends_on": ["<spec-id>"],
      "contract": {
        "inputs": ["<what this spec consumes from neighboring territories — contracts only>"],
        "outputs": ["<what this spec exposes at its border for others to consume>"]
      },
      "context_files": ["<paths to most relevant existing files — max 5>"]
    }
  ]
}
```

After mapping, show the user a compact table of specs and proceed unless there is genuine ambiguity.

---

## Phase 1: The Stalk — Requirements 🔍

**Batching rule**: group specs so no spec in a batch depends on another in the same batch. Dispatch each batch **simultaneously** via parallel `Agent` calls (multiple calls in a single response).

**For each spec, spawn one cat with this prompt:**

```
You are a requirements scout for a single bounded territory.

Feature context: <feature description from $ARGUMENTS>
Your spec ID: <spec.id>
Your territory: <spec.concern>
Your domain: <spec.domain>
You consume from neighboring territories: <spec.contract.inputs>
You must expose at your border: <spec.contract.outputs>

Sniff these existing files before writing (skip any that don't exist):
<spec.context_files, one per line>

Your hunt — stay strictly within your territory:
1. Extract functional requirements (WHAT, not HOW)
2. Write user stories: As a <role>, I want <action> so that <value>
3. Define acceptance criteria — each must be binary (pass/fail), specific, observable
4. List constraints: technical, security, performance, regulatory
5. Flag EVERY open question or architectural assumption in ## Open Questions
   — never silently decide; if you don't know the answer, ask

Write to: docs/specs/<feature>/<spec.id>/requirements.md

Output format:
# Requirements: <spec.concern>
## User Stories
## Functional Requirements
## Acceptance Criteria
## Constraints
## Open Questions
```

**Never include** in cat prompts: other specs' requirements, file contents (cats read files themselves), or instructions to touch files outside `docs/specs/<feature>/<spec.id>/`.

**After each batch**, read all outputs and verify:
- [ ] Requirements are binary assertions — not vague goals like "should be fast"
- [ ] No HOW — no implementation decisions embedded in requirements
- [ ] Acceptance criteria are specific and measurable
- [ ] Scope is bounded to this territory only
- [ ] Open questions are explicit, not silent assumptions

If a cat fails quality: re-dispatch with a correction note. Maximum 2 rounds before escalating to user.

**Collect all `## Open Questions` and ask the user before proceeding to Phase 2.**

---

## Phase 2: Building the Lair — Architecture 🏗️

Same batching and parallel rules. Run only after Phase 1 questions are answered.

**For each spec, spawn one cat:**

```
You are an architect cat for a single bounded territory.

Read all of these before designing — sniff first, build second:
- docs/specs/<feature>/<spec.id>/requirements.md  ← your territory's requirements
- <any relevant existing architecture docs in docs/design/>
- <spec.context_files>

Your territory: <spec.concern>
Neighboring borders you may consume (interfaces only — do not redesign their internals):
<for each spec.id in this spec's depends_on:>
  - <spec.id>: exposes = <spec.contract.outputs>

User's architectural decisions (MUST follow these — do not override):
<answers the user gave to Phase 1 open questions for this spec>

Design only YOUR territory:
1. List components with their responsibilities
2. Define data models: fields, types, constraints, relations, migrations required
3. Define your border contract: routes, events, or exports you expose
4. Map border crossings: how you consume neighboring specs' contracts
5. Document key decisions with rationale (why, not just what)
6. Security and performance considerations for your territory

CRITICAL: if you encounter a technology choice, design pattern, or tradeoff not covered
by the user's answers above — DO NOT decide. Add it to ## Open Questions with the
options and tradeoffs clearly described. The user will answer before this architecture
is accepted.

Write to: docs/design/<feature>/<spec.id>/architecture.md

Output format:
# Architecture: <spec.concern>
## Components
## Data Model
## Border Contract (Public API)
## Border Crossings (Integration Points)
## Technical Decisions
## Security & Performance
## Open Questions
```

**Quality check per cat output:**
- [ ] All acceptance criteria from Phase 1 are covered by at least one component
- [ ] Data model has no TBD fields — every field has type and constraint
- [ ] Border crossings reference only neighboring specs' `contract.outputs`, not their internals
- [ ] Every technical decision has a rationale
- [ ] No silent assumptions — all unknown decisions are in ## Open Questions

**Collect all `## Open Questions` and ask the user before proceeding to Phase 3.**

---

## Phase 3: The Hunt Plan — Task Breakdown 📋

Same batching rules. Run only after Phase 2 questions are answered.

**For each spec, spawn one cat:**

```
You are a hunt planner for a single bounded territory.

Read these first:
- docs/design/<feature>/<spec.id>/architecture.md  ← your territory's architecture
- docs/specs/<feature>/<spec.id>/requirements.md   ← your territory's requirements

Break the architecture into atomic hunt tasks.

Rules:
- Each task is 1–4 hours of focused work (S = < 1h, M = 1–4h; split any L-sized task)
- Order by internal dependency — a task that uses an interface comes after the task that creates it
- Each task has at least 2 binary acceptance criteria
- files_to_touch must never be empty
- Each task tags its spec ID for cross-territory traceability

Write to: docs/tasks/<feature>/<spec.id>/tasks.md

Repeat for each task:
## task-<n>: <slug>
- spec: <spec.id>
- size: S | M  (never L — split hairballs)
- depends_on: [<task-slugs within this spec>]
- description: <what to implement — concrete, not vague>
- files_to_touch: [<file paths>]
- acceptance_criteria:
  - [ ] <binary check>
  - [ ] <binary check>
```

**Quality check:**
- [ ] No L-sized tasks — all hairballs must be split
- [ ] Every task has at least 2 acceptance criteria
- [ ] Dependencies form a DAG — no circular hunts
- [ ] All architecture components from Phase 2 are covered by at least one task

---

## Phase 4: The Pride — Cross-Spec Synthesis 🦁

After all Phase 3 cats finish:

1. Read all `docs/tasks/<feature>/*/tasks.md`
2. Build a cross-territory dependency graph: a task in spec-B consuming spec-A's border contract must sequence after the task in spec-A that creates it
3. Topologically sort into execution batches
4. Write the hunt order to `docs/tasks/<feature>/plan.md`:

```markdown
# Hunt Plan: <feature>

## Territory Map
| ID | Domain | Concern |
|----|--------|---------|

## Execution Batches
Each batch is a parallel hunt. A batch starts only when the previous batch is complete.

### Batch 1
- spec-X / task-1
- spec-Y / task-1

### Batch 2
...

## Cross-Territory Sequencing
| Task | Must complete before |
|------|----------------------|

## Risk Summary
Top risks from open questions across all territories:
1. ...

## Estimate
| Size | Count |
|------|-------|
| S    | N     |
| M    | N     |
| Total | N    |
```

---

## The Purr Test (Quality Gate)

```
## Planning Quality Score: [X]/100

### Completeness (40 pts)
- [ ] All territories have requirements docs (10)
- [ ] All territories have architecture docs (15)
- [ ] All territories have task breakdowns, no hairballs (15)

### Quality (40 pts)
- [ ] Requirements are binary — no vague goals (10)
- [ ] Architecture is complete — no TBD fields (10)
- [ ] Tasks are atomic — S or M only (10)
- [ ] Cross-territory dependencies resolved in plan.md (10)

### Documentation (20 pts)
- [ ] Unified plan.md with execution batches (10)
- [ ] All cross-references are valid paths (10)
```

**Threshold**: 85/100 — below this, the cat goes back to fix what failed. Maximum 3 correction rounds before escalating to user.

---

## Output

Report to user:
- 🗺️ Territories mapped: N specs
- 🐾 Per-spec artifacts: `docs/specs/<feature>/`, `docs/design/<feature>/`, `docs/tasks/<feature>/`
- 🦁 Hunt order: `docs/tasks/<feature>/plan.md`
- 😺 Purr Test: [X]/100
- 🚀 Ready to pounce: `/agent-implement <feature>`
