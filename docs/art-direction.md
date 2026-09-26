# Dust In Space: Pixel Art Direction

A cool night landscape drawn with crisp, restrained pixel clusters. **Everything you can touch is warm.** The sky, land and background stars are indigo and violet. Collectible stars, links, Sun light and rewards are gold. Packs are the only other saturated colours.

See `docs/concept/gameplay_mockup_4x.png` and `docs/concept/asset_sheet.png`.

## Canvas and scale

- **Native resolution:** 180 × 320 (portrait, 9:16). Scale by integers only, with nearest-neighbour filtering.
- **One pixel size everywhere.** Never scale a sprite by a fraction, rotate it by a non-90° angle, or smooth it. Animate by drawing frames.
- **Screen zones (native px):** Sun y 0–78 · play sky y 78–250 · horizon and land y 230–284 · HUD y 284–320.
- **Touch targets** are set in code: at least a 44 pt hit circle per star, independent of sprite size.

## Palette

The palette has 40 colours in 7 ramps (the dust ramp reuses N7 and N8). Files: `assets/palettes/stellar_sun.gpl` (Aseprite) and `stellar_sun.hex`. Never use a colour outside the palette.

| Ramp | Dark → light | Use |
|---|---|---|
| Sky N0–N10 | `#07091F #0E1438 #151D4A #1E2860 #2A3375 #3E3F8A #5A51A6 #7E68C8 #A77FD8 #D08FC8 #F2A9C2` | Sky, clouds, background stars, UI plaques (N0 fill, N6 border) |
| Land M0–M6 | `#0A0C26 #121638 #1B2150 #2B3470 #4A5AA8 #9FB0EE #D9E2FF` | Mountains, forest, launcher, snow, counts |
| Starlight C0–C5 | `#FFFBEA #FFE59A #FFC062 #E88A57 #A45A78 #6A3F7A` | Collectibles, links, particles, Sun light; C4–C5 for halos only |
| Dim Sun S0–S4 | `#2A1230 #45193A #6B2238 #9A3232 #D0542E` | The unlit Sun and embers |
| Blue pack B0–B4 | `#12245A #1D4696 #2F78D0 #62B4F0 #B8E6FF` | Blue pack only |
| Red pack R0–R4 | `#4A1226 #862032 #C8413A #F07A4E #FFC09A` | Red pack only |
| Dust | `#7E68C8 #A77FD8 #D9CCFF` | Dust icon, numbers, particles |

### Colour rules

1. Warm (C0–C3) means interactive or valuable. Never use it for decoration.
2. Background stars are cool, 1 px, and kept away from collectible stars. 3 px glints are allowed only in the empty top corners.
3. Blue and red appear only on packs.
4. The Sun moves from the S ramp to the C ramp as it heals. That change is the progress bar.
5. A rejected link is drawn in S4 (ember), never red: red belongs to packs.

## Techniques

- **Stepped gradients:** flat bands, with a Bayer 4×4 checker only along each seam.
- **Glow without blur:** a C0 core, then hard steps outward through C1, C2 and C3, then a dithered C4/C5 halo (about 50%, then 20% density).
- **Planets:** 5-step shading lit from the top-left, wavy band texture, light dither at ramp seams, and no outline.
- **Silhouettes:** flat fills with a single lighter top edge; stepped pines.
- **Link line:** 1 px C1 with a C0 pulse every 5 px and C5 checker glow alongside.

## Assets

| Asset | Size (px) | Notes | States |
|---|---|---|---|
| Small star | 5×5, halo r4 | Plus shape | idle twinkle, selected, dissolve |
| Medium star | 11×11, halo r8 | 8-point star, cross core | same |
| Big star | 15×15, halo r11 | Round 5 px core, long rays | same |
| Selection ring | radius + 4 | Dashed C1 circle | 2-frame rotate |
| Sun | r17 + 12 rays | Light pools from the bottom; rays light clockwise | 0–100%, pulse, ignite, ignited idle (2 frames: alternate rays shimmer, core glint moves, nearby glow breathes) |
| Blue pack | r8 launcher / r6 HUD | Banded planet | idle, tremble, burst |
| Red pack | r6 + ring | Ringed planet | same |
| Slingshot | ~30×36 | Crescent fork with star gems | idle, pull (3–4 frames), release |
| Dust icon | 9×9 / 5×5 | Faceted diamond | pulse |
| Reward plaque | 46×11 | N0 fill, N6 border, clipped corners | shown while linking |

## UI text

- All numbers are rendered by the engine from a bitmap font and are never baked into sprites.
- Fonts: 5×7 for primary counters, 3×5 for secondary numbers, each with a 1 px N0 drop shadow.
- There are no panels behind the HUD; it sits on the dark forest ground.

## Pipeline

- Sources: `assets/art/source/*.aseprite`. Exported PNGs go to `assets/art/`, flattened unless an animation needs separate frames.
- `tools/art/build_concept.py` regenerates the concept mockup from code. It is a reference, not the production pipeline.
- The Sun, snow peak and pines from the concept still need a hand-drawn pass.
