"""Shared pieces of the Tind AI box: paths, the provider list, and the small JSON-over-Unix-socket protocol.

Every service speaks one JSON object per line over a stream socket. The caller's user id comes from the kernel
(SO_PEERCRED), never from the message, so a human can only ever reach their own briefings and answers.
"""
import json
import os
import pwd
import select
import socket
import struct

BRIEF_DIR = '/var/lib/tind-ai/briefing'
OUTBOX_DIR = '/var/lib/tind-ai/outbox'
RUN_DIR = '/run/tind-ai'
KEYS_DIR = '/etc/tind-ai/keys'
READY_DIR = '/etc/tind-ai/ready'          # one empty file per provider that has a key (readable by everyone)
CUSTOM_FILE = '/etc/tind-ai/custom.json'  # the custom endpoint (base_url, model), written by the root helper
PROVIDERS_FILE = '/usr/share/tind-ai/providers.json'
LOCAL_SOCKET = RUN_DIR + '/local.sock'
MAX_LINE = 4 * 1024 * 1024                # one request or answer, at most


def remote_socket(provider):
    return '%s/remote-%s.sock' % (RUN_DIR, provider)


def providers():
    """The provider list, with the custom endpoint filled in from /etc/tind-ai/custom.json when it exists."""
    with open(PROVIDERS_FILE, encoding='utf-8') as f:
        data = json.load(f)
    try:
        with open(CUSTOM_FILE, encoding='utf-8') as f:
            custom = json.load(f)
    except (OSError, ValueError):
        custom = {}
    for p in data['providers']:
        if p['id'] == 'custom' and custom.get('base_url'):
            p['base_url'] = custom['base_url']
            if custom.get('model'):
                p['models'] = [{'id': custom['model'], 'label': custom['model'], 'use': 'everyday'}]
    return data['providers']


def provider(pid):
    for p in providers():
        if p['id'] == pid:
            return p
    raise KeyError('unknown provider: %s' % pid)


def is_human(uid):
    """A normal login account: uid 1000-59999 and not one of the AI users."""
    if not 1000 <= uid < 60000:
        return False
    try:
        name = pwd.getpwuid(uid).pw_name
    except KeyError:
        return False
    return not name.startswith('tind-ai-')


def peer_uid(conn):
    creds = conn.getsockopt(socket.SOL_SOCKET, socket.SO_PEERCRED, struct.calcsize('3i'))
    _pid, uid, _gid = struct.unpack('3i', creds)
    return uid


def read_msg(conn):
    buf = b''
    while b'\n' not in buf:
        chunk = conn.recv(65536)
        if not chunk:
            break
        buf += chunk
        if len(buf) > MAX_LINE:
            raise ValueError('message too large')
    line = buf.split(b'\n', 1)[0]
    if not line:
        raise ValueError('empty message')
    return json.loads(line.decode('utf-8'))


def send_msg(conn, obj):
    conn.sendall(json.dumps(obj, ensure_ascii=False).encode('utf-8') + b'\n')


def call(path, obj, timeout=300):
    """Client side: send one request to a service socket and return its answer."""
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.settimeout(timeout)
    try:
        s.connect(path)
        send_msg(s, obj)
        return read_msg(s)
    finally:
        s.close()


def serve(handle, idle=120):
    """Serve connections on the socket systemd passed in (fd 3), one at a time; exit after `idle` quiet seconds.

    handle(uid, request) returns the answer object. Errors become {"ok": false, "error": ...}.
    """
    if os.environ.get('LISTEN_FDS') != '1':
        raise SystemExit('expected exactly one socket from systemd (LISTEN_FDS=1)')
    lsock = socket.socket(fileno=3)
    while True:
        ready, _, _ = select.select([lsock], [], [], idle)
        if not ready:
            return
        conn, _ = lsock.accept()
        with conn:
            conn.settimeout(600)
            try:
                uid = peer_uid(conn)
                if not is_human(uid):
                    raise PermissionError('only a normal login user may ask')
                answer = handle(uid, read_msg(conn))
            except Exception as e:  # noqa: BLE001 - every failure goes back to the window as text
                answer = {'ok': False, 'error': '%s: %s' % (type(e).__name__, e)}
            try:
                send_msg(conn, answer)
            except OSError:
                pass


def _acl(owner_perm, users, mask, default=False):
    """A POSIX ACL in the kernel's xattr format: owner, the named users (sorted), owning group none, mask, other none."""
    und = 0xFFFFFFFF
    ent = [(0x01, owner_perm, und)] + [(0x02, perm, u) for u, perm in sorted(users.items())]
    ent += [(0x04, 0, und), (0x10, mask, und), (0x20, 0, und)]
    return struct.pack('<I', 2) + b''.join(struct.pack('<HHI', t, p, i) for t, p, i in ent)


def user_dir(base, uid, readers):
    """base/<uid>: owned by this service user, mode 0700 plus an ACL that lets `readers` (uids) into the folder and
    read every file made in it later (default ACL). Nobody else, not even the other AI user, gets in."""
    path = os.path.join(base, str(uid))
    if not os.path.isdir(path):
        os.mkdir(path, 0o700)
        os.setxattr(path, 'system.posix_acl_access', _acl(7, {r: 5 for r in readers}, 5))
        os.setxattr(path, 'system.posix_acl_default', _acl(6, {r: 4 for r in readers}, 4))
    return path


def write_json(path, obj):
    """Create path with mode 0640 (the folder's default ACL gives the readers r), atomically."""
    tmp = path + '.tmp'
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o640)
    with os.fdopen(fd, 'w', encoding='utf-8') as f:
        json.dump(obj, f, ensure_ascii=False, indent=1)
    os.rename(tmp, path)


def prune(path, keep=50):
    """Keep the newest `keep` .json files in path."""
    files = sorted((f for f in os.listdir(path) if f.endswith('.json')),
                   key=lambda f: os.path.getmtime(os.path.join(path, f)), reverse=True)
    for f in files[keep:]:
        try:
            os.unlink(os.path.join(path, f))
        except OSError:
            pass
