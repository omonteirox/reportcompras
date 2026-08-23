#!/usr/bin/env bash
# =============================================================================
# sincronizar-cerebro.sh — Sincroniza o core da base de conhecimento com o brain
# =============================================================================
# Uso (executar da raiz do projeto que recebeu a injeção):
#   bash fonte-conhecimento/scripts/sincronizar-cerebro.sh
#
# O que é sincronizado:
#   - Arquivos core reais (rules, custom knowledge, index.json, scripts)
#   - CLAUDE.md na raiz do projeto
#
# O que NÃO é sincronizado (não precisa — são symlinks diretos, sempre atuais):
#   - abap-fundamentos/ (symlink → brain/abap-cheat-sheets2)
#   - cds-standard-sap/ (symlink → brain/cds-help)
#   - partner-reference/ (symlink → brain/sample-abap-partner-reference)
#   - fiori-showcase/ (symlink → brain/abap-plataform-fiori-feature-showcase)
#   - abap-util/ (symlink → brain/abap-util)
# =============================================================================

set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; RED='\033[0;31m'; NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FK="$(cd "${SCRIPT_DIR}/.." && pwd)"
PROJETO="$(cd "${FK}/.." && pwd)"
BRAIN_FILE="$FK/.brain_path"

if [ ! -f "$BRAIN_FILE" ]; then
    echo -e "${RED}[ERRO]${NC} $BRAIN_FILE não encontrado."
    echo -e "Certifique-se de que injetar_ia.sh foi executado neste projeto."
    exit 1
fi

CEREBRO=$(cat "$BRAIN_FILE")

if [ ! -f "$CEREBRO/CLAUDE.md" ]; then
    echo -e "${RED}[ERRO]${NC} Brain em '$CEREBRO' não encontrado ou movido."
    echo -e "Atualize '$BRAIN_FILE' com o novo caminho do brain e tente novamente."
    exit 1
fi

echo -e "${CYAN}Sincronizando brain: $CEREBRO${NC}"
echo -e "${CYAN}Projeto: $PROJETO${NC}"
echo ""

# Sincronizar core (arquivos reais)
rsync -a --delete \
    --exclude='abap-fundamentos' --exclude='cds-standard-sap' \
    --exclude='partner-reference' --exclude='fiori-showcase' --exclude='abap-util' \
    "$CEREBRO/fonte-conhecimento/" "$FK/"
echo -e "${GREEN}[OK]${NC} Core sincronizado (rules, index, knowledge custom, scripts)."

# Verificar symlinks externos (recriar se quebrados)
for PAIR in \
    "abap-fundamentos:$CEREBRO/abap-cheat-sheets2" \
    "cds-standard-sap:$CEREBRO/cds-help" \
    "partner-reference:$CEREBRO/sample-abap-partner-reference" \
    "fiori-showcase:$CEREBRO/abap-plataform-fiori-feature-showcase" \
    "abap-util:$CEREBRO/abap-util"
do
    ALIAS="${PAIR%%:*}"
    SOURCE="${PAIR##*:}"
    LINK="$FK/$ALIAS"
    if [ -L "$LINK" ] && [ -d "$LINK" ]; then
        echo -e "${GREEN}[OK]${NC} fonte-conhecimento/$ALIAS → symlink direto ativo."
    elif [ -d "$SOURCE" ]; then
        rm -f "$LINK"
        ln -sf "$SOURCE" "$LINK"
        echo -e "${GREEN}[REPARADO]${NC} fonte-conhecimento/$ALIAS → symlink direto recriado."
    else
        echo -e "${YELLOW}[AVISO]${NC} fonte-conhecimento/$ALIAS → fonte não encontrada: $SOURCE"
    fi
done

# Atualizar CLAUDE.md + AI_CORE.md na raiz
cp "$CEREBRO/CLAUDE.md" "$PROJETO/CLAUDE.md"
echo -e "${GREEN}[OK]${NC} CLAUDE.md atualizado."

cp "$CEREBRO/AI_CORE.md" "$PROJETO/AI_CORE.md"
echo -e "${GREEN}[OK]${NC} AI_CORE.md atualizado (contexto master)."

TOTAL=$(python3 -c "
import json
try:
    idx = json.load(open('$FK/index.json'))
    print(sum(len(d['entries']) for d in idx['domains'].values()))
except: print('?')
" 2>/dev/null)

echo ""
echo -e "${GREEN}[SUCESSO]${NC} Brain sincronizado — ${CYAN}${TOTAL} entradas na base${NC}"
