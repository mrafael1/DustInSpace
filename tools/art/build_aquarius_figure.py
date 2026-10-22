"""Builds the Aquarius's paintings (chapter 2's rewards), in assets/art/:

  aquarius_figure.png         the whole water carrier, the final stage's reward
  aquarius_piece_<part>.png   the same painting cut into the chapter's five parts (hand, body, legs,
                              stream, jar), in the same full-screen home layout: the chapter chart
                              shows the won ones dormant, then the whole figure once the final is won
  aquarius_part_<part>.png    each part stage's own painting, unchanged in the older shaded-solid
                              style (tools/art/aquarius_part_paintings.py, run from here)

The whole Aquarius is a clean line, semi-hollow with stardust, in the Scorpio's style
(tools/art/build_scorpio_figure.py, tools/art/clean_line.py, tools/art/stardust.py), round the 14
landmarks of StarMap.aquarius() (game/core/star_map.gd).

Pose: a youth kneeling in a lunge, facing left. The near leg is forward, its thigh rising and
tapering from the hip to the raised knee at lambda (a small knee bump), its shin standing down
through tau to a flat foot; the far knee is on the ground at Skat, a short shin rising back to a
pinched ankle, the foot standing on its toes (heel up and round, toes bent forward along the
ground). The torso is one upright V-shaped piece whose flank runs from the far armpit down to a
round seat, the neck flaring into the traps. The near arm has a long upper arm to a low elbow bump,
the forearm rising steeply from it, swelling at its muscle and tapering to a pinched wrist; the hand
is pressed square against the pot's lower belly (overlapping it 2-3 px) and dissolves into it. The
pot is tipped mouth down to the lower left: a short flat foot round star 6, a round belly, a pinched
neck and a flared lip round star 5; no handle. The head is drawn pixel by pixel (HEAD_ROWS) with its
own unthinned line: a classical profile (straight brow, nose, lips, chin) under a curly hair mass
picked out in denser stardust, an ear and a lit eye. The far arm opens down-right, tapering to a
clear elbow and an open hand at epsilon (thumb spread up, two finger lobes). A hip cloth wraps the
waist, its front hem broad and level over the near thigh. The water leaves the lip as one narrow
pour and fans into four wavy locks of clearly different widths, swaying together, with bubbles of
2-3 px round the fan, clear of it.

The body, its limbs, the hip cloth and the pot are one silhouette (ONE_BODY), outlined only round
the union. Each star sits inside a part of its own piece with a clear gap of 2 px or more from any
line.

The pieces partition the whole: each pixel goes with the part of the shape under it, else with the
nearest tagged pixel; each star's own pixel goes with its part.

Run: python tools/art/build_aquarius_figure.py [--preview out.png]   (needs Pillow and numpy)
"""

import argparse
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import aquarius_part_paintings  # noqa: E402
import clean_line as cl  # noqa: E402
import stardust as sd  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / "assets" / "art"
OUT = ART / "aquarius_figure.png"
PARTS = ("hand", "body", "legs", "stream", "jar")

# StarMap.aquarius() (game/core/star_map.gd): landmarks, sizes and strings.
L = [(150, 156), (124, 140), (98, 124), (74, 118), (50, 112), (26, 118), (52, 88), (90, 150),
     (66, 160), (70, 186), (88, 206), (42, 170), (30, 192), (24, 218)]
SIZES = ["S", "B", "B", "M", "M", "S", "S", "S", "M", "S", "B", "S", "S", "M"]
SEGMENTS = [(0, 1), (1, 2), (2, 3), (3, 4), (4, 5), (4, 6), (2, 7), (7, 8), (8, 9), (9, 10),
            (8, 11), (11, 12), (12, 13)]
# ChapterDef.aquarius() stages: which piece holds each star.
STAR_PARTS = {0: "hand", 1: "hand", 2: "body", 7: "body", 8: "legs", 9: "legs", 10: "legs",
              11: "stream", 12: "stream", 13: "stream", 3: "jar", 4: "jar", 5: "jar", 6: "jar"}
SEED = 11
LIGHT = np.array([-0.55, -0.65, 0.52])

# The pot, base (top right) to lip (bottom left), game px, along the line from star 6 to star 5 (the
# mouth tipped well down to the left), just long enough to hold both stars with a clear gap: a short
# broad foot round star 6, a round belly 20 px across, a pinched neck and a flared lip round star 5
# (11 px across, wider than the water leaving it). No handle (an ear-like loop read as a head).
_S6, _S5 = (52.0, 88.0), (26.0, 118.0)
_D = ((_S5[0] - _S6[0]) / 39.698, (_S5[1] - _S6[1]) / 39.698)
JAR_FOOT = (_S6[0] - 3.4 * _D[0], _S6[1] - 3.4 * _D[1])
JAR_MOUTH = (_S5[0] + 3.9 * _D[0], _S5[1] + 3.9 * _D[1])
_LEN = 39.698 + 3.4 + 3.9
JAR = [(a / _LEN, w) for a, w in (
    (0, 5.0), (0.6, 5.5), (2.5, 5.6), (5, 5.8), (7, 6.6), (8.5, 7.6), (10, 8.6), (12.5, 9.8), (15.5, 10.5), (18.5, 10.7),
    (21.5, 10.4), (24, 9.5), (26, 8.0), (28, 6.0), (29.8, 4.4), (31.5, 3.5), (34.5, 3.2), (37, 3.4), (39, 4.4),
    (41, 5.4), (43.5, 5.7), (_LEN, 5.0))]


def v(p):
    return np.array(p, float)


def interp(prof, f):
    fs, ws = zip(*prof)
    return float(np.interp(f, fs, ws))


def swayed(spine, sway):
    """`spine` (game px) resampled, its points pushed sideways by a sine (amplitude, wavelength,
    phase), easing in from the start and out before the end: the locks' ripple."""
    amp, lam, phase = sway
    ax = cl.Axis([v(p) for p in spine])
    out = []
    for s in np.linspace(0, ax.L, max(8, int(ax.L / 3))):
        c, t, nrm = ax.frame(s)
        ease = min(1.0, s / 16.0) * min(1.0, (ax.L - s) / 14.0)
        out.append(tuple(c + nrm * amp * math.sin(phase + 2 * math.pi * s / lam) * ease))
    return out


def band(spine, prof, n=80, start_cap=True, wave=None, sway=None, sides=(1.0, 1.0)):
    """A closed band along `spine` (game px) with half-width prof [(fraction, hw)] (game px),
    round at both ends. `wave` (amplitude, waves, phase) ripples its edges, scaled per side by
    `sides` (left, right of travel): a lock's crests on its outer edge. 4x points."""
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
    return left + cap1 + right[::-1] + (cap0 if start_cap else [])


def limb(spine, widths):
    """A limb along `spine` (game px), half-width `widths` at each spine point."""
    d = np.concatenate([[0], np.cumsum(np.linalg.norm(np.diff(np.array(spine, float), axis=0), axis=1))])
    return band(spine, list(zip(d / d[-1], widths)))


def jar_frame():
    f, m = v(JAR_FOOT), v(JAR_MOUTH)
    u = (m - f) / np.linalg.norm(m - f)
    return f, m, u, np.array([-u[1], u[0]])


def jar_shape(profile):
    f, m, u, n = jar_frame()
    pts = [f + (m - f) * t + n * w for t, w in profile] + [f + (m - f) * t - n * w for t, w in profile[::-1]]
    return cl.outline(pts, 8)


def rows_path(rows):
    """Filled pixel spans {y: [(x0, x1)]} as one path of 4x rectangles."""
    subs = []
    for y, spans in rows.items():
        for x0, x1 in spans:
            subs.append(cl.path_of([(x0 * 4, y * 4), ((x1 + 1) * 4, y * 4), ((x1 + 1) * 4, (y + 1) * 4),
                                    (x0 * 4, (y + 1) * 4)]))
    return " ".join(subs)


def ellipse(c, a, b, deg, k=18):
    t = math.radians(deg)
    u, n = np.array([math.cos(t), math.sin(t)]), np.array([-math.sin(t), math.cos(t)])
    return [(v(c) + u * a * math.cos(q) + n * b * math.sin(q)) * 4 for q in np.linspace(0, 2 * math.pi, k, endpoint=False)]


def circle(c, r, k=14):
    return [v(c) * 4 + r * 4 * np.array([math.cos(a), math.sin(a)]) for a in np.linspace(0, 2 * math.pi, k, endpoint=False)]


def curl_tail(start, centre, r0, turn, sign):
    """Spine points that swing from `start` round `centre` by `turn` radians (sign: +1 clockwise
    on screen), the radius shrinking to r0: a lock's curl."""
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


def tilt(pts, centre, deg):
    """Game-px points turned about `centre` (negative: the face tips down to the left)."""
    a = math.radians(deg)
    c, s_ = math.cos(a), math.sin(a)
    return [(centre[0] + (x - centre[0]) * c - (y - centre[1]) * s_,
             centre[1] + (x - centre[0]) * s_ + (y - centre[1]) * c) for x, y in pts]


def jar_at(a, p):
    """A point on the pot: `a` game px along it from the base toward the lip, `p` across it
    (positive toward the lower right, where the hand is)."""
    f, m, u, n = jar_frame()
    return tuple(f + u * a - n * p)


def framed(origin, toward, pts):
    """Points (h along the direction from `origin` to `toward`, q to its upper side) on the screen."""
    o, t = v(origin), v(toward)
    h = (t - o) / np.linalg.norm(t - o)
    q = np.array([h[1], -h[0]])
    if q[1] > 0:
        q = -q
    return [tuple(o + h * a + q * b) for a, b in pts]


def shapes():
    out = []

    def add(name, part, pts, group=None, smooth=False, n=10):
        pts = cl.outline(pts, n) if smooth else pts
        group = "figure" if name in ONE_BODY else (group or name)
        out.append({"name": name, "part": part, "group": group, "d": cl.path_of(pts)})

    # ---- the water: three locks of clearly different widths leave the lip together as one root and
    # fan apart: a thin one sweeping out to the left and rolling up high, a medium one falling down
    # through 98 to a curl at the foot, the widest one running down-right through phi to a curl at
    # mid height, away from the near shin; bubbles round the fan ----
    SW = (1.9, 30, 0.0)
    add("lock_l", "stream", band([(22.5, 123), (21, 130), (15.5, 137), (10, 147), (6.5, 159), (6, 168)]
                                 + curl_tail((6, 168), (10.5, 169.5), 1.3, 5.6, -1),
                                 [(0, 1.8), (0.15, 1.8), (0.4, 2.8), (0.65, 3.2), (0.82, 2.6), (1, 1.2)], sway=SW))
    add("lock_ml", "stream", band([(22.5, 123), (21.5, 131), (18, 140), (14.5, 152), (12.5, 166), (12, 180), (12.5, 190)]
                                  + curl_tail((12.5, 190), (17, 191.5), 1.4, 5.6, -1),
                                  [(0, 2.0), (0.12, 2.0), (0.35, 3.0), (0.6, 3.6), (0.82, 3.0), (1, 1.3)], sway=SW))
    add("lock_r", "stream", band([(22.5, 123), (23.5, 131), (28.5, 141), (34, 151), (38.5, 160), (42, 168), (43.5, 176)]
                                 + curl_tail((43.5, 176), (38.5, 177.5), 1.8, 5.8, 1),
                                 [(0, 2.4), (0.12, 2.6), (0.35, 4.6), (0.55, 5.8), (0.72, 6.0), (0.86, 4.4), (1, 1.8)],
                                 wave=(0.8, 3.0, 2.0), sides=(0.2, 1.0), sway=SW))
    add("lock_m", "stream", band([(22.5, 123), (22.5, 133), (21.5, 150), (22.5, 165), (27, 180), (30, 192.5),
                                  (28.5, 204), (25.5, 213), (24.5, 220), (27.5, 226)]
                                 + curl_tail((27.5, 226), (32.5, 223), 1.6, 5.6, -1),
                                 [(0, 2.6), (0.08, 2.8), (0.25, 3.6), (0.45, 4.2), (0.62, 4.8), (0.8, 4.4), (0.92, 3.2), (1, 1.6)],
                                 sway=SW))
    for k, (c, r) in enumerate([((11, 116), 2.2), ((41, 133), 2.2), ((3, 140), 2.0), ((46, 150), 1.8),
                                ((3, 180), 2.0), ((40, 190), 1.8), ((53, 194), 2.2), ((42, 205), 2.6),
                                ((14, 210), 2.2), ((44, 225), 2.4), ((19, 236), 2.0)]):
        add(f"bubble{k}", "stream", circle(c, r))

    # ---- the far leg: thigh down to the knee on the ground at Skat, a short shin rising a little back
    # to a pinched ankle, the foot standing on its toes under it: heel up and round, toes bent forward
    # along the ground ----
    add("far_leg", "legs", limb([(102, 158), (98, 176), (93, 192), (89, 205), (97, 204.5), (104.5, 202)],
                                [7.0, 6.6, 6.0, 6.4, 4.4, 2.5]), "far_leg")
    add("far_foot", "legs", cl.outline([(103, 200), (106.5, 198.5), (110, 199.5), (112, 203), (112, 208),
                                        (111, 212), (107.5, 214), (102.5, 214), (100.5, 212.5), (102.5, 211),
                                        (104.5, 208), (103.5, 204)], 6), "far_leg")
    # ---- the torso in one piece: traps rising to the neck, the far armpit, the flank tapering down
    # the back to the waist; the seat one round curve from the waist into the far thigh ----
    add("torso", "body", cl.outline(TORSO, 8))
    add("seat", "body", cl.outline(SEAT, 8))
    # ---- the near leg: the thigh rising forward from the hip to the raised knee at lambda, tapering,
    # a knee bump, the shin down through tau ----
    add("near_thigh", "legs", limb([(98, 166), (82, 162), (65, 157.5)], [7.4, 6.4, 5.4]), "near_leg")
    add("knee", "legs", circle((62.5, 157), 4.6, 16), "near_leg")
    add("near_shin", "legs", limb([(63, 159), (65, 170), (67, 184), (69, 197)], [5.2, 5.6, 5.8, 3.4]),
        "near_leg")
    add("near_foot", "legs", cl.outline([(66, 196), (72, 196), (74, 201), (73, 205), (62, 205),
                                         (56, 204), (57, 201)], 6), "near_leg")
    # the hip cloth: wrapped round the hips, its front hem broad and level over the near thigh, the
    # uneven ends at the back hip
    add("drape", "body", cl.outline([(83, 156), (94, 153.5), (104, 151), (108, 151), (109, 158),
                                     (104, 165), (96, 165.5), (88, 165), (82.5, 164.5), (80.5, 160)], 8))
    # ---- the neck, wide at its root so it flows into the traps ----
    add("neck", "body", limb(NECK, [4.5, 4.4, 6.0]))
    # ---- the far arm, opening down-right: a round shoulder, the upper arm tapering to the elbow by
    # star 1, the forearm swelling below it and narrowing to the wrist; an open hand at epsilon, palm
    # out, the fingers together and the thumb spread up ----
    add("far_arm", "hand", limb(FAR_UPPER, [5.4, 4.7, 3.9, 3.6]), "far_arm")
    add("far_forearm", "hand", limb(FAR_FORE, [3.6, 4.0, 3.4, 2.5]), "far_arm")
    add("far_hand", "hand", cl.outline(FAR_HAND, 6), "far_arm")
    # ---- the pot, then the near arm: the deltoid round on the shoulder, the upper arm down to the
    # elbow, the forearm rising, swelling just below the elbow and tapering to the wrist; the hand
    # laid against the pot's lower belly, fading into it ----
    add("jar", "jar", jar_shape(JAR))
    wrist, grip = WRIST, GRIP
    add("upper_arm", "jar", limb(NEAR_UPPER, [5.2, 4.8, 4.4, 4.0]), "near_arm")
    add("elbow", "jar", circle(NEAR_ELBOW, 2.6, 14), "near_arm")
    add("forearm", "jar", limb(NEAR_FORE + [wrist], [3.6, 4.4, 3.4, 2.3]), "near_arm")
    add("forearm_swell", "jar", ellipse(*NEAR_SWELL), "near_arm")
    # the hand: palm and fingers pressed against the belly's lower right, overlapping it 2-3 px
    add("near_hand", "jar", band(framed(wrist, grip, [(0, 0), (5, 0), (9.5, 0)]),
                                 [(0, 2.3), (0.3, 3.8), (0.7, 4.2), (1, 3.4)]), "near_arm")
    # ---- the head in profile, tipped down toward the pot: one silhouette of curly hair, a straight
    # classical brow and nose, lips, a firm chin, the jaw running back to the nape ----
    out.append({"name": "head", "part": "body", "group": "figure", "d": rows_path({y + HEAD_DROP: r for y, r in HEAD_ROWS.items()})})
    return out


# One continuous silhouette (the user's rule): the body, its limbs, the hip cloth and the pot the
# near hand holds are one group, outlined only round the union, so no part reads as severed and the
# hand melts into the pot. The hair and its curls stay on top (the hairline is a feature, not a seam).
ONE_BODY = {"far_leg", "far_foot", "torso", "seat", "near_thigh", "knee", "near_shin", "near_foot", "drape",
            "neck", "far_arm", "far_forearm", "far_hand", "jar", "upper_arm", "elbow", "forearm", "forearm_swell",
            "near_hand", "head"}
# Inner lines only where an overlap must read, as short strokes fading from the line's strength (4
# steps over the sky) at their first point to 1 at their last, never on the outline: the near thigh's
# underside carried on across the far thigh, so the raised knee reads in front. (The near arm needs
# none: its underside is already the outline down to the armpit.)
INNER = [[(93.0, 172.6), (97.5, 173.9), (103.0, 175.0)]]
WRIST, GRIP = (57.0, 116.5), (46.0, 107.0)  # the hand presses up-left, square to the pot

TORSO = [(84, 124), (87, 119.5), (93, 116.5), (99, 115), (106, 114.5), (112, 115.5), (117, 118), (121, 122),
         (120.5, 128), (118, 133), (114.5, 139), (111.5, 145), (109.5, 150), (106, 155), (100, 160), (92, 161),
         (86, 156), (85, 147), (84.5, 138), (84, 130)]
SEAT = [(106, 149), (110, 151.5), (112, 156), (111.5, 161), (108.5, 165.5), (103, 166), (100, 160), (101, 152)]
NECK = [(105.5, 106), (104.5, 111), (102.5, 118)]
FAR_UPPER = [(116, 122), (119.5, 128), (122.5, 134), (125, 139.5)]
FAR_FORE = [(125, 139.5), (131, 146), (137, 150), (143, 153)]
# The open hand, palm out: the wrist, the thumb spread up and out, the fingers together in two
# rounded lobes (index and middle, ring and little) with one short cleft between them, the heel of the
# palm round under star 0.
FAR_HAND = [(143, 151.5), (146, 150.2), (149.2, 146.4), (151.4, 145.6), (152.6, 146.8), (151, 150.8),
            (154, 151.2), (158.5, 151.6), (162, 153.2), (161.8, 155.2), (156.6, 155.8), (160.6, 158), (159.4, 160),
            (152, 160.8), (146.5, 159.5), (143, 157)]
# The near arm held out under the pot, the elbow a little low: the deltoid round on the shoulder, the
# upper arm tapering to the elbow (its point a small bump underneath), the forearm's muscle swelling on
# top just past the elbow (it holds star 3) and narrowing to the wrist.
NEAR_UPPER = [(90.5, 119.5), (85.5, 121.5), (80, 123.5), (76, 125)]
NEAR_ELBOW = (76.5, 126.5)
NEAR_FORE = [(76, 125), (70.5, 121.5), (64, 118.5)]
NEAR_SWELL = ((71.5, 120.0), 6.2, 3.5, -30.0)  # centre, half-length, half-width, degrees

HEAD_TILT = 0.0
HEAD_PIVOT = (104.0, 110.0)
# The head drawn pixel by pixel (a polygon this small loses the nose and lips to the smoothing):
# y: (left, right) filled spans, facing left. Forehead, a straight classical brow, the nose, lips and
# chin down the left; curly hair round the crown and the back of the head (each curl a 1 px bump in
# the silhouette); the jaw running back into the neck.
HEAD_ROWS = {
    84: [(102, 103), (106, 107), (110, 110)],
    85: [(100, 112)], 86: [(99, 114)], 87: [(98, 115)], 88: [(97, 116)], 89: [(98, 116)], 90: [(98, 117)],
    91: [(98, 117)], 92: [(98, 117)], 93: [(97, 116)], 94: [(98, 117)], 95: [(97, 116)], 96: [(96, 116)],
    97: [(95, 116)], 98: [(94, 115)], 99: [(97, 115)], 100: [(97, 114)], 101: [(96, 113)], 102: [(97, 112)],
    103: [(98, 111)], 104: [(97, 110)], 105: [(97, 109)], 106: [(98, 109)], 107: [(100, 108)], 108: [(102, 107)],
}
EYE = (99, 95)  # the eye
BROW = [(98, 93), (99, 93), (100, 93)]
# Hair: from each row's x rightward (rows above the first are all hair, rows past the last none).
HAIRLINE = {88: 99, 89: 100, 90: 101, 91: 102, 92: 103, 93: 104, 94: 105, 95: 106, 96: 107, 97: 108,
            98: 108, 99: 108, 100: 109, 101: 109, 102: 109, 103: 109}
CURL_MARKS = [(104, 87), (105, 86), (106, 87), (109, 88), (110, 87), (111, 88), (112, 91), (113, 90),
              (114, 91), (110, 93), (111, 92), (112, 93), (114, 95), (115, 94), (113, 98), (114, 97),
              (111, 101), (112, 100), (107, 90), (108, 91), (101, 87), (100, 88)]
EAR = [(107, 95), (108, 95), (109, 96), (109, 97), (108, 98)]


def head_detail(img, line):
    """The face and hair inside the head's line: the hair a denser stardust mass behind the
    hairline, with ring curls picked out in it, the ear a small curve inside the hair's edge, the face
    left thin so it reads as skin; the eye a lit pixel in a clear socket under a short brow."""
    sky = sd.sky_index()
    y0, y1, x0, x1 = HEAD_BAND

    def put(xx, yy, k):
        if line[yy, xx]:
            return
        if k == 0:
            img[yy, xx] = 0
            return
        img[yy, xx, :3] = sd.PAL[sd.N[sky[yy, xx] + k]]
        img[yy, xx, 3] = 255

    for y in range(y0, y1 + 1):
        start = HAIRLINE.get(y - HEAD_DROP, 999 if y - HEAD_DROP > max(HAIRLINE) else 0)
        for x in range(max(x0, start), x1 + 1):
            if img[y, x, 3] and not line[y, x] or (FORM[y, x] and not line[y, x]):
                put(x, y, 2 if sd.BAY[y, x] < 0.5 else 1)
    for k, pts in ((3, CURL_MARKS), (3, EAR)):
        for x, y in pts:
            put(x, y + HEAD_DROP, k)
    ex, ey = EYE[0], EYE[1] + HEAD_DROP
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            put(ex + dx, ey + dy, 0)
    for x, y in BROW:
        put(x, y + HEAD_DROP, 4)
    put(ex, ey, 4)
    # keep the profile clean: no stray speck floating just in front of the lips
    for y in range(y0, y1 + 1):
        for x in range(x0, 97):
            if not FORM[y, x] and not line[y, x]:
                img[y, x] = 0
    return img


HEAD_DROP = 2  # the head sits 2 px lower than its rows say
HEAD_BAND = (83 + HEAD_DROP, 108 + HEAD_DROP, 92, 121)  # y0, y1, x0, x1: where the head's own line replaces the traced one


def head_line(img, form, line):
    """The head's line drawn straight off its pixel silhouette (no thinning, which would shave off
    the nose, lips and curls): every pixel of the form with a 4-neighbour outside, minus elbows; 5
    steps over the sky on the lit side (outside up or left), 4 elsewhere. Returns the new line."""
    y0, y1, x0, x1 = HEAD_BAND
    band = np.zeros_like(form)
    band[y0:y1 + 1, x0:x1 + 1] = True
    mine = cl.drop_elbows(cl.edge_inner(form)) & band
    for y, x in zip(*np.nonzero(line & band & ~mine)):
        img[y, x] = 0
    for y, x in zip(*np.nonzero(mine)):
        lit = not form[y - 1, x] or not form[y, x - 1]
        steps_over_sky(img, y, x, cl.LINE_STEPS + (1 if lit else 0))
    return (line & ~band) | mine


def steps_over_sky(img, y, x, k):
    img[y, x, :3] = sd.PAL[sd.N[SKY[y, x] + k]]
    img[y, x, 3] = 255


def inner_lines(img, form, line):
    """The INNER strokes, each fading from 4 steps over the sky to 1 along its length, kept 3 px
    clear of every star."""
    for spine in INNER:
        pts = np.array(spine, float)
        d = np.concatenate([[0], np.cumsum(np.linalg.norm(np.diff(pts, axis=0), axis=1))])
        m = cl.stroke("M " + " L ".join(f"{x * 4 + 2} {y * 4 + 2}" for x, y in spine))
        for y, x in zip(*np.nonzero(m & form & ~sd.grow(line, 1))):
            if any(max(abs(x - sx), abs(y - sy)) < 3 for sx, sy in L):
                continue
            k = np.argmin(np.linalg.norm(pts - (x, y), axis=1))
            f = d[k] / d[-1]
            steps_over_sky(img, y, x, int(round(4 - 3 * f)))
    return img


def hand_fade(img, line, shape_masks):
    """The near hand dissolving into the pot: its outline (off the pot) dims from the wrist (4 steps
    over the sky) to 1 step where it meets the belly, and stops there."""
    hand = sd.grow(shape_masks["near_hand"], 1) & ~shape_masks["jar"]
    w, g = v(WRIST), v(GRIP)
    u = (g - w) / np.linalg.norm(g - w)
    span = np.linalg.norm(g - w)
    for y, x in zip(*np.nonzero(line & hand)):
        f = float(np.clip(np.dot(v((x, y)) - w, u) / span, 0, 1))
        k = int(round(4 - 3.6 * f))
        if k < 1:
            img[y, x] = 0
        else:
            steps_over_sky(img, y, x, k)
    return img


def near_only(img, groups, reach=6):
    """Clears specks more than `reach` px off the figure (stray specks at the canvas edge)."""
    far = sd.distance_inside(~(groups >= 0)) > reach
    img[far] = 0
    return img


def star_report(parts, line):
    for i, (x, y) in enumerate(L):
        gap = 99
        for dy in range(-4, 5):
            for dx in range(-4, 5):
                if line[y + dy, x + dx]:
                    gap = min(gap, max(abs(dx), abs(dy)))
        print(f"star {i:2d} {SIZES[i]} at {x},{y}: on {parts[y, x] or '-':7s} want {STAR_PARTS[i]:6s} "
              f"line gap {gap if gap < 99 else '>4'}")


SKY = sd.sky_index()
FORM = None  # the figure's form (groups >= 0), set in figure() before the head's detail is drawn


def figure():
    """The painting and each pixel's part tag."""
    global FORM
    sh = shapes()
    line, groups, parts = cl.draw(sh)
    star_report(parts, line)
    img, _ = cl.semi_hollow(sh, L, SIZES, SEED, LIGHT)
    masks = {s["name"]: cl.down(cl.fill_4x(s["d"])) for s in sh}
    img = hand_fade(img, line, masks)
    img = inner_lines(img, groups >= 0, line)
    line = head_line(img, groups >= 0, line)
    FORM = groups >= 0
    img = near_only(head_detail(img, line), groups)
    return img, cl.part_tags(parts, img, L, STAR_PARTS)


def save(img: np.ndarray, path: Path):
    Image.fromarray(img, "RGBA").save(path)
    print(f"wrote {path.relative_to(ROOT)}")


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--preview", type=Path, help="also write the figure over the sky, x3, with its stars, here")
    args = parser.parse_args()
    ART.mkdir(parents=True, exist_ok=True)
    img, tags = figure()
    used = sd.check(img)
    print(f"figure: {sum(used.values())} px, {used}")
    save(img, OUT)
    for part, piece in sd.pieces(img, tags, PARTS).items():
        save(piece, ART / f"aquarius_piece_{part}.png")
    if args.preview:
        sd.preview(img, L, SIZES, SEGMENTS, 3).save(args.preview)
        print(f"wrote {args.preview}")
    aquarius_part_paintings.build_parts()


if __name__ == "__main__":
    main()
