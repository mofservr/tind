#!/usr/bin/env python3
"""Drive a QEMU VM through its monitor socket: send keys, wait, take screenshots.
usage: drive.py MONITOR_SOCKET OUT_DIR STEPS.json
Steps (JSON list): {"wait": s} {"key": "ret"} {"keys": ["tab","ret"]} {"type": "text"} {"shot": "name"}
"""
import json, os, socket, subprocess, sys, time

mon, out, steps_file = sys.argv[1:4]
os.makedirs(out, exist_ok=True)
SHIFT = dict(zip('!@#$%^&*()_+{}|:"<>?~', ['1','2','3','4','5','6','7','8','9','0','minus','equal',
    'bracket_left','bracket_right','backslash','semicolon','apostrophe','comma','dot','slash','grave_accent']))
NAMES = {' ': 'spc', '.': 'dot', ',': 'comma', '-': 'minus', '/': 'slash', '=': 'equal',
         ';': 'semicolon', "'": 'apostrophe', '\\': 'backslash', '[': 'bracket_left',
         ']': 'bracket_right', '`': 'grave_accent', '\t': 'tab', '\n': 'ret'}

def hmp(cmd):
    s = socket.socket(socket.AF_UNIX)
    s.connect(mon)
    s.settimeout(2)
    try:
        s.recv(4096)
    except OSError:
        pass
    s.sendall((cmd + "\n").encode())
    time.sleep(0.4)
    try:
        s.recv(4096)
    except OSError:
        pass
    s.close()

def key(k, hold=120):
    hmp("sendkey %s %d" % (k, hold))
    time.sleep(hold / 1000 + 0.2)

def typ(text):
    for c in text:
        if c.isupper():
            key("shift-" + c.lower())
        elif c in SHIFT:
            key("shift-" + SHIFT[c])
        else:
            key(NAMES.get(c, c))

def shot(name):
    ppm = os.path.join(out, name + ".ppm")
    hmp("screendump " + ppm)
    time.sleep(1)
    if os.path.exists(ppm):
        subprocess.run(["convert", ppm, os.path.join(out, name + ".png")], check=False)
        os.remove(ppm)
    else:
        print("no screenshot for", name, flush=True)

for i, st in enumerate(json.load(open(steps_file))):
    print(i, st, flush=True)
    if "wait" in st:
        time.sleep(st["wait"])
    elif "key" in st:
        key(st["key"], st.get("hold", 120))
    elif "keys" in st:
        for k in st["keys"]:
            key(k)
            time.sleep(st.get("delay", 0.3))
    elif "type" in st:
        typ(st["type"])
    elif "shot" in st:
        shot(st["shot"])
