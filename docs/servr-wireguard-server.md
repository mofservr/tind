# Server side of the servr.no tunnel (template)

**Status: untested template.** I have no access to your server and did not read its configuration. Everything below uses example values (`10.8.0.0/24`, port `51820`). Adapt before use.

## Goal

Every Tind device keeps a background WireGuard connection to the server. Only the server's own addresses and names under `servr.no` go through it. Then services can stop listening on the public internet.

## 1. WireGuard endpoint on the server

```ini
# /etc/wireguard/wg0.conf
[Interface]
Address = 10.8.0.1/24
ListenPort = 51820
PrivateKey = <server private key, generated on the server: wg genkey>

# one block per device. /32 only, so a device can never claim another device's address
[Peer]
# morten-desktop
PublicKey = <device public key from `sudo tind-enroll init`>
AllowedIPs = 10.8.0.12/32
```

Enable with `systemctl enable --now wg-quick@wg0`. Open **UDP 51820** at the router and firewall. This is the only new public port.

Add a device without restarting: `wg set wg0 peer <pubkey> allowed-ips 10.8.0.12/32`, then add it to `wg0.conf` too.

## 2. What the Tind side needs from you

Fill in `/etc/tind/servr-tunnel.conf` (it ships in the `tind-wireguard` package, so for the ISO edit `os/packages/tind-wireguard/etc/tind/servr-tunnel.conf` before building):

| Value | Example |
|---|---|
| `SERVER_ENDPOINT` | `vpn.servr.no:51820` (a name that resolves publicly) |
| `SERVER_PUBLIC_KEY` | output of `wg pubkey` on the server |
| `ALLOWED_IPS` | `10.8.0.0/24` |
| `DNS_SERVER` | `10.8.0.1` |

None of these are secret.

## 3. Names inside the tunnel

Devices send queries for `*.servr.no` to `DNS_SERVER` while the tunnel is up (systemd-resolved routing domain `~servr.no`). That server needs to answer them with addresses reachable inside the tunnel. If your resolver is dnsmasq, add `listen-address=10.8.0.1` and answer your service names with the server's tunnel-side address. I have not read your `dnsmasq.conf`.

## 4. Per-device firewall rules (nftables sketch)

```nft
table inet filter {
  chain input {
    type filter hook input priority 0; policy drop;
    ct state established,related accept
    iif lo accept
    udp dport 51820 accept                        # the tunnel itself
    iifname "wg0" tcp dport { 443 } accept        # services reachable only through the tunnel
    # tcp dport 22 ip saddr <your admin address> accept   # keep an emergency way in
  }
  chain forward {
    type filter hook forward priority 0; policy drop;   # devices must not reach each other
  }
}
```

For finer control, restrict by source address: `ip saddr 10.8.0.12 tcp dport 443 accept` gives one device one service.

## 5. Closing the public ports without locking yourself out

1. Bring up the tunnel and enrol **your own** device first.
2. Reach every service through the tunnel and check it all works (sync'r, minn'r, Authelia login flow, Nextcloud trusted domains).
3. Restrict one service at a time. A softer first step than closing the port: in Caddy, allow only the tunnel subnet with a `remote_ip` matcher.
4. Keep one way in that does not depend on the tunnel (SSH from a fixed address, or console access) until you trust the setup.
5. Only then close the public port at the router.

## 6. Devices that are not Tind

Phones, Windows and macOS need the official WireGuard app and a peer of their own. If family and friends reach sync'r or minn'r from phones, plan that before closing anything. The iOS app can activate the tunnel on demand and Android has an always-on VPN setting.

## 7. Risks to weigh (also in the build plan)

- The WireGuard endpoint becomes a dependency of every service behind it, against the rule that one outage should not follow into the rest.
- Every new device is an admin task (add a peer, assign an address).
- Authelia stays the accepted exception to service independence.
