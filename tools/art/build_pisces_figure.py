"""Builds the Pisces's final painting (the chapter's reward), in assets/art/:

  pisces_figure.png          the whole Pisces, the final stage's reward (laid over StarMap.pisces())
  pisces_piece_<part>.png    the same painting cut into the chapter's five parts (circlet,
                             west_cord, knot, east_cord, north_fish; game/core/chapter_def.gd), in
                             the same full-screen home layout: the chapter chart shows the won ones
                             dormant, then the whole figure once the final is won
  pisces_part_<part>.png     each part stage's own painting, in the same clean-line style, the
                             final's fish, ribbons and bow re-posed to each stage's stars
                             (tools/art/pisces_part_paintings.py, run from here)

The whole Pisces is drawn in the clean-line semi-hollow style (tools/art/clean_line.py and
stardust.py), pose 1, "Urania". The western fish lies flat facing right (west) with gamma as its
eye, a dorsal sail over theta
(rooted on the back, one outline with the body), a short gill arc behind the eye (bowing toward the
tail, clear of the back and the belly), a small teardrop pectoral behind the gill, a closed pelvic
fin under kappa, a mouth notch at the snout, and its forked tail flicked up and left from a tie
band at omega. The northern fish stands upright facing up and right with tau as its eye, a
tapered snout with a mouth notch, a short gill arc behind the eye (from the belly edge, stopping
short of the back), one swept-back teardrop pectoral lying along the belly, a long low sail
dorsal on its back (left flank), a pinched tail root under a narrow tie band and a short two-lobed
tail forked out to the right. From each band a twisted ribbon (lens panels meeting at sharp X
crossings, lit faces dense and back faces sparse) runs to a bow at Alrescha: a round knot, two
loops out to the sides and two narrow tapered tails.

The pieces partition the whole: each pixel goes with the part of the shape under it, else with the
nearest tagged pixel; each star's own pixel goes with its part.

Every image is the full 180x320 game screen (transparent outside the figure), in home layout.

Run: python tools/art/build_pisces_figure.py [--preview out.png]   (needs Pillow and numpy)
"""

import argparse
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import clean_line  # noqa: E402
from clean_line import Axis, path_of  # noqa: E402
import stardust as sd  # noqa: E402
import pisces_part_paintings  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / "assets" / "art"
OUT = ART / "pisces_figure.png"
S = clean_line.S
SEED = 11
LIGHT = np.array([-0.55, -0.65, 0.52])

# StarMap.pisces() landmarks (game/core/star_map.gd): 0 gamma, 1 theta, 2 kappa, 3 lambda, 4 iota,
# 5 omega, 6 epsilon, 7 Alrescha, 8 xi, 9 omicron, 10 eta, 11 phi, 12 upsilon, 13 tau.
L = [(160, 146), (140, 128), (150, 170), (124, 170), (118, 144), (94, 158), (70, 174), (28, 214),
     (52, 196), (14, 188), (22, 160), (34, 134), (22, 110), (46, 96)]
SIZES = ["B", "M", "S", "M", "M", "M", "M", "B", "S", "M", "B", "S", "S", "S"]
SEGMENTS = [(1, 4), (4, 3), (3, 2), (2, 0), (4, 5), (5, 6), (6, 8), (8, 7), (7, 9), (9, 10),
            (10, 11), (11, 12), (12, 13)]
STAR_PARTS = {0: "circlet", 1: "circlet", 2: "circlet", 3: "circlet", 4: "west_cord", 5: "west_cord",
              6: "west_cord", 7: "knot", 8: "knot", 9: "east_cord", 10: "east_cord",
              11: "north_fish", 12: "north_fish", 13: "north_fish"}
PARTS = ("circlet", "west_cord", "knot", "east_cord", "north_fish")

# Ribbon twist: each panel is a lens (both edges sin-shaped, zero at the twists), so the edges of
# neighbouring panels cross in a sharp X; faces alternate dense (lit) and sparse (back).
X_ARM = 2.6      # how far each edge's stroke runs either side of a crossing, game px
LIT_FILL = 0.75  # extra Bayer fill on a lit face
BACK_KEEP = 0.10  # the share of stardust a back face keeps
# The big fish bodies: past HOLLOW_FROM px inside their edge the stardust thins to HOLLOW_CORE.
HOLLOW_FROM, HOLLOW_RAMP, HOLLOW_CORE = 3.0, 4.0, 0.10
HOLLOW_GROUPS = ("w_body", "n_body")


# ---- Outline helpers (game px in, 4x points out) ----

def smooth(points, sharp=(), n=14):
    """A closed Catmull-Rom outline through `points` (game px) as 4x points; the vertices listed
    in `sharp` are corners (each span leaves and reaches them straight)."""
    pts = [np.array(p, float) * S for p in points]
    k = len(pts)
    out = []
    for i in range(k):
        p1, p2 = pts[i], pts[(i + 1) % k]
        p0, p3 = pts[i - 1], pts[(i + 2) % k]
        if i in sharp:
            p0 = p1 - (p2 - p1)
        if (i + 1) % k in sharp:
            p3 = p2 + (p2 - p1)
        for t in np.linspace(0, 1, n, endpoint=False):
            t2, t3 = t * t, t * t * t
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2
                              + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    return out


def clip(poly, g, boundary, samples=24):
    """The part of the closed 4x polygon `poly` where g(p) >= 0, closed along `boundary(a, b)`
    (4x points from the exit crossing a back to the entry crossing b). Assumes one inside run."""
    P = [np.array(p, float) for p in poly]
    v = [g(p) for p in P]
    k = len(P)
    start = next(i for i in range(k) if v[i] < 0)
    run, entry, exit_ = [], None, None
    for j in range(1, k + 1):
        i0, i1 = (start + j - 1) % k, (start + j) % k
        a, b = v[i0], v[i1]
        if a < 0 <= b:
            entry = P[i0] + (P[i1] - P[i0]) * (a / (a - b))
            run.append(entry)
        if b >= 0:
            run.append(P[i1])
        if a >= 0 > b:
            exit_ = P[i0] + (P[i1] - P[i0]) * (a / (a - b))
            run.append(exit_)
    return run + boundary(exit_, entry)


def curve_x(xf):
    """A boundary x = xf(y) (game px), walked in y from the exit to the entry crossing."""
    def walk(a, b):
        return [np.array([xf(y / S) * S, y]) for y in np.linspace(a[1], b[1], 24)[1:-1]]
    return walk


def ring(c, r, n=32, ry=None):
    ry = r if ry is None else ry
    return [(np.array(c, float) + np.array([r * math.cos(a), ry * math.sin(a)])) * S
            for a in np.linspace(0, 2 * math.pi, n, endpoint=False)]


def open_path(pts):
    """An open polyline (game px) as an SVG path in 4x space."""
    q = [(round(float(x) * S + S / 2, 1), round(float(y) * S + S / 2, 1)) for x, y in pts]
    return "M %s %s " % q[0] + " ".join("L %s %s" % p for p in q[1:])


def arc_in(body4, pts):
    """The run of `pts` (game px) that lies inside the 1x fill of the 4x outline `body4`: a gill
    arc that ends on the body's edge, never past it."""
    inside = clean_line.down(clean_line.fill_4x(path_of(body4)))
    keep = [p for p in pts if inside[int(round(p[1])), int(round(p[0]))]]
    return keep


def _edge(hw, u):
    """A lens panel edge's half-width at u in [0, 1]: zero at both twists."""
    return hw * math.sin(math.pi * u)


def ribbon(spine, panels, name, hidden=()):
    """A twisted ribbon along `spine`: one closed lens panel per (s0, s1, half-width, part)
    (arclengths and widths in game px). Each edge's sign flips at every twist, so the left edge of
    one panel runs straight on into the right edge of the next and the two edges cross in a sharp X
    (no neck, no gap). A short 1 px stroke carries each edge through the crossing so the ribbon
    stays one unbroken line (except at the twists listed in `hidden`, under a band or the knot).
    Returns the shapes, the strokes and each panel's face ("lit" or "back")."""
    ax = Axis([np.array(p, float) * S for p in spine])
    shapes, strokes, faces = [], [], {}

    def pt(s, w):
        c, _, nrm = ax.frame(s * S)
        return c + nrm * w * S

    for k, (s0, s1, hw, part) in enumerate(panels):
        us = np.linspace(0, 1, 40)
        left = [pt(s0 + u * (s1 - s0), _edge(hw, u)) for u in us]
        right = [pt(s0 + u * (s1 - s0), -_edge(hw, u)) for u in us]
        g = f"{name}{k}"
        shapes.append({"name": g, "part": part, "group": g, "d": path_of(left + right[::-1][1:-1])})
        faces[g] = "lit" if k % 2 == 0 else "back"
    for k in range(len(panels) - 1):
        if k in hidden:
            continue
        (a0, a1, ahw, part), (b0, b1, bhw, _) = panels[k], panels[k + 1]
        ua, ub = 1 - X_ARM / (a1 - a0), X_ARM / (b1 - b0)
        for sign in (1, -1):
            line = [pt(a0 + u * (a1 - a0), sign * _edge(ahw, u)) for u in np.linspace(ua, 1, 6)]
            line += [pt(b0 + u * (b1 - b0), -sign * _edge(bhw, u)) for u in np.linspace(0, ub, 6)[1:]]
            pts = [(round(float(x), 1), round(float(y), 1)) for x, y in line]
            d = "M %s %s " % pts[0] + " ".join("L %s %s" % q for q in pts[1:])
            strokes.append({"name": f"{name}x{k}{sign}", "part": part, "d": d})
    return shapes, strokes, faces


def arclength_of(spine, p):
    ax = Axis([np.array(q, float) * S for q in spine])
    d = np.linalg.norm(ax.p - np.array(p, float) * S, axis=1)
    return float(ax.s[d.argmin()]) / S, ax.L / S


def shape(name, part, pts, group=None):
    return {"name": name, "part": part, "group": group or name, "d": path_of(pts)}


# ---- The western fish ----

# The body, snout first: upper jaw (174,150), down the back, round the belly, to the lower jaw
# (172,156) and the mouth notch (170,153) between them.
W_BODY = [(174, 150), (165, 136), (152, 126), (137, 121), (122, 125), (108, 136), (98, 147),
          (98, 164), (110, 172), (128, 177), (148, 177), (160, 172), (167, 164), (172, 157), (169, 153)]
W_SHARP = (0, 13, 14)
# The gill: a short arc behind the eye, bowing 6 px toward the tail, from y 135 to y 167 (clear of
# the back and the belly lines). The hidden seam between the Circlet and the West Cord.
W_GILL = lambda y: 155 - 6 * (1 - ((y - 151) / 16) ** 2)  # noqa: E731
W_SEAM = lambda y: 132 - 16 * (y - 120) / 60  # noqa: E731


def west_fish():
    body = smooth(W_BODY, W_SHARP)
    front = clip(body, lambda p: p[0] / S - W_SEAM(p[1] / S), curve_x(W_SEAM))
    # The forked tail: the long upper lobe flicked up-left, the short lower lobe lifted clear of
    # the ribbon (its tip at y 159).
    tail = smooth([(100, 152), (86, 140), (74, 131), (78, 143), (85, 151), (79, 155), (73, 159),
                   (89, 160), (100, 160)], (2, 4, 6))
    # The dorsal sail, raked back, rooted on the back line from (147,124) to (127,124) and merged
    # with the body (one outline, no doubled edge): its trailing edge meets the back in a notch.
    dorsal = smooth([(147, 124), (138, 114), (123, 103), (124, 111), (127, 119), (128, 124), (138, 130)],
                    (2, 5))
    # The pelvic fin: a closed triangle under kappa, rooted in the belly and swept back to (143,186).
    pelvic = smooth([(158, 172), (147, 173), (143, 186), (149, 183), (155, 179)], (2,))
    anal = smooth([(118, 173), (113, 179), (106, 184), (106, 177), (104, 168)], (2,))
    # The pectoral: a small closed teardrop on the flank behind the gill (clear of it), its round
    # root up by the gill and its point swept back and down.
    pector = smooth([(143, 150), (144, 153), (139, 158), (128, 164), (135, 155), (139, 151)], (3,), 10)
    band = smooth([(90, 145), (95, 144), (99, 146), (99, 168), (95, 170), (90, 168)], (), 10)
    ys = np.linspace(135, 167, 80)
    gill = {"name": "w_gill", "part": "circlet",
            "d": open_path([(W_GILL(y), y) for y in ys])}
    return {
        "tail": [shape("w_tail", "west_cord", tail)],
        "fins": [shape("w_pelvic", "circlet", pelvic), shape("w_anal", "west_cord", anal)],
        "body": [shape("w_dorsal", "circlet", dorsal, "w_body"),
                 shape("w_body", "west_cord", body, "w_body"),
                 shape("w_front", "circlet", front, "w_body")],
        "head": [shape("w_pector", "circlet", pector), shape("w_eye", "circlet", ring(L[0], 6.2))],
        "band": [shape("w_band", "west_cord", band)],
        "strokes": [gill],
    }


# ---- The northern fish ----

# Snout first: the upper jaw (47,81), the mouth notch (50,86), the lower jaw (55,85); then the
# belly (right) side down, pinching in a concave curve to the tail root under the band, and the
# back (left) side up to the forehead (40,84).
N_BODY = [(48, 82), (50, 87), (56, 86), (58, 93), (57, 103), (52, 116), (45, 127), (40.5, 135),
          (39.5, 141), (39.5, 147), (28.5, 147), (28.5, 141), (26, 135), (19, 126), (15.5, 115),
          (17, 104), (25, 96), (34, 90), (42, 85)]
N_SHARP = (0, 1, 2)
# The gill: an arc round tau's eye (radius 11), bowing down toward the tail, from the belly edge
# to (36,98), well short of the back line.
N_GILL_C, N_GILL_R, N_GILL_A = (47, 95), 11.0, (-8, 166)


def north_fish():
    body = smooth(N_BODY, N_SHARP)
    # The tail: from the root under the band, two lobes forked out to the right and a little down
    # (upper tip (53,150), notch (44,157), lower tip (50,166)).
    tail = smooth([(30, 146), (38, 146), (45, 148), (53, 150), (44, 157), (50, 166), (41, 162),
                   (35, 156), (31, 150)], (3, 4, 5))
    # One long low sail on the back (left flank), y 106-131: its root tucked under the body, its
    # outer edge running along the back to a point raked toward the tail.
    dorsal = smooth([(20, 104), (14, 107), (10, 114), (8, 126), (14, 127.5), (23, 131), (22, 112)],
                    (3,))
    # The pectoral: one swept-back teardrop just under the head on the belly side, lying along the
    # body (round root by the gill, point trailing toward the tail).
    pector = smooth([(53, 106), (56.5, 108), (57.5, 113), (53, 125), (50.5, 116), (50.5, 110)], (3,), 10)
    # The tie: a flat-ended ring across the tail root, 3-4 px wider than it each side.
    band = smooth([(25, 139), (43, 139), (44, 143), (43, 147.5), (25, 147.5), (24, 143)], (), 10)
    gill = {"name": "n_gill", "part": "north_fish",
            "d": open_path(arc_in(body, [(N_GILL_C[0] + N_GILL_R * math.cos(math.radians(a)),
                                          N_GILL_C[1] + N_GILL_R * math.sin(math.radians(a)))
                                         for a in np.linspace(*N_GILL_A, 160)]))}
    return {
        "tail": [shape("n_tail", "north_fish", tail)],
        "fins": [shape("n_dorsal", "north_fish", dorsal)],
        "body": [shape("n_body", "north_fish", body)],
        "head": [shape("n_pector", "north_fish", pector), shape("n_eye", "north_fish", ring(L[13], 4.2))],
        "band": [shape("n_band", "east_cord", band)],
        "strokes": [gill],
    }


# ---- The cords and the bow ----

# The west ribbon leaves the band's bottom edge, clear of the tail, and comes into the knot from
# its upper right; the east one leaves the north band's lower-left corner angled out to the left
# (away from the tail, which forks right), bends in a gentle S through eta and omicron and comes
# into the knot from its upper left.
WEST_SPINE = [(96, 165), (88, 172), (70, 174), (61, 184), (52, 196), (42, 204), (33, 210)]
EAST_SPINE = [(24, 210), (18, 200), (14, 188), (14, 179), (19, 168), (22, 160), (23, 152), (27, 144)]


def cords():
    e, _ = arclength_of(WEST_SPINE, L[6])
    x, end = arclength_of(WEST_SPINE, L[8])
    # Long narrow faces between the stars, broader faces on them (each star mid-face); the first
    # and last twists hide under the band and the knot.
    west, ws, wf = ribbon(WEST_SPINE, [
        (0, e - 8, 3.6, "west_cord"), (e - 8, e + 8, 6.0, "west_cord"),
        (e + 8, x - 8, 3.6, "west_cord"), (x - 8, x + 8, 6.6, "knot"),
        (x + 8, end, 3.4, "knot")], "wr")
    o, end = arclength_of(EAST_SPINE, L[9])
    h, _ = arclength_of(EAST_SPINE, L[10])
    east, es, ef = ribbon(EAST_SPINE, [
        (0, o - 9, 3.4, "knot"), (o - 9, o + 9, 6.6, "east_cord"), (o + 9, h - 9, 3.6, "east_cord"),
        (h - 9, h + 9, 6.8, "east_cord"), (h + 9, end, 3.2, "east_cord")], "er")
    return west, east, ws + es, {**wf, **ef}


def loop(spine, hw):
    """A bow loop: a band `hw` px either side of `spine` (game px), open at both ends."""
    ax = Axis([np.array(p, float) * S for p in spine])
    left, right = [], []
    for t in np.linspace(0, ax.L, 60):
        c, _, nrm = ax.frame(t)
        left.append(c + nrm * hw * S)
        right.append(c - nrm * hw * S)
    return left + right[::-1]


def bow():
    """The bow at Alrescha: a round knot, two loops out to the sides (their tips lifted a little)
    and two narrow tapered tails angled down and out, all above y 224 (clear of the horizon glow)."""
    tails = [
        shape("end_l", "knot", smooth([(23, 216), (27, 219), (21, 222), (15, 223), (19, 219.5)], (3,), 10)),
        shape("end_r", "knot", smooth([(29, 219), (33, 216), (37, 219.5), (41, 223), (35, 222)], (3,), 10)),
    ]
    # Each loop is a band of ribbon round an open eye (the sky shows through), both its ends
    # tucked under the knot.
    loops = [
        shape("loop_l", "knot", loop([(25, 212), (18, 208), (12, 205), (8, 206), (8, 211), (12, 215),
                                      (18, 216), (25, 216)], 1.9)),
        shape("loop_r", "knot", loop([(31, 212), (38, 208), (44, 205), (48, 206), (48, 211), (44, 215),
                                      (38, 216), (31, 216)], 1.9)),
    ]
    centre = shape("knot", "knot", ring(L[7], 6.8, 32, 6.2))
    return tails + loops + [centre], {"end_l": "back", "end_r": "back"}


def figure_shapes():
    w, n = west_fish(), north_fish()
    west, east, strokes, faces = cords()
    knot, kf = bow()
    shapes = (w["tail"] + west + w["fins"] + w["body"] + w["head"] + w["band"]
              + n["tail"] + east + n["fins"] + n["body"] + n["head"] + n["band"] + knot)
    return shapes, strokes + w["strokes"] + n["strokes"], {**faces, **kf}


def _order(shapes):
    order = sorted({s.get("group", s["name"]) for s in shapes},
                   key=lambda g: max(i for i, s in enumerate(shapes) if s.get("group", s["name"]) == g))
    return {g: i for i, g in enumerate(order)}


def _stars():
    stars = np.zeros((clean_line.H, clean_line.W), bool)
    for x, y in L:
        stars[y, x] = True
    return stars


def faces_pass(img, shapes, faces, line, groups):
    """Thickens the stardust on lit ribbon faces and thins it on back faces and the bow's tails,
    so each twist reads; the line and the stars' own pixels stay."""
    index = _order(shapes)
    sky = sd.sky_index()
    stars = _stars()
    for g, face in faces.items():
        inside = (groups == index[g]) & ~line & ~stars
        if face == "back":
            drop = inside & (img[..., 3] > 0) & (sd.BAY >= BACK_KEEP)
            img[drop] = 0
        else:
            dist = sd.distance_inside(groups == index[g])
            add = inside & (img[..., 3] == 0) & (sd.BAY < LIT_FILL * np.clip(1.4 - 0.25 * dist, 0.4, 1.0))
            for y, x in zip(*np.nonzero(add)):
                img[y, x, :3] = sd.PAL[sd.N[min(sky[y, x] + 1, 8)]]
                img[y, x, 3] = 255
    return img


def hollow_pass(img, shapes, line, groups):
    """Thins the plain stardust (one or two steps over the sky) in the middle of the big fish
    bodies, so they read thick at the edge and thin in the middle; specks, glints, the line and the
    stars' own pixels stay."""
    index = _order(shapes)
    sky = sd.sky_index()
    stars = _stars()
    names = {tuple(int(c) for c in v): k for k, v in sd.PAL.items()}
    for g in HOLLOW_GROUPS:
        dist = sd.distance_inside(groups == index[g])
        keep = np.clip(1.0 - (dist - HOLLOW_FROM) / HOLLOW_RAMP, HOLLOW_CORE, 1.0)
        cand = (groups == index[g]) & ~line & ~stars & (img[..., 3] > 0) & (sd.BAY >= keep)
        for y, x in zip(*np.nonzero(cand)):
            name = names[tuple(int(c) for c in img[y, x, :3])]
            if name in sd.N and sd.N.index(name) <= sky[y, x] + 2:
                img[y, x] = 0
    return img


def map_landmarks():
    """StarMap.pisces()'s landmarks, read from game/core/star_map.gd (one source of truth)."""
    import re
    src = (ROOT / "game" / "core" / "star_map.gd").read_text()
    block = re.search(r"static func pisces\(\) -> StarMap:(.*?)\n\n\n", src, re.S).group(1)
    marks = re.search(r"map\.landmarks = \[(.*?)\]\n", block, re.S).group(1)
    return [(int(x), int(y)) for x, y in re.findall(r"Vector2i\((-?\d+), (-?\d+)\)", marks)]


def save(img, path):
    Image.fromarray(img, "RGBA").save(path)
    print(f"wrote {path.relative_to(ROOT)}")


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--preview", type=Path, help="also write the figure over the sky, x3, here")
    args = parser.parse_args()
    assert map_landmarks() == L, "L differs from StarMap.pisces() in game/core/star_map.gd"
    shapes, strokes, faces = figure_shapes()
    line, groups, parts = clean_line.draw(shapes, strokes)
    ys, xs = np.nonzero(line)
    for i, ((x, y), s) in enumerate(zip(L, SIZES)):
        d = np.sqrt(((xs - x) ** 2 + (ys - y) ** 2).min())
        print(f"star {i:2d} {s} {STAR_PARTS[i]:10s} on {parts[y, x] or '-':10s} line {d:.1f} px")
    img, parts = clean_line.semi_hollow(shapes, L, SIZES, SEED, LIGHT, strokes=strokes)
    img = faces_pass(img, shapes, faces, line, groups)
    img = hollow_pass(img, shapes, line, groups)
    img[clean_line.END_PANEL_TOP:] = 0
    img = sd.sun_clamp(img)
    used = sd.check(img)
    print(f"figure: {sum(used.values())} px, {used}")
    ART.mkdir(parents=True, exist_ok=True)
    save(img, OUT)
    for part, piece in sd.pieces(img, clean_line.part_tags(parts, img, L, STAR_PARTS), PARTS).items():
        save(piece, ART / f"pisces_piece_{part}.png")
    if args.preview:
        sd.preview(img, L, SIZES, SEGMENTS).save(args.preview)
        print(f"wrote {args.preview}")
    pisces_part_paintings.build_parts()


if __name__ == "__main__":
    main()
