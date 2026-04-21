#!/usr/bin/env bash

set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "Run this script as root: sudo bash install_wireguard.sh"
  exit 1
fi

if [[ $# -lt 1 || $# -gt 3 ]]; then
  cat <<'EOF'
Usage:
  sudo bash install_wireguard.sh <server_public_ip_or_dns> [client_count] [listen_port]

Examples:
  sudo bash install_wireguard.sh 203.0.113.10
  sudo bash install_wireguard.sh vpn.example.com 3 51820
EOF
  exit 1
fi

SERVER_ENDPOINT="$1"
CLIENT_COUNT="${2:-3}"
LISTEN_PORT="${3:-51820}"
WG_DIR="/etc/wireguard"
WG_CONF="${WG_DIR}/wg0.conf"
CLIENT_DIR="/root/wireguard-clients"
SERVER_VPN_IP="10.66.66.1/24"
SERVER_VPN_ADDR="10.66.66.1"
CLIENT_NET_PREFIX="10.66.66"

if ! [[ "${CLIENT_COUNT}" =~ ^[0-9]+$ ]] || (( CLIENT_COUNT < 1 || CLIENT_COUNT > 50 )); then
  echo "client_count must be a number between 1 and 50."
  exit 1
fi

if ! [[ "${LISTEN_PORT}" =~ ^[0-9]+$ ]] || (( LISTEN_PORT < 1 || LISTEN_PORT > 65535 )); then
  echo "listen_port must be a valid TCP/UDP port number."
  exit 1
fi

if [[ -f "${WG_CONF}" ]]; then
  echo "${WG_CONF} already exists. Refusing to overwrite an existing WireGuard setup."
  echo "If you want to add another device later, use add_wireguard_client.sh instead."
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y wireguard wireguard-tools qrencode iptables

mkdir -p "${WG_DIR}" "${CLIENT_DIR}"
chmod 700 "${WG_DIR}" "${CLIENT_DIR}"

SERVER_PRIVATE_KEY="$(wg genkey)"
SERVER_PUBLIC_KEY="$(printf '%s' "${SERVER_PRIVATE_KEY}" | wg pubkey)"
SERVER_MAIN_IFACE="$(ip route get 1.1.1.1 | awk '/dev/ {print $5; exit}')"

if [[ -z "${SERVER_MAIN_IFACE}" ]]; then
  echo "Could not detect the server's default network interface."
  exit 1
fi

cat > /etc/sysctl.d/99-wireguard-forward.conf <<'EOF'
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=1
EOF
sysctl --system >/dev/null

umask 077

cat > "${WG_CONF}" <<EOF
[Interface]
Address = ${SERVER_VPN_IP}
ListenPort = ${LISTEN_PORT}
PrivateKey = ${SERVER_PRIVATE_KEY}
SaveConfig = true
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o ${SERVER_MAIN_IFACE} -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o ${SERVER_MAIN_IFACE} -j MASQUERADE
EOF

for i in $(seq 1 "${CLIENT_COUNT}"); do
  CLIENT_NAME="family-${i}"
  CLIENT_IP="${CLIENT_NET_PREFIX}.$((i + 1))/32"
  CLIENT_PRIVATE_KEY="$(wg genkey)"
  CLIENT_PUBLIC_KEY="$(printf '%s' "${CLIENT_PRIVATE_KEY}" | wg pubkey)"
  CLIENT_CONF="${CLIENT_DIR}/${CLIENT_NAME}.conf"

  cat >> "${WG_CONF}" <<EOF

[Peer]
PublicKey = ${CLIENT_PUBLIC_KEY}
AllowedIPs = ${CLIENT_IP}
EOF

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
done

systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0

if command -v ufw >/dev/null 2>&1; then
  ufw allow "${LISTEN_PORT}"/udp || true
fi

echo
echo "WireGuard server is up."
echo "Server public key:"
echo "${SERVER_PUBLIC_KEY}"
echo
echo "Client configs are in ${CLIENT_DIR}:"
ls -1 "${CLIENT_DIR}"
echo
echo "To show a QR code for a phone client:"
echo "  qrencode -t ansiutf8 < ${CLIENT_DIR}/family-1.conf"
