"""Aquarius's part-stage paintings (chapter 2), in assets/art/:

  aquarius_part_<part>.png    each part stage's own painting (hand, body, legs, stream, jar), the
                              body part fitted to that stage's own landmarks (game/core/star_map.gd,
                              read from the source), shown when the stage is complete

These keep the older shaded-solid style: each part an outline at native size, given roundness from
its own shape (its height grows with the distance to its edge), then lit and shaded as the Scorpio's
part stages are (tools/art/build_scorpio_figure.py: light from the top left, a stepped ramp with a
Bayer checker only along each seam, dark creases where one part lies over another, a rose rim on lit
edges, stardust specks, a thin aura). The water is its own material on the cool M ramp (M3-M6, a D0
rim, sparse glints). No colour outside the Stellar Sun palette; every pixel opaque or empty.

The whole figure and its chart pieces are drawn clean-line by tools/art/build_aquarius_figure.py,
which also runs this module.

Run: python tools/art/aquarius_part_paintings.py   (needs Pillow and numpy)
"""

import importlib.util
import re
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
_spec = importlib.util.spec_from_file_location("scorpio_art", ROOT / "tools" / "art" / "build_scorpio_figure.py")
sc = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(sc)

ART = sc.ART
STAR_MAP = sc.STAR_MAP
W, H = sc.W, sc.H
v, lerp, unit, bezier = sc.v, sc.lerp, sc.unit, sc.bezier
PARTS = ("hand", "body", "legs", "stream", "jar")
SS = 4  # outlines are filled 4x larger, then each pixel takes the majority: smooth stepped edges

HEX = dict(sc.HEX)
HEX.update({"M2": "1B2150", "M3": "2B3470", "M4": "4A5AA8", "M5": "9FB0EE", "M6": "D9E2FF"})
RGB = {k: tuple(int(c[i:i + 2], 16) for i in (0, 2, 4)) for k, c in HEX.items()}
sc.RGB.update(RGB)

# Each material's shading ramp (darkest first) and rim (lit edge, then brightest).
RAMPS = {
    "body": (list(sc.RAMP), list(sc.RIM)),
    "water": (["M3", "M3", "M4", "M4", "M4", "M5", "M5", "M6"], ["M6", "D0"]),
}

# --- outlines ------------------------------------------------------------------------------

def spline(points, steps=8):
    """A smooth closed outline through the points (Catmull-Rom)."""
    pts = [v(p) for p in points]
    n = len(pts)
    out = []
    for i in range(n):
        p0, p1, p2, p3 = pts[(i - 1) % n], pts[i], pts[(i + 1) % n], pts[(i + 2) % n]
        for t in np.linspace(0, 1, steps, endpoint=False):
            out.append(0.5 * (2 * p1 + (p2 - p0) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t
                              + (3 * p1 - p0 - 3 * p2 + p3) * t * t * t))
    return out


def mask_of(points, smooth=True):
    """The pixels inside an outline (smoothed through its points, or straight between them)."""
    img = Image.new("L", (W * SS, H * SS), 0)
    outline = spline(points) if smooth else [v(p) for p in points]
    ImageDraw.Draw(img).polygon([tuple(p * SS + SS / 2) for p in outline], fill=255)
    big = np.array(img, dtype=float) / 255.0
    return big.reshape(H, SS, W, SS).mean(axis=(1, 3)) >= 0.5


def limb(points, radii):
    """A tapering limb's outline: each side of its centre line offset by its radius, capped."""
    pts = [v(p) for p in points]
    left, right = [], []
    for k, p in enumerate(pts):
        d = unit(pts[min(k + 1, len(pts) - 1)] - pts[max(k - 1, 0)])
        n = np.array([-d[1], d[0]])
        left.append(p + n * radii[k])
        right.append(p - n * radii[k])
    cap0 = pts[0] - unit(pts[1] - pts[0]) * radii[0] * 0.8
    cap1 = pts[-1] + unit(pts[-1] - pts[-2]) * radii[-1] * 0.8
    return [cap0] + left + [cap1] + right[::-1]


def distance(mask, cap=40):
    """Each pixel's distance to the outside, by repeated erosion."""
    d = np.zeros(mask.shape)
    cur = mask.copy()
    for _ in range(cap):
        if not cur.any():
            break
        d += cur
        nb = cur.copy()
        for dy, dx in ((0, 1), (1, 0), (0, -1), (-1, 0)):
            nb &= np.roll(np.roll(cur, dy, 0), dx, 1)
        cur = nb
    return d


def blur(a, passes=2):
    for _ in range(passes):
        a = (a + np.roll(a, 1, 0) + np.roll(a, -1, 0) + np.roll(a, 1, 1) + np.roll(a, -1, 1)) / 5.0
    return a


class Shapes(sc.Solids):
    """The Scorpio's solids, plus parts drawn as outlines; each tagged with its material."""

    def __init__(self):
        super().__init__()
        self.mat = "body"
        self.mats = []
        self.eyes = []

    def _put(self, *args, **kwargs):
        self.mats.append(self.mat)
        super()._put(*args, **kwargs)

    def shape(self, outline, depth=8.0, lift=0.0, smooth=True):
        """A part from its outline: domed by its distance to the edge, lit by that dome's slope.
        `lift` stacks parts (a higher one lies over a lower one); keep it within -15..20."""
        mask = mask_of(outline, smooth)
        d = distance(mask)
        h = np.sqrt(np.clip(d / max(d.max(), 1.0), 0.0, 1.0)) * depth
        gy, gx = np.gradient(blur(h * mask, 2))
        self._put(mask, h, -gx, -gy, np.full(h.shape, 0.9), lift)


# --- parts ---------------------------------------------------------------------------------

def amphora(S, foot, rim, through=None, depth=12.0, lift=17.0):
    """A Greek amphora from its ring foot to its flared rim: an egg-shaped belly broadest at the
    shoulder, a narrow neck, two looped ear handles from the shoulder to the neck (through the two
    `through` points, if given) and a painted band round the belly."""
    F, R = v(foot), v(rim)
    length = np.linalg.norm(R - F)
    a = (R - F) / length
    n = np.array([-a[1], a[0]])
    s = length / 54.0
    widths = [(0.0, 7.0), (0.05, 7.0), (0.08, 3.4), (0.12, 4.0), (0.2, 8.0), (0.35, 12.0), (0.5, 14.0),
              (0.6, 14.5), (0.66, 13.0), (0.72, 8.0), (0.76, 4.4), (0.9, 4.0), (0.93, 6.5), (1.0, 6.5)]
    for k, side in enumerate((1.0, -1.0)):
        start = F + a * 0.63 * length + n * side * 13.0 * s
        end = F + a * 0.86 * length + n * side * 4.6 * s
        if through is not None:
            control = 2.0 * v(through[k]) - 0.5 * (start + end)
        else:
            control = F + a * 0.86 * length + n * side * 22.0 * s
        loop = bezier(start, control, end, 11)
        S.shape(limb(loop, [1.6 * s] * len(loop)), depth=2.5, lift=lift - 1.0)
    body = [F + a * t * length + n * w * s for t, w in widths]
    body += [F + a * t * length - n * w * s for t, w in widths[::-1]]
    S.shape(body, depth=depth, lift=lift, smooth=False)
    band = [F + a * 0.40 * length + n * 14.0 * s, F + a * 0.47 * length + n * 14.5 * s,
            F + a * 0.47 * length - n * 14.5 * s, F + a * 0.40 * length - n * 14.0 * s]
    S.shape(band, depth=1.0, lift=lift + 1.0, smooth=False)


def water(S, points, r0, r1, twists=3.0, lift=-12.0):
    """A falling ribbon of water through `points`: it twists (narrowing where it turns edge-on) and
    widens as it falls. Returns its path."""
    S.mat = "water"
    pts = [v(p) for p in points]
    path = []
    for k in range(len(pts) - 1):
        a, b = pts[k], pts[k + 1]
        bend = np.array([-(b - a)[1], (b - a)[0]]) * (0.15 if k % 2 else -0.15)
        path += bezier(a, (a + b) / 2 + bend, b, 8)[:-1]
    path.append(tuple(pts[-1]))
    n = len(path)
    for k in range(n - 1):
        a, b = v(path[k]), v(path[k + 1])
        t = k / (n - 1)
        width = (r0 + (r1 - r0) * t) * (0.45 + 0.55 * abs(np.cos(np.pi * twists * t)))
        S.ellipsoid((a + b) / 2, b - a, np.linalg.norm(b - a) / 2 + 1.5, max(width, 1.2), depth=1.4, lift=lift, squash=2.5, along_flat=0.2)
    S.mat = "body"
    return path


def droplets(S, path, every=12, offset=7.0, lift=-11.0, seed=3):
    """Drops breaking off either side of a falling stream."""
    rng = np.random.default_rng(seed)
    S.mat = "water"
    for i in range(every - 2, len(path), every):
        for _ in range(2):
            p = v(path[i]) + v((offset if (i // every) % 2 else -offset, 0)) + rng.normal(0, 1.8, 2)
            S.ellipsoid(p, (0.0, 1.0), 1.5, 1.1, depth=1.0, lift=lift, squash=2.0)
    S.mat = "body"


def splash(S, at, width=15.0, lift=-14.0):
    """Where a stream lands: a flat pool and a fan of spray."""
    S.mat = "water"
    at = v(at)
    S.ellipsoid(at + v((0, 4)), (1.0, 0.0), width, 3.6, depth=2.0, lift=lift)
    for k, ang in enumerate(np.linspace(-2.5, -0.6, 6)):
        tip = at + v((np.cos(ang), np.sin(ang))) * (10 + (k % 2) * 4)
        S.capsule(at + v((0, 1)), tip, 1.4, 0.8, lift=lift + 1.0)
    S.mat = "body"


def head_in_profile(S, head, lift, eye=True):
    """A head in profile facing left: a round skull, brow, straight nose, lips and a firm chin,
    the jaw back to an ear; short curled hair capping the back of the skull, a fillet band."""
    head = v(head)

    def P(x, y):
        return head + v((x, y))

    face = [P(-5, -8), P(-7, -4), P(-7, -2), P(-10, 2), P(-7, 3), P(-8, 5), P(-7, 6), P(-7, 8),
            P(-4, 10), P(1, 10), P(5, 7), P(7, 1), P(7, -5), P(2, -9)]
    S.shape(face, depth=7, lift=lift)
    hair = [P(-6, -7), P(-2, -10), P(4, -9), P(8, -5), P(9, 0), P(8, 4), P(5, 6), P(3, 2), P(1, -2),
            P(-3, -4), P(-6, -5)]
    S.shape(hair, depth=4, lift=lift + 1.5)
    S.shape(limb([P(-6, -5), P(-1, -7), P(5, -6), P(8, -4)], [0.8, 0.9, 0.9, 0.8]), depth=1.0, lift=lift + 3)
    S.shape(limb([P(1, 3), P(2, 5)], [1.3, 1.3]), depth=1.0, lift=lift + 0.5)  # the ear
    if eye:
        S.eyes.append(tuple(np.round(P(-5, 0)).astype(int)))


# --- the stages' own paintings -------------------------------------------------------------

def stage_landmarks():
    """Each Aquarius stage's landmarks, read from game/core/star_map.gd (one source of truth)."""
    src = STAR_MAP.read_text()
    found = {}
    for part in PARTS:
        block = re.search(r"static func aquarius_%s\(\) -> StarMap:(.*?)\n\n\n" % part, src, re.S).group(1)
        marks = re.search(r"map\.landmarks = \[(.*?)\]\n", block).group(1)
        found[part] = [(int(x), int(y)) for x, y in re.findall(r"Vector2i\((-?\d+), (-?\d+)\)", marks)]
    return found


def open_hand(S, wrist, out, lift):
    """An open hand at the end of an arm reaching along `out`: a palm, four fingers and a thumb."""
    out = unit(out)
    side = np.array([-out[1], out[0]])
    palm = v(wrist) + out * 5.0
    S.shape(limb([v(wrist), palm], [3.6, 4.6]), depth=3, lift=lift)
    for spread in (-0.45, -0.15, 0.15, 0.45):
        base = palm + out * 3.0 + side * spread * 7.0
        S.shape(limb([base, base + out * (6.0 - abs(spread) * 3.0) + side * spread * 2.0], [1.3, 1.0]), depth=1.5, lift=lift + 0.5)
    S.shape(limb([palm - side * 4.0, palm - side * 7.5 + out * 2.0], [1.4, 1.1]), depth=1.5, lift=lift + 0.5)


def build_hand(S, M):
    """The Hand: a sleeve at the shoulder (the first star), the arm down through every star to an
    open hand past the last."""
    M = [v(p) for p in M]
    S.shape(limb([M[0] + v((6, -3)), lerp(M[0], M[1], 0.45)], [9.0, 8.0]), depth=7, lift=4)
    S.shape(limb(M, list(np.linspace(6.5, 4.0, len(M)))), depth=6, lift=2)
    open_hand(S, M[-1], M[-1] - M[-2], lift=3)


def build_body(S, M):
    """The Body: the head in profile (the first star) on its shoulders, the torso down through the
    neck and body stars with the arms reaching forward, the tunic's skirt, the near leg forward to
    the knee and foot, the far leg kneeling back to the hip branch."""
    head, neck, body, knee, foot, hip = [v(p) for p in M]
    along = unit(body - neck)
    side = np.array([-along[1], along[0]])
    if side[0] > 0:
        side = -side  # towards the front (left)
    # Legs, behind the tunic.
    S.shape(limb([body + along * 6 - side * 4, hip + v((-4, -2)), hip + v((6, 2))], [8.0, 5.5, 4.0]), depth=6, lift=-8)
    S.shape(limb([body + along * 6 + side * 4, knee], [9.0, 7.0]), depth=6, lift=-4)
    S.shape(limb([knee, lerp(knee, foot, 0.6) + v((0, 4)), foot], [6.0, 4.8, 3.8]), depth=5, lift=-5)
    S.shape([foot + v((3, -3)), foot + v((3, 4)), foot + v((-9, 4)), foot + v((-8, -1))], depth=3, lift=-4)
    # The torso: shoulders either side of the neck star, the waist at the body star, the hips.
    torso = [neck + side * 13 - along * 4, neck - side * 13 - along * 2, body - side * 11,
             body - side * 13 + along * 10, body + side * 13 + along * 10, body + side * 11]
    S.shape(torso, depth=12, lift=0)
    S.shape(limb([body - side * 12 + along * 3, body + side * 12 + along * 3], [1.4, 1.4]), depth=1.0, lift=2)
    skirt = [body - side * 14 + along * 4, body + side * 14 + along * 4, knee + v((4, -8)), knee + v((8, 4)),
             body + side * 2 + along * 18, body - side * 12 + along * 16]
    S.shape(skirt, depth=7, lift=1.5)
    # Arms: the far one hanging back, the near one reaching forward.
    S.shape(limb([neck - side * 12, neck - side * 15 + along * 14, neck - side * 10 + along * 26], [5.0, 4.2, 3.4]), depth=5, lift=-2)
    S.shape(limb([neck + side * 11, neck + side * 20 + along * 8, neck + side * 30 + along * 4], [5.2, 4.4, 3.6]), depth=5, lift=3)
    # Neck and head.
    S.shape(limb([neck - along * 2, lerp(neck, head, 0.6)], [4.6, 4.2]), depth=4, lift=1)
    head_in_profile(S, head + v((0, 2)), lift=8)


def build_legs(S, M):
    """The Legs: the tunic's hem at the hip (the first star), the near leg through the knee and shin
    to the foot, the far leg through the calf to the heel."""
    hip, knee, shin, foot, calf, heel = [v(p) for p in M]
    S.shape(limb([hip, knee], [10.0, 7.5]), depth=7, lift=0)
    S.shape(limb([knee, shin, foot], [6.5, 5.0, 3.8]), depth=5, lift=-1)
    S.shape([foot + v((2, -3)), foot + v((3, 4)), foot + v((-9, 4)), foot + v((-8, 0))], depth=3, lift=-0.5)
    S.shape(limb([knee + v((4, 2)), calf, heel], [7.0, 5.0, 3.8]), depth=5, lift=-3)
    S.shape([heel + v((-2, -3)), heel + v((-3, 4)), heel + v((9, 4)), heel + v((8, 0))], depth=3, lift=-2.5)
    S.shape([hip + v((-14, -6)), hip + v((10, -10)), hip + v((14, 4)), hip + v((-2, 14)), hip + v((-16, 8))], depth=8, lift=3)
    S.shape(limb([hip + v((-12, -4)), hip + v((11, -8))], [1.4, 1.4]), depth=1.0, lift=4)


def build_stream(S, M):
    """The Stream: water winding down through every star, widening, to a splash past the last."""
    path = water(S, M + [tuple(v(M[-1]) + v((6, 10)))], 3.0, 7.0, lift=0.0)
    droplets(S, path, lift=1.0)
    splash(S, v(M[-1]) + v((8, 10)), width=16.0, lift=-1.0)


def build_jar(S, M):
    """The Jar: an amphora upside down, pouring: its foot by the top star, its belly round the
    centre star, its ear handles through the two side stars, its rim on the lip star, and the water
    falling from it through the spout star."""
    top, centre, left, right, lip, spout = [v(p) for p in M]
    amphora(S, foot=top + v((0, -4)), rim=lip + v((0, 2)), through=(right, left), depth=16.0, lift=4.0)
    path = water(S, [lip + v((-1, 5)), lerp(lip, spout, 0.5) + v((-2, 0)), spout, spout + v((-4, 14))], 2.8, 5.0, lift=0.0)
    droplets(S, path, every=8, offset=6.0, lift=1.0)


STAGE_BUILDERS = {"hand": build_hand, "body": build_body, "legs": build_legs, "stream": build_stream, "jar": build_jar}


# --- shading, pieces -----------------------------------------------------------------------

def shade(S):
    """The Scorpio's shading, per material: the figure on the N ramp, the water on the M ramp."""
    img = np.zeros((H, W, 4), dtype=np.uint8)
    inside = S.z >= 0.0
    mats = np.array(S.mats + [""], dtype=object)[np.where(S.owner >= 0, S.owner, len(S.mats))]
    for mat, (ramp, rim) in RAMPS.items():
        sc.RAMP[:] = ramp
        sc.RIM[:] = rim
        part = sc.shade(S)
        mask = inside & (mats == mat)
        img[mask] = part[mask]
        aura = (~inside) & (part[..., 3] > 0) & (img[..., 3] == 0)
        img[aura] = part[aura]
    sc.RAMP[:] = RAMPS["body"][0]
    sc.RIM[:] = RAMPS["body"][1]
    return img


def stardust(img):
    """The Scorpio's stardust specks on the figure's dark steps, and glints on the water."""
    dark = {RGB[k] for k in ("N2", "N3", "N4")}
    wet = {RGB[k] for k in ("M4", "M5")}
    for y in range(H):
        for x in range(W):
            if not img[y, x, 3]:
                continue
            colour = tuple(img[y, x, :3])
            if colour in wet:
                h = (x * 2246822519 + y * 3266489917) & 0xFFFFFFFF
                h = ((h ^ (h >> 15)) * 668265263) & 0xFFFFFFFF
                if h % 11 == 0:
                    img[y, x, :3] = RGB["M6"] if h % 4 else RGB["D0"]
            elif colour in dark:
                h = (x * 374761393 + y * 668265263) & 0xFFFFFFFF
                h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
                if h % 37 == 0:
                    img[y, x, :3] = RGB["N8"] if h % 3 else RGB["D0"]


def eyes(S, img):
    """Each head's eye: one dark pixel under the brow."""
    for x, y in S.eyes:
        img[y, x, :3] = RGB["N1"]


def build_parts():
    """Writes each part stage's own painting, aquarius_part_<part>.png."""
    ART.mkdir(parents=True, exist_ok=True)
    for part, landmarks in stage_landmarks().items():
        stage = Shapes()
        STAGE_BUILDERS[part](stage, landmarks)
        painting = shade(stage)
        stardust(painting)
        eyes(stage, painting)
        for x, y in landmarks:
            assert stage.owner[y, x] >= 0, f"{part}: landmark ({x}, {y}) sits on nothing"
        sc.save(painting, ART / f"aquarius_part_{part}.png")


if __name__ == "__main__":
    build_parts()
