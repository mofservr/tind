# Calamares job: remember which extras the user ticked in the installer launcher
# (/tmp/tind-extras-choice) so the installed system sets them up on first boot.
import os
import libcalamares

CHOICE = "/tmp/tind-extras-choice"


def pretty_name():
    return "Remember chosen extras"


def run():
    root = libcalamares.globalstorage.value("rootMountPoint")
    chosen = []
    try:
        with open(CHOICE) as f:
            chosen = f.read().split()
    except OSError:
        pass
    wanted = [x for x in ("gaming", "dev") if x in chosen]
    libcalamares.utils.debug("tindextras: file=%s chosen=%s wanted=%s" % (CHOICE, chosen, wanted))
    if not wanted or not root:
        return None
    d = os.path.join(root, "var/lib/tind")
    os.makedirs(d, exist_ok=True)
    with open(os.path.join(d, "pending-extras"), "w") as f:
        f.write(" ".join(wanted) + "\n")
    return None
