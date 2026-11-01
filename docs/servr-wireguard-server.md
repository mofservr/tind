# Server side of the servr.no tunnel

**Status: server side ready (2026-10-18).** Real values are used below (tunnel `10.0.0.0/24`, server `10.0.0.1`, `vpn.servr.no:51820`). None of them is secret and no key is in the repository. Full server notes are in the serv'r project doc `claude/TIND.md`.

## Decisions

- **Split tunnel.** Only `10.0.0.0/24` and `*.servr.no` go through the tunnel (`ALLOWED_IPS=10.0.0.0/24`).
- **Names inside the tunnel (option A).** For queries arriving over the tunnel, `*.servr.no` resolves to `10.0.0.1` (a second dnsmasq that listens on `10.0.0.1` only). The LAN address `192.168.1.37` must **not** be in `ALLOWED_IPS`: it clashes with friends' `192.168.1.x` networks and, at home, sends the tunnel's own endpoint traffic back into the tunnel.
- **At home the tunnel uses the server's LAN address; everywhere else the public one** (31 Oct 2026; replaces "`vpn.servr.no` always resolves to the public IP"). The home router cannot carry gigabit LAN traffic, so at home the tunnel must not hairpin through it. Devices get the LAN address as `LAN_ENDPOINT` in their enrolment block and use it wherever the server answers on it, whatever DNS the network hands out. `vpn.servr.no` itself stays the public name; the tunnel's own resolver must never answer it with `10.0.0.1`, and it is never a tunnel-internal name.
- **Scope: only Morten's own devices.** Every enrolled device can reach every internal service (Caddy trusts `10.0.0.0/24`). Friends' and family's devices wait for a separate OPNsense WireGuard zone.
- `tind-add-peer` has no remove command yet. Remove a peer by hand on the server.
- Client side (`tind-wireguard` 0.3.2): `tind-enroll refresh` picks the endpoint address and writes it into the NetworkManager profile, so NetworkManager never looks the name up through the tunnel's own DNS. It tries `LAN_ENDPOINT` once per network (proven by a ping through the tunnel), otherwise looks `vpn.servr.no` up through the current network's DNS. The watchdog (`tind-wireguard-watchdog.timer`, every minute) runs it, and reconnects when the last handshake is older than 150 s. Split DNS needs `systemd-resolved` on the client (Tind has it active).

## Goal

Every Tind device keeps a background WireGuard connection to the server. Only the server's own addresses and names under `servr.no` go through it. Then services can stop listening on the public internet.

## 1. WireGuard endpoint on the server

```ini
# /etc/wireguard/wg0.conf
[Interface]
Address = 10.0.0.1/24
ListenPort = 51820
PrivateKey = <server private key, generated on the server: wg genkey>

# one block per device. /32 only, so a device can never claim another device's address
[Peer]
# morten-desktop
PublicKey = <device public key from `sudo tind-enroll init`>
AllowedIPs = 10.0.0.12/32
```

Enable with `systemctl enable --now wg-quick@wg0`. Open **UDP 51820** at the router and firewall. This is the only new public port.

Add a device without restarting: `wg set wg0 peer <pubkey> allowed-ips 10.0.0.12/32`, then add it to `wg0.conf` too.

## 2. Enrolling a device (nothing server-specific is in the image or the repository)

The image ships no endpoint, server key or subnet. Each device gets them in an **enrolment block** from you.

One-time setup on the server: copy `docs/server/tind-add-peer` to `/usr/local/sbin/` and create `/etc/tind-add-peer.conf`:

```sh
ENDPOINT=vpn.servr.no:51820          # public name; see "The endpoint name" below
LAN_ENDPOINT=<server LAN address>:51820   # optional; devices use it at home
# optional: WG_IF=wg0  POOL_START=10  ALLOWED_IPS=...  DNS_SERVER=...
```

Per device:

1. On the device: `sudo tind-enroll init`. It prints the device's public key.
2. Send that key and a device name to yourself. On the server: `sudo tind-add-peer laptop <public-key>`. It picks the next free address from `POOL_START` upward, adds the peer live and to `wg0.conf`, and prints the block:

   ```
   ADDRESS=10.0.0.10/32
   SERVER_ENDPOINT=vpn.servr.no:51820
   SERVER_PUBLIC_KEY=...
   ALLOWED_IPS=10.0.0.0/24
   DNS_SERVER=10.0.0.1
   LAN_ENDPOINT=<server LAN address>:51820
   ```

3. Send the block back over a channel you trust. On the device: `sudo tind-enroll apply` and paste it (or `apply FILE`).

Running `tind-add-peer` again with the same key prints the same block. `sudo tind-add-peer --list` shows the devices. None of the values are secret, but whoever controls `DNS_SERVER` controls what `servr.no` names resolve to while the tunnel is up, so do not take the block from an untrusted source.

### The endpoint name

Use a name, not the IP, so the repository and the image never contain your address. Tind devices look the name up through the DNS of the network they are on, never through the tunnel (`tind-enroll refresh`, run every minute by the watchdog). At home they use `LAN_ENDPOINT` instead, once a ping through the tunnel proves the server answers on it, so it works even where the router's DHCP hands out the ISP's DNS. For that the server must accept WireGuard on its LAN interface (UDP 51820). The LAN address must not be in `ALLOWED_IPS`, so endpoint traffic never loops into the tunnel (`tind-enroll` refuses a block that breaks this). A new home WAN IP or a move between networks is picked up within about a minute. Existing devices get `LAN_ENDPOINT` by running `tind-add-peer` again with their key (it prints the same block, now with the line) and `sudo tind-enroll apply` on the device.

### What names resolve to inside the tunnel

Only addresses listed in `ALLOWED_IPS` go through the tunnel, so the tunnel-side resolver answers `*.servr.no` with the server's tunnel address `10.0.0.1` (option A above), with the services listening on it. Do not add the LAN address to `ALLOWED_IPS`.

## 3. Names inside the tunnel

Devices send queries for `*.servr.no` to `DNS_SERVER` while the tunnel is up (systemd-resolved routing domain `~servr.no`). That server needs to answer them with addresses reachable inside the tunnel. If your resolver is dnsmasq, a second dnsmasq instance listens on `10.0.0.1` only and answers `*.servr.no` with `10.0.0.1`.

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

For finer control, restrict by source address: `ip saddr 10.0.0.12 tcp dport 443 accept` gives one device one service.

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
