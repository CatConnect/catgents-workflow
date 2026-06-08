---
name: "agent-plan"
description: "Plan a feature using AI agents (requirements, architecture, tasks)"
compatibility: "Requires agent-init to be run first"
metadata:
  author: "catconnect"
  version: "1.0.0"
---

## Purpose

Plan a feature through a structured workflow: requirements analysis → architecture design → task breakdown.

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Pre-Execution Checks

1. Verify `.agents/config.json` exists (run `/agent-init` if not)
2. Parse feature description from arguments
3. If empty: ERROR "No feature description provided"

## Workflow Phases

### Phase 1: Requirements Analysis (spec-analyst)

**Goal**: Transform idea into clear, testable requirements

**Actions**:
1. Extract key concepts from description
2. Identify actors, actions, data, constraints
3. Create user stories
4. Define functional requirements
5. Set success criteria

**Output**: `docs/specs/<feature-name>/requirements.md`

**Quality Check**:
- [ ] All requirements are testable
- [ ] No implementation details (WHAT, not HOW)
- [ ] Success criteria are measurable
- [ ] Scope is clearly bounded

### Phase 2: Architecture Design (spec-architect)

**Goal**: Design system architecture based on requirements

**Actions**:
1. Read requirements from Phase 1
2. Design system components
3. Define data models
4. Create API contracts (if applicable)
5. Identify integration points

**Output**: `docs/design/<feature-name>/architecture.md`

**Quality Check**:
- [ ] Covers all functional requirements
- [ ] Data models are complete
- [ ] Integration points identified
- [ ] Scalability considerations documented

### Phase 3: Task Breakdown (spec-planner)

**Goal**: Break architecture into implementable tasks

**Actions**:
1. Read architecture from Phase 2
2. Identify implementation modules
3. Create task list with dependencies
4. Estimate complexity
5. Define acceptance criteria per task

**Output**: `docs/tasks/<feature-name>/tasks.md`

**Quality Check**:
- [ ] Tasks are atomic (1-2 days each)
- [ ] Dependencies are clear
- [ ] Each task has acceptance criteria
- [ ] Tasks are ordered by dependency

## Quality Gate

After all phases, run quality validation:

```markdown
## Planning Quality Score: [X]/100

### Completeness (40 points)
- [ ] Requirements documented (10)
- [ ] Architecture designed (15)
- [ ] Tasks broken down (15)

### Quality (40 points)
- [ ] Requirements testable (10)
- [ ] Architecture feasible (10)
- [ ] Tasks atomic (10)
- [ ] Dependencies clear (10)

### Documentation (20 points)
- [ ] All artifacts created (10)
- [ ] Cross-references valid (10)
```

**Threshold**: 85/100 to proceed to implementation

If score < 85:
1. Identify failing criteria
2. Return to specific phase for revision
3. Re-run quality check

## Loop Behavior

If quality gate fails:
- **Requirements issues** → Return to Phase 1
- **Architecture issues** → Return to Phase 2
- **Task issues** → Return to Phase 3

Maximum 3 iterations per phase before warning user.

## Output

Report to user:
- 📋 Requirements: `docs/specs/<feature-name>/requirements.md`
- 🏗️ Architecture: `docs/design/<feature-name>/architecture.md`
- 📝 Tasks: `docs/tasks/<feature-name>/tasks.md`
- ✅ Quality Score: [X]/100
- 🚀 Ready for implementation: `/agent-implement`

## Customization

User can modify:
- Quality thresholds in `.agents/config.json`
- Output directories
- Documentation format
