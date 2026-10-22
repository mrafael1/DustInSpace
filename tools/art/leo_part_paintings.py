"""Builds the Leo part stages' own paintings (the old shaded-solid style), in assets/art/:

  leo_part_<part>.png    each part stage's own painting (tail, haunch, heart, mane, head), the
                         same body part fitted to that stage's own landmarks
                         (game/core/star_map.gd, read from the source), shown when the stage is
                         complete

Drawn as the Aquarius is (tools/art/build_aquarius_figure.py): smooth outlines at native size, each
given roundness from its own shape, then lit and shaded as the Scorpio's part stages are (light from
the top left, the N ramp in flat bands with a Bayer checker only along each seam, dark creases where
one part lies over another, a rose rim on lit edges, stardust specks, a thin aura). The whole lion
and its chart pieces are the clean-line painting in tools/art/build_leo_figure.py, which runs this
module after it.
No colour outside the Stellar Sun palette; every pixel opaque or empty.

Run: python tools/art/build_leo_figure.py   (or this module alone; needs Pillow and numpy)
"""

import importlib.util
import re
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
_spec = importlib.util.spec_from_file_location("aquarius_art", ROOT / "tools" / "art" / "build_aquarius_figure.py")
aq = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(aq)
sc = aq.sc

ART = aq.ART
STAR_MAP = aq.STAR_MAP
W, H = aq.W, aq.H
v, lerp, unit, bezier = aq.v, aq.lerp, aq.unit, aq.bezier
limb = aq.limb
RGB = aq.RGB
PARTS = ("tail", "haunch", "heart", "mane", "head")

GROUND = 214.0

# The mane is its own material: the N ramp's deeper steps, so the head stands out in front of it.
aq.RAMPS["mane"] = (["N1", "N1", "N2", "N2", "N3", "N4", "N5", "N6"], ["N7", "N8"])


# --- parts ---------------------------------------------------------------------------------

def locks(S, outline, size, lift, spacing=3.5, seed=5):
    """A shaggy fringe round `outline`: overlapping rounded locks of hair every `spacing` px along
    it, each pointing away from the middle, so the edge is scalloped, not spiked."""
    path = [v(p) for p in aq.spline(outline, steps=12)]
    centre = sum(path) / len(path)
    rng = np.random.default_rng(seed)
    walked = spacing
    for k in range(len(path)):
        a, b = path[k], path[(k + 1) % len(path)]
        walked += float(np.linalg.norm(b - a))
        if walked < spacing:
            continue
        walked = 0.0
        out = unit(a - centre)
        length = size * (0.6 + 0.7 * rng.random())
        tip = a + out * length + np.array([-out[1], out[0]]) * rng.normal(0, 1.0)
        S.ellipsoid(lerp(a, tip, 0.5), tip - a, length * 0.6 + 1.0, size * 0.45, depth=3.0, lift=lift + rng.random() * 0.4, squash=1.5)


def mane(S, outline, lift, size=7.0, seed=5, root=None):
    """A lion's mane in its deeper colours: a domed mass inside `outline` ringed with overlapping
    locks, and tufts all over it, each pointing away from `root` (where the head sits; the middle
    by default), so the whole mass reads as fur, not a crest."""
    S.mat = "mane"
    locks(S, outline, size, lift - 1.0, seed=seed)
    S.shape(outline, depth=12, lift=lift)
    inside = aq.mask_of(outline)
    pts = [v(p) for p in outline]
    root = v(root) if root is not None else sum(pts) / len(pts)
    rng = np.random.default_rng(seed + 1)
    ys, xs = np.nonzero(inside)
    for k in rng.permutation(len(xs))[: max(6, len(xs) // 40)]:
        # A strand of hair: a tapering lock flowing out from the head, curving a little.
        p = v((xs[k] + 0.5, ys[k] + 0.5))
        out = unit(p - root + rng.normal(0, 0.35, 2))
        bend = np.array([-out[1], out[0]]) * rng.normal(0, 2.0)
        length = size * (1.1 + 0.6 * rng.random())
        tip = p + out * length + bend
        strand = bezier(p - out * 2.0, p + out * length * 0.5 - bend, tip, 5)
        S.shape(limb(strand, list(np.linspace(size * 0.34, 0.6, len(strand)))), depth=2.0, lift=lift + 11.0 + rng.random() * 0.8)
    S.mat = "body"


# The lion's head, drawn once in the whole figure's place (facing right) and fitted to any three
# points: the crown by the ear (mu), the brow over the eye (epsilon), the mouth (lambda).
HEAD_KEYS = [(136, 92), (154, 110), (160, 134)]
# Its outline: the forehead sloping forward to the square corner of the nose, the muzzle's front
# down to the lip, the chin set back, the jaw back to the cheek; a flatter muzzle over its front,
# the chin under it, a small round ear behind the crown.
HEAD_FACE = [(138, 100), (144, 97), (151, 98), (157, 102), (161, 107), (165, 111), (169, 114), (170, 118),
             (169, 121), (167, 123), (166, 127), (163, 130), (160, 133), (157, 136), (151, 138), (144, 136),
             (139, 130), (136, 120), (135, 108)]
HEAD_MUZZLE = [(158, 108), (165, 111), (169, 114), (170, 118), (169, 121), (166, 124), (160, 125), (156, 118)]
HEAD_CHIN = [(152, 128), (163, 128), (161, 134), (155, 137), (149, 135)]
HEAD_EAR = [(140, 100), (137, 92)]
# The face's marks, drawn over the shading: a dark eye under the brow with a glint, the nose pad at
# the muzzle's corner, the mouth's line back from the lip, whisker dots on the muzzle.
HEAD_MARKS = [((150, 108), "N1"), ((151, 108), "N1"), ((152, 108), "N1"), ((151, 107), "N8"),
              ((167, 114), "N1"), ((168, 114), "N1"), ((169, 115), "N1"), ((168, 115), "N1"), ((169, 116), "N2"),
              ((166, 125), "N1"), ((164, 126), "N1"), ((162, 127), "N1"), ((160, 127), "N1"), ((158, 127), "N2"),
              ((161, 117), "N4"), ((163, 116), "N4"), ((162, 120), "N4"), ((164, 119), "N4")]


def fit(keys, targets):
    """The affine map taking the three `keys` onto the three `targets`."""
    src = np.array([[x, y, 1.0] for x, y in keys])
    dst = np.array([v(p) for p in targets])
    m = np.linalg.solve(src, dst)
    return lambda p: np.array([p[0], p[1], 1.0]) @ m, float(np.sqrt(abs(np.linalg.det(m[:2, :2]))))


def similar(a, b, ta, tb):
    """The map that only turns and scales, taking `a` to `ta` and `b` to `tb`."""
    a, b, ta, tb = v(a), v(b), v(ta), v(tb)
    d, td = b - a, tb - ta
    k = np.linalg.norm(td) / np.linalg.norm(d)
    angle = np.arctan2(td[1], td[0]) - np.arctan2(d[1], d[0])
    c, s_ = np.cos(angle) * k, np.sin(angle) * k
    rot = np.array([[c, -s_], [s_, c]])
    return (lambda p: ta + rot @ (v(p) - a)), float(k)


def lion_head(S, crown, brow, mouth, lift, eye=True):
    """A lion's head in profile facing right on its crown by the ear, its brow over the eye and its
    mouth: a sloping forehead to the square corner of the nose, a flat muzzle, the chin set back, a
    round ear. With no `brow` (None), it's only turned and scaled onto the crown and the mouth, so a
    stage's head keeps its shape."""
    if brow is None:
        to, k = similar(HEAD_KEYS[0], HEAD_KEYS[2], crown, mouth)
    else:
        to, k = fit(HEAD_KEYS, [crown, brow, mouth])
    S.shape(limb([to(p) for p in HEAD_EAR], [3.8 * k, 3.0 * k]), depth=2.5, lift=lift - 1.0)
    S.shape([to(p) for p in HEAD_FACE], depth=6, lift=lift)
    S.shape([to(p) for p in HEAD_CHIN], depth=3, lift=lift + 1.0)
    S.shape([to(p) for p in HEAD_MUZZLE], depth=3, lift=lift + 2.0)
    for p, colour in HEAD_MARKS:
        if eye or colour != "N8":
            S.marks.append((tuple(np.round(to(p)).astype(int)), colour))


def paw(S, at, forward, lift, size=1.0):
    """A big paw at the end of a leg: a rounded pad along the ground, toes forward."""
    at, forward = v(at), unit(forward)
    S.shape(limb([at - forward * 3.0 * size, at + forward * 4.5 * size], [5.0 * size, 4.2 * size]), depth=3.5, lift=lift)


def tail(S, points, tuft, lift):
    """A long tail through `points`, thin, ending in a dark shaggy tuft (the mane's colours)."""
    S.shape(limb(points, list(np.linspace(2.4, 1.6, len(points)))), depth=2.5, lift=lift)
    tuft = v(tuft)
    S.mat = "mane"
    blob = [tuft + v((-4, -5)), tuft + v((3, -4)), tuft + v((5, 2)), tuft + v((1, 7)), tuft + v((-4, 5))]
    locks(S, blob, 4.0, lift + 0.2, spacing=3.5, seed=11)
    S.shape(blob, depth=4, lift=lift + 0.5)
    S.mat = "body"


# --- the stages' own paintings -------------------------------------------------------------

def stage_landmarks():
    """Each Leo stage's landmarks, read from game/core/star_map.gd (one source of truth)."""
    src = STAR_MAP.read_text()
    found = {}
    for part in PARTS:
        block = re.search(r"static func leo_%s\(\) -> StarMap:(.*?)\n\n\n" % part, src, re.S).group(1)
        marks = re.search(r"map\.landmarks = \[(.*?)\]\n", block).group(1)
        found[part] = [(int(x), int(y)) for x, y in re.findall(r"Vector2i\((-?\d+), (-?\d+)\)", marks)]
    return found


def build_tail(S, M):
    """The Tail: the round hindquarter at the first star, the tail sweeping down through every star
    and curling up to the tuft on the last."""
    rump = v(M[0])
    S.shape([rump + v((-12, -12)), rump + v((8, -16)), rump + v((20, -4)), rump + v((18, 14)), rump + v((4, 20)),
             rump + v((-10, 12)), rump + v((-14, 0))], depth=14, lift=2)
    tail(S, [rump + v((-10, 4))] + [v(p) for p in M[1:-1]] + [v(M[-1]) + v((2, 6))], M[-1], lift=0)


def round_mass(points, grow=10.0, steps=10):
    """A full rounded outline round `points` (a body's mass, not a band along them): each of
    `steps` directions from their centre reaches the farthest point that way, plus `grow`."""
    pts = [v(p) for p in points]
    centre = sum(pts) / len(pts)
    outline = []
    for k in range(steps):
        a = 2.0 * np.pi * k / steps
        d = np.array([np.cos(a), np.sin(a)])
        reach = max(float((p - centre) @ d) for p in pts)
        outline.append(centre + d * (max(reach, 0.0) + grow))
    return outline


def build_haunch(S, M):
    """The Haunch: the lion's round hindquarter over the back, loin, thigh and belly stars, the great
    thigh muscle over the big one, the leg down through the knee and the hock to the paw."""
    back, loin, thigh, knee, hock, foot, belly = [v(p) for p in M]
    S.shape(round_mass([back, loin, thigh, belly], grow=9.0), depth=10, lift=0)
    S.shape(round_mass([thigh + v((-4, -8)), thigh + v((6, 6)), knee + v((6, -6))], grow=8.0, steps=9), depth=8, lift=3)
    S.shape(limb([knee, hock, foot + v((4, -3))], [6.6, 5.0, 4.4]), depth=5, lift=2)
    paw(S, foot, foot - hock, lift=2.5)


def build_heart(S, M):
    """The Heart: a tuft of mane on the first star, the deep chest round the neck, Regulus and the
    breast, the foreleg striding forward through the wrist to the paw."""
    mane_star, neck, regulus, wrist, foot, breast = [v(p) for p in M]
    S.shape(round_mass([neck, regulus, breast, regulus + v((0, 10))], grow=9.0), depth=10, lift=0)
    S.shape(limb([regulus + v((2, -2)), wrist, foot + v((-4, -2))], [8.6, 6.0, 4.6]), depth=6, lift=3)
    paw(S, foot, (1, 0.3), lift=3.5)
    mane(S, [mane_star + v((-16, -10)), mane_star + v((0, -14)), mane_star + v((14, -6)), mane_star + v((14, 10)),
             neck + v((12, 2)), neck + v((-8, 2)), mane_star + v((-18, 6))], lift=6, size=6.0, seed=7,
         root=mane_star + v((14, 14)))


def build_mane(S, M):
    """The Mane: a great sweep of hair curling up through every star from the heart to the brow,
    every strand flowing out from where the head would sit inside the curve; a tuft branching out
    to the last star."""
    path = [v(p) for p in M[:-1]]
    curve = [v(p) for p in aq.spline(path, steps=6)][: (len(path) - 1) * 6 + 1]
    band = limb(curve, list(np.linspace(9.0, 12.0, len(curve))))
    centre = sum(path) / len(path) + v((10, 12))
    mane(S, band, lift=0, size=8.0, seed=21, root=centre)
    tuft = v(M[-1])
    root = path[2]
    S.mat = "mane"
    S.shape(limb([root, lerp(root, tuft, 0.5) + v((0, -3)), tuft], [7.0, 5.0, 3.6]), depth=6, lift=-1)
    blob = [tuft + v((-5, -5)), tuft + v((3, -5)), tuft + v((4, 3)), tuft + v((-2, 6)), tuft + v((-6, 1))]
    locks(S, blob, 5.0, -1.0, spacing=3.5, seed=23)
    S.mat = "body"


def build_head(S, M):
    """The Head: the mane behind it on the first two stars, the head in profile with the ear at the
    crown and the mouth on its stars (the face star on its eye side), a beard of mane under the jaw
    out to the branch star."""
    mane_star, brow_back, crown, face, mouth, jaw = [v(p) for p in M]
    mane(S, [mane_star + v((-12, -12)), brow_back + v((-8, -14)), crown + v((-4, -14)), crown + v((12, -6)),
             face + v((-8, 8)), jaw + v((-6, 12)), mane_star + v((4, 14)), mane_star + v((-14, 4))],
         lift=0, size=9.0, seed=9, root=face)
    mane(S, [jaw + v((-10, -6)), mouth + v((-8, -2)), mouth + v((-4, 8)), jaw + v((4, 12)), jaw + v((-10, 8))],
         lift=2, size=6.0, seed=10, root=face + v((4, -6)))
    lion_head(S, crown, None, mouth, lift=20)


STAGE_BUILDERS = {"tail": build_tail, "haunch": build_haunch, "heart": build_heart, "mane": build_mane, "head": build_head}


class Shapes(aq.Shapes):
    """The Aquarius's shapes, with marks drawn over the shading (the lion's face)."""

    def __init__(self):
        super().__init__()
        self.marks = []


def paint(S):
    img = aq.shade(S)
    aq.stardust(img)
    for (x, y), colour in S.marks:
        if 0 <= x < W and 0 <= y < H and img[y, x, 3]:
            img[y, x, :3] = RGB[colour]
    return img



def main():
    ART.mkdir(parents=True, exist_ok=True)
    for part, landmarks in stage_landmarks().items():
        stage = Shapes()
        STAGE_BUILDERS[part](stage, landmarks)
        painting = paint(stage)
        for x, y in landmarks:
            assert stage.owner[y, x] >= 0, f"{part}: landmark ({x}, {y}) sits on nothing"
        sc.save(painting, ART / f"leo_part_{part}.png")


if __name__ == "__main__":
    main()
