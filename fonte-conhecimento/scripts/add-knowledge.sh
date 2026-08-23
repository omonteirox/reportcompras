#!/usr/bin/env bash
# =============================================================================
# add-knowledge.sh — Adiciona nova entrada de conhecimento ao index.json
# =============================================================================
# Uso:
#   bash fonte-conhecimento/scripts/add-knowledge.sh \
#     --domain rap \
#     --title "Draft Handling em RAP" \
#     --file rap/best-practices/draft-handling.md \
#     --tags "draft,managed,bdef" \
#     --agent "rap-specialist,tech-lead"
#
# Argumentos:
#   --domain  (obrigatório) : cds | rap | badis | reports | behavior-definitions | classes | rules
#   --title   (obrigatório) : título descritivo da entrada
#   --file    (obrigatório) : caminho relativo ao diretório fonte-conhecimento/
#   --tags    (opcional)    : tags separadas por vírgula
#   --agent   (opcional)    : agentes relevantes separados por vírgula
#   --create  (opcional)    : cria o arquivo .md vazio se não existir
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
INDEX_FILE="${BASE_DIR}/index.json"

# --- Cores para output ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_success() { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# --- Parse de argumentos ---
DOMAIN=""
TITLE=""
FILE=""
TAGS="[]"
AGENTS="[]"
CREATE_FILE=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --domain)  DOMAIN="$2";  shift 2 ;;
    --title)   TITLE="$2";   shift 2 ;;
    --file)    FILE="$2";    shift 2 ;;
    --tags)
      # Converte "tag1,tag2,tag3" para ["tag1","tag2","tag3"]
      TAGS=$(echo "$2" | python3 -c "
import sys, json
raw = sys.stdin.read().strip()
tags = [t.strip() for t in raw.split(',') if t.strip()]
print(json.dumps(tags))
")
      shift 2
      ;;
    --agent)
      AGENTS=$(echo "$2" | python3 -c "
import sys, json
raw = sys.stdin.read().strip()
agents = [a.strip() for a in raw.split(',') if a.strip()]
print(json.dumps(agents))
")
      shift 2
      ;;
    --create)  CREATE_FILE=true; shift ;;
    --help|-h)
      sed -n '3,20p' "$0"
      exit 0
      ;;
    *)
      log_error "Argumento desconhecido: $1"
      exit 1
      ;;
  esac
done

# --- Validações ---
[[ -z "$DOMAIN" ]] && { log_error "--domain é obrigatório."; exit 1; }
[[ -z "$TITLE"  ]] && { log_error "--title é obrigatório.";  exit 1; }
[[ -z "$FILE"   ]] && { log_error "--file é obrigatório.";   exit 1; }

VALID_DOMAINS="cds rap badis reports behavior-definitions classes rules"
if ! echo "$VALID_DOMAINS" | grep -qw "$DOMAIN"; then
  log_error "Domínio inválido: '$DOMAIN'. Válidos: $VALID_DOMAINS"
  exit 1
fi

FULL_FILE_PATH="${BASE_DIR}/${FILE}"

# Verificar ou criar arquivo
if [[ ! -f "$FULL_FILE_PATH" ]]; then
  if [[ "$CREATE_FILE" == true ]]; then
    mkdir -p "$(dirname "$FULL_FILE_PATH")"
    cat > "$FULL_FILE_PATH" << EOF
# ${TITLE}

> Domínio: \`${DOMAIN}\`  |  Arquivo criado por: add-knowledge.sh

## Descrição

*Adicione aqui a descrição do conhecimento.*

## Conteúdo

*Adicione aqui o conteúdo.*
EOF
    log_success "Arquivo criado: ${FILE}"
  else
    log_error "Arquivo não encontrado: ${FULL_FILE_PATH}"
    log_warn  "Use --create para criar o arquivo automaticamente."
    exit 1
  fi
fi

TODAY=$(date +%Y-%m-%d)

log_info "Adicionando entrada '${TITLE}' ao domínio '${DOMAIN}'..."

# --- Atualizar index.json ---
python3 << PYEOF
import json, sys

with open('${INDEX_FILE}', 'r', encoding='utf-8') as f:
    idx = json.load(f)

if '${DOMAIN}' not in idx['domains']:
    print("[ERROR] Domínio '${DOMAIN}' não encontrado no index.json")
    sys.exit(1)

entries = idx['domains']['${DOMAIN}']['entries']

# Verificar se já existe entrada com o mesmo arquivo (preservar ID original)
existing_idx = next((i for i, e in enumerate(entries) if e['file'] == '${FILE}'), None)

if existing_idx is not None:
    entry_id = entries[existing_idx]['id']  # preserva o ID original
    print(f"[WARN] Entrada existente encontrada (ID: {entry_id}). Atualizando metadados...")
    entries[existing_idx].update({
        "title": "${TITLE}",
        "tags": ${TAGS},
        "agents": ${AGENTS},
        "updated": "${TODAY}"
    })
else:
    # Gera novo ID sequencial para o domínio
    domain_entries = entries
    next_num = len(domain_entries) + 1
    entry_id = f"${DOMAIN}-{next_num:03d}"
    new_entry = {
        "id": entry_id,
        "title": "${TITLE}",
        "file": "${FILE}",
        "tags": ${TAGS},
        "agents": ${AGENTS},
        "added": "${TODAY}",
        "mandatory": False
    }
    entries.append(new_entry)

idx['last_updated'] = '${TODAY}'

with open('${INDEX_FILE}', 'w', encoding='utf-8') as f:
    json.dump(idx, f, ensure_ascii=False, indent=2)

print(f"[OK] Entrada processada com ID: {entry_id}")
PYEOF

log_success "index.json atualizado com sucesso!"
echo ""
echo -e "${GREEN}✓ Conhecimento registrado:${NC}"
echo -e "  ID      : ${DOMAIN}"
echo -e "  Domínio : ${DOMAIN}"
echo -e "  Arquivo : ${FILE}"
echo -e "  Título  : ${TITLE}"

# =============================================================================
# PROPAGAÇÃO OBRIGATÓRIA AO BRAIN PAI
# Todo conhecimento adicionado num projeto deve ser espelhado no brain central.
# =============================================================================
BRAIN_PATH_FILE="${BASE_DIR}/.brain_path"
FULL_FILE_PATH="${BASE_DIR}/${FILE}"

if [ -f "$BRAIN_PATH_FILE" ]; then
    CEREBRO=$(cat "$BRAIN_PATH_FILE")
    BRAIN_FK="${CEREBRO}/fonte-conhecimento"

    if [ -d "$CEREBRO" ]; then
        # Copiar arquivo para o brain pai (somente se existir)
        if [ -f "$FULL_FILE_PATH" ]; then
            BRAIN_FILE_TARGET="${BRAIN_FK}/${FILE}"
            mkdir -p "$(dirname "$BRAIN_FILE_TARGET")"
            cp "$FULL_FILE_PATH" "$BRAIN_FILE_TARGET"
        fi

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

existing_idx = next((i for i, e in enumerate(entries) if e.get('file') == '${FILE}'), None)
TODAY = '${TODAY}'

if existing_idx is not None:
    entries[existing_idx].update({"title": "${TITLE}", "tags": ${TAGS}, "agents": ${AGENTS}, "updated": TODAY})
    print(f"[OK] Brain pai: entrada atualizada.")
else:
    next_num = len(entries) + 1
    entry_id = f"${DOMAIN}-{next_num:03d}"
    entries.append({"id": entry_id, "title": "${TITLE}", "file": "${FILE}",
                    "tags": ${TAGS}, "agents": ${AGENTS}, "added": TODAY, "mandatory": False})
    print(f"[OK] Brain pai atualizado: {entry_id}")

idx['domains']['${DOMAIN}']['entries'] = entries
idx['last_updated'] = TODAY

with open('${BRAIN_INDEX}', 'w', encoding='utf-8') as f:
    json.dump(idx, f, ensure_ascii=False, indent=2)
PYEOF2

        log_success "Propagado ao brain pai: $CEREBRO"
    else
        log_warn "Brain pai não encontrado em '$CEREBRO' — propagação ignorada."
    fi
else
    log_info ".brain_path não encontrado — executando no brain pai (sem propagação necessária)."
fi
