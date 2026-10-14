# Calamares job: remember which extras the user ticked so the installed system
# can set them up on first boot (tind-extras.service).
import os
import libcalamares


def pretty_name():
    return "Remember chosen extras"


def run():
    gs = libcalamares.globalstorage
    root = gs.value("rootMountPoint")
    chosen = set()
    keys = list(gs.keys())
    for key in keys:
        if key.startswith("packagechooser"):
            val = gs.value(key)
            if isinstance(val, str):
                items = val.split(",")
            elif isinstance(val, (list, tuple)):
                items = list(val)
            else:
                items = []
            chosen.update(str(i).strip() for i in items if str(i).strip())
    wanted = [x for x in ("gaming", "dev") if x in chosen]
    libcalamares.utils.debug("tindextras: chosen=%s wanted=%s keys=%s" % (sorted(chosen), wanted, keys))
    if not wanted or not root:
        return None
    d = os.path.join(root, "var/lib/tind")
    os.makedirs(d, exist_ok=True)
    with open(os.path.join(d, "pending-extras"), "w") as f:
        f.write(" ".join(wanted) + "\n")
    return None
