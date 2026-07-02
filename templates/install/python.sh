#!/bin/bash
# Instalador de {{PROJECT_NAME}}
# Requisitos: Python 3.9+

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}  Instalador: {{PROJECT_NAME}}${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Verificar Python 3
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}❌ Python 3 no está instalado.${NC}"
    echo "Instálalo desde https://www.python.org/downloads/ o con: brew install python3"
    exit 1
fi
echo -e "${GREEN}✓${NC} Python 3 detectado: $(python3 --version)"

# Crear venv e instalar
if [ ! -d "venv" ]; then
    python3 -m venv venv
fi
source venv/bin/activate
pip install --upgrade pip --quiet
pip install -r requirements.txt --quiet

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  ✅ Instalación completa${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Uso: source venv/bin/activate && python <tu-script>.py"
