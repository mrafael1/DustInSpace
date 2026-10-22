"""Leo's part-stage paintings (chapter 3), in assets/art/:

  leo_part_<part>.png    each part stage's own painting (tail, haunch, heart, mane, head), shown
                         when that stage is complete

The same clean-line semi-hollow style as the whole lion (tools/art/build_leo_figure.py,
tools/art/clean_line.py, tools/art/stardust.py): one silhouette per stage, outlined only round the
union, hollow with stardust inside, lit from the upper left. Each body part is the final's own,
re-posed to its stage's stars (StarMap.leo_<part>() in game/core/star_map.gd; each stage's
landmarks, segments and sizes are checked against that file, the one source of truth). Where the
body goes on past the stage's part, its line and dust dissolve into the sky (dithered on a fixed
per-pixel hash, not the Bayer grid the stardust itself is dithered on); a star's own pixel is kept.
Where a near limb lies over the body behind it, its edge is the final's fading inner stroke.

  tail    the lion faces right: its rump at the upper right (star 0 on the croup by the tail's
          root), the final's rear torso with the thigh's teardrop under it, dissolving where the
          body goes on; the tail the final's tube a little thicker, hanging in a long J down to the
          left (stars 1-4) and flicked up into the final's flame of a tuft, larger to hold the big
          Denebola (star 5)
  haunch  the final's haunch mirrored (the stage's leg zigs knee forward, hock back, paw forward
          with the lion facing left): the near thigh's teardrop at about 1.3x (croup 0, hip 1, thigh
          2, knee 3), the shin back to the pointed hock (4) and the cannon forward to the dome paw
          (5) with toe splits; the far hind leg stretched back behind it, pushing off (star 6 on its
          stifle); the flank going on forward, dissolving toward the top left
  heart   the lion faces right, its near foreleg lifted mid-stride, at about 1.3x: the torso's
          front, the upper arm from the shoulder (1) back to the jutting elbow, Regulus (2, big)
          just above it, the straight forearm (3) forward and down, the wrist knob and the paw
          hanging from it (4), toes curled with splits; the far foreleg planted behind, the
          brisket (5) behind the elbow; the back and the neck dissolve away, the withers left bare
          for the mane
  mane    the final's mane carried over whole, 1.3x about Algieba (star 2): its soft round top
          over the ear's place (4), the rear flames over the withers, one streaming back to the
          tuft star (6), the crown tufts with a forelock over the brow (5), the chest fringe
          hanging longer round stars 1 and 0, the face ruff ending where the face begins; the
          final's crown and ruff locks, stardust thinned as in the final
  head    the final's head and mane, 1.5x about the eye (star 3), the head lifted 24 degrees (the
          lion raising its head to roar at the Sun), the mane turning less: the true profile with
          the brow's step, the long bridge, the blunt nose, the closed mouth, the jaw fading up the
          cheek (star 5, big), the round ear (2), the crown's fur (1), the mane (0) dissolving away
          behind the head and the chest ruff under the chin (4 the throat) fading downward; the
          final's eye, a dark almond with a lit upper lid round its star

No colour outside the Stellar Sun palette; every pixel opaque or empty.

The whole lion and its chart pieces are built by tools/art/build_leo_figure.py, which also runs
this module.

Run: python tools/art/leo_part_paintings.py   (needs Pillow and numpy)
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
PARTS = ("tail", "haunch", "heart", "mane", "head")
SEED = 11
LIGHT = np.array([-0.55, -0.65, 0.52])  # the final's light: upper left
MANE_KEEP = 0.42                        # the final's thin_mane: the share of the mane's dust kept


# --- shared shapes and strokes --------------------------------------------------------------

def v(p):
    return np.array(p, float)


def unit(p):
    p = v(p)
    return p / np.linalg.norm(p)


def tuft(root, bend, tip, w):
    """The final's tuft: a flame along root-bend-tip, `w` px half-wide near its round root,
    tapering to a point (4x points)."""
    r, m, t = v(root), v(bend), v(tip)
    fs = np.linspace(0, 1, 16)
    pts = [(1 - f) ** 2 * r + 2 * (1 - f) * f * m + f * f * t for f in fs]
    left, right = [], []
    for k, (f, c) in enumerate(zip(fs, pts)):
        d = unit(pts[min(k + 1, len(pts) - 1)] - pts[max(k - 1, 0)])
        n = np.array([-d[1], d[0]])
        hw = w * (1 - f ** 2.4) * (0.75 + 0.25 * np.sin(min(f * 3.0, 1.0) * np.pi / 2))
        left.append(c + n * hw)
        right.append(c - n * hw)
    d0 = unit(pts[1] - pts[0])
    cap = [pts[0] - d0 * w * 0.9 + np.array([-d0[1], d0[0]]) * w * s for s in (0.55, 0.0, -0.55)]
    poly = left[::-1] + [cap[0], cap[1], cap[2]] + right
    return [tuple(p * 4) for p in poly]


def limb(points, radii):
    """The final's limb: a limb round a centre line, each side offset by its radius, ends capped."""
    pts = [v(p) for p in points]
    left, right = [], []
    for k, p in enumerate(pts):
        d = unit(pts[min(k + 1, len(pts) - 1)] - pts[max(k - 1, 0)])
        n = np.array([-d[1], d[0]])
        left.append(p + n * radii[k])
        right.append(p - n * radii[k])
    cap0 = pts[0] - unit(pts[1] - pts[0]) * radii[0] * 0.8
    cap1 = pts[-1] + unit(pts[-1] - pts[-2]) * radii[-1] * 0.8
    return [cap0] + left + [cap1] + right[::-1]


def repose(anchor_final, anchor_stage, scale, turn):
    """A function taking a final-layout point to the stage's layout: turned `turn` degrees (or the
    `turn` it is given) and scaled about the final's anchor, which lands on the stage's."""
    def place(p, turn_=None):
        a = math.radians(turn if turn_ is None else turn_)
        d = v(p) - v(anchor_final)
        r = np.array([d[0] * math.cos(a) - d[1] * math.sin(a), d[0] * math.sin(a) + d[1] * math.cos(a)])
        return tuple(v(anchor_stage) + r * scale)
    return place


def toe_strokes(toes, part):
    """1 px strokes (the toe splits, the mouth) through stage-px points."""
    return [{"name": f"toe{k}", "part": part,
             "d": cl.path_of([(x * 4 + 2, y * 4 + 2) for x, y in pts])[:-2]} for k, pts in enumerate(toes)]


def fade_stroke(pts, hold, reach, top=cl.LINE_STEPS):
    """The final's fading stroke: 1 px along `pts` (stage px) at `top` steps for `hold` px, then
    fading out over `reach` px: {(y, x): steps}."""
    m = cl.stroke(cl.path_of([(x * 4 + 2, y * 4 + 2) for x, y in pts])[:-2])
    dense, run = [], [0.0]
    for a, b in zip(pts, pts[1:]):
        for t in np.linspace(0, 1, 12, endpoint=False):
            dense.append(v(a) + (v(b) - v(a)) * t)
    dense.append(v(pts[-1]))
    for a, b in zip(dense, dense[1:]):
        run.append(run[-1] + np.linalg.norm(b - a))
    dense, out = np.array(dense), {}
    for y, x in zip(*np.nonzero(m)):
        s = run[int(np.argmin(np.hypot(dense[:, 0] - (x + 0.5), dense[:, 1] - (y + 0.5))))] - hold
        if s < reach:
            out[(y, x)] = top if s <= 0 else top - int(s * (top - 1) / reach)
    return out


def overlap_lines(sh, line, near, behind, start, reach):
    """The final's overlap_lines: where the near shapes lie over the ones behind, their edge as a
    short inner stroke from the silhouette (no higher than row `start`) at line strength, fading
    out over `reach` px: {(y, x): steps}."""
    fill = {s["name"]: cl.down(cl.fill_4x(s["d"])) for s in sh}
    near_fill = np.logical_or.reduce([fill[n] for n in near])
    behind_fill = np.logical_or.reduce([fill[n] for n in behind])
    cand = cl.edge_inner(near_fill) & behind_fill & ~line
    cand = cl.drop_elbows(cl.thin(cand))
    dist = {}
    frontier = [(y, x) for y, x in zip(*np.nonzero(cand))
                if y >= start and line[max(y - 2, 0):y + 3, max(x - 2, 0):x + 3].any()]
    for p in frontier:
        dist[p] = 0
    while frontier:
        nxt = []
        for y, x in frontier:
            for dy in (-2, -1, 0, 1, 2):
                for dx in (-2, -1, 0, 1, 2):
                    q = (y + dy, x + dx)
                    if q not in dist and 0 <= q[0] < cl.H and 0 <= q[1] < cl.W and cand[q]:
                        dist[q] = dist[(y, x)] + 1
                        nxt.append(q)
        frontier = nxt
    return {p: cl.LINE_STEPS - int(d * (cl.LINE_STEPS - 1) / reach) for p, d in dist.items() if d < reach}


def paint_strokes(img, lines, line, landmarks):
    """The final's paint_overlaps: the fading strokes over the stardust, the dust beside a bright
    one (above line strength) cleared so it reads, nothing within 2 px of a star."""
    sky = sd.sky_index()
    pale = (sd.PAL["N8"], sd.PAL["N9"], sd.PAL["D0"])
    for (y, x), steps in lines.items():
        if steps > cl.LINE_STEPS and not line[y, x]:
            for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
                q = (y + dy, x + dx)
                if q not in lines and not line[q] and img[q][3] and tuple(int(c) for c in img[q][:3]) not in pale:
                    img[q] = 0
    for (y, x), steps in lines.items():
        if any(abs(x - sx) <= 2 and abs(y - sy) <= 2 for sx, sy in landmarks):
            continue
        img[y, x, :3] = sd.PAL[sd.N[min(sky[y, x] + steps, 9)]]
        img[y, x, 3] = 255
    return img


def thin_mane(img, parts, line, landmarks):
    """The final's thin_mane: the stardust inside the mane thinned (not its line, not beside it)."""
    near = line.copy()
    for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
        near |= np.roll(line, (dy, dx), (0, 1))
    drop = (parts == "mane") & ~near & (sd.BAY > MANE_KEEP)
    for x, y in landmarks:
        drop[y, x] = False
    img[drop] = 0
    return img


_DICE = []


def dice():
    """The dissolve's dice: a fixed hash per pixel."""
    if not _DICE:
        _DICE.append(np.array([[sd.hsh(x, y, 31) for x in range(180)] for y in range(320)]))
    return _DICE[0]


def dissolved(img, landmarks, keeps):
    """`img` with each pixel dropped where the dice fall at or over any of `keeps` (each a keep
    share per pixel, 1 kept, 0 gone), the stars' own pixels kept."""
    stars = {(y, x): img[y, x].copy() for x, y in landmarks}
    for keep in keeps:
        img[dice() >= keep] = 0
    for (y, x), px in stars.items():
        img[y, x] = px
    return img


def radial_keep(centre, radius, power):
    """Gone at `centre`, kept from `radius` px away, eased by `power`."""
    (cx, cy) = centre
    return np.clip(np.hypot(sd.xs - cx, sd.ys - cy) / radius, 0, 1) ** power


def on_form(groups, landmarks, stage):
    for x, y in landmarks:
        assert groups[y, x] >= 0, f"{stage}: star at {x},{y} is off the form"


# --- the final's mane (the final's layout, game px) -------------------------------------------

CROWN_LOCKS = [[(151.8, 96.6), (149.6, 97), (147.4, 98.4)],
               [(146.6, 91.6), (144.8, 92.6), (143.6, 94.4)]]
RUFF_LOCKS = [[(124.2, 106.4), (125, 103.8), (126.6, 101.8), (128.8, 100.6)],
              [(126, 117.4), (126.6, 114.4), (128, 111.8), (130.2, 110)],
              [(124, 133.8), (124.8, 130), (126.4, 126.8), (129, 124.4)],
              [(129.6, 141.8), (130.4, 138.4), (132, 135.4), (134.4, 133.4)]]


def chest_ring(c, rx, ry, place):
    return [place((c[0] + rx * np.cos(a), c[1] + ry * np.sin(a))) for a in np.linspace(0, 2 * np.pi, 10)[:-1]]


# --- stage 1: the tail (the lion faces right) ------------------------------------------------

TAIL_L = [(150, 110), (126, 126), (100, 146), (74, 160), (48, 172), (30, 150)]
TAIL_SEGMENTS = [(0, 1), (1, 2), (2, 3), (3, 4), (4, 5)]
TAIL_SIZES = ["S", "S", "M", "M", "S", "B"]
# The final's TORSO rear (the back line, the croup, the rump's round, the belly) at 1.0x, closed at
# the right with a soft round where the body goes on.
TAIL_RUMP = [(180, 101), (170, 100.5), (160, 101), (152, 102.5), (147, 106), (144, 113), (144, 122),
             (146.5, 132), (151, 141), (156, 149), (161, 156), (166, 159), (171, 157), (174, 150),
             (176, 140), (180, 132)]
TAIL_FADE_X = (166, 180)   # the body going on dissolves from here to the right edge
# The thigh's front edge over the body: the final's stifle stroke, rising from the knee and fading.
TAIL_THIGH_STROKE = [(170, 156), (168, 147), (164, 138), (159, 130), (156, 121)]
# The final's tube (half-width 2.9 -> 1.9 at 1x) at 3.2 -> 2.3, from inside the croup out of the
# rump's top, through its stars in a long J and up into the tuft.
TAIL_TUBE = [(154, 110), (146, 111), (136, 117), (126, 126), (113, 137), (100, 146), (87, 154), (74, 160),
             (61, 167), (48, 172), (39, 170), (33, 163), (31, 158)]
TAIL_TUBE_W = (3.2, 2.3)
# The final's tuft (root, bend, tip, half-width), with one more, shorter lock on its back so its
# tip reads as hair at this size.
TAIL_TUFT = [((31.5, 162), (28, 147), (26, 131), 5.8),
             ((31, 160), (25, 152), (21, 142), 3.6)]


def tail_shapes():
    out = []

    def add(name, pts4):
        out.append({"name": name, "part": "tail", "group": "body", "d": cl.path_of(pts4)})

    add("rump", cl.outline(TAIL_RUMP, 8))
    add("tail", cl.tube([(x * 4 + 2, y * 4 + 2) for x, y in TAIL_TUBE], TAIL_TUBE_W[0] * 4, TAIL_TUBE_W[1] * 4))
    for k, f in enumerate(TAIL_TUFT):
        add(f"tuft{k}", tuft(*f))
    return out


def paint_tail():
    sh = tail_shapes()
    line, groups, _ = cl.draw(sh)
    on_form(groups, TAIL_L, "tail")
    img, _ = cl.semi_hollow(sh, TAIL_L, TAIL_SIZES, SEED, LIGHT)
    img = paint_strokes(img, fade_stroke(TAIL_THIGH_STROKE, 3, 12), line, TAIL_L)
    x0, x1 = TAIL_FADE_X
    keep = 1.0 - np.clip((sd.xs - x0) / (x1 - x0), 0, 1)
    keep = np.where(sd.xs >= x0, keep, 2.0)   # nothing left of the fade's start is touched
    img = dissolved(img, TAIL_L, [keep])
    return sd.sun_clamp(img)


# --- stage 2: the haunch (the lion faces left: the final's haunch mirrored) ------------------

HAUNCH_L = [(146, 104), (120, 124), (96, 146), (80, 174), (92, 202), (68, 222), (144, 150)]
HAUNCH_SEGMENTS = [(0, 1), (1, 2), (2, 3), (3, 4), (4, 5), (1, 6)]
HAUNCH_SIZES = ["M", "M", "B", "S", "S", "M", "S"]
# The near thigh, the final's teardrop at about 1.3x: its top the croup on the back line, its rear
# the rump's round, its round bottom the knee round star 3.
HAUNCH_THIGH = [(100, 106), (112, 102), (126, 99.5), (140, 98.5), (151, 100), (159, 106), (162.5, 115),
                (161, 126), (155, 137), (145, 148), (132, 159), (117, 170), (102, 179), (90, 185), (80, 185),
                (74.5, 179), (74, 170), (76.5, 160), (80.5, 149), (86, 138), (91, 128), (95, 118), (97, 110)]
# The near lower leg in one outline (the final's NEAR_HIND, mirrored): the shin slanting back to the
# pointed hock by star 4, the cannon forward-down to the dome paw on star 5, wider at the toes.
HAUNCH_NEAR_LEG = [(74, 172), (80, 168), (88, 175), (95, 186), (100, 195), (102, 200.5), (100, 205),
                   (94, 209), (88, 213), (83, 217), (82, 222), (80, 227), (75, 229.5), (66, 230), (59.5, 229.5),
                   (56, 226.5), (56.5, 221.5), (60, 216.5), (66, 213.5), (72, 211), (78, 206), (84, 199.5),
                   (84, 195), (78, 187), (73, 180)]
# The body going on forward from the haunch (the loin and flank, the belly line tucking up to the
# stifle), only so far as it dissolves into the sky: the haunch reads as a lion's, not a lone leg.
HAUNCH_FLANK = [(140, 99), (124, 99.5), (108, 101), (92, 103), (76, 105), (62, 108), (56, 120), (58, 134),
                (66, 144), (78, 149), (86, 150), (88, 140)]
# The far hind leg, stretched back behind it (pushing off): its stifle round star 6.
HAUNCH_FAR_LEG = [(132, 128), (148, 134), (153, 146), (154, 156), (158, 167), (164, 179), (168, 189),
                  (166, 195), (162, 203), (161, 210), (162, 215.5), (159.5, 220), (152, 220.5), (145, 220.5),
                  (142, 217.5), (144, 212.5), (149, 209), (152, 203), (153, 196), (148, 186), (141, 174),
                  (136, 162), (130, 146)]
HAUNCH_TOES = [[(67, 229), (67, 227)], [(61.5, 228.5), (62, 226.5)], [(150, 220), (150, 218)]]
HAUNCH_REACH, HAUNCH_START = 16, 140   # the near thigh's fading edge over the far leg
HAUNCH_FADE = ((48, 118), 44.0)        # the back going on dissolves toward this corner, over r px


def haunch_shapes():
    out = []

    def add(name, pts, n):
        out.append({"name": name, "part": "haunch", "group": "body", "d": cl.path_of(cl.outline(pts, n))})

    add("far_leg", HAUNCH_FAR_LEG, 5)
    add("flank", HAUNCH_FLANK, 6)
    add("thigh", HAUNCH_THIGH, 8)
    add("near_leg", HAUNCH_NEAR_LEG, 5)
    return out


def paint_haunch():
    sh = haunch_shapes()
    strokes = toe_strokes(HAUNCH_TOES, "haunch")
    line, groups, _ = cl.draw(sh, strokes)
    on_form(groups, HAUNCH_L, "haunch")
    img, _ = cl.semi_hollow(sh, HAUNCH_L, HAUNCH_SIZES, SEED, LIGHT, strokes=strokes)
    lines = overlap_lines(sh, line, ("thigh", "near_leg"), ("far_leg", "flank"), HAUNCH_START, HAUNCH_REACH)
    img = paint_strokes(img, lines, line, HAUNCH_L)
    img = dissolved(img, HAUNCH_L, [radial_keep(*HAUNCH_FADE, 1.5)])
    return sd.sun_clamp(img)


# --- stage 3: the heart (the lion faces right, its near foreleg lifted) ----------------------

HEART_L = [(146, 100), (124, 124), (104, 150), (118, 180), (142, 204), (76, 166)]
HEART_SEGMENTS = [(0, 1), (1, 2), (2, 3), (3, 4), (2, 5)]
HEART_SIZES = ["S", "M", "B", "S", "S", "M"]
# The torso's front: the back line from the withers back, the waist, the belly line forward to the
# brisket, the chest front up to the base of the neck.
HEART_TORSO = [(138, 104), (122, 110), (100, 114), (74, 116), (48, 118), (24, 120), (12, 134), (18, 148),
               (36, 155), (58, 162), (80, 170), (100, 174), (116, 168), (132, 160), (146, 148), (152, 132),
               (150, 116)]
# The far foreleg planted under the chest: the final's FAR_FORE at 1.25x.
HEART_FAR_FORE = [(98.5, 166), (112.9, 166), (112.9, 186), (111, 202.3), (110.5, 210.4), (113.5, 215.4),
                  (119.8, 220.4), (124.8, 225.4), (126, 230.4), (124.1, 233.5), (113.5, 233.5), (103.5, 232.9),
                  (100.4, 228.5), (100.4, 221), (98.5, 212.3), (98, 198.5), (98.75, 178.5)]
# The near upper arm, the final's UPPER_ARM at about 1.3x, down and back to the elbow's point.
HEART_UPPER_ARM = [(132, 98), (142, 93), (151, 96), (155, 108), (155, 124), (152, 138), (146, 150), (137, 160),
                   (126, 167), (114, 171), (104, 173), (96, 173.5), (91.5, 170.5), (93, 164), (97, 155),
                   (104, 141), (113, 125), (122, 109)]
# The forearm, the final's straight column (radii 5.6 -> 4.6 at 1x, here 7 -> 5.8).
HEART_FOREARM_AXIS = [(99, 165), (110, 172), (118, 180), (127, 188), (133, 193)]
HEART_FOREARM_RADII = [7.0, 6.9, 6.6, 6.2, 5.8]
# The wrist knob and the paw hanging from it (the final's WRIST and FORE_PAW at 1.25x).
HEART_WRIST = [(129, 188), (135.5, 187), (140, 192), (139, 199.5), (133.5, 202.5), (128.5, 199.5)]
HEART_FORE_PAW = [(134, 192), (140.6, 192.3), (145.8, 195.2), (151.4, 199.7), (155.5, 206.2), (155.8, 212.2),
                  (152.5, 216.2), (146.5, 217.7), (140.8, 216), (136.2, 211.5), (132.8, 205.7), (131.5, 198.2)]
HEART_TOES = [[(148.3, 217.0), (147.8, 214.2)], [(153.0, 213.7), (151.2, 212.0)], [(118, 233), (118, 231)]]
HEART_REACH, HEART_START = 30, 150     # the near limb's fading edge up the arm's back line
HEART_FADES = [((20, 150), 84.0), ((84, 100), 40.0)]   # the body and the neck going on dissolve
HEART_BACK_RAMP = ((30, 96), (110.0, 90.0))   # the back: gone at its corner, ramping in right and down


def heart_shapes():
    out = []

    def add(name, pts, n):
        out.append({"name": name, "part": "heart", "group": "body", "d": cl.path_of(cl.outline(pts, n))})

    add("far_fore", HEART_FAR_FORE, 5)
    add("torso", HEART_TORSO, 8)
    add("upper_arm", HEART_UPPER_ARM, 6)
    add("forearm", [tuple(p) for p in limb(HEART_FOREARM_AXIS, HEART_FOREARM_RADII)], 4)
    add("wrist", HEART_WRIST, 6)
    add("fore_paw", HEART_FORE_PAW, 6)
    return out


def paint_heart():
    sh = heart_shapes()
    strokes = toe_strokes(HEART_TOES, "heart")
    line, groups, _ = cl.draw(sh, strokes)
    on_form(groups, HEART_L, "heart")
    img, _ = cl.semi_hollow(sh, HEART_L, HEART_SIZES, SEED, LIGHT, strokes=strokes)
    lines = overlap_lines(sh, line, ("upper_arm", "forearm", "wrist", "fore_paw"), ("torso", "far_fore"),
                          HEART_START, HEART_REACH)
    img = paint_strokes(img, lines, line, HEART_L)
    keeps = [radial_keep(c, r, 1.2) for c, r in HEART_FADES]
    (x0, y0), (wx, wy) = HEART_BACK_RAMP
    keeps.append(np.clip((sd.xs - x0) / wx + (sd.ys - y0) / wy, 0, 1))
    img = dissolved(img, HEART_L, keeps)
    return sd.sun_clamp(img)


# --- stage 4: the mane (the final's mane, 1.3x about Algieba) --------------------------------

MANE_L = [(110, 224), (90, 200), (84, 170), (100, 142), (126, 128), (150, 140), (56, 150)]
MANE_SEGMENTS = [(0, 1), (1, 2), (2, 3), (3, 4), (4, 5), (2, 6)]
MANE_SIZES = ["M", "S", "B", "M", "S", "M", "S"]
MANE_SCALE = 1.3
MANE_T = repose((102, 124), (84, 169), MANE_SCALE, -3.0)   # the final's Algieba onto star 2
# MANE_MASS, its soft round top raised over the ear's place (the ear is the head's).
MANE_MASS = [(144, 96), (138, 89), (130, 87.5), (122, 90), (118, 93), (108, 96), (100, 104), (97, 118),
             (98, 132), (101, 144), (108, 154), (118, 160), (128, 157), (138, 150), (144, 144), (145, 130),
             (145, 104)]
# MANE_REAR, the top flame arching further back over the withers and down to star 6.
MANE_REAR = [((130, 94), (102, 89), (75, 113), 6.0),
             ((120, 98), (104, 97), (94, 108), 7.0),
             ((113, 111), (98, 114), (90, 126), 7.5),
             ((110, 125), (98, 130), (93, 141), 7.0)]
# CROWN_TUFTS, the last lying further down over the brow (star 5), as a forelock.
MANE_CROWN_TUFTS = [((141.5, 94.5), (143.5, 87), (148.2, 91.6), 2.8),
                    ((146, 96.5), (148.5, 90), (152.6, 95), 2.6),
                    ((149.5, 98.5), (156.5, 95), (155, 109), 3.6)]
# MANE_CHEST and below it the chest fringe hanging longer for stars 1 and 0, and one long lock.
MANE_CHEST = [((110, 137.5), 7.0, 5.2), ((122, 143), 7.5, 5.8), ((135, 145), 7.0, 5.6), ((146.5, 142), 5.5, 5.0),
              ((106, 146), 6.5, 5.2), ((118, 151), 7.0, 5.5), ((131, 151), 6.0, 5.0),
              ((113, 158), 6.0, 5.0), ((124, 160), 6.0, 5.0)]
MANE_CHEST_LOCK = ((121, 160), (120.5, 167), (124, 174), 4.5)
# FACE_RUFF without the throat (the head's): its front the face's back outline, the cheek's locks
# lying forward, so the mane stops where the face begins.
MANE_FACE_RUFF = [(150.6, 97.6), (145.6, 95.4), (141, 94.4), (136, 94.4), (131.4, 94.6),
                  (129.6, 93.2), (127, 94.6), (125.6, 98.5), (126.2, 102.5), (123.5, 106.5), (125.5, 110.5),
                  (126, 117), (130.5, 116.5), (127.5, 123), (123.5, 134), (129, 133.5), (128, 140), (126, 152),
                  (133.5, 147), (137, 151), (141.5, 158.5), (146, 150.5), (151, 152), (150, 145), (151, 137),
                  (149, 130), (148.2, 125.6), (150.4, 122.6), (147.6, 120.2), (149.8, 116.4), (147.8, 113.2),
                  (150, 109.4), (148.6, 106), (150.6, 103.2), (152.5, 100.5)]


def mane_tuft(root, bend, tip, w):
    return tuft(MANE_T(root), MANE_T(bend), MANE_T(tip), w * MANE_SCALE)


def mane_shapes():
    """The final's mane group, back to front, in the stage's layout."""
    out = []

    def add(name, pts4):
        out.append({"name": name, "part": "mane", "group": "mane", "d": cl.path_of(pts4)})

    add("mane_mass", cl.outline([MANE_T(p) for p in MANE_MASS], 6))
    for k, f in enumerate(MANE_REAR):
        add(f"rear{k}", mane_tuft(*f))
    for k, (c, rx, ry) in enumerate(MANE_CHEST):
        add(f"chest{k}", cl.outline(chest_ring(c, rx, ry, MANE_T), 6))
    add("chest_lock", mane_tuft(*MANE_CHEST_LOCK))
    for k, f in enumerate(MANE_CROWN_TUFTS):
        add(f"crown{k}", mane_tuft(*f))
    add("face_ruff", cl.outline([MANE_T(p) for p in MANE_FACE_RUFF], 6))
    return out


def mane_fades():
    """The final's crown and ruff locks."""
    k = MANE_SCALE
    out = {}
    for pts, hold, reach in ([(c, 1, 5) for c in CROWN_LOCKS] + [(c, 2, 6) for c in RUFF_LOCKS]):
        for p, s in fade_stroke([MANE_T(q) for q in pts], hold * k, reach * k, cl.LINE_STEPS + 1).items():
            out[p] = max(out.get(p, 0), s)
    return out


def paint_mane():
    sh = mane_shapes()
    line, groups, _ = cl.draw(sh)
    on_form(groups, MANE_L, "mane")
    img, parts = cl.semi_hollow(sh, MANE_L, MANE_SIZES, SEED, LIGHT)
    img = thin_mane(img, parts, line, MANE_L)
    img = paint_strokes(img, mane_fades(), line, MANE_L)
    return sd.sun_clamp(img)


# --- stage 5: the head (the final's head and mane, 1.5x about the eye, lifted) ----------------

HEAD_L = [(40, 150), (64, 124), (94, 108), (124, 118), (146, 144), (112, 148)]
HEAD_SEGMENTS = [(0, 1), (1, 2), (2, 3), (3, 4), (3, 5)]
HEAD_SIZES = ["M", "S", "S", "M", "S", "B"]
HEAD_SCALE = 1.5
HEAD_TURN = -24.0          # degrees; negative lifts the muzzle
HEAD_MANE_TURN = -18.0     # the mane turns less: it hangs from the neck while the head lifts
HEAD_T = repose((154, 110), (124, 118), HEAD_SCALE, HEAD_TURN)   # the final's eye onto star 3


def head_m(p):
    """A final-layout mane point in the stage's layout."""
    return HEAD_T(p, HEAD_MANE_TURN)


# The final's head, as approved (the final's layout, game px).
HEAD_OUTLINE = [(149.5, 102), (153, 101.6), (157, 101.2), (160.5, 100.8), (162.8, 100.6),
                (163, 102.4), (161.4, 103.4), (163, 104.4), (167, 107), (170.8, 109.6), (174, 111.8),
                (175.5, 113.5), (175.6, 116), (175.6, 120.5), (174.6, 121.8), (172.2, 122.4), (171.6, 123.3),
                (171.6, 125.6), (170.4, 127), (167, 127.4), (161, 127.4), (155, 127.2), (151, 126.8),
                (148.2, 125.6), (150.4, 122.6), (147.6, 120.2), (149.8, 116.4), (147.8, 113.2), (150, 109.4),
                (148.6, 106), (150.6, 103.2)]
HEAD_MOUTH = [(171.5, 122.5), (168, 123), (165, 123.6), (162.5, 124.4)]
HEAD_EAR = [(132.6, 97), (132.2, 90.6), (132.8, 86.8), (134.4, 84.4), (136.4, 83.8), (138.4, 84.6), (139.6, 87.4),
            (140, 92), (140, 97)]
HEAD_JAW = [(168.5, 127.4), (161, 127.5), (155, 127.2), (151, 126.6), (148.6, 125.2), (150.2, 122.6),
            (148, 120), (149.6, 116.4), (148.2, 113)]
HEAD_MANE_MASS = [(138, 100), (128, 97), (118, 93), (108, 96), (100, 104), (97, 118), (98, 130), (104, 138),
                  (114, 141), (130, 142), (148, 141), (151, 130), (146, 104)]
HEAD_MANE_REAR = [((132, 95), (121, 90), (110, 95), 5.0),
                  ((120, 98), (104, 97), (94, 108), 7.0),
                  ((113, 111), (98, 114), (90, 126), 7.5),
                  ((110, 125), (98, 130), (93, 141), 7.0)]
HEAD_CROWN_TUFTS = [((141.5, 94.5), (143.5, 87), (148.2, 91.6), 2.8),
                    ((146, 96.5), (148.5, 90), (152.6, 95), 2.6),
                    ((150.5, 99), (153, 93.4), (157, 99.4), 2.4)]
HEAD_MANE_CHEST = MANE_CHEST[:4]
HEAD_FACE_RUFF = [(158.4, 101), (155.4, 99.8), (150.6, 97.6), (145.6, 95.4), (141, 94.4),
                  (136, 94.4), (131.4, 94.6),
                  (129.6, 93.2), (127, 94.6), (125.6, 98.5), (126.2, 102.5), (123.5, 106.5), (125.5, 110.5),
                  (126, 117), (130.5, 116.5), (127.5, 123), (123.5, 134),
                  (129, 133.5), (128, 140), (126, 152), (133.5, 147), (137, 151), (141.5, 158.5), (146, 150.5),
                  (151, 153), (155.5, 151), (158, 146.5), (161.5, 144.5), (164.5, 139.5), (166.5, 133),
                  (166.5, 128.5), (160, 126), (153, 124), (153.5, 112), (154, 103), (158.8, 101.8), (161.8, 100.6)]
# The final's eye at 1x: a dark almond (4.4 x 2.6 px half-axes) round the star, its upper lid lit.
HEAD_EYE_HALF = (4.4, 2.6)
HEAD_FADE = ((6, 150), 64.0)   # the mane behind the head dissolves away from here
# The chest ruff under the lifted chin dissolves downward (kept above NECK[0], gone at NECK[1]).
HEAD_NECK = (140, 180)


def head_tuft(root, bend, tip, w, turn=None):
    return tuft(HEAD_T(root, turn), HEAD_T(bend, turn), HEAD_T(tip, turn), w * HEAD_SCALE)


def head_shapes():
    """The final's head-end group, back to front, in the stage's layout."""
    out = []

    def add(name, part, pts4):
        out.append({"name": name, "part": part, "group": "mane", "d": cl.path_of(pts4)})

    add("mane_mass", "mane", cl.outline([head_m(p) for p in HEAD_MANE_MASS], 6))
    for k, f in enumerate(HEAD_MANE_REAR):
        add(f"rear{k}", "mane", head_tuft(*f, turn=HEAD_MANE_TURN))
    for k, (c, rx, ry) in enumerate(HEAD_MANE_CHEST):
        add(f"chest{k}", "mane", cl.outline(chest_ring(c, rx, ry, head_m), 6))
    for k, f in enumerate(HEAD_CROWN_TUFTS):
        add(f"crown{k}", "mane", head_tuft(*f))
    add("ear", "head", cl.outline([HEAD_T(p) for p in HEAD_EAR], 6))
    add("face_ruff", "mane", cl.outline([head_m(p) for p in HEAD_FACE_RUFF], 6))
    add("head", "head", [tuple(v(HEAD_T(p)) * 4) for p in HEAD_OUTLINE])
    return out


def head_strokes():
    pts = [HEAD_T(p) for p in HEAD_MOUTH]
    return [{"name": "mouth", "part": "head", "d": cl.path_of([(x * 4 + 2, y * 4 + 2) for x, y in pts])[:-2]}]


def head_fades():
    """The final's fades: the jaw and the cheek's lock, the crown and ruff locks (placed by the
    re-pose but keeping the final's own slant: turned, the locks hang plumb and read as rain)."""
    k = HEAD_SCALE
    out = fade_stroke([HEAD_T(p) for p in HEAD_JAW], 19 * k, 10 * k)
    for pts, hold, reach in ([(c, 1, 5) for c in CROWN_LOCKS] + [(c, 2, 6) for c in RUFF_LOCKS]):
        place = HEAD_T if pts in CROWN_LOCKS else head_m
        a0 = v(place(pts[0]))
        placed = [tuple(a0 + (v(q) - v(pts[0])) * HEAD_SCALE) for q in pts]
        for p, s in fade_stroke(placed, hold * k, reach * k, cl.LINE_STEPS + 1).items():
            out[p] = max(out.get(p, 0), s)
    return out


def head_eye(img, line):
    """The final's eye at this size: a slanted dark almond (sky) round star 3 in a ring of stardust
    three steps up, its upper lid lit, no pale speck near it."""
    sky = sd.sky_index()
    cx, cy = HEAD_L[3]
    a = math.radians(HEAD_TURN + 8)   # the final's eye slants a little, front corner lower
    u = np.array([math.cos(a), math.sin(a)])
    w = np.array([-u[1], u[0]])
    hx, hy = HEAD_EYE_HALF[0] * HEAD_SCALE, HEAD_EYE_HALF[1] * HEAD_SCALE
    for y in range(cy - 10, cy + 11):
        for x in range(cx - 10, cx + 11):
            d = np.array([x - cx, y - cy], float)
            e = (d @ u / hx) ** 2 + (d @ w / hy) ** 2
            if e <= 1.0 and not line[y, x]:
                img[y, x, :3] = sd.PAL[sd.N[sky[y, x] + 2]]
                img[y, x, 3] = 255
            if img[y, x, 3] and not line[y, x] and e <= 3.0 and tuple(int(c) for c in img[y, x, :3]) in (
                    sd.PAL["D0"], sd.PAL["N9"], sd.PAL["N8"]):
                img[y, x, :3] = sd.PAL[sd.N[sky[y, x] + 3]]
    # the dark almond inside (sky) round the star's own pixel, and the lit upper lid
    for y in range(cy - 10, cy + 11):
        for x in range(cx - 10, cx + 11):
            d = np.array([x - cx, y - cy], float)
            e = (d @ u / (hx * 0.72)) ** 2 + (d @ w / (hy * 0.62)) ** 2
            if e <= 1.0 and (x, y) != (cx, cy):
                img[y, x] = 0
    for t in np.linspace(-1, 1, 40):
        p = v((cx, cy)) + u * hx * t * 0.95 - w * hy * (1 - t * t) ** 0.5 * 1.05
        x, y = int(round(p[0])), int(round(p[1]))
        img[y, x, :3] = sd.PAL[sd.N[min(sky[y, x] + cl.LINE_STEPS + 1, 9)]]
        img[y, x, 3] = 255
    return img


def paint_head():
    sh = head_shapes()
    line, groups, _ = cl.draw(sh, head_strokes())
    on_form(groups, HEAD_L, "head")
    img, parts = cl.semi_hollow(sh, HEAD_L, HEAD_SIZES, SEED, LIGHT, strokes=head_strokes())
    img = thin_mane(img, parts, line, HEAD_L)
    img = paint_strokes(img, head_fades(), line, HEAD_L)
    img = head_eye(img, line)
    neck = np.clip((HEAD_NECK[1] - sd.ys) / (HEAD_NECK[1] - HEAD_NECK[0]), 0, 1) ** 0.8
    img = dissolved(img, HEAD_L, [radial_keep(*HEAD_FADE, 1.2), neck])
    return sd.sun_clamp(img)


# --- the stages ----------------------------------------------------------------------------

STAGES = {
    "tail": (TAIL_L, TAIL_SEGMENTS, TAIL_SIZES, paint_tail),
    "haunch": (HAUNCH_L, HAUNCH_SEGMENTS, HAUNCH_SIZES, paint_haunch),
    "heart": (HEART_L, HEART_SEGMENTS, HEART_SIZES, paint_heart),
    "mane": (MANE_L, MANE_SEGMENTS, MANE_SIZES, paint_mane),
    "head": (HEAD_L, HEAD_SEGMENTS, HEAD_SIZES, paint_head),
}
SIZE_CODES = {"SMALL": "S", "MEDIUM": "M", "BIG": "B"}


def stage_maps():
    """Each Leo part stage's landmarks, segments and sizes, read from game/core/star_map.gd."""
    src = STAR_MAP.read_text()
    found = {}
    for part in PARTS:
        block = re.search(r"static func leo_%s\(\) -> StarMap:(.*?)\n\n\n" % part, src, re.S).group(1)

        def pairs(field):
            body = re.search(r"map\.%s = \[(.*?)\]\n" % field, block).group(1)
            return [(int(x), int(y)) for x, y in re.findall(r"Vector2i\((-?\d+), (-?\d+)\)", body)]

        sizes = re.search(r"map\.sizes = \[(.*?)\]\n", block).group(1)
        found[part] = (pairs("landmarks"), pairs("segments"),
                       [SIZE_CODES[s] for s in re.findall(r"Star\.Size\.(\w+)", sizes)])
    return found


def build_parts():
    """Writes each part stage's own painting, leo_part_<part>.png."""
    ART.mkdir(parents=True, exist_ok=True)
    maps = stage_maps()
    for part in PARTS:
        landmarks, segments, sizes, paint = STAGES[part]
        assert maps[part] == (landmarks, segments, sizes), \
            f"{part}: the painting's stars differ from StarMap.leo_{part}()"
        img = paint()
        used = sd.check(img)
        print(f"part {part}: {sum(used.values())} px, {used}")
        sd.save(img, ART / f"leo_part_{part}.png")


if __name__ == "__main__":
    build_parts()
