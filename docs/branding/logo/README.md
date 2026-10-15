# Tind logo set

Twelve standalone SVGs: three forms in four colourways. Every file is flat, single colour, cropped to the artwork with a small even margin.

## Forms

| Form | Use |
|---|---|
| `icon` | Peak only. Small sizes, favicons, app icons, avatars. Still reads at 16 px. |
| `stacked` | Peak above the wordmark. Installer, splash screens, square or portrait spaces. |
| `horizontal` | Peak left, wordmark right, sitting on the mountain's base. Web headers, banners, documents. |

## Colourways

| Suffix | Colour | Where |
|---|---|---|
| `-os-light` | Alpenglow pink `#EC5179` | Inside the OS, light theme |
| `-os-dark` | Aurora teal `#138677` | Inside the OS, dark theme |
| `-light` | Near black `#0C1523` | General use on light backgrounds: installer, website, print |
| `-dark` | Near white `#C4E0EC` | General use on dark backgrounds |

Files are named `tind-<form>-<colourway>.svg`, for example `tind-stacked-dark.svg` or `tind-horizontal-os-light.svg`.

## Notes

- The wordmark's odd letterforms (clipped "d", slanted "T") are deliberate and part of the identity. Do not replace them with a font.
- The icon and wordmark were traced from the original artwork and drawn as clean vector paths: the peak is a 12-point polygon.
- The pink and teal keep the hues of `glow-500` and `aurora-400` from the Tind Ice palette, adjusted so they stay at 3:1 or better on both light and dark backgrounds. The near black and near white are the repo's `fjell-900` and `ice-200`.
- Do not recolour, outline, add effects to, or stretch the logo.

## Colour rules

| Where | Colour |
|---|---|
| Dark theme | aurora teal `#138677` |
| Light theme | alpenglow pink `#EC5179` |
| General use, light background | near black `#0C1523` |
| General use, dark background | near white `#C4E0EC` |

No duo or other mixed-colour versions.

## Additional assets

Built on the same artwork and colours as the 12 SVGs above.

| Path | What |
|---|---|
| `symbolic/tind-logo-symbolic.svg` | 16×16 GNOME symbolic icon, recoloured by the toolkit (teal in the dark theme, pink in the light theme when the shell styles it so). Left-foot jag simplified for small sizes. |
| `app/tind-logo.svg` | Full-colour app icon (icon name `tind-logo`): dark rounded tile, near-white peak, faint pink glow. Not theme-dependent. |
| `app/tind-logo-small.svg` | Same with a larger peak, used for the 16–32 px PNGs. |
| `app/tind-avatar.svg` | Full-bleed square (no rounded corners) for avatars and platform-masked icons. |
| `favicon/` | `favicon.svg` (near black on light tabs, near white on dark tabs), `favicon.ico` (16/32/48), PNGs, `apple-touch-icon.png`, `icon-192/512.png`. |
| `social/` | 1280×640 card using the `horizontal-dark` lockup. |
| `png/app/` | App icon at 16, 22, 24, 32, 48, 64, 128, 256, 512, 1024, and the avatar at 1024. |
| `os-assets/` | Laid out like `os/packages/`, ready to copy in: hicolor icons (16–512, scalable, symbolic), pixmaps, Plymouth `logo.png` (stacked, near white), Calamares `logo.png` (peak only) and `icon.png`. **Not yet wired into the packages**: `os/packages/` still has the previous icons. |

Below 24 px use the symbolic icon or the small app icon, not the full lockups.
