# Family VPN Server with AmneziaWG 2.0

This repo is now set up for `AmneziaWG 2.0`, not plain WireGuard.

AmneziaWG 2.0 is designed to make WireGuard-style traffic harder to identify by DPI by randomizing packet signatures and mimicking common UDP protocols such as QUIC or DNS. It is still `UDP`, not normal TCP HTTPS.

## Why this is the better fit

- Plain WireGuard has a recognizable fingerprint and is often easier to interfere with.
- AmneziaWG 2.0 is specifically built for censorship resistance.
- The officially supported setup path is to let the `AmneziaVPN` app connect to your VPS over SSH and install the server-side pieces for you.

## Important reality check for Iran in April 2026

- During a near-total international shutdown, no VPS VPN can help because users cannot reach the server at all.
- When some outside connectivity exists but DPI and protocol interference are active, `AmneziaWG 2.0` is a more realistic starting point than plain WireGuard.
- If UDP gets heavily degraded or blocked entirely on your users' networks, you may still need a TCP/TLS-based fallback later.

## Official requirements

Based on current Amnezia docs, a VPS should meet these requirements:

- OS: `Ubuntu 22.04.x` or `24.04.x`, or `Debian 12/13`
- Virtualization: `KVM`
- Public `IPv4` address
- SSH access as `root` or a passwordless `sudo` user
- CPU architecture: `x86-64 / amd64`
- RAM: `1 GB+`
- Disk: `10 GB+`
- Linux kernel: `4.14+` for AmneziaWG 2.0

Important: Amnezia docs say `arm64/aarch64` is not supported for their official VPS workflow.

## Files in this repo

- `check_amnezia_vps.sh`: preflight checker for the VPS before you try app-based installation
- `open_amnezia_port.sh`: helper to open the chosen UDP port in `ufw`

## Step 1: Clone on the server

```bash
git clone https://github.com/Fear-moonlight/WG_Family.git
cd WG_Family
chmod +x check_amnezia_vps.sh open_amnezia_port.sh
./check_amnezia_vps.sh
```

If the checker warns about virtualization, CPU architecture, or missing IPv4, fix those before going further.

## Step 2: Install AmneziaVPN on your own device

Install the latest `AmneziaVPN` app on the device you will use for administration:

- iPhone, iPad, or Mac
- Windows
- Android

Use version `4.8.12.9` or later for AmneziaWG 2.0 support.

## Step 3: Let the app install the server

In the AmneziaVPN app:

1. Add a new server.
2. Enter your VPS public IPv4, SSH username, and password or SSH key.
3. Choose `Automatic` setup or choose `AmneziaWG` manually.
4. Let the app connect by SSH and install the protocol.

The official docs say this is the supported way to install and manage self-hosted AmneziaWG 2.0.

## Step 4: Change the port immediately

Amnezia installs AmneziaWG with a random port by default.

The current docs explicitly recommend changing it to a port `<= 9999`, for example:

- `443` only if you are intentionally testing that path and are sure nothing else on the server needs it
- `585`
- `1234`
- `8443`

After you pick the port in the Amnezia app, open it on the server:

```bash
sudo bash open_amnezia_port.sh 1234
```

Also open the same UDP port in your cloud provider firewall or security group.

## Step 5: Create family device configs

In the AmneziaVPN app:

1. Open your server.
2. Open the installed `AmneziaWG` protocol.
3. Generate new guest connections for each family member.

The docs are clear that `AmneziaWG 2.0` requires new keys/configs. Old AmneziaWG legacy configs do not upgrade in place.

## iPhone use

For iPhone:

1. Install the latest `AmneziaVPN` app from the App Store.
2. From your admin device, share the guest connection with the family member.
3. Open or import that connection in the iPhone app.
4. Connect using the `AmneziaWG` profile created from the server.

Unlike plain WireGuard, the normal workflow here is app-managed sharing, not manually scanning a raw WireGuard QR code from the server.

## Basic checks on the server

After installation from the app, these commands are useful:

```bash
docker ps
sudo ss -lunp
ip -4 addr
uname -r
```

If you changed to port `1234`, check that it is listening:

```bash
sudo ss -lunp | grep 1234
```

## Troubleshooting notes

- If your family cannot connect, first try a lower UDP port under `9999`.
- Make sure the same UDP port is allowed both in `ufw` and in the VPS provider firewall.
- If the app version is older than `4.8.12.9`, AmneziaWG 2.0 guest configs may not work.
- If your VPS is `arm64`, `OpenVZ`, or `LXC`, the official installer path may fail.
- If the network blocks or degrades `UDP` completely, AmneziaWG may still struggle even though it is more DPI-resistant than plain WireGuard.

## Sources

- [Using AmneziaWG 2.0 Protocol on Self-Hosted Servers](https://amneziavpn.org/documentation/instructions/new-amneziawg-selfhosted/)
- [VPS Requirements](https://amneziavpn.org/documentation/supported-linux-os-for-vps)
- [Set Up a Self-Hosted VPN](https://amneziavpn.org/documentation/instructions/install-vpn-on-server)
- [AmneziaWG Overview](https://amneziavpn.org/documentation/amnezia-wg)
