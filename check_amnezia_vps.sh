#!/usr/bin/env bash

set -euo pipefail

pass() {
  printf '[PASS] %s\n' "$1"
}

warn() {
  printf '[WARN] %s\n' "$1"
}

info() {
  printf '[INFO] %s\n' "$1"
}

os_name="$(. /etc/os-release && echo "${NAME:-unknown}")"
os_version="$(. /etc/os-release && echo "${VERSION_ID:-unknown}")"
arch="$(uname -m)"
kernel="$(uname -r)"
virt="$(systemd-detect-virt 2>/dev/null || true)"
ram_mb="$(awk '/MemTotal/ { printf "%d", $2 / 1024 }' /proc/meminfo)"
disk_avail_gb="$(df -BG / | awk 'NR==2 {gsub(/G/, "", $4); print $4}')"
ipv4="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '/src/ {print $7; exit}')"

info "OS: ${os_name} ${os_version}"
info "Kernel: ${kernel}"
info "Arch: ${arch}"
info "Virtualization: ${virt:-unknown}"
info "RAM: ${ram_mb} MB"
info "Free disk on /: ${disk_avail_gb} GB"
info "Detected IPv4: ${ipv4:-none}"

case "${os_name} ${os_version}" in
  "Ubuntu 22.04"|"Ubuntu 24.04"|"Debian GNU/Linux 12"|"Debian GNU/Linux 13")
    pass "Supported OS/version for the official Amnezia self-hosted workflow."
    ;;
  *)
    warn "OS/version is outside the officially supported list."
    ;;
esac

case "${arch}" in
  x86_64|amd64)
    pass "Supported CPU architecture."
    ;;
  *)
    warn "CPU architecture is not officially supported by Amnezia's VPS workflow."
    ;;
esac

if [[ -n "${virt}" && "${virt}" == "kvm" ]]; then
  pass "KVM virtualization detected."
elif [[ -z "${virt}" || "${virt}" == "none" ]]; then
  warn "Could not confirm KVM virtualization. Check with your VPS provider."
else
  warn "Detected virtualization '${virt}', while official docs prefer KVM."
fi

if [[ -n "${ipv4}" ]]; then
  pass "Public IPv4 appears to be available from the routing table."
else
  warn "Could not detect a usable IPv4 route."
fi

if (( ram_mb >= 1024 )); then
  pass "RAM meets the 1 GB minimum."
else
  warn "Less than 1 GB RAM detected."
fi

if (( disk_avail_gb >= 10 )); then
  pass "Disk space meets the 10 GB minimum."
else
  warn "Less than 10 GB free disk detected on /."
fi

kernel_major="$(printf '%s' "${kernel}" | cut -d. -f1)"
kernel_minor="$(printf '%s' "${kernel}" | cut -d. -f2)"

if (( kernel_major > 4 || (kernel_major == 4 && kernel_minor >= 14) )); then
  pass "Kernel version meets the AmneziaWG 2.0 minimum."
else
  warn "Kernel version appears older than 4.14."
fi

echo
info "Next step: install the latest AmneziaVPN app on your admin device and let it SSH into this server."
