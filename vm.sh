#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Uso: $0 <start|stop> <nombre-vm> [archivo-env]" >&2
  echo "     $0 list [archivo-env]" >&2
  exit 1
}

[[ $# -lt 1 ]] && usage

ACTION="$1"
ENV_FILE="${3:-ionos-vms.env}"

if [[ "$ACTION" == "list" ]]; then
  ENV_FILE="${2:-ionos-vms.env}"
  [[ ! -f "$ENV_FILE" ]] && { echo "Error: archivo env '$ENV_FILE' no encontrado." >&2; exit 1; }
  # shellcheck source=/dev/null
  source "$ENV_FILE"
  : "${IONOS_TOKEN:?IONOS_TOKEN no está definido en $ENV_FILE}"
  : "${IONOS_DATACENTER_ID:?IONOS_DATACENTER_ID no está definido en $ENV_FILE}"

  echo "Obteniendo VMs del datacenter ${IONOS_DATACENTER_ID} ..."
  curl -s \
    -H "Authorization: Bearer ${IONOS_TOKEN}" \
    "https://api.ionos.com/cloudapi/v6/datacenters/${IONOS_DATACENTER_ID}/servers?depth=1" \
    | python3 -c "
import sys, json
data = json.load(sys.stdin)
items = data.get('items', [])
if not items:
    print('  No se encontraron servidores.')
else:
    print(f'  {\"NOMBRE\":<30} {\"ESTADO\":<12} ID DE SERVIDOR')
    print(f'  {\"-\"*30} {\"-\"*12} {\"-\"*36}')
    for s in items:
        name   = s.get('properties', {}).get('name', '?')
        status = s.get('properties', {}).get('vmState', '?')
        sid    = s.get('id', '?')
        print(f'  {name:<30} {status:<12} {sid}')
"
  exit 0
fi

if [[ "$ACTION" != "start" && "$ACTION" != "stop" ]]; then
  echo "Error: la acción debe ser 'start', 'stop' o 'list', se recibió '$ACTION'." >&2
  usage
fi

[[ $# -lt 2 ]] && usage
VM_NAME="$2"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Error: archivo env '$ENV_FILE' no encontrado." >&2
  exit 1
fi

# shellcheck source=/dev/null
source "$ENV_FILE"

: "${IONOS_TOKEN:?IONOS_TOKEN no está definido en $ENV_FILE}"
: "${IONOS_DATACENTER_ID:?IONOS_DATACENTER_ID no está definido en $ENV_FILE}"

API_BASE="https://api.ionos.com/cloudapi/v6"
AUTH_HEADER="Authorization: Bearer ${IONOS_TOKEN}"

echo "Buscando '$VM_NAME' en el datacenter ${IONOS_DATACENTER_ID} ..."
SERVER_ID=$(curl -s \
  -H "$AUTH_HEADER" \
  "${API_BASE}/datacenters/${IONOS_DATACENTER_ID}/servers?depth=1" \
  | python3 -c "
import sys, json
data = json.load(sys.stdin)
target = sys.argv[1]
for s in data.get('items', []):
    if s.get('properties', {}).get('name', '') == target:
        print(s['id'])
        sys.exit(0)
sys.exit(1)
" "$VM_NAME") || {
  echo "Error: VM '$VM_NAME' no encontrada en el datacenter." >&2
  echo "Ejecuta '$0 list' para ver las VMs disponibles." >&2
  exit 1
}

echo "${ACTION^}ing VM '$VM_NAME' (servidor: $SERVER_ID) ..."
response=$(curl -s -o /dev/null -w "%{http_code}" \
  -X POST \
  -H "$AUTH_HEADER" \
  -H "Content-Type: application/json" \
  "${API_BASE}/datacenters/${IONOS_DATACENTER_ID}/servers/${SERVER_ID}/${ACTION}")

if [[ "$response" == "202" ]]; then
  echo "-> Solicitud aceptada (202). La VM '$VM_NAME' está ${ACTION}ando."
else
  echo "-> Fallo (HTTP $response)." >&2
  exit 1
fi
