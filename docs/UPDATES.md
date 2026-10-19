# How Tind updates itself

The `tind-*` packages (branding, shell theme, defaults, installer, app boxes) are published as an apt
repository at **https://apt.servr.no/** (a static site on GitHub Pages). Every install points at it through
`tind-archive-keyring`, so a fix reaches installed computers with the normal apt updates, no reinstall.
Debian's own updates are unchanged.

## Channels

| Channel | What it serves | Who follows it |
|---|---|---|
| `stable` | a package version **14 days** after it first appeared on `next` | every ISO install (the default) |
| `next` | every version built from `main`, at once | Morten's own computers |

Show or change the channel: `tind-channel`, `sudo tind-channel next`, `sudo tind-channel stable`
(then `sudo apt update`). Updates install silently through unattended-upgrades (the Tind origin is added in
`/etc/apt/apt.conf.d/52tind-unattended-upgrades`); nothing reboots by itself, and a new shell theme or
extension shows after the next login.

## Rolling out and rolling back

1. Push to `main`. When the `build` workflow is green (ISO boot test included), `publish-apt` puts the new
   versions on `next` within minutes.
2. A daily job (03:17 UTC) promotes a version to `stable` once it has been on `next` for 14 days.
3. **Every changed package needs a higher `Version:`** in its `DEBIAN/control`; publishing refuses a package
   whose contents changed under an already published version (apt would never offer it).
4. **A bad version caught within the 14 days:** add a line `package version` to `os/packages/WITHDRAWN`, push a
   fixed package with a higher version. `stable` keeps serving the last good version until the fix has aged.
5. **A genuine emergency fix:** Actions > publish-apt > Run workflow > tick *fast_track* (promotes the current
   versions to `stable` at once).
6. A version that already reached `stable` cannot be pulled back by apt; ship a higher version that undoes it.

GitHub pauses scheduled workflows after 60 days without any repository activity. If that ever happens,
promotions simply stop and `stable` stays where it is (open the Actions tab and re-enable the workflow).

## Computers installed before the repository existed

```bash
curl -fsSLO https://apt.servr.no/tind-archive-keyring.deb
sudo apt install ./tind-archive-keyring.deb
gpg --show-keys /usr/share/keyrings/tind-archive-keyring.gpg   # fingerprint must be 0F04 FB12 B3F9 7F21 F377 2F7F FE16 2F9E 34C4 D769
sudo tind-channel next        # optional, for the machines that test first
sudo apt update && sudo apt upgrade
```

## Behind the scenes

- `os/scripts/publish-apt.sh` builds the two suites, signs them with the key in the GitHub secret
  `TIND_APT_SIGNING_KEY` (public part: `tind-archive-keyring`, fingerprint above) and keeps its only state in
  `state/first-seen.json` on the live site. `os/scripts/test-publish-apt.sh` tests the promotion rules and runs a
  real `apt-get update` against the result; the `build` workflow runs it on every push.
- Only packages named `tind-*` (architecture `all`) are accepted, so this repository can never replace a Debian
  package.
- DNS: `apt.servr.no` is a CNAME to GitHub Pages. While the servr.no tunnel is up, Tind computers resolve
  `*.servr.no` through serv'r's DNS (which forwards this name upstream); if serv'r is down, updates pause until
  it is back.
- Losing the signing key means every install needs a new keyring package and a manual step. Keep the Bitwarden
  copy and the revocation certificate.
