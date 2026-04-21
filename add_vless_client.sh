#!/usr/bin/env bash

set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "Run as root: sudo bash add_vless_client.sh <label> <endpoint> [port]"
  exit 1
fi

if [[ $# -lt 2 || $# -gt 3 ]]; then
  cat <<'EOF'
Usage:
  sudo bash add_vless_client.sh <label> <endpoint> [port]

Example:
  sudo bash add_vless_client.sh mom-iphone 173.199.92.49
EOF
  exit 1
fi

LABEL="$1"
ENDPOINT="$2"
PORT_OVERRIDE="${3:-}"
CFG="/usr/local/etc/xray/config.json"

if [[ ! -f "${CFG}" ]]; then
  echo "Xray config not found at ${CFG}. Run install_vless_ws.sh first."
  exit 1
fi

if ! [[ "${LABEL}" =~ ^[a-zA-Z0-9._-]+$ ]]; then
  echo "label can only contain letters, numbers, '.', '_' and '-'."
  exit 1
fi

UUID="$(cat /proc/sys/kernel/random/uuid)"
PORT_FROM_CONFIG="$(jq -r '.inbounds[0].port' "${CFG}")"
WS_PATH="$(jq -r '.inbounds[0].streamSettings.wsSettings.path // "/"' "${CFG}")"
ENCODED_PATH="$(printf '%s' "${WS_PATH}" | jq -sRr @uri)"

if [[ -n "${PORT_OVERRIDE}" ]]; then
  if ! [[ "${PORT_OVERRIDE}" =~ ^[0-9]+$ ]] || (( PORT_OVERRIDE < 1 || PORT_OVERRIDE > 65535 )); then
    echo "Invalid port override: ${PORT_OVERRIDE}"
    exit 1
  fi
  PORT="${PORT_OVERRIDE}"
else
  PORT="${PORT_FROM_CONFIG}"
fi

TMP="$(mktemp)"
jq --arg id "${UUID}" --arg email "${LABEL}" \
  '.inbounds[0].settings.clients += [{"id":$id,"level":0,"email":$email}]' \
  "${CFG}" > "${TMP}"
install -m 600 "${TMP}" "${CFG}"
rm -f "${TMP}"

xray -test -config "${CFG}"
systemctl restart xray

echo "Added client: ${LABEL}"
echo "URI:"
echo "vless://${UUID}@${ENDPOINT}:${PORT}?type=ws&encryption=none&path=${ENCODED_PATH}&host=&security=none#${LABEL}"
