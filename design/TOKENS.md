# Tind design tokens (approved mockups, Oct 2026)

Concept: arctic winter. Night (default) and March midday (low sun, alpine glow). Clear ice: one even
translucent tint, no outlines, no drop shadows, almost no glow, edges feathered.

| | Night | March midday |
|---|---|---|
| Surface tint (bar, dock, menus) | #2a6f8c, #3a8f9c, #2a8f94 at 20 % (menu 30 %) | #f4f9ff, #ffe6e0, #f8eef8 at 26 % (menu 42 %) |
| Accent | deep aurora teal #0b8274 (tile #066f68 at 72 %) | rosy salmon #e07a78 (tile #e07070 at 50 %) |
| On-accent text | #c9fff0 | #6b2430 |
| UI text | #eaf6fb | #1a2a3a |
| Running dot | #7cf0d8 | #d96a62 |
| Edge glow | accent at 3.5 % (almost invisible) | same |

Geometry: top bar full width, 32 px, even tint, fades out over its last ~20 px.
Dock flush to the left edge, 74 x 420, vertically centred below the bar, right corners radius 20,
left corners square, icons 46 px in 52 px tiles, 10 px gap, separator before the app-grid button.
Quick settings: 360 px wide, radius 24, 12 px from the right edge, tiles radius 28 (pill), sliders 12 px high.
Font: Nunito Sans. Icons: stock Papirus (unmodified). Dock: Firefox, Files, Terminal, Thunderbird, LibreOffice Writer.
Wallpapers: the final set of eight pairs lives in os/packages/tind-branding/usr/share/backgrounds/tind (3840x2160).
No dynamic day/night switching: the light/dark toggle in Settings switches the whole look.
