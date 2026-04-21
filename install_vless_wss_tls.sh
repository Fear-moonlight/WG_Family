#!/usr/bin/env bash

set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "Run as root: sudo bash install_vless_wss_tls.sh <domain> <email> [ws_path]"
  exit 1
fi

if [[ $# -lt 2 || $# -gt 3 ]]; then
  cat <<'EOF'
Usage:
  sudo bash install_vless_wss_tls.sh <domain> <email> [ws_path]

Example:
  sudo bash install_vless_wss_tls.sh vpn.example.com admin@example.com /ws
EOF
  exit 1
fi

DOMAIN="$1"
EMAIL="$2"
WS_PATH="${3:-/}"
CFG="/usr/local/etc/xray/config.json"
META="/usr/local/etc/xray/vless_meta.json"
CADDYFILE="/etc/caddy/Caddyfile"
XRAY_LOCAL_PORT="10000"
PUBLIC_PORT="443"

if [[ "${WS_PATH:0:1}" != "/" ]]; then
  echo "ws_path must start with '/'. Example: /ws"
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y curl jq uuid-runtime caddy

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
      "tag": "vless-ws-local",
      "listen": "127.0.0.1",
      "port": ${XRAY_LOCAL_PORT},
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

if [[ "${WS_PATH}" == "/" ]]; then
  CADDY_PATH_MATCH="/*"
else
  CADDY_PATH_MATCH="${WS_PATH}*"
fi

cat > "${CADDYFILE}" <<EOF
{
  email ${EMAIL}
}

${DOMAIN} {
  encode zstd gzip
  @vless path ${CADDY_PATH_MATCH}
  reverse_proxy @vless 127.0.0.1:${XRAY_LOCAL_PORT}
  respond "ok" 200
}
EOF

caddy validate --config "${CADDYFILE}"

systemctl enable xray
systemctl restart xray

systemctl enable caddy
systemctl restart caddy

cat > "${META}" <<EOF
{
  "endpoint": "${DOMAIN}",
  "port": ${PUBLIC_PORT},
  "ws_path": "${WS_PATH}",
  "security": "tls",
  "host": "${DOMAIN}",
  "sni": "${DOMAIN}"
}
EOF
chmod 600 "${META}"

if command -v ufw >/dev/null 2>&1; then
  ufw allow 80/tcp || true
  ufw allow 443/tcp || true
fi

echo
echo "Installed VLESS + WS + TLS (WSS) via Caddy."
echo "Domain: ${DOMAIN}"
echo "Public port: ${PUBLIC_PORT}"
echo "WS path: ${WS_PATH}"
echo
echo "Client URI:"
echo "vless://${UUID}@${DOMAIN}:${PUBLIC_PORT}?type=ws&encryption=none&path=${ENCODED_PATH}&host=${DOMAIN}&security=tls&sni=${DOMAIN}#family-main"
echo
echo "Make sure your domain A record points to this VPS public IP."
echo "Also allow TCP 80 and 443 in your VPS provider firewall."
