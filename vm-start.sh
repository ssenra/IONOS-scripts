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
: "${VM_IDS:?VM_IDS no está definido en $ENV_FILE}"

API_BASE="https://api.ionos.com/cloudapi/v6"
AUTH_HEADER="Authorization: Bearer ${IONOS_TOKEN}"

IFS=',' read -ra SERVERS <<< "$VM_IDS"

for server_id in "${SERVERS[@]}"; do
  server_id="${server_id// /}"  # eliminar espacios en blanco
  [[ -z "$server_id" ]] && continue

  echo "Encendiendo VM: $server_id ..."
  response=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST \
    -H "$AUTH_HEADER" \
    -H "Content-Type: application/json" \
    "${API_BASE}/datacenters/${IONOS_DATACENTER_ID}/servers/${server_id}/start")

  if [[ "$response" == "202" ]]; then
    echo "  -> Solicitud de inicio de VM $server_id aceptada (202)."
  else
    echo "  -> Error al encender la VM $server_id (HTTP $response)." >&2
  fi
done
