---
name: "agent-init"
description: "Initialize agent workflow infrastructure in any project"
compatibility: "Works with any project type (React, Next.js, Python, etc)"
metadata:
  author: "catconnect"
  version: "1.0.0"
---

## Purpose

Set up the agent workflow infrastructure in your project. This creates the necessary directories, configuration files, and hooks to enable AI-driven development workflows.

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## What This Does

1. **Creates directory structure**
2. **Sets up agent configuration**
3. **Initializes workflow hooks**
4. **Validates installation**

## Execution Flow

### Step 1: Analyze Project

Determine the project type by checking for:
- `package.json` → Node.js/JavaScript/TypeScript
- `requirements.txt` or `pyproject.toml` → Python
- `go.mod` → Go
- `Cargo.toml` → Rust
- `pom.xml` or `build.gradle` → Java
- Default → Generic project

### Step 2: Create Directories

```bash
mkdir -p .agents/skills
mkdir -p .agents/agents
mkdir -p .agents/commands
mkdir -p docs/specs
mkdir -p docs/design
mkdir -p docs/tasks
```

### Step 3: Create Configuration

Create `.agents/config.json`:

```json
{
  "version": "1.0.0",
  "project_type": "<detected-type>",
  "agents": {
    "analyst": {
      "enabled": true,
      "description": "Requirements analysis"
    },
    "architect": {
      "enabled": true,
      "description": "System design"
    },
    "planner": {
      "enabled": true,
      "description": "Task breakdown"
    },
    "developer": {
      "enabled": true,
      "description": "Implementation"
    },
    "tester": {
      "enabled": true,
      "description": "Testing"
    },
    "reviewer": {
      "enabled": true,
      "description": "Code review"
    },
    "validator": {
      "enabled": true,
      "description": "Final validation"
    }
  },
  "quality_gates": {
    "planning": 85,
    "development": 80,
    "validation": 85
  }
}
```

### Step 4: Create Workflow Hook

Create `.agents/hooks/workflow.json`:

```json
{
  "on_spec_created": {
    "action": "run_quality_check",
    "gate": "planning"
  },
  "on_code_implemented": {
    "action": "run_tests",
    "gate": "development"
  },
  "on_review_complete": {
    "action": "run_validation",
    "gate": "validation"
  }
}
```

### Step 5: Validate Installation

Check that all directories and files were created successfully.

## Output

Report to user:
- ✅ Directories created
- ✅ Configuration initialized
- ✅ Hooks configured
- 📁 Location: `.agents/`

## Next Steps

After initialization, use:
- `/agent-plan <feature-description>` - Plan a new feature
- `/agent-implement` - Implement planned features

## Troubleshooting

If directories already exist:
- Ask user: "Agent workflow already initialized. Overwrite configuration?"
- If yes, backup existing config and recreate
- If no, skip initialization
