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
