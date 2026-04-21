# Family VPN Server with VLESS + WebSocket

This repo is now focused on `Xray VLESS + WS` because your tested profile is working in your network:

```text
vless://UUID@HOST:80?type=ws&encryption=none&path=%2F&host=&security=none
```

This setup reproduces that pattern on your own VPS.

## What this setup does

- Installs Xray using the official XTLS installer script
- Creates a `VLESS + WebSocket` inbound on port `80` by default
- Uses `security=none` to match your working link style
- Opens the selected TCP port in `ufw` (if installed)
- Generates a ready-to-share client URI

## Files in this repo

- `install_vless_ws.sh`: first-time setup and first client creation
- `add_vless_client.sh`: add extra users/devices later

## Quick install on server

```bash
git clone https://github.com/Fear-moonlight/WG_Family.git
cd WG_Family
chmod +x install_vless_ws.sh add_vless_client.sh
sudo bash install_vless_ws.sh YOUR_PUBLIC_IP_OR_DOMAIN 80 /
```

Example:

```bash
sudo bash install_vless_ws.sh 173.199.92.49 80 /
```

At the end, the script prints a `vless://...` URI.

## Add separate users

Create one user per device so you can revoke people independently.

```bash
sudo bash add_vless_client.sh mom-iphone 173.199.92.49
sudo bash add_vless_client.sh dad-laptop 173.199.92.49
```

Each run creates a new UUID and prints a new URI.

## iPhone usage

1. Install a V2Ray/Xray-compatible iOS client app.
2. Import by URI.
3. Paste the generated `vless://...` link.
4. Connect.

## Important notes

- This is `WS over TCP` without TLS, because we are intentionally matching your currently working format.
- Without TLS, traffic is easier to fingerprint than proper `WSS/TLS` or `REALITY`.
- If this starts failing again, the next upgrade path is `VLESS + REALITY` or `WSS + TLS` on `443`.

## Verify on server

```bash
sudo systemctl status xray --no-pager
sudo ss -ltnp | grep xray
sudo journalctl -u xray -n 50 --no-pager
```

## Sources

- [Project X VLESS inbound docs](https://xtls.github.io/en/config/inbounds/vless.html)
- [Project X WebSocket transport docs](https://xtls.github.io/en/config/transports/websocket)
- [XTLS official install script](https://github.com/XTLS/Xray-install)
