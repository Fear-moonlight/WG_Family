#!/usr/bin/env bash

set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "Run this script as root: sudo bash add_wireguard_client.sh"
  exit 1
fi

if [[ $# -lt 2 || $# -gt 3 ]]; then
  cat <<'EOF'
Usage:
  sudo bash add_wireguard_client.sh <client_name> <server_public_ip_or_dns> [listen_port]

Example:
  sudo bash add_wireguard_client.sh mom vpn.example.com 51820
EOF
  exit 1
fi

CLIENT_NAME="$1"
SERVER_ENDPOINT="$2"
LISTEN_PORT="${3:-51820}"
WG_CONF="/etc/wireguard/wg0.conf"
CLIENT_DIR="/root/wireguard-clients"

if [[ ! -f "${WG_CONF}" ]]; then
  echo "WireGuard server config not found at ${WG_CONF}."
  exit 1
fi

if [[ ! "${CLIENT_NAME}" =~ ^[a-zA-Z0-9_-]+$ ]]; then
  echo "client_name may only contain letters, numbers, _ and -"
  exit 1
fi

mkdir -p "${CLIENT_DIR}"

if [[ -f "${CLIENT_DIR}/${CLIENT_NAME}.conf" ]]; then
  echo "Client config ${CLIENT_DIR}/${CLIENT_NAME}.conf already exists."
  exit 1
fi

SERVER_PUBLIC_KEY="$(wg show wg0 public-key)"
LAST_IP_OCTET="$(
  awk -F '[ ./]+' '
    /AllowedIPs = 10\.66\.66\./ { print $4 }
  ' "${WG_CONF}" | sort -n | tail -1
)"

if [[ -z "${LAST_IP_OCTET}" ]]; then
  NEXT_IP_OCTET=2
else
  NEXT_IP_OCTET=$((LAST_IP_OCTET + 1))
fi

if (( NEXT_IP_OCTET > 254 )); then
  echo "No more client addresses available in 10.66.66.0/24."
  exit 1
fi

CLIENT_IP="10.66.66.${NEXT_IP_OCTET}/32"
CLIENT_PRIVATE_KEY="$(wg genkey)"
CLIENT_PUBLIC_KEY="$(printf '%s' "${CLIENT_PRIVATE_KEY}" | wg pubkey)"
CLIENT_CONF="${CLIENT_DIR}/${CLIENT_NAME}.conf"

cat >> "${WG_CONF}" <<EOF

[Peer]
PublicKey = ${CLIENT_PUBLIC_KEY}
AllowedIPs = ${CLIENT_IP}
EOF

wg syncconf wg0 <(wg-quick strip wg0)

cat > "${CLIENT_CONF}" <<EOF
[Interface]
PrivateKey = ${CLIENT_PRIVATE_KEY}
Address = ${CLIENT_IP}
DNS = 1.1.1.1, 8.8.8.8

[Peer]
PublicKey = ${SERVER_PUBLIC_KEY}
Endpoint = ${SERVER_ENDPOINT}:${LISTEN_PORT}
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
EOF

chmod 600 "${CLIENT_CONF}"

echo "Created ${CLIENT_CONF}"
echo "QR code:"
qrencode -t ansiutf8 < "${CLIENT_CONF}"
