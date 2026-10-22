"""Builds the Sagittarius's final painting (the chapter's reward), in assets/art/:

  sagittarius_figure.png         the whole archer, the final stage's reward (StarMap.SAGITTARIUS_FIGURE)
  sagittarius_piece_<part>.png   the same painting cut into the chapter's five parts (arrow, bow,
                                 body, legs, head; game/core/chapter_def.gd), in the same
                                 full-screen home layout: the chapter chart shows the won ones
                                 dormant, then the whole figure once the final is won
  sagittarius_part_<stage>.png   each part stage's own painting, in the same clean-line style, the
                                 final's archer re-posed to each stage's stars
                                 (tools/art/sagittarius_part_paintings.py, run from here)

Clean-line semi-hollow like Scorpio (tools/art/clean_line.py, tools/art/stardust.py). Pose (Urania's
Mirror plate 24): the centaur faces right (west), torso three-quarters to the viewer and leaning back
into the draw. The left hand holds a Scythian recurve at Kaus Media, its fist below the arrow rest;
the right hand draws the string to the chest at Nunki, the upper arm back and down to a sharp elbow.
The arrow is one 1 px shaft from the nock beside Nunki through phi's crossing of the forearm to a
small barbed head round Alnasl, two small vanes at the nock end. Both strings run from the tip curls
to the nock, behind the limbs, the bow arm and the hand. The head is a bearded profile with curls; a
cloak clasped at the back of the neck streams back and left to a broad frayed end round xi. The horse
body runs left: tau on the flank, Ascella in the near foreleg's top, Rukbat in its hoof; the far
foreleg is lifted, both hind legs angle at the hock, the tail flares out behind.

The pieces partition the whole: each pixel goes with the part of the shape under it, else with the
nearest tagged pixel; each star's own pixel goes with its part.

Run: python tools/art/build_sagittarius_figure.py [--preview out.png]   (needs Pillow and numpy)
"""

import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import clean_line  # noqa: E402
from clean_line import Axis, catmull, path_of, placed  # noqa: E402
import stardust as sd  # noqa: E402
import sagittarius_part_paintings  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / "assets" / "art"
OUT = ART / "sagittarius_figure.png"
S = 4
SEED = 11
LIGHT = np.array([-0.55, -0.65, 0.52])

# StarMap.sagittarius() (game/core/star_map.gd): landmarks, sizes, segments.
L = [(150, 176), (124, 158), (124, 124), (128, 100), (88, 156), (62, 148), (60, 180), (84, 194),
     (128, 196), (146, 222), (40, 122), (22, 100), (86, 228)]
SIZES = ["M", "M", "M", "S", "S", "B", "S", "M", "B", "S", "S", "S", "S"]
SEGMENTS = [(0, 1), (1, 2), (2, 3), (1, 4), (4, 5), (5, 6), (6, 7), (7, 8), (8, 9), (5, 10),
            (10, 11), (7, 12)]
PARTS = ("arrow", "bow", "body", "legs", "head")
STAR_PARTS = {0: "arrow", 1: "arrow", 2: "bow", 3: "bow", 8: "bow", 9: "bow", 4: "body", 5: "body",
              6: "legs", 7: "legs", 12: "legs", 10: "head", 11: "head"}


# ---- Shape helpers, in game pixels (converted to clean_line's 4x space) ----

def loop(pts) -> str:
    """A closed outline through game-pixel centres: smooth (Catmull-Rom) through plain (x, y), a
    sharp corner at each (x, y, "s")."""
    sharp = [len(p) > 2 for p in pts]
    xy = [(np.array(p[:2], float) + 0.5) * S for p in pts]
    if not any(sharp):
        return path_of(clean_line.outline([np.array(p[:2], float) + 0.5 for p in pts]))
    k = sharp.index(True)
    xy = xy[k:] + xy[:k]
    sharp = sharp[k:] + sharp[:k]
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
    """A closed shape along a spine (game px): full width interpolated over `widths` (one per spine
    point, else evenly spread along it), each end "round" or "point"."""
    ax = Axis([(np.array(p, float) + 0.5) * S for p in spine])
    n = 70
    sp = np.array(spine, float)
    chord = np.concatenate([[0], np.cumsum(np.linalg.norm(np.diff(sp, axis=0), axis=1))])
    if len(widths) == len(spine):
        at = chord / chord[-1]
    else:
        at = np.linspace(0, 1, len(widths))
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
    pts = left + cap(ax.L, ws[-1], 1, end)[::1] + right[::-1]
    c0 = cap(0, ws[0], -1, start)
    pts += c0
    return path_of(pts)


def shp(name, part, d, group=None):
    return {"name": name, "part": part, "group": group or name, "d": d}


# The arrow: from the nock on the string at the hand beside Nunki, straight through Alnasl.
NOCK = (67, 140)
ALNASL = (150, 176)
ARROW_ANG = float(np.degrees(np.arctan2(ALNASL[1] - NOCK[1], ALNASL[0] - NOCK[0])))
ARROW_LEN = float(np.hypot(ALNASL[0] - NOCK[0], ALNASL[1] - NOCK[1]))


def along(u: float):
    """The point on the arrow's axis `u` game px from the nock."""
    a = np.radians(ARROW_ANG)
    return (NOCK[0] + np.cos(a) * u, NOCK[1] + np.sin(a) * u)


# The bow's spine from the upper tip to the lower one (game px): the upper recurve curls forward
# round mu, the limb sweeps back past Kaus Borealis, forward to the grip under the arrow, back past
# Kaus Australis, and the lower recurve curls forward round eta.
BOW_SPINE = [(140.5, 85.5), (137, 85.5), (134, 87.5), (131.5, 92), (129.5, 96.5), (127.5, 101),
             (124.5, 106), (122, 112), (121.5, 118.5), (122.5, 124.5), (123.5, 133), (124.5, 142),
             (125.5, 150), (126, 158), (128.5, 166), (131.5, 172), (132, 179), (130, 188),
             (128.3, 196), (132, 203), (137.5, 208.5), (142.5, 213.5), (145.5, 218), (146.5, 222.5),
             (147, 227), (147.5, 231), (149.5, 234.5), (153, 236), (156.5, 236)]
BOW_WIDTHS = [2, 3, 3.5, 4.5, 5, 5.5, 6, 6.5, 7, 7.5, 8, 8.5, 9.5, 10.5, 10, 9.5, 9, 8.5, 8, 7.5, 7, 6.5,
              6, 5.5, 4.5, 4, 3.5, 3, 2]
# The riser's stretch above the arrow rest (Kaus Media): the arrow piece's share of the bow.
RISER = (12, 14)

# ---- The figure, back to front ----

def figure_shapes() -> list:
    sh = []
    # The cloak: clasped at the back of the neck (hidden behind the head and the shoulders), it
    # streams back and left at a shallow slant and widens like a flag to a broad free end round xi;
    # its pointed flicks are all on that trailing (left) edge. Its lower edge stays well above the
    # drawing arm.
    sh.append(shp("cloak", "head", loop([
        (46, 121, "s"), (39, 118), (32, 111), (27, 103), (23, 96), (19, 91, "s"),
        (15, 97, "s"), (8, 96, "s"), (10, 103, "s"), (2, 104, "s"), (6, 111, "s"), (0, 114, "s"),
        (5, 119, "s"), (2, 125, "s"), (10, 126), (19, 128), (29, 129), (38, 130), (46, 131, "s")])))
    # The tail: narrow at the croup, swept out and back at a slant, flaring like a flame into three
    # pointed flicks well above the hooves.
    sh.append(shp("tail", "legs", loop([
        (21, 167, "s"), (14, 170), (8, 176), (4, 183), (2, 190), (1, 198, "s"), (5, 193),
        (5, 201, "s"), (9, 194), (11, 199, "s"), (12, 191), (14, 183), (18, 176, "s")]), group="centaur"))
    # The far hind leg, behind the barrel and a step ahead of the near one: gaskin down and back to
    # a sharp hock, the cannon angled forward under it to its own hoof.
    sh.append(shp("far_hind", "legs", loop([
        (42, 192), (53, 192), (54, 201), (51, 208), (48, 214), (49, 220), (52, 228), (55, 233),
        (57, 238, "s"), (47, 238, "s"), (48, 233), (46, 227), (43, 220), (40, 214, "s"),
        (41, 206), (40, 198)]), group="centaur"))
    # The far foreleg, lifted: forearm forward to a sharp knee, the cannon tucked back under it,
    # a small hoof.
    sh.append(shp("far_fore", "legs", loop([
        (88, 192), (95, 190), (101, 196), (107, 205, "s"), (104, 209), (100, 213, "s"),
        (101, 217, "s"), (96, 219, "s"), (95, 214, "s"), (99, 207), (95, 202), (89, 199)]), group="centaur"))
    # The horse's barrel and the human torso, one silhouette (no line at the waist): a croup rise,
    # the belly dipping mid-barrel, the breast pushed out in front of the man's waist.
    sh.append(shp("barrel", "legs", loop([
        (60, 166), (72, 166), (84, 168), (93, 172), (98, 179), (98, 186), (93, 193), (84, 199),
        (70, 202), (56, 205), (42, 202), (30, 199), (20, 195), (14, 188), (13, 180), (17, 172),
        (24, 166), (32, 167), (44, 168)]), group="centaur"))
    # The man's torso, leaning back into the draw: a short neck, square shoulders with a corner in
    # front, tapering to the waist.
    sh.append(shp("torso", "body", loop([
        (44, 121, "s"), (50, 121, "s"), (51, 129), (54, 132), (60, 133), (64, 136, "s"),
        (65, 141), (65, 147), (66, 156), (66, 166), (60, 170), (50, 170), (49, 160), (45, 150),
        (41, 142), (39, 135, "s"), (43, 131)]), group="centaur"))
    # The near foreleg, its own part over the barrel: the elbow jutting back at Ascella's level,
    # the forearm's front running up into the breast, a knee bump, a slim cannon.
    sh.append(shp("near_fore", "legs", loop([
        (75, 192, "s"), (80, 188), (88, 184), (95, 181), (100, 179, "s"), (100, 185), (97, 191), (93, 197),
        (91, 204), (92, 210), (89, 215), (88, 221), (88, 227), (84, 227), (84, 221), (83, 214),
        (80, 208), (78, 201), (76, 196)]), group="centaur"))
    # Its hoof, a part of its own round Rukbat: a small trapezoid.
    sh.append(shp("near_fore_hoof", "legs", loop([
        (83, 226, "s"), (89, 226, "s"), (92, 231, "s"), (81, 231, "s")]), group="centaur"))
    # The near hind leg: thigh over the barrel, stifle forward, a broad gaskin down to the hock
    # jutting back, the cannon angled forward under it to a planted hoof.
    sh.append(shp("near_hind", "legs", loop([
        (20, 176), (30, 175), (37, 182), (41, 194), (37, 203), (32, 209), (30, 215), (31, 223),
        (33, 230), (36, 237, "s"), (25, 238, "s"), (26, 231), (23, 223), (17, 212, "s"),
        (17, 204), (14, 192), (15, 182)]), group="centaur"))
    # The bow arm: from the front shoulder (inside the torso, so it leaves the chest with no seam)
    # through phi to the wrist, its top a clear step below the shaft all the way to the fist.
    sh.append(shp("bow_arm", "body", ribbon(
        [(60, 146), (70, 150), (80, 153.5), (88, 156.5), (100, 161.5), (112, 166.5), (122, 172)],
        [7, 6.5, 6, 6, 5.5, 5, 4.5]), group="centaur"))
    # The bow fist round the grip, below the arrow with a gap over it: one silhouette with the arm
    # and the bow, so the hand fades into the grip (its knuckles are a fade stroke).
    sh.append(shp("fist", "body", loop([
        (121, 171.5), (127, 171), (133, 171.5), (137.5, 173.5), (138.5, 177.5), (135, 181),
        (127, 181.5), (121, 179)]), group="centaur"))
    # The bow, drawn the right way round for an archer facing right at full draw: its back bulges
    # toward the target with the grip its most forward point, both limbs bend back toward the
    # archer, and each tip recurves forward, away from him (a Scythian recurve), the upper one up
    # past mu, the lower one down past eta, so each string leaves its tip clear of the limb. One
    # silhouette with the bow arm and fist; the riser's stretch above the arrow rest (Kaus Media)
    # goes with the arrow piece.
    sh.append(shp("bow_limbs", "bow", ribbon(BOW_SPINE, BOW_WIDTHS, start="point", end="point"), group="centaur"))
    sh.append(shp("riser", "arrow", ribbon(BOW_SPINE[RISER[0]:RISER[1] + 1],
                                           [w - 0.5 for w in BOW_WIDTHS[RISER[0]:RISER[1] + 1]]), group="centaur"))
    # The drawing arm: the upper arm and the forearm folded together at full draw, one band from
    # the back of the shoulders to a round elbow out behind him; the forearm's top edge is a fade
    # stroke running back from the hand, so the bend reads without cutting the arm off.
    sh.append(shp("draw_arm", "body", ribbon(
        [(25, 138), (33, 139.5), (44, 141)], [5, 8, 9]), group="centaur"))
    sh.append(shp("hand", "body", loop([
        (55, 142.5), (60, 140), (66, 139.5), (69.5, 142), (69.5, 148.5), (65.5, 153), (58, 153), (54, 149)]), group="centaur"))
    # The head in profile, looking down the arrow: two broad curls on the back and one on top, a
    # brow over a nose wedge, a wedge beard pointing down and forward; pi inside at the back.
    sh.append(shp("head", "head", loop([
        (45, 127), (40, 127, "s"), (36, 125), (35, 121), (39, 119, "s"), (35, 116), (36, 112),
        (40, 111, "s"), (40, 108), (45, 107, "s"), (50, 108), (54, 110), (56, 113, "s"),
        (55, 115, "s"), (63, 121, "s"), (57, 122, "s"), (58, 124, "s"), (56, 125, "s"), (59, 127),
        (63, 132, "s"), (56, 130), (52, 128, "s")]), group="centaur"))
    # The fletching at the nock end: two small vanes lying along the shaft, swept back to points,
    # over the bow arm (so the arm's outline does not run through them).
    sh.append(shp("fletch", "arrow", _closed(FLETCH), group="fletch"))
    # The arrow's head round Alnasl: a small barbed point on the shaft's line. Its outline is the
    # "arrowhead_line" stroke, so its barbs keep their points at this size; this shape only holds
    # its stardust and its part.
    head = dict(shp("arrowhead", "arrow", _closed(ARROWHEAD), group="arrow"), outline=False)
    sh.append(head)
    return sh


def _line(p, q):
    return "M %.1f %.1f L %.1f %.1f" % ((p[0] + 0.5) * S, (p[1] + 0.5) * S, (q[0] + 0.5) * S, (q[1] + 0.5) * S)


def _closed(pts):
    return "M " + " L ".join("%.1f %.1f" % ((x + 0.5) * S, (y + 0.5) * S) for x, y in pts) + " Z"


# The fletching at the nock end: two small vanes along the shaft, swept back to points.
FLETCH = [tuple(p) for p in placed(NOCK, ARROW_ANG, [(11, 0), (3.5, 2.7), (5.5, 0), (3.5, -2.7)])]
# The arrowhead's outline round Alnasl, in game px.
ARROWHEAD = [tuple(p) for p in placed(ALNASL, ARROW_ANG, [
    (7.5, 0), (-1, 3.6), (-4.5, 3.4), (-1.8, 0.9), (-1.8, -0.9), (-4.5, -3.4), (-1, -3.6)])]


# The bow's tips, where the recurves end: each string runs straight from there to the nock and
# clears its limb (the tip is the bow's outermost point as seen from the nock). It passes behind
# the bow arm and the horse's breast, and in front of the drawing hand, so the V shows at the nock.
TIP_UP = (134, 88)
TIP_DOWN = (147, 233)


def behind(p, q, skip=("hand",)) -> str:
    """The string from p to q (game px) as a path, with the stretches over the figure's shapes
    (except `skip`) left out."""
    cover = np.zeros((320, 180), bool)
    for sh in figure_shapes():
        if sh["group"] in ("bow", "centaur") and sh["name"] not in skip:
            cover |= clean_line.down(clean_line.fill_4x(sh["d"]))
    p, q = np.array(p, float), np.array(q, float)
    n = int(np.hypot(*(q - p)) * 8)
    pts = [p + (q - p) * t for t in np.linspace(0, 1, n)]
    on = [bool(cover[int(round(y)), int(round(x))]) for x, y in pts]
    runs, cur = [], []
    for k, (pt, b) in enumerate(zip(pts, on)):
        if not b:
            if not cur and k > 0:
                cur.append(pts[k - 1])
            cur.append(pt)
        elif cur:
            cur.append(pt)
            runs.append(cur)
            cur = []
    if cur:
        runs.append(cur)
    return " ".join(_line(r[0], r[-1]) for r in runs if len(r) > 2)


STRINGS = [
    {"name": "string_up", "part": "bow", "d": behind(TIP_UP, NOCK)},
    {"name": "string_down", "part": "bow", "d": behind(NOCK, TIP_DOWN)},
    # The shaft: one straight 1 px line from the nock to the arrowhead, like the strings.
    {"name": "shaft", "part": "arrow", "d": _line(NOCK, along(ARROW_LEN - 1.8))},
    {"name": "arrowhead_line", "part": "arrow", "d": _closed(ARROWHEAD)},
    {"name": "fletch_line", "part": "arrow", "d": _closed(FLETCH)},
]


# Inner lines where a near part must read in front of the one silhouette: short strokes (game px,
# from the strong end) that fade out into the stardust instead of closing off a part.
FADES = [
    # The drawing hand's underside and the forearm's lower edge across the torso, fading toward
    # the elbow.
    [(69, 149), (65, 153), (58, 153), (54, 149.5), (48, 147), (43, 145.5)],
    # The drawing forearm's top edge, from the fist at Nunki back to the elbow: it splits the band
    # into the forearm in front and the upper arm behind it.
    [(56, 143), (48, 140.8), (40, 138.8), (33, 137.3)],
    # The bow fist's knuckles in front of the grip, fading up into the riser.
    [(137, 179), (133.5, 177), (130, 174.5), (127.5, 172.5)],
    # The near hind leg's stifle, in front of the far hind leg, fading up into the barrel.
    [(38, 205), (40.5, 198), (40.5, 191), (38, 184)],
    # The near foreleg's front, in front of the lifted far foreleg, fading up into the breast.
    [(91, 205), (93, 198), (96.5, 192), (99, 186)],
]


def fade_strokes(img: np.ndarray, fades, top: int = clean_line.LINE_STEPS + 1) -> np.ndarray:
    """Draws each fade stroke as a 1 px line from `top` steps above the sky at its start down to
    one step at its end, its last third broken every other pixel; it never darkens a pixel and
    keeps clear of the stars."""
    sky = sd.sky_index()
    ramp = [tuple(sd.PAL[n]) for n in sd.N]
    for pts in fades:
        d = path_of(catmull([(np.array(p, float) + 0.5) * S for p in pts], 16))
        m = clean_line.stroke(d.replace(" Z", ""))
        ys, xs = np.nonzero(m)
        start = np.array(pts[0], float)
        reach = np.hypot(xs - start[0], ys - start[1])
        order = np.argsort(reach)
        total = reach.max() + 1e-6
        for k, i in enumerate(order):
            y, x, t = ys[i], xs[i], reach[i] / total
            if any((x - lx) ** 2 + (y - ly) ** 2 <= 4 for lx, ly in L):
                continue
            if t > 0.66 and k % 2:
                continue
            want = int(round(top + (1 - top) * t))
            n = min(sky[y, x] + want, 9 if sky[y, x] >= 6 else 8)
            have = ramp.index(tuple(img[y, x, :3])) if img[y, x, 3] and tuple(img[y, x, :3]) in ramp else -1
            if n > have:
                img[y, x, :3] = sd.PAL[sd.N[n]]
                img[y, x, 3] = 255
    return img


def drop_strays(img: np.ndarray, form: np.ndarray) -> np.ndarray:
    """Clears each lone N7/N8/N9 pixel off the form (it reads as dirt): only D0 specks stand alone
    in the sky."""
    a = img[..., 3] > 0
    nb = sum(sd.shift(a, dy, dx).astype(int) for dy in (-1, 0, 1) for dx in (-1, 0, 1) if dy or dx)
    d0 = tuple(sd.PAL["D0"])
    for y, x in zip(*np.nonzero(a & (nb == 0) & ~form)):
        if tuple(int(c) for c in img[y, x, :3]) != d0:
            img[y, x] = 0
    return img


def save(img: np.ndarray, path: Path):
    Image.fromarray(img, "RGBA").save(path)
    print(f"wrote {path.relative_to(ROOT)}")


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--preview", type=Path, help="also write the figure over the sky, x3, here")
    args = parser.parse_args()
    ART.mkdir(parents=True, exist_ok=True)
    shapes = figure_shapes()
    img, parts = clean_line.semi_hollow(shapes, L, SIZES, SEED, LIGHT, strokes=STRINGS)
    _, groups, _ = clean_line.draw(shapes, STRINGS)
    img = drop_strays(img, groups >= 0)
    img = fade_strokes(img, FADES)
    used = sd.check(img)
    print(f"figure: {sum(used.values())} px, {used}")
    tags = clean_line.part_tags(parts, img, L, STAR_PARTS)
    pieces = sd.pieces(img, tags, PARTS)
    save(img, OUT)
    for part, piece in pieces.items():
        save(piece, ART / f"sagittarius_piece_{part}.png")
    if args.preview:
        sd.preview(img, L, SIZES, SEGMENTS).save(args.preview)
        print(f"wrote {args.preview}")
    sagittarius_part_paintings.build_parts()


if __name__ == "__main__":
    main()
