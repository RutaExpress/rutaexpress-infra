#!/bin/sh
# Genera definitions.json desde la plantilla, reemplazando cada contraseña por su hash SHA-256
set -eu

hash() {
  h=$(rabbitmqctl -q hash_password "$1" | tail -n 1)
  [ -n "$h" ] || { echo "ERROR: no se pudo generar el hash" >&2; exit 1; }
  echo "$h"
}

ADMIN_HASH=$(hash "$RX_ADMIN_PASSWORD")
OPS_HASH=$(hash "$RX_OPS_PASSWORD")
SHIPMENTS_HASH=$(hash "$RX_SHIPMENTS_PASSWORD")
NOTIFY_HASH=$(hash "$RX_NOTIFY_PASSWORD")

sed -e "s|__RX_ADMIN_HASH__|$ADMIN_HASH|" \
    -e "s|__RX_OPS_HASH__|$OPS_HASH|" \
    -e "s|__RX_SHIPMENTS_HASH__|$SHIPMENTS_HASH|" \
    -e "s|__RX_NOTIFY_HASH__|$NOTIFY_HASH|" \
    /scripts/definitions.template.json > /definitions/definitions.json

chmod 644 /definitions/definitions.json
echo "definitions.json generado: vhost rutaexpress y 4 usuarios (contraseñas en hash)"
