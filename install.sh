#!/bin/bash
# CatAgents — Install Script
# Instala worker e pr globalmente em ~/.claude/skills/
# Usage: ./install.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$HOME/.claude/skills"

echo "🐱 CatAgents Installer"
echo ""

# Verificar gh CLI
if ! command -v gh &> /dev/null; then
    echo "⚠️  gh (GitHub CLI) não encontrado."
    echo "   Instale em: https://cli.github.com"
    echo "   Os workers precisam do gh para funcionar."
    echo ""
fi

# Criar diretório de skills se não existir
mkdir -p "$SKILLS_DIR"

# Instalar skills
echo "📦 Instalando skills em $SKILLS_DIR ..."

for skill in worker pr; do
    src="$SCRIPT_DIR/skills/$skill"
    if [ -d "$src" ]; then
        rm -rf "$SKILLS_DIR/$skill"
        cp -r "$src" "$SKILLS_DIR/$skill"
        echo "   ✓ $skill"
    else
        echo "   ⚠ $skill não encontrado — pulado"
    fi
done

echo ""
echo "✅ Instalado!"
echo ""
echo "Workers disponíveis (abra um terminal por worker):"
echo ""
echo "  Código:      /worker triage | dev | dev-jules | qa | reviewer"
echo "  Descoberta:  /worker scout | qa-monitor | security | deps"
echo "  Produto:     /worker pm | ux | prioritizer"
echo "  Operações:   /worker stale | release"
echo ""
echo "  Antes de ship:  /pr"
echo ""
echo "Requisito: gh auth status (GitHub CLI autenticado)"
echo ""
