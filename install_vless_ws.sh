#!/usr/bin/env bash

set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "Run as root: sudo bash install_vless_ws.sh <endpoint> [port] [ws_path]"
  exit 1
fi

if [[ $# -lt 1 || $# -gt 3 ]]; then
  cat <<'EOF'
Usage:
  sudo bash install_vless_ws.sh <endpoint> [port] [ws_path]

Example:
  sudo bash install_vless_ws.sh 173.199.92.49 80 /
EOF
  exit 1
fi

ENDPOINT="$1"
PORT="${2:-80}"
WS_PATH="${3:-/}"
CFG="/usr/local/etc/xray/config.json"
META="/usr/local/etc/xray/vless_meta.json"

if ! [[ "${PORT}" =~ ^[0-9]+$ ]] || (( PORT < 1 || PORT > 65535 )); then
  echo "Invalid port: ${PORT}"
  exit 1
fi

if [[ "${WS_PATH:0:1}" != "/" ]]; then
  echo "ws_path must start with '/'. Example: /"
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y curl jq uuid-runtime

bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install -u root

UUID="$(cat /proc/sys/kernel/random/uuid)"
ENCODED_PATH="$(printf '%s' "${WS_PATH}" | jq -sRr @uri)"

mkdir -p /usr/local/etc/xray

cat > "${CFG}" <<EOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "tag": "vless-ws-in",
      "listen": "0.0.0.0",
      "port": ${PORT},
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${UUID}",
            "level": 0,
            "email": "family-main"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": {
          "path": "${WS_PATH}",
          "headers": {}
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    },
    {
      "protocol": "blackhole",
      "tag": "block"
    }
  ]
}
EOF

xray -test -config "${CFG}"
systemctl enable xray
systemctl restart xray

cat > "${META}" <<EOF
{
  "endpoint": "${ENDPOINT}",
  "port": ${PORT},
  "ws_path": "${WS_PATH}",
  "security": "none",
  "host": "",
  "sni": ""
}
EOF
chmod 600 "${META}"

if command -v ufw >/dev/null 2>&1; then
  ufw allow "${PORT}"/tcp || true
fi

echo
echo "Installed VLESS + WS server."
echo "Endpoint: ${ENDPOINT}"
echo "Port: ${PORT}"
echo "Path: ${WS_PATH}"
echo
echo "Client URI:"
echo "vless://${UUID}@${ENDPOINT}:${PORT}?type=ws&encryption=none&path=${ENCODED_PATH}&host=&security=none#family-main"
echo
echo "If you use a cloud firewall (Vultr), also allow TCP ${PORT} there."
