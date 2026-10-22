"""Sagittarius's part-stage paintings (chapter 5), in assets/art/:

  sagittarius_part_<stage>.png   each part stage's own painting (arrow, bow, body, legs, head),
                                 shown when that stage is complete

The same clean-line semi-hollow style as the whole figure (tools/art/build_sagittarius_figure.py,
tools/art/clean_line.py, tools/art/stardust.py): the final's archer, re-posed and scaled to each
stage's stars (StarMap.sagittarius_<stage>() in game/core/star_map.gd; each stage's landmarks and
sizes are checked against that file, the one source of truth). The final's seed and light (upper
left); one silhouette per stage, with fade strokes and open ends where it runs on into another part.

  arrow   the final's arrow drawn big enough to carry the stage alone: the nock (star 0, lit) at the
          lower left, the shaft (the final's 1 px shaft as a slim outlined rod) climbing straight
          through stars 1-3 to a broad barbed head round star 4 (big), its two barbs swept back as
          far as star 5, which sits in the lower one; two swept-back vanes just behind star 1
  bow     the final's Scythian recurve, mirrored (the arrow flies left): the grip (star 0, lit) the
          bow's most forward point, the limbs bending back through stars 1 and 3 to the recurves at
          stars 2 and 4, each tip curling forward past them; at full draw, both strings run from the
          tip curls to the nock at the right, the arrow (1 px shaft, two small vanes, a small barbed
          head) crossing the grip to its head round star 5 (big); the final's widths, no hand
  body    the final's man, drawn bigger and turned a little more to the viewer, facing right and
          leaning back into the draw: his back up the left through stars 0 and 1 to Nunki (2, big),
          the drawing arm the final's folded band from a round elbow behind him to the hand at his
          chest, the shoulders (3) under the final's bearded head, the bow arm leaving the deltoid
          (4) to the right and fading out toward the Bow's bow, the chest (5) curving in to the
          waist (6), where the torso fades out down into the Legs' horse
  legs    the final's horse facing right, its barrel and tail the final's outlines x1.4: star 0
          (lit) at the hip, where a stub of the man's waist fades out upward; the near hind carries
          stars 1-3 (stifle, hock, hoof), the near foreleg stars 4-6 (elbow, knee, hoof); the far
          legs stand behind, a step off; the near legs read in front through the final's fade strokes
  head    the final's bearded profile mirrored (looking left), about x3.4 and tipped forward: curls
          at the back (6) and on top (the crown, 5, big), the brow (4), the nose wedge over the cheek
          (3), the beard (2) running back under the chin (1); the neck (0, lit) leaves the jaw down
          to the right and fades out; the cloak, clasped at the nape, streams back and up behind the
          head to its frayed end round star 7

No colour outside the Stellar Sun palette; every pixel opaque or empty.

The whole figure and its chart pieces are built by tools/art/build_sagittarius_figure.py, which also
runs this module.

Run: python tools/art/sagittarius_part_paintings.py   (needs Pillow and numpy)
"""

import re
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import clean_line  # noqa: E402
from clean_line import Axis, catmull, path_of, placed  # noqa: E402
import stardust as sd  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / "assets" / "art"
STAR_MAP = ROOT / "game" / "core" / "star_map.gd"
PARTS = ("arrow", "bow", "body", "legs", "head")
S = 4
SEED = 11                                      # the final's seed
LIGHT = np.array([-0.55, -0.65, 0.52])         # the final's light: upper left


# --- shared shapes and passes (the final's builder), in game px --------------------------------

def loop(pts) -> str:
    """A closed outline through game-pixel centres: smooth through (x, y), a corner at (x, y, "s")."""
    sharp = [len(p) > 2 for p in pts]
    xy = [(np.array(p[:2], float) + 0.5) * S for p in pts]
    if not any(sharp):
        return path_of(clean_line.outline([np.array(p[:2], float) + 0.5 for p in pts]))
    k = sharp.index(True)
    xy, sharp = xy[k:] + xy[:k], sharp[k:] + sharp[:k]
    xy.append(xy[0])
    sharp.append(True)
    out, run = [], [xy[0]]
    for p, s in zip(xy[1:], sharp[1:]):
        run.append(p)
        if s:
            seg = catmull(run, 12) if len(run) > 2 else np.array(run)
            out.extend(list(seg[:-1]))
            run = [p]
    return path_of(out)


def ribbon(spine, widths, start="round", end="round") -> str:
    """A closed band along a spine (game px), full width interpolated over `widths`."""
    ax = Axis([(np.array(p, float) + 0.5) * S for p in spine])
    n = 70
    sp = np.array(spine, float)
    chord = np.concatenate([[0], np.cumsum(np.linalg.norm(np.diff(sp, axis=0), axis=1))])
    at = chord / chord[-1] if len(widths) == len(spine) else np.linspace(0, 1, len(widths))
    ws = np.interp(np.linspace(0, 1, n), at, widths) * S / 2
    left, right = [], []
    for s, w in zip(np.linspace(0, ax.L, n), ws):
        c, t, nrm = ax.frame(s)
        left.append(c + nrm * w)
        right.append(c - nrm * w)

    def cap(s, w, sign, kind):
        c, t, nrm = ax.frame(s)
        if kind == "point":
            return [c + sign * t * w * 1.6]
        return [c + sign * t * w * np.sin(a) + nrm * w * np.cos(a) * sign for a in np.linspace(0, np.pi, 9)[1:-1]]
    return path_of(left + cap(ax.L, ws[-1], 1, end) + right[::-1] + cap(0, ws[0], -1, start))


def shp(name, d, group, part):
    return {"name": name, "part": part, "group": group or name, "d": d}


def fade_strokes(img, fades, landmarks, top=clean_line.LINE_STEPS + 1):
    """The final's fade strokes: 1 px lines from `top` steps above the sky down to one, their last
    third broken; they never darken a pixel and keep clear of the stars."""
    sky = sd.sky_index()
    ramp = [tuple(sd.PAL[n]) for n in sd.N]
    for pts in fades:
        d = path_of(catmull([(np.array(p, float) + 0.5) * S for p in pts], 16))
        m = clean_line.stroke(d.replace(" Z", ""))
        ys, xs = np.nonzero(m)
        reach = np.hypot(xs - pts[0][0], ys - pts[0][1])
        total = reach.max() + 1e-6
        for k, i in enumerate(np.argsort(reach)):
            y, x, t = ys[i], xs[i], reach[i] / total
            if any((x - lx) ** 2 + (y - ly) ** 2 <= 4 for lx, ly in landmarks) or (t > 0.66 and k % 2):
                continue
            n = min(sky[y, x] + int(round(top + (1 - top) * t)), 9 if sky[y, x] >= 6 else 8)
            have = ramp.index(tuple(img[y, x, :3])) if img[y, x, 3] and tuple(img[y, x, :3]) in ramp else -1
            if n > have:
                img[y, x, :3] = sd.PAL[sd.N[n]]
                img[y, x, 3] = 255
    return img


def drop_strays(img, form):
    """The final's clean-up: only D0 specks stand alone off the form."""
    a = img[..., 3] > 0
    nb = sum(sd.shift(a, dy, dx).astype(int) for dy in (-1, 0, 1) for dx in (-1, 0, 1) if dy or dx)
    d0 = tuple(sd.PAL["D0"])
    for y, x in zip(*np.nonzero(a & (nb == 0) & ~form)):
        if tuple(int(c) for c in img[y, x, :3]) != d0:
            img[y, x] = 0
    return img


def open_end_along(img, origin, direction, length, box):
    """Fades the figure out over `length` px from `origin` along `direction` (game px), inside
    `box` (x0, y0, x1, y1): an open end where the figure runs on into another part."""
    d = np.array(direction, float)
    d /= np.linalg.norm(d)
    x0, y0, x1, y1 = box
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            t = ((x - origin[0]) * d[0] + (y - origin[1]) * d[1]) / length
            if img[y, x, 3] and t > 0 and (t >= 1 or sd.hsh(x, y, 9) < t ** 1.2):
                img[y, x] = 0
    return img


def open_end_up(img, x0, x1, y_full, y_gone):
    """Fades the figure out between rows y_full (whole) and y_gone (nothing) over columns x0..x1,
    and clears those columns past y_gone: an open end where the figure runs on into another part."""
    for y in range(min(y_full, y_gone), max(y_full, y_gone) + 1):
        t = (y - y_full) / (y_gone - y_full)
        for x in range(x0, x1 + 1):
            if img[y, x, 3] and (t >= 1 or sd.hsh(x, y, 9) < t ** 1.3):
                img[y, x] = 0
    lo, hi = (y_gone, 320) if y_gone > y_full else (0, y_gone)
    img[lo:hi, x0:x1 + 1] = 0
    return img


def drawn(sh, landmarks, sizes, strokes=()):
    """The final's semi-hollow pass over `sh` (and `strokes`), strays dropped; returns the image
    and the form (the shapes' fill and the strokes' lines)."""
    img, _ = clean_line.semi_hollow(sh, landmarks, sizes, SEED, LIGHT, strokes=strokes)
    line, groups, _ = clean_line.draw(sh, strokes)
    form = groups >= 0
    if strokes:
        form = form | line
    return drop_strays(img, form), form


# --- arrow ---------------------------------------------------------------------------------

# StarMap.sagittarius_arrow(): 0 the nock (lit), 1-3 the shaft, 4 the head (big), 5 the barb.
ARROW_L = [(36, 220), (62, 196), (88, 172), (114, 148), (140, 124), (150, 158)]
ARROW_SIZES = ["S", "S", "M", "S", "B", "M"]
ARROW_NOCK = np.array(ARROW_L[0], float)
ARROW_HEAD = np.array(ARROW_L[4], float)
ARROW_ANG = float(np.degrees(np.arctan2(ARROW_HEAD[1] - ARROW_NOCK[1], ARROW_HEAD[0] - ARROW_NOCK[0])))
ARROW_LEN = float(np.hypot(*(ARROW_HEAD - ARROW_NOCK)))
# Local frame (x along the shaft from the nock, y to its upper-left side), game px.
SHAFT_W = 4.4          # full width of the rod (the final's 1 px shaft at this scale)
BACK = 4.0             # the shaft runs this far behind the nock star
# One vane (local, upper side; the lower one mirrors it): from its front on the shaft just past
# star 1 it sweeps back and out to a trailing point, its back edge cut in towards the shaft.
VANE = [(37, 1.0, "s"), (28, 4.5), (18, 8), (9, 11), (4, 12.5, "s"), (7, 8), (11, 4.5), (13, 1.0, "s")]
# The nock: two short prongs either side of the string groove, behind star 0.
NOCK_PTS = [(-BACK, 2.6, "s"), (-BACK - 3.2, 2.4, "s"), (-BACK - 1.2, 0.7, "s"), (-BACK - 1.2, -0.7, "s"),
            (-BACK - 3.2, -2.4, "s"), (-BACK, -2.6, "s"), (2, -2.0, "s"), (2, 2.0, "s")]


def arrow_head_outline():
    """The head round star 4 (local, from star 4): a long swept broadhead, the final's barbed head
    drawn out to reach star 5: a sharp point well ahead of star 4, its edges hollowed a little, and
    two long barbs swept back to points, star 5 in the lower one, cut deep in to the neck."""
    pts = [(44, 0, "s"),
           (30, 7.5), (15, 15.5), (0, 24), (-12, 31.5), (-21, 37, "s"),   # the edge, out to the barb
           (-15, 29), (-10, 21.5), (-6, 13), (-3.5, 6), (-5.5, SHAFT_W / 2, "s"),  # back to the neck
           (-5.5, -SHAFT_W / 2, "s"), (-3.5, -6), (-6, -13), (-10, -21.5), (-15, -29),
           (-21, -37, "s"),
           (-12, -31.5), (0, -24), (15, -15.5), (30, -7.5)]
    xy = placed(ARROW_HEAD, ARROW_ANG, [p[:2] for p in pts])
    return [tuple(q) + p[2:] for q, p in zip(xy, pts)]


def arrow_fades():
    """Short fades where a vane lies over the shaft (the rod's two edges running on into the
    fletching), and the head's midrib from near the point back toward star 4."""
    out = []
    for side in (1, -1):
        pts = placed(ARROW_NOCK, ARROW_ANG, [(34, side * SHAFT_W / 2), (24, side * SHAFT_W / 2),
                                             (14, side * SHAFT_W / 2)])
        out.append([tuple(p) for p in pts])
    out.append([tuple(p) for p in placed(ARROW_HEAD, ARROW_ANG, [(38, 0), (24, 0), (9, 0)])])
    return out


def paint_arrow():
    sh = []
    shaft = placed(ARROW_NOCK, ARROW_ANG, [(-BACK, 0), (ARROW_LEN - 6, 0)])
    sh.append(shp("shaft", ribbon([tuple(p) for p in shaft], [SHAFT_W, SHAFT_W]), "arrow", "arrow"))
    for side in (1, -1):
        vane = placed(ARROW_NOCK, ARROW_ANG, [(x, y * side) for x, y, *_ in VANE])
        sh.append(shp(f"vane{side}", loop([tuple(q) + tuple(p[2:]) for q, p in zip(vane, VANE)]),
                      "arrow", "arrow"))
    nock = placed(ARROW_NOCK, ARROW_ANG, [p[:2] for p in NOCK_PTS])
    sh.append(shp("nock", loop([tuple(p) + ("s",) for p in nock]), "arrow", "arrow"))
    sh.append(shp("head", loop(arrow_head_outline()), "arrow", "arrow"))
    img, form = drawn(sh, ARROW_L, ARROW_SIZES)
    return fade_strokes(img, arrow_fades(), ARROW_L), form


# --- bow -----------------------------------------------------------------------------------

# StarMap.sagittarius_bow(): 0 the grip (lit), 1 the upper limb, 2 its recurve, 3 the lower limb,
# 4 its recurve, 5 the arrow's head (big).
BOW_L = [(90, 152), (100, 118), (124, 96), (100, 186), (124, 208), (58, 152)]
BOW_SIZES = ["M", "M", "S", "M", "S", "B"]
# The upper half's spine (game px) from the tip's curl down to the grip; the lower half mirrors it
# about the arrow's line (the stage's stars are symmetric). The limb leaves the grip bulging forward
# (left), bends back through star 1 to the recurve at star 2, and the tip curls forward past it.
BOW_MID = 152
BOW_UPPER = [(113, 83.5), (117, 83.6), (120.6, 85.6), (123.2, 89.6), (124.2, 95.5), (122.6, 102),
             (118, 108.5), (111, 113.5), (104, 117), (98, 121.5), (93.8, 128), (91.2, 136), (90.2, 144),
             (90, 152)]
# Full widths along it, tip to grip: the final's BOW_WIDTHS (2 at the tip, 10.5 at the grip).
BOW_UPPER_W = [2, 3, 3.5, 4.5, 5, 5.5, 6, 6.5, 7, 7.5, 8.5, 9.5, 10, 10.5]
# The tips, where each string leaves its curl, and the nock the strings meet at full draw.
BOW_TIP_UP = (113.5, 84.0)
BOW_TIP_DOWN = (113.5, 2 * BOW_MID - 84.0)
BOW_NOCK = (156, BOW_MID)
BOW_HEAD = BOW_L[5]
# The final's arrow, flying left (180 degrees): its barbed head x1.6 round star 5, its two vanes
# x1.4 at the nock.
BOW_ANG = 180.0
BOW_HEAD_K, BOW_VANE_K = 1.6, 1.4
BOW_ARROWHEAD = [tuple(p) for p in placed((BOW_HEAD[0] + 2, BOW_HEAD[1]), BOW_ANG, [
    (7.5 * BOW_HEAD_K, 0), (-1 * BOW_HEAD_K, 3.6 * BOW_HEAD_K), (-4.5 * BOW_HEAD_K, 3.4 * BOW_HEAD_K),
    (-1.8 * BOW_HEAD_K, 0.9 * BOW_HEAD_K), (-1.8 * BOW_HEAD_K, -0.9 * BOW_HEAD_K),
    (-4.5 * BOW_HEAD_K, -3.4 * BOW_HEAD_K), (-1 * BOW_HEAD_K, -3.6 * BOW_HEAD_K)])]
BOW_FLETCH = [tuple(p) for p in placed(BOW_NOCK, BOW_ANG, [(x * BOW_VANE_K, y * BOW_VANE_K) for x, y in
                                                           [(11, 0), (3.5, 2.7), (5.5, 0), (3.5, -2.7)]])]


def _line(p, q):
    return "M %.1f %.1f L %.1f %.1f" % ((p[0] + 0.5) * S, (p[1] + 0.5) * S, (q[0] + 0.5) * S, (q[1] + 0.5) * S)


def _closed(pts):
    return "M " + " L ".join("%.1f %.1f" % ((x + 0.5) * S, (y + 0.5) * S) for x, y in pts) + " Z"


def bow_spine():
    lower = [(x, 2 * BOW_MID - y) for x, y in BOW_UPPER[::-1]][1:]
    return BOW_UPPER + lower, BOW_UPPER_W + BOW_UPPER_W[::-1][1:]


def bow_strokes():
    """Both strings from the tip curls to the nock, the shaft from the nock to the head (over the
    bow: the arrow lies on its near side), and the arrowhead's and the fletching's outlines."""
    out = [{"name": name, "part": "bow", "d": _line(p, q)}
           for name, p, q in (("string_up", BOW_TIP_UP, BOW_NOCK), ("string_down", BOW_NOCK, BOW_TIP_DOWN))]
    out.append({"name": "shaft", "part": "bow",
                "d": _line(BOW_NOCK, (BOW_HEAD[0] + 2 - 1.8 * BOW_HEAD_K, BOW_HEAD[1]))})
    out.append({"name": "arrowhead_line", "part": "bow", "d": _closed(BOW_ARROWHEAD)})
    out.append({"name": "fletch_line", "part": "bow", "d": _closed(BOW_FLETCH)})
    return out


def paint_bow():
    sp, w = bow_spine()
    sh = [shp("limbs", ribbon(sp, w, start="point", end="point"), "bow", "bow"),
          shp("fletch", _closed(BOW_FLETCH), "fletch", "bow"),
          dict(shp("arrowhead", _closed(BOW_ARROWHEAD), "arrow", "bow"), outline=False)]
    return drawn(sh, BOW_L, BOW_SIZES, bow_strokes())


# --- body ----------------------------------------------------------------------------------

# StarMap.sagittarius_body(): 0 the flank (lit), 1 the back, 2 Nunki (big), 3 the top of the
# shoulders, 4 the front shoulder, 5 the chest, 6 the waist in front.
BODY_L = [(70, 186), (60, 156), (72, 128), (100, 124), (126, 140), (130, 172), (108, 194)]
BODY_SIZES = ["S", "M", "B", "S", "M", "S", "M"]
# The torso, leaning back: the back up the left, the shoulders over the top with the neck rising
# between them into the head, the deltoid, the chest swelling under it and in to the waist (open at
# the bottom).
TORSO = [(66, 214), (66, 204), (63, 194), (60, 184), (56, 172), (55, 160), (56, 148), (60, 136),
         (67, 126), (77, 120), (86, 117), (89, 106), (101, 105), (104, 117), (111, 121), (122, 127),
         (132, 132), (139, 139), (139, 150), (136, 162), (134, 173), (128, 185), (120, 197), (115, 206),
         (114, 214)]
BODY_WAIST_FADE = ((88, 200), (0, 1), 12, (50, 196, 130, 216))
# The head: the final's bearded profile (build_sagittarius_figure.py's "head"), facing right as in
# the final, x1.75 round the nape so the man has his head on his shoulders: curls at the back and on
# top, a brow over a nose wedge, a wedge beard pointing down and forward.
BODY_HEAD_SRC = [(45, 127), (40, 127, "s"), (36, 125), (35, 121), (39, 119, "s"), (35, 116), (36, 112),
                 (40, 111, "s"), (40, 108), (45, 107, "s"), (50, 108), (54, 110), (56, 113, "s"),
                 (55, 115, "s"), (63, 121, "s"), (57, 122, "s"), (58, 124, "s"), (56, 125, "s"), (59, 127),
                 (63, 132, "s"), (56, 130), (52, 128, "s")]
BODY_HEAD_K, BODY_HEAD_FROM, BODY_HEAD_TO = 1.75, (47, 127), (97, 117)
BODY_HEAD = [(BODY_HEAD_TO[0] + (p[0] - BODY_HEAD_FROM[0]) * BODY_HEAD_K,
              BODY_HEAD_TO[1] + (p[1] - BODY_HEAD_FROM[1]) * BODY_HEAD_K) + tuple(p[2:])
             for p in BODY_HEAD_SRC]
# The drawing arm at full draw, seen from the front: the upper arm short and foreshortened, back
# from the shoulder at Nunki to a sharp elbow just out behind him; the forearm folded forward along
# its top over the shoulders to the hand at the jaw (the string's anchor), so it has a forearm's
# length.
DRAW_ARM = ([(80, 137), (60, 133), (41, 128)], [15, 14, 11])
FOREARM = ([(39, 125), (58, 121), (78, 118), (96, 117)], [10, 10.5, 9.5, 8])
FIST = [(91, 111), (99, 109), (106, 111), (109, 116), (107, 121), (100, 123), (93, 122), (90, 117)]
# The bow arm leaving the deltoid, reaching right and down to the bow (the final's slope), fading
# out before the screen's edge.
BOW_ARM = ([(118, 140), (140, 149), (160, 157), (178, 164)], [17, 13, 11, 10])
BOW_ARM_FADE = ((150, 153), (0.92, 0.38), 22, (140, 130, 179, 190))
# The final's fade strokes, re-placed.
BODY_FADES = [
    # The forearm's lower edge, from the hand back toward the elbow over the shoulders: it splits
    # the band into the forearm on top and the upper arm under it.
    [(92, 122), (80, 123), (66, 125.5), (52, 128), (44, 129.5)],
    # The fist's knuckles at the jaw, under the beard.
    [(108, 119), (103, 122), (97, 122.5)],
    # The jaw behind the hand, fading up toward the ear.
    [(90, 115), (89, 110), (91, 105)],
    # The chest's lower edge under the front shoulder, fading in toward the middle.
    [(137, 160), (129, 163), (120, 162), (112, 158)],
]


def paint_body():
    sh = [shp("torso", loop(TORSO), "man", "body"),
          shp("bow_arm", ribbon(*BOW_ARM), "man", "body"),
          shp("draw_arm", ribbon(*DRAW_ARM, end="point"), "man", "body"),
          shp("forearm", ribbon(*FOREARM), "man", "body"),
          shp("head", loop(BODY_HEAD), "man", "body"),
          shp("fist", loop(FIST), "man", "body")]
    img, form = drawn(sh, BODY_L, BODY_SIZES)
    img = fade_strokes(img, BODY_FADES, BODY_L)
    for fade in (BODY_WAIST_FADE, BOW_ARM_FADE):
        img = open_end_along(img, *fade)
    return img, form


# --- legs ----------------------------------------------------------------------------------

# StarMap.sagittarius_legs(): 0 the hip (lit); 1 stifle, 2 hock, 3 hoof (hind); 4 elbow, 5 knee,
# 6 hoof (fore).
LEGS_L = [(90, 118), (62, 140), (46, 184), (62, 216), (118, 140), (134, 184), (118, 216)]
LEGS_SIZES = ["M", "S", "M", "B", "S", "M", "B"]
# The final's barrel (horse barrel and the man's waist, one silhouette) and tail, in the final's px.
BARREL = [(60, 166), (72, 166), (84, 168), (93, 172), (98, 179), (98, 186), (93, 193), (84, 199),
          (70, 202), (56, 205), (42, 202), (30, 199), (20, 195), (14, 188), (13, 180), (17, 172),
          (24, 166), (32, 167), (44, 168)]
TAIL = [(21, 167, "s"), (14, 170), (8, 176), (4, 183), (2, 190), (1, 198, "s"), (5, 193),
        (5, 201, "s"), (9, 194), (11, 199, "s"), (12, 191), (14, 183), (18, 176, "s")]
# The man's waist where it leaves the barrel (the final's torso foot, x1.4), fading out upward.
LEGS_WAIST = [(77, 112), (79, 102), (80, 93), (97, 92), (99, 101), (103, 110)]
LEGS_WAIST_FADE = (74, 106, 108, 96)     # columns, the row it starts to fade, the row it is gone
# The legs in this stage's px (the stars fix the joints; the shapes are the final's).
NEAR_HIND = [(34, 116), (50, 111), (62, 120), (68, 134), (66, 148), (60, 158), (55, 166), (52, 174),
             (51, 182), (54, 192), (58, 201), (61, 208), (64, 213), (67, 219, "s"), (57, 219, "s"),
             (57, 214), (54, 208), (49, 200), (43, 194), (38, 189, "s"), (40, 182), (43, 174), (42, 166),
             (36, 156), (30, 144), (29, 130)]
FAR_HIND = [(64, 146), (76, 146), (75, 158), (71, 168), (68, 178), (68, 188), (72, 198), (76, 207),
            (80, 213), (82, 219, "s"), (72, 219, "s"), (71, 213), (66, 204), (60, 194, "s"), (59, 182),
            (60, 168), (61, 156)]
NEAR_FORE = [(110, 136), (126, 134), (130, 148), (135, 162), (139, 174), (140, 183, "s"), (135, 192),
             (129, 201), (125, 208), (126, 214), (125, 219, "s"), (114, 219, "s"), (115, 213), (120, 205),
             (126, 195), (131, 186), (130, 177), (125, 165), (118, 154), (113, 146)]
FAR_FORE = [(97, 144), (109, 144), (108, 156), (105, 168), (104, 178), (105, 184), (104, 190), (103, 200),
            (103, 208), (105, 213), (106, 219, "s"), (96, 219, "s"), (97, 213), (98, 207), (98, 199),
            (97, 190), (96, 184), (97, 177), (96, 166), (95, 155)]
# The final's fade strokes, re-placed: the near hind's stifle in front of the far hind, fading up
# into the barrel; the near foreleg's front, fading up into the breast.
LEGS_FADES = [
    [(68, 150), (69, 141), (67, 131), (63, 122)],
    [(118, 154), (114, 146), (111, 139)],
]


def legs_pose(x, y):
    """The final's game px to this stage's: x1.4 about the barrel's rump and back."""
    return (28 + (x - 13) * 1.4, 100 + (y - 166) * 1.4)


def legs_tail():
    """The final's tail, x1.4 like the barrel and then drawn out x1.35 from its root at the croup,
    so it flares like the final's (the stage's legs are longer than the final's)."""
    root = np.array(legs_pose(21, 167))
    return [tuple(root + (np.array(legs_pose(*p[:2])) - root) * 1.35) + tuple(p[2:]) for p in TAIL]


def paint_legs():
    barrel = [legs_pose(*p[:2]) + tuple(p[2:]) for p in BARREL]
    sh = [shp("tail", loop(legs_tail()), "horse", "legs"),
          shp("far_hind", loop(FAR_HIND), "horse", "legs"),
          shp("far_fore", loop(FAR_FORE), "horse", "legs"),
          shp("waist", loop(LEGS_WAIST), "horse", "legs"),
          shp("barrel", loop(barrel), "horse", "legs"),
          shp("near_hind", loop(NEAR_HIND), "horse", "legs"),
          shp("near_fore", loop(NEAR_FORE), "horse", "legs")]
    img, form = drawn(sh, LEGS_L, LEGS_SIZES)
    img = fade_strokes(img, LEGS_FADES, LEGS_L)
    return open_end_up(img, *LEGS_WAIST_FADE), form


# --- head ----------------------------------------------------------------------------------

# StarMap.sagittarius_head(): 0 the neck (lit), 1 under the chin, 2 the beard, 3 the face, 4 the
# brow, 5 the crown (big), 6 the back of the head, 7 the cloak's end (the map's "feather").
HEAD_L = [(118, 182), (92, 194), (62, 180), (58, 148), (74, 122), (104, 124), (126, 144), (112, 94)]
HEAD_SIZES = ["S", "M", "S", "M", "S", "B", "M", "S"]
# The final's head loop (mirrored, x3.4, tipped forward) redrawn at this size, from the top curl
# round the face to the beard and back up the curls: sharp corners where the final has them.
HEAD = [(98, 106, "s"),                                     # the curl on top, at the crown
        (88, 107), (78, 111), (69, 118), (63.5, 126.5, "s"),  # forehead down to the brow
        (65, 133, "s"),                                     # the eye's notch under it
        (60, 141), (53, 149), (46.5, 156.5, "s"),           # the nose wedge
        (58, 160, "s"), (55, 164, "s"), (61, 167, "s"),     # under the nose, the lip, the mouth
        (57, 172), (53, 182), (49, 193), (46, 203.5, "s"),  # the beard's front down to its point
        (60, 203), (76, 202), (90, 200.5), (100, 197),      # its underside running back
        (107, 191, "s"),                                    # the jaw's corner
        (116, 186), (126, 178), (131, 172, "s"),            # behind the jaw to the nape
        (139, 165), (141, 156), (135, 149, "s"),            # the lower curl at the back
        (141, 141), (140, 130), (133, 122, "s"),            # the upper curl at the back
        (128, 114), (120, 109), (110, 107, "s"),            # up over the back of the crown
        (106, 102), (101, 102.5)]                           # the top curl
# The neck, from under the jaw down to the right, fading out where the shoulders would be.
NECK = [(104, 192), (122, 178), (134, 170), (140, 188), (142, 206), (124, 214), (110, 206)]
NECK_FADE = ((126, 198), (0.25, 1), 14, (98, 190, 150, 225))
# The final's cloak (the free end's pointed flicks on its trailing edge), clasped at the nape and
# streaming back and up behind the head to its broad frayed end above the crown.
CLOAK = [(128, 176, "s"), (138, 170), (144, 158), (146, 144), (148, 130), (153, 120),   # up behind the head
         (161, 115), (168, 113, "s"),                                                # its lower edge, out
         (164, 109, "s"), (175, 106, "s"), (167, 101, "s"), (176, 95, "s"), (166, 93, "s"),
         (171, 85, "s"), (160, 87, "s"),                                             # the frayed free end
         (150, 85), (138, 84), (126, 85), (115, 88), (107, 93), (102, 100, "s"),      # its upper edge back
         (114, 106), (126, 114), (134, 126), (137, 142), (133, 158), (124, 170, "s")]


def paint_head():
    sh = [shp("cloak", loop(CLOAK), "cloak", "head"),
          shp("neck", loop(NECK), "head", "head"),
          shp("head", loop(HEAD), "head", "head")]
    img, form = drawn(sh, HEAD_L, HEAD_SIZES)
    return open_end_along(img, *NECK_FADE), form


# --- the stages ----------------------------------------------------------------------------

STAGES = {
    "arrow": (ARROW_L, ARROW_SIZES, paint_arrow),
    "bow": (BOW_L, BOW_SIZES, paint_bow),
    "body": (BODY_L, BODY_SIZES, paint_body),
    "legs": (LEGS_L, LEGS_SIZES, paint_legs),
    "head": (HEAD_L, HEAD_SIZES, paint_head),
}
SIZE_CODES = {"SMALL": "S", "MEDIUM": "M", "BIG": "B"}


def stage_maps():
    """Each Sagittarius stage's landmarks and sizes, read from game/core/star_map.gd."""
    src = STAR_MAP.read_text()
    found = {}
    for part in PARTS:
        block = re.search(r"static func sagittarius_%s\(\) -> StarMap:(.*?)\n\n\n" % part, src, re.S).group(1)
        marks = re.search(r"map\.landmarks = \[(.*?)\]\n", block).group(1)
        sizes = re.search(r"map\.sizes = \[(.*?)\]\n", block).group(1)
        found[part] = ([(int(x), int(y)) for x, y in re.findall(r"Vector2i\((-?\d+), (-?\d+)\)", marks)],
                       [SIZE_CODES[s] for s in re.findall(r"Star\.Size\.(\w+)", sizes)])
    return found


def build_parts():
    """Writes each part stage's own painting, sagittarius_part_<stage>.png."""
    ART.mkdir(parents=True, exist_ok=True)
    maps = stage_maps()
    for part in PARTS:
        landmarks, sizes, paint = STAGES[part]
        assert maps[part] == (landmarks, sizes), \
            f"{part}: the painting's stars differ from StarMap.sagittarius_{part}()"
        img, form = paint()
        for k, (x, y) in enumerate(landmarks):
            assert form[y, x], f"{part}: star {k} at {(x, y)} is off the figure"
            assert img[y, x, 3], f"{part}: star {k} has no faint pixel"
        used = sd.check(img)
        print(f"part {part}: {sum(used.values())} px, {used}")
        sd.save(img, ART / f"sagittarius_part_{part}.png")


if __name__ == "__main__":
    build_parts()
