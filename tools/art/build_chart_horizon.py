"""Builds the chart's horizon, assets/art/chart_horizon.png: the ground at the bottom of a chapter's
chart (playtest: an empty blue bottom looked odd). The stage background's land, lower and simpler:
a faint horizon glow, a far range with a lit top edge, stepped pines and the grass bank over dark
soil. Transparent above the land. 180 px wide and tiling: every shape repeats every 180 px, so a
wide screen continues it. Palette-locked (Stellar Sun), opaque pixels only. Python 3 + Pillow.

    python tools/art/build_chart_horizon.py
"""
import math
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "art" / "chart_horizon.png"
W, H = 180, 36

PAL = {
    "N2": "151D4A", "N3": "1E2860", "N4": "2A3375",
    "M0": "0A0C26", "M1": "121638", "M2": "1B2150", "M3": "2B3470", "M4": "4A5AA8",
}
C = {k: tuple(int(v[i:i + 2], 16) for i in (0, 2, 4)) for k, v in PAL.items()}
BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]

# Rows (from the strip's top): the far range's ridge sits about RANGE_ROW (never above row 7, so the
# strip stays clear of the chart's PLAY), the pines stand on PINE_ROW, the grass bank starts about
# GROUND_ROW.
RANGE_ROW = 11
RANGE_AMP = 3.0
GLOW_ROWS = 4
PINE_ROW = 28
GROUND_ROW = 27


def bay(x: int, y: int) -> float:
    return BAYER[y % 4][x % 4] / 16.0


def wave(x: int, terms: list[tuple[int, float, float]]) -> float:
    """A sum of sines whose periods divide 180 (cycles per strip), so it tiles."""
    return sum(amp * math.sin(2 * math.pi * x * k / W + phase) for k, amp, phase in terms)


def ridge(x: int) -> int:
    return round(RANGE_ROW - RANGE_AMP * (0.6 * wave(x, [(2, 1, 0.4)]) + 0.3 * wave(x, [(5, 1, 1.9)]) + 0.1 * wave(x, [(12, 1, 3.1)])))


def grass(x: int) -> int:
    return GROUND_ROW + round(1.0 * wave(x, [(3, 1, 0)]) + 0.6 * wave(x, [(5, 1, 1)]))


def build() -> None:
    px: list[list[str | None]] = [[None] * W for _ in range(H)]

    def put(x: int, y: int, name: str) -> None:
        if 0 <= y < H:
            px[y][x % W] = name

    for x in range(W):
        top = ridge(x)
        # The horizon glow: a dithered N3, then N4 against the range, thinning upward.
        for k in range(1, GLOW_ROWS + 1):
            if bay(x, top - k) < (GLOW_ROWS + 1 - k) / (GLOW_ROWS + 2):
                put(x, top - k, "N4" if k == 1 else "N3")
        for y in range(top, H):
            put(x, y, "M2")
        put(x, top, "M3")
    # Stepped pines along the forest edge, at fixed places that wrap round the strip.
    x = 2
    i = 0
    while x < W:
        h = 8 + (i * 7) % 9
        w = h // 2 + 2
        base = PINE_ROW + (i * 3) % 3 - 1
        for j in range(h):
            half = int((j / h) * w / 2 + .5) - (1 if j % 3 == 0 and j > 2 else 0)
            for dx in range(-half, half + 1):
                put(x + dx, base - h + j, "M1")
        x += 6 + (i * 5) % 4
        i += 1
    # The grass bank over dark soil, as the stage's floor: a lit M3 rim, M2 under it, M1 soil
    # stepping into M0 through a dithered seam.
    for x in range(W):
        top = grass(x)
        for y in range(top, H):
            k = (y - top) / max(1, H - top)
            put(x, y, "M1" if bay(x, y) > k else "M0")
        put(x, top, "M3")
        put(x, top + 1, "M2")
        if grass(x - 1) > top and grass(x + 1) >= top:
            put(x, top, "M4")
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    img.putdata([(*C[n], 255) if n else (0, 0, 0, 0) for row in px for n in row])
    img.save(OUT)
    print(f"wrote {OUT.relative_to(ROOT)} ({W}x{H})")


if __name__ == "__main__":
    build()
