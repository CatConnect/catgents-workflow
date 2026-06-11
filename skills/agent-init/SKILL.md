---
name: "agent-init"
description: "Set up the litter box — initialize agent workflow infrastructure in any project"
compatibility: "Works with any project type (React, Next.js, Python, Go, Rust, Java, etc)"
metadata:
  author: "catconnect"
  version: "1.0.0"
---

## Purpose

Every cat needs a territory before it can hunt. This skill sets up the workflow infrastructure — directories, configuration, and hooks — so the other cats (`/agent-plan`, `/agent-implement`) have a clean litter box to operate in.

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Execution Flow

### Step 1: Sniff the Project

Determine project type by checking for:
- `package.json` → Node.js / JavaScript / TypeScript
- `requirements.txt` or `pyproject.toml` → Python
- `go.mod` → Go
- `Cargo.toml` → Rust
- `pom.xml` or `build.gradle` → Java
- Default → Generic project

### Step 2: Scratch the Directories

```bash
mkdir -p .agents/skills
mkdir -p .agents/agents
mkdir -p .agents/commands
mkdir -p docs/specs
mkdir -p docs/design
mkdir -p docs/tasks
```

### Step 3: Write the Territory Config

Create `.agents/config.json`:

```json
{
  "version": "1.0.0",
  "project_type": "<detected-type>",
  "cats": {
    "scout": {
      "enabled": true,
      "description": "Requirements scout — maps the hunting ground"
    },
    "lair-builder": {
      "enabled": true,
      "description": "Architecture designer — builds the lair"
    },
    "paw-planner": {
      "enabled": true,
      "description": "Task planner — plans the pounce sequence"
    },
    "claws-dev": {
      "enabled": true,
      "description": "Developer — does the actual scratching"
    },
    "cat-tester": {
      "enabled": true,
      "description": "Tester — checks if the prey is actually caught"
    },
    "whisker-reviewer": {
      "enabled": true,
      "description": "Code reviewer — sniffs for problems"
    },
    "purr-validator": {
      "enabled": true,
      "description": "Final validator — only purrs when everything passes"
    }
  },
  "quality_gates": {
    "planning": 85,
    "development": 80,
    "validation": 85
  }
}
```

### Step 4: Set the Workflow Hooks

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

### Step 5: Verify the Litter Box

Check that all directories and files were created successfully.

## Output

Report to user:
- 🐾 Directories scratched into place
- 🐱 Territory config initialized
- 🔔 Hooks set
- 📁 Location: `.agents/`

## Next Steps

```
/agent-plan <feature-description>   — stalk a new feature
/agent-implement                    — pounce on the planned feature
```

## Troubleshooting

If directories already exist:
- Ask user: "Litter box already set up. Overwrite config?"
- If yes: backup existing config and recreate
- If no: skip initialization, leave territory intact
