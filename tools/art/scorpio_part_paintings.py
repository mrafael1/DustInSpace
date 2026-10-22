"""The Scorpio's part-stage paintings in the final's clean-line semi-hollow style, for
tools/art/build_scorpio_figure.py.

Each part stage's painting is the same body part as scorpio_figure.png, re-posed on that stage's own
landmarks (game/core/star_map.gd) and rendered exactly as the whole is: clean_line.semi_hollow with
the final's light and seed, the final's shape profiles (tail beads p=2.4 pinch=0.12, plates p=3.2,
carapace p=3.0, thin jointed legs, the final's pincer outline), sized to each stage's star spacing.

  stinger  the tail's last beads come in from the right along the bottom (stars 0, 1), turn up at
           the left (2) and climb to the telson's root (3); the swollen vesicle runs right to the
           big star (4) and the slim sting arcs up to the tip star (5), its point hooked back
  tail     one bead per star down the right and along the bottom, thinning towards the sting
  body     wide overlapping plates carry the spine's stars 0-2 and taper into two tail beads (3, 4);
           stars 1 and 2 each branch to a leg either side (5-8), each star on its leg's knee
  heart    a plated body widest at Antares (2), the eight legs fanning out from under the plates
           as the final's do, Antares's branches (5, 6) each the third leg's knee
  claws    the neck's plates climb to the carapace round Dschubba (2); an arm up to its elbow (3)
           and a pincer holding beta (4), an arm down to its elbow (5) and a pincer holding pi (6),
           both opening to the right, the lower one mirrored

`paint(stage, landmarks, sizes, seed, light)` returns the painting (180x320 RGBA). Needs Pillow and
numpy.
"""

import numpy as np

import clean_line
from clean_line import Axis, cubic, path_of, placed, segment, tube


def g(x, y):
    """A game point (pixel centre) in clean_line's 4x space."""
    return (x * 4 + 2, y * 4 + 2)


def arclength_of(ax, p):
    """The arclength of the axis point nearest the game point `p`."""
    q = np.array(g(*p))
    return float(ax.s[np.argmin(np.linalg.norm(ax.p - q, axis=1))])


def spine_axis(M, spine, ends):
    """An axis through the spine's stars, reaching `ends` of a string past its first and last."""
    P = [np.array(M[i], float) for i in spine]
    a = P[0] - (P[1] - P[0]) * ends[0]
    b = P[-1] + (P[-1] - P[-2]) * ends[1]
    return Axis([g(*a)] + [g(*p) for p in P] + [g(*b)])


def bead(name, part, ax, s0, s1, w):
    """A tail segment with the final's profile."""
    return {"name": name, "part": part, "group": name,
            "d": path_of(segment(ax, s0, s1, w, w * 0.94, p=2.4, pinch=0.12))}


# ---- Stage 1: the Stinger ----

# This stage's strings are about 1.25x the final's tail strings; the widths grow a little less.
STINGER_K = 1.12
# The tail's centre line: in from the right past star 0, along the bottom (a little above the stars
# so the beads clear the end panel), up the left through star 2 to the telson's root by star 3.
STINGER_AXIS = [(134, 233), (112, 234), (80, 233), (61, 227), (52, 213), (56, 199), (65, 190)]
# Five beads (the final's metasomal segments) from the right to the telson, widths in 4x.
STINGER_WIDTHS = [28, 27, 26, 25, 24]
# The telson, outlined round the stars (game px, a closed Catmull-Rom curve): the final's teardrop
# vesicle, flat along its underside and swelling on its other side, with the sting curving towards
# the swell (up here, where the final's turns down) to a hooked point past the tip star.
STINGER_TELSON = [(58, 193), (72, 194), (86, 192), (97, 188), (105, 183), (111, 174), (114, 164),
                  (114, 154), (112, 147), (108, 143), (103, 143), (107, 146), (109, 151), (109, 159),
                  (106, 168), (100, 174), (94, 171), (84, 169), (72, 171), (62, 179), (58, 187)]


def stinger_shapes(M) -> list:
    out = [{"name": "telson", "part": "stinger", "group": "telson",
            "d": path_of(clean_line.outline(STINGER_TELSON))}]
    ax = Axis([g(*p) for p in STINGER_AXIS])
    n = len(STINGER_WIDTHS)
    step = ax.L / n
    for i in reversed(range(n)):
        s0, s1 = i * step - 7, (i + 1) * step + 7
        out.append(bead(f"bead{i}", "stinger", ax, max(s0, 0), min(s1, ax.L), STINGER_WIDTHS[i] * STINGER_K))
    return out


# ---- Stage 2: the Tail ----

# This stage's strings are about 1.25x the final's tail segments; the widths grow with them.
TAIL_K = 1.25
# The centre line: half a string before star 0 to half a string past star 5, through every star.
TAIL_ENDS = (0.5, 0.5)
# The beads' half-widths in 4x, body end first (the final's 29..24, scaled by TAIL_K).
TAIL_WIDTHS = [30, 29, 28, 27, 26, 25]
TAIL_OVERLAP = 7


def tail_shapes(M) -> list:
    ax = spine_axis(M, range(len(M)), TAIL_ENDS)
    at = [arclength_of(ax, p) for p in M]
    joints = [0.0] + [(at[i] + at[i + 1]) / 2 for i in range(len(M) - 1)] + [ax.L]
    out = []
    for i in reversed(range(len(M))):
        s0, s1 = joints[i] - TAIL_OVERLAP, joints[i + 1] + TAIL_OVERLAP
        out.append(bead(f"bead{i}", "tail", ax, max(s0, 0), min(s1, ax.L), TAIL_WIDTHS[i] * TAIL_K))
    return out


# ---- Stage 3: the Body ----

LEG_WIDTH = (3.4, 2.8)

BODY_SPINE = [0, 1, 2, 3, 4]
# The centre line: a little before star 0 to a little past star 4, through the spine's stars.
BODY_ENDS = (0.35, 0.33)
# The plates: from the axis's start to BODY_PLATES_END px past star 2; their half-widths (4x) along
# the plated length, front to back: the final's mesosoma's rear, widest at the front, tapering into
# the tail.
BODY_PLATE_COUNT = 7
BODY_PLATES_END = 9
BODY_PLATE_WIDTH = [(0.0, 60), (0.2, 70), (0.45, 70), (0.75, 58), (1.0, 44)]
# The tail's first three beads (4x half-widths) and the joints between them (px past star 2): star 3
# in the second, star 4 in the third, each about the final's bead length.
BODY_BEAD_WIDTHS = [30, 29, 28]
BODY_BEAD_JOINTS = [30, 56]
BODY_OVERLAP = 7
# The legs, the rearmost of the final's, so swept well back (feet towards the tail): (star, side
# (+1 down-right, -1 up-left), foot angle (degrees from out, + towards the head), tibia length, 4x).
BODY_LEGS = [(5, -1, -80, 58), (6, 1, -56, 58), (7, -1, -96, 60), (8, 1, -80, 60)]


def body_plate_width(s, end):
    ts, ws = zip(*BODY_PLATE_WIDTH)
    return float(np.interp(s / end, ts, ws))


def body_shapes(M) -> list:
    ax = spine_axis(M, BODY_SPINE, BODY_ENDS)
    at = {i: arclength_of(ax, M[i]) for i in BODY_SPINE}
    end = at[2] + BODY_PLATES_END * 4
    out = []
    # The beads, under everything.
    joints = [end - 10] + [at[2] + j * 4 for j in BODY_BEAD_JOINTS] + [ax.L]
    for i in reversed(range(len(BODY_BEAD_WIDTHS))):
        out.append(bead(f"bead{i}", "body", ax, joints[i] - BODY_OVERLAP, min(joints[i + 1] + BODY_OVERLAP, ax.L),
                        BODY_BEAD_WIDTHS[i]))
    # The legs, under the plates: root under the plate at the star's foot on the axis, the femur out
    # to the knee at the star, the tibia on out and back.
    for k, side, foot_ang, l2 in BODY_LEGS:
        star = np.array(g(*M[k]))
        s = arclength_of(ax, M[k])
        c, t, nrm = ax.frame(s)
        n = -nrm * side if (star - c) @ (-nrm * side) > 0 else nrm * side
        f = -t
        root = c + n * (body_plate_width(s, end) - 14)
        knee = star
        r = np.radians(foot_ang)
        foot = knee + (n * np.cos(r) + f * np.sin(r)) * l2
        spine = [root, root + (knee - root) * 0.55, knee, knee + (foot - knee) * 0.5, foot]
        out.append({"name": f"leg{k}", "part": "body", "group": f"leg{k}", "d": path_of(tube(spine, *LEG_WIDTH))})
    # The plates, the front one on top.
    edges = np.linspace(0, end, BODY_PLATE_COUNT + 1)
    for i in reversed(range(BODY_PLATE_COUNT)):
        s0, s1 = edges[i] - 4, edges[i + 1] + 10
        out.append({"name": f"plate{i}", "part": "body", "group": f"plate{i}",
                    "d": path_of(segment(ax, max(s0, 0), s1, body_plate_width(s0 + 4, end),
                                         body_plate_width(s1 - 4, end), p=3.2))})
    return out


# ---- Stage 4: the Heart ----

# The spine from the head end (upper right) to the tail end, so "forward" is up the axis as in the
# final, and the final's left-of-travel side (its "up" legs) is the upper left here.
HEART_SPINE = [4, 3, 2, 1, 0]
HEART_ENDS = (0.3, 0.3)
HEART_PLATE_COUNT = 10
# The plates' half-widths (4x) along the axis, head end first: widest at Antares.
HEART_PLATE_WIDTH = [(0.0, 50), (0.25, 72), (0.5, 80), (0.75, 70), (1.0, 46)]
# The legs, as the final's (LEGS_UP / LEGS_DOWN): (root offset along the axis from Antares in 4x,
# knee angle (+: towards the head), femur, foot angle, tibia), lengths scaled by HEART_LEG_K; a leg
# with a star has its knee on that star.
HEART_LEG_K = 1.25
HEART_LEGS_UP = [(-48, 36, 44, -14, 44), (-24, 8, 48, -44, 50), (0, -20, 50, -70, 52), (24, -48, 48, -96, 52)]
HEART_LEGS_DOWN = [(-52, 62, 44, 20, 46), (-26, 30, 50, -14, 54), (0, -2, 52, -46, 56), (26, -34, 50, -80, 54)]
HEART_STAR_LEGS = {("u", 2): 5, ("d", 2): 6}


def heart_plate_width(ax, s):
    ts, ws = zip(*HEART_PLATE_WIDTH)
    return float(np.interp(s / ax.L, ts, ws))


def heart_shapes(M) -> list:
    ax = spine_axis(M, HEART_SPINE, HEART_ENDS)
    antares = arclength_of(ax, M[2])
    out = []
    for side, sign, legs in (("u", 1, HEART_LEGS_UP), ("d", -1, HEART_LEGS_DOWN)):
        for j, (ds, a1, l1, a2, l2) in enumerate(legs):
            s = antares + ds * HEART_LEG_K
            c, t, nrm = ax.frame(s)
            n, f = nrm * sign, -t
            root = c + n * (heart_plate_width(ax, s) - 12)

            def toward(a):
                r = np.radians(a)
                return n * np.cos(r) + f * np.sin(r)
            star = HEART_STAR_LEGS.get((side, j))
            knee = np.array(g(*M[star])) if star is not None else root + toward(a1) * l1 * HEART_LEG_K
            foot = knee + toward(a2) * l2 * HEART_LEG_K
            spine = [root, root + (knee - root) * 0.55, knee, knee + (foot - knee) * 0.5, foot]
            out.append({"name": f"leg_{side}{j}", "part": "heart", "group": f"leg_{side}{j}",
                        "d": path_of(tube(spine, *LEG_WIDTH))})
    edges = np.linspace(0, ax.L, HEART_PLATE_COUNT + 1)
    for i in reversed(range(HEART_PLATE_COUNT)):
        s0, s1 = edges[i] - 4, edges[i + 1] + 10
        out.append({"name": f"plate{i}", "part": "heart", "group": f"plate{i}",
                    "d": path_of(segment(ax, max(s0, 0), min(s1, ax.L), heart_plate_width(ax, s0 + 4),
                                         heart_plate_width(ax, s1 - 4), p=3.2))})
    return out


# ---- Stage 5: the Claws ----

# This stage spreads its stars wider than the final's head: the arms grow by CLAWS_K, the pincers by
# CHELA_K and the carapace by CARA_K.
CLAWS_K = 1.3
CHELA_K = 1.2
# The axis from the carapace's front (CARA_FRONT px ahead of Dschubba) back through the neck to a
# little past star 0.
CARA_FRONT = 16
CLAWS_ENDS_BACK = 0.35
# The carapace: from the front back CARA_LEN px, half-widths (4x, before CARA_K) front and back.
CARA_LEN = 30
CARA_W = (34, 52)
CARA_K = 1.15
# The neck's plates behind the carapace, half-widths (4x) from front to back.
CLAWS_PLATE_COUNT = 5
CLAWS_PLATE_WIDTH = [(0.0, 48), (0.5, 58), (1.0, 64)]
# The arms: each a femur from under the carapace's front side out to its elbow star and a patella
# from there to the pincer's wrist, one outline (the final's femur and patella widths, 4x).
ARM_ROOT = 9           # px back from the carapace's front
ARM_ROOT_OUT = 9       # px out from the axis
FEMUR_W = (11, 10)
FEMUR_BOW = (3, 0)     # px: the upper femur arcs out over the carapace to its elbow; the lower is clear
PATELLA_W = (11, 13)
# The pincers: (hand star, elbow star, side (+1 up), angle (deg, 0 = right, + down), the final's
# chela parameters L, h, g, fb (4x, before CHELA_K)); each hand star sits in its hand at HOLD[star]
# (fraction along, fraction out). The upper pincer points up-right and holds beta further along, so
# its wrist sits close to the elbow: a short patella as in the final, not a long swan neck.
CHELAE = [(4, 3, 1, -28, 154, 44, 0.0, 0.62), (6, 5, -1, 18, 164, 46, 0.04, 0.58)]
HOLD = {4: (0.45, 0.15), 6: (0.32, 0.15)}


def chela(L, h, g=0.0, fb=0.62):
    """The final's pincer in local space (x along it, y to its outer side): a bulbous hand and two
    curved fingers, their tips turned toward each other round an almond opening."""
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


def neck_axis(M):
    head, p1, p0 = (np.array(M[i], float) for i in (2, 1, 0))
    u = (head - p1) / np.linalg.norm(head - p1)
    front = head + u * CARA_FRONT
    back = p0 - (p1 - p0) * CLAWS_ENDS_BACK
    return Axis([g(*front), g(*head), g(*p1), g(*p0), g(*back)])


def claws_plate_width(s, s0, s1):
    ts, ws = zip(*CLAWS_PLATE_WIDTH)
    return float(np.interp((s - s0) / (s1 - s0), ts, ws))


def hand(M, star, side, ang, Lc, hc, gc, fb):
    """The pincer's outline and wrist (4x), placed so its hand holds the star."""
    Lc, hc = Lc * CHELA_K, hc * CHELA_K
    pts = chela(Lc, hc, gc, fb)
    if side < 0:
        pts = [(x, -y) for x, y in pts]
    a = np.radians(ang)
    u = np.array([np.cos(a), np.sin(a)])
    w = np.array([np.sin(a), -np.cos(a)])
    wrist = np.array(g(*M[star])) - u * HOLD[star][0] * Lc - w * HOLD[star][1] * hc * side
    return placed(wrist, ang, pts), wrist


def claws_shapes(M) -> list:
    ax = neck_axis(M)
    cara_end = CARA_LEN * CARA_K * 4
    out = []
    # The neck's plates, under everything, the front one on top.
    edges = np.linspace(cara_end - 16, ax.L, CLAWS_PLATE_COUNT + 1)
    for i in reversed(range(CLAWS_PLATE_COUNT)):
        s0, s1 = edges[i] - 4, min(edges[i + 1] + 10, ax.L)
        out.append({"name": f"plate{i}", "part": "claws", "group": f"plate{i}",
                    "d": path_of(segment(ax, s0, s1, claws_plate_width(s0 + 4, edges[0], ax.L),
                                         claws_plate_width(s1 - 4, edges[0], ax.L), p=3.2))})
    # The arms, from under the carapace's front sides (the axis's normal points up here).
    pincers = []
    for k, (star, elbow, side, ang, Lc, hc, gc, fb) in enumerate(CHELAE):
        pts, wrist = hand(M, star, side, ang, Lc, hc, gc, fb)
        pincers.append(pts)
        c, t, nrm = ax.frame(ARM_ROOT * 4)
        up = nrm if nrm[1] < 0 else -nrm
        root = c + up * side * ARM_ROOT_OUT * 4
        e = np.array(g(*M[elbow]))
        femur = [root, (root + e) / 2 + up * side * FEMUR_BOW[k] * 4, e]
        patella = [e, e + (wrist - e) * 0.5 - up * side * 6.0, wrist]
        out.append({"name": f"femur{k}", "part": "claws", "group": f"arm{k}",
                    "d": path_of(tube(femur, *(np.array(FEMUR_W) * CLAWS_K)))})
        out.append({"name": f"patella{k}", "part": "claws", "group": f"arm{k}",
                    "d": path_of(tube(patella, *(np.array(PATELLA_W) * CLAWS_K)))})
    out.append({"name": "carapace", "part": "claws", "group": "carapace",
                "d": path_of(segment(ax, 0, cara_end, CARA_W[0] * CARA_K, CARA_W[1] * CARA_K, p=3.0))})
    for k, pts in enumerate(pincers):
        out.append({"name": f"chela{k}", "part": "claws", "group": f"chela{k}", "d": path_of(pts)})
    return out


SHAPES = {"stinger": stinger_shapes, "tail": tail_shapes, "body": body_shapes,
          "heart": heart_shapes, "claws": claws_shapes}


def paint(stage: str, landmarks, sizes, seed: int, light) -> np.ndarray:
    """The part stage's painting: its shapes painted semi-hollow, every star on the figure."""
    img, parts = clean_line.semi_hollow(SHAPES[stage](landmarks), landmarks, sizes, seed, light)
    for k, (x, y) in enumerate(landmarks):
        assert parts[y, x], f"{stage}: star {k} at {(x, y)} is off the figure"
    return img
