"""The "Stardust Myth" style shared by the chapters' final paintings (<id>_figure.png) and their
chart pieces (<id>_piece_<part>.png).

A constellation figure is not drawn as a solid creature but as a vision condensing out of the sky:
a broken contour on its lit edges (a dotted ghost of a line on the shadow side), faint strokes on
its joints, sparse Bayer-dithered nebula wisps that gather along the inside of the form and leave
its middle hollow (the sky shows through), a thin haze drifting just outside it, stardust specks
thickest at the contour, and one mythic flourish (Scorpio: a stardust trail off the sting).

Colours are chosen relative to the sky behind each pixel: a painted pixel is "n steps above the
sky" on the N ramp (assets/art/background.png read as N steps), so the figure is the same faint
lift over the dark top and the brighter horizon. Specks are absolute colours (N7, N8, D0) and the
rose glints N9. No warm (C*) colour is ever decoration. Each landmark star sits in a small gap
clear of specks, so no pale dot near a star can be mistaken for one.

Use: a chapter's builder models its figure (a mask, normals and a per-pixel part or tag map, any
way it likes), paints it with the layers here onto a `Dust` canvas, resolves it with `resolve`,
checks it with `check`, writes `preview` for review and cuts it with `pieces`. The layer helpers
draw their random numbers from the caller's numpy generator in call order, so a builder that calls
them in a fixed order with a fixed seed always paints the same pixels.

Needs Pillow and numpy. Every image is the full 180x320 game screen in home layout.
"""

from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
PALETTE = ROOT / "assets" / "palettes" / "stellar_sun.gpl"
BACKGROUND = ROOT / "assets" / "art" / "background.png"

W, H = 180, 320
# The Sun's zone at the top of the screen (docs/art-direction.md): figures stay below it.
SUN_BOTTOM = 78
# The night ramp, darkest first: the steps a figure paints in.
N = [f"N{i}" for i in range(11)]
# Colours that are never decoration (gold, the Sun, packs): any of them in a figure is a bug.
WARM_PREFIXES = ("C", "S", "R")
# How far each size of landmark star keeps specks away (px radius): small, medium, big.
STAR_GAP = {"S": 3, "M": 5, "B": 7}
FOUR = ((0, 1), (1, 0), (0, -1), (-1, 0))

BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]], dtype=float)
ys, xs = np.mgrid[0:H, 0:W]
# The Bayer 4x4 threshold (0..1) of every screen pixel: a pixel is painted where density > it.
BAY = (BAYER[ys % 4, xs % 4] + 0.5) / 16.0


def load_palette() -> dict:
    """The Stellar Sun palette as {name: (r, g, b)}, read from the .gpl."""
    pal = {}
    for line in PALETTE.read_text().splitlines():
        parts = line.split()
        if len(parts) == 4 and parts[0].isdigit():
            pal[parts[3]] = tuple(int(c) for c in parts[:3])
    return pal


PAL = load_palette()


def shift(m: np.ndarray, dy: int, dx: int) -> np.ndarray:
    """`m` moved by (dy, dx), wrapping at the screen's edges."""
    return np.roll(np.roll(m, dy, axis=0), dx, axis=1)


def hsh(x, y, s: int = 0) -> float:
    """A fixed hash of a pixel (and a salt) in 0..1: the specks' and the trail's dice."""
    h = (int(x) * 374761393 + int(y) * 668265263 + s * 2246822519) & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    return (h ^ (h >> 16)) / 0xFFFFFFFF


def value_noise(rng: np.random.Generator, cell: float, octaves: int = 3) -> np.ndarray:
    """Smooth value noise in 0..1 on the screen grid (bilinear, several octaves)."""
    out = np.zeros((H, W))
    amp, total = 1.0, 0.0
    for o in range(octaves):
        c = max(cell / (2 ** o), 1.5)
        gw, gh = int(W / c) + 3, int(H / c) + 3
        g = rng.random((gh, gw))
        fx, fy = xs / c, ys / c
        x0, y0 = np.floor(fx).astype(int), np.floor(fy).astype(int)
        tx, ty = fx - x0, fy - y0
        tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
        a = g[y0, x0] * (1 - tx) + g[y0, x0 + 1] * tx
        b = g[y0 + 1, x0] * (1 - tx) + g[y0 + 1, x0 + 1] * tx
        out += amp * (a * (1 - ty) + b * ty)
        total += amp
        amp *= 0.5
    return out / total


def distance_inside(mask: np.ndarray) -> np.ndarray:
    """The distance (px, by 4-neighbour erosion) from each pixel of `mask` to its outside; 0 out."""
    d = np.zeros((H, W))
    cur = mask.copy()
    k = 0
    while cur.any() and k < 40:
        k += 1
        d[cur] = k
        nxt = cur.copy()
        for dy, dx in FOUR:
            nxt &= shift(cur, dy, dx)
        cur = nxt
    return d


def grow(mask: np.ndarray, steps: int) -> np.ndarray:
    """`mask` grown by `steps` px in all eight directions."""
    m = mask.copy()
    for _ in range(steps):
        g = m.copy()
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                g |= shift(m, dy, dx)
        m = g
    return m


def edge_of(inside: np.ndarray) -> np.ndarray:
    """The silhouette: pixels of `inside` with an empty 4-neighbour."""
    edge = np.zeros((H, W), bool)
    for dy, dx in FOUR:
        edge |= inside & ~shift(inside, dy, dx)
    return edge


def creases_of(inside: np.ndarray, owner: np.ndarray, z: np.ndarray, edge: np.ndarray) -> np.ndarray:
    """The joints: pixels whose right or lower neighbour belongs to another, higher solid."""
    crease = np.zeros((H, W), bool)
    for dy, dx in ((0, 1), (1, 0)):
        no, nz = shift(owner, dy, dx), shift(z, dy, dx)
        crease |= inside & (no >= 0) & (no != owner) & (nz > z + 0.6)
    return crease & ~edge


def sky_index() -> np.ndarray:
    """The N step of the stage background under each pixel (home layout), its 1 px stars smoothed
    out (the darker of each pixel's row neighbours two away)."""
    bg = np.array(Image.open(BACKGROUND).convert("RGB")).astype(int)
    ramp = np.array([PAL[n] for n in N])
    idx = np.abs(bg.sum(axis=2)[..., None] - ramp.sum(axis=1)[None, None, :]).argmin(axis=2)
    return np.minimum(idx, np.minimum(shift(idx, 0, 2), shift(idx, 0, -2)))


class Dust:
    """The canvas a figure is painted on: per pixel, a `level` (steps above the sky, -1 empty) and
    a `fixed` colour name (a speck or glint, absolute; "" none). `fixed` wins over `level`."""

    def __init__(self):
        self.level = np.full((H, W), -1)
        self.fixed = np.full((H, W), "", dtype=object)

    def put(self, mask: np.ndarray, steps: int):
        """Raises the pixels of `mask` to at least `steps` above the sky."""
        self.level[mask] = np.maximum(self.level[mask], steps)

    def put_px(self, x: int, y: int, steps: int):
        """Raises one pixel to at least `steps` above the sky."""
        self.level[y, x] = max(self.level[y, x], steps)

    def clear(self, mask: np.ndarray):
        """Empties the pixels of `mask` (sky shows through)."""
        self.level[mask] = -1
        self.fixed[mask] = ""


def broken_contour(dust: Dust, rng, edge, facing, lit, bias) -> np.ndarray:
    """The outline in fragments: drawn where a slow noise plus `bias` (per pixel; the lit side and
    any feature that must read get more) is high, 2-4 steps up, brightest where lit; elsewhere a
    dotted ghost of a line. Returns the drawn contour (for `rose_glints`)."""
    stroke = value_noise(rng, 7, 2)
    keep = stroke + bias > 0.40
    contour = edge & keep
    shadow = edge & ~keep & (stroke + bias > 0.05) & ((xs + ys) % 2 == 0)
    dust.put(shadow, 2)
    dust.put(shadow & (stroke > 0.5), 3)
    dust.put(contour & (facing <= 0.1), 2)
    dust.put(contour & (facing > 0.1), 3)
    dust.put(contour & (facing > 0.1) & (lit > 0.6), 4)
    return contour


def contour_bias(facing, weights: dict, tags: np.ndarray) -> np.ndarray:
    """The contour's bias: favours the lit side, plus `weights[tag]` on the pixels of each tag."""
    bias = 0.32 * np.clip(facing, -1, 1)
    for tag, weight in weights.items():
        bias = bias + weight * (tags == tag)
    return bias


def joint_strokes(dust: Dust, rng, crease):
    """Short faint strokes (2 steps up) on about half the joints: plates and rings."""
    dust.put(crease & (value_noise(rng, 4, 1) > 0.5), 2)


def nebula(dust: Dust, rng, inside, dist, lit, fill=1.0):
    """Wisps inside the form: dithered, dense near the edge and thin in the middle (hollow), 1 step
    up, 2 where lit. `fill` (a number or per-pixel array) thins them where a part should stay open."""
    neb = value_noise(rng, 10, 3)
    band = np.clip(1.0 - (dist - 1.0) / 5.0, 0.0, 1.0)
    dens = inside * (band * (0.35 + 0.55 * lit) + 0.12 + 0.15 * lit) * np.clip((neb - 0.25) * 2.4, 0, 1.2)
    dens = dens * fill
    dust.put(inside & (BAY < dens), 1)
    dust.put(inside & (BAY < dens * 0.35) & (lit > 0.55), 2)


def outer_haze(dust: Dust, rng, inside) -> np.ndarray:
    """A thin dithered haze 1 step up just outside the form, as if it condensed from it. Returns
    the distance outside the form (for `specks`)."""
    out_d = distance_inside(~inside)
    haze = value_noise(rng, 12, 3)
    hd = (~inside) * np.clip(1.0 - (out_d - 1) / 6.0, 0, 1) * np.clip((haze - 0.45) * 2.0, 0, 1) * 0.28
    dust.put((~inside) & (BAY < hd), 1)
    return out_d


def stardust_trail(dust: Dust, path, wisp: int = 120):
    """A drifting stream of dust along `path` ([(point, t)] with t 0..1 from its start): scattered
    specks and 1-2 step dust, widening and fading as t grows, over a faint dithered wisp under its
    first `wisp` points. The mythic flourish (Scorpio: off the sting)."""
    for p, t in path:
        spread = 1.8 + 4.0 * t
        for j in range(2):
            u = hsh(p[0] * 13, p[1] * 7, j) - 0.5
            w = hsh(p[0] * 5, p[1] * 11, j + 9) - 0.5
            q = p + np.array([u, w]) * spread * 2
            x, y = int(round(q[0])), int(round(q[1]))
            if 0 <= x < W and 0 <= y < H and hsh(x, y, 3 + j) < 0.55 - 0.5 * t:
                if hsh(x, y, 21) < 0.16 * (1 - t) + 0.02:
                    dust.fixed[y, x] = "D0" if hsh(x, y, 5) < 0.5 else "N8"
                elif t < 0.25:
                    dust.put_px(x, y, 2)
                else:
                    dust.put_px(x, y, 1 if hsh(x, y, 8) < 0.5 else 2)
    for p, t in path[:wisp]:
        x, y = int(round(p[0])), int(round(p[1]))
        for dy in range(-2, 3):
            for dx in range(-2, 3):
                X, Y = x + dx, y + dy
                if 0 <= X < W and 0 <= Y < H and BAY[Y, X] < 0.22 * (1 - t / 0.5):
                    dust.put_px(X, Y, 1)


def trail_pixels(path) -> np.ndarray:
    """Every pixel `stardust_trail` may touch along `path` (a slight superset), for tagging the
    flourish's piece: apply it only to pixels no solid has tagged."""
    m = np.zeros((H, W), bool)
    for p, t in path:
        spread = 1.8 + 4.0 * t
        for j in range(2):
            u = hsh(p[0] * 13, p[1] * 7, j) - 0.5
            w = hsh(p[0] * 5, p[1] * 11, j + 9) - 0.5
            q = p + np.array([u, w]) * spread * 2
            x, y = int(round(q[0])), int(round(q[1]))
            if 0 <= x < W and 0 <= y < H:
                m[y, x] = True
        x, y = int(round(p[0])), int(round(p[1]))
        m[max(y - 2, 0):y + 3, max(x - 2, 0):x + 3] = True
    return m


def specks(dust: Dust, inside, dist, out_d, lit):
    """Stardust specks (D0, N8, N7), thickest on the contour and fading off it both ways."""
    dd = np.where(inside, dist - 1, -out_d)
    near = np.exp(-np.abs(dd) / 2.5)
    for y in range(H):
        for x in range(W):
            if near[y, x] < 0.05 or dust.fixed[y, x]:
                continue
            p = 0.06 * near[y, x] * (0.7 + lit[y, x] if inside[y, x] else 0.7)
            if hsh(x, y, 1) < p:
                h = hsh(x, y, 2)
                dust.fixed[y, x] = "D0" if h < 0.25 else ("N8" if h < 0.7 else "N7")


def rose_glints(dust: Dust, contour, lit, exclude=None):
    """A few N9 glints on the brightest drawn edges (not on `exclude`)."""
    for y in range(H):
        for x in range(W):
            if contour[y, x] and lit[y, x] > 0.85 and hsh(x, y, 4) < 0.18:
                if exclude is None or not exclude[y, x]:
                    dust.fixed[y, x] = "N9"


def star_gaps(dust: Dust, landmarks, sizes, hollow: int = 0):
    """Keeps each landmark star readable: no speck within its size's STAR_GAP radius (a pale dot
    there could pass for a star), and with `hollow` > 0 nothing at all within that radius."""
    for (lx, ly), s in zip(landmarks, sizes):
        r2 = (xs - lx) ** 2 + (ys - ly) ** 2
        clear = r2 <= STAR_GAP[s] ** 2
        dust.fixed[clear & (dust.fixed != "")] = ""
        if hollow:
            dust.clear(r2 <= hollow * hollow)


def quiet_stars(dust: Dust, landmarks, ring: int = 1, pale: int = 7, calm: int = 3, calm_steps: int = 2,
                pale_names=("D0", "N8", "N9")):
    """Keeps every landmark star clear, whatever its size: empties the `ring` px round it (its own
    pixel stays), drops any pale speck (`pale_names`) within `pale` px (it could pass for a star)
    and caps the lines within `calm` px at `calm_steps` above the sky, so nothing bright crowds it."""
    for lx, ly in landmarks:
        r2 = (xs - lx) ** 2 + (ys - ly) ** 2
        own = (xs == lx) & (ys == ly)
        dust.clear((np.abs(xs - lx) <= ring) & (np.abs(ys - ly) <= ring) & ~own)
        dust.fixed[(r2 <= pale * pale) & np.isin(dust.fixed, list(pale_names))] = ""
        near = (r2 <= calm * calm) & ~own
        dust.level[near] = np.minimum(dust.level[near], calm_steps)
        dust.fixed[near & (dust.fixed != "")] = ""


def soften_near_stars(img: np.ndarray, landmarks, radius: int = 5, top: str = "N7") -> np.ndarray:
    """Dims every pixel within `radius` px of a landmark star (its own pixel aside) that is paler
    than `top` (an N step, or D0) down to `top`, so no bright line or speck crowds the star. Returns
    the image."""
    brighter = [N[i] for i in range(N.index(top) + 1, len(N))] + ["D0"]
    pale = {PAL[n] for n in brighter}
    for lx, ly in landmarks:
        for y in range(max(ly - radius, 0), min(ly + radius + 1, H)):
            for x in range(max(lx - radius, 0), min(lx + radius + 1, W)):
                if (x, y) == (lx, ly) or (x - lx) ** 2 + (y - ly) ** 2 > radius * radius:
                    continue
                if img[y, x, 3] and tuple(int(c) for c in img[y, x, :3]) in pale:
                    img[y, x, :3] = PAL[top]
    return img


def resolve(dust: Dust, sky: np.ndarray) -> np.ndarray:
    """The canvas as RGBA palette pixels: a fixed colour as is, a level as the N step that many
    above the sky (at most N8, N9 over the bright horizon), alpha 0 or 255."""
    img = np.zeros((H, W, 4), np.uint8)
    for y in range(H):
        for x in range(W):
            name = dust.fixed[y, x]
            if not name and dust.level[y, x] >= 1:
                name = N[int(min(sky[y, x] + dust.level[y, x], 9 if sky[y, x] >= 6 else 8))]
            if name:
                img[y, x, :3] = PAL[name]
                img[y, x, 3] = 255
    return img


def sun_clamp(img: np.ndarray, top: int = SUN_BOTTOM) -> np.ndarray:
    """Empties every row above `top` (the Sun's zone) and returns the image."""
    img[:top] = 0
    return img


def colours_used(img: np.ndarray) -> dict:
    """{palette name: opaque pixel count}; raises on an off-palette pixel."""
    inv = {v: k for k, v in PAL.items()}
    used = {}
    for y, x in zip(*np.nonzero(img[..., 3])):
        rgb = tuple(int(c) for c in img[y, x, :3])
        assert rgb in inv, f"({x}, {y}) {rgb} is not a Stellar Sun colour"
        used[inv[rgb]] = used.get(inv[rgb], 0) + 1
    return dict(sorted(used.items()))


def check(img: np.ndarray, top: int = SUN_BOTTOM) -> dict:
    """Asserts the painting's hard rules (180x320, alpha 0/255 only, palette colours only, no warm
    decoration, nothing in the Sun's zone above `top`) and returns `colours_used`."""
    assert img.shape == (H, W, 4), img.shape
    assert set(np.unique(img[..., 3]).tolist()) <= {0, 255}, "partial alpha"
    used = colours_used(img)
    warm = [k for k in used if k.startswith(WARM_PREFIXES)]
    assert not warm, f"warm colours as decoration: {warm}"
    assert not img[:top, :, 3].any(), f"painted in the Sun's zone (y < {top})"
    return used


def spread_tags(tags: np.ndarray, opaque: np.ndarray) -> np.ndarray:
    """Gives every untagged opaque pixel the tag of its nearest tagged pixel (4-neighbour steps,
    through empty sky too; ties go right, down, left, up). `tags` is an object array, "" untagged."""
    out = tags.copy()
    frontier = out != ""
    while (opaque & (out == "")).any():
        if not frontier.any():
            raise ValueError("opaque pixels with no tagged pixel to take a part from")
        new = np.zeros((H, W), bool)
        for dy, dx in FOUR:
            src = shift(out, dy, dx)
            take = (out == "") & ~new & shift(frontier, dy, dx)
            # No wrapping round the screen's edges.
            if dy > 0:
                take[:dy, :] = False
            if dy < 0:
                take[dy:, :] = False
            if dx > 0:
                take[:, :dx] = False
            if dx < 0:
                take[:, dx:] = False
            out[take] = src[take]
            new |= take
        frontier = new
    return out


def pieces(img: np.ndarray, tags: np.ndarray, parts) -> dict:
    """The painting cut by a per-pixel part tag into {part: RGBA image}. Asserts the cut is an
    exact partition: every opaque pixel in exactly one piece, and the pieces add back to `img`."""
    opaque = img[..., 3] > 0
    bad = opaque & ~np.isin(tags, list(parts))
    assert not bad.any(), f"{int(bad.sum())} opaque pixels without a part"
    out = {}
    for part in parts:
        piece = img.copy()
        piece[tags != part] = 0
        out[part] = piece
    count = sum((p[..., 3] > 0).astype(int) for p in out.values())
    assert (count == opaque).all(), "pieces overlap or miss a pixel"
    assert (sum(p.astype(int) for p in out.values()) == img).all(), "pieces don't add up"
    return out


def preview(img: np.ndarray, landmarks, sizes, segments=(), scale: int = 3) -> Image.Image:
    """The painting over the background with its landmarks drawn as stars (small, medium, big),
    dotted C5 strings along `segments`, scaled `scale` times (nearest): for review only."""
    bg = Image.open(BACKGROUND).convert("RGBA")
    bg.alpha_composite(Image.fromarray(img, "RGBA"))
    px = bg.load()
    for a, b in segments:
        (x0, y0), (x1, y1) = landmarks[a], landmarks[b]
        steps = max(abs(x1 - x0), abs(y1 - y0))
        for k in range(0, steps + 1, 2):
            px[round(x0 + (x1 - x0) * k / steps), round(y0 + (y1 - y0) * k / steps)] = PAL["C5"] + (255,)
    for (x, y), s in zip(landmarks, sizes):
        if s == "S":
            for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)):
                px[x + dx, y + dy] = PAL["C2"] + (255,)
        elif s == "M":
            for d in range(-2, 3):
                px[x + d, y] = PAL["N9"] + (255,)
                px[x, y + d] = PAL["N9"] + (255,)
            px[x, y] = PAL["D0"] + (255,)
        else:
            for d in range(-3, 4):
                px[x + d, y] = PAL["M5"] + (255,)
                px[x, y + d] = PAL["M5"] + (255,)
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    px[x + dx, y + dy] = PAL["M6"] + (255,)
            px[x, y] = PAL["C0"] + (255,)
    return bg.resize((W * scale, H * scale), Image.NEAREST)


def save(img: np.ndarray, path: Path):
    """Writes an RGBA painting and prints its repo path."""
    Image.fromarray(img, "RGBA").save(path)
    try:
        print(f"wrote {path.relative_to(ROOT)}")
    except ValueError:
        print(f"wrote {path}")
