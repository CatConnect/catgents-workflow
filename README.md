# CatAgents Workflow

> *"A cat doesn't plan — it pounces at exactly the right moment."*

A system of AI agent skills for Claude Code. Cats decompose features into bounded specs, hunt in parallel, and coordinate teams through GitHub — without ever talking directly to each other.

---

## Skills

| Skill | What It Does | Install |
|-------|-------------|---------|
| `/agent-init` | Sets up the litter box — project infrastructure | project |
| `/agent-plan` | Stalks the feature — decomposes into specs, dispatches parallel cats | project |
| `/agent-implement` | Pounces — parallel task cats execute the plan | project |
| `/github-team` | Coordinates a multi-terminal dev team via GitHub labels | global |

---

## Installation

### One command (Linux / macOS)

```bash
git clone https://github.com/CatConnect/catgents-workflow.git
./catgents-workflow/install.sh your-project
```

### One command (Windows)

```powershell
git clone https://github.com/CatConnect/catgents-workflow.git
.\catgents-workflow\install.ps1 your-project
```

This installs:
- `agent-init`, `agent-plan`, `agent-implement` into `your-project/.claude/skills/`
- `github-team` into `~/.claude/skills/` (global — works in any repo)

**Requirements:** Claude Code CLI, `gh` (GitHub CLI) authenticated.

---

## Skill 1–3: Plan & Implement (`agent-plan` + `agent-implement`)

### Quick start

```
/agent-init
/agent-plan "Add user authentication with OAuth2"
/agent-implement user-auth-oauth2
```

### How it works

**`/agent-plan`** decomposes a feature into bounded specs. Each spec is one domain concern — one cat's territory. Then it dispatches independent cats in parallel for requirements, architecture, and task breakdown. Cats that depend on each other hunt in sequence; everyone else hunts at the same time.

No assumptions allowed. When a cat hits an architectural decision — tech choice, design tradeoff, pattern — it drops it in `## Open Questions` and the orchestrator asks the user before proceeding.

**`/agent-implement`** reads the resulting `plan.md` and dispatches one cat per task in parallel. Each cat receives only its task's acceptance criteria, its spec's architecture, and the specific files it needs to touch.

```
/agent-plan "notification system"
│
├── Territorial Mapping  →  .agents/<feature>/decomposition.json
├── Requirements  (parallel cats)  →  docs/specs/…/requirements.md
├── Architecture  (parallel cats)  →  docs/design/…/architecture.md
├── Task Breakdown (parallel cats)  →  docs/tasks/…/tasks.md
└── Synthesis  →  docs/tasks/<feature>/plan.md

/agent-implement "notification system"
│
├── [Batch 1]  cat-A  cat-B  (independent tasks, parallel)
├── [Batch 2]  cat-C  (depends on Batch 1)
└── Final: test suite + acceptance criteria pass/fail
```

### Artifact structure

```
your-project/
├── .agents/
│   └── <feature>/
│       └── decomposition.json
├── docs/
│   ├── specs/<feature>/<spec>/requirements.md
│   ├── design/<feature>/<spec>/architecture.md
│   └── tasks/<feature>/
│       ├── <spec>/tasks.md
│       └── plan.md                ← execution order with parallel batches
└── .claude/skills/
    ├── agent-init/
    ├── agent-plan/
    └── agent-implement/
```

### Quality gates

| Gate | Threshold | What it checks |
|------|-----------|----------------|
| Purr Test (planning) | 85/100 | Testable requirements, no TBD fields, atomic tasks, resolved dependencies |
| Nine Lives (implementation) | 80/100 | Conventions followed, all criteria PASS/FAIL, tests pass, no regressions |

---

## Skill 4: GitHub Team (`/github-team`)

Coordinate multiple Claude Code terminals using **GitHub labels as shared state**. Each terminal takes a role and loops autonomously. Terminals never talk directly — they read and write the same GitHub repo.

### Team presets

Open as many terminals as you want, each runs one role:

| Preset | Terminals | Commands |
|--------|-----------|----------|
| **solo** | 1 | `/github-team solo` |
| **duo** | 2 | `/github-team duo:triage-dev` + `/github-team duo:qa-review` |
| **trio** | 3 | `/github-team trio:triage` + `/github-team trio:dev` + `/github-team trio:qa-review` |
| **quad** | 4 | `triage` + `backend` + `frontend` + `qa-review` |
| **full** | 5 | `triage` + `backend` + `frontend` + `qa` + `reviewer` |

### Roles

| Role | Finds | Does | Never |
|------|-------|------|-------|
| `triage` | Issues without area/status label | Classifies, labels, blocks conflicts | Code, open PRs, merge |
| `backend` | `area:backend` + `status:ready` | Implement → PR → mark needs-review | Touch frontend, merge |
| `frontend` | `area:frontend` + `status:ready` | Implement → PR → mark needs-review | Touch backend, merge |
| `fullstack` | `status:ready` (either area) | Same as backend/frontend | Merge |
| `qa` | PRs with `status:needs-review` | Test, approve or block | Merge, code |
| `reviewer` | PRs with `status:qa-approved` | Verify checklist, merge | Merge without QA |
| `qa-review` | `needs-review` → test → merge | QA + merge combined | Code |

### Label system (auto-created on first run)

```
area:backend   area:frontend   area:infra   area:db   area:docs   area:qa

status:ready        status:blocked       status:in-progress
status:needs-scope  status:needs-review  status:qa-approved
status:qa-blocked   status:ready-to-merge

risk:conflict   risk:migration   risk:auth   risk:high   risk:low
```

### Issue lifecycle

```
(new issue)
    ↓ triage
needs-scope  →  status:ready  →  dev claims (lock)  →  in-progress  →  PR opens
                                                                            ↓
                                                                      needs-review
                                                                            ↓ qa
                                                                      qa-approved
                                                                            ↓ reviewer
                                                                         merged ✓
```

### Anti-race lock pattern

When two terminals could claim the same issue simultaneously:

1. Comment `claiming #<N> — agent:<role> — <timestamp>`
2. Apply `status:in-progress` + assign self
3. Wait 10 seconds
4. Re-check: am I the only assignee and the first "claiming" comment?
   - Yes → proceed
   - No → undo, pick another issue

### Usage example (full team)

```bash
# Terminal 1
/github-team triage

# Terminal 2
/github-team backend

# Terminal 3
/github-team frontend

# Terminal 4
/github-team qa

# Terminal 5
/github-team reviewer
```

Each terminal loops, logs what it's doing, and sleeps between cycles (`triage: 120s` · `dev: 60s` · `qa: 60s` · `reviewer: 90s`).

---

## Why one cat per spec

| Problem | Solution |
|---------|----------|
| Long contexts bury relevant info | Each cat gets a short, focused context |
| Single agent drifts between domains | Each cat has one territory |
| Sequential planning is slow | Independent cats hunt concurrently |
| Errors in one domain contaminate others | Bounded context — no cross-territory interference |
| Architect assumes tech stack | Cats ask. Always. |
| Two terminals grab the same issue | Lock pattern via GitHub comments |
| Terminals need a coordinator process | GitHub labels ARE the coordinator |

---

## Compatibility

Works with any Claude Code project: React, Next.js, Vue, Node.js, Python, Go, Rust, Java — any language, any framework. `github-team` requires `gh` CLI authenticated to the target repo.

---

## License

MIT
