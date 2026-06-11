# 🐱 CatAgents Workflow

> *"A cat doesn't plan — it pounces at exactly the right moment."*

An AI-driven development workflow system built on parallel bounded-context subagents. Every feature gets decomposed into specs, every spec gets its own cat — focused, territorial, and impossible to distract.

## The Three Cats

| Skill | What It Does | Version |
|-------|-------------|---------|
| `/agent-init` | Sets up the litter box (project infrastructure) | 1.0.0 |
| `/agent-plan` | Stalks the feature — decomposes into specs, dispatches a cat per spec in parallel | 2.0.0 |
| `/agent-implement` | Pounces — parallel task cats execute the plan from `plan.md` | 2.0.0 |

## Quick Start

### 1. Claim your territory

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

### 2. Set up the litter box

```
/agent-init
```

### 3. Stalk the feature

```
/agent-plan "Add user authentication with OAuth2"
```

### 4. Pounce

```
/agent-implement user-auth-oauth2
```

---

## How It Works

### agent-plan: The Stalk

A cat never charges blindly — it studies, maps the territory, then acts. `agent-plan` works the same way:

**Phase 0 — Territorial Mapping 🗺️**

The orchestrator decomposes the feature into bounded specs. Each spec is one territory — one domain concern, one cat's job. Result saved to `.agents/<feature>/decomposition.json`.

Example for "notification system":
```
spec-data-model  →  notifications table, schema, migrations
spec-api         →  GET/POST /notifications endpoints
spec-ui-bell     →  header icon + dropdown component
spec-job         →  async delivery worker
```

**Phases 1–3 — Parallel Cats 🐾**

For each phase (Requirements → Architecture → Task Breakdown), independent specs are dispatched **simultaneously** as subagents via the `Agent` tool. Each cat receives only:
- Its own territory's description
- The contracts (inputs/outputs) of specs it depends on — not their internals
- A short list of relevant files to sniff around

Cats that depend on each other hunt in sequence. Everyone else hunts at the same time.

**No assumptions allowed.** Whenever a cat encounters an architectural decision — tech choice, design tradeoff, pattern — it drops it in `## Open Questions` and the orchestrator asks the user before proceeding. Cats are territorial but they respect the owner.

**Phase 4 — The Pride 🦁**

The orchestrator synthesizes all per-spec outputs into `docs/tasks/<feature>/plan.md` — a topologically-sorted execution plan with parallel batches.

### agent-implement: The Pounce

Reads `plan.md` and dispatches independent tasks in parallel. Each task cat gets only:
- Its task description and acceptance criteria
- Its spec's architecture and requirements docs
- The specific files it needs to touch

One cat per task. Focused. No distractions.

---

## Why One Cat Per Spec

| Problem | Solution |
|---------|----------|
| Long contexts bury relevant info (*Lost in the Middle*, Liu et al. 2023) | Each cat gets a short, focused context — its prey is always at the top |
| Single agent drifts between domains | Each cat has one territory and cannot leave it |
| Sequential planning is slow | Independent cats hunt concurrently |
| Errors in one domain contaminate others | Bounded context = no cross-territory interference |
| Architect assumes tech stack | Cats ask. Always. |

---

## Artifact Structure

After `/agent-plan <feature>`:

```
your-project/
├── .agents/
│   └── <feature>/
│       └── decomposition.json        ← territorial map with contracts
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
│           └── plan.md               ← the hunt order
```

---

## Workflow Diagram

```
/agent-plan <feature>
│
├── 🗺️  Territorial Mapping
│   └── .agents/<feature>/decomposition.json
│
├── 🔍  Requirements (parallel cats)
│   ├── [Batch 1] 🐱 spec-A cat ──► docs/specs/.../requirements.md
│   │             🐱 spec-B cat ──► docs/specs/.../requirements.md
│   └── [Batch 2] 🐱 spec-C cat ──► docs/specs/.../requirements.md
│           ↕
│     ❓ Orchestrator asks user about open questions before next phase
│
├── 🏗️  Architecture (parallel cats, same batching)
│           ↕
│     ❓ Orchestrator asks user about open questions before next phase
│
├── 📋  Task Breakdown (parallel cats, same batching)
│
└── 🦁  Pride Synthesis ──► docs/tasks/<feature>/plan.md


/agent-implement <feature>
│
├── Read plan.md → execution batches
│
├── [Batch 1] 🐱 task-X cat ──► implements, tests, reports PASS/FAIL
│             🐱 task-Y cat ──► implements, tests, reports PASS/FAIL
│
├── [Batch 2 after Batch 1] 🐱 task-Z cat ──► ...
│
└── 🎯 Final: full test suite + acceptance criteria verification
```

---

## Quality Gates

### The Purr Test — Planning (85/100)
- All specs have requirements, architecture, and task docs
- Requirements are testable (binary, not vague)
- Architecture has no TBD fields
- Tasks are atomic (S or M — no hairballs)
- Cross-spec dependencies resolved in `plan.md`

### The Nine Lives Check — Implementation (80/100)
- Code follows existing conventions
- Every acceptance criterion explicitly PASS/FAIL
- Tests run and pass
- No regressions

---

## Customization

Edit `.agents/config.json` to tune the thresholds:

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

Works with any project: React, Next.js, Vue, Angular, Node.js, Python, Go, Rust, Java — any language, any framework. Cats adapt.

## License

MIT
