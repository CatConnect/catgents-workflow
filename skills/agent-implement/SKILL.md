---
name: "agent-implement"
description: "Implement planned features with code, tests, and validation"
compatibility: "Requires agent-plan to be run first"
metadata:
  author: "catconnect"
  version: "1.0.0"
---

## Purpose

Implement features based on the plan created by `/agent-plan`. This skill handles coding, testing, review, and validation.

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Pre-Execution Checks

1. Verify plan exists in `docs/tasks/`
2. If no plan found: ERROR "Run `/agent-plan <feature>` first"
3. Load task list from `docs/tasks/<feature-name>/tasks.md`
4. Identify current task (first incomplete)

## Workflow Phases

### Phase 1: Implementation (spec-developer)

**Goal**: Write code for current task

**Actions**:
1. Read task description and acceptance criteria
2. Read architecture from `docs/design/`
3. Implement code following project conventions
4. Create necessary files/directories
5. Follow existing code style

**Output**: Source code files

**Quality Check**:
- [ ] Code follows project conventions
- [ ] No commented-out code
- [ ] No TODO/FIXME without issue reference
- [ ] Error handling implemented
- [ ] TypeScript types defined (if applicable)

### Phase 2: Testing (spec-tester)

**Goal**: Write tests for implemented code

**Actions**:
1. Identify test framework (check `package.json` or project config)
2. Create test files mirroring source structure
3. Write unit tests for new functions/components
4. Write integration tests if applicable
5. Ensure tests are runnable

**Output**: Test files

**Quality Check**:
- [ ] Tests cover main functionality
- [ ] Edge cases tested
- [ ] Tests are independent
- [ ] Tests can run successfully

### Phase 3: Code Review (spec-reviewer)

**Goal**: Review code for quality and best practices

**Actions**:
1. Check code style consistency
2. Review error handling
3. Verify security practices
4. Check performance considerations
5. Validate documentation

**Output**: Review report (inline comments)

**Quality Check**:
- [ ] No security vulnerabilities
- [ ] No performance issues
- [ ] Code is maintainable
- [ ] Follows DRY principles

### Phase 4: Validation (spec-validator)

**Goal**: Final validation before marking task complete

**Actions**:
1. Run all tests
2. Run linter/formatter
3. Check TypeScript compilation (if applicable)
4. Verify no regressions
5. Update task status

**Output**: Validation report

**Quality Check**:
- [ ] All tests pass
- [ ] No lint errors
- [ ] No type errors
- [ ] Task acceptance criteria met

## Quality Gate

After all phases, run quality validation:

```markdown
## Implementation Quality Score: [X]/100

### Code Quality (40 points)
- [ ] Follows conventions (10)
- [ ] Error handling (10)
- [ ] No security issues (10)
- [ ] Performance considered (10)

### Testing (30 points)
- [ ] Tests written (10)
- [ ] Tests pass (10)
- [ ] Edge cases covered (10)

### Validation (30 points)
- [ ] Linter passes (10)
- [ ] Type check passes (10)
- [ ] No regressions (10)
```

**Threshold**: 80/100 to proceed to next task

If score < 80:
1. Identify failing criteria
2. Return to specific phase for revision
3. Re-run quality check

## Loop Behavior

If quality gate fails:
- **Code issues** → Return to Phase 1
- **Test issues** → Return to Phase 2
- **Review issues** → Return to Phase 3
- **Validation issues** → Return to Phase 4

Maximum 3 iterations per task before warning user.

## Task Progression

After successful implementation:
1. Mark task as complete in `tasks.md`
2. Move to next task
3. Repeat workflow

## Output

Report to user:
- ✅ Task completed: [task-name]
- 📁 Files created/modified: [list]
- 🧪 Tests: [pass/fail]
- 📊 Quality Score: [X]/100
- 📋 Next task: [task-name] (or "All tasks complete!")

## Customization

User can modify:
- Quality thresholds in `.agents/config.json`
- Test framework preference
- Code style rules
- Linting configuration
