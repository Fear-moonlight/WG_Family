#!/usr/bin/env bash

set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "Run this script as root: sudo bash open_amnezia_port.sh <udp_port>"
  exit 1
fi

if [[ $# -ne 1 ]]; then
  echo "Usage: sudo bash open_amnezia_port.sh <udp_port>"
  exit 1
fi

port="$1"

if ! [[ "${port}" =~ ^[0-9]+$ ]] || (( port < 1 || port > 65535 )); then
  echo "Please provide a valid UDP port number."
  exit 1
fi

if command -v ufw >/dev/null 2>&1; then
  ufw allow "${port}"/udp
  echo "Opened UDP ${port} in ufw."
else
  echo "ufw is not installed. Open UDP ${port} in your firewall manually."
fi

echo "Also remember to allow UDP ${port} in your VPS provider firewall."
