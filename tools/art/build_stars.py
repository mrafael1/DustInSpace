"""Builds the star sprites in assets/art/ (issue #12, docs/art-direction.md "Assets").

Three collectible stars, drawn at native size. Each size has its own colour, like a star's
temperature, so the sizes tell apart at a glance (RAMPS below):
  small  5x5   plus shape                                        orange: C2 core, C3 arms
  medium 11x11 8-point star with a cross core                    gold: C0 core, C1 body, C2 tips
  big    15x15 round 5 px core (a plus in a disc) with long rays blue-white: C0 core, M6, M5 tips
Each size is one horizontal strip, stars_<size>.png, with one frame per state (FRAMES below),
and a JSON sidecar naming the frames. The dashed C1 selection ring is selection_ring_<size>.png,
2 frames (the dashes swap). StarView draws these frames; the halo stays a dithered glow in code.

Frames are the idle pixel map with its ramp steps shifted or cut, so a hand pass in Aseprite
can redraw any frame in the PNG and the game picks it up with no code change. There is no
Aseprite in the agent's environment, so these PNGs are the source until a hand pass saves
.aseprite files in assets/art/source/.

Run: python tools/art/build_stars.py   (needs Pillow)
"""

import json
import math
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "art"

C0, C1, C2, C3 = (255, 251, 234), (255, 229, 154), (255, 192, 98), (232, 138, 87)
M4, M5, M6 = (74, 90, 168), (159, 176, 238), (217, 226, 255)

# Each size's colour chain, brightest first, and where each shape step (0 = core) sits on it.
# Frames brighten or dim by moving along the chain; every chain starts at C0, so a flare is white.
RAMPS = {
    "small": ([C0, C1, C2, C3], [2, 3, 3, 3]),
    "medium": ([C0, C1, C2, C3], [0, 1, 1, 2]),
    "big": ([C0, M6, M5, M4], [0, 1, 1, 2]),
}

# Digits are shape steps (0 = core); "." is empty. Centred, odd sizes.
SHAPES = {
    "small": [
        "..2..",
        "..1..",
        "21012",
        "..1..",
        "..2..",
    ],
    "medium": [
        ".....3.....",
        ".....2.....",
        ".....1.....",
        "..3..1..3..",
        "...21012...",
        "32110001123",
        "...21012...",
        "..3..1..3..",
        ".....1.....",
        ".....2.....",
        ".....3.....",
    ],
    "big": [
        ".......3.......",
        ".......2.......",
        ".......2.......",
        "...3...1...3...",
        "....2..1..2....",
        "......111......",
        ".....11011.....",
        "322111000111223",
        ".....11011.....",
        "......111......",
        "....2..1..2....",
        "...3...1...3...",
        ".......2.......",
        ".......2.......",
        ".......3.......",
    ],
}

# Each frame: (name, highest step drawn, step shift). Negative shift = brighter.
#   idle        the settled star
#   glint       a twinkle: every step one notch brighter
#   spark       mid-flight after a burst: only the core
#   flare       a valid link's first dissolve frame: all white
#   flare_core  second dissolve frame: core and inner ring, white
#   fade_core   third dissolve frame: core only, a step down its chain
#   fade_dot    last dissolve frame: a single pixel of the first ring's colour (drawn specially)
#   dim         Big Bang redshift: a step darker as it nears the hole
#   dim_core    Big Bang swallow: only the core, three steps dimmer
FRAMES = [
    ("idle", 3, 0),
    ("glint", 3, -1),
    ("spark", 0, 0),
    ("flare", 3, -4),
    ("flare_core", 1, -4),
    ("fade_core", 0, 1),
    ("fade_dot", -1, 1),
    ("dim", 3, 1),
    ("dim_core", 0, 3),
]

# Selection ring: a dashed C1 circle this far outside the sprite, dashes swapping per frame.
# Warm on every size: it marks what the player picked.
RING_GAP = 4
RING_DASHES = 16
RING_FRAMES = 2


def frame_pixels(size_name: str, rows: list[str], max_step: int, shift: int) -> dict[tuple[int, int], tuple]:
    chain, place = RAMPS[size_name]
    size = len(rows)
    if max_step < 0:
        # A single pixel at the centre, one step down from the core.
        return {(size // 2, size // 2): chain[place[1]]}
    dots = {}
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch == ".":
                continue
            step = int(ch)
            if step <= max_step:
                dots[(x, y)] = chain[max(0, min(len(chain) - 1, place[step] + shift))]
    return dots


def ring_pixels(radius: int, frame: int) -> dict[tuple[int, int], tuple]:
    """Offsets from the centre, like StarView's old code ring: every other dash, swapping."""
    dots = {}
    for dy in range(-radius - 1, radius + 2):
        for dx in range(-radius - 1, radius + 2):
            if round(math.sqrt(dx * dx + dy * dy)) != radius:
                continue
            dash = int((math.atan2(dy, dx) + math.pi) / (2 * math.pi) * RING_DASHES) % RING_DASHES
            if (dash + frame) % 2 == 0:
                dots[(dx, dy)] = C1
    return dots


def write_strip(name: str, frames: list[dict], cell: int, frame_names: list[str]) -> None:
    image = Image.new("RGBA", (cell * len(frames), cell), (0, 0, 0, 0))
    for i, dots in enumerate(frames):
        for (x, y), colour in dots.items():
            image.putpixel((i * cell + x, y), colour + (255,))
    image.save(OUT / f"{name}.png")
    (OUT / f"{name}.json").write_text(json.dumps({"frame_size": [cell, cell], "frames": frame_names}, indent=2) + "\n")
    print(f"wrote {name}.png ({image.width}x{image.height}, {len(frames)} frames)")


def build() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for size, rows in SHAPES.items():
        n = len(rows)
        assert all(len(r) == n for r in rows), size
        write_strip(f"stars_{size}", [frame_pixels(size, rows, m, s) for _, m, s in FRAMES], n, [f[0] for f in FRAMES])
        radius = n // 2 + RING_GAP
        cell = 2 * (radius + 1) + 1
        rings = []
        for f in range(RING_FRAMES):
            rings.append({(dx + radius + 1, dy + radius + 1): c for (dx, dy), c in ring_pixels(radius, f).items()})
        write_strip(f"selection_ring_{size}", rings, cell, [f"ring_{f}" for f in range(RING_FRAMES)])


if __name__ == "__main__":
    build()
