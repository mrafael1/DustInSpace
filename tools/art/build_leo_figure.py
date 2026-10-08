"""Builds the painted Leo (chapter 3's reward) and its pieces, in assets/art/:

  leo_figure.png         the whole lion, the final's reward and the chart's
  leo_piece_<part>.png   the same painting cut into the chapter's five parts (tail, haunch, heart,
                         mane, head), in the same full-screen home layout: the chapter chart
                         assembles them as parts are won
  leo_part_<part>.png    each part stage's own painting, the same body part fitted to that stage's
                         own landmarks (game/core/star_map.gd, read from the source), shown when the
                         stage is complete

Drawn exactly as the Aquarius is (tools/art/build_aquarius_figure.py): smooth outlines at native
size, each given roundness from its own shape, then lit and shaded as the Scorpio is (light from
the top left, the N ramp in flat bands with a Bayer checker only along each seam, dark creases where
one part lies over another, a rose rim on lit edges, stardust specks, a thin aura), so the three
chapters match.

The lion walks to the right, east to the left as on the sky: its stars are points on the body. The
tail tuft is Denebola, the back Zosma, the thigh Chertan, the hock iota and the hind paw sigma; the
shaggy mane carries Algieba and zeta; the head in profile has mu by the ear, epsilon on the brow
over the eye and lambda at the mouth; the chest is eta, the raised foreleg Regulus and its paw
omicron, lifted mid-stride.
No colour outside the Stellar Sun palette; every pixel opaque or empty.

Run: python tools/art/build_leo_figure.py   (needs Pillow and numpy)
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
    mouth, brow, crown, zeta, algieba, eta, regulus, omicron, zosma, denebola, chertan, iota, sigma = map(v, L)

    # The far legs, behind everything: a hind leg planted under the hip, a foreleg under the chest.
    S.tag = "haunch"
    S.shape(limb([(76, 140), (84, 172), (72, 192), (74, GROUND - 4)], [10.0, 6.6, 5.2, 4.6]), depth=6, lift=-10)
    paw(S, (76, GROUND - 3), (1, 0), lift=-9.5)
    S.tag = "heart"
    S.shape(limb([(118, 150), (122, 184), (124, GROUND - 4)], [9.0, 6.2, 5.0]), depth=6, lift=-10)
    paw(S, (126, GROUND - 3), (1, 0), lift=-9.5)

    # The body, one long torso from the rump to the deep chest under the mane; its back half goes
    # with the tail (Zosma on the back), its front with the heart.
    S.tag = "tail|heart@88"
    S.shape([(42, 124), (52, 114), (70, 113), (90, 115), (108, 118), (120, 134), (124, 152), (114, 166),
             (96, 164), (78, 162), (58, 162), (42, 146)], depth=11, lift=0)
    S.tag = "tail"
    tail(S, [(44, 122), (36, 126), (31, 134), (28, 142), (27, 146)], denebola + v((0, 3)), lift=-2)

    # The near hind leg: the big thigh from the hip (Chertan on it) to the knee, the shin back to
    # the hock (iota), the foot down to the paw (sigma).
    S.tag = "haunch"
    S.shape([(48, 136), (60, 130), (74, 132), (80, 148), (76, 166), (66, 172), (54, 164), (46, 150)], depth=12, lift=4)
    S.shape(limb([(72, 166), (60, 178), iota, (52, 200), sigma + v((0, -1))], [7.4, 6.2, 5.2, 4.6, 4.4]), depth=5, lift=3)
    paw(S, (56, GROUND - 3), (1, 0), lift=3.5)

    # The near foreleg, raised mid-stride: the upper arm down from the shoulder, the forearm through
    # Regulus forward to the wrist, the paw (omicron) lifted, toes curled down.
    S.tag = "heart"
    S.shape(limb([(106, 142), (110, 162), regulus, (132, 188), omicron + v((-3, -2))], [9.6, 8.2, 6.6, 5.2, 4.8]), depth=6, lift=6)
    paw(S, omicron, (1, 0.5), lift=6.5)

    # The mane round the neck and over the shoulders (Algieba and zeta in it), behind the head.
    S.tag = "mane"
    mane(S, [(92, 116), (96, 98), (106, 86), (120, 80), (132, 82), (140, 92), (142, 108), (146, 126),
             (150, 142), (140, 148), (126, 142), (114, 136), (102, 132), (94, 126)], lift=10, size=8.0,
         root=(150, 116))

    # A beard of mane under the jaw, framing the face.
    mane(S, [(140, 134), (150, 138), (158, 140), (158, 148), (148, 152), (138, 146)], lift=14, size=5.0,
         seed=13, root=(152, 122))

    # The head in profile in front of the mane: the ear by mu, the eye under epsilon, the mouth at
    # lambda.
    S.tag = "head"
    lion_head(S, crown, brow, mouth, lift=26)


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


# --- pieces --------------------------------------------------------------------------------

def split_tag(tag, x):
    """A solid shared by two parts ("left|right@x": the torso) goes to the left one before column x."""
    if "|" not in tag:
        return tag
    parts, at = tag.split("@")
    left, right = parts.split("|")
    return left if x < int(at) else right


def pieces(S, img):
    """The whole cut by part, as the Scorpio's and the Aquarius's: each pixel with its part's
    solid, each aura pixel with the body pixel beside it. Every star must lie on its own part."""
    for star, part in STAR_PARTS.items():
        x, y = L[star]
        owner = S.owner[y, x]
        assert owner >= 0, f"landmark {star} sits on nothing"
        assert split_tag(S.tags[owner], x) == part, f"landmark {star} ({part}) sits on the {S.tags[owner]}"
    tags = np.full((H, W), "", dtype=object)
    inside = S.z >= 0.0
    for y, x in zip(*np.nonzero(inside)):
        tags[y, x] = split_tag(S.tags[S.owner[y, x]], x)
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
    S = Shapes()
    build_figure(S)
    img = paint(S)
    sc.save(img, ART / "leo_figure.png")
    for part, piece in pieces(S, img).items():
        sc.save(piece, ART / f"leo_piece_{part}.png")
    for part, landmarks in stage_landmarks().items():
        stage = Shapes()
        STAGE_BUILDERS[part](stage, landmarks)
        painting = paint(stage)
        for x, y in landmarks:
            assert stage.owner[y, x] >= 0, f"{part}: landmark ({x}, {y}) sits on nothing"
        sc.save(painting, ART / f"leo_part_{part}.png")


if __name__ == "__main__":
    main()
