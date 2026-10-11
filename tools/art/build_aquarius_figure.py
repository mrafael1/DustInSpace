"""Builds the painted Aquarius (chapter 2's reward) and its pieces, in assets/art/:

  aquarius_figure.png         the whole water carrier, the final's reward, as a Stardust Myth vision
  aquarius_piece_<part>.png   the same painting cut into the chapter's five parts (hand, body, legs,
                              stream, jar), in the same full-screen home layout: the chapter chart
                              shows the won ones dormant, then the whole figure once the final is won
  aquarius_part_<part>.png    each part stage's own painting, the same body part fitted to that
                              stage's own landmarks (game/core/star_map.gd, read from the source),
                              shown when the stage is complete

The whole Aquarius is painted in the Stardust Myth style (tools/art/stardust.py): Ganymede, the
youth who pours the gods' water, suggested, not drawn. His form is modelled as outlined shapes
anchored to the 14 landmarks of StarMap.aquarius, keeping human proportions and kneeling: the
shoulders on Sadalmelik and Sadalsuud, the head in profile on a neck above them facing the jar, the
right arm out to the open hand on epsilon, the left arm holding up the tipped amphora (Sadachbia on
the forearm, zeta on its belly, pi by its foot, eta at its neck), the tunic belted at theta, the
near knee on lambda and the shin down through tau to a flat foot, the far knee on the ground at
Skat, its shin tapering back along the ground to a foot with its toes tucked under. The shapes are
never shaded: they give the stardust a mask, normals and joints. Over them go a broken contour on
the lit edges (brighter than the shared default, to match the Scorpio), joint strokes, a thin
hollow nebula (thinner still on the broad jar, torso and head), an outer haze, specks thickest at
the contour and rose glints. What must read at native size is redrawn as strokes over that: the
head (the face's profile, the skull to the nape, open below to a throat line, the eye forward, the
hair a dithered cap), the amphora (a flat foot disc, the belly and neck, one clear lip ellipse, two
ear handles, a faint painted band) and the hand gripping it, the open hand on epsilon, the legs'
bends and feet (the far thigh's back edge into the shin, the heels, the near ankle's notch), the
torso's back and the tunic's hem. The water is not a form but flowing dust: three wavering strands
over a sparse dithered ribbon from the jar's mouth through phi, psi and 98. The mythic flourish:
Piscis Austrinus, the southern fish, drinking the poured water at its end, a broken stardust
contour low in the sky. Every pixel is a palette N step above the sky behind it, or a speck (N7,
N8, D0) or glint (N9); opaque or empty; nothing in the Sun's zone (y < 78); each landmark star in
a small clear gap (nothing within 2 px, no speck within its size's gap, no lone speck just past
it), its own pixel painted one faint step (hidden under it) so its piece holds it.

The pieces partition the whole: each pixel goes with the part of the shape under it (ChapterDef
aquarius; the head with the body, the jar arm with the jar, a shape under a star with that star's
part), else the stream's (its strands and the fish), else the nearest tagged pixel's.

The part stages keep the shaded-solid style: each part drawn as smooth outlines, given roundness
from its own shape and shaded as the Scorpio's stages are (tools/art/build_scorpio_figure.py: a
stepped ramp lit from the top left, dark creases, a rose rim, stardust specks, a thin aura), the
water on the cool M ramp.

Run: python tools/art/build_aquarius_figure.py [--preview out.png]   (needs Pillow and numpy)
"""

import argparse
import importlib.util
import re
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "art"))
import stardust as sd  # noqa: E402

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

# Aquarius's landmarks (StarMap.aquarius): 0 epsilon (hand), 1 Sadalsuud, 2 Sadalmelik (the
# shoulders), 3 Sadachbia (the forearm), 4 zeta, 5 eta, 6 pi (the amphora), 7 theta (the waist),
# 8 lambda (the near knee), 9 tau (the shin), 10 Skat (the far knee), 11 phi, 12 psi, 13 98 (the
# water).
L = [(150, 156), (124, 140), (98, 124), (74, 118), (50, 112), (26, 118), (52, 88), (90, 150),
     (66, 160), (70, 186), (88, 206), (42, 170), (30, 192), (24, 218)]

# Which part owns each landmark (ChapterDef.aquarius).
STAR_PARTS = {0: "hand", 1: "hand", 2: "body", 7: "body", 8: "legs", 9: "legs", 10: "legs",
              11: "stream", 12: "stream", 13: "stream", 3: "jar", 4: "jar", 5: "jar", 6: "jar"}


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

def amphora(S, foot, rim, through=None, depth=12.0, lift=17.0, handles=True):
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
    for k, side in enumerate((1.0, -1.0) if handles else ()):
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


# (the whole figure is built in the Stardust Myth section below)


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


# --- the whole Aquarius, in the Stardust Myth style (tools/art/stardust.py) -------------

SEED = 11
# Each landmark's size (StarMap.aquarius sizes): the stars' gaps and the preview's stars.
SIZES = ["S", "B", "B", "M", "M", "S", "S", "S", "M", "S", "B", "S", "S", "M"]
# Aquarius's strings, for the preview.
SEGMENTS = [(0, 1), (1, 2), (2, 3), (3, 4), (4, 5), (4, 6), (2, 7), (7, 8), (8, 9), (9, 10),
            (8, 11), (11, 12), (12, 13)]
# The solid tags that go with another part's piece.
TAG_PARTS = {"head": "body", "arm": "jar"}
# Features that must read keep more of their outline (contour bias per tag).
BIAS = {"head": 0.70, "jar": 0.55, "hand": 0.40, "arm": 0.22, "legs": 0.14}
# The amphora's foot and rim (tipped to pour: the foot up by pi, the mouth down at eta).
JAR_FOOT, JAR_RIM = (60, 84), (24, 124)
# The stream's path, from the jar's mouth through phi, psi and 98.
STREAM = [(25, 121), (22, 138), (32, 156), L[11], L[12], L[13]]
# The mythic flourish: Piscis Austrinus, the southern fish, drinking the poured water at its end.
FISH_MOUTH = (26, 224)
FISH_TILT, FISH_SCALE = -0.16, 0.8  # rising to its tail, clear of the near foot
# The feet (outlines): the far one's toes tucked under, its heel up; the near one flat, its heel
# behind an ankle notch.
FAR_FOOT = [(114, 205), (117, 202), (120, 201), (123, 202), (125, 206), (128, 209), (128, 211), (116, 211)]
NEAR_FOOT = [(68, 199), (75, 199), (75, 202), (79, 205), (80, 208), (79, 211), (56, 211), (55, 208),
             (61, 205), (67, 202)]
# Where the jar hand grips the amphora's belly (its knuckles on the outline), and the fist's
# solid round it.
GRIP = (57, 106)
FIST = [(63, 105), (60, 101), (55, 101), (53, 104), (54, 108), (57, 110), (61, 110)]


def build_vision(S):
    """The youth's form (a mask, normals and joints for the stardust; never shaded): kneeling,
    facing left, the far leg behind, the near leg forward, the tunic, the head in profile, the right
    arm out to the open hand on epsilon, the left arm up holding the tipped amphora, the stream.
    Returns the stream's path."""
    hand, sadalsuud, sadalmelik, sadachbia, zeta, eta, pi, theta, knee, tau, skat, phi, psi, s98 = map(v, L)
    up = np.array([0.45, -0.89])
    mid = (sadalmelik + sadalsuud) / 2
    ground = 210.0

    S.tag = "legs"
    # The far leg kneels: the thigh down to the knee on the ground at Skat, the shin back along
    # the ground tapering to the ankle, the foot's toes tucked under, its heel up.
    S.shape(limb([(100, 164), (95, 186), skat], [8.0, 7.0, 5.6]), depth=7, lift=-12)
    S.shape(limb([skat + v((1, 0)), (103, 206.8), (116, 207.8)], [3.7, 2.9, 2.1]), depth=5, lift=-12.5)
    S.shape(FAR_FOOT, depth=3, lift=-11.5)
    # The near leg forward: the thigh to the knee on lambda, the shin down through tau to the
    # ankle, the foot flat on the ground, its heel behind.
    S.shape(limb([(96, 160), (80, 158), knee], [8.0, 7.0, 6.0]), depth=7, lift=-4)
    S.shape(limb([knee, tau, (72, 199)], [5.6, 4.6, 3.4]), depth=6, lift=-6)
    S.shape(NEAR_FOOT, depth=3, lift=-5)

    S.tag = "body"
    torso = [sadalmelik + v((-4, 1)), sadalmelik + v((-7, 10)), (84, 146), (86, 156), (104, 160),
             (114, 154), (120, 147), sadalsuud + v((3, 2)), sadalsuud + v((1, -5)), mid + up * 7 + v((5, 0)),
             mid + up * 7 + v((-6, -1)), sadalmelik + v((1, -4))]
    S.shape(torso, depth=18, lift=0)
    skirt = [(84, 151), (106, 157), (110, 165), (104, 172), (92, 171), (82, 166), (78, 158)]
    S.shape(skirt, depth=6, lift=3)
    S.shape(limb([(84, 152), (108, 159)], [1.3, 1.3]), depth=1.0, lift=4)
    neck_base = mid + up * 4
    head = mid + up * 19.0
    S.tag = "head"
    S.shape(limb([neck_base, lerp(neck_base, head, 0.8)], [4.2, 3.6]), depth=4, lift=1)
    S.marks = {"head": S.count - 1}
    head_in_profile(S, head, lift=6)
    S.marks["head_end"] = S.count

    S.tag = "hand"
    elbow = v((137, 150))
    wrist = v((145, 154))
    S.shape(limb([sadalsuud + v((-2, -3)), lerp(sadalsuud, elbow, 0.4)], [6.2, 5.6]), depth=5, lift=5)
    S.shape(limb([sadalsuud, elbow, wrist], [4.8, 3.9, 3.0]), depth=5, lift=4)
    first = S.count
    open_hand(S, wrist, wrist - elbow + v((0, 1)), lift=4.5)
    S.marks["hand"] = (first, S.count, wrist, wrist - elbow + v((0, 1)))

    S.tag = "arm"
    S.shape(limb([sadalmelik + v((-7, 1)), (84, 122), sadachbia, (60, 108)], [5.2, 4.6, 4.0, 3.6]), depth=5, lift=20)
    S.shape(FIST, depth=3, lift=21)
    S.tag = "jar"
    amphora(S, foot=JAR_FOOT, rim=JAR_RIM, handles=False)
    S.marks["jar"] = S.count - 2

    S.tag = "stream"
    return water(S, STREAM + [FISH_MOUTH], 3.2, 7.5)


def line_px(a, b):
    """The pixels of a 1 px line from a to b."""
    (x0, y0), (x1, y1) = np.round(v(a)).astype(int), np.round(v(b)).astype(int)
    n = max(abs(x1 - x0), abs(y1 - y0), 1)
    return [(int(round(x0 + (x1 - x0) * k / n)), int(round(y0 + (y1 - y0) * k / n))) for k in range(n + 1)]


def polyline_px(points):
    """The pixels of a 1 px line through the points, in order, each once."""
    out = []
    for a, b in zip(points[:-1], points[1:]):
        for p in line_px(a, b):
            if not out or out[-1] != p:
                out.append(p)
    return out


def stroke(dust, points, steps, broken=0.0, salt=71, mine=None):
    """A drawn line of dust through the points, `steps` above the sky; with `broken` > 0 about that
    share of its pixels left out (in short gaps), so it stays a broken contour. Marks `mine`."""
    for k, (x, y) in enumerate(polyline_px(points)):
        if not (0 <= x < W and 0 <= y < H) or sd.hsh(k // 2, salt, 72) < broken:
            continue
        dust.put_px(x, y, steps)
        if mine is not None:
            mine[y, x] = True


def ellipse_pts(centre, major, a, b, start=0.0, end=2 * np.pi, n=40):
    """Points round an ellipse (semi-axes a along `major`, b across it) from `start` to `end`."""
    c, u = v(centre), unit(major)
    w = np.array([-u[1], u[0]])
    return [tuple(c + u * a * np.cos(t) + w * b * np.sin(t)) for t in np.linspace(start, end, n)]


def nebula_fill():
    """How full the nebula is, per pixel: thin over the whole figure (the sky shows through, as on
    the Scorpio), thinner where the form is broad (the jar's belly, the torso's front, the head)."""
    fill = np.full((H, W), 0.85)
    for (x0, y0, x1, y1), f in (((26, 86, 58, 118), 0.3), ((84, 118, 100, 152), 0.4),
                                ((104, 100, 132, 129), 0.0), ((98, 150, 122, 205), 0.6)):
        fill[y0:y1, x0:x1] = f
    return fill


def head_marks(dust, S):
    """The head in profile, drawn as strokes (the solids' outline closed it into a ball): the
    face's profile brightest (brow, nose, lips, chin), the skull round the back to the nape, which
    runs on into the back's line, a throat line from the chin down to the shoulder (the head joins
    the body, open below), an ear, the eye forward under the brow and the curled hair a denser
    dithered cap over the back and top of the skull."""
    zone = (S.owner >= S.marks["head"]) & (S.owner < S.marks["head_end"])
    box = (sd.xs >= 104) & (sd.xs <= 132) & (sd.ys >= 98) & (sd.ys <= 127)
    dust.clear(sd.grow(zone, 1) & box & ~((S.owner >= 0) & (S.owner < S.marks["head"])))
    stroke(dust, [(117, 104), (115, 105), (113, 106), (112, 108), (111, 110), (111, 112), (110, 113),
                  (109, 114), (108, 115), (107, 116), (108, 117), (110, 118), (109, 119), (110, 120),
                  (109, 121), (110, 122), (110, 123), (111, 124), (113, 125)], 4)
    stroke(dust, [(113, 125), (112, 126), (111, 127), (110, 128)], 3)
    stroke(dust, [(117, 104), (119, 103), (122, 103), (124, 104), (126, 105), (127, 106), (128, 108),
                  (129, 110), (129, 115), (128, 118), (127, 121), (125, 124), (123, 126), (122, 128)], 3)
    stroke(dust, [(114, 123), (116, 122)], 2)
    stroke(dust, [(123, 115), (124, 116), (124, 118), (123, 119)], 2)
    hair = mask_of([(117, 104), (122, 103), (126, 105), (129, 110), (129, 116), (127, 121), (125, 121),
                    (123, 117), (121, 112), (119, 108)], smooth=False)
    dust.put(hair & (sd.BAY < 0.6), 2)
    dust.put(hair & (sd.BAY < 0.22), 3)
    stroke(dust, [(117, 105), (119, 108), (121, 112), (123, 116)], 3, broken=0.3, salt=73)
    stroke(dust, [(112, 113), (114, 113)], 2)
    dust.put_px(114, 115, 4)


def open_spline(points, steps=6):
    """A smooth open line through the points (Catmull-Rom, the ends held)."""
    pts = [v(p) for p in points]
    pts = [pts[0]] + pts + [pts[-1]]
    out = []
    for i in range(1, len(pts) - 2):
        p0, p1, p2, p3 = pts[i - 1], pts[i], pts[i + 1], pts[i + 2]
        for t in np.linspace(0, 1, steps, endpoint=False):
            out.append(tuple(0.5 * (2 * p1 + (p2 - p0) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t
                                    + (3 * p1 - p0 - 3 * p2 + p3) * t * t * t)))
    out.append(tuple(pts[-2]))
    return out


# The amphora's half-width along its axis (fractions of foot to rim, px): a short stem under the
# foot disc, the egg belly broadest at the shoulder, the narrow neck flaring to the lip.
JAR_PROFILE = [(0.08, 2.8), (0.13, 5.0), (0.22, 8.8), (0.35, 12.2), (0.5, 13.8), (0.62, 13.4),
               (0.7, 10.6), (0.75, 6.6), (0.78, 4.6), (0.86, 4.3), (0.93, 4.8), (0.96, 6.0)]


def jar_marks(dust, S, tags):
    """The amphora, redrawn as strokes over a sparse nebula (the solids' contour tangled at its
    ends): a short flat foot disc across its axis at the top, a short stem, the belly's outline
    (the lit side brighter, a few breaks), the painted band's two rings and the shoulder ring, the
    neck flaring to one clear lip ellipse at the mouth (the stream's strands leave it), two ear
    handles from the shoulder to the neck, and the fist gripping the belly over its outline."""
    jar = tags == "jar"
    foot, rim = v(JAR_FOOT), v(JAR_RIM)
    length = float(np.linalg.norm(rim - foot))
    a = (rim - foot) / length
    n = np.array([-a[1], a[0]])
    along = ((sd.xs + 0.5 - foot[0]) * a[0] + (sd.ys + 0.5 - foot[1]) * a[1]) / length
    across = (sd.xs + 0.5 - foot[0]) * n[0] + (sd.ys + 0.5 - foot[1]) * n[1]
    # Clear the solids' contour on the jar; keep a thin wisp of its nebula inside.
    zone = sd.grow(jar, 1) & (tags != "arm") & (tags != "stream") & ~(sd.grow(tags == "arm", 0))
    keep = dust.level.copy()
    dust.clear(zone)
    inner = jar & (keep == 1) & (sd.BAY < 0.5)
    dust.put(inner, 1)

    def P(t, w):
        return tuple(foot + a * t * length + n * w)

    # The foot: a flat disc across the axis, then the short stem down to the belly.
    stroke(dust, [P(-0.03, 6.2), P(-0.03, -6.2)], 5)
    stroke(dust, [P(-0.03, 6.2), P(0.025, 6.2), P(0.025, 2.8)], 4)
    stroke(dust, [P(-0.03, -6.2), P(0.025, -6.2), P(0.025, -2.8)], 4)
    # The belly and neck, each side: the lit (upper) side brightest.
    for side, steps in ((1, 5), (-1, 4)):
        line = open_spline([P(0.025, side * 2.8)] + [P(t, side * w) for t, w in JAR_PROFILE])
        stroke(dust, line, steps, broken=0.04 if side > 0 else 0.1, salt=82 + side)
    # The lip: one clear ellipse across the mouth.
    stroke(dust, ellipse_pts(P(0.97, 0), n, 6.2, 2.3), 5)
    # The painted band: only a faint dither (rings across a jar this tipped read as folds).
    band = (along > 0.40) & (along < 0.47) & (np.abs(across) < 11.0) & (sd.BAY < 0.25)
    dust.put(band, 2)
    # The handles: loops from the shoulder out and up to the neck, below the lip.
    for side, steps in ((1, 4), (-1, 3)):
        loop = bezier(v(P(0.62, side * 13.0)), v(P(0.79, side * 20.0)), v(P(0.81, side * 4.4)), 12)
        stroke(dust, loop, steps)
    # The hand gripping the belly: the forearm runs into it, the back of the hand to the knuckles
    # on the jar's edge, four fingers wrapping over it (the outline cleared under them).
    grip = v(GRIP)
    fingers = ((-3.0, 3.0), (-1.0, 4.5), (1.0, 4.5), (3.0, 3.5))  # (across the grip, length)
    under = np.zeros((H, W), bool)
    for s, k in fingers:
        for x, y in line_px(grip + a * s, grip + a * s + n * (k + 1)):
            under[y, x] = True
    dust.clear(sd.grow(under, 1))
    for s, k in fingers:
        stroke(dust, [grip + a * s - n * 0.5, grip + a * s + n * k], 4)
    stroke(dust, [grip - a * 3.4 - n * 0.5, grip - a * 3.8 - n * 4.0], 4)
    stroke(dust, [grip + a * 3.4 - n * 0.5, grip + a * 3.8 - n * 4.0], 3)


def leg_marks(dust):
    """The legs' bends and feet, drawn over the broken contour so the kneel reads: the far
    thigh's back edge turning into the shin's top edge at the knee (Skat's gap kept clear), the
    far foot's heel up and toes tucked on the ground, the near foot's ankle notch and heel, the
    near thigh's underside."""
    stroke(dust, [(107, 165), (105, 174), (103, 184), (101, 192), (99, 197), (100, 200), (104, 202),
                  (110, 203), (115, 204)], 3, broken=0.22, salt=74)
    stroke(dust, [(115, 204), (117, 202), (119, 201), (121, 201), (123, 202), (124, 204), (125, 206),
                  (127, 208), (128, 209), (128, 211)], 3)
    stroke(dust, [(123, 209), (125, 210)], 2)
    stroke(dust, [(75, 194), (75, 201), (74, 203), (77, 204), (79, 206), (80, 208), (79, 210)], 3)
    stroke(dust, [(68, 199), (66, 202), (62, 204), (58, 206), (55, 208), (55, 210)], 3)
    stroke(dust, [(75, 167), (82, 168), (90, 167)], 2, broken=0.25, salt=75)


def body_marks(dust):
    """The torso's back from the armpit down to the hip, and the tunic's hem: broken strokes, so
    the torso, the tunic and the far thigh stay apart."""
    stroke(dust, [(122, 148), (119, 153), (116, 158), (113, 162), (110, 166)], 3, broken=0.2, salt=76)
    stroke(dust, [(80, 165), (86, 169), (93, 171), (100, 172), (105, 171), (110, 167)], 3, broken=0.18, salt=77)


def fish_marks(dust):
    """The mythic flourish: Piscis Austrinus, the southern fish, drinking the poured water from
    its upturned mouth (the stream's end), drawn as a broken contour of stardust low in the sky:
    a back and belly arc, a forked tail, a dorsal fin, a gill, an eye, a few scales. Returns its
    pixels (its piece is the stream's)."""
    mine = np.zeros((H, W), bool)
    m = v(FISH_MOUTH)

    c, k = np.cos(FISH_TILT), np.sin(FISH_TILT)

    def P(x, y):
        x, y = x * FISH_SCALE, y * FISH_SCALE
        return tuple(m + v((x * c - y * k, x * k + y * c)))

    stroke(dust, [P(-1, -2), P(3, -5), P(8, -7), P(15, -7), P(22, -5), P(27, -2)], 4, broken=0.08, salt=78, mine=mine)
    stroke(dust, [P(0, 1), P(3, 4), P(8, 6), P(15, 6), P(22, 4), P(27, 1)], 3, broken=0.1, salt=79, mine=mine)
    stroke(dust, [P(-1, -2), P(1, 0), P(0, 1)], 3, mine=mine)
    stroke(dust, [P(27, -2), P(33, -8), P(31, -1), P(33, 6), P(27, 1)], 4, broken=0.06, salt=80, mine=mine)
    stroke(dust, [P(11, -7), P(14, -11), P(19, -10), P(21, -6)], 3, broken=0.15, salt=81, mine=mine)
    stroke(dust, [P(7, -5), P(9, -1), P(7, 4)], 2, mine=mine)
    ex, ey = (int(c) for c in P(4, -2))
    dust.put_px(ex, ey, 4)
    mine[ey, ex] = True
    for dx, dy in ((12, -2), (16, 0), (20, -2), (14, 3), (19, 2)):
        x, y = (int(c) for c in P(dx, dy))
        dust.put_px(x, y, 1)
        mine[y, x] = True
    return mine


def hand_marks(dust, S):
    """The open hand on epsilon: solids this thin merge into a blob of contour, so the hand is
    redrawn as strokes: the palm's outline, four spread fingers and the thumb (as open_hand
    builds them), each a 1 px line of dust at the outline's strength."""
    first, end, wrist, out = S.marks["hand"]
    zone = (S.owner >= first) & (S.owner < end)
    dust.clear(sd.grow(zone, 1) & (zone | (S.owner < 0)))
    out = unit(out)
    side = np.array([-out[1], out[0]])
    palm = v(wrist) + out * 5.0
    dust.put(sd.edge_of(mask_of(limb([v(wrist), palm + out * 1.5], [3.0, 4.0]))), 3)
    for spread in (-0.45, -0.15, 0.15, 0.45):
        base = palm + out * 2.0 + side * spread * 7.0
        tip = base + out * (7.0 - abs(spread) * 3.0) + side * spread * 2.5
        for x, y in line_px(base, tip):
            dust.put_px(x, y, 4)
    for x, y in line_px(palm - side * 3.5, palm - side * 7.5 + out * 2.0):
        dust.put_px(x, y, 4)


def paint_stream(dust, path, r0=2.4, r1=6.5):
    """The poured water as flowing stardust, not a tube: three wavering strands down the stream
    (the middle one brightest, each broken into dashes) over a sparse dithered ribbon, widening as
    it falls, with specks of spray glinting on it. Returns the pixels it painted."""
    mine = np.zeros((H, W), bool)
    pts = []
    for a, b in zip(path[:-1], path[1:]):
        a, b = v(a), v(b)
        steps = max(int(np.ceil(np.linalg.norm(b - a))), 1)
        pts += [a + (b - a) * i / steps for i in range(steps)]
    pts.append(v(path[-1]))
    n = len(pts)
    for k in range(n):
        t = k / (n - 1)
        a, b = pts[max(k - 1, 0)], pts[min(k + 1, n - 1)]
        d = unit(b - a)
        side = np.array([-d[1], d[0]])
        width = r0 + (r1 - r0) * t
        for c in np.linspace(-1.0, 1.0, 9):
            q = pts[k] + side * c * width
            x, y = int(round(q[0])), int(round(q[1]))
            if 0 <= x < W and 0 <= y < H and sd.BAY[y, x] < 0.22 - 0.12 * abs(c):
                dust.put_px(x, y, 1)
                mine[y, x] = True
    for k in range(n):
        t = k / (n - 1)
        a, b = pts[max(k - 1, 0)], pts[min(k + 1, n - 1)]
        d = unit(b - a)
        side = np.array([-d[1], d[0]])
        width = r0 + (r1 - r0) * t
        for j, (across, step) in enumerate(((-0.75, 2), (0.0, 3), (0.75, 2))):
            wave = 0.9 * np.sin(k * 0.45 + j * 2.1)
            q = pts[k] + side * (across * width + wave)
            x, y = int(round(q[0])), int(round(q[1]))
            if not (0 <= x < W and 0 <= y < H) or sd.hsh(k, j, 51) < 0.12 + 0.25 * t * (j != 1):
                continue
            dust.put_px(x, y, step + (1 if j == 1 else 0) + (1 if j != 1 and t < 0.2 else 0))
            mine[y, x] = True
            if sd.hsh(x, y, 52) < 0.10:
                dust.fixed[y, x] = "D0" if sd.hsh(x, y, 53) < 0.4 else "N8"
    return mine


def lone_specks_near_stars(dust, landmarks, sizes, reach=5):
    """Clears specks just past a star's gap (within its gap + `reach`) that stand alone (at most
    one painted neighbour): a pale dot there could pass for a star."""
    painted = (dust.level >= 1) | (dust.fixed != "")
    nb = sum(sd.shift(painted, dy, dx).astype(int) for dy in (-1, 0, 1) for dx in (-1, 0, 1)
             if dy or dx)
    for (lx, ly), s in zip(landmarks, sizes):
        r2 = (sd.xs - lx) ** 2 + (sd.ys - ly) ** 2
        near = r2 <= (sd.STAR_GAP[s] + reach) ** 2
        dust.clear(near & (dust.fixed != "") & (nb <= 1))


def paint_vision(S, stream):
    """The stardust over the form. Returns the painting and the marks its pieces need."""
    rng = np.random.default_rng(SEED)
    tags = np.array(S.tags + [""], dtype=object)[S.owner]
    # The water is painted as flowing dust (paint_stream), not as a form.
    inside = (S.z >= 0.0) & (tags != "stream")
    lit = np.clip(S.n @ sc.LIGHT, 0.0, 1.0)
    facing = S.n[..., 0] * sc.LIGHT[0] + S.n[..., 1] * sc.LIGHT[1]
    dust = sd.Dust()
    edge = sd.edge_of(inside)
    crease = sd.creases_of(inside, S.owner, S.z, edge)
    dist = sd.distance_inside(inside)

    bias = sd.contour_bias(facing, BIAS, tags)
    contour = sd.broken_contour(dust, rng, edge, facing, lit, bias)
    # Brighter strokes than the shared default, as on the Scorpio: the lit side two steps more.
    dust.put(contour & (facing > -0.2), 3)
    dust.put(contour & (lit > 0.4), 4)
    dust.put(contour & (lit > 0.75), 5)
    sd.joint_strokes(dust, rng, crease)
    sd.nebula(dust, rng, inside, dist, lit, fill=nebula_fill())
    out_d = sd.outer_haze(dust, rng, inside)
    water_px = paint_stream(dust, stream)
    sd.specks(dust, inside, dist, out_d, lit)
    sd.rose_glints(dust, contour, lit)
    jar_marks(dust, S, tags)
    head_marks(dust, S)
    leg_marks(dust)
    body_marks(dust)
    fish_px = fish_marks(dust)
    hand_marks(dust, S)
    sd.star_gaps(dust, L, SIZES)
    lone_specks_near_stars(dust, L, SIZES)
    # Each star sits in a small clear gap (nothing within 2 px but its own pixel, which is painted
    # one faint step, hidden under the star: the piece the star belongs to holds it, so the chart
    # can grow that piece from its stars).
    for x, y in L:
        dust.clear((sd.xs - x) ** 2 + (sd.ys - y) ** 2 <= 4)
        dust.level[y, x] = 1
    img = sd.sun_clamp(sd.resolve(dust, sd.sky_index()))
    return img, {"trail": water_px | fish_px}


def part_tags(S, img, marks):
    """Each painted pixel's part: the part of the solid under it (a joint under a star goes with
    that star's part), else the stream's (the flourish), else the nearest tagged pixel's."""
    for star, part in STAR_PARTS.items():
        x, y = L[star]
        assert S.owner[y, x] >= 0, f"landmark {star} sits on nothing"
        S.tags[S.owner[y, x]] = part
    names = [TAG_PARTS.get(t, t) for t in S.tags]
    for star, part in STAR_PARTS.items():
        x, y = L[star]
        assert names[S.owner[y, x]] == part, f"landmark {star} sits on a solid of two parts"
    tags = np.array(names + [""], dtype=object)[S.owner]
    tags[marks["trail"] & (tags == "")] = "stream"
    return sd.spread_tags(tags, img[..., 3] > 0)


def paint_aquarius():
    """The whole Aquarius. Returns the painting, its form and its marks (for the pieces)."""
    S = Shapes()
    stream = build_vision(S)
    img, marks = paint_vision(S, stream)
    return img, S, marks


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--preview", type=Path, help="also write the figure over the sky, x3, here")
    args = parser.parse_args()
    ART.mkdir(parents=True, exist_ok=True)
    img, S, marks = paint_aquarius()
    used = sd.check(img)
    print(f"figure: {sum(used.values())} px, {used}")
    sd.save(img, ART / "aquarius_figure.png")
    for part, piece in sd.pieces(img, part_tags(S, img, marks), PARTS).items():
        sd.save(piece, ART / f"aquarius_piece_{part}.png")
    if args.preview:
        sd.preview(img, L, SIZES, SEGMENTS).save(args.preview)
        print(f"wrote {args.preview}")
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
    main()
