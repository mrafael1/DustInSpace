"""Aquarius's part-stage paintings (chapter 2), in assets/art/:

  aquarius_part_<part>.png    each part stage's own painting (hand, body, legs, stream, jar), shown
                              when that stage is complete

The same clean-line semi-hollow style as the whole figure (tools/art/build_aquarius_figure.py,
tools/art/clean_line.py, tools/art/stardust.py): one silhouette per stage, outlined only round the
union, hollow with stardust inside, lit from the upper left. Each body part is the final's own,
re-posed and scaled to its stage's stars (StarMap.aquarius_<part>() in game/core/star_map.gd; each
stage's landmarks and sizes are checked against that file, the one source of truth). Every star sits
on the form with a clear gap from the line.

  hand    the far arm, mirrored: a round deltoid at the shoulder (star 0), the upper arm tapering to
          the elbow at star 2 (a small elbow point underneath), the forearm swelling past the elbow
          to a pinched wrist, the open hand palm out (star 4 on the palm), the thumb spread up and
          four rounded finger tips with short clefts (1 px strokes)
  body    the youth bracing against the leftward current, leaning back: the pixel-drawn classical
          head (curly hair in denser stardust, an ear, a lit eye; star 0 on the cheek), the laid-back
          V torso and hip cloth (star 1 below the collarbone, star 2 the hip), the near leg stretched
          forward to a pointed foot (stars 3, 4), the far knee dropped behind (star 5), its foot on
          its toes; the near arm out forward, the far arm trailing back to the final's open hand
  legs    the hip cloth over the thighs (star 0), the near leg (knee bump, the shin with its calf, a
          flat foot, stars 1-3) and the far leg from behind the near thigh (its calf, star 4, a pinched
          ankle and the foot on its toes, heel up and round at Skat, star 5), about 1.45x the final's
  stream  the poured water: a main lock from a narrow root (star 0) swinging through two bends and
          widening on its long run down-right to a curl past the last star, four companion locks of
          different widths peeling off into curls, swaying together, with 2-3 px bubbles round them
  jar     the final's pot (a short flat foot, a round belly, a pinched neck, a flared lip, no handle)
          standing nearly upright, scaled so the Y's arms sit in its broadest belly; the water leaves
          the lip as one narrow pour fanning into three swaying locks, the widest through the spout
          star; the near hand that holds the pot in the final is left out

No colour outside the Stellar Sun palette; every pixel opaque or empty.

The whole figure and its chart pieces are built by tools/art/build_aquarius_figure.py, which also
runs this module.

Run: python tools/art/aquarius_part_paintings.py   (needs Pillow and numpy)
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
PARTS = ("hand", "body", "legs", "stream", "jar")
SEED = 11
LIGHT = np.array([-0.55, -0.65, 0.52])  # the final's light: upper left
SKY = sd.sky_index()


# --- shared shapes (4x points, as clean_line draws them) -----------------------------------

def v(p):
    return np.array(p, float)


def interp(prof, f):
    fs, ws = zip(*prof)
    return float(np.interp(f, fs, ws))


def swayed(spine, sway):
    """The spine swayed sideways on a sine (amplitude, wavelength, phase), easing in at both ends."""
    amp, lam, phase = sway
    ax = cl.Axis([v(p) for p in spine])
    out = []
    for s in np.linspace(0, ax.L, max(8, int(ax.L / 3))):
        c, t, nrm = ax.frame(s)
        ease = min(1.0, s / 16.0) * min(1.0, (ax.L - s) / 14.0)
        out.append(tuple(c + nrm * amp * math.sin(phase + 2 * math.pi * s / lam) * ease))
    return out


def band(spine, prof, n=80, wave=None, sway=None, sides=(1.0, 1.0)):
    """A closed band along `spine` (game px), half-width prof [(fraction, hw)], round at both ends,
    optionally its edges rippled (`wave`) and its spine swayed (`sway`). 4x points."""
    if sway:
        spine = swayed(spine, sway)
    ax = cl.Axis([v(p) * 4 for p in spine])
    left, right = [], []
    for i in range(n + 1):
        s = ax.L * i / n
        c, t, nrm = ax.frame(s)
        w = interp(prof, i / n) * 4
        wl = wr = w
        if wave:
            amp, waves, phase = wave
            ramp = min(1.0, i / n * 4, (1 - i / n) * 5)
            wl = w + sides[0] * amp * 4 * math.sin(phase + i / n * waves * 2 * math.pi) * ramp
            wr = w + sides[1] * amp * 4 * math.sin(phase + 2.2 + i / n * waves * 2 * math.pi) * ramp
        left.append(c + nrm * wl)
        right.append(c - nrm * wr)
    c1, t1, n1 = ax.frame(ax.L)
    w1 = interp(prof, 1.0) * 4
    cap1 = [c1 + t1 * w1 * math.sin(a) + n1 * w1 * math.cos(a) for a in np.linspace(0, math.pi, 9)[1:-1]]
    c0, t0, n0 = ax.frame(0)
    w0 = interp(prof, 0.0) * 4
    cap0 = [c0 - t0 * w0 * math.sin(a) - n0 * w0 * math.cos(a) for a in np.linspace(0, math.pi, 9)[1:-1]]
    return left + cap1 + right[::-1] + cap0


def limb(spine, widths):
    """A band whose half-widths are given at each spine point."""
    d = np.concatenate([[0], np.cumsum(np.linalg.norm(np.diff(np.array(spine, float), axis=0), axis=1))])
    return band(spine, list(zip(d / d[-1], widths)))


def ellipse(c, a, b, deg, k):
    t = math.radians(deg)
    u, n = np.array([math.cos(t), math.sin(t)]), np.array([-math.sin(t), math.cos(t)])
    return [(v(c) + u * a * math.cos(q) + n * b * math.sin(q)) * 4 for q in np.linspace(0, 2 * math.pi, k, endpoint=False)]


def circle(c, r, k=14):
    return [v(c) * 4 + r * 4 * np.array([math.cos(a), math.sin(a)]) for a in np.linspace(0, 2 * math.pi, k, endpoint=False)]


def curl_tail(start, centre, r0, turn, sign):
    """A lock's tail rolling up round `centre` into a tight curl."""
    s, c = v(start), v(centre)
    a0 = math.atan2(s[1] - c[1], s[0] - c[0])
    rs = np.linalg.norm(s - c)
    pts = []
    for k in range(1, 7):
        f = k / 6
        a = a0 + sign * turn * f
        r = rs + (r0 - rs) * f
        pts.append(tuple(c + r * np.array([math.cos(a), math.sin(a)])))
    return pts


def rows_path(rows):
    """A path covering pixel rows {y: [(x0, x1), ...]}."""
    subs = []
    for y, spans in rows.items():
        for x0, x1 in spans:
            subs.append(cl.path_of([(x0 * 4, y * 4), ((x1 + 1) * 4, y * 4), ((x1 + 1) * 4, (y + 1) * 4),
                                    (x0 * 4, (y + 1) * 4)]))
    return " ".join(subs)


def steps_over_sky(img, y, x, k):
    img[y, x, :3] = sd.PAL[sd.N[SKY[y, x] + k]]
    img[y, x, 3] = 255


def near_only(img, form, reach=6):
    """No stray specks far off the form."""
    img[sd.distance_inside(~form) > reach] = 0
    return img


def on_form(groups, landmarks, stage):
    for x, y in landmarks:
        assert groups[y, x] >= 0, f"{stage}: star at {x},{y} is off the form"


# --- stage 1: the hand ---------------------------------------------------------------------

HAND_L = [(146, 104), (120, 126), (94, 148), (64, 166), (36, 186)]
HAND_SIZES = ["B", "S", "M", "S", "M"]
HAND_SHOULDER = (148.0, 101.0)            # the joint, under the deltoid
HAND_ELBOW = (94.5, 147.5)                # star 2, where the stars' line bends
# The upper arm: deltoid, biceps, tapering to the elbow (the final's FAR_UPPER widths, scaled).
HAND_UPPER = [HAND_SHOULDER, (134, 113), (120, 125.5), (107, 136.5), HAND_ELBOW]
HAND_UPPER_W = [11.0, 9.6, 8.0, 6.8, 6.0]
# The forearm: swelling just below the elbow, narrowing to the wrist (FAR_FORE's widths).
HAND_FORE_W = [6.0, 7.0, 5.8, 4.6, 3.6]
HAND_DELTOID = ((134.7, 109.5), 13.0, 9.5, -40.8)    # swelling on the outer (lit) side
HAND_ELBOW_POINT = ((96.6, 150.6), 3.2)                # the olecranon, on the underside
HAND_BICEPS = ((112.0, 134.4), 19.0, 7.6, 139.2)       # on the underside
HAND_FORE_SWELL = ((83.0, 154.0), 9.5, 6.6, 146.0)    # the forearm's muscle, just past the elbow
# The open hand, palm out, as in the final (FAR_HAND): the thumb spread up from the palm's upper side,
# the fingers held together, ending in rounded tips with short clefts between them. Local px: x from
# the wrist along the hand, y to its upper side. The wrist bends the hand up a little (HAND_ANGLE).
HAND_ANGLE = 165.0
HAND_PALM_STAR = (9.0, -1.0)   # where star 4 sits on the palm, local
HAND_SCALE = 1.2               # the hand's local px to game px
HAND_OUTLINE = [
    (0, -3.8), (5, -6.0), (10, -7.0), (15, -6.8),
    (19, -6.6), (22, -5.8), (23, -4.6), (22.4, -3.6), (20.5, -3.3),          # little finger
    (24, -3.4), (26.6, -2.6), (27.2, -1.2), (26.5, -0.1), (24, 0.1),         # ring
    (25, 0.2), (27.6, 0.8), (28.2, 2.2), (27.4, 3.4), (25, 3.5),             # middle
    (26.6, 3.9), (27.2, 5.3), (26.2, 6.6), (22, 6.9), (17, 7.0),             # index
    (15, 7.4), (16.8, 10.2), (18.2, 13.6), (17.8, 15.9), (15.8, 16.5), (13.8, 14.6), (10.6, 10.4),
    (6.5, 7.6), (3, 5.0),                                                     # thumb
    (0, 3.8)]
HAND_CLEFTS = [[(20.5, -3.3), (16.5, -3.4)], [(24, 0.1), (17.5, 0.1)], [(25, 3.5), (18.5, 3.5)]]


def hand_frame():
    a = math.radians(HAND_ANGLE)
    u = np.array([math.cos(a), math.sin(a)])
    up = np.array([u[1], -u[0]])
    if up[1] > 0:
        up = -up
    return u, up


HAND_WRIST = np.array(HAND_L[4], float) - (hand_frame()[0] * HAND_PALM_STAR[0]
                                           + hand_frame()[1] * HAND_PALM_STAR[1]) * HAND_SCALE
# The forearm's spine, from the elbow through star 3 to the wrist the hand fixes.
HAND_FORE = [HAND_ELBOW, (82, 155.5), (68, 165), (57, 173), tuple(HAND_WRIST)]


def hand_local(x, y):
    u, up = hand_frame()
    return HAND_WRIST + (u * x + up * y) * HAND_SCALE


def hand_clefts():
    out = []
    for k, (p0, p1) in enumerate(HAND_CLEFTS):
        q0, q1 = hand_local(*p0), hand_local(*p1)
        out.append({"name": f"cleft{k}", "part": "hand",
                    "d": f"M {q0[0] * 4 + 2:.1f} {q0[1] * 4 + 2:.1f} L {q1[0] * 4 + 2:.1f} {q1[1] * 4 + 2:.1f}"})
    return out


def hand_shapes():
    out = []

    def add(name, pts):
        out.append({"name": name, "part": "hand", "group": "arm", "d": cl.path_of(pts)})

    add("upper_arm", limb(HAND_UPPER, HAND_UPPER_W))
    add("deltoid", ellipse(*HAND_DELTOID, k=20))
    add("biceps", ellipse(*HAND_BICEPS, k=20))
    add("elbow", circle(*HAND_ELBOW_POINT))
    add("forearm", limb(HAND_FORE, HAND_FORE_W))
    add("forearm_swell", ellipse(*HAND_FORE_SWELL, k=20))
    add("hand", cl.outline([hand_local(x, y) for x, y in HAND_OUTLINE], 5))
    return out


def paint_hand():
    sh = hand_shapes()
    line, groups, parts = cl.draw(sh, hand_clefts())
    on_form(groups, HAND_L, "hand")
    img, _ = cl.semi_hollow(sh, HAND_L, HAND_SIZES, SEED, LIGHT, strokes=hand_clefts())
    return near_only(img, groups >= 0)


# --- stage 2: the body ---------------------------------------------------------------------

BODY_L = [(146, 104), (128, 132), (104, 156), (72, 178), (32, 196), (140, 190)]
BODY_SIZES = ["M", "S", "B", "S", "M", "S"]
# The final's head, drawn pixel by pixel (game px, the final's layout), moved whole.
FINAL_FAR_FOOT = [(103, 200), (106.5, 198.5), (110, 199.5), (112, 203), (112, 208), (111, 212), (107.5, 214),
                  (102.5, 214), (100.5, 212.5), (102.5, 211), (104.5, 208), (103.5, 204)]
FINAL_FAR_ANKLE = (104.5, 202)
HEAD_ROWS = {
    84: [(102, 103), (106, 107), (110, 110)],
    85: [(100, 112)], 86: [(99, 114)], 87: [(98, 115)], 88: [(97, 116)], 89: [(98, 116)], 90: [(98, 117)],
    91: [(98, 117)], 92: [(98, 117)], 93: [(97, 116)], 94: [(98, 117)], 95: [(97, 116)], 96: [(96, 116)],
    97: [(95, 116)], 98: [(94, 115)], 99: [(97, 115)], 100: [(97, 114)], 101: [(96, 113)], 102: [(97, 112)],
    103: [(98, 111)], 104: [(97, 110)], 105: [(97, 109)], 106: [(98, 109)], 107: [(100, 108)], 108: [(102, 107)],
}
EYE = (99, 95)
BROW = [(98, 93), (99, 93), (100, 93)]
HAIRLINE = {88: 99, 89: 100, 90: 101, 91: 102, 92: 103, 93: 104, 94: 105, 95: 106, 96: 107, 97: 108,
            98: 108, 99: 108, 100: 109, 101: 109, 102: 109, 103: 109}
CURL_MARKS = [(104, 87), (105, 86), (106, 87), (109, 88), (110, 87), (111, 88), (112, 91), (113, 90),
              (114, 91), (110, 93), (111, 92), (112, 93), (114, 95), (115, 94), (113, 98), (114, 97),
              (111, 101), (112, 100), (107, 90), (108, 91), (101, 87), (100, 88)]
EAR = [(107, 95), (108, 95), (109, 96), (109, 97), (108, 98)]

# The head moved whole (rows unchanged) so star 0 sits on the cheek, between the eye and the ear.
HX, HY = 43, 7
HEAD_BAND = (84 + HY - 1, 108 + HY, 92 + HX, 121 + HX)
# The torso and hip cloth laid back along the line from the neck base to the hip centre.
BODY_NECK_BASE, BODY_HIP = (151.0, 125.0), (107.0, 154.0)
_U = (v(BODY_HIP) - v(BODY_NECK_BASE)) / np.linalg.norm(v(BODY_HIP) - v(BODY_NECK_BASE))  # down the body
_F = np.array([-_U[1], _U[0]])                                                             # toward the chest
# The torso, the final's proportions (shoulders about 34 px across, the waist 21): the traps rising to
# the neck, the round front shoulder, the chest, the belly to the hip; the back down from the far
# shoulder and blade, tapering at the waist and swelling into the seat. (a along the body, p forward.)
BODY_TORSO = [(-3, 5), (1, 10), (5, 13.5), (11, 15), (18, 14.5), (26, 13), (34, 12), (42, 12.5), (49, 11),
              (55, 4), (57, -4), (54, -10), (47, -12), (40, -9), (33, -10), (24, -14), (14, -17.5), (6, -18),
              (0, -14), (-3, -6)]
# The hip cloth wrapped round the hips, its front hem broad and level over the near thigh.
BODY_DRAPE = [(38, 13), (40, 3), (39, -11), (45, -13), (52, -12.5), (56, -5), (57, 6), (55, 13.5), (47, 14)]
BODY_NECK = [(149.0, 112.0), (149.5, 118.0), (151.0, 125.0)]
BODY_NEAR_THIGH = [(104, 158), (88, 168.5), (73, 177.5)]
BODY_NEAR_KNEE = (71.5, 178.5)
BODY_NEAR_SHIN = [(70, 180), (58, 185.5), (47, 190), (41, 192.5)]
# A pointed foot carrying on the leg's line: the ankle, the instep, the toes, the sole and the heel.
BODY_NEAR_FOOT = [(44, 188.5), (38, 190), (31, 193), (25, 197), (21, 200.5), (22, 202.5), (27, 202),
                  (33, 200), (39, 198.5), (45, 197.5), (47, 193)]
BODY_FAR_THIGH = [(113, 156), (126, 172), (139, 188)]
BODY_FAR_KNEE = (140.5, 190.5)
BODY_FAR_SHIN = [(141, 191), (151, 194), (159, 195)]
BODY_FAR_ANKLE = (159.5, 195.0)
# The near arm out forward for balance, the far arm trailing back and down.
BODY_NEAR_UPPER = [(138, 127.5), (131, 125), (125, 122.5), (120, 120.5)]
BODY_NEAR_FORE = [(120, 120), (112, 116.5), (104, 113)]
BODY_NEAR_HAND = [(105, 110), (100, 108.5), (96, 109), (94, 111), (97, 113), (101, 115.5), (105, 116.5)]
BODY_FAR_UPPER = [(155, 135), (159, 142), (162.5, 149), (165, 155)]
BODY_FAR_FORE = [(165, 155), (166.5, 161), (167, 166), (167, 171)]
# The final's open hand (palm out, thumb spread, two finger lobes), turned to hang from the wrist.
FINAL_FAR_HAND = [(143, 151.5), (146, 150.2), (149.2, 146.4), (151.4, 145.6), (152.6, 146.8), (151, 150.8),
                  (154, 151.2), (158.5, 151.6), (162, 153.2), (161.8, 155.2), (156.6, 155.8), (160.6, 158),
                  (159.4, 160), (152, 160.8), (146.5, 159.5), (143, 157)]


def body_frame(pts):
    """(a along the body from the neck base, p toward the chest) on the screen."""
    return [tuple(v(BODY_NECK_BASE) + _U * a + _F * p) for a, p in pts]


def hang(pts, wrist=(143, 154), to=(167, 171), deg=78, k=0.8):
    a = math.radians(deg)
    c, s_ = math.cos(a), math.sin(a)
    return [(to[0] + k * ((x - wrist[0]) * c - (y - wrist[1]) * s_), to[1] + k * ((x - wrist[0]) * s_ + (y - wrist[1]) * c))
            for x, y in pts]


def body_shapes():
    out = []

    def add(name, pts):
        out.append({"name": name, "part": "body", "group": "figure", "d": cl.path_of(pts)})

    add("far_thigh", limb(BODY_FAR_THIGH, [7.0, 6.6, 6.0]))
    add("far_knee", circle(BODY_FAR_KNEE, 5.6, 16))
    add("far_shin", limb(BODY_FAR_SHIN, [5.4, 4.6, 2.6]))
    ox, oy = BODY_FAR_ANKLE[0] - FINAL_FAR_ANKLE[0], BODY_FAR_ANKLE[1] - FINAL_FAR_ANKLE[1]
    add("far_foot", cl.outline([(x + ox, y + oy) for x, y in FINAL_FAR_FOOT], 6))
    add("far_upper", limb(BODY_FAR_UPPER, [5.4, 4.7, 3.9, 3.6]))
    add("far_fore", limb(BODY_FAR_FORE, [3.6, 4.0, 3.4, 2.5]))
    add("far_hand", cl.outline(hang(FINAL_FAR_HAND), 6))
    add("torso", cl.outline(body_frame(BODY_TORSO), 8))
    add("near_thigh", limb(BODY_NEAR_THIGH, [8.2, 6.6, 5.4]))
    add("near_knee", circle(BODY_NEAR_KNEE, 4.8, 16))
    add("near_shin", limb(BODY_NEAR_SHIN, [5.2, 5.4, 4.2, 3.0]))
    add("near_foot", cl.outline(BODY_NEAR_FOOT, 6))
    add("drape", cl.outline(body_frame(BODY_DRAPE), 8))
    add("neck", limb(BODY_NECK, [4.5, 4.4, 6.0]))
    add("near_upper", limb(BODY_NEAR_UPPER, [5.2, 4.8, 4.4, 4.0]))
    add("near_fore", limb(BODY_NEAR_FORE, [3.6, 4.4, 3.4, 2.3]))
    add("near_hand", cl.outline(BODY_NEAR_HAND, 6))
    out.append({"name": "head", "part": "body", "group": "figure",
                "d": rows_path({y + HY: [(a + HX, b + HX) for a, b in r] for y, r in HEAD_ROWS.items()})})
    return out


def head_line(img, form, line):
    """The head's own line off its pixel silhouette (no thinning, keeps nose, lips and curls)."""
    y0, y1, x0, x1 = HEAD_BAND
    bnd = np.zeros_like(form)
    bnd[y0:y1 + 1, x0:x1 + 1] = True
    head = np.zeros_like(form)
    for y, r in HEAD_ROWS.items():
        for a, b in r:
            head[y + HY, a + HX:b + HX + 1] = True
    mine = cl.drop_elbows(cl.edge_inner(form)) & bnd & sd.grow(head, 0)
    for y, x in zip(*np.nonzero(line & bnd & sd.grow(head, 1) & ~mine)):
        img[y, x] = 0
    for y, x in zip(*np.nonzero(mine)):
        lit = not form[y - 1, x] or not form[y, x - 1]
        steps_over_sky(img, y, x, cl.LINE_STEPS + (1 if lit else 0))
    return (line & ~(bnd & sd.grow(head, 1))) | mine, head


def head_detail(img, line, form, head):
    """Hair a denser stardust mass behind the hairline with ring curls, the ear, the face thin, the
    eye a lit pixel in a clear socket under a short brow (the final's head_detail)."""
    def put(xx, yy, k):
        if line[yy, xx]:
            return
        if k == 0:
            img[yy, xx] = 0
            return
        steps_over_sky(img, yy, xx, k)

    for y in range(84 + HY, 109 + HY):
        ry = y - HY
        start = HAIRLINE.get(ry, 999 if ry > max(HAIRLINE) else 0) + HX
        for x in range(start, 122 + HX):
            if head[y, x] and not line[y, x]:
                put(x, y, 2 if sd.BAY[y, x] < 0.5 else 1)
    for pts in (CURL_MARKS, EAR):
        for x, y in pts:
            put(x + HX, y + HY, 3)
    ex, ey = EYE[0] + HX, EYE[1] + HY
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            put(ex + dx, ey + dy, 0)
    for x, y in BROW:
        put(x + HX, y + HY, 4)
    put(ex, ey, 4)
    for y in range(84 + HY, 109 + HY):
        for x in range(80 + HX, 97 + HX):
            if not form[y, x] and not line[y, x]:
                img[y, x] = 0
    return img


def star_clear(img, line, landmarks, sizes):
    """Each star in a clear gap: nothing but the line within 1 px (2 for M and B), no pale speck
    within its STAR_GAP, and its own faint pixel one step above the sky."""
    pale_colours = {sd.PAL[n] for n in ("D0", "N7", "N8", "N9")}
    for (x, y), s in zip(landmarks, sizes):
        r = {"S": 1, "M": 2, "B": 2}[s]
        g = sd.STAR_GAP[s]
        for yy in range(y - g, y + g + 1):
            for xx in range(x - g, x + g + 1):
                if line[yy, xx] or not img[yy, xx, 3]:
                    continue
                near = max(abs(xx - x), abs(yy - y)) <= r
                pale = SKY[yy, xx] < 99 and tuple(img[yy, xx, :3]) in pale_colours
                if near or pale:
                    img[yy, xx] = 0
        steps_over_sky(img, y, x, 1)
    return img


def paint_body():
    sh = body_shapes()
    line, groups, parts = cl.draw(sh)
    form = groups >= 0
    on_form(groups, BODY_L, "body")
    img, _ = cl.semi_hollow(sh, BODY_L, BODY_SIZES, SEED, LIGHT)
    line, head = head_line(img, form, line)
    img = head_detail(img, line, form, head)
    img = near_only(img, form)
    img = star_clear(img, line, BODY_L, BODY_SIZES)
    img[cl.END_PANEL_TOP:] = 0
    return sd.sun_clamp(img)


# --- stage 3: the legs ---------------------------------------------------------------------

LEGS_L = [(124, 100), (96, 124), (68, 148), (34, 166), (116, 154), (140, 184)]
LEGS_SIZES = ["M", "M", "S", "S", "S", "B"]
LEGS_FAR_ANKLE = (133, 176)
LEGS_NEAR_ANKLE = (44, 160)
# The near foot, flat like the final's (heel, a high instep, toes to the left), its sole tipped a
# little with the leg so it reads as a step reaching forward.
LEGS_NEAR_FOOT = [(41.5, 156), (46, 157.5), (49.5, 161), (51, 165.5), (49.5, 169.5), (45, 171.5), (37, 172),
                  (29, 172.5), (24, 172), (22.5, 169.5), (25, 167.5), (31, 165), (36, 161.5)]
# The hip cloth over the top of the thighs: a level waist, its front hem broad and level over the near
# thigh, the ends uneven at the back hip.
LEGS_DRAPE = [(109, 94), (114, 90.5), (121, 88), (129, 86.5), (137, 86), (143, 87.5), (147, 92),
              (148.5, 101), (147.5, 107), (144.5, 112), (139.5, 116), (133.5, 119.5), (127, 121.5),
              (121, 121), (116.5, 117), (112.5, 111.5), (108.5, 106), (107.5, 99)]


def scaled(pts, anchor_from, anchor_to, k):
    """The final's points, scaled by k about `anchor_from` and moved to `anchor_to`."""
    a, b = v(anchor_from), v(anchor_to)
    return [tuple(b + (v(p) - a) * k) for p in pts]


def legs_shapes():
    out = []

    def add(name, pts):
        out.append({"name": name, "part": "legs", "group": "figure", "d": cl.path_of(pts)})

    # The far leg, behind: its thigh hidden under the near one, showing from the knee; the shin down
    # to the right with the calf swelling on its back, a pinched ankle, the foot on its toes.
    add("far_thigh", limb([(130, 98), (113, 113), (100, 128)], [9.6, 8.6, 7.4]))
    add("far_shin", limb([(99, 131), (110, 146), (122, 161), LEGS_FAR_ANKLE], [7.2, 7.6, 6.0, 3.6]))
    add("far_calf", ellipse((114.5, 148.5), 11.0, 5.6, 53.0, k=18))
    add("far_foot", cl.outline(scaled(FINAL_FAR_FOOT, FINAL_FAR_ANKLE, LEGS_FAR_ANKLE, 1.5), 6))
    # The near leg, in front: the thigh from the hip down-left to a knee bump, the shin on down-left
    # with its calf underneath, narrowing to the ankle; a flat foot, toes to the left.
    add("near_thigh", limb([(131, 97), (112, 112), (92, 127)], [10.6, 9.4, 7.6]))
    add("knee", circle((88.0, 127.5), 6.8, 16))
    add("near_shin", limb([(86, 132), (72, 143), (58, 152), LEGS_NEAR_ANKLE], [6.6, 6.4, 5.0, 3.4]))
    add("near_calf", ellipse((74.5, 145.5), 11.0, 5.4, -36.0, k=18))
    add("near_foot", cl.outline(LEGS_NEAR_FOOT, 6))
    add("drape", cl.outline(LEGS_DRAPE, 6))
    return out


def paint_legs():
    sh = legs_shapes()
    line, groups, parts = cl.draw(sh)
    on_form(groups, LEGS_L, "legs")
    img, _ = cl.semi_hollow(sh, LEGS_L, LEGS_SIZES, SEED, LIGHT)
    return near_only(img, groups >= 0)


# --- stage 4: the stream -------------------------------------------------------------------

STREAM_L = [(44, 100), (72, 122), (48, 148), (80, 170), (110, 188), (132, 226)]
STREAM_SIZES = ["S", "M", "S", "M", "S", "M"]
STREAM_SWAY = (1.9, 30, 0.0)  # the final's sway (amplitude, wavelength, phase)
# The main lock's spine: the root just above the source, the first bend round star 1, back left to the
# second bend round star 2, then the long run down-right through 3 and 4 to the curl past 5.
STREAM_MAIN = [(43, 96), (47, 103), (57, 111), (67, 117), (74, 124), (71, 133), (60, 140), (50, 146), (48, 153),
               (56, 161), (68, 166), (81, 171), (96, 179), (110, 189), (122, 203), (129, 216), (132, 229)]
STREAM_MAIN_TAIL = curl_tail((132, 229), (126.5, 232), 1.8, 5.6, 1)
STREAM_MAIN_PROF = [(0, 2.7), (0.05, 3.1), (0.16, 3.8), (0.27, 4.4), (0.4, 4.2), (0.55, 4.6), (0.7, 5.4),
                    (0.8, 5.4), (0.9, 4.8), (0.95, 3.4), (1, 1.6)]
# Companion locks hug the main one (offset off its swayed spine, so they sway with it) and peel off
# into curls: (name, from, to along the main spine as fractions, side (+1/-1), half-width profile,
# gap to the main lock at its start and end (negative: overlap)).
STREAM_COMPANIONS = [
    # thin, round the outside of the first bend, drifting off to the right and rolling up
    ("lock_outer", 0.02, 0.30, 1, [(0, 1.6), (0.3, 2.2), (0.7, 2.6), (1, 2.0)], (-1.0, 3.0)),
    # medium, round the outside of the second bend, falling away under it to the left
    ("lock_bend", 0.40, 0.53, -1, [(0, 2.0), (0.4, 3.0), (1, 2.4)], (-1.5, 3.5)),
    # thin, the long run's upper edge, rolling up at mid height like the final's lock_r
    ("lock_high", 0.58, 0.76, -1, [(0, 1.6), (0.4, 2.4), (1, 2.0)], (-1.0, 3.5)),
    # medium, the long run's lower edge, rolling up beside the last star
    ("lock_low", 0.60, 0.88, 1, [(0, 2.0), (0.3, 3.0), (0.7, 3.2), (1, 2.4)], (-1.0, 3.5)),
]
STREAM_BUBBLES = [((33, 101), 2.2), ((58, 98), 2.0), ((90, 112), 2.2), ((25, 128), 2.0), ((84, 147), 2.4),
                  ((66, 182), 2.0), ((24, 160), 2.0), ((100, 162), 2.2), ((92, 205), 2.4), ((140, 180), 2.0),
                  ((150, 212), 2.2), ((112, 226), 2.6), ((150, 236), 2.0)]


def companion(spine, prof_main, f0, f1, side, prof, gaps):
    """A lock offset off the main lock's (already swayed) spine from fraction f0 to f1, drifting away
    from it, then rolling up into a curl away from it."""
    ax = cl.Axis([v(p) for p in spine])
    pts = []
    for f in np.linspace(f0, f1, max(6, int((f1 - f0) * ax.L / 3))):
        c, t, nrm = ax.frame(f * ax.L)
        u = (f - f0) / (f1 - f0)
        d = interp(prof_main, f) + interp(prof, u) + gaps[0] + (gaps[1] - gaps[0]) * u * u
        if f0 > 0.05:
            d *= min(1.0, 0.4 + u * 3)  # a lock leaving mid-stream starts inside the main one
        pts.append(tuple(c - side * nrm * d))
    end = v(pts[-1])
    t = end - v(pts[-2])
    t /= np.linalg.norm(t)
    out = -side * ax.frame(f1 * ax.L)[2]
    centre = end + out * 5.0
    best = None
    for sign in (1, -1):
        tail = curl_tail(tuple(end), tuple(centre), 1.4, 5.4, sign)
        if np.dot(v(tail[0]) - end, t) > 0:
            best = tail
    return pts + best


def stream_shapes():
    out = []

    def add(name, pts):
        out.append({"name": name, "part": "stream", "group": name, "d": cl.path_of(pts)})

    spine = swayed(STREAM_MAIN + STREAM_MAIN_TAIL, STREAM_SWAY)
    add("lock_main", band(spine, STREAM_MAIN_PROF, n=160, wave=(0.6, 6.0, 2.0), sides=(0.3, 1.0)))
    for name, f0, f1, side, prof, gaps in STREAM_COMPANIONS:
        lock = companion(spine, STREAM_MAIN_PROF, f0, f1, side, prof, gaps)
        f = (len(lock) - 6) / (len(lock) - 1)  # the curl's share: the lock tapers to a fine tip round it
        add(name, band(lock, [(p * f, w) for p, w in prof] + [(1, 1.1)], n=120))
    for k, (c, r) in enumerate(STREAM_BUBBLES):
        add(f"bubble{k}", circle(c, r))
    return out


def paint_stream():
    sh = stream_shapes()
    line, groups, parts = cl.draw(sh)
    on_form(groups, STREAM_L, "stream")
    img, _ = cl.semi_hollow(sh, STREAM_L, STREAM_SIZES, SEED, LIGHT)
    return near_only(img, groups >= 0)


# --- stage 5: the jar ----------------------------------------------------------------------

JAR_L = [(90, 100), (90, 128), (60, 146), (120, 146), (90, 170), (66, 196)]
JAR_SIZES = ["S", "M", "S", "M", "B", "S"]
# The pot, foot (top) to lip (bottom): (y, half-width) game px along a nearly upright axis. The
# final's parts (a short broad flat-ended foot, a round belly, a pinched neck, a flared lip, no
# handle), its belly widened to hold the stage's Y: eta and Sadachbia sit in its broadest part.
JAR_ROWS = [(94, 14.0), (95.2, 15.0), (99.5, 15.2), (101.5, 15.8), (104, 17.4), (108, 20.6), (113, 24.6),
            (120, 29.0), (128, 32.6), (136, 34.4), (144, 34.8), (150, 33.6), (155, 30.0),
            (158.5, 25.0), (161, 18.0), (163, 12.0), (165, 8.6), (167, 8.4), (169, 10.5), (172, 12.8),
            (175.5, 13.4), (178, 12.0)]
JAR_TOP_X, JAR_BOTTOM_X = 91.0, 89.0  # the axis tips a hair to the left: the pot pours that way
JAR_SWAY = (1.4, 30, 0.4)
JAR_POUR = (88.0, 176.0)  # where the water leaves the lip
JAR_BUBBLES = [((98, 186), 2.0), ((37, 185), 2.0), ((96, 205), 2.2), ((34, 211), 2.0),
               ((70, 211), 1.8), ((45, 223), 2.2), ((70, 233), 2.0), ((92, 224), 1.8)]


def jar_shape():
    def x_at(y):
        f = (y - JAR_ROWS[0][0]) / (JAR_ROWS[-1][0] - JAR_ROWS[0][0])
        return JAR_TOP_X + (JAR_BOTTOM_X - JAR_TOP_X) * f
    right = [(x_at(y) + w, y) for y, w in JAR_ROWS]
    left = [(x_at(y) - w, y) for y, w in JAR_ROWS[::-1]]
    return cl.outline(right + left, 8)


def jar_shapes():
    out = []

    def add(name, part, pts):
        out.append({"name": name, "part": part, "group": name, "d": cl.path_of(pts)})

    root = JAR_POUR
    # thin: sweeping out to the left and rolling up
    add("lock_l", "stream", band([root, (85, 182), (78, 185), (68, 186.5), (57, 189), (48, 194), (43, 201)]
                                 + curl_tail((43, 201), (47.5, 203.5), 1.3, 5.4, -1),
                                 [(0, 1.6), (0.15, 1.7), (0.4, 2.4), (0.65, 2.7), (0.82, 2.2), (1, 1.1)],
                                 sway=JAR_SWAY))
    # medium: falling down, drifting left, curling at the bottom
    add("lock_r", "stream", band([root, (89, 185), (88.5, 195), (85, 204), (80.5, 212), (79, 219)]
                                 + curl_tail((79, 219), (83.5, 221), 1.5, 5.6, -1),
                                 [(0, 1.9), (0.12, 2.1), (0.35, 3.0), (0.6, 3.4), (0.82, 2.8), (1, 1.4)],
                                 sway=JAR_SWAY))
    # widest: down and left through the spout star, curling low
    add("lock_m", "stream", band([root, (85.5, 186), (78, 192), (70, 195), (63, 199.5), (57.5, 207), (55, 215),
                                  (56.5, 223)]
                                 + curl_tail((56.5, 223), (61.5, 222), 1.6, 5.6, -1),
                                 [(0, 2.4), (0.08, 2.6), (0.25, 3.6), (0.45, 4.4), (0.62, 4.8), (0.8, 4.2),
                                  (0.92, 3.0), (1, 1.6)], wave=(0.7, 3.0, 2.0), sides=(1.0, 0.2), sway=JAR_SWAY))
    for k, (c, r) in enumerate(JAR_BUBBLES):
        add(f"bubble{k}", "stream", circle(c, r))
    add("jar", "jar", jar_shape())
    return out


def paint_jar():
    sh = jar_shapes()
    line, groups, parts = cl.draw(sh)
    on_form(groups, JAR_L, "jar")
    img, _ = cl.semi_hollow(sh, JAR_L, JAR_SIZES, SEED, LIGHT)
    img = near_only(img, groups >= 0)
    return sd.sun_clamp(img)


# --- the stages ----------------------------------------------------------------------------

STAGES = {
    "hand": (HAND_L, HAND_SIZES, paint_hand),
    "body": (BODY_L, BODY_SIZES, paint_body),
    "legs": (LEGS_L, LEGS_SIZES, paint_legs),
    "stream": (STREAM_L, STREAM_SIZES, paint_stream),
    "jar": (JAR_L, JAR_SIZES, paint_jar),
}
SIZE_CODES = {"SMALL": "S", "MEDIUM": "M", "BIG": "B"}


def stage_maps():
    """Each Aquarius stage's landmarks and sizes, read from game/core/star_map.gd."""
    src = STAR_MAP.read_text()
    found = {}
    for part in PARTS:
        block = re.search(r"static func aquarius_%s\(\) -> StarMap:(.*?)\n\n\n" % part, src, re.S).group(1)
        marks = re.search(r"map\.landmarks = \[(.*?)\]\n", block).group(1)
        sizes = re.search(r"map\.sizes = \[(.*?)\]\n", block).group(1)
        found[part] = ([(int(x), int(y)) for x, y in re.findall(r"Vector2i\((-?\d+), (-?\d+)\)", marks)],
                       [SIZE_CODES[s] for s in re.findall(r"Star\.Size\.(\w+)", sizes)])
    return found


def build_parts():
    """Writes each part stage's own painting, aquarius_part_<part>.png."""
    ART.mkdir(parents=True, exist_ok=True)
    maps = stage_maps()
    for part in PARTS:
        landmarks, sizes, paint = STAGES[part]
        assert maps[part] == (landmarks, sizes), f"{part}: the painting's stars differ from StarMap.aquarius_{part}()"
        img = paint()
        used = sd.check(img)
        print(f"part {part}: {sum(used.values())} px, {used}")
        sd.save(img, ART / f"aquarius_part_{part}.png")


if __name__ == "__main__":
    build_parts()
