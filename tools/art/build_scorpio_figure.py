"""Builds the painted Scorpio in assets/art/scorpio_figure.png (the final stage's reward).

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

The image is the full 180x320 game screen (transparent outside the figure), in home layout: the
chapter chart draws it as is, and a stage draws it where its sky shifts the map.

Run: python tools/art/build_scorpio_figure.py   (needs Pillow and numpy)
"""

import math
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "art" / "scorpio_figure.png"

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
        prev = track[max(k - 1, 0)]
        nxt = track[min(k + 1, plates - 1)]
        S.ellipsoid(track[k], v(nxt) - v(prev), 9.0, widths[k], depth=7.0, lift=-k * 0.6, along_flat=0.35)

    # The carapace (prosoma): a broad shield from Dschubba back to sigma, over the plates' front.
    S.ellipsoid(lerp(head, sigma, 0.45), v(head) - v(sigma), 15.0, 11.0, depth=8.0, lift=1.5)

    # The metasoma: five tail joints from mu to kappa, each a bulb, thinning towards the sting.
    tail = [lerp(eps, mu, 0.92), L[8], L[9], L[10], L[11], L[12]]
    radii = [7.0, 6.6, 6.2, 5.8, 5.4]
    for k in range(5):
        a, b = v(tail[k]), v(tail[k + 1])
        S.ellipsoid((a + b) / 2, b - a, np.linalg.norm(b - a) / 2 + 3.0, radii[k], depth=6.0, lift=-3.0 + k * 0.2, along_flat=0.5)

    # The telson: a swollen bulb between kappa and Shaula, then the curved sting past Shaula.
    kappa, shaula = v(L[12]), v(L[13])
    S.ellipsoid(lerp(kappa, shaula, 0.6), shaula - kappa, 13.0, 6.8, depth=6.0, lift=-1.5)
    forward = unit(shaula - kappa)
    curl = np.array([forward[1], -forward[0]])  # turns up, back over the body
    if curl[1] > 0:
        curl = -curl
    sting = bezier(shaula + forward * 4.0, shaula + forward * 14.0 + curl * 2.0, shaula + forward * 13.0 + curl * 12.0, 10)
    S.chain(sting, list(np.linspace(3.6, 0.5, len(sting))), lift=-1.0)

    # The pedipalps: from the carapace's front corners out to beta and pi, then heavy pincers that
    # open forward (right), the way the scorpion faces.
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


def main():
    S = Solids()
    build_body(S)
    img = shade(S)
    add_details(img)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(img, "RGBA").save(OUT)
    print(f"wrote {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
