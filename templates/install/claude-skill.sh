#!/bin/bash
# Instalador de Claude skill: {{PROJECT_NAME}}
# Copia SKILL.md a ~/.claude/skills/ y configura el entorno

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SKILL_NAME="$(basename "$SCRIPT_DIR")"
SKILL_DEST="$HOME/.claude/skills/$SKILL_NAME"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Instalador: {{PROJECT_NAME}}${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Verificar Claude Code
if [ ! -d "$HOME/.claude" ]; then
    echo -e "${RED}❌ Claude Code no parece estar instalado.${NC}"
    echo "   Directorio ~/.claude no existe."
    echo "   Instala Claude Code desde: https://docs.claude.com/claude-code"
    exit 1
fi

# Si hay requirements.txt, crear venv
if [ -f "requirements.txt" ]; then
    echo -e "${YELLOW}Instalando dependencias Python...${NC}"
    if [ ! -d "venv" ]; then
        python3 -m venv venv
    fi
    source venv/bin/activate
    pip install --upgrade pip --quiet
    pip install -r requirements.txt --quiet
    echo -e "${GREEN}✓${NC} Dependencias instaladas"
fi

# Copiar skill a ~/.claude/skills/
mkdir -p "$SKILL_DEST"
cp -R "$SCRIPT_DIR/"* "$SKILL_DEST/"
# Excluir install.sh y README.md del destino (no son parte de la skill en ejecución)
rm -f "$SKILL_DEST/install.sh" "$SKILL_DEST/README.md" "$SKILL_DEST/LICENSE" "$SKILL_DEST/.gitignore"

echo -e "${GREEN}✓${NC} Skill instalada en: $SKILL_DEST"

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  ✅ Instalación completa${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Uso:"
echo "  Abre Claude Code y escribe: /$SKILL_NAME"
