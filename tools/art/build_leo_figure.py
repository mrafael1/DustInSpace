"""Builds the painted Leo (chapter 3's reward) and its pieces, in assets/art/:

  leo_figure.png         the whole lion, the final's reward and the chart's
  leo_piece_<part>.png   the same painting cut into the chapter's five parts (tail, haunch, heart,
                         mane, head), in the same full-screen home layout: the chapter chart
                         assembles them as parts are won
  leo_part_<part>.png    each part stage's own painting, the same body part fitted to that stage's
                         own landmarks (game/core/star_map.gd, read from the source), shown when the
                         stage is complete

The whole Leo is painted in the Stardust Myth style (tools/art/stardust.py), as the Scorpio is: the
lion is suggested, not drawn. Its form is modelled as overlapping solids (never shaded) that give
the stardust a mask, normals and a feature per solid. Over them go a broken contour (the lit side,
the legs and the head's silhouette at the brightest steps), each leg's own edge where it lies over
the body, the jaw's edge over the ruff (the back of the head only a broken line the mane's locks
cross), hollow nebula wisps (the face empty, the torso and the mane mostly sky), an outer haze,
specks thickest at the contour, rose glints, the face's marks (the eye a bright dot in a small
clear hollow under a heavy brow, the square muzzle's nose pad, whisker dots, the mouth's and the
chin's lines), the mane's scalloped ruff with a few locks of dust flowing out of it and round the
nape, the tail tuft's hanging locks, toe notches on the planted paws, and the mythic flourish: the
Lion of Summer's sunburst, rays of stardust fanning back from the mane's crest. Ruler-straight
runs are wobbled. Every pixel is a palette N step above the sky behind it, or a speck (N7, N8, D0)
or glint (N9); opaque or empty; nothing in the Sun's zone (y < 78); each landmark star in a small
clear gap, with no pale speck within 7 px of it and none on the face.

The lion walks to the right, east to the left as on the sky: its stars are points on the body. The
tail tuft is Denebola, the back Zosma, the thigh Chertan, the hock iota and the hind paw sigma; the
shaggy mane carries Algieba and zeta; the head in profile has mu by the ear, epsilon on the brow
over the eye and lambda at the mouth; the chest is eta, the raised foreleg Regulus and its paw
omicron, lifted mid-stride.

The pieces partition the whole: each pixel goes with the part of the solid under it (the torso
split at x 88 between the tail and the heart), else with the mane (its locks and rays), else with
the nearest tagged pixel.

The part stages keep the shaded-solid style of the Aquarius (tools/art/build_aquarius_figure.py):
smooth outlines lit from the top left on the N ramp, dark creases, a rose rim, stardust specks and
a thin aura.

Run: python tools/art/build_leo_figure.py [--preview out.png]   (needs Pillow and numpy)
"""

import argparse
import importlib.util
import re
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import stardust as sd  # noqa: E402

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

# Leo's landmarks (StarMap.leo): 0 lambda (the mouth), 1 epsilon (the brow), 2 mu (by the ear),
# 3 zeta, 4 Algieba (the mane), 5 eta (the chest), 6 Regulus (the foreleg), 7 omicron (its paw),
# 8 Zosma (the back), 9 Denebola (the tail tuft), 10 Chertan (the thigh), 11 iota (the hock),
# 12 sigma (the hind paw).
L = [(160, 134), (154, 110), (136, 92), (112, 100), (102, 124), (112, 148), (116, 176), (144, 194),
     (60, 122), (26, 150), (64, 156), (50, 184), (54, 212)]

# Which part owns each landmark (ChapterDef.leo).
STAR_PARTS = {9: "tail", 8: "tail", 10: "haunch", 11: "haunch", 12: "haunch", 6: "heart", 7: "heart",
              5: "heart", 4: "mane", 3: "mane", 2: "head", 1: "head", 0: "head"}

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


def build_figure(S):
    """The whole lion's form (never shaded: the Stardust Myth layers draw over it). Each solid has
    its part (`S.tag`, for the pieces) and its feature (`S.feat`, for the stardust)."""
    mouth, brow, crown, zeta, algieba, eta, regulus, omicron, zosma, denebola, chertan, iota, sigma = map(v, L)

    # The far legs, behind everything: a hind leg planted under the hip, a foreleg under the chest.
    S.tag, S.feat = "haunch", "farhind"
    S.shape(limb([(76, 140), (85, 170), (71, 190), (75, GROUND - 4)], [10.0, 6.4, 5.0, 4.6]), depth=6, lift=-10)
    S.feat = "farpaw"
    paw(S, (76, GROUND - 3), (1, 0), lift=-9.5)
    S.tag, S.feat = "heart", "farfore"
    S.shape(limb([(118, 150), (122, 184), (124, GROUND - 4)], [9.0, 6.2, 5.0]), depth=6, lift=-10)
    S.feat = "farpaw"
    paw(S, (126, GROUND - 3), (1, 0), lift=-9.5)

    # The body, one long torso from the rump to the deep chest under the mane; its back half goes
    # with the tail (Zosma on the back), its front with the heart. The back sags a little behind
    # the shoulders and rises again over the haunch.
    S.tag, S.feat = "tail|heart@88", "torso"
    S.shape([(42, 124), (50, 113), (62, 112), (74, 116), (88, 117), (108, 118), (120, 134), (124, 152),
             (114, 166), (96, 164), (78, 162), (58, 162), (42, 146)], depth=11, lift=0)
    S.tag, S.feat = "tail", "tail"
    figure_tail(S, [(44, 122), (36, 126), (31, 134), (28, 142), (27, 146)], denebola + v((0, 3)), lift=-2)

    # The near hind leg: the big thigh from the hip (Chertan on it) to the knee, the shin back to
    # the hock (iota, a cat's sharp heel), the foot down and forward to the paw (sigma).
    S.tag, S.feat = "haunch", "thigh"
    S.shape([(48, 136), (60, 130), (74, 132), (80, 148), (76, 166), (66, 172), (54, 164), (46, 150)], depth=12, lift=4)
    S.feat = "hindleg"
    S.shape(limb([(72, 166), (62, 176), iota + v((-2, 1)), (51, 196), sigma + v((1, -1))], [7.4, 6.0, 5.0, 4.4, 4.4]), depth=5, lift=3)
    S.feat = "paw"
    paw(S, (56, GROUND - 3), (1, 0), lift=3.5)

    # The near foreleg, raised mid-stride: the upper arm down from the shoulder, the forearm through
    # Regulus forward to the wrist, the paw (omicron) lifted, toes curled down.
    S.tag, S.feat = "heart", "foreleg"
    S.shape(limb([(106, 142), (110, 162), regulus, (132, 188), omicron + v((-3, -2))], [9.6, 8.2, 6.6, 5.2, 4.8]), depth=6, lift=6)
    S.feat = "paw"
    paw(S, omicron, (1, 0.5), lift=6.5)

    # The mane round the neck and over the shoulders (Algieba and zeta in it), behind the head.
    S.tag, S.feat = "mane", "mane"
    figure_mane(S, MANE, lift=10, size=7.0, root=(150, 116))

    # A ruff of mane under the jaw and down the throat, framing the face.
    S.feat = "beard"
    figure_mane(S, [(140, 132), (150, 137), (159, 139), (160, 147), (150, 153), (138, 147)], lift=14, size=5.0,
                seed=13, root=(152, 122))

    # The head in profile in front of the mane: the ear by mu, the eye under epsilon, the mouth at
    # lambda. One solid (no muzzle or chin of its own, so no inner walls): the face is read from
    # its silhouette and its marks.
    S.tag, S.feat = "head", "ear"
    S.shape(limb(FIG_EAR, [3.8, 3.0]), depth=2.5, lift=25)
    S.feat = "face"
    S.shape(FIG_FACE, depth=6, lift=26)


def figure_tail(S, points, tuft, lift):
    """The whole lion's tail: `tail`'s, its tuft a soft brush of hair drooping from the tail's end
    (a smooth teardrop, no spiky locks, so it can't pass for a star's burst), tagged as its own
    feature (it must read)."""
    S.shape(limb(points, list(np.linspace(2.4, 1.6, len(points)))), depth=2.5, lift=lift)
    tuft = v(tuft)
    S.mat, S.feat = "mane", "tuft"
    blob = [tuft + v((-1, -7)), tuft + v((4, -4)), tuft + v((5, 2)), tuft + v((2, 8)), tuft + v((-2, 10)),
            tuft + v((-5, 5)), tuft + v((-5, -2))]
    S.shape(blob, depth=4, lift=lift + 0.5)
    S.mat = "body"


def figure_mane(S, outline, lift, size=7.0, seed=5, root=None):
    """`mane` for the whole lion: the same domed mass ringed with locks, with half as many tufts
    over it (the mane must leave sky showing through, not read as a scribble)."""
    S.mat = "mane"
    locks(S, outline, size, lift - 1.0, seed=seed)
    S.shape(outline, depth=12, lift=lift)
    inside = aq.mask_of(outline)
    pts = [v(p) for p in outline]
    root = v(root) if root is not None else sum(pts) / len(pts)
    rng = np.random.default_rng(seed + 1)
    ys, xs = np.nonzero(inside)
    for k in rng.permutation(len(xs))[: max(4, len(xs) // 90)]:
        p = v((xs[k] + 0.5, ys[k] + 0.5))
        out = unit(p - root + rng.normal(0, 0.35, 2))
        bend = np.array([-out[1], out[0]]) * rng.normal(0, 2.0)
        length = size * (1.1 + 0.6 * rng.random())
        tip = p + out * length + bend
        strand = bezier(p - out * 2.0, p + out * length * 0.5 - bend, tip, 5)
        S.shape(limb(strand, list(np.linspace(size * 0.34, 0.6, len(strand)))), depth=2.0, lift=lift + 11.0 + rng.random() * 0.8)
    S.mat = "body"


# The whole lion's head (facing right; mu by the ear, epsilon on the brow, lambda at the mouth's
# corner): the forehead sloping to a heavy brow, the long straight bridge to a square muzzle with
# its nose pad at the top front corner, the muzzle's flat front down to the lip, the chin under it
# and the jaw back to the throat.
FIG_FACE = [(139, 97), (145, 96), (151, 98), (157, 102), (163, 106), (168, 109), (171, 111), (172, 115),
            (172, 120), (170, 123), (167, 125), (166, 129), (163, 134), (159, 137), (153, 138), (147, 136),
            (142, 131), (139, 122), (138, 108)]
FIG_EAR = [(140, 100), (137, 92)]


# The mane's outline (round the neck and over the shoulders).
MANE = [(92, 116), (96, 104), (106, 96), (120, 93), (132, 93), (140, 98), (142, 108), (146, 126),
        (150, 142), (140, 148), (126, 142), (114, 136), (102, 132), (94, 126)]


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


# --- the whole Leo, in the Stardust Myth style (tools/art/stardust.py) ------------------------

SEED = 11
LIGHT = sc.LIGHT
# Each landmark's size (StarMap.leo sizes): the stars' gaps and the preview's stars.
SIZES = ["S", "M", "S", "S", "B", "S", "B", "S", "M", "B", "M", "S", "S"]
# Leo's strings (StarMap.leo segments), for the preview.
SEGMENTS = [(0, 1), (1, 2), (2, 3), (3, 4), (4, 5), (5, 6), (6, 7), (4, 8), (8, 9), (9, 10), (10, 11), (11, 12)]

HEAD = ("ear", "face", "chin", "muzzle")
LIMBS = ("farhind", "farfore", "farpaw", "thigh", "hindleg", "foreleg", "paw")
HAIR = ("mane", "beard", "tuft")
# How much more of its outline each feature keeps: the head, the legs and the paws must read.
BIAS = {"ear": 0.9, "face": 0.9, "chin": 0.8, "muzzle": 0.9, "hindleg": 0.32, "foreleg": 0.32,
        "paw": 0.36, "farhind": 0.22, "farfore": 0.22, "farpaw": 0.30, "thigh": 0.22, "tail": 0.30,
        "tuft": 0.12, "mane": 0.50, "beard": 0.45, "torso": 0.0}
# How full each feature's nebula is: the mane a light veil of wisps, the torso the most hollow.
FILL = {"torso": 0.35, "thigh": 0.45, "hindleg": 0.7, "foreleg": 0.7, "farhind": 0.55, "farfore": 0.55,
        "face": 0.0, "ear": 0.5, "mane": 0.45, "beard": 0.5, "tuft": 0.8}
# Where one feature lies over another, its own edge is drawn: this many steps up (the legs over the
# body and each other, the head's jaw over the ruff), with this share of holes.
OVERLAP = {"head": (4, 0.0), "limb": (4, 0.15), "hair": (3, 0.45), "torso": (2, 0.5), "tail": (3, 0.1)}
# The head's own edge over the mane is drawn only round the face and the jaw (x >= HEAD_BACK or
# y >= JAW_TOP); the back of the head is a faint broken line the mane's locks spill over.
HEAD_BACK, JAW_TOP = 144, 128
# The face's marks: the eye (a dot in a small clear hollow, one step over the outline), the nose
# pad (a bright square at the muzzle's top front corner), the mouth's line back from the lip and
# the chin's under it.
EYE = [(151, 108), (152, 108)]
NOSE = [(168, 111), (169, 111), (170, 111), (168, 112), (169, 112), (170, 112), (169, 113)]
# The heavy brow over the eye (two rows), the bridge's ridge and the whisker dots on the muzzle.
BROW = [(145, 104), (146, 103), (147, 103), (148, 103), (149, 103), (150, 104), (151, 104), (152, 105),
        (146, 104), (147, 104), (148, 104), (149, 104)]
BRIDGE = [(156, 105), (158, 106), (160, 107), (162, 108)]
WHISKERS = [(163, 117), (165, 116), (164, 120), (166, 119)]
MOUTH = [(170, 122), (168, 123), (167, 124), (165, 124), (164, 125), (162, 125), (161, 126)]
CHIN = [(164, 129), (163, 130), (162, 131)]
# Each planted paw's middle on the ground (the far hind, the near hind, the far fore), for its toes.
PAWS = ((76, 211), (56, 211), (126, 211))
# The mane's ruff round the back of the head: locks of dust from just inside the head's edge
# flowing out over the mane, from the crown round the nape to the throat.
RUFF_CENTRE = (153, 117)
RUFF_ANGLES = (-160, -145, -130, -112, 172, 160, 147, 134, 121, 108, 96)
# The mythic flourish, the Lion of Summer: a sunburst of stardust rays fanning out of the mane's
# crest (degrees from RUFF_CENTRE, 0 = east, -90 = up), each ray's length (px).
RAYS = ((-175, 20), (-165, 27), (-155, 24), (-145, 12), (-135, 8))


def group(feat: str) -> str:
    if feat in HEAD:
        return "head"
    if feat in LIMBS:
        return "limb"
    if feat in HAIR:
        return "hair"
    return feat


def feature_map(S) -> np.ndarray:
    return np.array(S.feats + [""], dtype=object)[S.owner]


def part_map(S) -> np.ndarray:
    """Each covered pixel's part, from the solid on top ("" off the form)."""
    names = np.array(S.tags + [""], dtype=object)[S.owner]
    out = np.full((H, W), "", dtype=object)
    for name in set(S.tags):
        m = names == name
        if "|" in name:
            parts, at = name.split("@")
            left, right = parts.split("|")
            out[m & (sd.xs < int(at))] = left
            out[m & (sd.xs >= int(at))] = right
        else:
            out[m] = name
    return out


def overlap_edges(S, feats, inside) -> np.ndarray:
    """The pixels of a feature that lie over another feature's pixel next to them: its own edge
    where it overlaps (a leg over the body, the head over the mane)."""
    over = np.zeros((H, W), bool)
    for dy, dx in sd.FOUR:
        nf, nz, ni = sd.shift(feats, dy, dx), sd.shift(S.z, dy, dx), sd.shift(inside, dy, dx)
        over |= inside & ni & (nf != feats) & (S.z > nz + 0.6)
    return over


def hair_strokes(dust, inside, mask, root, count, seed, length=(6.0, 12.0)):
    """The mane's locks as strokes of dust: `count` tapering, gently bent strands from inside
    `mask`, each flowing away from `root` (where the head sits), 3 steps up at the root fading to
    2, a pale speck at some tips. Returns the strokes' pixels."""
    rng = np.random.default_rng(seed)
    ys_, xs_ = np.nonzero(mask)
    mine = np.zeros((H, W), bool)
    root = v(root)
    for k in rng.permutation(len(xs_))[:count]:
        p = v((xs_[k] + 0.5, ys_[k] + 0.5))
        out = unit(unit(p - root) + rng.normal(0, 0.35, 2))
        side = np.array([-out[1], out[0]])
        n = length[0] + (length[1] - length[0]) * rng.random()
        bend = rng.normal(0, 3.0)
        last = None
        for j in range(int(n * 1.6)):
            t = j / (n * 1.6)
            q = p + out * n * t + side * bend * t * t
            x, y = int(round(q[0] - 0.5)), int(round(q[1] - 0.5))
            if not (0 <= x < W and 0 <= y < H) or (x, y) == last:
                continue
            last = (x, y)
            if sd.hsh(x, y, 61) < 0.05 + 0.3 * t * t:
                continue
            dust.put_px(x, y, 3 if t < 0.55 else 2)
            mine[y, x] = True
        if last and rng.random() < 0.35 and not dust.fixed[last[1], last[0]]:
            dust.fixed[last[1], last[0]] = "N8" if rng.random() < 0.6 else "N7"
            mine[last[1], last[0]] = True
    return mine


def sun_rays(dust, form):
    """The mythic flourish, the Lion of Summer: a sunburst of stardust rays fanning out of the mane's
    crest. Each ray leaves the form's edge along its angle from RUFF_CENTRE as a broken core 5 steps
    up fading to 3 (thicker at its root, a few pale specks along it), with drifting dust round it and a pale speck at its tip; nothing near a star or
    in the Sun's zone. Returns the rays' pixels (for the pieces)."""
    mine = np.zeros((H, W), bool)
    near_star = np.zeros((H, W), bool)
    for lx, ly in L:
        near_star |= (sd.xs - lx) ** 2 + (sd.ys - ly) ** 2 <= 36
    c = v(RUFF_CENTRE)
    for k, (angle, length) in enumerate(RAYS):
        d = np.array([np.cos(np.radians(angle)), np.sin(np.radians(angle))])
        side = np.array([-d[1], d[0]])
        r = 0.0
        while form[int(c[1] + d[1] * r), int(c[0] + d[0] * r)] or r < 4:
            r += 0.5
        start = c + d * (r - 1.0)
        last = None
        for j in range(int(length * 2)):
            t = j / (length * 2)
            q = start + d * length * t + side * 0.8 * np.sin(t * 3.0 + k)
            x, y = int(round(q[0])), int(round(q[1]))
            if (x, y) == last or not (0 <= x < W and sd.SUN_BOTTOM < y < H) or near_star[y, x]:
                continue
            last = (x, y)
            if sd.hsh(x, y, 91) < 0.08 + 0.45 * t:
                continue
            dust.put_px(x, y, 5 if t < 0.3 else (4 if t < 0.65 else 3))
            mine[y, x] = True
            # A thicker root, so each ray reads as leaving the mane.
            if t < 0.25:
                X, Y = int(round(q[0] + side[0])), int(round(q[1] + side[1]))
                if not near_star[Y, X] and Y > sd.SUN_BOTTOM:
                    dust.put_px(X, Y, 3)
                    mine[Y, X] = True
            elif sd.hsh(x, y, 99) < 0.22 and not near_star[y, x]:
                dust.fixed[y, x] = "D0" if sd.hsh(x, y, 100) < 0.4 else "N8"
            # Dust drifting off the ray, wider towards its end.
            for s in (-1, 1):
                off = q + side * s * (1.5 + 2.5 * t) + d * (sd.hsh(x, y, 92 + s) - 0.5) * 2
                X, Y = int(round(off[0])), int(round(off[1]))
                if 0 <= X < W and sd.SUN_BOTTOM < Y < H and not near_star[Y, X] and sd.hsh(X, Y, 93) < 0.35:
                    if sd.hsh(X, Y, 94) < 0.18:
                        dust.fixed[Y, X] = "N8" if sd.hsh(X, Y, 95) < 0.6 else "N7"
                    else:
                        dust.put_px(X, Y, 1 if sd.hsh(X, Y, 94) < 0.6 else 2)
                    mine[Y, X] = True
        if last and not near_star[last[1], last[0]]:
            dust.fixed[last[1], last[0]] = "N8"
    return mine


def ruff_strokes(dust, head):
    """The mane's ruff round the back of the head: locks of dust from 2 px inside the head's edge
    flowing out (away from RUFF_CENTRE), 3 steps up fading to 2, so the mane spills over the nape
    and the face sits inside it. Returns the strokes' pixels."""
    mine = np.zeros((H, W), bool)
    c = v(RUFF_CENTRE)
    for k, angle in enumerate(RUFF_ANGLES):
        d = np.array([np.cos(np.radians(angle)), np.sin(np.radians(angle))])
        side = np.array([-d[1], d[0]])
        r = 0.0
        while head[int(c[1] + d[1] * r), int(c[0] + d[0] * r)]:
            r += 0.5
        start = c + d * (r - 2.0)
        n = 8.0 + 5.0 * sd.hsh(k, 7, 95)
        bend = (sd.hsh(k, 3, 96) - 0.5) * 4.0
        last = None
        for j in range(int(n * 1.6)):
            t = j / (n * 1.6)
            q = start + d * n * t + side * bend * t * t
            x, y = int(round(q[0])), int(round(q[1]))
            if (x, y) == last:
                continue
            last = (x, y)
            if sd.hsh(x, y, 97) < 0.05 + 0.3 * t * t:
                continue
            dust.fixed[y, x] = ""
            dust.level[y, x] = max(dust.level[y, x], 4 if t < 0.5 else 3)
            mine[y, x] = True
    return mine


def break_runs(dust, keep, minlen=7, chunk=5):
    """Wobbles the drawn lines that run ruler-straight: along every horizontal or vertical run of
    `minlen` or more line pixels (2+ steps up, or a speck), every `chunk`-th pair of pixels steps
    1 px aside (to an empty side), or is dropped where both sides are taken. `keep` is never
    touched (the face)."""
    line = (dust.level >= 2) | (dust.fixed != "")
    for vertical in (False, True):
        lv = line.T if vertical else line
        rows, cols = lv.shape
        for r in range(rows):
            c = 0
            while c < cols:
                if not lv[r, c]:
                    c += 1
                    continue
                s = c
                while c < cols and lv[r, c]:
                    c += 1
                if c - s < minlen:
                    continue
                for a in range(s + 3, c - 2, chunk):
                    for b in (a, a + 1):
                        y, x = (b, r) if vertical else (r, b)
                        if keep[y, x]:
                            continue
                        for o in (1, -1) if sd.hsh(x, y, 98) < 0.5 else (-1, 1):
                            Y, X = (y, x + o) if vertical else (y + o, x)
                            if 0 <= X < W and 0 <= Y < H and dust.level[Y, X] < 1 and not dust.fixed[Y, X]:
                                dust.level[Y, X], dust.fixed[Y, X] = dust.level[y, x], dust.fixed[y, x]
                                break
                        dust.level[y, x], dust.fixed[y, x] = -1, ""


def toes(dust, inside, paws):
    """Toe notches on each planted paw: the sole's edge broken and a short crease rising from each
    break, between the front toes (each paw by its middle on the ground, facing right)."""
    for px, py in paws:
        for dx in (1, 4, 7):
            x = px + dx
            y = py + 6
            while y > py and not inside[y, x]:
                y -= 1
            dust.level[y, x] = -1
            dust.fixed[y, x] = ""
            dust.level[y - 1, x] = max(dust.level[y - 1, x], 4)
            dust.level[y - 2, x] = max(dust.level[y - 2, x], 3)


def head_zone(groups):
    """The head and a 1 px margin round it."""
    return sd.grow(groups == "head", 1)


def paint_leo(S):
    """The whole Leo over its form. Returns the painting and the marks off the form (the rays and
    the hair strokes, for the pieces)."""
    rng = np.random.default_rng(SEED)
    inside = S.z >= 0.0
    lit = np.clip(S.n @ LIGHT, 0.0, 1.0)
    facing = S.n[..., 0] * LIGHT[0] + S.n[..., 1] * LIGHT[1]
    feats = feature_map(S)
    groups = np.vectorize(group, otypes=[object])(feats)
    head = groups == "head"
    dust = sd.Dust()
    edge = sd.edge_of(inside)
    dist = sd.distance_inside(inside)

    contour = sd.broken_contour(dust, rng, edge, facing, lit, sd.contour_bias(facing, BIAS, feats))
    # The lit side's outline (the mane's crest, the back, the legs) at the brightest steps, as the
    # Scorpio's is.
    dust.put(contour & (facing > 0.05) & (lit > 0.35), 5)
    dust.put(contour & (groups == "limb") & (facing > -0.2), 5)
    # The head's silhouette whole and at full strength, its shadow side too: the face must read.
    dust.put(edge & head, 5)
    over = overlap_edges(S, groups, inside) & ~edge
    front = (sd.xs >= HEAD_BACK) | (sd.ys >= JAW_TOP)
    for g, (steps, share) in OVERLAP.items():
        holes = np.vectorize(lambda x, y: sd.hsh(x, y, 51) < share)(sd.xs, sd.ys)
        mine = over & (groups == g) & ~holes
        if g == "head":
            mine &= front
        dust.put(mine, steps)
    # The back of the head: a broken line the ruff's locks cross, so the face sits in the mane.
    nape = np.vectorize(lambda x, y: sd.hsh(x, y, 52) < 0.45)(sd.xs, sd.ys)
    dust.put(over & head & ~front & ~nape, 4)
    # The ear: its own round rim over the face and the mane, so it reads as an ear on the crown.
    ear = feats == "ear"
    rim = ear & np.any([~sd.shift(ear, dy, dx) for dy, dx in sd.FOUR], axis=0) & ~edge
    dust.put(rim & (sd.ys < 99), 4)
    fill = np.ones((H, W))
    for f, k in FILL.items():
        fill[feats == f] = k
    sd.nebula(dust, rng, inside, dist, lit, fill)
    out_d = sd.outer_haze(dust, rng, inside)
    rays = sun_rays(dust, inside)
    sd.specks(dust, inside, dist, out_d, lit)
    hair = hair_strokes(dust, inside, (feats == "mane") & (dist > 2), (150, 116), 22, SEED + 1, (8.0, 13.0))
    hair |= hair_strokes(dust, inside, (feats == "beard") & (dist > 1), (152, 122), 7, SEED + 2, (4.0, 7.0))
    # The tail tuft's hair: a few short locks hanging out of it, so it reads as a brush, not a ring.
    hair |= hair_strokes(dust, inside, (feats == "tuft") & (dist > 1), (L[9][0] + 3, L[9][1] - 8), 7, SEED + 3, (7.0, 10.0))
    sd.rose_glints(dust, contour, lit, exclude=head)

    # The mane's ruff: its scalloped edge against the sky drawn almost whole, so the mass reads.
    ruff = edge & (groups == "hair")
    dust.put(ruff & np.vectorize(lambda x, y: sd.hsh(x, y, 81) > 0.2)(sd.xs, sd.ys), 4)
    # No pale specks on the face: its three stars sit close together there.
    dust.fixed[head_zone(groups)] = ""
    # A dark gap just outside the jaw where it lies over the ruff, so the face stands clear of it.
    ring = np.any([sd.shift(head, dy, dx) for dy, dx in sd.FOUR], axis=0) & ~head & (groups == "hair") & ~edge
    dust.clear(ring & (sd.ys >= JAW_TOP))
    hair |= ruff_strokes(dust, head)
    # The face: the eye a bright dot in a small clear hollow under the heavy brow, the nose pad,
    # the bridge, the mouth's and the chin's lines, the whisker dots.
    for ex, ey in EYE:
        dust.clear(((sd.xs - ex) ** 2 + (sd.ys - ey) ** 2 <= 5) & ~edge)
    marks = np.zeros((H, W), bool)
    for pts, steps in ((EYE, 6), (NOSE, 5), (BROW, 4), (BRIDGE, 3), (WHISKERS, 3), (MOUTH, 4), (CHIN, 3)):
        for x, y in pts:
            dust.fixed[y, x] = ""
            dust.level[y, x] = max(dust.level[y, x], steps)
            marks[y, x] = True
    toes(dust, inside, PAWS)
    break_runs(dust, marks | (head & front))
    # Each star in a small clear gap (nothing within 2 px), and no pale speck or glint within 7 px
    # of any star: a pale dot there could pass for one.
    sd.star_gaps(dust, L, SIZES, hollow=2)
    for lx, ly in L:
        dust.fixed[(sd.xs - lx) ** 2 + (sd.ys - ly) ** 2 <= 49] = ""
    return sd.sun_clamp(sd.resolve(dust, sd.sky_index())), rays | hair


def part_tags(S, img, trail) -> np.ndarray:
    """Each painted pixel's part: the part of the solid under it, else the mane's (its rays and locks), else
    the nearest tagged pixel's (the haze and the specks off the form). Every star lies on its own
    part's solid."""
    tags = part_map(S)
    for star, part in STAR_PARTS.items():
        x, y = L[star]
        assert tags[y, x] == part, f"landmark {star} ({part}) sits on the {tags[y, x] or 'sky'}"
    tags[trail & (tags == "")] = "mane"
    return sd.spread_tags(tags, img[..., 3] > 0)


class Shapes(aq.Shapes):
    """The Aquarius's shapes, with marks drawn over the shading (the lion's face)."""

    def __init__(self):
        super().__init__()
        self.marks = []
        # The figure's anatomy (by solid id): which feature each solid draws, for the stardust.
        self.feat = ""
        self.feats = []

    def _put(self, *args, **kwargs):
        self.feats.append(self.feat)
        super()._put(*args, **kwargs)


def paint(S):
    img = aq.shade(S)
    aq.stardust(img)
    for (x, y), colour in S.marks:
        if 0 <= x < W and 0 <= y < H and img[y, x, 3]:
            img[y, x, :3] = RGB[colour]
    return img


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--preview", type=Path, help="also write the figure over the sky, x3, here")
    args = parser.parse_args()
    ART.mkdir(parents=True, exist_ok=True)
    S = Shapes()
    build_figure(S)
    img, trail = paint_leo(S)
    used = sd.check(img)
    print(f"figure: {sum(used.values())} px, {used}")
    sd.save(img, ART / "leo_figure.png")
    for part, piece in sd.pieces(img, part_tags(S, img, trail), PARTS).items():
        sd.save(piece, ART / f"leo_piece_{part}.png")
    if args.preview:
        sd.preview(img, L, SIZES, SEGMENTS).save(args.preview)
        print(f"wrote {args.preview}")
    for part, landmarks in stage_landmarks().items():
        stage = Shapes()
        STAGE_BUILDERS[part](stage, landmarks)
        painting = paint(stage)
        for x, y in landmarks:
            assert stage.owner[y, x] >= 0, f"{part}: landmark ({x}, {y}) sits on nothing"
        sc.save(painting, ART / f"leo_part_{part}.png")


if __name__ == "__main__":
    main()
