# Family VPN Server with VLESS + WebSocket

This repo is now focused on `Xray VLESS + WS` because your tested profile is working in your network:

```text
vless://UUID@HOST:80?type=ws&encryption=none&path=%2F&host=&security=none
```

This setup reproduces that pattern on your own VPS.

It now supports two modes:

- `Compatibility mode`: WS without TLS (`security=none`) to match your current working profile
- `Safer mode`: WSS/TLS on `443` using Caddy + Let's Encrypt

## What this setup does

- Installs Xray using the official XTLS installer script
- Creates either:
  - `VLESS + WS` on port `80` (`security=none`)
  - `VLESS + WS + TLS` on port `443` (`security=tls`)
- Opens the selected TCP port in `ufw` (if installed)
- Generates a ready-to-share client URI

## Files in this repo

- `install_vless_ws.sh`: compatibility setup (`security=none`)
- `install_vless_wss_tls.sh`: safer TLS setup (`security=tls`, `443`)
- `add_vless_client.sh`: add extra users/devices later (auto-detects TLS or non-TLS mode)

## Mode A: Compatibility (your current style)

```bash
git clone https://github.com/Fear-moonlight/WG_Family.git
cd WG_Family
chmod +x install_vless_ws.sh install_vless_wss_tls.sh add_vless_client.sh
sudo bash install_vless_ws.sh YOUR_PUBLIC_IP_OR_DOMAIN 80 /
```

Example:

```bash
sudo bash install_vless_ws.sh 173.199.92.49 80 /
```

At the end, the script prints a `vless://...` URI.

## Mode B: Safer TLS (recommended)

Requirements:

- A domain you control, pointed to your VPS public IP (A record)
- Ports `80` and `443` open in VPS firewall

Install:

```bash
sudo bash install_vless_wss_tls.sh vpn.example.com admin@example.com /ws
```

This will:

- keep Xray on local `127.0.0.1:10000`
- terminate TLS in Caddy on `443`
- issue certificates automatically with Let's Encrypt
- print a TLS client URI

## Add separate users

Create one user per device so you can revoke people independently.

```bash
sudo bash add_vless_client.sh mom-iphone vpn.example.com
sudo bash add_vless_client.sh dad-laptop vpn.example.com
```

Each run creates a new UUID and prints a new URI. The script auto-builds the right URI format based on server mode.

## iPhone usage

1. Install a V2Ray/Xray-compatible iOS client app.
2. Import by URI.
3. Paste the generated `vless://...` link.
4. Connect.

## Important notes

- Non-TLS WS mode is easier to fingerprint by DPI than TLS mode.
- TLS mode is safer, but requires a working domain and open `80/443`.
- If TLS mode starts getting blocked, the next upgrade path is `VLESS + REALITY`.

## Verify on server

```bash
sudo systemctl status xray --no-pager
sudo systemctl status caddy --no-pager
sudo ss -ltnp | grep xray
sudo journalctl -u xray -n 50 --no-pager
sudo journalctl -u caddy -n 50 --no-pager
```

## Sources

- [Project X VLESS inbound docs](https://xtls.github.io/en/config/inbounds/vless.html)
- [Project X WebSocket transport docs](https://xtls.github.io/en/config/transports/websocket)
- [XTLS official install script](https://github.com/XTLS/Xray-install)
