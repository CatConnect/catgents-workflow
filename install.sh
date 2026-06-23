#!/bin/bash
# CatAgents Workflow — Install Script
# Usage: ./install.sh [project-path]
# Installs agent-plan/init/implement into <project>/.claude/skills/
# Installs github-team into ~/.claude/skills/ (global)

set -e

PROJECT_PATH="${1:-.}"

echo "🐱 CatAgents Workflow Installer"
echo ""

# Check project path
if [ ! -d "$PROJECT_PATH" ]; then
    echo "❌ Project path not found: $PROJECT_PATH"
    exit 1
fi

PROJECT_PATH="$(cd "$PROJECT_PATH" && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "📁 Project: $PROJECT_PATH"

# ── Project-level skills ───────────────────────────────────────────────────────

echo ""
echo "📋 Installing project skills into $PROJECT_PATH/.claude/skills/ ..."
mkdir -p "$PROJECT_PATH/.claude/skills"

for skill in agent-init agent-plan agent-implement; do
    if [ -d "$SCRIPT_DIR/skills/$skill" ]; then
        cp -r "$SCRIPT_DIR/skills/$skill" "$PROJECT_PATH/.claude/skills/"
        echo "   ✓ $skill"
    else
        echo "   ⚠ $skill not found in $SCRIPT_DIR/skills/ — skipped"
    fi
done

# ── Support dirs ──────────────────────────────────────────────────────────────

mkdir -p "$PROJECT_PATH/.agents"
mkdir -p "$PROJECT_PATH/docs/specs"
mkdir -p "$PROJECT_PATH/docs/design"
mkdir -p "$PROJECT_PATH/docs/tasks"

# ── Config ────────────────────────────────────────────────────────────────────

if [ ! -f "$PROJECT_PATH/.agents/config.json" ]; then
    cat > "$PROJECT_PATH/.agents/config.json" << 'EOF'
{
  "version": "2.0.0",
  "project_type": "generic",
  "quality_gates": {
    "planning": 85,
    "development": 80,
    "validation": 85
  }
}
EOF
    echo "   ✓ .agents/config.json"
fi

# ── Global skill: github-team ─────────────────────────────────────────────────

echo ""
echo "🌐 Installing github-team into ~/.claude/skills/ (global) ..."
mkdir -p "$HOME/.claude/skills"

if [ -d "$SCRIPT_DIR/skills/github-team" ]; then
    cp -r "$SCRIPT_DIR/skills/github-team" "$HOME/.claude/skills/"
    echo "   ✓ github-team"
else
    echo "   ⚠ github-team not found — skipped"
fi

# ── Done ──────────────────────────────────────────────────────────────────────

echo ""
echo "✅ Done!"
echo ""
echo "Project skills ($(basename "$PROJECT_PATH")):"
echo "  /agent-init              — set up the territory"
echo "  /agent-plan <feature>    — stalk the feature"
echo "  /agent-implement <feat>  — pounce"
echo ""
echo "Global skill (any repo):"
echo "  /github-team solo                    — all-in-one terminal"
echo "  /github-team triage|backend|frontend — dedicated terminals"
echo "  /github-team qa|reviewer|qa-review   — quality terminals"
echo "  /github-team duo:triage-dev          — duo preset, terminal 1"
echo "  /github-team duo:qa-review           — duo preset, terminal 2"
echo ""
echo "Tip: run 'gh auth status' to confirm GitHub CLI is authenticated."
echo ""
