"""Fixed redaction rules for briefings (layer 1 of 3; the local model pass and the human preview follow).

Every hit becomes a numbered placeholder, the same value always the same number within one briefing, so the
remote AI can still see that two lines mention the same address or user without seeing the address or user.
"""
import ipaddress
import pwd
import re
import socket

# Patterns run in this order: whole blocks and tokens first, so their parts are not picked up as something else.
PRIVATE_KEY = re.compile(r'-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----.*?(?:-----END [A-Z0-9 ]*PRIVATE KEY-----|\Z)', re.S)
TOKENS = re.compile(r'''(?x)
    \b(?:
        sk-(?:ant-|proj-)?[A-Za-z0-9_-]{16,}          # OpenAI, Anthropic style keys
      | gh[pousr]_[A-Za-z0-9]{20,} | github_pat_[A-Za-z0-9_]{20,}
      | glpat-[A-Za-z0-9_-]{16,}
      | xox[abprs]-[A-Za-z0-9-]{10,}
      | AKIA[0-9A-Z]{16}
      | AIza[0-9A-Za-z_-]{35}
      | eyJ[A-Za-z0-9_-]{8,}\.eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}   # JWT
    )''')
# key=value or key: value where the key says it is a secret; the value goes, the key stays readable
SECRET_KV = re.compile(r'''(?ix)
    \b((?:pass(?:word|wd|phrase)?|pwd|secret|token|api[_-]?key|apikey|access[_-]?key|private[_-]?key|
          client[_-]?secret|auth(?:orization)?|bearer|cookie|session(?:id)?|psk|wpa[_-]?psk)
       ["']?\s*[:=]\s*(?:bearer\s+|basic\s+)?)
    (["']?)(?!\[|(?:bearer|basic)\s)([^\s"',;]{3,})''')
BEARER = re.compile(r'(?i)\b(bearer|basic)\s+([A-Za-z0-9._~+/=-]{12,})')
EMAIL = re.compile(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b')
MAC = re.compile(r'\b[0-9A-Fa-f]{2}(?::[0-9A-Fa-f]{2}){5}\b|\b[0-9A-Fa-f]{2}(?:-[0-9A-Fa-f]{2}){5}\b')
UUID = re.compile(r'\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\b')
IPV4 = re.compile(r'(?<![\d.])(?:\d{1,3}\.){3}\d{1,3}(?![\d.])')
IPV6 = re.compile(r'(?<![0-9A-Fa-f:])(?:[0-9A-Fa-f]{0,4}:){2,7}[0-9A-Fa-f]{0,4}(?![0-9A-Fa-f:])')
LONG_HEX = re.compile(r'\b[0-9a-fA-F]{40,}\b')
LONG_B64 = re.compile(r'(?<![A-Za-z0-9+/=])(?=[A-Za-z0-9+/]*[0-9])(?=[A-Za-z0-9+/]*[a-z])(?=[A-Za-z0-9+/]*[A-Z])[A-Za-z0-9+/]{40,}={0,2}')

KEEP_IPS = {'127.0.0.1', '0.0.0.0', '255.255.255.255', '127.0.0.53'}
# words that name the system, not a person: a login or real-name part from this list is never replaced (the live
# session's user is "tind", "Debian Live user"; replacing those would blank every tind-* package and "user" in a log)
STOP = {'tind', 'debian', 'live', 'user', 'users', 'root', 'admin', 'guest', 'steam', 'gnome', 'linux', 'test',
        'home', 'default', 'system', 'local', 'desktop', 'laptop', 'computer', 'owner'}


class Redactor:
    def __init__(self, extra_names=()):
        self.maps = {}        # kind -> {value: placeholder}
        self.counts = {}      # kind -> hits
        self.names = self._names(extra_names)

    @staticmethod
    def _names(extra):
        """Login names and real names of every normal user, the host name and the machine id."""
        words = {}
        for p in pwd.getpwall():
            if 1000 <= p.pw_uid < 60000 and not p.pw_name.startswith('tind-ai-'):
                if p.pw_name.lower() not in STOP:
                    words[p.pw_name] = 'user'
                real = p.pw_gecos.split(',')[0].strip()
                parts = [w for w in real.split() if len(w) >= 3 and w.lower() not in STOP]
                if parts and len(real) >= 3:
                    words[real] = 'name'
                    for part in parts:
                        words.setdefault(part, 'name')
        for h in {socket.gethostname(), socket.gethostname().split('.')[0]}:
            if h and h not in ('localhost', 'debian', 'tind'):
                words[h] = 'host'
        for path in ('/etc/machine-id', '/var/lib/dbus/machine-id'):
            try:
                with open(path, encoding='ascii') as f:
                    mid = f.read().strip()
                if mid:
                    words[mid] = 'machine-id'
            except OSError:
                pass
        try:
            with open('/etc/machine-info', encoding='utf-8') as f:
                for line in f:
                    if line.startswith('PRETTY_HOSTNAME='):
                        v = line.split('=', 1)[1].strip().strip('"')
                        if len(v) >= 3:
                            words[v] = 'host'
        except OSError:
            pass
        for w in extra:
            if w and len(w) >= 3 and w.lower() not in STOP:
                words[w] = 'name'
        return words

    def _ph(self, kind, value):
        m = self.maps.setdefault(kind, {})
        if value not in m:
            m[value] = '[%s-%d]' % (kind, len(m) + 1)
        self.counts[kind] = self.counts.get(kind, 0) + 1
        return m[value]

    def _sub(self, pattern, kind, text, keep=None):
        def rep(mt):
            v = mt.group(0)
            if keep and keep(v):
                return v
            return self._ph(kind, v)
        return pattern.sub(rep, text)

    @staticmethod
    def _keep_ipv4(v):
        try:
            ip = ipaddress.IPv4Address(v)
        except ValueError:
            return True                      # 999.1.1.1 is not an address: leave it
        return v in KEEP_IPS or ip.is_loopback

    @staticmethod
    def _keep_ipv6(v):
        groups = [g for g in v.split(':') if g]
        if '::' not in v and len(groups) < 3:
            return True
        # clock times (21:15:03) and other short all-digit groups are not addresses
        if all(g.isdigit() and len(g) <= 2 for g in groups):
            return True
        try:
            ip = ipaddress.IPv6Address(v)
        except ValueError:
            return True
        return ip.is_loopback or ip.is_unspecified

    def text(self, s):
        s = PRIVATE_KEY.sub(lambda m: self._ph('private-key', m.group(0)), s)
        s = TOKENS.sub(lambda m: self._ph('token', m.group(0)), s)
        s = BEARER.sub(lambda m: m.group(1) + ' ' + self._ph('secret', m.group(2)), s)
        s = SECRET_KV.sub(lambda m: m.group(1) + m.group(2) + self._ph('secret', m.group(3)), s)
        s = self._sub(EMAIL, 'email', s)
        s = self._sub(MAC, 'mac', s)
        s = self._sub(UUID, 'uuid', s)
        s = self._sub(IPV4, 'ip', s, self._keep_ipv4)
        s = self._sub(IPV6, 'ip', s, self._keep_ipv6)
        s = self._sub(LONG_HEX, 'blob', s)
        s = self._sub(LONG_B64, 'blob', s)
        # names last, longest first, as whole words (a user called "tom" does not touch "atom")
        for word in sorted(self.names, key=len, reverse=True):
            kind = self.names[word]
            pat = re.compile(r'(?<![A-Za-z0-9_])' + re.escape(word) + r'(?![A-Za-z0-9_])')
            s = pat.sub(lambda m, k=kind, w=word: self._ph(k, w), s)
        return s

    def state(self):
        """The value -> placeholder maps, so the next message of the same conversation keeps the same numbers.
        These hold the real values: they are kept where only tind-ai-local can read them."""
        return self.maps

    def load(self, maps):
        for kind, m in (maps or {}).items():
            if isinstance(m, dict):
                self.maps[kind] = {str(k): str(v) for k, v in m.items()}

    def summary(self):
        return dict(sorted(self.counts.items()))

