#!/bin/bash
# CatAgents — Install Script (Linux / macOS / Git Bash)
# Instala dependencias e skills em ~/.claude/skills/ e ~/.verboo/skills/
# Usage: ./install.sh

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "CatAgents Installer"
echo ""

# ─── 1. Verificar gh CLI ──────────────────────────────────────────────────────
if ! command -v gh &>/dev/null; then
    echo "ERRO: gh (GitHub CLI) nao encontrado."
    echo "      Instale em: https://cli.github.com e tente novamente."
    exit 1
fi
echo "OK  gh CLI encontrado"

# ─── 2. Instalar jq ───────────────────────────────────────────────────────────
if command -v jq &>/dev/null; then
    echo "OK  jq encontrado ($(jq --version))"
else
    echo "Instalando jq..."

    if [[ "$(uname)" == "Darwin" ]]; then
        if command -v brew &>/dev/null; then
            brew install jq
        else
            echo "AVISO: brew nao encontrado. Instale jq manualmente: https://jqlang.github.io/jq/download/"
        fi
    elif [[ "$(uname -s)" == MINGW* ]] || [[ "$(uname -s)" == MSYS* ]]; then
        # Git Bash no Windows — tenta /usr/bin, fallback para ~/bin
        JQ_URL="https://github.com/jqlang/jq/releases/latest/download/jq-windows-amd64.exe"
        if [ -w "/usr/bin" ]; then
            JQ_DEST="/usr/bin/jq"
        else
            mkdir -p "$HOME/bin"
            JQ_DEST="$HOME/bin/jq"
            # Garantir ~/bin no PATH do bashrc
            grep -q 'export PATH.*HOME/bin' "$HOME/.bashrc" 2>/dev/null || \
                echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.bashrc"
        fi
        echo "Git Bash detectado — baixando jq.exe para $JQ_DEST ..."
        curl -fsSL -o "$JQ_DEST" "$JQ_URL" && chmod +x "$JQ_DEST"
        export PATH="$HOME/bin:$PATH"
        echo "OK  jq instalado em $JQ_DEST"
    elif command -v apt-get &>/dev/null; then
        sudo apt-get install -y jq
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y jq
    elif command -v pacman &>/dev/null; then
        sudo pacman -S --noconfirm jq
    else
        echo "AVISO: nao foi possivel instalar jq automaticamente."
        echo "       Baixe em: https://jqlang.github.io/jq/download/"
    fi
fi

# ─── 3. Instalar skills ───────────────────────────────────────────────────────
for SKILLS_DIR in "$HOME/.claude/skills" "$HOME/.verboo/skills"; do
    PARENT="$(dirname "$SKILLS_DIR")"
    [ -d "$PARENT" ] || continue   # pasta pai nao existe (verboo nao instalado)

    mkdir -p "$SKILLS_DIR"
    echo ""
    echo "Instalando em $SKILLS_DIR ..."

    for skill in worker; do
        src="$SCRIPT_DIR/skills/$skill"
        if [ -d "$src" ]; then
            rm -rf "$SKILLS_DIR/$skill"
            cp -r "$src" "$SKILLS_DIR/$skill"
            echo "   OK  $skill"
        else
            echo "   AVISO: $skill nao encontrado em $src"
        fi
    done
done

# ─── 4. Resultado ─────────────────────────────────────────────────────────────
echo ""
echo "Instalacao concluida!"
echo ""
echo "Uso (abra um terminal por worker, dentro do clone do repo alvo):"
echo ""
echo "  /worker team-manager   # orquestrador — comece por ele"
echo "  /worker dev            # implementa issues assignadas"
echo "  /worker qa             # revisa PRs assignadas"
echo "  /worker reviewer       # mergeia PRs aprovadas"
echo "  /worker scout          # varredura passiva (opcional)"
echo ""
echo "Requisito: gh auth login (GitHub CLI autenticado)"
echo ""
