# CatConnect Agent Workflow

A generic, reusable AI-driven development workflow system. Works with any project type and any AI agent.

## Overview

Three skills to transform ideas into production-ready code using **parallel bounded-context subagents**:

| Skill | Purpose | Version |
|-------|---------|---------|
| `/agent-init` | Set up workflow infrastructure | 1.0.0 |
| `/agent-plan` | Decompose feature into specs → parallel subagents per spec | 2.0.0 |
| `/agent-implement` | Implement via parallel task subagents driven by plan.md | 2.0.0 |

## Quick Start

### 1. Install in your project

**Linux / macOS:**
```bash
git clone https://github.com/CatConnect/catgents-workflow.git
./catgents-workflow/install.sh your-project
```

**Windows:**
```powershell
git clone https://github.com/CatConnect/catgents-workflow.git
.\catgents-workflow\install.ps1 your-project
```

### 2. Initialize workflow

```
/agent-init
```

### 3. Plan a feature

```
/agent-plan "Add user authentication with OAuth2"
```

### 4. Implement the feature

```
/agent-implement user-auth-oauth2
```

---

## How It Works (v2.0.0)

### agent-plan: Parallel Bounded-Context Planning

Instead of a single agent analyzing the whole feature sequentially, `agent-plan` v2 runs in 4 phases:

**Phase 0 — Spec Decomposition**

The orchestrator breaks the feature into bounded specs — each spec covers exactly one domain concern (data model, API, UI component, auth rule, background job, etc.). The result is saved to `.agents/<feature>/decomposition.json`.

Example for "notification system":
```
spec-data-model  →  notifications table, schema, migrations
spec-api         →  GET/POST /notifications endpoints
spec-ui-bell     →  header icon + dropdown component
spec-job         →  async delivery worker
```

**Phase 1–3 — Parallel Subagents**

For each phase (Requirements → Architecture → Task Breakdown), independent specs are dispatched **simultaneously** as subagents via the `Agent` tool. Each subagent receives only:
- Its spec's description and domain concern
- The contracts (inputs/outputs) of specs it depends on — not their internals
- A short list of relevant existing files to read

This means `spec-data-model` and `spec-job` analyze their requirements at the same time. `spec-api` — which depends on the data model — waits, then runs in the next batch.

**Phase 4 — Cross-Spec Synthesis**

The orchestrator reads all per-spec task files, builds a cross-spec dependency graph, and writes `docs/tasks/<feature>/plan.md` with topologically-sorted execution batches.

### agent-implement: Parallel Task Execution

`agent-implement` reads `plan.md` and dispatches each independent task batch in parallel. Each task subagent receives only its own task description, acceptance criteria, and the files it needs to touch.

---

## Why Parallel Subagents

| Problem | Solution |
|---------|----------|
| Long contexts bury relevant information (Liu et al., 2023 — *Lost in the Middle*) | Each subagent gets a short, focused context with its spec at the top |
| Single agent drifts between domains | Each subagent has a single, fixed role and scope |
| Sequential planning is slow for large features | Independent specs run concurrently |
| Errors in one domain contaminate reasoning in another | Bounded context prevents cross-spec error cascade |

---

## Artifact Structure

After `/agent-plan <feature>`:

```
your-project/
├── .agents/
│   └── <feature>/
│       └── decomposition.json      ← spec graph with contracts
├── docs/
│   ├── specs/
│   │   └── <feature>/
│   │       ├── spec-data-model/
│   │       │   └── requirements.md
│   │       └── spec-api/
│   │           └── requirements.md
│   ├── design/
│   │   └── <feature>/
│   │       ├── spec-data-model/
│   │       │   └── architecture.md
│   │       └── spec-api/
│   │           └── architecture.md
│   └── tasks/
│       └── <feature>/
│           ├── spec-data-model/
│           │   └── tasks.md
│           ├── spec-api/
│           │   └── tasks.md
│           └── plan.md             ← unified execution batches
```

---

## Workflow Diagram

```
/agent-plan <feature>
│
├── Phase 0: Spec Decomposition
│   └── .agents/<feature>/decomposition.json
│
├── Phase 1: Requirements (parallel per spec)
│   ├── [Batch 1 simultaneous] spec-A subagent → docs/specs/.../requirements.md
│   │                          spec-B subagent → docs/specs/.../requirements.md
│   └── [Batch 2 after Batch 1] spec-C subagent → docs/specs/.../requirements.md
│
├── Phase 2: Architecture (parallel per spec, same batching)
│
├── Phase 3: Task Breakdown (parallel per spec, same batching)
│
└── Phase 4: Synthesis → docs/tasks/<feature>/plan.md


/agent-implement <feature>
│
├── Read plan.md → execution batches
│
├── [Batch 1 simultaneous] task-X subagent → implements, runs tests, reports PASS/FAIL
│                          task-Y subagent → implements, runs tests, reports PASS/FAIL
│
├── [Batch 2 after Batch 1] task-Z subagent → ...
│
└── Final: full test suite + acceptance criteria verification
```

---

## Quality Gates

### Planning (85/100 threshold)
- All specs have requirements, architecture, and task docs
- Requirements are testable (binary, not vague)
- Architecture has no TBD data models
- Tasks are atomic (S or M only — no L tasks)
- Cross-spec dependencies resolved in `plan.md`

### Implementation (80/100 threshold)
- Code follows existing conventions
- Every acceptance criterion explicitly verified (PASS/FAIL)
- Tests run and pass
- No regressions

---

## Customization

Edit `.agents/config.json` to adjust quality thresholds:

```json
{
  "quality_gates": {
    "planning": 85,
    "development": 80,
    "validation": 85
  }
}
```

---

## Compatibility

Works with any project type: React, Next.js, Vue, Angular, Node.js, Python, Go, Rust, Java, or any framework.

## License

MIT
