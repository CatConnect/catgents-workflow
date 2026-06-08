#!/bin/bash
# CatConnect Agent Workflow - Install Script
# Usage: ./install.sh [project-path]

set -e

PROJECT_PATH="${1:-.}"

echo "🚀 CatConnect Agent Workflow Installer"
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
  "version": "1.0.0",
  "project_type": "generic",
  "agents": {
    "analyst": { "enabled": true, "description": "Requirements analysis" },
    "architect": { "enabled": true, "description": "System design" },
    "planner": { "enabled": true, "description": "Task breakdown" },
    "developer": { "enabled": true, "description": "Implementation" },
    "tester": { "enabled": true, "description": "Testing" },
    "reviewer": { "enabled": true, "description": "Code review" },
    "validator": { "enabled": true, "description": "Final validation" }
  },
  "quality_gates": {
    "planning": 85,
    "development": 80,
    "validation": 85
  }
}
EOF

echo ""
echo "✅ Installation complete!"
echo ""
echo "Next steps:"
echo "  1. Run /agent-init to initialize workflow"
echo "  2. Run /agent-plan <feature> to plan a feature"
echo "  3. Run /agent-implement to implement"
echo ""
