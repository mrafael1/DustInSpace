"""Pisces's part-stage paintings (chapter 6), in assets/art/:

  pisces_part_<part>.png    each part stage's own painting (circlet, west_cord, knot, east_cord,
                            north_fish), shown when that stage is complete

The same clean-line semi-hollow style as the whole figure (tools/art/build_pisces_figure.py,
tools/art/clean_line.py, tools/art/stardust.py): the final's fish, ribbons and bow, re-posed and
scaled to each stage's stars (StarMap.pisces_<part>() in game/core/star_map.gd; each stage's
landmarks and sizes are checked against that file, the one source of truth). Lit from the upper
left; the fish bodies hollow in the middle, the ribbons' lit faces dense and back faces sparse.

  circlet     the western fish whole, the final's at 1.4x about its eye (gamma), facing right; the
              belly let down 5 px under lambda and the sail's trailing root carried back over theta;
              no tie band (the West Cord's): the body narrows to a short tail root and the tail
              grows out of it as one silhouette
  west_cord   the western fish's hind body (anal fin, forked tail, tie band on omega) at 0.885x,
              turned 4 degrees head up, its head off the right edge (cut there with no line down
              the cut, the stardust thinning before it); the twisted ribbon from under the band
              through delta, epsilon, mu and nu (a broad back face on each star), ending in a twist
              past nu
  knot        the final's bow at its own size, tipped 30 degrees clockwise on Alrescha (round knot,
              two loops round open eyes, two narrow tapered tails); the west cord in through nu and
              xi, the east cord out through omicron, pi and eta, both tying in from above the right
              loop
  east_cord   the ribbon from a twist past eta up through rho to the northern fish's tie band on
              chi; the fish's tail end at 1.5x (sail, swept-back pectoral, two-lobed tail flexed
              36 degrees up so its upper lobe reaches psi1, phi on the tail root), dissolving into
              the sky where the head would begin
  north_fish  the northern fish whole at 1.8x, turned 43 degrees to swim up and left (sail toward
              the lower left), the eye ring on 65 Psc, the gill arc, the pectoral under sigma, the
              tail flexed 18 degrees about the tie band so it stays on screen, the forehead let out
              2 px so 68 Psc sits inside it

No colour outside the Stellar Sun palette; every pixel opaque or empty.

The whole figure and its chart pieces are built by tools/art/build_pisces_figure.py, which also
runs this module.

Run: python tools/art/pisces_part_paintings.py   (needs Pillow and numpy)
"""

import math
import re
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import clean_line as cl  # noqa: E402
import stardust as sd  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / "assets" / "art"
STAR_MAP = ROOT / "game" / "core" / "star_map.gd"
PARTS = ("circlet", "west_cord", "knot", "east_cord", "north_fish")
S = cl.S
SEED = 11
LIGHT = np.array([-0.55, -0.65, 0.52])  # the final's light: upper left
X_ARM, LIT_FILL, BACK_KEEP = 2.6, 0.75, 0.10  # the final's ribbon twists and faces
HALF_FACE = 8.0                               # half a broad back face, along the ribbon


# --- shared shapes and passes (the final's) --------------------------------------------------

def smooth(points, sharp=(), n=14):
    """The final's closed Catmull-Rom outline (game px in, 4x points out), corners at `sharp`."""
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


def ring(c, rx, ry=None, n=32):
    ry = rx if ry is None else ry
    return [(np.array(c, float) + np.array([rx * math.cos(a), ry * math.sin(a)])) * S
            for a in np.linspace(0, 2 * math.pi, n, endpoint=False)]


def open_path(pts):
    q = [(round(float(x) * S + S / 2, 1), round(float(y) * S + S / 2, 1)) for x, y in pts]
    return "M %s %s " % q[0] + " ".join("L %s %s" % p for p in q[1:])


def shape(name, part, pts, group=None):
    return {"name": name, "part": part, "group": group or name, "d": cl.path_of(pts)}


def rotate(d, deg):
    a = math.radians(deg)
    return np.array((d[0] * math.cos(a) - d[1] * math.sin(a), d[0] * math.sin(a) + d[1] * math.cos(a)))


def _edge(hw, u):
    return hw * math.sin(math.pi * u)


def ribbon(spine, panels, name, part):
    """The final's twisted ribbon: one closed lens panel per (s0, s1, half-width) along `spine`
    (game px), each edge crossing into the next panel's other edge in a sharp X carried by a short
    1 px stroke. Returns the shapes, the strokes and each panel's face (broad back, narrow lit)."""
    ax = cl.Axis([np.array(p, float) * S for p in spine])
    shapes_, strokes_, faces = [], [], {}

    def pt(s, w):
        c, _, nrm = ax.frame(s * S)
        return c + nrm * w * S

    for k, (s0, s1, hw) in enumerate(panels):
        us = np.linspace(0, 1, 40)
        left = [pt(s0 + u * (s1 - s0), _edge(hw, u)) for u in us]
        right = [pt(s0 + u * (s1 - s0), -_edge(hw, u)) for u in us]
        g = f"{name}{k}"
        shapes_.append({"name": g, "part": part, "group": g, "d": cl.path_of(left + right[::-1][1:-1])})
        faces[g] = "back" if hw > 4.5 else "lit"
    for k in range(len(panels) - 1):
        (a0, a1, ahw), (b0, b1, bhw) = panels[k], panels[k + 1]
        ua, ub = 1 - X_ARM / (a1 - a0), X_ARM / (b1 - b0)
        for sign in (1, -1):
            line = [pt(a0 + u * (a1 - a0), sign * _edge(ahw, u)) for u in np.linspace(ua, 1, 6)]
            line += [pt(b0 + u * (b1 - b0), -sign * _edge(bhw, u)) for u in np.linspace(0, ub, 6)[1:]]
            pts = [(round(float(x), 1), round(float(y), 1)) for x, y in line]
            d = "M %s %s " % pts[0] + " ".join("L %s %s" % q for q in pts[1:])
            strokes_.append({"name": f"{name}x{k}{sign}", "part": part, "d": d})
    return shapes_, strokes_, faces


def arclength_of(spine, p):
    ax = cl.Axis([np.array(q, float) * S for q in spine])
    d = np.linalg.norm(ax.p - np.array(p, float) * S, axis=1)
    return float(ax.s[d.argmin()]) / S, ax.L / S


def cord_panels(spine, landmarks, sizes, stars, narrow, broad, run_on=False):
    """The final's rhythm along `spine`: a narrow lit face between the stars, a broad back face
    centred on each star (listed from the spine's start). The ribbon ends at the last broad face's
    far twist or, with `run_on` (the spine running on under the knot), with a narrow face to its end."""
    panels, s = [], 0.0
    for i in stars:
        c, _ = arclength_of(spine, landmarks[i])
        if not run_on or s < c - HALF_FACE - 1:
            panels.append((s, c - HALF_FACE, narrow))
        panels.append((max(c - HALF_FACE, 0.0) if run_on else c - HALF_FACE, c + HALF_FACE, broad[sizes[i]]))
        s = c + HALF_FACE
    if run_on:
        _, end = arclength_of(spine, spine[-1])
        if end > s + 4:
            panels.append((s, end, narrow))
    return panels


def group_index(sh):
    order = sorted({s.get("group", s["name"]) for s in sh},
                   key=lambda g: max(i for i, s in enumerate(sh) if s.get("group", s["name"]) == g))
    return {g: i for i, g in enumerate(order)}


def star_mask(landmarks):
    m = np.zeros((320, 180), bool)
    for x, y in landmarks:
        m[y, x] = True
    return m


def faces_pass(img, sh, faces, line, groups, landmarks):
    """The final's faces_pass: lit ribbon faces thicker, back faces thinner, so each twist reads."""
    index = group_index(sh)
    sky = sd.sky_index()
    stars = star_mask(landmarks)
    for g, face in faces.items():
        inside = (groups == index[g]) & ~line & ~stars
        if face == "back":
            img[inside & (img[..., 3] > 0) & (sd.BAY >= BACK_KEEP)] = 0
        else:
            dist = sd.distance_inside(groups == index[g])
            add = inside & (img[..., 3] == 0) & (sd.BAY < LIT_FILL * np.clip(1.4 - 0.25 * dist, 0.4, 1.0))
            for y, x in zip(*np.nonzero(add)):
                img[y, x, :3] = sd.PAL[sd.N[min(sky[y, x] + 1, 8)]]
                img[y, x, 3] = 255
    return img


def plain_dust(img, mask):
    """The pixels of `mask` holding plain stardust (one or two steps over the sky): not the line,
    the specks or the glints."""
    pal = {tuple(int(c) for c in v): k for k, v in sd.PAL.items()}
    sky = sd.sky_index()
    out = np.zeros(mask.shape, bool)
    for y, x in zip(*np.nonzero(mask & (img[..., 3] > 0))):
        name = pal[tuple(int(c) for c in img[y, x, :3])]
        out[y, x] = name in sd.N and sd.N.index(name) <= sky[y, x] + 2
    return out


def hollow_pass(img, sh, line, groups, landmarks, body, hollow=(3.0, 4.0, 0.10)):
    """The final's hollow_pass: thins the plain stardust in the middle of the big fish body, from
    `hollow` (from, ramp, core) = the final's (3, 4, 0.10) unless eased."""
    frm, ramp, core = hollow
    index = group_index(sh)
    dist = sd.distance_inside(groups == index[body])
    keep = np.clip(1.0 - (dist - frm) / ramp, core, 1.0)
    img[plain_dust(img, (groups == index[body]) & ~line & ~star_mask(landmarks) & (sd.BAY >= keep))] = 0
    return img


def keep_star_pixels(img, landmarks):
    """Each star keeps its faint pixel."""
    sky = sd.sky_index()
    for x, y in landmarks:
        if not img[y, x, 3]:
            img[y, x, :3] = sd.PAL[sd.N[sky[y, x] + 1]]
            img[y, x, 3] = 255
    return img


def drawn(sh, st, landmarks, sizes, stage):
    """The stage's line and groups, and its stardust; every star on the form."""
    line, groups, _ = cl.draw(sh, st)
    ys, xs = np.nonzero(line)
    for x, y in landmarks:
        assert groups[y, x] >= 0, f"{stage}: star at {x},{y} is off the form"
        d = np.sqrt(((xs - x) ** 2 + (ys - y) ** 2).min())
        print(f"  {stage} star at {x},{y}: line {d:.1f} px")
    img, _ = cl.semi_hollow(sh, landmarks, sizes, SEED, LIGHT, strokes=st)
    return img, line, groups


def finish(img):
    img[cl.END_PANEL_TOP:] = 0
    return sd.sun_clamp(img)


# --- the final's fish and bow (final game px) ------------------------------------------------

# The western fish. Its body without the tie band narrows to a tail root (circlet), or with it
# (west_cord) stays full to the band.
W_TAIL_SHARP = (2, 4, 6)
W_ANAL = [(118, 173), (113, 179), (106, 184), (106, 177), (104, 168)]
W_DORSAL = [(147, 124), (138, 114), (123, 103), (122, 111), (121, 119), (119, 126), (138, 130)]
W_PELVIC = [(158, 172), (147, 173), (143, 186), (149, 183), (155, 179)]
W_PECTOR = [(143, 150), (144, 153), (139, 158), (128, 164), (135, 155), (139, 151)]
W_GILL = lambda y: 155 - 6 * (1 - ((y - 151) / 16) ** 2)  # noqa: E731
W_EYE_R = 6.2

# The northern fish.
N_SHARP = (0, 1, 2)
N_TAIL_SHARP = (3, 4, 5)
N_DORSAL = [(20, 104), (14, 107), (10, 114), (8, 126), (14, 127.5), (23, 131), (22, 112)]
N_PECTOR = [(53, 106), (56.5, 108), (57.5, 113), (53, 125), (50.5, 116), (50.5, 110)]
N_BAND = [(25, 139), (43, 139), (44, 143), (43, 147.5), (25, 147.5), (24, 143)]
N_BAND_C = np.array((34.0, 143.25))  # the band's centre
N_EYE_C = np.array((46.0, 96.0))     # the eye (tau in the final)

# The bow at Alrescha.
KNOT_F = np.array((28.0, 214.0))
END_L = [(23, 216), (27, 219), (21, 222), (15, 223), (19, 219.5)]
END_R = [(29, 219), (33, 216), (37, 219.5), (41, 223), (35, 222)]
LOOP_L = [(25, 212), (18, 208), (12, 205), (8, 206), (8, 211), (12, 215), (18, 216), (25, 216)]
LOOP_R = [(31, 212), (38, 208), (44, 205), (48, 206), (48, 211), (44, 215), (38, 216), (31, 216)]
LOOP_HW = 1.9
KNOT_RX, KNOT_RY = 6.8, 6.2


# --- stage 1: the Circlet ----------------------------------------------------------------------

CIRCLET_L = [(127, 157), (117, 191), (83, 201), (57, 183), (56, 148), (77, 128)]
CIRCLET_SIZES = ["B", "S", "M", "S", "M", "M"]
CIRCLET_K = 1.4  # scaled about the final's eye (gamma), which lands on this stage's gamma
CIRCLET_EYE_F = np.array((160.0, 146.0))
# The final's body with the belly let down 5 px under lambda, no band: a short tail root.
CIRCLET_BODY = [(174, 150), (165, 136), (152, 126), (137, 121), (122, 125), (109, 135), (101, 145),
                (96, 150.5), (96.5, 156), (102, 163), (112, 172), (128, 182.5), (147, 180), (160, 172),
                (167, 164), (172, 157), (169, 153)]
CIRCLET_SHARP = (0, 15, 16)
CIRCLET_TAIL = [(98, 151.5), (86, 140), (74, 131), (78, 143), (85, 151), (79, 155), (73, 159),
                (89, 160.5), (97, 155.5)]


def paint_circlet():
    L, SIZES = CIRCLET_L, CIRCLET_SIZES

    def posed(points):
        return [tuple(np.array(L[0], float) + CIRCLET_K * (np.array(p, float) - CIRCLET_EYE_F)) for p in points]

    sh = [
        shape("w_tail", "circlet", smooth(posed(CIRCLET_TAIL), W_TAIL_SHARP), "w_body"),
        shape("w_pelvic", "circlet", smooth(posed(W_PELVIC), (2,))),
        shape("w_anal", "circlet", smooth(posed(W_ANAL), (2,))),
        shape("w_dorsal", "circlet", smooth(posed(W_DORSAL), (2, 5)), "w_body"),
        shape("w_body", "circlet", smooth(posed(CIRCLET_BODY), CIRCLET_SHARP), "w_body"),
        shape("w_pector", "circlet", smooth(posed(W_PECTOR), (3,), 10)),
        shape("w_eye", "circlet", ring(L[0], W_EYE_R * CIRCLET_K)),
    ]
    st = [{"name": "w_gill", "part": "circlet",
           "d": open_path(posed([(W_GILL(y), y) for y in np.linspace(135, 167, 80)]))}]
    img, line, groups = drawn(sh, st, L, SIZES, "circlet")
    img = hollow_pass(img, sh, line, groups, L, "w_body")
    return finish(img)


# --- stage 2: the West Cord --------------------------------------------------------------------

WEST_L = [(168, 98), (143, 121), (113, 132), (92, 160), (63, 169), (40, 196)]
WEST_SIZES = ["M", "M", "S", "M", "S", "M"]
WEST_K, WEST_TURN = 0.885, -3.9  # scaled and turned (head a little up) about the band, onto omega
WEST_BAND_F = np.array((94.0, 158.0))
WEST_HOLLOW = (5.0, 5.0, 0.25)   # the final's hollow, eased: only the hind body shows
WEST_BODY = [(174, 150), (165, 136), (152, 126), (137, 121), (122, 125), (108, 136), (98, 147),
             (98, 164), (110, 172), (128, 177), (148, 177), (160, 172), (167, 164), (172, 157), (169, 153)]
WEST_SHARP = (0, 13, 14)
WEST_TAIL = [(100, 152), (86, 140), (74, 131), (78, 143), (85, 151), (79, 155), (73, 159),
             (89, 160), (100, 160)]
WEST_BAND = [(90, 145), (95, 144), (99, 146), (99, 168), (95, 170), (90, 168)]
# The hind body is cut at the screen's right edge: no line down the edge, the stardust thinning
# over WEST_FADE px before it.
WEST_CUT, WEST_FADE = 178.5, 7.0
WEST_SPINE = [(145, 127), (137, 134), (125, 136.5), (113, 132), (102, 140), (95, 150), (92, 160), (84, 166),
              (74, 169), (63, 169), (52, 175), (44, 186), (40, 196), (37, 206)]
WEST_NARROW, WEST_BROAD = 3.6, {"S": 5.4, "M": 6.2}


def edge_cut(img, sh, groups):
    """The body cut at the screen's right edge, the way the chart piece is cut at the seam: nothing
    past the cut (no line down the edge), the stardust thinning over WEST_FADE px before it."""
    body = groups == group_index(sh)["w_body"]
    ys, xs = np.mgrid[0:320, 0:180]
    cut = np.full(xs.shape, WEST_CUT)
    past = body & (xs > cut)
    img[past] = 0
    near = body & ~past & (xs > cut - WEST_FADE)
    img[plain_dust(img, near & (sd.BAY >= (cut - xs) / WEST_FADE))] = 0
    return img


def paint_west_cord():
    L, SIZES = WEST_L, WEST_SIZES

    def posed(points):
        return [tuple(np.array(L[1], float) + rotate((np.array(p, float) - WEST_BAND_F) * WEST_K, WEST_TURN))
                for p in points]

    panels = cord_panels(WEST_SPINE, L, SIZES, (2, 3, 4, 5), WEST_NARROW, WEST_BROAD)
    rib, st, faces = ribbon(WEST_SPINE, panels, "wr", "west_cord")
    sh = ([shape("w_tail", "west_cord", smooth(posed(WEST_TAIL), W_TAIL_SHARP))] + rib
          + [shape("w_anal", "west_cord", smooth(posed(W_ANAL), (2,))),
             shape("w_body", "west_cord", smooth(posed(WEST_BODY), WEST_SHARP)),
             shape("w_band", "west_cord", smooth(posed(WEST_BAND), (), 10))])
    img, line, groups = drawn(sh, st, L, SIZES, "west_cord")
    img = faces_pass(img, sh, faces, line, groups, L)
    img = hollow_pass(img, sh, line, groups, L, "w_body", WEST_HOLLOW)
    img = edge_cut(img, sh, groups)
    img[:, :20] = 0  # specks the right-edge cut wrapped round to the left edge (stardust.shift rolls)
    return finish(keep_star_pixels(img, L))


# --- stage 3: the Knot -------------------------------------------------------------------------

KNOT_L = [(108, 176), (76, 190), (44, 196), (64, 166), (86, 142), (110, 118)]
KNOT_SIZES = ["M", "S", "B", "M", "S", "M"]
KNOT_TURN = 30.0  # the bow at its own size, tipped clockwise about the knot, onto Alrescha
KNOT_WEST_SPINE = [(116, 172), (108, 176), (98, 182), (87, 187), (76, 190), (65, 190), (56, 188), (49, 190)]
KNOT_EAST_SPINE = [(48, 192), (54, 183), (59, 174), (64, 166), (72, 157), (80, 149), (86, 142), (94, 133),
                   (102, 125), (110, 118), (116, 112)]
KNOT_NARROW, KNOT_BROAD = 3.4, {"S": 5.6, "M": 6.4}


def bow_loop(spine, hw):
    """The final's bow loop: a band `hw` px either side of `spine` (game px), open at both ends."""
    ax = cl.Axis([np.array(p, float) * S for p in spine])
    left, right = [], []
    for t in np.linspace(0, ax.L, 60):
        c, _, nrm = ax.frame(t)
        left.append(c + nrm * hw * S)
        right.append(c - nrm * hw * S)
    return left + right[::-1]


def paint_knot():
    L, SIZES = KNOT_L, KNOT_SIZES

    def posed(points):
        return [tuple(np.array(L[2], float) + rotate(np.array(p, float) - KNOT_F, KNOT_TURN)) for p in points]

    west, ws, wf = ribbon(KNOT_WEST_SPINE, cord_panels(KNOT_WEST_SPINE, L, SIZES, (0, 1), KNOT_NARROW,
                                                       KNOT_BROAD, run_on=True), "wr", "knot")
    east, es, ef = ribbon(KNOT_EAST_SPINE, cord_panels(KNOT_EAST_SPINE, L, SIZES, (3, 4, 5), KNOT_NARROW,
                                                       KNOT_BROAD, run_on=True), "er", "knot")
    bow = [
        shape("end_l", "knot", smooth(posed(END_L), (3,), 10)),
        shape("end_r", "knot", smooth(posed(END_R), (3,), 10)),
        shape("loop_l", "knot", bow_loop(posed(LOOP_L), LOOP_HW)),
        shape("loop_r", "knot", bow_loop(posed(LOOP_R), LOOP_HW)),
        shape("knot", "knot", ring(L[2], KNOT_RX, KNOT_RY)),
    ]
    sh, st = west + east + bow, ws + es
    faces = {**wf, **ef, "end_l": "back", "end_r": "back"}
    img, line, groups = drawn(sh, st, L, SIZES, "knot")
    img = faces_pass(img, sh, faces, line, groups, L)
    return finish(keep_star_pixels(img, L))


# --- stage 4: the East Cord --------------------------------------------------------------------

EAST_L = [(50, 206), (62, 176), (92, 156), (124, 150), (100, 124)]
EAST_SIZES = ["B", "S", "M", "S", "M"]
EAST_K, EAST_TAIL_TURN = 1.5, -36.0  # scaled about the band onto chi; the tail flexed up about it
EAST_BODY = [(48, 82), (50, 87), (56, 86), (58, 93), (57, 103), (52, 116), (45, 127), (40.5, 135),
             (39.5, 141), (39.5, 147), (28.5, 147), (28.5, 141), (26, 135), (19, 126), (15.5, 115),
             (17, 104), (25, 96), (34, 90), (42, 85)]
# The tail, its upper lobe drawn out 7 px and the fork's notch set 2 px deeper, so psi1 sits inside.
EAST_TAIL = [(30, 146), (38, 146), (46, 147.5), (60, 152), (43, 159.5), (50, 166), (41, 162),
             (35, 156), (31, 150)]
# The body dissolves upward: from EAST_CUT px above the band's centre (stage px) line and stardust
# thin out together over EAST_FADE px, so the fish fades into the sky above phi.
EAST_CUT, EAST_FADE = 58.0, 12.0
EAST_SPINE = [(84, 157), (76, 161), (68, 167), (62, 176), (57, 186), (53, 196), (50, 206), (48, 216)]
EAST_NARROW, EAST_BROAD = 3.6, {"S": 5.6, "M": 6.4, "B": 6.8}


def body_fade(img, sh, groups):
    """The fish dissolving upward: from EAST_CUT px above the band, line, stardust and specks thin
    out together over EAST_FADE px (scattered, not in Bayer rows), so no line runs across the top."""
    index = group_index(sh)
    fish = sd.grow(np.isin(groups, [index[g] for g in ("n_dorsal", "n_body", "n_pector")]), 2)
    ys, xs = np.mgrid[0:320, 0:180]
    top = EAST_L[2][1] - EAST_CUT - EAST_FADE
    keep = (ys - top) / EAST_FADE
    noise = np.vectorize(lambda x, y: sd.hsh(x, y, 7))(xs, ys)
    img[fish & (noise >= keep)] = 0
    return img


def paint_east_cord():
    L, SIZES = EAST_L, EAST_SIZES

    def posed(points, turn=0.0):
        return [tuple(np.array(L[2], float) + rotate((np.array(p, float) - N_BAND_C) * EAST_K, turn))
                for p in points]

    panels = cord_panels(EAST_SPINE, L, SIZES, (1, 0), EAST_NARROW, EAST_BROAD)
    rib, st, faces = ribbon(EAST_SPINE, panels, "er", "east_cord")
    sh = ([shape("n_tail", "north_fish", smooth(posed(EAST_TAIL, EAST_TAIL_TURN), N_TAIL_SHARP))] + rib
          + [shape("n_dorsal", "north_fish", smooth(posed(N_DORSAL), (3,))),
             shape("n_body", "north_fish", smooth(posed(EAST_BODY), N_SHARP)),
             shape("n_pector", "north_fish", smooth(posed(N_PECTOR), (3,), 10)),
             shape("n_band", "east_cord", smooth(posed(N_BAND), (), 10))])
    img, line, groups = drawn(sh, st, L, SIZES, "east_cord")
    img = faces_pass(img, sh, faces, line, groups, L)
    img = hollow_pass(img, sh, line, groups, L, "n_body")
    img = body_fade(img, sh, groups)
    return finish(keep_star_pixels(img, L))


# --- stage 5: the North Fish -------------------------------------------------------------------

NORTH_L = [(128, 186), (100, 172), (72, 156), (52, 130), (80, 116), (110, 128)]
NORTH_SIZES = ["M", "S", "B", "S", "M", "S"]
# Scaled and turned (counter-clockwise) about the eye, which lands at NORTH_EYE (on 65 Psc's ring);
# the tail alone flexed NORTH_TAIL_TURN more degrees about the band's centre.
NORTH_K, NORTH_TURN, NORTH_TAIL_TURN = 1.8, -43.0, 18.0
NORTH_EYE = np.array((78.5, 114.5))
# The final's body, the forehead let out 2 px.
NORTH_BODY = [(48, 82), (50, 87), (56, 86), (58, 93), (57, 103), (52, 116), (45, 127), (40.5, 135),
              (39.5, 141), (39.5, 147), (28.5, 147), (28.5, 141), (26, 135), (19, 126), (15.5, 115),
              (16, 104), (22, 94.5), (31, 88), (42, 85)]
NORTH_TAIL = [(30, 146), (38, 146), (45, 148), (53, 150), (44, 157), (50, 166), (41, 162),
              (35, 156), (31, 150)]
N_GILL_C, N_GILL_R, N_GILL_A = (47, 95), 11.0, (-8, 166)
N_EYE_R = 4.2


def north_pose(p, turn=0.0):
    q = rotate((np.array(p, float) - N_EYE_C) * NORTH_K, NORTH_TURN) + NORTH_EYE
    if turn:
        c = np.array(north_pose(N_BAND_C))
        q = c + rotate(q - c, turn)
    return tuple(q)


def arc_in(body4, pts):
    """The final's arc_in: the run of `pts` (stage px) inside the body's fill, so the gill arc ends
    on the body's edge, never past it."""
    inside = cl.down(cl.fill_4x(cl.path_of(body4)))
    return [p for p in pts if inside[int(round(p[1])), int(round(p[0]))]]


def paint_north_fish():
    L, SIZES = NORTH_L, NORTH_SIZES

    def posed(points):
        return [north_pose(p) for p in points]

    body = smooth(posed(NORTH_BODY), N_SHARP)
    sh = [shape("n_tail", "north_fish", smooth([north_pose(p, NORTH_TAIL_TURN) for p in NORTH_TAIL],
                                               N_TAIL_SHARP)),
          shape("n_dorsal", "north_fish", smooth(posed(N_DORSAL), (3,))),
          shape("n_body", "north_fish", body),
          shape("n_pector", "north_fish", smooth(posed(N_PECTOR), (3,), 10)),
          shape("n_eye", "north_fish", ring(NORTH_EYE, N_EYE_R * NORTH_K)),
          shape("n_band", "north_fish", smooth(posed(N_BAND), (), 10))]
    gill = [(N_GILL_C[0] + N_GILL_R * math.cos(math.radians(a)), N_GILL_C[1] + N_GILL_R * math.sin(math.radians(a)))
            for a in np.linspace(*N_GILL_A, 160)]
    st = [{"name": "n_gill", "part": "north_fish", "d": open_path(arc_in(body, posed(gill)))}]
    img, line, groups = drawn(sh, st, L, SIZES, "north_fish")
    img = hollow_pass(img, sh, line, groups, L, "n_body")
    return finish(keep_star_pixels(img, L))


# --- the stages ----------------------------------------------------------------------------

STAGES = {
    "circlet": (CIRCLET_L, CIRCLET_SIZES, paint_circlet),
    "west_cord": (WEST_L, WEST_SIZES, paint_west_cord),
    "knot": (KNOT_L, KNOT_SIZES, paint_knot),
    "east_cord": (EAST_L, EAST_SIZES, paint_east_cord),
    "north_fish": (NORTH_L, NORTH_SIZES, paint_north_fish),
}
SIZE_CODES = {"SMALL": "S", "MEDIUM": "M", "BIG": "B"}


def stage_maps():
    """Each Pisces stage's landmarks and sizes, read from game/core/star_map.gd."""
    src = STAR_MAP.read_text()
    found = {}
    for part in PARTS:
        block = re.search(r"static func pisces_%s\(\) -> StarMap:(.*?)\n\n\n" % part, src, re.S).group(1)
        marks = re.search(r"map\.landmarks = \[(.*?)\]\n", block).group(1)
        sizes = re.search(r"map\.sizes = \[(.*?)\]\n", block).group(1)
        found[part] = ([(int(x), int(y)) for x, y in re.findall(r"Vector2i\((-?\d+), (-?\d+)\)", marks)],
                       [SIZE_CODES[s] for s in re.findall(r"Star\.Size\.(\w+)", sizes)])
    return found


def build_parts():
    """Writes each part stage's own painting, pisces_part_<part>.png."""
    ART.mkdir(parents=True, exist_ok=True)
    maps = stage_maps()
    for part in PARTS:
        landmarks, sizes, paint = STAGES[part]
        assert maps[part] == (landmarks, sizes), f"{part}: the painting's stars differ from StarMap.pisces_{part}()"
        img = paint()
        used = sd.check(img)
        print(f"part {part}: {sum(used.values())} px, {used}")
        sd.save(img, ART / f"pisces_part_{part}.png")


if __name__ == "__main__":
    build_parts()
