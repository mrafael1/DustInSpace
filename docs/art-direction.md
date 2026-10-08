# Dust In Space: Pixel Art Direction

A cool night landscape drawn with crisp, restrained pixel clusters. **Everything you can touch is warm.** The sky, land and background stars are indigo and violet. Links, Sun light, rewards and the lit constellation are gold; collectible stars are coded by size (below). Packs are the only other saturated colours.

See `docs/concept/gameplay_mockup_4x.png` and `docs/concept/asset_sheet.png`.

## Canvas and scale

- **Native resolution:** 180 × 320 (portrait, 9:16). Scale by integers only, with nearest-neighbour filtering.
- **One pixel size everywhere.** Never scale a sprite by a fraction, rotate it by a non-90° angle, or smooth it. Animate by drawing frames.
- **Screen zones (native px):** Sun y 0–78 · play sky y 78–250 · horizon and land y 230–284 · HUD y 284–320.
- **Taller screens:** the view fills the phone at a whole-number scale and the 180×320 game sits on the bottom edge. The UI anchors to the real screen's corners (speaker top-left, pause or options gear top-right, dust bottom-left, packs bottom-right), the Sun rises to the top of the screen, and the play sky grows up into the space it leaves, with the Scorpio map moved up to stay centred in it. The sky above the background fades into N0 space with cool 1 px stars.
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

1. Warm (C0–C3) means interactive or valuable. Never use it for decoration. One exception: collectible stars are colour-coded by size, so the sizes read at a glance. Small is orange (C2 core, C3 arms), medium mauve (D0 core, N9 body, N8 tips, with a C5/N6 halo), and big blue-white (C0 core, M6 body, M5 tips, with a cool M4/M3 halo instead of C4/C5). The medium star's mauve comes from the bright end of the N ramp, so it stays clear of the N5–N8 background stars. The selection ring stays C1 on every size. Gold is kept for the finished constellation: no sky star is gold. Unlit constellation stars are drawn exactly like the sky star of their size (still idle frame) with four ember corner brackets (C3/C4, swapping) that mean "you can pick this". Lit, they turn gold whatever their size (C0 core, C1 body, C2 tips, the colour of the lit strings) with a warm C4/C5 halo and a twinkle, and lose the brackets. While a link is traced, a picked constellation star keeps its colour and shows its halo and the C1 selection ring, like a picked sky star.
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
| Small star | 5×5, halo r4 | Plus shape; orange | idle twinkle, selected, dissolve |
| Medium star | 11×11, halo r8 | 8-point star, cross core; gold | same |
| Big star | 15×15, halo r11 | Round 5 px core, long rays; blue-white, cool halo | same |
| Selection ring | radius + 4 | Dashed C1 circle | 2-frame rotate |
| Sun | r17 + 12 rays | Light pools from the bottom; rays light clockwise | 0–100% with a smoulder (2 frames: embers swap, dim halo breathes), pulse, ignite, ignited idle (2 frames: alternate rays shimmer, core glint moves) |
| Blue pack | r8 launcher / r6 HUD | Banded planet | idle, tremble, burst |
| Red pack | r6 + ring | Ringed planet | same |
| Slingshot | ~30×36 | Crescent fork with star gems | idle, pull (3–4 frames), release |
| Dust icon | 9×9 / 5×5 | Faceted diamond | pulse |
| Floating payout | text + 5×5 dust icon | "+n" in the 5×7 font, D0 (the top combo flashes C0 and hops 1 px) | rises 5 px from a collected link, stays until its dust lands (prototype, #59) |

## UI text

- All numbers are rendered by the engine from a bitmap font and are never baked into sprites.
- Fonts: 5×7 for primary counters, 3×5 for secondary numbers, each with a 1 px N0 drop shadow.
- There are no panels behind the HUD; it sits on the forest floor: a lit M3 grass bank with M4 glints and tufts, M1 soil stepping (checker seam) into dark M0, faint M1 strata, a few half-buried stones and a flat slab the telescope stands on. Behind the dust counter and each pack's count and button it stays M0/M1 so the HUD reads. The floor repeats every 180 px, and a wider screen's side margins continue it. The one plate is each pack's buy button: M1 fill with a 1 px border and clipped corners (C2 when affordable, M4 when not), drawn in code.

## Pipeline

- Sources: `assets/art/source/*.aseprite`. Exported PNGs go to `assets/art/`, flattened unless an animation needs separate frames.
- `tools/art/build_concept.py` regenerates the concept mockup from code. It is a reference, not the production pipeline.
- Sprites are generated by `tools/art/build_stars.py` and `tools/art/build_ui_art.py` into horizontal strips with JSON sidecars (frame size, origin, frame names); a hand pass can redraw any PNG and the game picks it up.
- The Sun is drawn in code (`game/scenes/sun.gd`): its states (fill, rays, pulse, smoulder, ignition, ignited idle) combine into too many frames for hand-edited sprites. `tools/art/export_sun_reference.gd` renders its key states to `docs/concept/sun_states.png` as the starting point for a hand pass.
- The chapter's paintings are 180×320 PNGs in home layout (transparent outside the figure), built by `tools/art/build_scorpio_figure.py`: the whole Scorpio (`scorpio_figure.png`), the same painting cut into the five parts for the chart (`scorpio_piece_<part>.png`, which partition it exactly; each joint goes with the part of the star on it), and each part stage's own painting fitted to its stars (`scorpio_part_<stage>.png`, layouts read from `star_map.gd`). The whole Scorpio is the scorpion as shaded solids anchored to the 14 landmarks, lit from the top left on the N ramp (N1–N8) with an N9/N10 rose rim and highlights, N1 joint creases, N8/D0 stardust specks and a checkered N3 aura. Opaque palette pixels only. A hand pass can redraw it and the game picks it up.
- The chapter chart's ground is `assets/art/chart_horizon.png` (180×36, transparent above the land, tiling), built by `tools/art/build_chart_horizon.py` from the stage background's land, lower and simpler.
- The background (sky, background stars, mountains, pines, forest floor) is one opaque 180×320 PNG, `assets/art/background.png`, built by `tools/art/build_background.py` and drawn behind everything. The snow peak and pines still need a hand-drawn pass.
