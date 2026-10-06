"""Builds the painted Aquarius (chapter 2's reward) and its pieces, in assets/art/:

  aquarius_figure.png         the whole water carrier, the final's reward and the chart's
  aquarius_piece_<part>.png   the same painting cut into the chapter's five parts (hand, body, legs,
                              stream, jar), in the same full-screen home layout: the chapter chart
                              assembles them as parts are won
  aquarius_part_<part>.png    each part stage's own painting, the same body part fitted to that
                              stage's own landmarks (game/core/star_map.gd, read from the source),
                              shown when the stage is complete

The figure is drawn as smooth outlines at native size, like vector art: each part (the tunic, a
limb, the head in profile, the amphora's profile) is an outline, given roundness from its own
shape (its height grows with the distance to its edge), then lit and shaded exactly as the
Scorpio is (tools/art/build_scorpio_figure.py: light from the top left, a stepped ramp with a Bayer
checker only along each seam, dark creases where one part lies over another, a rose rim on lit
edges, stardust specks, a thin aura). Spheres and capsules suit a segmented scorpion; a person
drawn with them reads as a mannequin.

The stars are points on the body, not its joints, so it keeps human proportions (about seven heads,
kneeling): the shoulders on Sadalmelik and Sadalsuud, the head above them in profile facing the
jar, the right arm out to the open hand on epsilon, the left arm holding up a Greek amphora
(Sadachbia on the forearm, zeta on its belly, pi by its foot, eta at its mouth) tipped to pour, the
tunic belted at theta, the near knee forward on lambda and the shin down through tau, the far knee
on the ground at Skat, and the water pouring down the left through phi, psi and 98 to a splash.
The water is its own material on the cool M ramp (M3-M6, a D0 rim, sparse glints).
No colour outside the Stellar Sun palette; every pixel opaque or empty.

Run: python tools/art/build_aquarius_figure.py   (needs Pillow and numpy)
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


def head_in_profile(S, head, lift):
    """A head in profile facing left: brow, nose, lips and chin; hair falling in curls at the
    back; a fillet band round it."""
    head = v(head)

    def P(x, y):
        return head + v((x, y))

    face = [P(-7, -6), P(-8, -2), P(-11, 1), P(-8, 2), P(-9, 4), P(-7, 5), P(-8, 7), P(-5, 10),
            P(1, 10), P(6, 7), P(8, 0), P(5, -8), P(-2, -10)]
    S.shape(face, depth=7, lift=lift)
    hair = [P(-6, -8), P(-1, -11), P(6, -10), P(10, -5), P(11, 1), P(10, 6), P(12, 9), P(8, 11),
            P(5, 8), P(4, 2), P(1, -3), P(-4, -4), P(-7, -5)]
    S.shape(hair, depth=5, lift=lift + 2)
    S.shape(limb([P(-6, -6), P(0, -8), P(7, -5), P(10, -2)], [0.9, 1.0, 1.0, 0.9]), depth=1.2, lift=lift + 4)


def build_figure(S):
    hand, sadalsuud, sadalmelik, sadachbia, zeta, eta, pi, theta, knee, tau, skat, phi, psi, s98 = map(v, L)
    up = np.array([0.52, -0.85])
    mid = (sadalmelik + sadalsuud) / 2

    # The far leg, behind: the thigh from under the tunic to the knee on the ground (Skat), the
    # shin lying back, the foot.
    S.tag = "legs"
    S.shape(limb([(100, 168), (94, 188), skat], [8.0, 7.0, 6.0]), depth=7, lift=-12)
    S.shape(limb([skat, (106, 210), (122, 209)], [5.5, 4.6, 3.6]), depth=5, lift=-12.5)
    S.shape([(118, 206), (128, 205), (131, 209), (119, 212)], depth=3, lift=-11.5)
    # The near leg: the shin from the knee (lambda) down through tau, the foot flat.
    S.shape(limb([knee, (67, 174), tau, (71, 193)], [6.5, 5.4, 4.6, 4.0]), depth=6, lift=-6)
    S.shape([(73, 189), (74, 197), (56, 198), (54, 194), (62, 191)], depth=3, lift=-5)

    # The tunic: the torso from the shoulders to the waist (theta), the skirt over the hips and the
    # near thigh, a belt, a mantle over the left shoulder.
    S.tag = "body"
    torso = [sadalmelik + v((-3, 0)), sadalmelik + v((-6, 10)), (84, 146), (86, 158), (104, 162),
             (114, 154), (120, 146), sadalsuud + v((3, 1)), sadalsuud + v((0, -6)), mid + up * 8 + v((6, 0)),
             mid + up * 8 + v((-6, -2)), sadalmelik + v((2, -4))]
    S.shape(torso, depth=11, lift=0)
    skirt = [(82, 150), (106, 158), (112, 166), (106, 175), (92, 177), (78, 171), (68, 166), (64, 159), (70, 153)]
    S.shape(skirt, depth=7, lift=5)
    S.shape(limb([(83, 153), (111, 160)], [1.4, 1.4]), depth=1.0, lift=6)
    mantle = [sadalmelik + v((-4, -1)), sadalmelik + v((4, -4)), (106, 134), (108, 152), (100, 158), (94, 146)]
    S.shape(mantle, depth=6, lift=8)
    S.shape(limb([mid + up * 6, mid + up * 12], [4.5, 4.2]), depth=4, lift=1)
    head_in_profile(S, mid + up * 18.0, lift=12)

    # The near knee shows through the drape (lambda sits on it).
    S.tag = "legs"
    S.shape(limb([knee + v((6, -1)), knee], [5.5, 5.0]), depth=4, lift=7)

    # The right arm: a short sleeve, the bare arm out and down to the open hand on epsilon.
    S.tag = "hand"
    elbow = v((138, 151))
    S.shape(limb([sadalsuud + v((0, -2)), lerp(sadalsuud, elbow, 0.45)], [7.0, 6.5]), depth=6, lift=6)
    S.shape(limb([sadalsuud, elbow, (147, 155)], [5.2, 4.2, 3.4]), depth=5, lift=4)
    S.shape([(146, 152), (153, 152), (157, 155), (156, 159), (149, 160), (145, 157)], depth=3, lift=5)

    # The left arm from beside the shoulder to the amphora (Sadachbia on the forearm), the hand at
    # its side; the amphora tipped about 45 degrees, its foot up by pi, its mouth down at eta.
    S.tag = "jar"
    S.shape(limb([(91, 125), (84, 123), sadachbia, (57, 105)], [5.4, 4.8, 4.2, 3.8]), depth=5, lift=20)
    amphora(S, foot=(60, 82), rim=(24, 124))

    # The water: from the mouth down the left through phi, psi and 98, drops breaking off, a splash.
    S.tag = "stream"
    path = water(S, [(24, 126), (22, 140), (32, 156), phi, psi, s98, s98 + v((4, 12))], 2.0, 7.5)
    droplets(S, path)
    splash(S, s98 + v((6, 12)))


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


def pieces(S, img):
    """The whole cut by part, as the Scorpio's: each pixel with its part's solid, each aura pixel
    with the body pixel beside it. Every star must lie on a part of its own part."""
    for star, part in STAR_PARTS.items():
        x, y = L[star]
        owner = S.owner[y, x]
        assert owner >= 0, f"landmark {star} sits on nothing"
        assert S.tags[owner] == part, f"landmark {star} ({part}) sits on the {S.tags[owner]}"
    tags = np.full((H, W), "", dtype=object)
    inside = S.z >= 0.0
    for y, x in zip(*np.nonzero(inside)):
        tags[y, x] = S.tags[S.owner[y, x]]
    for y, x in zip(*np.nonzero(img[..., 3] > 0)):
        if tags[y, x]:
            continue
        for dy, dx in ((0, 1), (1, 0), (0, -1), (-1, 0)):
            ny, nx = (y + dy) % H, (x + dx) % W
            if tags[ny, nx] and inside[ny, nx]:
                tags[y, x] = tags[ny, nx]
                break
    assert all(tags[y, x] for y, x in zip(*np.nonzero(img[..., 3] > 0))), "every pixel has a part"
    out = {}
    for part in PARTS:
        piece = img.copy()
        piece[tags != part] = 0
        out[part] = piece
    return out


def main():
    ART.mkdir(parents=True, exist_ok=True)
    S = Shapes()
    build_figure(S)
    img = shade(S)
    stardust(img)
    sc.save(img, ART / "aquarius_figure.png")
    for part, piece in pieces(S, img).items():
        sc.save(piece, ART / f"aquarius_piece_{part}.png")
    for part, landmarks in stage_landmarks().items():
        stage = Shapes()
        STAGE_BUILDERS[part](stage, landmarks)
        painting = shade(stage)
        stardust(painting)
        for x, y in landmarks:
            assert stage.owner[y, x] >= 0, f"{part}: landmark ({x}, {y}) sits on nothing"
        sc.save(painting, ART / f"aquarius_part_{part}.png")


if __name__ == "__main__":
    main()
