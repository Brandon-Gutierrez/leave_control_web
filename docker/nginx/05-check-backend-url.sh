#!/bin/sh
# BACKEND_URL (la dirección de la API) debe ser http(s)://host[:puerto], sin ruta
# ni barra final: nginx reenvía la ruta original de cada petición.
set -e

fail() {
    echo "[backend] BACKEND_URL no es válido (valor: '${BACKEND_URL}'). $1" >&2
    echo "[backend] Ejemplos: http://control-salidas-api   https://10.0.0.5:8443" >&2
    exit 1
}

case "${BACKEND_URL}" in
    http://?* | https://?*) ;;
    *) fail "Debe empezar con http:// o https://." ;;
esac

case "${BACKEND_URL#*://}" in
    */* | *" "* | *'"'* | *';'*) fail "No lleva ruta, barra final ni espacios." ;;
esac
