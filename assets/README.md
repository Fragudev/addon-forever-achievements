# Artwork

Source images. They are **not** shipped in the addon zip (only `ForeverAchievements/` is).

| File | What | Used for |
|---|---|---|
| `forever_achievements_logo.png` | Forever Achievements logo, gold trophy on a dark blue square, 1254x1254 | source of `ForeverAchievements/Media/forever_achievements_logo.tga`: AddOns list icon, window header, minimap button |

## Regenerating the game texture

WoW does not load PNG. It loads TGA or BLP with power-of-two sides. `tools/make_tga.swift` (macOS, needs the Swift
toolchain) centres an image on a transparent square canvas and writes a 32-bit uncompressed TGA with straight alpha:

```bash
swift tools/make_tga.swift assets/forever_achievements_logo.png ForeverAchievements/Media/forever_achievements_logo.tga 128 0
```

The last two arguments are the canvas size in pixels (a power of two) and the margin as a fraction of it. The logo
is already square and fills its canvas, so the margin is 0.
