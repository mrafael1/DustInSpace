"""Builds the Scorpio's paintings (the chapter's rewards), in assets/art/:

  scorpio_figure.png         the whole scorpion, the final stage's reward, as a Stardust Myth vision
  scorpio_piece_<part>.png   the same painting cut into the chapter's five parts (stinger, tail,
                             body, heart, claws), in the same full-screen home layout: the chapter
                             chart shows the won ones dormant, then the whole figure once the final
                             is won
  scorpio_part_<map>.png     each part stage's own painting, the same body part fitted to that
                             stage's own landmarks (game/core/star_map.gd, read from the source),
                             shown when the stage is complete

The whole Scorpio is painted in the Stardust Myth style (tools/art/stardust.py): the scorpion is
suggested, not drawn. Its form is modelled as overlapping solids anchored to the 14 landmarks of
Scorpius (game/core/scorpio.gd LANDMARKS): Dschubba on the head, beta and pi in the claws, Antares
at the heart, the tail curling down through zeta, eta and theta and back up to Shaula, the sting.
The solids are never shaded: they give the stardust a mask, normals and joints. Over them go a
broken contour on the lit edges, faint joint strokes, hollow nebula wisps, an outer haze, specks
thickest at the contour, rose glints, and the mythic flourish: a stardust trail spiralling off the
sting into the empty sky. The carapace is a notched shield with a drawn rim, a median ridge and a
pair of eyes; the eight legs are single strokes of dust with a bright knee, under the shield and
the plates. The heavy pincers (and their haze) are kept from the first approved pass, painted over
its own form (oval carapace, solid legs), because their contour depends on what surrounds them.
Every pixel is a palette N step above the sky behind it, or a speck (N7, N8, D0) or glint (N9);
opaque or empty; nothing in the Sun's zone (y < 78); each landmark star in a gap clear of specks.

The pieces partition the whole: each pixel goes with the part of the solid under it (Chapter.STAGES;
a joint where two parts meet goes with the part of the star on it), else with its leg (front pairs
heart, back pairs body) or the sting's trail (stinger), else with the nearest tagged pixel.

The part stages keep the shaded-solid style: each part as solids lit from the top left on a stepped
N ramp, N1 creases, an N9/N10 rose rim, N8/D0 stardust specks and a checkered N3 aura.

Every image is the full 180x320 game screen (transparent outside the figure), in home layout: the
chapter chart draws it as is, and a stage draws it where its sky shifts the map.

Run: python tools/art/build_scorpio_figure.py [--preview out.png]   (needs Pillow and numpy)
"""

import argparse
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import stardust as sd  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / "assets" / "art"
OUT = ART / "scorpio_figure.png"
# The end panel's top row on the home screen after the final's win (game/ui/end_screen.gd, TOP
# shifted with the sky): nothing is painted from here down.
END_PANEL_TOP = 243
STAR_MAP = ROOT / "game" / "core" / "star_map.gd"
PARTS = ("stinger", "tail", "body", "heart", "claws")

W, H = 180, 320

HEX = {
    "N0": "07091F", "N1": "0E1438", "N2": "151D4A", "N3": "1E2860", "N4": "2A3375",
    "N5": "3E3F8A", "N6": "5A51A6", "N7": "7E68C8", "N8": "A77FD8", "N9": "D08FC8",
    "N10": "F2A9C2", "C0": "FFFBEA", "C4": "A45A78", "C5": "6A3F7A", "D0": "D9CCFF",
}
RGB = {k: tuple(int(v[i:i + 2], 16) for i in (0, 2, 4)) for k, v in HEX.items()}

# The body's shading ramp, darkest first.
RAMP = ["N1", "N2", "N3", "N4", "N5", "N6", "N7", "N8"]
RIM = ["N9", "N10"]
CREASE = "N1"
AURA = "N3"

BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]], dtype=float)

# Scorpius's landmarks (game/core/scorpio.gd): 0 beta, 1 Dschubba, 2 pi, 3 sigma, 4 Antares,
# 5 tau, 6 epsilon, 7 mu, 8 zeta, 9 eta, 10 theta, 11 iota, 12 kappa, 13 Shaula.
L = [(146, 90), (160, 112), (158, 138), (134, 122), (110, 134), (100, 158), (95, 182),
     (92, 207), (88, 233), (62, 236), (36, 232), (14, 214), (28, 192), (52, 184)]

LIGHT = np.array([-0.55, -0.65, 0.52])
LIGHT /= np.linalg.norm(LIGHT)


def v(p):
    return np.array(p, dtype=float)


def lerp(a, b, t):
    return v(a) + (v(b) - v(a)) * t


class Solids:
    """Rasterises solids into a height (z), a normal and the id of the solid on top, per pixel."""

    def __init__(self):
        self.z = np.full((H, W), -1.0)
        self.n = np.zeros((H, W, 3))
        self.owner = np.full((H, W), -1, dtype=int)
        self.flat = np.zeros((H, W), dtype=bool)
        self.count = 0
        # The part each solid belongs to (by solid id), set through `tag` as solids are added.
        self.tag = ""
        self.tags = []
        ys, xs = np.mgrid[0:H, 0:W]
        self.px = xs + 0.5
        self.py = ys + 0.5

    def _put(self, inside, z, nx, ny, nz, lift, flat=False):
        # Every solid floats above the page, so a negative lift only sinks it under the others.
        z = z + lift + 20.0
        win = inside & (z > self.z)
        self.z[win] = z[win]
        norm = np.sqrt(nx * nx + ny * ny + nz * nz) + 1e-9
        self.n[win, 0] = (nx / norm)[win]
        self.n[win, 1] = (ny / norm)[win]
        self.n[win, 2] = (nz / norm)[win]
        self.owner[win] = self.count
        self.flat[win] = flat
        self.tags.append(self.tag)
        self.count += 1

    def ellipsoid(self, centre, along, a, b, depth=None, lift=0.0, squash=1.0, along_flat=1.0):
        """A spheroid: semi-axis `a` along the unit vector `along`, `b` across it, seen from above.
        `along_flat` < 1 rounds it less along its axis: a plate of a longer body, not a ball."""
        c = v(centre)
        u = v(along) / np.linalg.norm(along)
        w = np.array([-u[1], u[0]])
        dx, dy = self.px - c[0], self.py - c[1]
        s = (dx * u[0] + dy * u[1]) / a
        t = (dx * w[0] + dy * w[1]) / b
        r2 = s * s + t * t
        inside = r2 <= 1.0
        h = np.sqrt(np.clip(1.0 - r2, 0.0, 1.0))
        depth = depth if depth is not None else min(a, b)
        # The normal of the spheroid (s, t, h) mapped back to screen axes.
        gs, gt = s / a * along_flat, t / b
        nx = gs * u[0] + gt * w[0]
        ny = gs * u[1] + gt * w[1]
        nz = h / depth * squash
        self._put(inside, h * depth, nx, ny, nz, lift)

    def capsule(self, p0, p1, r0, r1, lift=0.0):
        """A tapered capsule from p0 (radius r0) to p1 (radius r1)."""
        a, b = v(p0), v(p1)
        ab = b - a
        length2 = float(ab @ ab) + 1e-9
        dx, dy = self.px - a[0], self.py - a[1]
        t = np.clip((dx * ab[0] + dy * ab[1]) / length2, 0.0, 1.0)
        cx, cy = a[0] + ab[0] * t, a[1] + ab[1] * t
        ox, oy = self.px - cx, self.py - cy
        d2 = ox * ox + oy * oy
        r = r0 + (r1 - r0) * t
        inside = d2 <= r * r
        h = np.sqrt(np.clip(r * r - d2, 0.0, None))
        self._put(inside, h, ox, oy, h + 1e-3, lift)

    def chain(self, points, radii, lift=0.0):
        for k in range(len(points) - 1):
            self.capsule(points[k], points[k + 1], radii[k], radii[k + 1], lift)


def bezier(p0, p1, p2, steps):
    p0, p1, p2 = v(p0), v(p1), v(p2)
    return [tuple((1 - t) ** 2 * p0 + 2 * (1 - t) * t * p1 + t * t * p2) for t in np.linspace(0, 1, steps)]


def unit(p):
    p = v(p)
    return p / np.linalg.norm(p)



# ---- The whole Scorpio, in the Stardust Myth style (tools/art/stardust.py). ----

SEED = 7
# Each landmark's size (game/core/scorpio.gd SIZES): the stars' gaps and the preview's stars.
SIZES = ["M", "M", "S", "S", "B", "S", "M", "S", "S", "S", "B", "S", "M", "B"]
# Scorpius's strings, for the preview.
SEGMENTS = [(0, 1), (1, 2), (1, 3), (3, 4), (4, 5), (5, 6), (6, 7), (7, 8), (8, 9), (9, 10),
            (10, 11), (11, 12), (12, 13)]

# The carapace (prosoma): a shield from just over the first body plate to Dschubba, broader at
# the back than the plate it sits on, narrowing to a notched front edge between the arms.
CARA_BACK = (127.0, 125.0)
CARA_FRONT = (159.5, 112.5)
CARA_HALF = (13.5, 9.0)          # half-width at the back edge, at the front edge
CARA_BIAS = 0.45                 # the shield's outline is drawn almost whole
CARA_FILL = 0.6                  # and its inside kept thinner than the body's
# The legs: four per side, each root (under the carapace's flank), knee, ankle and foot. The femur
# leaves the flank, the knee turns the leg back towards the tail. The front pairs are held back
# out of the pincers' reach (the arms ride over them).
LEGS = [
    # Upper side: the femur goes out (up) from under the shield's top edge, a clear knee, then
    # the shin turns outward and back. The shins fan from up-left (front) to down-left (back).
    [(138, 109), (137, 101), (133, 97), (131, 97)],      # upper I
    [(132, 111), (128, 102), (121, 101), (119, 102)],    # upper II
    [(125, 115), (119, 106), (111, 108), (108, 110)],    # upper III
    [(118, 121), (110, 112), (102, 116), (99, 119)],     # upper IV
    # Lower side: out (down-right) from under the shield's lower edge, a clear knee, then the
    # shin and foot back down-left. The front shin stands upright, the back one sweeps back.
    [(140, 131), (144, 133), (145, 138), (144, 142)],    # lower I
    [(133, 135), (139, 138), (141, 144), (140, 149)],    # lower II
    [(125, 139), (132, 142), (135, 149), (133, 155)],    # lower III
    [(116, 146), (122, 150), (125, 157), (122, 163)],    # lower IV
]
# The piece each leg goes with: the front two pairs with the heart, the back two with the body.
LEG_PARTS = ["heart", "heart", "body", "body", "heart", "heart", "body", "body"]
LEG_MAX = 4      # the leg's stroke, steps above the sky (the femur and foot one less)
LEG_KNEE = 5     # the knee, one step brighter
LEG_HOLES = 0.08  # the share of a leg's pixels left out, so it reads as dust, not wire
# How far round each pincer its haze reaches: the first pass's pixels are kept in there.
PINCER_HAZE = 7
# The solid tags that go with another part's piece.
TAG_PARTS = {"arms": "claws", "carapace": "claws"}


def body_plates(S: Solids):
    """The mesosoma: seven plates from just behind the carapace to mu, widest round Antares."""
    sigma, antares, tau, eps, mu = L[3], L[4], L[5], L[6], L[7]
    widths = [11.0, 12.5, 13.5, 13.5, 12.5, 11.0, 9.0]
    track = [lerp(sigma, antares, 0.45), lerp(sigma, antares, 0.95), lerp(antares, tau, 0.45),
             lerp(antares, tau, 0.95), lerp(tau, eps, 0.5), lerp(eps, mu, 0.1), lerp(eps, mu, 0.55)]
    for k in range(7):
        S.tag = "heart" if k < 3 else "body"
        prev = track[max(k - 1, 0)]
        nxt = track[min(k + 1, 6)]
        S.ellipsoid(track[k], v(nxt) - v(prev), 9.0, widths[k], depth=7.0, lift=-k * 0.6, along_flat=0.35)


def tail_and_sting(S: Solids):
    """The metasoma (five joints from mu to kappa, thinning), the telson between kappa and Shaula,
    and the curved sting past Shaula."""
    eps, mu = L[6], L[7]
    tail = [lerp(eps, mu, 0.92), L[8], L[9], L[10], L[11], L[12]]
    radii = [7.0, 6.6, 6.2, 5.8, 5.4]
    for k in range(5):
        S.tag = "tail" if k < 4 else "stinger"
        a, b = v(tail[k]), v(tail[k + 1])
        S.ellipsoid((a + b) / 2, b - a, np.linalg.norm(b - a) / 2 + 3.0, radii[k], depth=6.0, lift=-3.0 + k * 0.2, along_flat=0.5)
    kappa, shaula = v(L[12]), v(L[13])
    S.tag = "stinger"
    S.ellipsoid(lerp(kappa, shaula, 0.6), shaula - kappa, 13.0, 6.8, depth=6.0, lift=-1.5)
    tip, forward, curl = sting_tip()
    sting_points = bezier(shaula + forward * 4.0, shaula + forward * 14.0 + curl * 2.0, tip, 10)
    S.chain(sting_points, list(np.linspace(3.6, 0.5, len(sting_points))), lift=-1.0)


def sting_tip():
    """The sting's point, the telson's forward direction and the way the sting curls (up)."""
    kappa, shaula = v(L[12]), v(L[13])
    forward = unit(shaula - kappa)
    curl = np.array([forward[1], -forward[0]])
    if curl[1] > 0:
        curl = -curl
    return shaula + forward * 13.0 + curl * 12.0, forward, curl


def heavy_pincer(S: Solids, claw, bend: float):
    """A heavy pincer at a claw star (beta up, `bend` -1; pi down, +1), opening forward (right),
    the way the scorpion faces. The lower one is pulled in so its fingers end inside x 180."""
    reach = 1.0 if bend < 0 else 0.62
    manus = v(claw) + v((5.0 * reach, 0.0))
    S.ellipsoid(manus, (1.0, 0.25 * bend), 8.5, 5.8, depth=5.5, lift=0.5)
    tip = manus + v((7.0 * reach, 0.0))
    fixed = bezier(tip + v((-1, -2.2)), tip + v((7.0 * reach, -6.0)), tip + v((11.0 * reach, -1.0)), 7)
    moving = bezier(tip + v((-1, 2.2)), tip + v((7.0 * reach, 6.0)), tip + v((11.0 * reach, 1.0)), 7)
    S.chain(fixed, list(np.linspace(2.8, 0.7, 7)), lift=0.2)
    S.chain(moving, list(np.linspace(2.5, 0.7, 7)), lift=0.0)


def arm_elbow(claw, bend: float):
    """The pedipalp's elbow: halfway to the claw star from the carapace's front, pulled back."""
    shoulder = v(L[1]) + v((-4.0, 5.0 * bend))
    return lerp(shoulder, claw, 0.5) + v((-6.0, 1.0 * bend))


def cara_frame():
    """The shield's back centre, its unit axis to the front, its unit side (+: the lower flank)
    and its length."""
    b, f = v(CARA_BACK), v(CARA_FRONT)
    length = float(np.linalg.norm(f - b))
    u = (f - b) / length
    w = np.array([-u[1], u[0]])
    return b, u, w, length


def cara_half(s):
    return CARA_HALF[0] + (CARA_HALF[1] - CARA_HALF[0]) * s


def shield(S: Solids, depth=8.0, lift=1.5):
    """The carapace as a height field: a rounded trapezoid (superellipse), domed, with a notch."""
    b, u, w, length = cara_frame()
    dx, dy = S.px - b[0], S.py - b[1]
    s = (dx * u[0] + dy * u[1]) / length
    t = dx * w[0] + dy * w[1]
    tn = t / cara_half(np.clip(s, 0, 1))
    r = np.abs(2.0 * s - 1.0) ** 6 + np.abs(tn) ** 4
    inside = r <= 1.0
    inside &= ~((s * length > length - 1.6) & (np.abs(t) < 1.6))  # the front notch
    h = depth * np.sqrt(np.clip(1.0 - r, 0.0, 1.0)) * inside
    gy, gx = np.gradient(h)
    S._put(inside, h, -gx, -gy, np.full_like(h, 1.2), lift)


def front_corner(sign: float):
    """A front corner of the shield, where an arm leaves from under it."""
    b, u, w, length = cara_frame()
    return b + u * (length - 2.0) + w * sign * (cara_half(1.0) - 1.0)


def build_vision(S: Solids) -> list:
    """The scorpion's form (a mask, normals and joints for the stardust, never shaded as solids):
    the plates, the shield over their front, the tail and sting, and the arms from the shield's
    front corners to beta and pi with heavy pincers. The legs are strokes (`leg_strokes`), not
    solids: a solid tube this thin would draw as two outlines and a knot of haze. Returns the ids
    of the two arms' first joints (the shield's rim breaks where they leave it)."""
    arms = []
    body_plates(S)
    S.tag = "carapace"
    shield(S)
    tail_and_sting(S)
    for claw, bend in ((L[0], -1.0), (L[2], 1.0)):
        S.tag = "arms"
        S.chain([front_corner(bend), arm_elbow(claw, bend), claw], [3.6, 3.0, 3.6], lift=-0.5)
        arms.append(S.count - 2)
        S.tag = "claws"
        heavy_pincer(S, claw, bend)
    return arms


def build_first_vision(S: Solids):
    """The first approved pass's form, kept for its pincers (the user's favourite part: their haze
    and contour depend on the arms and carapace round them): solid legs, an oval carapace and the
    arms from its front, all else as `build_vision`."""
    head, sigma, antares, mu = L[1], L[3], L[4], L[7]
    spine_dir = unit(v(mu) - v(sigma))
    side = np.array([-spine_dir[1], spine_dir[0]])
    roots = [lerp(head, sigma, 0.55), lerp(head, sigma, 0.95), lerp(sigma, antares, 0.4), lerp(sigma, antares, 0.85)]
    reach = [15.0, 17.0, 18.0, 18.0]
    for k, root in enumerate(roots):
        S.tag = "heart" if k < 2 else "body"
        for sign in (-1.0, 1.0):
            out = side * sign
            knee = root + out * reach[k] * 0.55 - spine_dir * (3.0 - k * 1.5)
            ankle = knee + out * reach[k] * 0.35 + spine_dir * (2.0 + k * 1.2)
            foot = ankle + spine_dir * (5.0 + k) + out * 2.0
            S.chain([root, knee, ankle, foot], [2.1, 1.8, 1.4, 0.9], lift=-4.0)
    body_plates(S)
    S.tag = "claws"
    S.ellipsoid(lerp(head, sigma, 0.45), v(head) - v(sigma), 15.0, 11.0, depth=8.0, lift=1.5)
    tail_and_sting(S)
    S.tag = "claws"
    for claw, bend in ((L[0], -1.0), (L[2], 1.0)):
        shoulder = v(head) + v((-4.0, 5.0 * bend))
        S.chain([shoulder, arm_elbow(claw, bend), claw], [3.6, 3.0, 3.6], lift=-0.5)
        heavy_pincer(S, claw, bend)


def pincer_zone() -> np.ndarray:
    """The pincers (hands and fingers) grown by their haze's reach: the first pass's pixels."""
    S = Solids()
    for claw, bend in ((L[0], -1.0), (L[2], 1.0)):
        heavy_pincer(S, claw, bend)
    return sd.grow(S.z >= 0, PINCER_HAZE)


def leg_line(a, b):
    (x0, y0), (x1, y1) = a, b
    n = max(abs(x1 - x0), abs(y1 - y0))
    return [(round(x0 + (x1 - x0) * k / n), round(y0 + (y1 - y0) * k / n)) for k in range(n + 1)]


def leg_strokes():
    """Each leg as a 1 px stroke of (segment, pixel) pairs: 0 femur, 1 tibia, 2 foot."""
    out = []
    for leg_points in LEGS:
        px = []
        for seg in range(3):
            for p in leg_line(leg_points[seg], leg_points[seg + 1]):
                if not px or px[-1][1] != p:
                    px.append((seg, p))
        out.append(px)
    return out


def trail_path():
    """The sting's trail: it leaves the sting along its curl, then wanders up and left, waving."""
    tip, forward, curl = sting_tip()
    up_left = unit((-0.62, -1.0))
    side = np.array([-up_left[1], up_left[0]])
    path = []
    for k in range(260):
        t = k / 259
        p = (tip + curl * 5.0 + forward * 3.0 * min(t * 6, 1.0) + curl * 4.0 * min(t * 6, 1.0)
             + up_left * 78.0 * t + side * 7.0 * math.sin(t * 2.6 * math.pi) * t)
        path.append((p, t))
    return path


def head_marks(dust, S: Solids, cara, arms):
    """The carapace's own lines: its rim drawn whole (it lies over the legs and the first plate),
    broken only where the arms leave from under its front corners, and a faint median ridge.
    Returns the dark gap just outside the rim (kept empty: the shield overlaps what is under it)
    and the two median eyes near its front edge."""
    b, u, w, length = cara_frame()
    s = ((S.px - b[0]) * u[0] + (S.py - b[1]) * u[1]) / length
    t = (S.px - b[0]) * w[0] + (S.py - b[1]) * w[1]
    rim = np.zeros((H, W), bool)
    arms_near = np.zeros((H, W), bool)
    near = np.zeros((H, W), bool)
    for dy, dx in sd.FOUR:
        rim |= cara & ~sd.shift(cara, dy, dx)
        arms_near |= np.isin(sd.shift(S.owner, dy, dx), arms)
        near |= sd.shift(cara, dy, dx)
    dust.put(rim & ~arms_near, 4)
    dust.put(cara & (np.abs(t) < 0.7) & (s > 0.28) & (s < 0.64), 2)
    gap = near & ~cara & (S.z >= 0) & ~arms_near
    # Where the shield's top edge meets the first plate's, a 1 px break so the two lines don't
    # run on as one outline.
    gap |= (sd.xs >= 126) & (sd.xs <= 128) & (sd.ys >= 111) & (sd.ys <= 113) & ~cara
    eyes = []
    for side in (-1.0, 1.0):
        e = b + u * (0.84 * length) + w * side * 2.0
        eyes.append((int(round(e[0])), int(round(e[1]))))
    return gap, eyes


def paint_legs(dust, body):
    """The legs as single strokes of dust, hidden where the body lies over them, at the outline's
    strength with the knee one step brighter, a few specks drifting off each shin, and a dotted
    shadow under the femur. Returns each leg's pixels (for its piece)."""
    marks = []
    for li, leg in enumerate(leg_strokes()):
        mine = np.zeros((H, W), bool)
        kx, ky = LEGS[li][1]
        for seg, (x, y) in leg:
            if body[y, x] or sd.hsh(x, y, 37) < LEG_HOLES:
                continue
            step = (LEG_MAX - 1, LEG_MAX, LEG_MAX - 1)[seg]
            if (x - kx) ** 2 + (y - ky) ** 2 <= 2:
                step = LEG_KNEE
            dust.level[y, x] = max(dust.level[y, x], step)
            dust.fixed[y, x] = ""
            mine[y, x] = True
        for seg, (x, y) in leg:
            if seg == 1 and sd.hsh(x, y, 41) < 0.30:
                dx, dy = (2, 0) if sd.hsh(x, y, 42) < 0.5 else (-2, 1)
                if not body[y + dy, x + dx] and dust.level[y + dy, x + dx] <= 1:
                    dust.fixed[y + dy, x + dx] = "N8" if sd.hsh(x, y, 43) < 0.6 else "N7"
                    mine[y + dy, x + dx] = True
        for seg, (x, y) in leg:
            if seg == 0 and li < 4 and not body[y + 1, x] and dust.level[y + 1, x] < 1 and (x + y) % 2 == 0:
                dust.level[y + 1, x] = 1
                mine[y + 1, x] = True
        marks.append(mine)
    return marks


def paint_vision(S: Solids, arms=None):
    """The stardust over a form: with `arms` (the ids `build_vision` returns), the head pass
    (shield marks, eyes, leg strokes); without, the first pass (eye glints only). Returns the
    painting and, for the head pass, the marks its pieces need."""
    rng = np.random.default_rng(SEED)
    inside = S.z >= 0.0
    lit = np.clip(S.n @ LIGHT, 0.0, 1.0)
    facing = S.n[..., 0] * LIGHT[0] + S.n[..., 1] * LIGHT[1]
    tags = np.array(S.tags + [""], dtype=object)[S.owner]
    cara = tags == "carapace"
    dust = sd.Dust()
    edge = sd.edge_of(inside)
    crease = sd.creases_of(inside, S.owner, S.z, edge)
    dist = sd.distance_inside(inside)

    # The pincers, the shield and the sting keep more of their outline: they must read.
    bias = sd.contour_bias(facing, {"claws": 0.34, "arms": 0.34, "stinger": 0.30, "carapace": CARA_BIAS}, tags)
    contour = sd.broken_contour(dust, rng, edge, facing, lit, bias)
    sd.joint_strokes(dust, rng, crease)
    if arms is not None:
        cara_gap, eyes = head_marks(dust, S, cara, arms)
    sd.nebula(dust, rng, inside, dist, lit, np.where(cara, CARA_FILL, 1.0))
    out_d = sd.outer_haze(dust, rng, inside)
    path = trail_path()
    sd.stardust_trail(dust, path)
    sd.specks(dust, inside, dist, out_d, lit)
    sd.rose_glints(dust, contour, lit)

    marks = None
    if arms is None:
        # The eyes: two pale glints on the carapace's brow.
        for ex, ey in ((152, 109), (154, 113)):
            dust.fixed[ey, ex] = "D0"
    else:
        dust.level[cara_gap] = -1
        # The eyes: a pair of dots at the outline's strength, each in a small clear hollow.
        for ex, ey in eyes:
            dust.clear((np.abs(sd.xs - ex) <= 1) & (np.abs(sd.ys - ey) <= 1))
        for ex, ey in eyes:
            dust.level[ey, ex] = 4
        dust.fixed[cara_gap] = ""
        marks = {"legs": paint_legs(dust, inside | cara_gap), "trail": sd.trail_pixels(path)}
    # The sting's point: a rose glint where the hook ends, so the trail reads as leaving it.
    tip, _, _ = sting_tip()
    tx, ty = int(round(tip[0])), int(round(tip[1]))
    dust.fixed[ty, tx] = "N9"
    dust.fixed[ty + 1, tx] = "N8"
    sd.star_gaps(dust, L, SIZES)
    return sd.resolve(dust, sd.sky_index()), marks


def paint_scorpio():
    """The whole Scorpio: the head pass, with the pincers and their haze from the first pass.
    Returns the painting, the head pass's form and its marks (for the pieces)."""
    S = Solids()
    arms = build_vision(S)
    img, marks = paint_vision(S, arms)
    first = Solids()
    build_first_vision(first)
    first_img, _ = paint_vision(first)
    keep = pincer_zone()
    img[keep] = first_img[keep]
    # Each star on one faint pixel of its own (one step above the sky, hidden under the star): its
    # piece holds it, so the chart can grow that piece from its stars.
    sky = sd.sky_index()
    for x, y in L:
        if not img[y, x, 3]:
            img[y, x, :3] = sd.PAL[sd.N[sky[y, x] + 1]]
            img[y, x, 3] = 255
    # The haze stops above the end panel, so the whole tail stays in view after the win.
    img[END_PANEL_TOP:] = 0
    return sd.sun_clamp(img), S, marks


def part_tags(S: Solids, img: np.ndarray, marks) -> np.ndarray:
    """Each painted pixel's part: the part of the solid under it (a joint where two parts meet goes
    with the part of the star on it, so every star sits on its own part's piece), else its leg's
    or the sting's trail's, else the nearest tagged pixel's (the haze and the specks off the form)."""
    for star, part in STAR_PARTS.items():
        x, y = L[star]
        S.tags[S.owner[y, x]] = part
    names = [TAG_PARTS.get(t, t) for t in S.tags]
    for star, part in STAR_PARTS.items():
        x, y = L[star]
        assert names[S.owner[y, x]] == part, f"landmark {star} sits on a solid of two parts"
    tags = np.array(names + [""], dtype=object)[S.owner]
    for mine, part in zip(marks["legs"], LEG_PARTS):
        tags[mine & (tags == "")] = part
    tags[marks["trail"] & (tags == "")] = "stinger"
    tags = sd.spread_tags(tags, img[..., 3] > 0)
    # Each star's own pixel goes with its part, whatever solid lies under it.
    for star, part in STAR_PARTS.items():
        x, y = L[star]
        tags[y, x] = part
    return tags




# The part stages' own paintings: the same body parts, fitted to each stage's landmarks.

def stage_landmarks():
    """Each part stage's landmarks, read from game/core/star_map.gd (one source of truth)."""
    import re
    src = STAR_MAP.read_text()
    found = {}
    for name in PARTS:
        block = re.search(r"static func %s\(\) -> StarMap:(.*?)\n\n\n" % name, src, re.S).group(1)
        marks = re.search(r"map\.landmarks = \[(.*?)\]\n", block).group(1)
        found[name] = [(int(x), int(y)) for x, y in re.findall(r"Vector2i\((-?\d+), (-?\d+)\)", marks)]
    return found


def tail_joints(S, points, radii, lift=-3.0):
    """A bulb on each string of a line of points: the tail's joints."""
    for k in range(len(points) - 1):
        a, b = v(points[k]), v(points[k + 1])
        S.ellipsoid((a + b) / 2, b - a, np.linalg.norm(b - a) / 2 + 3.0, radii[k], depth=6.0, lift=lift + k * 0.2, along_flat=0.5)


def plates(S, spine, widths):
    """The plated body along a spine: a plate on each star and between each two."""
    track = []
    for k in range(len(spine) - 1):
        track += [v(spine[k]), lerp(spine[k], spine[k + 1], 0.5)]
    track.append(v(spine[-1]))
    w = np.interp(np.linspace(0, len(widths) - 1, len(track)), range(len(widths)), widths)
    # Each plate reaches well past the next one's centre, so they overlap like a body's plates.
    step = np.linalg.norm(track[1] - track[0])
    for k in range(len(track)):
        prev, nxt = track[max(k - 1, 0)], track[min(k + 1, len(track) - 1)]
        S.ellipsoid(track[k], nxt - prev, max(9.0, step * 0.8), w[k], depth=7.0, lift=-k * 0.6, along_flat=0.35)


def leg(S, root, star, back):
    """A jointed leg from the body at `root` out through the leg's star, bending back (`back`)."""
    out = unit(v(star) - v(root))
    knee = v(star) + out * 4.0
    foot = knee + out * 4.0 + back * 7.0
    S.chain([root, star, knee, foot], [2.1, 1.8, 1.4, 0.9], lift=-4.0)


def pincer(S, claw, forward):
    """A heavy pincer at a claw star, opening along `forward`."""
    f = unit(forward)
    side = np.array([-f[1], f[0]])
    manus = v(claw) + f * 5.0
    S.ellipsoid(manus, f, 8.5, 5.8, depth=5.5, lift=0.5)
    tip = manus + f * 7.0
    fixed = bezier(tip - f - side * 2.2, tip + f * 7.0 - side * 6.0, tip + f * 11.0 - side * 1.0, 7)
    moving = bezier(tip - f + side * 2.2, tip + f * 7.0 + side * 6.0, tip + f * 11.0 + side * 1.0, 7)
    S.chain(fixed, list(np.linspace(2.8, 0.7, 7)), lift=0.2)
    S.chain(moving, list(np.linspace(2.5, 0.7, 7)), lift=0.0)


def sting(S, base, tip, inward):
    """The telson's sting from `base` through the tip star, hooking towards `inward` past it."""
    f = unit(v(tip) - v(base))
    curl = np.array([-f[1], f[0]])
    if curl @ (v(inward) - v(tip)) < 0:
        curl = -curl
    points = bezier(v(base) + f * 4.0, v(tip) + f * 4.0, v(tip) + f * 6.0 + curl * 9.0, 10)
    S.chain(points, list(np.linspace(5.0, 0.6, len(points))), lift=-1.0)


def build_stinger(S, M):
    """The Stinger, as the whole's: the tail's last joints come in from the right along the bottom,
    turn up at the left, then the swollen telson runs right to the big star and the sting curls up
    from it to the tip star."""
    tail_joints(S, M[:4], [6.6, 6.3, 6.0])
    S.ellipsoid(lerp(M[3], M[4], 0.6), v(M[4]) - v(M[3]), 16.0, 8.5, depth=6.0, lift=-1.5)
    forward = unit(v(M[4]) - v(M[3]))
    points = bezier(v(M[4]) + forward * 4.0, v(M[4]) + forward * 26.0, v(M[5]), 10)
    S.chain(points + [v(M[5]) + v((-4.0, -5.0))], list(np.linspace(5.0, 1.8, len(points))) + [0.6], lift=-1.0)


def build_tail(S, M):
    """The Tail: a joint on each string, thinning towards the sting."""
    tail_joints(S, M, list(np.linspace(7.0, 5.4, len(M) - 1)))


def build_trunk(S, M, spine, widths):
    """The Body or the Heart: plates along the spine, a leg out through every other star."""
    for k in range(len(M)):
        if k in spine:
            continue
        root = M[[s for s in spine if (min(s, k), max(s, k)) in BRANCHES_OF[id(M)]][0]]
        back = unit(v(M[spine[-1]]) - v(M[spine[0]]))
        leg(S, root, M[k], back)
    plates(S, [M[i] for i in spine], widths)


BRANCHES_OF = {}


def build_body_stage(S, M):
    BRANCHES_OF[id(M)] = {(1, 5), (1, 6), (2, 7), (2, 8)}
    build_trunk(S, M, [0, 1, 2, 3, 4], [10.0, 13.0, 14.0, 12.0, 9.0])


def build_heart_stage(S, M):
    BRANCHES_OF[id(M)] = {(2, 5), (2, 6)}
    build_trunk(S, M, [0, 1, 2, 3, 4], [8.0, 11.0, 13.5, 11.0, 8.0])


def build_claws(S, M):
    """The Claws, as the whole's: the neck's plates, the carapace reaching back from the head, and an
    arm up and an arm down, each bending back at its elbow, with a heavy pincer opening forward
    (right), the way the scorpion faces. The stage spreads its stars wider than the whole's head, so
    the carapace and pincers grow with it (`k`) to keep the whole's proportions."""
    k = 1.3
    plates(S, [M[0], M[1]], [10.0, 12.0])
    S.ellipsoid(lerp(M[2], M[1], 0.3), v(M[2]) - v(M[1]), 15.0 * k, 11.0 * k, depth=8.0 * k, lift=1.5)
    for (a, b, c), bend in (((2, 3, 4), -1.0), ((2, 5, 6), 1.0)):
        S.chain([M[a], M[b], M[c]], [4.6, 3.8, 4.6], lift=-0.5)
        manus = v(M[c]) + v((5.0, 0.0)) * k
        S.ellipsoid(manus, (1.0, 0.25 * bend), 8.5 * k, 5.8 * k, depth=5.5 * k, lift=0.5)
        tip = manus + v((7.0, 0.0)) * k
        fixed = bezier(tip + v((-1, -2.2)) * k, tip + v((7.0, -6.0)) * k, tip + v((11.0, -1.0)) * k, 7)
        moving = bezier(tip + v((-1, 2.2)) * k, tip + v((7.0, 6.0)) * k, tip + v((11.0, 1.0)) * k, 7)
        S.chain(fixed, list(np.linspace(2.8, 0.7, 7) * k), lift=0.2)
        S.chain(moving, list(np.linspace(2.5, 0.7, 7) * k), lift=0.0)


STAGE_BUILDERS = {
    "stinger": build_stinger, "tail": build_tail, "body": build_body_stage,
    "heart": build_heart_stage, "claws": build_claws,
}


def shade(S: Solids):
    img = np.zeros((H, W, 4), dtype=np.uint8)
    inside = S.z >= 0.0
    ys, xs = np.mgrid[0:H, 0:W]
    bay = (BAYER[ys % 4, xs % 4] + 0.5) / 16.0

    n = S.n
    diffuse = np.clip(n @ LIGHT, 0.0, 1.0)
    half = LIGHT + np.array([0.0, 0.0, 1.0])
    half /= np.linalg.norm(half)
    spec = np.clip(n @ half, 0.0, 1.0) ** 24
    # Ambient plus diffuse, then into ramp steps; dither only near each seam.
    level = 0.12 + 0.88 * diffuse
    steps = len(RAMP)
    f = level * (steps - 1)
    base = np.floor(f)
    frac = f - base
    seam = 0.22
    up = (frac > 1.0 - seam) & (bay < (frac - (1.0 - seam)) / seam * 0.5)
    idx = np.clip(base + up, 0, steps - 1).astype(int)

    # Creases: where the solid on top changes, the lower one shows a dark joint line.
    crease = np.zeros((H, W), dtype=bool)
    for dy, dx in ((0, 1), (1, 0), (0, -1), (-1, 0)):
        nb_owner = np.roll(np.roll(S.owner, dy, axis=0), dx, axis=1)
        nb_z = np.roll(np.roll(S.z, dy, axis=0), dx, axis=1)
        crease |= inside & (nb_owner >= 0) & (nb_owner != S.owner) & (nb_z > S.z + 0.6)

    # Silhouette edge: inside pixels with an empty neighbour.
    edge = np.zeros((H, W), dtype=bool)
    for dy, dx in ((0, 1), (1, 0), (0, -1), (-1, 0)):
        nb = np.roll(np.roll(inside, dy, axis=0), dx, axis=1)
        edge |= inside & ~nb
    facing = (n[..., 0] * LIGHT[0] + n[..., 1] * LIGHT[1]) > 0.12

    colours = np.zeros((H, W), dtype=object)
    colours[:] = ""
    for k, name in enumerate(RAMP):
        colours[inside & (idx == k)] = name
    colours[inside & crease] = CREASE
    colours[inside & edge & ~facing] = "N1"
    colours[inside & edge & facing & (diffuse > 0.45)] = RIM[0]
    colours[inside & edge & facing & (diffuse > 0.75)] = RIM[1]
    colours[inside & ~edge & ~crease & (spec > 0.55)] = RIM[0]
    colours[inside & ~edge & ~crease & (spec > 0.8)] = RIM[1]

    # A thin aura lifts the silhouette off the sky: the empty pixels next to the body.
    aura = np.zeros((H, W), dtype=bool)
    for dy, dx in ((0, 1), (1, 0), (0, -1), (-1, 0)):
        aura |= ~inside & np.roll(np.roll(inside, dy, axis=0), dx, axis=1)
    colours[aura & ((xs + ys) % 2 == 0)] = AURA

    for y in range(H):
        for x in range(W):
            name = colours[y, x]
            if name:
                img[y, x, :3] = RGB[name]
                img[y, x, 3] = 255
    return img

def add_stardust(img: np.ndarray):
    dark = {RGB[k] for k in ("N2", "N3", "N4")}
    for y in range(H):
        for x in range(W):
            if img[y, x, 3] and tuple(img[y, x, :3]) in dark:
                h = (x * 374761393 + y * 668265263) & 0xFFFFFFFF
                h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
                if h % 37 == 0:
                    img[y, x, :3] = RGB["N8"] if h % 3 else RGB["D0"]


# Which part owns each of Scorpius's landmarks (game/core/chapter.gd STAGES).
STAR_PARTS = {13: "stinger", 12: "stinger", 11: "stinger", 10: "tail", 9: "tail", 8: "tail",
              7: "body", 6: "body", 5: "body", 4: "heart", 3: "heart", 1: "claws", 0: "claws", 2: "claws"}



def save(img: np.ndarray, path: Path):
    Image.fromarray(img, "RGBA").save(path)
    print(f"wrote {path.relative_to(ROOT)}")


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--preview", type=Path, help="also write the figure over the sky, x3, here")
    args = parser.parse_args()
    ART.mkdir(parents=True, exist_ok=True)
    img, S, marks = paint_scorpio()
    used = sd.check(img)
    print(f"figure: {sum(used.values())} px, {used}")
    save(img, OUT)
    for part, piece in sd.pieces(img, part_tags(S, img, marks), PARTS).items():
        save(piece, ART / f"scorpio_piece_{part}.png")
    if args.preview:
        sd.preview(img, L, SIZES, SEGMENTS).save(args.preview)
        print(f"wrote {args.preview}")
    for name, landmarks in stage_landmarks().items():
        stage = Solids()
        STAGE_BUILDERS[name](stage, landmarks)
        painting = shade(stage)
        add_stardust(painting)
        save(painting, ART / f"scorpio_part_{name}.png")


if __name__ == "__main__":
    main()
