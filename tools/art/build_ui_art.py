"""Builds the launcher and UI sprites in assets/art/ (issue #13, docs/art-direction.md "Assets").

  pack_blue.png / pack_red.png  banded planet (blue r8) and ringed planet (red r6 + ring), lit from
                                the top-left, no outline. Frames: idle_0-idle_5 (the idle spin: the
                                bands drift a pixel per frame, a full turn in 6), bright, grown,
                                grown_bright (the tremble: a step up the ramp, then one radius
                                bigger), hud (r6).
  pack_burst.png                the opening's ring: 3 frames growing 5 -> 9 -> 13 px, dithered 50%.
  slingshot.png                 the fork (handle, crescent arms, star gems): 4 pull frames, the
                                gems warming C3 -> C0 as the pull grows. The bands are drawn in code.
  dust_icon.png                 faceted diamond on the dust ramp: large (9x9), small (5x5).
  reward_plaque.png             46x11, N0 fill, N6 border with clipped corners.
Each strip has a JSON sidecar: frame size, frame names, and the origin (the pixel the node sits on).

These are exact ports of the code that drew them before, so the game looks the same; a hand pass
in Aseprite can redraw any PNG and the game picks it up with no code change. There is no Aseprite
in the agent's environment, so these PNGs are the source until .aseprite files are saved in
assets/art/source/. The Sun stays drawn in code (game/scenes/sun.gd): see the PR for why.

Run: python tools/art/build_ui_art.py   (needs Pillow)
"""

import json
import math
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "art"


def hex_rgb(h: str) -> tuple:
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


PAL = {k: hex_rgb(v) for k, v in {
    "N0": "07091F", "N6": "5A51A6", "N7": "7E68C8", "N8": "A77FD8",
    "M3": "2B3470", "M4": "4A5AA8",
    "C0": "FFFBEA", "C1": "FFE59A", "C2": "FFC062", "C3": "E88A57",
    "D0": "D9CCFF",
}.items()}
BLUE = [hex_rgb(h) for h in ["12245A", "1D4696", "2F78D0", "62B4F0", "B8E6FF"]]
RED = [hex_rgb(h) for h in ["4A1226", "862032", "C8413A", "F07A4E", "FFC09A"]]

# --- packs (was PackView.pixels) -----------------------------------------------------------
PACK_RADIUS = {"blue": 8, "red": 6}
RING_RADII = (10.5, 3.5)
HUD_RADIUS = 6
# The idle spin: the wavy bands repeat every SPIN_FRAMES px across, so shifting them a pixel per
# frame loops seamlessly and reads as the planet turning.
SPIN_FRAMES = 6
PACK_FRAMES = [(f"idle_{i}", False, False, 0, i) for i in range(SPIN_FRAMES)] + [
    ("bright", False, True, 0, 0), ("grown", True, False, 0, 0),
    ("grown_bright", True, True, 0, 0), ("hud", False, False, HUD_RADIUS, 0)]


def pack_pixels(kind: str, grown: bool, bright: bool, radius: int, spin: int = 0) -> dict:
    ramp = RED if kind == "red" else BLUE
    r = (radius if radius > 0 else PACK_RADIUS[kind]) + (1 if grown else 0)
    lift = 1 if bright else 0
    dots = {}
    if kind == "red":
        add_ring(dots, ramp, lift, r, False)
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            if dx * dx + dy * dy > r * r + r:
                continue
            light = (dx + dy + 2 * r) / (4 * r)
            step = len(ramp) - 1 - max(0, min(len(ramp) - 1, int(light * len(ramp))))
            wave = 1 if (dx + spin) % SPIN_FRAMES < 3 else 0
            if (dy + wave) % 4 == 0:
                step -= 1
            dots[(dx, dy)] = ramp[max(0, min(len(ramp) - 1, step + lift))]
    if kind == "red":
        add_ring(dots, ramp, lift, r, True)
    return dots


def add_ring(dots: dict, ramp: list, lift: int, r: int, front: bool) -> None:
    rx, ry = RING_RADII[0] + (r - PACK_RADIUS["red"]), RING_RADII[1] + (r - PACK_RADIUS["red"])
    for dy in range(-math.ceil(ry), math.ceil(ry) + 1):
        for dx in range(-math.ceil(rx), math.ceil(rx) + 1):
            e = (dx / rx) ** 2 + (dy / ry) ** 2
            if e < 0.6 or e > 1.05:
                continue
            if (dy >= 0) != front:
                continue
            dots[(dx, dy)] = ramp[max(0, min(len(ramp) - 1, 3 + lift))] if dy >= 0 else ramp[2]


# --- burst ring (was Launcher._draw_burst_ring) --------------------------------------------
BURST_RADII = [5, 9, 13]


def burst_pixels(frame: int) -> dict:
    r = BURST_RADII[frame]
    dots = {}
    for dy in range(-r - 1, r + 2):
        for dx in range(-r - 1, r + 2):
            if round_half_away(math.sqrt(dx * dx + dy * dy)) == r and (dx + dy) % 2 == 0:
                dots[(dx, dy)] = PAL["C1"] if frame < 2 else PAL["C2"]
    return dots


def round_half_away(v: float) -> int:
    """GDScript roundi(): halves round away from zero (Python's round() goes to even)."""
    return int(math.floor(v + 0.5)) if v >= 0 else -int(math.floor(-v + 0.5))


# --- slingshot (was Launcher._draw_fork) ---------------------------------------------------
FORK_TIPS = [(-11, -4), (11, -4)]
PULL_FRAMES = 4
GEMS = [PAL["C3"], PAL["C2"], PAL["C1"], PAL["C0"]]


def line_pixels(a: tuple, b: tuple) -> list:
    """LinkLayer.line_pixels: Bresenham, both ends included."""
    pixels = []
    dx, dy = abs(b[0] - a[0]), -abs(b[1] - a[1])
    sx = (b[0] > a[0]) - (b[0] < a[0])
    sy = (b[1] > a[1]) - (b[1] < a[1])
    error = dx + dy
    x, y = a
    while True:
        pixels.append((x, y))
        if (x, y) == b:
            break
        twice = 2 * error
        if twice >= dy:
            error += dy
            x += sx
        if twice <= dx:
            error += dx
            y += sy
    return pixels


def path_pixels(points: list) -> list:
    pixels = []
    for i in range(1, len(points)):
        segment = line_pixels(points[i - 1], points[i])
        if pixels:
            segment = segment[1:]
        pixels.extend(segment)
    return pixels


def fork_pixels(pull_frame: int) -> dict:
    dots = {}
    for y in range(6, 15):
        for x in range(-1, 2):
            dots[(x, y)] = PAL["M4"] if x == -1 else PAL["M3"]
    for side in (-1, 1):
        tip = FORK_TIPS[0 if side < 0 else 1]
        for (x, y) in path_pixels([(0, 6), (side * 9, 3), tip]):
            dots[(x, y)] = PAL["M4"]
            dots[(x, y + 1)] = PAL["M4"]
    for tip in FORK_TIPS:
        for d in [(0, 0), (0, -1), (0, 1), (-1, 0), (1, 0)]:
            dots[(tip[0] + d[0], tip[1] + d[1])] = GEMS[pull_frame] if d == (0, 0) else PAL["C3"]
    return dots


# --- dust icon (was DustIcon.pixels) -------------------------------------------------------
def dust_pixels(small: bool) -> dict:
    r = 2 if small else 4
    dots = {}
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            if abs(dx) + abs(dy) > r:
                continue
            colour = PAL["N8"]
            if dx <= 0 and dy <= 0:
                colour = PAL["D0"]
            elif dx > 0 and dy > 0:
                colour = PAL["N7"]
            dots[(dx, dy)] = colour
    return dots


# --- reward plaque (was RewardPlaque._draw) ------------------------------------------------
PLAQUE = (46, 11)


def plaque_pixels() -> dict:
    w, h = PLAQUE
    dots = {}
    for y in range(h):
        for x in range(w):
            corner = (x in (0, w - 1)) and (y in (0, h - 1))
            if corner:
                continue
            edge = x in (0, w - 1) or y in (0, h - 1)
            dots[(x, y)] = PAL["N6"] if edge else PAL["N0"]
    return dots


# --- output --------------------------------------------------------------------------------
def write_strip(name: str, frames: list, names: list) -> None:
    """Frames are dicts of offsets; one cell fits them all, with the same origin in every frame."""
    xs = [x for f in frames for (x, _) in f]
    ys = [y for f in frames for (_, y) in f]
    lo = (min(xs), min(ys))
    size = (max(xs) - lo[0] + 1, max(ys) - lo[1] + 1)
    image = Image.new("RGBA", (size[0] * len(frames), size[1]), (0, 0, 0, 0))
    for i, dots in enumerate(frames):
        for (x, y), colour in dots.items():
            image.putpixel((i * size[0] + x - lo[0], y - lo[1]), colour + (255,))
    image.save(OUT / f"{name}.png")
    sidecar = {"frame_size": list(size), "origin": [-lo[0], -lo[1]], "frames": names}
    (OUT / f"{name}.json").write_text(json.dumps(sidecar, indent=2) + "\n", newline="\n")
    print(f"wrote {name}.png ({image.width}x{image.height}, {len(frames)} frames, origin {sidecar['origin']})")


def build() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for kind in ("blue", "red"):
        write_strip(f"pack_{kind}", [pack_pixels(kind, g, b, r, s) for _, g, b, r, s in PACK_FRAMES], [f[0] for f in PACK_FRAMES])
    write_strip("pack_burst", [burst_pixels(i) for i in range(len(BURST_RADII))], [f"ring_{r}" for r in BURST_RADII])
    write_strip("slingshot", [fork_pixels(i) for i in range(PULL_FRAMES)], [f"pull_{i}" for i in range(PULL_FRAMES)])
    write_strip("dust_icon", [dust_pixels(False), dust_pixels(True)], ["large", "small"])
    write_strip("reward_plaque", [{(x, y): c for (x, y), c in plaque_pixels().items()}], ["plaque"])


if __name__ == "__main__":
    build()
