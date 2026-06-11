#!/bin/bash
# CatConnect Agent Workflow - Install Script
# Usage: ./install.sh [project-path]

set -e

PROJECT_PATH="${1:-.}"

echo "🐱 CatAgents Workflow Installer"
echo ""

# Check if project path exists
if [ ! -d "$PROJECT_PATH" ]; then
    echo "❌ Project path not found: $PROJECT_PATH"
    exit 1
fi

echo "📁 Project: $PROJECT_PATH"

# Create directories
echo "📂 Creating directories..."
mkdir -p "$PROJECT_PATH/.agents/skills"
mkdir -p "$PROJECT_PATH/.agents/agents"
mkdir -p "$PROJECT_PATH/.agents/commands"
mkdir -p "$PROJECT_PATH/docs/specs"
mkdir -p "$PROJECT_PATH/docs/design"
mkdir -p "$PROJECT_PATH/docs/tasks"

# Get script location
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Copy skills
echo "📋 Copying skills..."
cp -r "$SCRIPT_DIR/skills/agent-init" "$PROJECT_PATH/.agents/skills/"
cp -r "$SCRIPT_DIR/skills/agent-plan" "$PROJECT_PATH/.agents/skills/"
cp -r "$SCRIPT_DIR/skills/agent-implement" "$PROJECT_PATH/.agents/skills/"

# Create config
echo "⚙️ Creating configuration..."
cat > "$PROJECT_PATH/.agents/config.json" << 'EOF'
{
  "version": "2.0.0",
  "project_type": "generic",
  "cats": {
    "scout": { "enabled": true, "description": "Requirements scout — maps the hunting ground" },
    "lair-builder": { "enabled": true, "description": "Architecture designer — builds the lair" },
    "paw-planner": { "enabled": true, "description": "Task planner — plans the pounce sequence" },
    "claws-dev": { "enabled": true, "description": "Developer — does the actual scratching" },
    "cat-tester": { "enabled": true, "description": "Tester — checks if the prey is actually caught" },
    "whisker-reviewer": { "enabled": true, "description": "Code reviewer — sniffs for problems" },
    "purr-validator": { "enabled": true, "description": "Final validator — only purrs when everything passes" }
  },
  "quality_gates": {
    "planning": 85,
    "development": 80,
    "validation": 85
  }
}
EOF

echo ""
echo "✅ Litter box ready!"
echo ""
echo "Next steps:"
echo "  1. Run /agent-init   — set up the territory"
echo "  2. Run /agent-plan <feature>   — stalk the feature"
echo "  3. Run /agent-implement <feature>   — pounce"
echo ""
