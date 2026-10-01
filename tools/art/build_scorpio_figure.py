"""Builds the painted Scorpio (the chapter's reward) and its pieces, in assets/art/:

  scorpio_figure.png         the whole scorpion, the final stage's reward
  scorpio_piece_<part>.png   the same painting cut into the chapter's five parts (stinger, tail,
                             body, heart, claws), in the same full-screen home layout: the chapter
                             chart assembles them as parts are won
  scorpio_part_<map>.png     each part stage's own painting, the same body part fitted to that
                             stage's own landmarks (game/core/star_map.gd, read from the source),
                             shown when the stage is complete

Completing the final (stage 6) no longer traces a line drawing round the stars: the scorpion itself
rises behind them, painted. Every body part is anchored to the 14 landmarks of Scorpius's figure
(game/core/scorpio.gd LANDMARKS), so the gold stars sit on its body as the real stars sit on the
constellation: Dschubba on the head, beta and pi in the claws, Antares at the heart, the tail
curling down through zeta, eta and theta and back up to Shaula, the sting.

The body is modelled as overlapping solids (spheroids and capsules: the carapace, seven plates of
the abdomen, five tail joints, the telson, the curved sting, two jointed arms with heavy pincers,
four pairs of legs). Each pixel takes the solid nearest the viewer, is lit from the top left, and
is shaded on a stepped palette ramp (flat bands, a Bayer 4x4 checker only along each seam). Where
one solid meets another a dark crease shows the joint, the lit edges catch a rose rim (N9/N10),
small glints mark the highlights, and a thin 1 px aura (N3) lifts the silhouette off the sky.
No colour outside the Stellar Sun palette; no partial alpha (each pixel is opaque or empty).

Every image is the full 180x320 game screen (transparent outside the figure), in home layout: the
chapter chart draws it as is, and a stage draws it where its sky shifts the map.
The pieces partition the whole: every solid is tagged with the part whose stars it carries
(Chapter.STAGES), and the aura follows the body pixel beside it.

Run: python tools/art/build_scorpio_figure.py   (needs Pillow and numpy)
"""

import math
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / "assets" / "art"
OUT = ART / "scorpio_figure.png"
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


def build_body(S: Solids):
    head, sigma, antares, tau, eps, mu = L[1], L[3], L[4], L[5], L[6], L[7]

    # Legs first (under everything): four pairs off the front of the body, each three joints that
    # reach out, then bend back towards the tail.
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

    # The mesosoma: seven plates from just behind the carapace to mu, widest round Antares.
    plates = 7
    widths = [11.0, 12.5, 13.5, 13.5, 12.5, 11.0, 9.0]
    track = [lerp(sigma, antares, 0.45), lerp(sigma, antares, 0.95), lerp(antares, tau, 0.45),
             lerp(antares, tau, 0.95), lerp(tau, eps, 0.5), lerp(eps, mu, 0.1), lerp(eps, mu, 0.55)]
    for k in range(plates):
        S.tag = "heart" if k < 3 else "body"
        prev = track[max(k - 1, 0)]
        nxt = track[min(k + 1, plates - 1)]
        S.ellipsoid(track[k], v(nxt) - v(prev), 9.0, widths[k], depth=7.0, lift=-k * 0.6, along_flat=0.35)

    # The carapace (prosoma): a broad shield from Dschubba back to sigma, over the plates' front.
    S.tag = "claws"
    S.ellipsoid(lerp(head, sigma, 0.45), v(head) - v(sigma), 15.0, 11.0, depth=8.0, lift=1.5)

    # The metasoma: five tail joints from mu to kappa, each a bulb, thinning towards the sting.
    tail = [lerp(eps, mu, 0.92), L[8], L[9], L[10], L[11], L[12]]
    radii = [7.0, 6.6, 6.2, 5.8, 5.4]
    for k in range(5):
        S.tag = "tail" if k < 4 else "stinger"
        a, b = v(tail[k]), v(tail[k + 1])
        S.ellipsoid((a + b) / 2, b - a, np.linalg.norm(b - a) / 2 + 3.0, radii[k], depth=6.0, lift=-3.0 + k * 0.2, along_flat=0.5)

    # The telson: a swollen bulb between kappa and Shaula, then the curved sting past Shaula.
    kappa, shaula = v(L[12]), v(L[13])
    S.tag = "stinger"
    S.ellipsoid(lerp(kappa, shaula, 0.6), shaula - kappa, 13.0, 6.8, depth=6.0, lift=-1.5)
    forward = unit(shaula - kappa)
    curl = np.array([forward[1], -forward[0]])  # turns up, back over the body
    if curl[1] > 0:
        curl = -curl
    sting = bezier(shaula + forward * 4.0, shaula + forward * 14.0 + curl * 2.0, shaula + forward * 13.0 + curl * 12.0, 10)
    S.chain(sting, list(np.linspace(3.6, 0.5, len(sting))), lift=-1.0)

    # The pedipalps: from the carapace's front corners out to beta and pi, then heavy pincers that
    # open forward (right), the way the scorpion faces.
    S.tag = "claws"
    for claw, bend in ((L[0], -1.0), (L[2], 1.0)):
        shoulder = v(head) + v((-4.0, 5.0 * bend))
        elbow = lerp(shoulder, claw, 0.5) + v((-6.0, 1.0 * bend))
        S.chain([shoulder, elbow, claw], [3.6, 3.0, 3.6], lift=-0.5)
        manus = v(claw) + v((5.0, 0.0))
        S.ellipsoid(manus, (1.0, 0.25 * bend), 8.5, 5.8, depth=5.5, lift=0.5)
        tip = manus + v((7.0, 0.0))
        fixed = bezier(tip + v((-1, -2.2)), tip + v((7.0, -6.0)), tip + v((11.0, -1.0)), 7)
        moving = bezier(tip + v((-1, 2.2)), tip + v((7.0, 6.0)), tip + v((11.0, 1.0)), 7)
        S.chain(fixed, list(np.linspace(2.8, 0.7, 7)), lift=0.2)
        S.chain(moving, list(np.linspace(2.5, 0.7, 7)), lift=0.0)


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


def add_details(img: np.ndarray):
    # Stardust in the body: a sparse scatter of pale specks on its darker steps, fixed by a hash.
    dark = {RGB[k] for k in ("N2", "N3", "N4")}
    for y in range(H):
        for x in range(W):
            if img[y, x, 3] and tuple(img[y, x, :3]) in dark:
                h = (x * 374761393 + y * 668265263) & 0xFFFFFFFF
                h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
                if h % 37 == 0:
                    img[y, x, :3] = RGB["N8"] if h % 3 else RGB["D0"]
    # Eyes on the carapace, near its front: two pale glints.
    for p in ((152, 109), (154, 113)):
        img[p[1], p[0], :3] = RGB["D0"]
        img[p[1], p[0], 3] = 255


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


def pieces(S: Solids, img: np.ndarray):
    """The whole painting cut by part: each body pixel goes with its solid's part, each aura pixel
    with the body pixel beside it. A joint where two parts meet goes with the part of the star on
    top of it, so every star sits on its own part's piece."""
    for star, part in STAR_PARTS.items():
        x, y = L[star]
        S.tags[S.owner[y, x]] = part
    for star, part in STAR_PARTS.items():
        x, y = L[star]
        assert S.tags[S.owner[y, x]] == part, f"landmark {star} sits on a solid of two parts"
    tags = np.full((H, W), "", dtype=object)
    inside = S.z >= 0.0
    for y, x in zip(*np.nonzero(inside)):
        tags[y, x] = S.tags[S.owner[y, x]]
    for y, x in zip(*np.nonzero(img[..., 3] > 0)):
        if tags[y, x]:
            continue
        for dy, dx in ((0, 1), (1, 0), (0, -1), (-1, 0)):
            # The aura wraps at the image's edges like the np.roll that made it.
            ny, nx = (y + dy) % H, (x + dx) % W
            if tags[ny, nx] and inside[ny, nx]:
                tags[y, x] = tags[ny, nx]
                break
    out = {}
    for part in PARTS:
        piece = img.copy()
        piece[tags != part] = 0
        out[part] = piece
    assert all(tags[y, x] for y, x in zip(*np.nonzero(img[..., 3] > 0))), "every pixel has a part"
    return out


def save(img: np.ndarray, path: Path):
    Image.fromarray(img, "RGBA").save(path)
    print(f"wrote {path.relative_to(ROOT)}")


def main():
    ART.mkdir(parents=True, exist_ok=True)
    S = Solids()
    build_body(S)
    img = shade(S)
    add_details(img)
    save(img, OUT)
    for part, piece in pieces(S, img).items():
        save(piece, ART / f"scorpio_piece_{part}.png")
    for name, landmarks in stage_landmarks().items():
        stage = Solids()
        STAGE_BUILDERS[name](stage, landmarks)
        painting = shade(stage)
        add_stardust(painting)
        save(painting, ART / f"scorpio_part_{name}.png")


if __name__ == "__main__":
    main()
