"""Where a provider's service may connect: the API host, resolved once by the root helper (netallow) into
/run/tind-ai/hosts-<provider>.json. The firewall admits exactly those addresses and ports for tind-ai-remote, and
the client connects to those addresses (with TLS checked against the host name), so it needs no DNS of its own."""
import ipaddress
import json
import socket
import urllib.parse

RUN_DIR = '/run/tind-ai'


def parse(base_url):
    """(scheme, host, port, path) of a provider's base URL. Plain http only to this computer (a local model server)."""
    u = urllib.parse.urlsplit(base_url)
    if u.scheme not in ('https', 'http') or not u.hostname:
        raise ValueError('the endpoint must be an http(s) URL: %r' % base_url)
    port = u.port or (443 if u.scheme == 'https' else 80)
    if u.scheme == 'http':
        try:
            local = ipaddress.ip_address(u.hostname).is_loopback
        except ValueError:
            local = u.hostname == 'localhost'
        if not local:
            raise ValueError('plain http is only allowed to this computer (127.0.0.1); use https')
    return u.scheme, u.hostname, port, u.path.rstrip('/')


def resolve(host, port):
    addrs = []
    for fam, _t, _p, _c, sa in socket.getaddrinfo(host, port, type=socket.SOCK_STREAM):
        if fam in (socket.AF_INET, socket.AF_INET6) and sa[0] not in addrs:
            addrs.append(sa[0])
    if not addrs:
        raise OSError('no address for %s' % host)
    return addrs


def hosts_file(provider):
    return '%s/hosts-%s.json' % (RUN_DIR, provider)


def load(provider):
    with open(hosts_file(provider), encoding='utf-8') as f:
        return json.load(f)
