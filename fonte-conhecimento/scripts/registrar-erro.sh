#!/usr/bin/env bash
# =============================================================================
# registrar-erro.sh — Registra um erro aprendido na base de conhecimento
# =============================================================================
# Uso interativo (o aprendiz chama este script):
#   bash fonte-conhecimento/scripts/registrar-erro.sh \
#     --domain rap \
#     --title "Usar SELECT dentro de LOOP em determination" \
#     --agent rap-specialist \
#     --severity alta \
#     --tags "performance,select,loop,determination" \
#     --file "rap/erros-aprendizados/select-dentro-loop.md"
#
# O arquivo .md deve já existir com conteúdo preenchido pelo agente aprendiz.
# Este script apenas registra no index.json e valida a estrutura.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
INDEX_FILE="${BASE_DIR}/index.json"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

DOMAIN=""
TITLE=""
AGENT=""
SEVERITY="media"
TAGS="[]"
FILE=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --domain)   DOMAIN="$2";   shift 2 ;;
    --title)    TITLE="$2";    shift 2 ;;
    --agent)    AGENT="$2";    shift 2 ;;
    --severity) SEVERITY="$2"; shift 2 ;;
    --file)     FILE="$2";     shift 2 ;;
    --tags)
      TAGS=$(echo "$2" | python3 -c "
import sys, json
raw = sys.stdin.read().strip()
tags = [t.strip() for t in raw.split(',') if t.strip()]
print(json.dumps(tags))
")
      shift 2 ;;
    *) echo -e "${RED}Argumento desconhecido: $1${NC}" >&2; exit 1 ;;
  esac
done

[[ -z "$DOMAIN" ]] && { echo -e "${RED}--domain obrigatório${NC}"; exit 1; }
[[ -z "$TITLE"  ]] && { echo -e "${RED}--title obrigatório${NC}";  exit 1; }
[[ -z "$FILE"   ]] && { echo -e "${RED}--file obrigatório${NC}";   exit 1; }

FULL_PATH="${BASE_DIR}/${FILE}"
[[ ! -f "$FULL_PATH" ]] && { echo -e "${RED}Arquivo não encontrado: $FULL_PATH${NC}"; exit 1; }

TODAY=$(date +%Y-%m-%d)

python3 << PYEOF
import json, sys

with open('${INDEX_FILE}', 'r', encoding='utf-8') as f:
    idx = json.load(f)

if '${DOMAIN}' not in idx['domains']:
    print("[ERROR] Domínio '${DOMAIN}' não encontrado.")
    sys.exit(1)

entries = idx['domains']['${DOMAIN}']['entries']

# Verificar duplicata por arquivo
if any(e['file'] == '${FILE}' for e in entries):
    print("[WARN] Entrada já existe para este arquivo — ignorando.")
    sys.exit(0)

next_num = len(entries) + 1
entry_id = f"${DOMAIN}-err-{next_num:03d}"

entries.append({
    "id": entry_id,
    "title": "❌ Erro: ${TITLE}",
    "file": "${FILE}",
    "tags": ${TAGS} + ["erro-aprendido", "${SEVERITY}"],
    "agents": ["${AGENT}", "aprendiz"],
    "tipo": "erro-aprendido",
    "severidade": "${SEVERITY}",
    "added": "${TODAY}",
    "mandatory": False
})

idx['last_updated'] = '${TODAY}'

with open('${INDEX_FILE}', 'w', encoding='utf-8') as f:
    json.dump(idx, f, ensure_ascii=False, indent=2)

print(f"[OK] Erro registrado com ID: {entry_id}")
PYEOF

echo ""
echo -e "${GREEN}✓ Erro aprendido registrado:${NC}"
echo -e "  Domínio   : ${DOMAIN}"
echo -e "  Agente    : ${AGENT:-não especificado}"
echo -e "  Severidade: ${SEVERITY}"
echo -e "  Arquivo   : ${FILE}"
echo -e ""

# =============================================================================
# PROPAGAÇÃO OBRIGATÓRIA AO BRAIN PAI
# Todo aprendizado registrado num projeto deve ser espelhado no brain central.
# =============================================================================
BRAIN_PATH_FILE="${BASE_DIR}/.brain_path"
if [ -f "$BRAIN_PATH_FILE" ]; then
    CEREBRO=$(cat "$BRAIN_PATH_FILE")
    BRAIN_FK="${CEREBRO}/fonte-conhecimento"

    if [ -d "$CEREBRO" ]; then
        # Copiar arquivo de erro para o brain pai
        BRAIN_FILE_TARGET="${BRAIN_FK}/${FILE}"
        mkdir -p "$(dirname "$BRAIN_FILE_TARGET")"
        cp "$FULL_PATH" "$BRAIN_FILE_TARGET"

        # Atualizar index.json do brain pai
        BRAIN_INDEX="${BRAIN_FK}/index.json"
        python3 << PYEOF2
import json, sys
try:
    with open('${BRAIN_INDEX}', 'r', encoding='utf-8') as f:
        idx = json.load(f)
except Exception as e:
    print(f"[WARN] Não foi possível ler o index.json do brain pai: {e}")
    sys.exit(0)

if '${DOMAIN}' not in idx.get('domains', {}):
    print("[WARN] Domínio '${DOMAIN}' não encontrado no brain pai — ignorando.")
    sys.exit(0)

entries = idx['domains']['${DOMAIN}']['entries']
if isinstance(entries, int): entries = []

if any(e.get('file') == '${FILE}' for e in entries):
    print("[OK] Brain pai já possui esta entrada.")
    sys.exit(0)

next_num = len(entries) + 1
entry_id = f"${DOMAIN}-err-{next_num:03d}"

entries.append({
    "id": entry_id,
    "title": "❌ Erro: ${TITLE}",
    "file": "${FILE}",
    "tags": ${TAGS} + ["erro-aprendido", "${SEVERITY}"],
    "agents": ["${AGENT}", "aprendiz"],
    "tipo": "erro-aprendido",
    "severidade": "${SEVERITY}",
    "added": "${TODAY}",
    "mandatory": False
})

idx['domains']['${DOMAIN}']['entries'] = entries
idx['last_updated'] = '${TODAY}'

with open('${BRAIN_INDEX}', 'w', encoding='utf-8') as f:
    json.dump(idx, f, ensure_ascii=False, indent=2)

print(f"[OK] Brain pai atualizado: {entry_id}")
PYEOF2

        echo -e "${GREEN}✓ Propagado ao brain pai:${NC} $CEREBRO"
    else
        echo -e "${YELLOW}[AVISO]${NC} Brain pai não encontrado em '$CEREBRO' — propagação ignorada."
    fi
else
    echo -e "${YELLOW}[INFO]${NC} .brain_path não encontrado — executando no brain pai (sem propagação necessária)."
fi

echo -e ""
echo -e "${YELLOW}Próximo passo:${NC} Os agentes especificados consultarão este arquivo nas próximas interações."
echo -e "  Se o erro for de alta severidade, considere adicionar a regra em:"
echo -e "  ${BLUE}agents/_shared/${AGENT}.md${NC}"
