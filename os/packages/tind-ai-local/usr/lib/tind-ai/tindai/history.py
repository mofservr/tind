"""What a briefing sends of a chat's earlier turns (long chats, 28 Nov). Pure text work, no files, no network.

A chat goes back to the model as:
  1. the first exchange (the question, usually with the Tind report, and its answer), always;
  2. the "chat so far" summary of the turns after it, once the window has made one (it covers the first N messages);
  3. every turn after the summary, word for word.
Only the newest copy of each attachment (Tind report, system journal, a Steam log, a file) is sent; older copies
become one line. The rules footer the local service adds at the end of each message is taken off earlier turns.
If the whole would still not fit the model, the oldest turns of part 3 are left out and the caller is told.
"""
import re

FIRST_LIMIT = 60_000        # characters of the first message (head kept, then the end)
FIRST_HEAD = 20_000
TURN_LIMIT = 40_000         # characters of any other earlier message
TURN_HEAD = 12_000
SUMMARY_LIMIT = 20_000      # characters of the summary itself
REPLY_ROOM = 16_384         # tokens kept free for the answer

# the attachment sections the local service writes: "## <name>" and a fenced block
SECTION_RE = re.compile(r'(?m)^## (Tind report|System journal[^\n]*|Steam log [^\n]+|File [^\n]+)\n```\n')
FOOTER_RE = re.compile(r'\n\n\[Tind: [^\n]*\]\s*$')


def cut_middle(text, limit, head):
    """Keep the start (the question, the top of a report) and the end (the newest log lines), drop the middle."""
    if len(text) <= limit:
        return text
    return (text[:head] + '\n[... %d characters cut from the middle ...]\n' % (len(text) - limit)
            + text[-(limit - head):])


def strip_footer(text):
    return FOOTER_RE.sub('', text)


def _key(name):
    return 'System journal' if name.startswith('System journal') else name


def sections(text):
    """[(key, name, start, end)] for each attachment section in a message, in order."""
    found = list(SECTION_RE.finditer(text))
    out = []
    for i, mt in enumerate(found):
        end = found[i + 1].start() if i + 1 < len(found) else len(text)
        out.append((_key(mt.group(1)), mt.group(1), mt.start(), end))
    return out


def newest_only(texts, later=''):
    """The user texts with each attachment kept only in its newest copy (also counting `later`, the message being
    sent now). Older copies become one line naming the attachment."""
    last = {}
    for i, t in enumerate(list(texts) + [later]):
        for key, _name, _s, _e in sections(t):
            last[key] = i
    out = []
    for i, t in enumerate(texts):
        secs = sections(t)
        if not secs:
            out.append(t)
            continue
        pieces, pos = [], 0
        for key, name, s, e in secs:
            if last.get(key, i) > i:
                pieces.append(t[pos:s])
                pieces.append('## %s\n[a newer copy is attached further down]' % name
                              + ('\n\n' if t[e:].strip() else ''))
                pos = e
        pieces.append(t[pos:])
        out.append(''.join(pieces))
    return out


def assemble(history, summary=None, covers=0, later='', budget=None):
    """history: [{'role', 'text', 'raw'}] as the window sends it (every message, oldest first, texts as sent).
    summary: the chat-so-far text (already redacted by the caller) covering history[:covers] after the first exchange.
    later: the message being sent now. budget: the characters the history may use (None: no limit).
    Returns (items, info): items as [{'role', 'text', 'raw'}], info {'first', 'summary', 'recent', 'dropped'}."""
    h = [dict(x, text=strip_footer(str(x.get('text', '')))) for x in history]
    users = [i for i, x in enumerate(h) if x['role'] == 'user']
    fixed = newest_only([h[i]['text'] for i in users], later)
    for i, t in zip(users, fixed):
        h[i]['text'] = t
    for n, x in enumerate(h):
        x['text'] = (cut_middle(x['text'], FIRST_LIMIT, FIRST_HEAD) if n == 0
                     else cut_middle(x['text'], TURN_LIMIT, TURN_HEAD))
    first = h[:2]
    use_summary = bool(summary and summary.strip()) and covers > 2 and covers <= len(h)
    recent = h[covers:] if use_summary else h[2:]
    dropped = 0
    if budget is not None:
        size = sum(len(x['text']) for x in first + recent) + (len(summary) + 300 if use_summary else 0)
        while recent and size > budget:
            size -= len(recent[0]['text'])
            recent = recent[1:]
            dropped += 1
        while recent and recent[0]['role'] != 'user':     # start on a question
            recent = recent[1:]
            dropped += 1
    items = [dict(x) for x in first]
    if use_summary:
        note = ('Chat so far: a summary of the messages between the first exchange above and the messages below '
                '(written for Tind by a model; the user may have corrected it). Treat it as part of the '
                'conversation.\n\n' + cut_middle(summary.strip(), SUMMARY_LIMIT, SUMMARY_LIMIT // 2))
        if recent and recent[0]['role'] == 'user':
            recent = [dict(recent[0], text=note + '\n\n---\n\n' + recent[0]['text'])] + recent[1:]
        else:
            items.append({'role': 'user', 'text': note, 'raw': False})
    items += [dict(x) for x in recent]
    info = {'first': bool(first), 'summary': use_summary, 'recent': len(recent), 'dropped': dropped}
    return items, info


def budget_chars(m, system='', later=''):
    """The characters an earlier-turns history may take for model entry m."""
    try:
        context = int(m.get('context') or 128_000)
    except (TypeError, ValueError):
        context = 128_000
    total = int((context - REPLY_ROOM) * 3.5 * 0.9)
    return max(20_000, total - len(system) - len(later))
