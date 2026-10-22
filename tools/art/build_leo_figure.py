"""Builds the Leo's painting (chapter 3's reward), in assets/art/:

  leo_figure.png         the whole lion, the final stage's reward and the chapter chart's
  leo_piece_<part>.png   the same painting cut into the chapter's five parts (tail, haunch, heart,
                         mane, head), in the same full-screen home layout: the chapter chart shows
                         the won ones dormant, then the whole figure once the final is won
  leo_part_<part>.png    each part stage's own painting, in the same clean-line style, the final's
                         body parts re-posed to each stage's stars
                         (tools/art/leo_part_paintings.py, run from here)

The whole Leo is the Scorpio's clean line, semi-hollow with stardust (tools/art/clean_line.py and
tools/art/stardust.py), round the 13 landmarks of StarMap.leo (game/core/star_map.gd). The pieces
partition the whole: each pixel goes with the part of the shape under it, else with the nearest
tagged pixel; each star's own pixel goes with its part (ChapterDef.leo's stages).

Run: python tools/art/build_leo_figure.py [--preview out.png]   (needs Pillow and numpy)

The drawing, as approved:

Leo, release draft: the Scorpio's clean line, semi-hollow with stardust, in the pose of the
user's v2 concept (output/imagegen/zodiac-concepts-20261012/leo-constellation-v2.png).

A lion walking right. The head is a true profile, longer than tall (about 36 x 28 px): a low flat
crown, the brow a hard step over a slanted almond eye, the long straight bridge sloping to the nose's
blunt corner, a square muzzle front, the closed mouth from the lip's notch back to its drooping
corner, a short square chin and a straight jaw line back to the cheek; the face ends at the mane's
locks lying forward on the cheek. The mane runs over the crown (rev 1: Leo read as bald) and the
round ear rises out of it in one outline with it. The mane is one mass whose top is a soft round (no upward points), with
broad flames hanging down and back over the withers and rounded tufts ending at the chest; over it
an inner mane frames the face, from behind the ear round the back of the head and under the jaw
(lambda in its throat, which goes with the head's piece), its edge a row of locks falling down and
back, the lowest the longest, draping over the chest. The stardust inside the mane is thinned so
each edge reads. The body drops at the chest under the mane and tucks at the waist; the haunch is a
teardrop whose top line is the back line. The near foreleg is lifted mid-stride, built as a lion's (rev 1):
the shoulder down and back to the jutting point of the elbow, one straight forearm forward and down
through Regulus, a soft wrist, the paw hanging a little round omicron; the far foreleg is planted behind it with a kinked wrist and the paw turned forward. Both
hind legs zig: the shin slanting back to a pointed hock, the cannon forward-down to a dome paw that
is wider at the toes (toe splits on the near paws).

One silhouette (rev 1): the body, all four legs and the tail are one group, so no seam where a leg
or the tail meets the body; where a near limb lies over the body or a far limb, its edge is a short
inner stroke that rises from the silhouette (the elbow, the stifle) and fades out. The tail rises a little off the rump, curves
down and back past Denebola and ends in a small flame of a tuft.

Rev 2: the face and the inner mane are one silhouette (no closed line round the face): the jaw is a
stroke at line strength from the chin back to the cheek, then up the cheek's lock fading out; two
locks lie forward over the crown and fade out on the brow. The ear stands behind the inner mane
(its locks lie over the ear's base), upright, rounded with a slight tip, with an inner-ear stroke.
The near foreleg is as thick as the other legs, its elbow juts back clear of the far leg, the wrist
is a knob that kinks the leg, and the paw, broader than the wrist, hangs down round omicron.

Rev 3 (one silhouette for the head end): the mane, the face ruff, the ear and the face are one group,
so no line splits the mane down the middle; the ruff's back edge is a row of short lock strokes that
fade up into the mane (RUFF_LOCKS). The crown is the mane's own silhouette: three soft tufts
(CROWN_TUFTS) rise forward of the ear and lie forward over the forehead, the last ending above the
brow, parted by short fading strokes (CROWN_LOCKS). The ear is small and round (about 9 x 7 px above
the fur, mu inside), half buried in the crown fur, with no inner-ear stroke. The inner-ear note in
Rev 2 no longer applies.
"""

import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import clean_line as cl  # noqa: E402
import stardust as sd  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / "assets" / "art"
OUT = ART / "leo_figure.png"

# StarMap.leo (game/core/star_map.gd): 0 lambda (mouth), 1 epsilon (brow), 2 mu (ear), 3 zeta,
# 4 Algieba (mane), 5 eta (chest), 6 Regulus (foreleg), 7 omicron (its paw), 8 Zosma (back),
# 9 Denebola (tail), 10 Chertan (thigh), 11 iota (hock), 12 sigma (hind paw).
L = [(160, 134), (154, 110), (136, 92), (112, 100), (102, 124), (112, 148), (116, 176), (144, 194),
     (60, 122), (26, 150), (64, 156), (50, 184), (54, 212)]
SIZES = ["S", "M", "S", "S", "B", "S", "B", "S", "M", "B", "M", "S", "S"]
SEGMENTS = [(0, 1), (1, 2), (2, 3), (3, 4), (4, 5), (5, 6), (6, 7), (4, 8), (8, 9), (9, 10), (10, 11), (11, 12)]
# ChapterDef.leo stages: the part each star belongs to.
STAR_PARTS = {9: "tail", 8: "tail", 10: "haunch", 11: "haunch", 12: "haunch", 6: "heart", 7: "heart",
              5: "heart", 4: "mane", 3: "mane", 2: "head", 1: "head", 0: "head"}
PARTS = ("tail", "haunch", "heart", "mane", "head")
SEED = 11
LIGHT = np.array([-0.55, -0.65, 0.52])

# ---- The outlines, in game pixels (cl.outline smooths them into 4x space) ----

# The torso: the back from the withers (under the mane) to the rump, the rump, the belly tucked at
# the waist and dropping to the brisket, the chest front up under the mane (set inside the near
# upper arm, whose front line is the chest line).
TORSO = [(112, 113), (98, 114), (84, 116), (70, 116.5), (58, 115.5), (44, 116), (36, 121), (32, 131),
         (34, 144), (42, 152), (60, 158), (76, 155), (88, 157), (100, 163), (110, 166), (119, 160),
         (124, 149), (125, 134), (122, 120)]
# The near hind thigh, a teardrop: its point at the hip on the back line (its top line is the back
# line), its rear line the rump, its round bottom at the knee round Chertan.
THIGH = [(40, 115), (49, 114.5), (53.5, 117), (57, 127), (63, 137), (71, 145), (77, 153), (78.5, 162),
         (75, 170), (65, 173.5), (52, 169), (41, 158), (34, 146), (31.5, 133), (33.5, 121)]
# The near hind leg below the thigh, one outline with an angle in it: the shin slants back from the
# knee to the pointed hock by iota, the cannon runs forward-down to the paw on sigma; the paw a low
# dome, wider at the toes, its rounded front a little ahead of the leg.
NEAR_HIND = [(64, 160), (76.5, 160.5), (79.5, 164), (79.6, 168.5), (77, 172.5), (71.5, 177), (65.5, 181.5), (60.5, 184.5), (56, 188), (56, 195), (58, 201.5),
             (62, 204.5), (66.5, 207.5), (69, 211.5), (68.5, 215.5), (63, 217), (54, 217), (47.5, 216),
             (47, 211), (50, 205), (49.5, 198), (47.5, 191), (44.5, 188.5), (44, 186.5), (47, 182), (53, 175),
             (58, 168)]
# The far hind leg, the same zig a step forward: the stifle, the shin slanting back to a pointed
# hock, the cannon forward-down to its dome paw.
FAR_HIND = [(80, 148), (89, 151), (92.5, 160), (90.5, 168), (85, 176), (80.5, 182), (78.5, 188), (79, 195),
            (82, 200.5), (86, 203.5), (90.5, 207), (92.5, 211), (91, 214), (80, 214), (73.5, 213.5),
            (73, 209.5), (75, 204.5), (74.5, 198), (72, 192.5), (68.5, 189.5), (68.5, 187), (71.5, 181),
            (76, 172), (78, 162), (76, 154)]
# The far foreleg, planted under the chest behind the lifted forearm: a column with a forward kink at
# the wrist, the paw turned forward.
FAR_FORE = [(104, 160), (115.5, 160), (115.5, 176), (114, 189), (113.6, 195.5), (116, 199.5), (121, 203.5),
            (125, 207.5), (126, 211.5), (124.5, 214), (116, 214), (108, 213.5), (105.5, 210), (105.5, 204),
            (104, 197), (103.6, 186), (104.2, 170)]
# The near foreleg, lifted mid-stride, as a real lion's: the shoulder (its front line the chest
# line) running down and back to the point of the elbow, which juts back under the chest.
UPPER_ARM = [(115, 121), (125, 119), (129.5, 128), (130, 141), (128.5, 152), (125, 161), (119, 168),
             (111, 172), (104, 173.5), (99.5, 174.5), (96, 172.6), (97.5, 168), (100.5, 161), (104, 150),
             (108.5, 134)]
# The forearm: one straight column from the elbow forward and down through Regulus (on its axis),
# as thick as the other legs (10-11 px), narrowing a little to the wrist.
FOREARM_AXIS = [(101, 169), (116, 176.4), (127, 181.6), (134.5, 185.2)]
FOREARM_RADII = [5.6, 5.4, 5.0, 4.6]
# The wrist a knob that kinks the leg down, then the paw hanging from it, broader than the wrist,
# its toes curled down and forward round omicron.
WRIST = [(131, 180.2), (136.2, 179.6), (139.6, 183.6), (138.6, 189.6), (134.4, 191.8), (130.4, 189.6)]
FORE_PAW = [(134.5, 184), (139.8, 184.2), (144, 186.6), (148.5, 190.2), (151.8, 195.4), (152, 200.2),
            (149.4, 203.4), (144.6, 204.6), (140, 203.2), (136.4, 199.6), (133.6, 195), (132.6, 189)]
# The head in profile, one outline, about 35 x 29 px: the back of the skull, the low flat crown,
# the brow a hard step over the eye, the stop, the long straight bridge sloping to the nose's blunt
# corner, the square muzzle front, a step in at the lip to the short square chin, the straight jaw
# line up and back to the cheek, the cheek and throat.
HEAD = [(149.5, 102), (153, 101.6), (157, 101.2), (160.5, 100.8), (162.8, 100.6),
        (163, 102.4), (161.4, 103.4), (163, 104.4), (167, 107), (170.8, 109.6), (174, 111.8),
        (175.5, 113.5), (175.6, 116), (175.6, 120.5), (174.6, 121.8), (172.2, 122.4), (171.6, 123.3), (171.6, 125.6),
        (170.4, 127), (167, 127.4), (161, 127.4), (155, 127.2), (151, 126.8),
        # the back of the face is the mane's front edge: locks of the mane lying forward on the
        # cheek, the head shows only in front of them
        (148.2, 125.6), (150.4, 122.6), (147.6, 120.2), (149.8, 116.4), (147.8, 113.2), (150, 109.4),
        (148.6, 106), (150.6, 103.2)]
# The closed mouth: one line from under the nose back along the lip, drooping to its corner.
MOUTH = [(171.5, 122.5), (168, 123), (165, 123.6), (162.5, 124.4)]
# The ear by mu: round, pricked, rising out of the mane on the crown (one outline with the mane).
# Behind the inner mane, so the mane's locks lie over its base and only the ear stands clear: upright,
# rounded with a slight point at its tip, and an inner-ear stroke along its front rim.
# Rev 3: small and round (about 9 x 8 px above the fur), half buried in the crown fur; one
# silhouette with the mane, so only its round top shows, between the fur behind it and the crown's
# tufts in front.
EAR = [(132.6, 97), (132.2, 90.6), (132.8, 86.8), (134.4, 84.4), (136.4, 83.8), (138.4, 84.6), (139.6, 87.4),
       (140, 92), (140, 97)]
# The face's own lines where it lies on the mane (the face and the mane are one silhouette): the
# jaw over the throat ruff, at line strength from the chin back to the cheek, then up the cheek's
# lock, fading out where the locks lie on the cheek. (points, px at full strength, px to fade)
JAW = [(168.5, 127.4), (161, 127.5), (155, 127.2), (151, 126.6), (148.6, 125.2), (150.2, 122.6),
       (148, 120), (149.6, 116.4), (148.2, 113)]
# The locks lying forward over the crown onto the brow: strokes from the mane's top edge sweeping
# down and forward, fading out on the forehead.
# Rev 3: the crown's tufts are the mane's own silhouette; these strokes part them, from each notch
# back along the underside of the lock that overhangs it, fading out in the fur.
CROWN_LOCKS = [[(151.8, 96.6), (149.6, 97), (147.4, 98.4)],
               [(146.6, 91.6), (144.8, 92.6), (143.6, 94.4)]]
# Rev 3: the face ruff has no line of its own (the face, the ruff and the mane are one mass); its
# back edge is a row of short locks, each a stroke from its tip at line strength fading up and
# forward into the mane.
RUFF_LOCKS = [[(124.2, 106.4), (125, 103.8), (126.6, 101.8), (128.8, 100.6)],
              [(126, 117.4), (126.6, 114.4), (128, 111.8), (130.2, 110)],
              [(124, 133.8), (124.8, 130), (126.4, 126.8), (129, 124.4)],
              [(129.6, 141.8), (130.4, 138.4), (132, 135.4), (134.4, 133.4)]]
# The eye: a slanted dark almond under the brow (sky), its upper lid lit. Painted after the stardust.
# Rev 4: the eye is epsilon (154, 110): the star is the eye's glint, set in a dark almond (the
# corners between the star's arms, the back corner and the drooping front corner), the upper lid a
# lit arch over it, the front (inner) corner the lower, as a lion's.
EYE_DARK = [(153, 109), (155, 109), (153, 111), (155, 111), (151, 110), (157, 110), (157, 111)]
EYE_LID = [(150, 109), (151, 108), (152, 108), (153, 107), (154, 107), (155, 107), (156, 108), (157, 108),
           (158, 109)]
EYE_RING = [(x, y) for x in range(149, 160) for y in range(107, 114)]
EYE_C = (154, 110)

# The mane's silhouette: one mass, its top a soft round; at its rear, three broad flames hanging
# down and back over the withers (tips down, overlapping like the Scorpio's plates); at its bottom,
# rounded tufts ending on the chest. Flames are (root, bend, tip, half-width); chest tufts are
# (centre, x radius, y radius).
MANE_MASS = [(138, 100), (128, 97), (118, 93), (108, 96), (100, 104), (97, 118), (98, 130), (104, 138),
             (114, 141), (130, 142), (148, 141), (151, 130), (146, 104)]
MANE_REAR = [((132, 95), (121, 90), (110, 95), 5.0),
             ((120, 98), (104, 97), (94, 108), 7.0),
             ((113, 111), (98, 114), (90, 126), 7.5),
             ((110, 125), (98, 130), (93, 141), 7.0)]
# Rev 3: the crown's tufts, flames like the rear ones, rising from behind the ear's front and lying
# forward over the forehead, the last ending above the brow (root, bend, tip, half-width).
CROWN_TUFTS = [((141.5, 94.5), (143.5, 87), (148.2, 91.6), 2.8),
               ((146, 96.5), (148.5, 90), (152.6, 95), 2.6),
               ((150.5, 99), (153, 93.4), (157, 99.4), 2.4)]
MANE_CHEST = [((110, 137.5), 7.0, 5.2), ((122, 143), 7.5, 5.8), ((135, 145), 7.0, 5.6), ((146.5, 142), 5.5, 5.0)]
# The inner mane round the face, over the mass: one crescent from behind the ear, round the back
# of the head and under the jaw (lambda in its throat), its back and lower edge a row of locks
# falling down and back, the lowest the longest, draping over the chest. Only that edge shows;
# the head covers the rest. Its throat (from x 148) goes with the head's piece.
# Rev 3: over the crown the ruff rises in three soft tufts forward of the ear, lying forward, the
# last ending above the brow.
FACE_RUFF = [(158.4, 101), (155.4, 99.8), (150.6, 97.6), (145.6, 95.4), (141, 94.4),
             (136, 94.4), (131.4, 94.6),
             (129.6, 93.2), (127, 94.6), (125.6, 98.5), (126.2, 102.5), (123.5, 106.5), (125.5, 110.5), (126, 117), (130.5, 116.5), (127.5, 123), (123.5, 134),
             (129, 133.5), (128, 140), (126, 152), (133.5, 147), (137, 151), (141.5, 158.5), (146, 150.5),
             (151, 153), (155.5, 151), (158, 146.5), (161.5, 144.5), (164.5, 139.5), (166.5, 133),
             (166.5, 128.5), (160, 126), (153, 124), (153.5, 112), (154, 103), (158.8, 101.8), (161.8, 100.6)]

def v(p):
    return np.array(p, float)


def unit(p):
    p = v(p)
    return p / np.linalg.norm(p)


def limb(points, radii):
    """A limb round a centre line: each side offset by its radius, the ends capped."""
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


def tuft(root, bend, tip, w):
    """A mane tuft: a flame along the curve root-bend-tip, `w` px half-wide near its round root,
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


def shapes():
    """The lion as clean_line shapes, back to front."""
    out = []

    def add(name, part, pts, group=None, smooth=True, n=10, **kw):
        pts = cl.outline(pts, n) if smooth else pts
        out.append({"name": name, "part": part, "group": group or name, "d": cl.path_of(pts), **kw})

    # The whole body is ONE group, one silhouette: no seam where a leg or the tail meets the body.
    # Where a near limb crosses the body or a far limb, `overlap_lines` adds short fading strokes.
    # the far legs, behind the body: the hind one with its hock, the fore one planted, its wrist kinked
    add("far_hind", "haunch", FAR_HIND, BODY, n=5)
    add("far_fore", "heart", FAR_FORE, BODY, n=5)
    # the tail: rising a little off the rump, then curving down and back past Denebola, tapering
    # into a small flame of a tuft that points down and back
    spine = [(37, 123), (32, 119.5), (26.5, 119.5), (22, 123.5), (19.5, 130), (18.5, 138), (19, 146),
             (20.5, 153), (22.5, 160), (23, 165)]
    add("tail", "tail", cl.tube([(x * 4, y * 4) for x, y in spine], 2.9 * 4, 1.9 * 4), BODY, smooth=False)
    out.append({"name": "tuft", "part": "tail", "group": BODY, "d": cl.path_of(tuft((23.2, 165), (24.2, 172),
                                                                                    (18.5, 179), 4.0))})
    # Denebola beside the tail line: a fill-only sliver from the tail's edge to its pixel carries
    # its part (no line; the star covers it)
    out.append({"name": "denebola", "part": "tail", "group": "denebola", "outline": False,
                "d": cl.path_of([(21 * 4, 150 * 4), (27 * 4, 150 * 4), (27 * 4, 151 * 4), (21 * 4, 151 * 4)])})
    # the torso: its back half with the tail's part, its front (from x 88) with the heart
    torso = cl.outline(TORSO, 10)
    out.append({"name": "torso", "part": "tail", "group": BODY, "d": cl.path_of(torso)})
    out.append({"name": "torso_front", "part": "heart", "group": BODY,
                "d": cl.path_of(clip_right(torso, 88 * 4))})
    # the near hind leg: the thigh round Chertan, then the shin, hock, cannon and paw in one line
    add("thigh", "haunch", THIGH, BODY)
    add("near_hind", "haunch", NEAR_HIND, BODY, n=5)
    # the near foreleg lifted mid-stride: the shoulder down to the elbow, the straight forearm
    # forward through Regulus, the wrist, the paw hanging on omicron
    add("upper_arm", "heart", UPPER_ARM, BODY, n=6)
    out.append({"name": "forearm", "part": "heart", "group": BODY,
                "d": cl.path_of(cl.outline(limb(FOREARM_AXIS, FOREARM_RADII), 4))})
    add("wrist", "heart", WRIST, BODY, n=6)
    add("fore_paw", "heart", FORE_PAW, BODY, n=6)
    # the mane: its mass with the rear flames and the chest tufts
    add("mane_mass", "mane", MANE_MASS, "mane", n=6)
    for k, (root, bend, tip, w) in enumerate(MANE_REAR):
        out.append({"name": f"rear{k}", "part": "mane", "group": "mane", "d": cl.path_of(tuft(root, bend, tip, w))})
    for k, (c, rx, ry) in enumerate(MANE_CHEST):
        ring = [(c[0] + rx * np.cos(a), c[1] + ry * np.sin(a)) for a in np.linspace(0, 2 * np.pi, 10)[:-1]]
        add(f"chest{k}", "mane", ring, "mane", n=6)
    for k, (root, bend, tip, w) in enumerate(CROWN_TUFTS):
        out.append({"name": f"crown{k}", "part": "mane", "group": "mane", "d": cl.path_of(tuft(root, bend, tip, w))})
    # the ear, behind the inner mane: the mane's locks lie over its base
    add("ear", "head", EAR, "mane", n=6)
    # the inner mane round the face, over the crown to the brow (the lion is not bald) and the ear's
    # base; its throat with the head's piece
    ruff = cl.outline(FACE_RUFF, 6)
    out.append({"name": "face_ruff", "part": "mane", "group": "mane", "d": cl.path_of(ruff)})
    out.append({"name": "throat", "part": "head", "group": "mane", "d": cl.path_of(clip_right(ruff, 148 * 4))})
    # the face on top, one silhouette with the mane: its jaw and cheek are drawn by `fades`
    add("head", "head", [(x * 4, y * 4) for x, y in HEAD], "mane", smooth=False)
    return out


BODY = "body"
# The near limbs, in front of the body: (their shapes, how many px their inner line runs from the
# silhouette before it has faded out, the lowest row it may start from: below the body, so the
# strokes rise from the elbow and the stifle and fade up into the body).
FRONT_LIMBS = [(("upper_arm", "forearm", "wrist", "fore_paw"), 14, 160), (("thigh", "near_hind"), 11, 150)]


def overlap_lines(shapes_):
    """Where a near limb lies over the body or a far limb, its edge as a short inner stroke that
    starts at the silhouette at line strength and fades out along the stroke: {(y, x): steps}."""
    line, groups, _ = cl.draw(shapes_)
    order = sorted({s.get("group", s["name"]): k for k, s in enumerate(shapes_)}.items(), key=lambda t: t[1])
    body_index = [g for g, _ in order].index(BODY)
    on_body = groups == body_index
    fill = {s["name"]: cl.down(cl.fill_4x(s["d"])) for s in shapes_ if s.get("group") == BODY}
    out = {}
    for names, reach, start in FRONT_LIMBS:
        mine = np.zeros_like(on_body)
        for n in names:
            mine |= fill[n]
        rest = np.zeros_like(on_body)
        for n, m in fill.items():
            if n not in names:
                rest |= m
        cand = cl.edge_inner(mine) & sd.grow(rest, 1) & on_body & ~line
        cand = cl.drop_elbows(cl.thin(cand))
        # walk along the stroke from where it touches the silhouette line
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
        for p, d in dist.items():
            if d < reach:
                steps = cl.LINE_STEPS - int(d * (cl.LINE_STEPS - 1) / reach)
                out[p] = max(out.get(p, 0), steps)
    return out


def fade_stroke(pts, hold, reach, top=cl.LINE_STEPS):
    """A 1 px stroke along `pts` (game px) at line strength for `hold` px, then fading out over
    `reach` px: {(y, x): steps}."""
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


def fades():
    """The face's jaw and cheek lock, and the inner ear: strokes that fade out."""
    out = fade_stroke(JAW, 19, 10)
    for pts, hold, reach in ([(c, 1, 5) for c in CROWN_LOCKS]
                             + [(c, 2, 6) for c in RUFF_LOCKS]):
        for p, k in fade_stroke(pts, hold, reach, cl.LINE_STEPS + 1).items():
            out[p] = max(out.get(p, 0), k)
    return out


def paint_overlaps(img, lines):
    """The fading inner strokes over the stardust, kept clear of the stars."""
    sky = sd.sky_index()
    # the dust right beside a stroke is cleared, so the stroke reads against the sky
    for (y, x), steps in lines.items():
        if steps > cl.LINE_STEPS and not LINE[y, x]:
            for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
                q = (y + dy, x + dx)
                if q not in lines and not LINE[q] and img[q][3] and tuple(int(c) for c in img[q][:3]) not in (sd.PAL["N8"], sd.PAL["N9"], sd.PAL["D0"]):
                    img[q] = 0
    for (y, x), steps in lines.items():
        if any(abs(x - sx) <= 2 and abs(y - sy) <= 2 for sx, sy in L):
            continue
        img[y, x, :3] = sd.PAL[sd.N[min(sky[y, x] + steps, 9)]]
        img[y, x, 3] = 255
    return img


def strokes():
    """The lines drawn inside a part: the mouth, and the toe splits on the near paws."""
    lines = [MOUTH, [(64.5, 215), (64, 213)], [(60, 215), (60, 213)],
             [(146.6, 203.6), (146.2, 201.4)], [(150.4, 201), (149, 199.6)]]
    return [{"name": f"line{k}", "part": "head" if k == 0 else ("haunch" if k < 3 else "heart"),
             "d": cl.path_of([(x * 4 + 2, y * 4 + 2) for x, y in pts])[:-2]} for k, pts in enumerate(lines)]


def clip_right(pts, x0):
    """Sutherland-Hodgman: the part of a closed polygon (4x points) right of x = x0 (4x)."""
    out = []
    for a, b in zip(pts, pts[1:] + pts[:1]):
        ina, inb = a[0] >= x0, b[0] >= x0
        if ina:
            out.append(a)
        if ina != inb:
            t = (x0 - a[0]) / (b[0] - a[0])
            out.append((x0, a[1] + (b[1] - a[1]) * t))
    return out


def face(img):
    """The eye by hand at true size: a dark almond (sky) in a ring of stardust three steps above
    the sky, its upper lid lit, and no pale speck near it."""
    sky = sd.sky_index()
    for x, y in EYE_RING:
        if (abs(x - EYE_C[0]) / 4.4) ** 2 + (abs(y - EYE_C[1]) / 2.6) ** 2 <= 1.0 and not LINE[y, x]:
            img[y, x, :3] = sd.PAL[sd.N[sky[y, x] + 3]]
            img[y, x, 3] = 255
    # no pale speck right by the eye (it would read as a second eye)
    for y in range(100, 115):
        for x in range(148, 163):
            if img[y, x, 3] and not LINE[y, x] and tuple(int(c) for c in img[y, x, :3]) in (sd.PAL["D0"], sd.PAL["N9"], sd.PAL["N8"]):
                img[y, x, :3] = sd.PAL[sd.N[sky[y, x] + 3]]
    for x, y in EYE_LID:
        img[y, x, :3] = sd.PAL[sd.N[min(sky[y, x] + cl.LINE_STEPS + 1, 9)]]
        img[y, x, 3] = 255
    for x, y in EYE_DARK:
        img[y, x] = 0
    return img


def thin_mane(img, parts):
    """Thins the stardust inside the mane (not its lines, not near a line) so each tuft's edge
    reads against the sky and the mane is no darker than the body."""
    near = LINE.copy()
    for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
        near |= np.roll(LINE, (dy, dx), (0, 1))
    drop = np.isin(parts, ["mane"]) & ~near & (sd.BAY > MANE_KEEP)
    img[drop] = 0
    return img


MANE_KEEP = 0.42
LINE = cl.draw(shapes(), strokes())[0]


def paint():
    img, parts = cl.semi_hollow(shapes(), L, SIZES, SEED, LIGHT, strokes=strokes())
    img = thin_mane(img, parts)
    img = paint_overlaps(img, overlap_lines(shapes()))
    img = paint_overlaps(img, fades())
    img = face(img)
    sd.check(img)
    wrong = [(s, parts[L[s][1], L[s][0]], p) for s, p in STAR_PARTS.items() if parts[L[s][1], L[s][0]] != p]
    assert not wrong, f"stars on the wrong part (star, on, want): {wrong}"
    tags = cl.part_tags(parts, img, L, STAR_PARTS)
    return img, sd.pieces(img, tags, PARTS)


def save(img, path):
    Image.fromarray(img, "RGBA").save(path)
    print(f"wrote {path.relative_to(ROOT)}")


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--preview", type=Path, help="also write the figure over the sky, x3, with its stars, here")
    args = parser.parse_args()
    ART.mkdir(parents=True, exist_ok=True)
    img, pieces = paint()
    used = sd.check(img)
    print(f"figure: {sum(used.values())} px, {used}")
    save(img, OUT)
    for part, piece in pieces.items():
        save(piece, ART / f"leo_piece_{part}.png")
    if args.preview:
        sd.preview(img, L, SIZES, SEGMENTS, scale=3).save(args.preview)
        print(f"wrote {args.preview}")
    import leo_part_paintings  # noqa: E402  (the part stages' own paintings)
    leo_part_paintings.build_parts()


if __name__ == "__main__":
    main()
