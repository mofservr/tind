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

## 2. Enrolling a device (nothing server-specific is in the image or the repository)

The image ships no endpoint, server key or subnet. Each device gets them in an **enrolment block** from you.

One-time setup on the server: copy `docs/server/tind-add-peer` to `/usr/local/sbin/` and create `/etc/tind-add-peer.conf`:

```sh
ENDPOINT=vpn.servr.no:51820   # a name devices can reach from anywhere; see "The endpoint name" below
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
   ```

3. Send the block back over a channel you trust. On the device: `sudo tind-enroll apply` and paste it (or `apply FILE`).

Running `tind-add-peer` again with the same key prints the same block. `sudo tind-add-peer --list` shows the devices. None of the values are secret, but whoever controls `DNS_SERVER` controls what `servr.no` names resolve to while the tunnel is up, so do not take the block from an untrusted source.

### The endpoint name

Use a name, not the IP, so the repository and the image never contain your address. `vpn.servr.no` works: a public A record gives the IP, and your resolver on the tunnel address can answer the same name with the same public IP, so the lookup works whether or not the tunnel is up. Inside your own network, answer it with the server's LAN address so a device at home connects directly and does not depend on NAT hairpinning.

### What names resolve to inside the tunnel

Only addresses listed in `ALLOWED_IPS` go through the tunnel. If your resolver answers `*.servr.no` with a LAN address such as `192.168.1.37` for tunnel clients, that traffic never enters the tunnel. Either have the tunnel-side resolver answer service names with the server's tunnel address (`10.0.0.1`, with the services listening on it), or set `ALLOWED_IPS` in `/etc/tind-add-peer.conf` to also include the LAN address as a `/32`. The first avoids clashes with a friend's home network using the same `192.168.1.x` range.

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
