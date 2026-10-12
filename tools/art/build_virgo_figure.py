"""Builds the Virgo's paintings (chapter 4's rewards), in assets/art/:

  virgo_figure.png         the whole winged maiden, the final's reward, as a Stardust Myth vision
  virgo_piece_<part>.png   the same painting cut into the chapter's five parts (head, wing, robe,
                           feet, wheat; ChapterDef.virgo), in the same full-screen home layout: the
                           chapter chart shows the won ones dormant, then the whole figure once the
                           final is won

The Virgo has no part-stage paintings yet (virgo_part_<stage>.png); this builder writes none.

The whole Virgo is painted in the Stardust Myth style (tools/art/stardust.py), as the Scorpio is:
the maiden is suggested, not drawn. Astraea, the star maiden, the last of the immortals to leave
the earth, flies to the right like a winged Victory, her stars points on her body: her face lifted
to the stars under a faint diadem of dust, the throat at Zavijava and eta on her breast, her hair
streaming back in loose strands; a feathered wing raised from her back through delta to its tip at
Vindemiatrix; the far arm reaching ahead into her flight; the near arm bent at the elbow, the fist
at her hip (Porrima) holding a stalk of wheat that falls past theta to its ear at Spica; one long
end of her girdle streaming back through zeta and tau to 109; below a knee-length chiton her legs
part like scissors, iota on the back shin, the back foot pointed at mu, the front foot at kappa.
The mythic flourish: her wake, a stream of stardust leaving the wing's tip and curling back on
itself in the empty sky, the way she left for the heavens.

Her form is modelled as overlapping solids (outlines domed by their distance to the edge, spheroids
and tapered capsules) that are never shaded: they give the stardust a mask, normals and joints.
The parts too fine for a solid are drawn as strokes of dust: the face's profile (pixel by pixel),
the hair's strands, the girdle's ribbon, the fist, the wheat's stalk, grains and awns. Over the
form go a broken contour (its key lines lifted: the profile, the shoulder, the wing's leading edge,
the shins and feet), faint joint strokes (the feathers' rows, the robe's folds, the hairline),
sparse hollow nebula wisps, an outer haze, specks thickest at the contour, rose glints, the eye,
and the wake. Every pixel is a palette N step above the sky behind it, or a speck (N7, N8, D0) or
glint (N9); opaque or empty; nothing in the Sun's zone (y < 78); each landmark star in a gap clear
of specks (stardust.quiet_stars), on one faint pixel of its own part (under the star).

The pieces partition the whole: each pixel goes with the part of the stroke drawn on it (hair,
ribbon, fist, wheat, diadem), else the part of the solid under it (a joint where two parts meet
goes with the part of the star on it), else the wake's (the wing), else the nearest tagged pixel.

Run: python tools/art/build_virgo_figure.py [--preview out.png]   (needs Pillow and numpy)
"""

import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
import stardust as sd  # noqa: E402
import build_scorpio_figure as sc  # noqa: E402  (its Solids: the form's z, normals and owners)

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / "assets" / "art"
OUT = ART / "virgo_figure.png"
PARTS = ("head", "wing", "robe", "feet", "wheat")
W, H = sd.W, sd.H
v, lerp, unit, bezier = sc.v, sc.lerp, sc.unit, sc.bezier

SEED = 11
SS = 4  # outlines are filled 4x larger, then each pixel takes the majority: smooth stepped edges
LIGHT = np.array([-0.55, -0.65, 0.52])
LIGHT /= np.linalg.norm(LIGHT)

# Virgo's landmarks (StarMap.virgo): 0 Zavijava (the throat), 1 eta (the breast), 2 Porrima (the
# fist, at the hip), 3 delta (the wing), 4 Vindemiatrix (the wing's tip), 5 theta (the stalk),
# 6 Spica (the ear of wheat), 7 zeta, 8 tau, 9 109 (the girdle's end), 10 iota (the back shin),
# 11 mu (the back foot), 12 kappa (the front foot).
L = [(162, 136), (140, 152), (116, 160), (106, 132), (98, 96), (100, 186), (86, 216), (78, 150),
     (56, 134), (24, 126), (50, 178), (22, 172), (48, 206)]
SIZES = ["M", "S", "M", "S", "B", "S", "B", "M", "S", "M", "S", "S", "S"]
SEGMENTS = [(0, 1), (1, 2), (2, 3), (3, 4), (2, 5), (5, 6), (3, 7), (7, 8), (8, 9), (7, 10),
            (10, 11), (10, 12)]
# Which part owns each landmark (ChapterDef.virgo).
STAR_PARTS = {0: "head", 1: "head", 3: "wing", 4: "wing", 7: "robe", 8: "robe", 9: "robe",
              10: "feet", 11: "feet", 12: "feet", 6: "wheat", 5: "wheat", 2: "wheat"}

# Each solid's tag (a feature) and the part its pixels go with.
TAG_PARTS = {
    "face": "head", "hair": "head", "neck": "head", "torso": "head", "far_arm": "head",
    "wing": "wing", "feather": "wing", "wing_edge": "wing",
    "chiton": "robe", "fold": "robe", "girdle": "robe",
    "leg": "feet", "foot": "feet",
    "arm": "wheat",
}
# The features whose outline must read are held almost whole (stardust.contour_bias).
CONTOUR_WEIGHTS = {"face": 0.55, "hair": 0.15, "foot": 0.55, "far_arm": 0.30, "arm": 0.40,
                   "leg": 0.35, "torso": 0.15, "wing": 0.45, "feather": 0.40, "wing_edge": 0.85}
# The key lines, lifted to N7/N8 where the contour is drawn (steps above the sky): the profile,
# the shoulder and back, the wing's leading edge, the shins and the feet.
KEY_LINES = {"face": 5, "torso": 5, "wing_edge": 6, "leg": 5, "foot": 5, "arm": 4, "far_arm": 4}
# The nebula's density per feature: sparse everywhere (the sky shows through), the hair a touch
# denser so the face reads in front of it.
FILL_DEFAULT = 0.4
FILL = {"hair": 0.6, "face": 0.0, "neck": 0.25, "torso": 0.25, "chiton": 0.3, "fold": 0.3,
        "wing": 0.35, "feather": 0.35}


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


def blur(a, passes=2):
    for _ in range(passes):
        a = (a + np.roll(a, 1, 0) + np.roll(a, -1, 0) + np.roll(a, 1, 1) + np.roll(a, -1, 1)) / 5.0
    return a


def rotate(p, degrees):
    a = np.radians(degrees)
    c, s_ = np.cos(a), np.sin(a)
    return np.array([p[0] * c - p[1] * s_, p[0] * s_ + p[1] * c])


def line_px(a, b):
    """The pixels of a 1 px line from `a` to `b`."""
    (x0, y0), (x1, y1) = a, b
    n = max(int(round(max(abs(x1 - x0), abs(y1 - y0)))), 1)
    return [(int(round(x0 + (x1 - x0) * k / n)), int(round(y0 + (y1 - y0) * k / n))) for k in range(n + 1)]


def path_px(points):
    """The pixels of a 1 px polyline through `points`, each once, in order, with its fraction t
    (0..1) along the path."""
    seen, out = set(), []
    for a, b in zip(points, points[1:]):
        for p in line_px(a, b):
            if p not in seen:
                seen.add(p)
                out.append(p)
    n = max(len(out) - 1, 1)
    return [(p, k / n) for k, p in enumerate(out)]


class Shapes(sc.Solids):
    """The Scorpio's solids, plus parts drawn as outlines."""

    def shape(self, outline, depth=8.0, lift=0.0, smooth=True, soften=2):
        """A part from its outline, domed by its distance to the edge (its normals from that
        dome's slope). `lift` stacks parts: a higher one lies over a lower one."""
        self.mask_shape(mask_of(outline, smooth), depth, lift, soften)

    def mask_shape(self, mask, depth=8.0, lift=0.0, soften=1):
        """A part from its pixels, domed as `shape`."""
        d = sd.distance_inside(mask)
        h = np.sqrt(np.clip(d / max(d.max(), 1.0), 0.0, 1.0)) * depth
        gy, gx = np.gradient(blur(h * mask, soften))
        self._put(mask, h, -gx, -gy, np.full(h.shape, 0.9), lift)


class Strokes:
    """The parts drawn as strokes of dust, too fine for a solid: per pixel its steps above the sky
    (or an absolute colour) and the part it goes with."""

    def __init__(self):
        self.level = np.full((H, W), -1)
        self.fixed = np.full((H, W), "", dtype=object)
        self.part = np.full((H, W), "", dtype=object)

    def put(self, x, y, steps, part, colour=""):
        if 0 <= x < W and 0 <= y < H:
            self.level[y, x] = max(self.level[y, x], steps)
            if colour:
                self.fixed[y, x] = colour
            self.part[y, x] = part

    def drawn(self):
        return (self.level >= 0) | (self.fixed != "")

    def onto(self, dust: sd.Dust):
        """Lays the strokes over the canvas: they replace whatever lies under them."""
        m = self.drawn()
        dust.level[m] = self.level[m]
        dust.fixed[m] = self.fixed[m]


# --- the head ------------------------------------------------------------------------------

# The face's profile, pixel by pixel on screen, looking up and to the right, from the top of the
# forehead down the brow, the nose (5 px out from the brow), the lips and the chin, then back under
# the jaw into the neck: drawn whole and bright, it must read at native size.
PROFILE = [(163, 107), (164, 108), (165, 108), (166, 109), (166, 110), (167, 111), (168, 112),
           (168, 113), (167, 114), (168, 115), (169, 116), (170, 117), (171, 118), (172, 119),
           (173, 120), (172, 121), (171, 121), (170, 122), (171, 123), (170, 124), (171, 125),
           (170, 126), (170, 127), (171, 128), (170, 129), (169, 130), (168, 130), (167, 130),
           (166, 131), (165, 131)]
# The profile's features that step out (nose, lips, chin) are a step brighter than the rest.
PROFILE_BRIGHT = range(9, 25)
# The hair's span over the skull and down the back of the head, per row from HEAD_TOP.
HEAD_TOP = 106
HAIR_ROWS = [(154, 161), (152, 162), (151, 162), (150, 162), (149, 160), (149, 159), (149, 158),
             (149, 157), (149, 157), (149, 157), (149, 157), (149, 157), (149, 157), (150, 157),
             (150, 157), (150, 157), (150, 157), (151, 157), (151, 158), (152, 158), (153, 158),
             (154, 158), (156, 158)]
EYE = ((164, 115), (165, 115))
HEAD_CENTRE = (158.0, 117.0)
KNOT = (151.0, 113.0)


def head_mask(which):
    """The pixels of the hair ("h") or the face ("F": from the hairline to the profile)."""
    front = {}
    for x, y in PROFILE:
        front[y] = max(front.get(y, 0), x)
    m = np.zeros((H, W), bool)
    for y in range(HEAD_TOP, max(front) + 1):
        row = y - HEAD_TOP
        h0, h1 = HAIR_ROWS[row] if row < len(HAIR_ROWS) else (None, 158 + (y - 128))
        if which == "h" and h0 is not None:
            m[y, h0:h1 + 1] = True
        if which == "F" and y in front:
            m[y, h1 + 1:front[y] + 1] = True
    return m


def build_head(S):
    """The head: the neck from the shoulders up to the jaw (Zavijava at the throat), the face, the
    hair over the crown gathered in a knot at the back."""
    S.tag = "neck"
    S.shape(limb([(154, 143), (159, 134), (164, 127)], [5.4, 4.6, 4.0]), depth=4, lift=6)
    S.tag = "face"
    S.mask_shape(head_mask("F"), depth=7, lift=8)
    S.tag = "hair"
    S.mask_shape(head_mask("h"), depth=3, lift=9)
    S.ellipsoid(KNOT, v((-1, 0.2)), 3.6, 3.0, depth=2.5, lift=9.2)


def draw_hair(T: Strokes):
    """Loose strands streaming back from the knot, waving, each fading and breaking towards its
    end: the hair in the wind of her flight (N5/N6 at its root)."""
    strands = [  # (start, length, drop, wave amplitude, waves, phase)
        ((149, 110), 24, 3, 1.6, 1.3, 0.0),
        ((148, 113), 30, 8, 2.0, 1.1, 1.7),
        ((148, 116), 22, 10, 1.4, 1.5, 3.1),
        ((150, 119), 16, 9, 1.2, 1.2, 0.8),
    ]
    for k, ((x0, y0), length, drop, amp, waves, phase) in enumerate(strands):
        pts = []
        for i in range(41):
            t = i / 40
            x = x0 - length * t
            y = y0 + drop * t * t + amp * np.sin(phase + t * waves * 2 * np.pi) * t
            pts.append((x, y))
        for (x, y), t in path_px(pts):
            if sd.hsh(x, y, 60 + k) < 0.15 + 0.75 * t * t:
                continue
            T.put(x, y, 3 if t < 0.35 else (2 if t < 0.75 else 1), "head")


def draw_diadem(T: Strokes):
    """A faint diadem of dust over her brow, the star maiden's: broken N5 dots on an arc."""
    cx, cy = HEAD_CENTRE
    for a in np.linspace(-150, -45, 34):
        r = np.radians(a)
        x, y = int(round(cx + 17.0 * np.cos(r))), int(round(cy + 16.0 * np.sin(r)))
        if (x + y) % 2 == 0 and sd.hsh(x, y, 70) > 0.3:
            T.put(x, y, 3, "head", "N5")


# --- the wing ------------------------------------------------------------------------------

# Where the wing rises from her back.
WING_ROOT = (134, 142)


def build_wing(S):
    """A bird's wing raised from her back to its tip at Vindemiatrix, as a statue's: a bowed
    leading edge (the arm of the wing, its line held whole and brightest), and the feathers hanging
    back from it, fanning from the secondaries near her back (down and back) to the primaries
    sweeping up to the tip, their rounded ends making a scalloped trailing edge.
    In the row the feather nearer the body lies over the next."""
    R, T = v(WING_ROOT), v(L[4]) + v((-1, -5))
    along = unit(T - R)
    back = np.array([along[1], -along[0]])
    if back[0] > 0:
        back = -back  # the trailing edge lies to the left of the leading edge
    length = float(np.linalg.norm(T - R))
    bow = [(0.0, 2), (0.3, 7), (0.55, 8), (0.8, 5), (1.0, 0)]

    def lead(t):
        """The leading edge's point `t` of the way from root to tip (bowed forward)."""
        return R + along * length * t - back * float(np.interp(t, [p[0] for p in bow], [p[1] for p in bow]))

    def feather(u, reach):
        base = lead(0.03 + 0.8 * u) + back * 1.5
        angle = np.radians(88 - 62 * u)
        d = along * np.cos(angle) + back * np.sin(angle)
        size = float(np.interp(u, [0.0, 0.35, 0.7, 1.0], [20, 29, 30, 13]))
        return base, base + d * size * reach

    S.tag = "wing"
    ts = np.linspace(0.0, 1.0, 14)
    outline = [lead(t) for t in ts] + [feather(u, 0.8)[1] for u in ts[::-1]] + [R + back * 3]
    S.shape(outline, depth=6, lift=-10)
    S.tag = "feather"
    for reach, count, width, up in ((1.0, 7, 5.2, 0.0),):
        for k, u in enumerate(np.linspace(1.0, 0.0, count)):
            base, tip = feather(u, reach)
            w = width * (0.8 + 0.2 * (1 - u))
            S.shape(limb([base, lerp(base, tip, 0.55), tip], [w * 0.7, w, w * 0.55]), depth=4.5,
                    lift=-8 + up + 0.06 * k)
    S.tag = "wing_edge"
    S.shape(limb([lead(t) for t in (0.0, 0.3, 0.6, 0.85, 1.0)], [3.4, 3.2, 2.8, 2.2, 1.2]), depth=5, lift=-3)


# --- the legs, the robe, the arms ----------------------------------------------------------

def leg(S, knee, ankle, toes, lift):
    """A bare shin from under the hem at `knee` to the ankle, the calf full, and the foot pointed
    from the ankle to its toes: a round heel behind the ankle, the instep arched, the toes."""
    K, A, T = v(knee), v(ankle), v(toes)
    S.tag = "leg"
    S.shape(limb([K, lerp(K, A, 0.35), lerp(K, A, 0.8), A], [4.6, 4.8, 3.4, 3.0]), depth=4, lift=lift)
    d = unit(T - A)
    sole = np.array([-d[1], d[0]])
    if sole[1] > 0:
        sole = -sole
    s = float(np.linalg.norm(T - A)) / 13.5

    def F(x, y):
        return A + d * x * s + sole * y * max(s, 1.0)

    S.tag = "foot"
    S.shape([F(-3.5, 3.4), F(-5.2, 1.0), F(-4.0, -2.2), F(-1.5, -3.4), F(2, -3.4), F(6, -2.6),
             F(10, -1.4), F(13.8, 0.2), F(13.4, 1.6), F(9.5, 2.0), F(5, 2.6), F(1, 3.6)],
            depth=2.5, lift=lift + 0.4)


# The near arm's joints: the shoulder, the elbow (a clear angle) and the wrist at the fist.
SHOULDER = (150.0, 146.0)
ELBOW = (140.0, 172.0)
WRIST = (122.0, 163.0)


def build_near_arm(S):
    """The near arm, bent: the upper arm down from the shoulder, a sharp elbow, the forearm
    tapering back up to the wrist at her hip."""
    S.tag = "arm"
    S.shape([(145.5, 144.0), (154.5, 147.5), (144.0, 175.5), (139.0, 176.0), (122.5, 166.0),
             (121.5, 160.5), (137.5, 167.0)], depth=5, lift=16, smooth=False, soften=1)


# The fist round the stalk at Porrima, pixel by pixel (o its outline, k the knuckles, + inside):
# a small closed hand, square-ish, the curled fingers' knuckles in a row along its front and foot,
# the wrist joining it on the right.
FIST_ORIGIN = (111, 157)
FIST_ROWS = [
    "...oooo.....",
    "..o++++oo...",
    ".k+++++++o..",
    ".o++++++++oo",
    "k+++++++++++",
    ".o++++++++++",
    "k+++++++++oo",
    ".k+k+k+koo..",
]


def draw_fist(T: Strokes):
    for row, line in enumerate(FIST_ROWS):
        for col, c in enumerate(line):
            x, y = FIST_ORIGIN[0] + col, FIST_ORIGIN[1] + row
            if c == "o":
                T.put(x, y, 3, "wheat")
            elif c == "k":
                T.put(x, y, 5, "wheat")
            elif c == "+":
                T.put(x, y, 2, "wheat")


# --- the wheat -----------------------------------------------------------------------------

EAR_BASE = v(L[6]) + v((5, -14))
EAR_TIP = v(L[6]) + v((-3, 11))


def draw_wheat(T: Strokes, sky):
    """The stalk from the fist down past theta (a leaf off it there), and the ear of wheat at
    Spica: chevron grains down its core in N6/N7, a clear ring round the star, the awns spraying
    out from the tip."""
    stalk = bezier(v(L[2]) + v((2, 6)), v(L[5]) + v((3, -6)), EAR_BASE, 24)
    for (x, y), t in path_px(stalk):
        if sd.hsh(x, y, 51) > 0.08:
            T.put(x, y, 3, "wheat")
    leaf = bezier(v(L[5]) + v((4, -9)), v(L[5]) + v((-5, -6)), v(L[5]) + v((-12, 1)), 10)
    for (x, y), t in path_px(leaf):
        if sd.hsh(x, y, 52) > 0.1 + 0.5 * t:
            T.put(x, y, 2, "wheat")
    d = unit(EAR_TIP - EAR_BASE)
    side = np.array([-d[1], d[0]])
    sx, sy = L[6]
    for (x, y), t in path_px([EAR_BASE, EAR_TIP]):
        T.put(x, y, 1, "wheat")
    for k, t in enumerate(np.linspace(0.03, 0.92, 9)):
        # The grains as chevrons stacked down the core, each pointing to the tip: a pair of plump
        # arms leaning out and back to the stalk, smaller towards the tip.
        c = lerp(EAR_BASE, EAR_TIP, t)
        size = 1.0 - 0.4 * t
        for sgn in (-1.0, 1.0):
            b = c + side * sgn * 3.4 * size - d * 2.6 * size
            for plump in (0.0, 1.0):
                for x, y in line_px(c + d * plump, b + d * plump):
                    near = (x - sx) ** 2 + (y - sy) ** 2 <= 16
                    T.put(x, y, 2 if near or plump else 3, "wheat")
    for k, spread in enumerate(np.linspace(-1.0, 1.0, 7)):
        a = EAR_TIP + d * 1.0
        b = EAR_TIP + rotate(d, 34 * spread) * (12 - 3 * abs(spread))
        for i, (x, y) in enumerate(line_px(a, b)):
            if sd.hsh(x, y, 54 + k) > 0.1 + 0.06 * i:
                T.put(x, y, 2 if i < 5 else 1, "wheat")
    # A clear ring round Spica, 2 px: the star reads on the ear.
    ring = ((sd.xs - sx) ** 2 + (sd.ys - sy) ** 2 <= 8) & ~((sd.xs == sx) & (sd.ys == sy))
    T.level[ring] = -1
    T.fixed[ring] = ""
    T.part[ring] = ""


# --- the girdle's ribbon -------------------------------------------------------------------

def draw_ribbon(T: Strokes):
    """One long end of her girdle streaming back from her waist through zeta and tau to 109: a
    single wavy ribbon, 2 px wide at the waist, tapering, twisting and breaking towards its end,
    dimmer than the legs."""
    pts = [v(p) for p in [(112, 156), (100, 154), (88, 152), L[7], (66, 142), L[8], (40, 130), L[9],
                          (14, 125)]]
    path = []
    for k in range(len(pts) - 1):
        a, b = pts[k], pts[k + 1]
        bend = np.array([-(b - a)[1], (b - a)[0]]) * (0.14 if k % 2 else -0.14)
        path += bezier(a, (a + b) / 2 + bend, b, 10)[:-1]
    path.append(tuple(pts[-1]))
    for (x, y), t in path_px(path):
        if sd.hsh(x, y, 80) < 0.03 + 0.5 * t ** 3:
            continue
        T.put(x, y, 4 if t < 0.35 else (3 if t < 0.75 else 2), "robe")
        # The ribbon's width where it lies flat (it turns edge-on as it twists).
        flat = abs(np.cos(np.pi * 3.0 * t)) * (1.0 - t)
        if flat > 0.35 and sd.hsh(x, y, 81) < 0.8:
            T.put(x, y + 1, 2 if t < 0.5 else 1, "robe")


# --- the form ------------------------------------------------------------------------------

def build_figure(S):
    """The maiden's form, back to front: the wing, the legs, the chiton, the far arm, the bust and
    head, the girdle, the near arm."""
    build_wing(S)
    # The legs, bare below the hem: the back one out straight through iota, its foot pointed at
    # mu; the front one bent at the knee, its foot pointed down at kappa.
    leg(S, (64, 177), (27, 170), (13, 182), lift=-3)
    leg(S, (70, 187), (59, 202), (41, 209), lift=-2)
    # The chiton: from the waist over the hips and both thighs to a hem just below the knees; a
    # long fold down each leg, curving back with the wind of her flight.
    S.tag = "chiton"
    S.shape([(112, 149), (98, 153), (86, 157), (74, 161), (64, 164), (60, 170), (62, 177), (64, 184),
             (68, 190), (73, 196), (81, 195), (91, 190), (103, 184), (115, 176), (121, 167)],
            depth=5, lift=0, soften=5)
    S.tag = "fold"
    for fold in ([(108, 158), (90, 160), (68, 172)], [(110, 169), (88, 175), (75, 190)]):
        S.shape(limb(bezier(fold[0], fold[1], fold[2], 6), [0.8, 1.1, 1.4, 1.7, 1.9, 2.0]), depth=1.2, lift=4.2)
    # The far arm, behind the bust: from the far shoulder out ahead into her flight, the hand open.
    S.tag = "far_arm"
    # (The hand stays inside x 173: the haze round it would wrap round the screen's edge.)
    S.shape(limb([(154, 143), (161, 151), (166, 156)], [3.6, 3.0, 2.6]), depth=3, lift=1)
    S.shape([(164, 154), (168.5, 152.5), (172.5, 155), (171, 158), (166, 159)], depth=2, lift=1.4)
    # The bust: the torso from the shoulders to the waist.
    S.tag = "torso"
    S.shape([(152, 134), (140, 137), (128, 142), (116, 147), (106, 151), (106, 166), (118, 168),
             (130, 165), (142, 161), (151, 156), (158, 149), (159, 141)], depth=14, lift=2)
    build_head(S)
    S.tag = "girdle"
    S.shape(limb([(112, 151), (115, 166)], [2.3, 2.3]), depth=2, lift=4)
    build_near_arm(S)


def draw_strokes(sky) -> Strokes:
    T = Strokes()
    draw_hair(T)
    draw_diadem(T)
    draw_ribbon(T)
    draw_fist(T)
    draw_wheat(T, sky)
    return T


def wake_path():
    """The wake: it leaves the wing's tip backwards and curls round on itself in a loose spiral in
    the empty sky (flattened, under the Sun's zone), as the stream of her leaving."""
    tip = v(L[4]) + v((-5, -3))
    centre = v((58.0, 98.0))
    rel = tip - centre
    r0 = float(np.linalg.norm(rel * (1.0, 2.6)))
    a0 = np.arctan2(rel[1] * 2.6, rel[0])
    path = []
    for k in range(220):
        t = k / 219
        a = a0 - t * 1.75 * 2 * np.pi
        r = r0 * (1.0 - 0.72 * t)
        p = centre + v((r * np.cos(a), r * np.sin(a) / 2.6))
        path.append((p, t))
    return path


# --- the stardust --------------------------------------------------------------------------

# The lines drawn whole where a feature lies over another: (upper tags, lower tags, steps).
OVERLAPS = [
    (("chiton", "fold"), ("leg",), 4),             # the hem over the shins: the knees
    (("hair",), ("face",), 3),                     # the hairline
    (("face",), ("neck",), 3),                     # the jaw
    (("girdle",), ("chiton", "torso"), 3),         # the girdle round the waist
    (("feather",), ("feather", "wing"), 2),        # the feathers' rows
    (("arm",), ("torso", "chiton"), 4),            # the near arm over the bust
    (("torso",), ("far_arm",), 2),                 # the bust over the far arm
]


def overlap_line(S, tags, upper, lower) -> np.ndarray:
    """The pixels of a feature in `upper` next to a lower solid of a feature in `lower`: the line
    where one lies over the other."""
    mine = np.isin(tags, upper)
    line = np.zeros((H, W), bool)
    for dy, dx in sd.FOUR:
        nt, nz, no = sd.shift(tags, dy, dx), sd.shift(S.z, dy, dx), sd.shift(S.owner, dy, dx)
        line |= mine & np.isin(nt, lower) & (no != S.owner) & (nz < S.z)
    return line


def paint(S):
    """The stardust over the form. Returns the painting and the marks its pieces need."""
    rng = np.random.default_rng(SEED)
    sky = sd.sky_index()
    inside = S.z >= 0.0
    lit = np.clip(S.n @ LIGHT, 0.0, 1.0)
    facing = S.n[..., 0] * LIGHT[0] + S.n[..., 1] * LIGHT[1]
    tags = np.array(S.tags + [""], dtype=object)[S.owner]
    dust = sd.Dust()
    edge = sd.edge_of(inside)
    crease = sd.creases_of(inside, S.owner, S.z, edge)
    dist = sd.distance_inside(inside)

    bias = sd.contour_bias(facing, CONTOUR_WEIGHTS, tags)
    contour = sd.broken_contour(dust, rng, edge, facing, lit, bias)
    for tag, steps in KEY_LINES.items():
        dust.put(contour & (tags == tag), steps)
    sd.joint_strokes(dust, rng, crease)
    fill = np.full((H, W), FILL_DEFAULT)
    for tag, f in FILL.items():
        fill[tags == tag] = f
    sd.nebula(dust, rng, inside, dist, lit, fill)
    out_d = sd.outer_haze(dust, rng, inside)
    path = wake_path()
    sd.stardust_trail(dust, path, wisp=60)
    sd.specks(dust, inside, dist, out_d, lit)
    face = tags == "face"
    sd.rose_glints(dust, contour, lit, exclude=face)
    # Lines where one part lies over another, drawn whole so the anatomy reads.
    for upper, lower, steps in OVERLAPS:
        dust.put(overlap_line(S, tags, upper, lower), steps)
    # The face: its profile drawn whole and bright (it must read at native size), a few specks of
    # dust inside it (hollow), the eye a short dash under the brow in a clear hollow.
    dust.clear(face)
    dust.put(face & np.vectorize(lambda x, y: sd.hsh(x, y, 61) < 0.12)(sd.xs, sd.ys), 1)
    dust.put(edge & face, 3)
    for k, (x, y) in enumerate(PROFILE):
        dust.clear((sd.xs == x) & (sd.ys == y))
        dust.put_px(x, y, 6 if k in PROFILE_BRIGHT else 5)
    for x, y in EYE:
        dust.clear((np.abs(sd.xs - x) <= 1) & (np.abs(sd.ys - y) <= 1) & face)
    for x, y in EYE:
        dust.fixed[y, x] = "N7"
    strokes = draw_strokes(sky)
    strokes.onto(dust)
    sd.star_gaps(dust, L, SIZES)
    sd.quiet_stars(dust, L)
    # Each star on one faint pixel of its own part (hidden under the star): its piece forms from it.
    for x, y in L:
        dust.fixed[y, x] = ""
        dust.level[y, x] = max(dust.level[y, x], 1)
    img = sd.soften_near_stars(sd.sun_clamp(sd.resolve(dust, sky)), L)
    return img, tags, {"strokes": strokes.part, "wake": sd.trail_pixels(path)}


def part_tags(S, tags, img, marks):
    """Each painted pixel's part: the part of the stroke drawn on it, else the part of the solid
    under it (a joint where two parts meet goes with the part of the star on it), else the wake's,
    else the nearest tagged pixel's (the haze and the specks off the form)."""
    names = [TAG_PARTS.get(t, t) for t in S.tags]
    for star, part in STAR_PARTS.items():
        x, y = L[star]
        if S.owner[y, x] >= 0:
            names[S.owner[y, x]] = part
    out = np.array(names + [""], dtype=object)[S.owner]
    drawn = marks["strokes"] != ""
    out[drawn] = marks["strokes"][drawn]
    out[marks["wake"] & (out == "")] = "wing"
    for star, part in STAR_PARTS.items():
        x, y = L[star]
        out[y, x] = part
    return sd.spread_tags(out, img[..., 3] > 0)


def paint_virgo():
    S = Shapes()
    build_figure(S)
    img, tags, marks = paint(S)
    return img, S, tags, marks


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--preview", type=Path, help="also write the figure over the sky, x3, here")
    args = parser.parse_args()
    ART.mkdir(parents=True, exist_ok=True)
    img, S, tags, marks = paint_virgo()
    used = sd.check(img)
    print(f"figure: {sum(used.values())} px, {used}")
    sd.save(img, OUT)
    for part, piece in sd.pieces(img, part_tags(S, tags, img, marks), PARTS).items():
        for star, owner in STAR_PARTS.items():
            if owner == part:
                x, y = L[star]
                assert piece[y, x, 3] == 255, f"{part} misses landmark {star}"
        sd.save(piece, ART / f"virgo_piece_{part}.png")
    if args.preview:
        sd.preview(img, L, SIZES, SEGMENTS).save(args.preview)
        print(f"wrote {args.preview}")


if __name__ == "__main__":
    main()
