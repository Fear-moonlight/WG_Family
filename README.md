# Family VPN Server on Ubuntu 22.04

This setup uses WireGuard on an Ubuntu 22.04 LTS server with a public IP.

## Why this setup

- WireGuard is simpler and faster to run than OpenVPN.
- It works well for a small family setup.
- It is easy to add phones, laptops, and tablets later.

## Important reality check for Iran in April 2026

- Iran has been under severe internet restrictions and long-duration disruptions in 2026.
- During a near-total or total shutdown of international connectivity, no normal VPS-based VPN can restore access because there is no usable outside path to reach your server.
- When some international connectivity is available, a personal WireGuard server is still a reasonable first option because it is simple, stable, and under your control.

## Files in this folder

- `install_wireguard.sh`: first-time server install and initial client generation
- `add_wireguard_client.sh`: add more devices later

## What to prepare

- Ubuntu 22.04 LTS server
- Public IPv4 address or DNS name
- SSH access as a sudo user
- UDP port `51820` open in the cloud firewall

## Install on the server

Copy these two files to the server, then run:

```bash
chmod +x install_wireguard.sh add_wireguard_client.sh
sudo bash install_wireguard.sh YOUR_SERVER_IP_OR_DNS 3 51820
```

Example:

```bash
sudo bash install_wireguard.sh 203.0.113.10 3 51820
```

That creates:

- the WireGuard server
- three client configs:
  - `/root/wireguard-clients/family-1.conf`
  - `/root/wireguard-clients/family-2.conf`
  - `/root/wireguard-clients/family-3.conf`

## Import on family devices

### iPhone / Android

1. Install the official WireGuard app.
2. On the server, show a QR code:

```bash
sudo qrencode -t ansiutf8 < /root/wireguard-clients/family-1.conf
```

3. In the phone app, scan the QR code.

### Windows / macOS / Linux

1. Install the WireGuard client.
2. Copy the `.conf` file securely to the device.
3. Import the tunnel.

## Add another family member later

```bash
sudo bash add_wireguard_client.sh mom YOUR_SERVER_IP_OR_DNS 51820
```

The new config will be written to:

```bash
/root/wireguard-clients/mom.conf
```

## Basic checks

On the server:

```bash
sudo systemctl status wg-quick@wg0
sudo wg show
sudo ss -lunp | grep 51820
```

On a connected device, confirm your public IP changed:

```bash
curl ifconfig.me
```

## Practical notes

- I assumed your Ubuntu version is `22.04`, since `22.24` is not a standard Ubuntu release.
- If your cloud provider has its own firewall or security group, you must allow inbound UDP `51820` there too.
- If your family still cannot connect from Iran, the likely cause is active filtering or a broader connectivity event, not a broken WireGuard config.
- In that case, the next fallback is usually to keep this WireGuard server as the simple baseline and add a second transport on a different server profile rather than changing family devices constantly.
