#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="${1:-ionos-vms.env}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Error: archivo env '$ENV_FILE' no encontrado." >&2
  echo "Uso: $0 [archivo-env]" >&2
  exit 1
fi

# shellcheck source=/dev/null
source "$ENV_FILE"

: "${IONOS_TOKEN:?IONOS_TOKEN no está definido en $ENV_FILE}"
: "${IONOS_DATACENTER_ID:?IONOS_DATACENTER_ID no está definido en $ENV_FILE}"
: "${VM_NAMES:?VM_NAMES no está definido en $ENV_FILE}"

API_BASE="https://api.ionos.com/cloudapi/v6"
AUTH_HEADER="Authorization: Bearer ${IONOS_TOKEN}"

IFS=',' read -ra SERVERS <<< "$VM_NAMES"

for vm_name in "${SERVERS[@]}"; do
  vm_name="${vm_name// /}"  # eliminar espacios en blanco
  [[ -z "$vm_name" ]] && continue

  echo "Buscando UUID de '$vm_name' ..."
  server_id=$(curl -s \
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
" "$vm_name") || {
    echo "  -> Error: VM '$vm_name' no encontrada en el datacenter." >&2
    continue
  }

  echo "Encendiendo VM '$vm_name' (UUID: $server_id) ..."
  response=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST \
    -H "$AUTH_HEADER" \
    -H "Content-Type: application/json" \
    "${API_BASE}/datacenters/${IONOS_DATACENTER_ID}/servers/${server_id}/start")

  if [[ "$response" == "202" ]]; then
    echo "  -> Solicitud de inicio de VM '$vm_name' aceptada (202)."
  else
    echo "  -> Error al encender la VM '$vm_name' (HTTP $response)." >&2
  fi
done
