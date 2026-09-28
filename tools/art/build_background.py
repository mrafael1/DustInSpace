"""Builds the night background in assets/art/background.png (issue #14, docs/art-direction.md).

One opaque 180x320 image, drawn behind everything (the Sun's sky glow included):
  sky          stepped gradient N1 -> N10, flat bands with a Bayer 4x4 checker only at the seams,
               a quiet milky-way arc one step lighter, and a few flat wisp clouds.
  stars        cool 1 px background stars (never warm, never shaped like a collectible), thin in
               the play sky (y 78-250) so they can't be mistaken for stars to link, none behind the
               Sun, and 3 px glints only in the empty top corners.
  land         a far range with one snow peak (M3-M6), mid hills (M2) and stepped pines (M1), from
               y 230 down.
  ground       the forest floor the HUD sits on (y 284-320): a grass line lit M2 along its top with
               tufts, dark M0 soil with sparse M1 grit, a few half-buried stones, and a flat stone
               slab the telescope's tripod stands on. Quiet behind the dust counter and the pack
               controls, so their text reads. Every feature repeats every 180 px across (and none
               touches the side edges), so the Backdrop can tile the ground into a wider screen's
               margins without a seam.

Ported from the concept generator (tools/art/build_concept.py) with its own seeded RNG, so a rebuild
gives the same pixels. The snow peak and pines still want a hand pass in Aseprite: redraw the PNG
and the game picks it up with no code change.

Run: python tools/art/build_background.py   (needs Pillow)
"""

import math
import random
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "art" / "background.png"

W, H = 180, 320
SUN = (90, 39)
SUN_KEEPOUT = 34
PLAY_SKY = (78, 250)
LAND_TOP = 230

PAL = {
    "N1": "0E1438", "N2": "151D4A", "N3": "1E2860", "N4": "2A3375", "N5": "3E3F8A",
    "N6": "5A51A6", "N7": "7E68C8", "N8": "A77FD8", "N9": "D08FC8", "N10": "F2A9C2",
    "M0": "0A0C26", "M1": "121638", "M2": "1B2150", "M3": "2B3470", "M4": "4A5AA8",
    "M5": "9FB0EE", "M6": "D9E2FF",
}
C = {k: tuple(int(v[i:i + 2], 16) for i in (0, 2, 4)) for k, v in PAL.items()}

BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]

SKY_RAMP = ["N1", "N1", "N2", "N2", "N3", "N3", "N4", "N5", "N6", "N7", "N8", "N9", "N10"]
SKY_STOPS = [0, 30, 60, 95, 130, 160, 190, 212, 228, 240, 250, 258, 266]
WISPS = [(20, 64, 38, "N3"), (150, 52, 30, "N3"), (40, 176, 44, "N5"), (140, 196, 50, "N6"),
         (70, 226, 60, "N7"), (10, 236, 30, "N8"), (150, 238, 36, "N8")]
CORNER_GLINTS = [(8, 12), (171, 20), (14, 58), (164, 70)]


def bay(x: int, y: int) -> float:
    return (BAYER[y % 4][x % 4] + .5) / 16


class Canvas:
    def __init__(self) -> None:
        self.px = [["N1"] * W for _ in range(H)]

    def put(self, x: int, y: int, name: str) -> None:
        if 0 <= x < W and 0 <= y < H:
            self.px[y][x] = name

    def get(self, x: int, y: int) -> str:
        return self.px[y][x]

    def image(self) -> Image.Image:
        im = Image.new("RGB", (W, H))
        im.putdata([C[name] for row in self.px for name in row])
        return im


def draw_sky(cv: Canvas) -> None:
    for y in range(H):
        k = 0
        while k < len(SKY_STOPS) - 1 and y >= SKY_STOPS[k + 1]:
            k += 1
        f = len(SKY_RAMP) - 1 if k >= len(SKY_STOPS) - 1 else k + (y - SKY_STOPS[k]) / (SKY_STOPS[k + 1] - SKY_STOPS[k])
        i = int(f)
        fr = f - i
        nxt = min(i + 1, len(SKY_RAMP) - 1)
        for x in range(W):
            # Clean bands; the checker only in the last 45% of each, towards the next step.
            cv.put(x, y, SKY_RAMP[nxt] if fr > .55 and bay(x, y) < (fr - .55) / .45 else SKY_RAMP[i])
    # The milky-way arc: one step lighter, sparse ordered dither.
    for y in range(40, 200):
        for x in range(W):
            band = abs(math.hypot((x - 90) / 1.25, y - 330) - 245)
            if band < 16 and bay(x, y) < (1 - band / 16) * .45:
                cur = cv.get(x, y)
                cv.put(x, y, SKY_RAMP[min(SKY_RAMP.index(cur) + 1, len(SKY_RAMP) - 1)] if cur in SKY_RAMP else cur)
    # Wisp clouds: flat strips with stepped ends.
    for cx, cy, length, name in WISPS:
        for x in range(cx - length // 2, cx + length // 2):
            cv.put(x, cy, name)
        for x in range(cx - length // 2 + 5, cx + length // 2 - 7):
            cv.put(x, cy - 1, name)


def draw_stars(cv: Canvas, rng: random.Random) -> None:
    placed = 0
    while placed < 110:
        x, y = rng.randrange(W), rng.randrange(4, LAND_TOP)
        if math.hypot(x - SUN[0], y - SUN[1]) < SUN_KEEPOUT:
            continue
        # Thin in the play sky: two of every three candidates there are dropped.
        if PLAY_SKY[0] <= y < PLAY_SKY[1] and rng.random() < .67:
            continue
        r = rng.random()
        if y > 200:
            name = "N8" if r < .7 else "N9"
        elif y > 150:
            name = "N6"
        else:
            name = "N7" if r < .55 else ("N8" if r < .85 else "M5")
        cv.put(x, y, name)
        placed += 1
    for x, y in CORNER_GLINTS:
        cv.put(x, y, "M5")
        for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            cv.put(x + dx, y + dy, "N7")


def ridge(x: int, base: float, amp: float, seed: float) -> float:
    return base - amp * (.55 * math.sin(x * .045 + seed) + .3 * math.sin(x * .11 + seed * 2.1) + .15 * math.sin(x * .27 + seed * 3.7))


def draw_land(cv: Canvas, rng: random.Random) -> None:
    # The far range, with one snow peak lit from the left.
    peak_x, peak_y = 126, 233
    for x in range(W):
        dxp = x - peak_x
        peak = peak_y + abs(dxp) * (1.25 if dxp < 0 else 1.0) + (1 if (x * 7) % 5 == 0 else 0) + ((abs(dxp) > 5) and (x * 3) % 3 == 0)
        on_peak = peak <= ridge(x, 252, 7, 1.3)
        top = int(min(ridge(x, 252, 7, 1.3), peak))
        snow_line = peak_y + 6 + int(2 * math.sin(x * 1.7))
        for y in range(top, H):
            name = "M3"
            if on_peak and y < snow_line:
                if dxp <= 0:
                    name = "M6" if dxp < -1 and bay(x, y) < .6 else "M5"
                else:
                    name = "M5" if bay(x, y) < .3 else "M4"
            elif on_peak and y < snow_line + 3 and bay(x, y) < .35:
                name = "M4"
            cv.put(x, y, name)
        # A single lighter top edge on the lit side.
        if not (on_peak and top < snow_line):
            cv.put(x, top, "M4" if x < peak_x else "M3")
    # Mid hills.
    for x in range(W):
        top = int(ridge(x, 266, 6, 4.2))
        for y in range(top, H):
            cv.put(x, y, "M2")
        if bay(x, top) < .5:
            cv.put(x, top, "M3")
    # Stepped pines along the forest edge.
    x = -4
    while x < W + 4:
        h = rng.randint(8, 20)
        w = h // 2 + 2
        base = 286 + rng.randint(-1, 2)
        for j in range(h):
            half = int((j / h) * w / 2 + .5) - (1 if j % 3 == 0 and j > 2 else 0)
            for i in range(-half, half + 1):
                cv.put(x + i, base - h + j, "M1")
        x += rng.randint(5, 9)


GROUND_TOP = 284
# The soil darkens in steps down from the grass: M1, a checker seam, then M0.
SOIL_SEAM = (296, 301)
# Faint strata in the M0 soil: (base y, amplitude), each a broken wavy M1 line.
STRATA = [(307, 1), (315, 1)]
# Stones half in the soil: (centre x, top y, half width, rows).
STONES = [(10, 313, 3, 3), (62, 310, 2, 2), (104, 312, 4, 3), (126, 316, 3, 2), (170, 316, 2, 2), (44, 316, 2, 2)]
# The telescope's slab: its tripod feet (Telescope at x 80, feet at y 310) stand on its top row.
SLAB = (66, 311, 94, 315)
# Keep strata off these (x0, y0, x1, y1): the dust counter, and each pack's icon, count and button.
QUIET = [(4, 294, 64, 308), (112, 282, 180, 314)]


def grass_line(x: int) -> int:
    # Periods that divide 180, so the line tiles across.
    return GROUND_TOP + 2 + round(1.2 * math.sin(2 * math.pi * x / 60) + 0.8 * math.sin(2 * math.pi * x / 36 + 1))


def quiet(x: int, y: int) -> bool:
    return any(x0 <= x < x1 and y0 <= y < y1 for x0, y0, x1, y1 in QUIET)


def tuft(x: int) -> int:
    """How tall the grass tuft at column x is (0 for none), on a 180-periodic rhythm."""
    k = (x * 7) % 30
    return {0: 3, 1: 2, 13: 2, 14: 1, 22: 1}.get(k, 0)


def draw_ground(cv: Canvas) -> None:
    seam0, seam1 = SOIL_SEAM
    for x in range(W):
        top = grass_line(x)
        for y in range(top, H):
            if y < seam0:
                name = "M1"
            elif y < seam1:
                name = "M0" if bay(x, y) < (y - seam0 + 1) / (seam1 - seam0 + 1) else "M1"
            else:
                name = "M0"
            cv.put(x, y, name)
        # The grass bank: a lit M3 rim with an M4 glint on its crests, M2 under it, M3 blades
        # above it (M4 tips on the tallest).
        cv.put(x, top, "M3")
        cv.put(x, top + 1, "M2")
        cv.put(x, top + 2, "M2" if bay(x, top + 2) < .5 else "M1")
        if grass_line(x - 1) > top and grass_line(x + 1) >= top:
            cv.put(x, top, "M4")
        h = tuft(x)
        for j in range(1, h + 1):
            cv.put(x, top - j, "M4" if j == h and h >= 3 else "M3")
    # Strata: broken wavy M1 lines in the M0 soil, off the HUD's text.
    for base, amp in STRATA:
        for x in range(W):
            y = base + round(amp * math.sin(2 * math.pi * x / 45))
            if (x // 5) % 4 != 3 and not quiet(x, y):
                cv.put(x, y, "M1")
    # Half-buried stones: M2 bodies, an M3 lit top edge with an M4 glint, M1 underside.
    for cx, top, half, rows in STONES:
        for j in range(rows):
            w = half - (1 if j == 0 else 0)
            for i in range(-w, w + 1):
                cv.put(cx + i, top + j, "M1" if j == rows - 1 else "M2")
        for i in range(-half + 1, half - 1):
            cv.put(cx + i, top, "M3")
        cv.put(cx - half + 1, top, "M4")
    # The slab under the telescope: an M3 top edge, an M2 face with a crack, an M1 underside and
    # an M0 shadow; two pebbles beside it.
    x0, y0, x1, y1 = SLAB
    for x in range(x0 + 1, x1):
        cv.put(x, y0, "M4" if x < x0 + 6 else "M3")
        for y in range(y0 + 1, y1 - 1):
            cv.put(x, y, "M2")
        cv.put(x, y1 - 1, "M1")
    for y in range(y0 + 1, y1 - 1):
        cv.put(x0, y, "M2")
        cv.put(x1, y, "M1")
    cv.put(x0 + 18, y0 + 1, "M1")
    cv.put(x0 + 19, y0 + 2, "M1")
    for x, y in ((x0 - 3, y1 - 1), (x1 + 3, y1 - 2)):
        cv.put(x, y, "M2")
        cv.put(x + 1, y, "M1")


def build() -> None:
    rng = random.Random(14)
    cv = Canvas()
    draw_sky(cv)
    draw_stars(cv, rng)
    draw_land(cv, rng)
    draw_ground(cv)
    cv.image().save(OUT)
    print(f"wrote {OUT.relative_to(ROOT)} ({W}x{H})")


if __name__ == "__main__":
    build()
