"""Builds the Scorpio's paintings (the chapter's rewards), in assets/art/:

  scorpio_figure.png         the whole scorpion, the final stage's reward
  scorpio_piece_<part>.png   the same painting cut into the chapter's five parts (stinger, tail,
                             body, heart, claws), in the same full-screen home layout: the chapter
                             chart shows the won ones dormant, then the whole figure once the final
                             is won
  scorpio_part_<map>.png     each part stage's own painting, the same body part fitted to that
                             stage's own landmarks (game/core/star_map.gd, read from the source),
                             shown when the stage is complete

The whole Scorpio is a clean line, semi-hollow with stardust. Its form is a stack of shapes
(tools/art/clean_line.py) round the 14 landmarks of Scorpius (game/core/scorpio.gd LANDMARKS): a
carapace with two arms and heavy pincers reaching to beta and pi, eight thin legs, six body plates
from sigma through Antares, and a tail of six segments curling down through zeta, eta and theta and
back up to the telson and its sting at Shaula. clean_line draws one unbroken 1 px line round each
plate and segment, hidden where a later shape lies over it. The line is four N steps above the sky
behind it (five on its lit, upper-left side) with a few N9 rose glints. Inside, each segment holds
Bayer-dithered stardust (tools/art/stardust.py) one or two steps up, thick along its edge and thin
in its middle so the sky shows through, plus N7/N8/D0 specks off the line. Opaque palette pixels
only; nothing in the Sun's zone (y < 78) or at or below the end panel; each landmark star in a gap
clear of specks, on a faint pixel of its own part.

The pieces partition the whole: each pixel goes with the part of the segment under it, else with
the nearest tagged pixel; each star's own pixel goes with its part.

The part stages are painted the same way (tools/art/scorpio_part_paintings.py): each the same body
part as the whole, re-posed on that stage's landmarks with the whole's shape profiles, light and
seed, a clean line semi-hollow with stardust.

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
import clean_line  # noqa: E402
from clean_line import Axis, cubic, path_of, placed, segment, tube  # noqa: E402
import scorpio_part_paintings  # noqa: E402
import stardust as sd  # noqa: E402

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



# ---- The whole Scorpio: a clean line, semi-hollow with stardust (tools/art/clean_line.py). ----

SEED = 7
# Each landmark's size (game/core/scorpio.gd SIZES): the stars' gaps and the preview's stars.
SIZES = ["M", "M", "S", "S", "B", "S", "M", "S", "S", "S", "B", "S", "M", "B"]
# Scorpius's strings, for the preview.
SEGMENTS = [(0, 1), (1, 2), (1, 3), (3, 4), (4, 5), (5, 6), (6, 7), (7, 8), (8, 9), (9, 10),
            (10, 11), (11, 12), (12, 13)]

# The figure is drawn in clean_line's 4x space (game pixel (x, y) covers 4x..4x+3).
# The centre line of the body and tail, from the carapace's front to the telson's root.
AXIS = [(668, 458), (610, 468), (555, 480), (500, 503), (458, 545), (428, 602), (405, 670),
        (390, 740), (374, 822), (356, 902), (305, 932), (220, 934), (140, 916), (80, 870), (72, 820)]
# The carapace: from CARA_S0 to CARA_S1 along the axis, half-widths at its front and back.
CARA_S0, CARA_S1, CARA_W = 6, 118, (36, 52)
# The mesosoma's half-width along the axis: (arclength, half-width), linear between.
BODY_WIDTH = [(100, 48), (150, 60), (205, 70), (250, 72), (300, 67), (345, 56), (392, 42)]
# The six plates' edges along the axis (each overlaps the next) and their parts.
PLATE_EDGES = [108, 152, 198, 244, 290, 338, 392]
PLATE_PARTS = ["heart", "heart", "heart", "heart", "body", "body"]
# The six tail segments, from TAIL_S0 to the axis's end: half-widths and parts.
TAIL_S0 = 386
TAIL_WIDTHS = [29, 28, 27, 26, 25, 24]
TAIL_PARTS = ["body", "body", "tail", "tail", "tail", "stinger"]
# The telson: a round vesicle at kappa and a slim sting arcing over to Shaula, its tip turned down.
TELSON = ("M 52 818 C 54 780 88 750 124 746 C 150 736 182 722 206 726 "
          "C 221 729 229 739 226 752 C 220 745 211 741 200 743 "
          "C 182 746 166 756 158 774 C 150 798 122 814 96 822 Z")
# The legs, four a side, each arching out and forward to the knee, then out and back to the foot:
# (arclength of the root, knee angle (+: toward the head), femur length, foot angle, tibia length).
LEGS_UP = [(124, 36, 44, -14, 44), (148, 8, 48, -44, 50), (172, -20, 50, -70, 52), (196, -48, 48, -96, 52)]
LEGS_DOWN = [(170, 62, 44, 20, 46), (196, 30, 50, -14, 54), (222, -2, 52, -46, 56), (248, -34, 50, -80, 54)]
LEG_WIDTH = (3.4, 2.8)
# The pedipalps: femur and patella (spines and half-widths), then the pincer at the wrist.
ARMS = [
    {"femur": [(612, 430), (575, 412), (536, 404)], "fw": (11, 10),
     "patella": [(536, 404), (546, 382), (574, 368)], "pw": (11, 13)},
    {"femur": [(606, 512), (624, 548), (642, 574)], "fw": (13, 12),
     "patella": [(642, 574), (662, 590), (670, 614)], "pw": (12, 14)},
]
CHELAE = [
    {"wrist": (562, 365), "ang": 8, "L": 154, "h": 44, "g": 0.0, "fb": 0.62},
    {"wrist": (670, 604), "ang": 112, "L": 164, "h": 46, "g": 0.04, "fb": 0.58},
]

def chela(L, h, g=0.0, fb=0.62):
    """A pincer in local space (x along it, y to its outer side): a bulbous hand and two curved
    fingers, their tips turned toward each other round an almond opening. The fingers begin at
    `fb` of its length; `g` opens the gap between their tips."""
    def X(x):
        return L * (x * fb / 0.62 if x <= 0.62 else fb + (x - 0.62) * (1 - fb) / 0.38)
    P = []
    P += cubic((X(0), 0.42 * h), (X(0.12), 1.0 * h), (X(0.45), 1.08 * h), (X(0.62), 0.78 * h))
    P += cubic((X(0.62), 0.78 * h), (X(0.80), 0.60 * h), (X(0.98), 0.48 * h), (X(1.0), (0.16 + g) * h))[1:]
    P += cubic((X(1.0), (0.16 + g) * h), (X(0.93), (0.30 + g) * h), (X(0.80), 0.34 * h), (X(0.66), 0.06 * h))[1:]
    P += cubic((X(0.66), 0.06 * h), (X(0.78), -0.26 * h), (X(0.90), (-0.24 - g) * h), (X(0.95), (-0.20 - g) * h))[1:]
    P += cubic((X(0.95), (-0.20 - g) * h), (X(0.95), -0.50 * h), (X(0.78), -0.76 * h), (X(0.55), -0.90 * h))[1:]
    P += cubic((X(0.55), -0.90 * h), (X(0.35), -1.0 * h), (X(0.10), -0.85 * h), (X(0), -0.40 * h))[1:]
    return P


def body_width(s):
    xs_, ws = zip(*BODY_WIDTH)
    return float(np.interp(s, xs_, ws))


def figure_shapes() -> list:
    """The scorpion as clean_line shapes, back to front: the telson, the tail, the legs, the
    plates, the arms, the carapace and the pincers."""
    shapes = []

    def add(name, part, pts, group=None):
        shapes.append({"name": name, "part": part, "group": group or name, "d": path_of(pts)})

    ax = Axis(AXIS)
    shapes.append({"name": "telson", "part": "stinger", "group": "telson", "d": TELSON})
    step = (ax.L - TAIL_S0) / len(TAIL_WIDTHS)
    for i in reversed(range(len(TAIL_WIDTHS))):
        s0, s1, w = TAIL_S0 + i * step - 7, TAIL_S0 + (i + 1) * step + 7, TAIL_WIDTHS[i]
        add(f"bead{i}", TAIL_PARTS[i], segment(ax, s0, s1, w, w * 0.94, p=2.4, pinch=0.12))
    for side, sign, legs in (("u", 1, LEGS_UP), ("d", -1, LEGS_DOWN)):
        for j, (s, a1, l1, a2, l2) in enumerate(legs):
            c, t, nrm = ax.frame(s)
            n, f = nrm * sign, -t
            root = c + n * (body_width(s) - 10)

            def toward(a):
                r = math.radians(a)
                return n * math.cos(r) + f * math.sin(r)
            knee = root + toward(a1) * l1
            foot = knee + toward(a2) * l2
            spine = [root, root + toward(a1) * l1 * 0.55, knee, knee + toward(a2) * l2 * 0.5, foot]
            add(f"leg_{side}{j}", "claws" if s < CARA_S1 else "heart", tube(spine, *LEG_WIDTH))
    for i in reversed(range(len(PLATE_PARTS))):
        s0, s1 = PLATE_EDGES[i] - 4, PLATE_EDGES[i + 1] + 10
        add(f"plate{i}", PLATE_PARTS[i], segment(ax, s0, s1, body_width(s0 + 4), body_width(s1 - 4), p=3.2))
    for k, arm in enumerate(ARMS):
        add(f"femur{k}", "claws", tube(arm["femur"], *arm["fw"]), group=f"arm{k}")
        add(f"patella{k}", "claws", tube(arm["patella"], *arm["pw"]), group=f"arm{k}")
    add("carapace", "claws", segment(ax, CARA_S0, CARA_S1, CARA_W[0], CARA_W[1], p=3.0))
    for k, ch in enumerate(CHELAE):
        add(f"chela{k}", "claws", placed(ch["wrist"], ch["ang"], chela(ch["L"], ch["h"], ch["g"], ch["fb"])))
    return shapes


# The part stages' own paintings: the same body parts, fitted to each stage's landmarks.

def stage_landmarks():
    """Each part stage's landmarks and their sizes ("S", "M", "B"), read from
    game/core/star_map.gd (one source of truth)."""
    import re
    src = STAR_MAP.read_text()
    found = {}
    for name in PARTS:
        block = re.search(r"static func %s\(\) -> StarMap:(.*?)\n\n\n" % name, src, re.S).group(1)
        marks = re.search(r"map\.landmarks = \[(.*?)\]\n", block).group(1)
        sizes = re.search(r"map\.sizes = \[(.*?)\]\n", block).group(1)
        found[name] = ([(int(x), int(y)) for x, y in re.findall(r"Vector2i\((-?\d+), (-?\d+)\)", marks)],
                       [size[0] for size in re.findall(r"Star\.Size\.(SMALL|MEDIUM|BIG)", sizes)])
    return found


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
    img, parts = clean_line.semi_hollow(figure_shapes(), L, SIZES, SEED, LIGHT)
    used = sd.check(img)
    print(f"figure: {sum(used.values())} px, {used}")
    save(img, OUT)
    for part, piece in sd.pieces(img, clean_line.part_tags(parts, img, L, STAR_PARTS), PARTS).items():
        save(piece, ART / f"scorpio_piece_{part}.png")
    if args.preview:
        sd.preview(img, L, SIZES, SEGMENTS).save(args.preview)
        print(f"wrote {args.preview}")
    for name, (landmarks, sizes) in stage_landmarks().items():
        painting = scorpio_part_paintings.paint(name, landmarks, sizes, SEED, LIGHT)
        used = sd.check(painting)
        print(f"{name}: {sum(used.values())} px, {used}")
        save(painting, ART / f"scorpio_part_{name}.png")


if __name__ == "__main__":
    main()
