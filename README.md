# CatConnect Agent Workflow

A generic, reusable AI-driven development workflow system. Works with any project type and any AI agent.

## Overview

Three simple skills to transform ideas into production-ready code:

| Skill | Purpose |
|-------|---------|
| `/agent-init` | Set up workflow infrastructure |
| `/agent-plan` | Plan features (requirements → architecture → tasks) |
| `/agent-implement` | Implement features (code → tests → review → validation) |

## Quick Start

### 1. Install in your project

```bash
# Clone this repo
git clone https://github.com/catconnect/catconnect-agent-workflow.git

# Copy skills to your project
cp -r catconnect-agent-workflow/skills/* your-project/.agents/skills/

# Or use the install script
./install.sh your-project
```

### 2. Initialize workflow

```
/agent-init
```

This creates:
- `.agents/` - Configuration and skills
- `docs/specs/` - Specifications
- `docs/design/` - Architecture docs
- `docs/tasks/` - Task lists

### 3. Plan a feature

```
/agent-plan "Add user authentication with OAuth2"
```

This generates:
- `docs/specs/<feature>/requirements.md`
- `docs/design/<feature>/architecture.md`
- `docs/tasks/<feature>/tasks.md`

### 4. Implement the feature

```
/agent-implement
```

This:
- Implements code task by task
- Writes tests
- Reviews code
- Validates quality
- Loops back if quality gates fail

## Workflow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                      Agent Workflow                         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐              │
│  │   INIT   │───▶│   PLAN   │───▶│IMPLEMENT │              │
│  └──────────┘    └──────────┘    └──────────┘              │
│                       │               │                     │
│                       ▼               ▼                     │
│                  ┌─────────┐    ┌─────────┐                │
│                  │ Quality │    │ Quality │                │
│                  │ Gate 1  │    │ Gate 2  │                │
│                  └─────────┘    └─────────┘                │
│                       │               │                     │
│                  ┌────┴────┐    ┌────┴────┐                │
│                  │  Loop   │    │  Loop   │                │
│                  └─────────┘    └─────────┘                │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Quality Gates

### Planning Quality (85/100 threshold)
- Requirements completeness
- Architecture feasibility
- Task breakdown quality

### Implementation Quality (80/100 threshold)
- Code quality
- Test coverage
- Validation results

## Project Structure

After installation:

```
your-project/
├── .agents/
│   ├── skills/
│   │   ├── agent-init/
│   │   │   └── SKILL.md
│   │   ├── agent-plan/
│   │   │   └── SKILL.md
│   │   └── agent-implement/
│   │       └── SKILL.md
│   ├── agents/
│   ├── commands/
│   └── config.json
├── docs/
│   ├── specs/
│   ├── design/
│   └── tasks/
└── ... (your project files)
```

## Customization

Edit `.agents/config.json` to:
- Enable/disable agents
- Adjust quality thresholds
- Change output directories

## Compatibility

Works with any project type:
- React / Next.js / Vue / Angular
- Node.js / Python / Go / Rust / Java
- Any framework or language

## License

MIT
