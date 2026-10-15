# Tind design: v2 (approved)

Arctic winter. Night is the default; March midday is the light pair. See TOKENS.md for the exact values.

- `mockups/` six boards as PNG (1280x720): desktop, apps open and quick settings, night and midday
- `assets/wallpapers/` night and midday wallpapers (1920x1080)
- `assets/icons/` stock Papirus icons used in the dock (unmodified, GPL-3)
- `source/` Claude Design board files (.dc.html + canvas.json); live copy: https://claude.ai/artifact/NY3xk8B841T7DUfGKzMc2D

Ported into the OS: os/packages/tind-branding (tind-ice extension: stylesheet.css night, stylesheet-light.css midday,
extension.js switches them with the colour scheme; wallpapers; dconf accent).
Still open: the logo (start over), and real-hardware verification of the shell styling.
