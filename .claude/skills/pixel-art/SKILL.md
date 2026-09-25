---
name: pixel-art
description: Create, edit or review Dust In Space sprites, backgrounds and UI art so they match the pixel-art direction (180x320 grid, Stellar Sun palette, warm = interactive). Use for any new asset, art bug, or before importing art into Godot.
---

# Pixel art for Dust In Space

Read `docs/art-direction.md` first. The target look is `docs/concept/gameplay_mockup_4x.png`.

## Checklist for every asset
- [ ] Drawn at **native size** for the 180×320 grid, never downscaled from a large image.
- [ ] Every colour is in `assets/palettes/stellar_sun.gpl`. Verify it with the script below.
- [ ] Warm colours (C0–C3) are used only if the asset is interactive or valuable.
- [ ] No anti-aliasing to transparency. Alpha is either 0 or 255, except glows done as dithered pixels.
- [ ] Clean stepped edges with no jaggies or orphan pixels. Silhouettes still read in a flat single-colour test.
- [ ] Dither (ordered, checker) only at ramp seams, in atmosphere, or on planet texture.
- [ ] Readable at 1× on a phone. Collectible stars must be clearly different at 5 / 11 / 15 px.
- [ ] Source `.aseprite` saved in `assets/art/source/`. PNG exported to `assets/art/`, and animations as horizontal strips with a JSON sidecar.

## Palette verification
```bash
python - <<'EOF'
from PIL import Image; import sys, pathlib
pal={tuple(int(h[i:i+2],16) for i in (0,2,4)) for h in pathlib.Path('assets/palettes/stellar_sun.hex').read_text().split()}
for p in pathlib.Path('assets/art').glob('*.png'):
    im=Image.open(p).convert('RGBA'); bad={px[:3] for px in im.getdata() if px[3] and px[:3] not in pal}
    semi=any(0<px[3]<255 for px in im.getdata())
    print(p.name, 'OK' if not bad and not semi else f'off-palette {len(bad)} / semi-alpha {semi}')
EOF
```

## Aseprite
- Aseprite runs on the user's computer, not in the agent sandbox. Don't assume you can drive it.
- If an Aseprite CLI is available (`aseprite -b`), export with `aseprite -b file.aseprite --sheet out.png --data out.json --format json-array --sheet-type horizontal`.
- Otherwise you can draw with Python/PIL at native size (see `tools/art/build_concept.py` for star, planet, Sun and font helpers). Tell the user which parts need a hand pass.

## Generated images
Anything from an image generator is **concept art only**. It must be redrawn or cleaned to the palette and grid before it enters `assets/art/`.

## Godot import
The project default filter is Nearest. Turn mipmaps off, keep the lossless compression mode, and keep pixel snap on. Build UI numbers with Label nodes and the bitmap fonts in `assets/fonts/`, never as sprites.
