# Design: pinned

The design is settled. Nothing here changes without Morten's OK, and design changes are shown to him before they reach `main`. No images, logos or wallpapers are generated for this project without asking first.

## Principle

The UI should draw no attention to itself: it is there, looks pleasant, and helps a good workflow. Light theme = alpenglow, dark theme = northern lights. Dark is the default.

## Shell

- Top bar, dock, menus, Quick Settings and notification cards share one solid colour, a notch darker than the window header. No blur, no translucency, no gradients, no glow, no hairline edge.
  - Dark: `#121314`, text `#F2F2F2`
  - Light: `#DFDBD8`, text `#2E2A27`
- Dock on the left, fixed and always visible. Dock and top bar form one square frame; menus, Quick Settings and cards are rounded with a soft window shadow.
- Top bar shows the four workspaces as numbers (active one bold in the accent colour, empty ones dimmed) instead of dots. Dock icons carry a small permanent number to the left and the running dots sit under the icon.
- Dock "Show apps" button: the plain Tind peak in the theme colour, no tile, no glow.
- Login screen: flat dark background and the Tind logo.
- Icons: Papirus. UI font: Nunito Sans.

Source: `os/packages/tind-branding/usr/share/gnome-shell/extensions/tind-ice@tind.no/stylesheet.css`.

## Logo

- Three forms only: icon, stacked, horizontal (`docs/branding/logo/`). Single colour, no duo colours.
- The wordmark letterforms are deliberate. Do not swap the font; the wordmark is traced outlines, not live text.

| Use | Colour |
|---|---|
| On the dark theme (aurora teal) | `#138677` |
| On the light theme (alpenglow pink) | `#EC5179` |
| General use, near-black | `#0C1523` |
| General use, near-white | `#C4E0EC` |

These are logo-weight colours, not for UI text on dark backgrounds.

## Accents

- The default accent matches the logo: teal `#138677` on dark, pink `#EC5179` on light.
- GNOME's accent picker is narrowed to two ramps, teal and alpenglow (9 shades): Spruce, Teal, Aurora, Seafoam, Frost, Blush, Alpenglow, Coral, Rose.
- Set in: the `00-tind` dconf defaults, the accent table in `tind-ice` `extension.js`, the GTK 3 and GTK 4 accent css in `etc/skel`, `tind-accent.js` in `tind-mozilla-config`, the GRUB themes and Calamares `branding.desc`.

## Not coming back

- Translucent "ice" panels, blur, or a floating glass dock.
- The duo-colour logo and the old triangle logo.
- A literal lotus (the warm pink is all that remains of it).
- A slogan.
