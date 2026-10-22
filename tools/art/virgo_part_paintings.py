"""Virgo's part-stage paintings (chapter 4), in assets/art/:

  virgo_part_<part>.png    each part stage's own painting (head, wing, robe, feet, wheat), shown
                           when that stage is complete (StarMap.virgo_<part>()'s painting)

The same clean-line semi-hollow style as the whole figure (tools/art/build_virgo_figure.py,
tools/art/clean_line.py, tools/art/stardust.py): one clean line round each silhouette, hollow with
Bayer-dithered stardust inside, lit from the upper left, the body fading out in a Bayer ramp where
the stage's part ends (as the final's raised hand fades) so each stage shows a part, not a cut.
Each stage is drawn round StarMap.virgo_<part>()'s stars (game/core/star_map.gd); each stage's
landmarks and sizes are checked against that file, the one source of truth.

  head    the final's upper body (the reworked head with its bun, the torso's front, the lowered
          arm across the chest) moved by one similarity (x3.2, tilted 6 degrees so the face lifts
          a little toward the Sun), the bust fading out below the waist. Star 5 (big) is the eye,
          Leo's way (a dark almond round the star, a lit lid); 4 the back of the skull, 3 the nape
          by the bun, 2 between the shoulder blades, 1 the small of the back, 0 (lit) the hip.
  wing    seen from behind: the head with its parting and the low knot at the nape, the shoulders,
          the final's raised arm (each bone fitted onto its joints, about x1.42) reaching up-left,
          the hand fading out short of star 3 (its own faint pixel, as Vindemiatrix in the final),
          the right arm hanging and fading with the back. The wing grows from behind the right
          shoulder blade in the final's robe language: one clean line, the trailing edge cut into
          pointed swept feather tongues, a curved line where the coverts end, short lines in from
          the notches. Star 0 (lit) between the shoulder blades, 1 the elbow, 2 the forearm,
          4 the coverts, 5 the wing's middle, 6 among the primaries.
  robe    the final's robe hanging from the girdle at the waist (star 0) in three falls (a long
          middle fall, the two sides lifted by the wind), its hem cut into pointed swept tongues,
          long thin folds from the gathered waist, the bodice fading out upward.
  feet    at about the final's scale, she leaps with her legs parted: the robe over the hips and
          thighs, hanging between the knees in one fall (stars 4 and 8 in its tongues), the bare
          shins and pointed feet below, the heel jutting back; stars 3 and 7 just past the toes
          (their own faint pixels). Star 0 (lit) at the hips under the girdle.
  wheat   the final's ear (its notches, awns and grains) stood upright and scaled up so Spica
          (star 4) sits in its upper grains, the stalk's three joints (stars 1-3) each putting out a
          leaf blade by turns; the final's small fist holds the stalk low on a forearm from the
          lower right that fades out, the stalk's foot (star 0, lit) under it.

No colour outside the Stellar Sun palette; every pixel opaque or empty.

The whole figure and its chart pieces are built by tools/art/build_virgo_figure.py, which also
runs this module.

Run: python tools/art/virgo_part_paintings.py   (needs Pillow and numpy)
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
PARTS = ("head", "wing", "robe", "feet", "wheat")
SEED = 11
LIGHT = (-0.55, -0.65, 0.52)  # the final's light: upper left


# --- shared helpers ------------------------------------------------------------------------

def chain(*segs, n=10):
    """Catmull-Rom runs joined end to end (sharp where they meet), as 4x points."""
    out = []
    for seg in segs:
        c = cl.catmull([np.array(p, float) * 4 for p in seg], n)
        out.extend(c[:-1])
    return out


def limb(spine, us, ws, n=60, tip=1.0):
    """A closed band along `spine` (game px), half-width ws at fractions us, round at both ends (the
    end cap `tip` times as long as it is wide). 4x points."""
    ax = cl.Axis([np.array(p, float) * 4 for p in spine])
    left, right = [], []
    for s in np.linspace(0, ax.L, n):
        c, t, nrm = ax.frame(s)
        w = float(np.interp(s / ax.L, us, ws)) * 4
        left.append(c + nrm * w)
        right.append(c - nrm * w)
    c1, t1, n1 = ax.frame(ax.L)
    w1 = ws[-1] * 4
    cap_end = [c1 + t1 * w1 * tip * math.sin(a) + n1 * w1 * math.cos(a) for a in np.linspace(0, math.pi, 9)[1:-1]]
    c0, t0, n0 = ax.frame(0)
    w0 = ws[0] * 4
    cap_start = [c0 - t0 * w0 * math.sin(a) - n0 * w0 * math.cos(a) for a in np.linspace(0, math.pi, 9)[1:-1]]
    return left + cap_end + right[::-1] + cap_start


def stroke_d(pts, n):
    """An open stroke through the points (game px), as clean_line's path data."""
    c = cl.catmull([np.array(p, float) * 4 + 2 for p in pts], n)
    return "M %s %s " % tuple(np.round(c[0], 1)) + " ".join("L %s %s" % tuple(np.round(p, 1)) for p in c[1:])


def mask_of(shp, *names):
    m = np.zeros((sd.H, sd.W), bool)
    for s in shp:
        if s["name"] in names:
            m |= cl.down(cl.fill_4x(s["d"]))
    return m


def level(sky, y, x, steps):
    """The Stardust ramp's colour `steps` above the sky at this pixel."""
    return sd.PAL[sd.N[int(min(sky[y, x] + steps, 8))]]


def fade(img, sky, px, keep, line, ghost=0.25):
    """Bayer-fades the pixels `px` out where the dither is at or above `keep` (lines just past it
    stay as a faint ghost one step above the sky)."""
    for y, x in zip(*np.nonzero(px)):
        b = sd.BAY[y, x]
        if b < keep[y, x]:
            continue
        if line[y, x] and b < keep[y, x] + ghost:
            img[y, x, :3] = level(sky, y, x, 1)
        else:
            img[y, x, 3] = 0


def along(spine, ys, xs, back=False):
    """Each pixel's fraction along a polyline (past its end > 1), by its nearest point on it. With
    `back`, a pixel nearest the last segment counts from that segment's line even before its start."""
    pts = np.array(spine, float)
    seg = np.diff(pts, axis=0)
    lens = np.linalg.norm(seg, axis=1)
    cum = np.concatenate([[0], np.cumsum(lens)])
    best_d = np.full(ys.shape, 1e9)
    best_s = np.zeros(ys.shape)
    for k, (a, v, ln) in enumerate(zip(pts[:-1], seg, lens)):
        t = ((xs - a[0]) * v[0] + (ys - a[1]) * v[1]) / (ln * ln)
        last = k == len(seg) - 1
        tc = np.maximum(t, 0) if last else np.clip(t, 0, 1)
        d = np.hypot(xs - (a[0] + tc * v[0]), ys - (a[1] + tc * v[1]))
        s = cum[k] + (t if back and last else tc) * ln
        better = d < best_d
        best_d[better] = d[better]
        best_s[better] = s[better]
    return best_s / cum[-1]


def close(img, sky, landmarks):
    """Each star keeps its own faint pixel; nothing under the end panel; the Sun's glow clamped."""
    for x, y in landmarks:
        if not img[y, x, 3]:
            img[y, x, :3] = level(sky, y, x, 1)
            img[y, x, 3] = 255
    img[cl.END_PANEL_TOP:] = 0
    return sd.sun_clamp(img)


def painted(shapes, strokes, landmarks, sizes, finish):
    """The stage's shapes painted semi-hollow, then its own finish (fades and details)."""
    shp = shapes()
    img, _ = cl.semi_hollow(shp, landmarks, sizes, SEED, LIGHT, strokes=strokes())
    line, _, _ = cl.draw(shp, strokes())
    return finish(img, line)


# --- stage 1: the Head ---------------------------------------------------------------------

HEAD_L = [(58, 206), (84, 188), (108, 168), (122, 140), (116, 108), (148, 126)]
HEAD_SIZES = ["S", "S", "M", "M", "S", "B"]

# The move: the final's eye (Zavijava) onto star 5, scaled and tilted.
HEAD_EYE_F = (162.0, 136.0)
HEAD_SCALE = 3.2
HEAD_TILT = -6.0              # degrees; - lifts the face (counter-clockwise on screen)

# The final's upper body (the reworked pass), final game px. The face's profile, smoothed from the
# final's pixel profile (NEW_PROFILE): forehead, brow, the straight nose to its tip, the nostril,
# upper lip, mouth, lower lip, the chin's dip, chin, throat.
HEAD_PROFILE = [(164.5, 128.4), (165.6, 130.2), (166.3, 132.5), (166.9, 134.6), (167.6, 136.4),
                (169.0, 138.0), (170.6, 139.4), (169.4, 140.5), (168.0, 140.8), (168.6, 141.9),
                (168.2, 143.1), (167.6, 143.8), (168.2, 144.8), (167.7, 145.9), (167.3, 147.0),
                (165.8, 147.8), (164.0, 148.3)]
HEAD_SKULL = [(164.5, 128.4), (162.6, 126.2), (159, 125.3), (155.4, 126), (152.4, 128), (150.8, 130.6),
              (150.2, 133)]
HEAD_BUN = [(150.2, 133), (148.6, 133.4), (147.4, 135), (147.4, 137.6), (148.6, 139.6), (150, 140.4)]
HEAD_INSIDE = [(150, 140.4), (152, 144), (155, 147.5), (158.5, 150)]
HEAD_THROAT = [(158.5, 150), (161.4, 149.6), (163.4, 148.8), (164.0, 148.3)]
# Two strands sweeping back over the skull to the bun (at this size a pair, so the big skull reads
# as hair gathered back, not bare).
HEAD_STRANDS = [[(161.0, 128.2), (157.2, 127.6), (153.8, 129.3), (151.6, 132.0), (150.3, 134.6)],
                [(158.6, 130.6), (155.6, 131.3), (153.3, 133.3), (151.8, 136.2)]]
HEAD_HAIRLINE = [(164, 128.4), (160.2, 129), (157.4, 131), (156.2, 134.4)]
HEAD_JAW = [(156.8, 137.5), (157.4, 141), (159, 144.6), (162.5, 148.4)]
# The bust's torso: the final's TORSO_NEW front (the chest round under the throat, curving into the
# belly) with its back run straight on from the nape down to the waist (the final's back hump is the
# raised arm's shoulder, which this stage leaves out); below the waist it fades.
HEAD_BUST = [(149.6, 141.4), (146.6, 145.6), (142.5, 149.4), (137.5, 152.8), (131.5, 156.0), (125.5, 159.0),
             (119.5, 162.5), (114, 168), (118, 178), (128, 177), (138, 170.5),
             (146, 167), (152, 164.5), (157.5, 163), (160.2, 160.6), (161.6, 157.4), (161.8, 154.2),
             (160.6, 151.4), (159, 149.8), (154, 146)]
# The near (lowered) arm across the chest: the final's shoulder, ARM_MID and elbow.
HEAD_ARM = [(154, 156), (138, 162), (123.5, 167)]
HEAD_ARM_W = ([0, 0.45, 1], [4.6, 4.6, 3.7])
HEAD_ARM_FADE = (4.0, 15.0)   # the arm's inner line fades out toward its shoulder (final px)
# The eye (Leo's way), at this scale: the dark almond round the star, the eye-white ring, the lid.
HEAD_EYE_R = (5.6, 2.8)       # the eye-white ring (stage px)
HEAD_LID_SPAN = (-6.5, 5.5)   # the upper lid's x span round the star (stage px, before the tilt)
HEAD_FACE_FILL = 2
HEAD_FACE_SOLID = 18          # solid this far back from the profile (stage px), then fading
HEAD_FACE_FADE = 6.0
# The bust fades out below the waist: along the back (star 3 to star 0) past FADE[0], gone at FADE[1]
# (stage px beyond star 0), and the arm past its own end.
HEAD_FADE = (-4.0, 16.0)
HEAD_ARM_END = (0.55, 1.0)    # the near upper arm: whole to this fraction, gone past it


def head_move(p):
    """The final's point p on this stage: Zavijava onto star 5, scaled and tilted."""
    a = math.radians(HEAD_TILT)
    dx, dy = p[0] - HEAD_EYE_F[0], p[1] - HEAD_EYE_F[1]
    x = dx * math.cos(a) - dy * math.sin(a)
    y = dx * math.sin(a) + dy * math.cos(a)
    return np.array([HEAD_L[5][0] + x * HEAD_SCALE, HEAD_L[5][1] + y * HEAD_SCALE])


def head_moved(pts):
    return [head_move(p) for p in pts]


def head_shapes():
    out = []

    def add(name, pts4, group="body", **kw):
        out.append({"name": name, "part": "head", "group": group, "d": cl.path_of(pts4), **kw})

    add("torso", cl.outline(head_moved(HEAD_BUST), 8))
    add("head", chain(head_moved(HEAD_SKULL), head_moved(HEAD_BUN), head_moved(HEAD_INSIDE),
                      head_moved(HEAD_THROAT), head_moved(HEAD_PROFILE[::-1])))
    face = head_moved(HEAD_HAIRLINE) + head_moved(HEAD_JAW) + head_moved(HEAD_PROFILE[::-1])
    add("face", [p * 4 for p in face], group="face", outline=False)
    add("arm", limb(head_moved(HEAD_ARM), HEAD_ARM_W[0], [w * HEAD_SCALE for w in HEAD_ARM_W[1]]), group="arm")
    return out


def head_strokes():
    return [{"name": f"hair{k}", "part": "head", "d": stroke_d(head_moved(pts), 12)}
            for k, pts in enumerate([HEAD_HAIRLINE] + HEAD_STRANDS)]


def head_eye(img, sky):
    """The eye, Leo's way, round star 5: a ring of eye-white stardust, the dark almond corners
    between the star's arms, the lit upper lid (tilted with the head)."""
    cx, cy = HEAD_L[5]
    a = math.radians(HEAD_TILT)
    for y in range(cy - 5, cy + 6):
        for x in range(cx - 8, cx + 9):
            dx, dy = x - cx, y - cy
            u = dx * math.cos(-a) - dy * math.sin(-a)
            v = dx * math.sin(-a) + dy * math.cos(-a)
            e = (u / HEAD_EYE_R[0]) ** 2 + (v / HEAD_EYE_R[1]) ** 2
            if e <= 1.0:
                corner = abs(u) >= 2 and abs(v) >= 1.5 or (abs(u) > 3.5 and abs(v) < 1.5 and e > 0.55)
                if corner:
                    img[y, x, 3] = 0
                else:
                    img[y, x, :3] = level(sky, y, x, 3)
                    img[y, x, 3] = 255
    for k in np.linspace(HEAD_LID_SPAN[0], HEAD_LID_SPAN[1], 30):
        v = -HEAD_EYE_R[1] - 1.0 - 1.4 * (1 - (k / 6.5) ** 2)
        x = round(cx + k * math.cos(a) - v * math.sin(a))
        y = round(cy + k * math.sin(a) + v * math.cos(a))
        img[y, x, :3] = level(sky, y, x, 5)
        img[y, x, 3] = 255


def head_finish(img, line):
    sky = sd.sky_index()
    shp = head_shapes()
    ys, xs = np.mgrid[0:sd.H, 0:sd.W]
    # the face: solid two steps over the sky, fading back into the hair; the profile bright
    face = mask_of(shp, "face")
    prof = {}
    pl = cl.stroke(cl.path_of([p * 4 + 2 for p in head_moved(HEAD_PROFILE)]).replace(" Z", ""))
    for y, x in zip(*np.nonzero(pl)):
        prof[y] = max(prof.get(y, 0), x)
    for y, x in zip(*np.nonzero(face & ~line)):
        py = prof.get(y)
        if py is None:
            py = prof[min(prof, key=lambda r: abs(r - y))]
        back = max(0, py - x - HEAD_FACE_SOLID)
        if back == 0 or sd.BAY[y, x] < 1.0 - back / HEAD_FACE_FADE:
            img[y, x, :3] = level(sky, y, x, HEAD_FACE_FILL)
            img[y, x, 3] = 255
    nose = head_move((169.5, 139.0))
    for y, x in zip(*np.nonzero(line & sd.grow(pl, 1))):
        bright = math.hypot(x - nose[0], y - nose[1]) < 9
        img[y, x, :3] = level(sky, y, x, 6 if bright else 5)
        img[y, x, 3] = 255
    # nothing in front of the profile
    for y, x in prof.items():
        img[y, x + 1:min(x + 8, sd.W), 3] = 0
    head_eye(img, sky)
    # the near arm's line over the chest fades out toward its shoulder
    body = mask_of(shp, "torso", "head")
    inner = body & sd.shift(body, 1, 0) & sd.shift(body, -1, 0) & sd.shift(body, 0, 1) & sd.shift(body, 0, -1)
    arm = mask_of(shp, "arm")
    sh = head_move(HEAD_ARM[0])
    r = np.hypot(xs - sh[0], ys - sh[1])
    a0, a1 = HEAD_ARM_FADE[0] * 1.6, HEAD_ARM_FADE[1] * 1.6
    keep = np.clip((r - a0) / (a1 - a0), 0, 1)
    fade(img, sky, line & inner & sd.grow(arm, 1) & (r < a1), keep, line, ghost=0.35)
    # the bust fades out below the waist, the arm past its own end
    drawn = img[..., 3] > 0
    a, b = np.array(HEAD_L[3], float), np.array(HEAD_L[0], float)
    u = (b - a) / np.linalg.norm(b - a)
    past = (xs - b[0]) * u[0] + (ys - b[1]) * u[1]
    keep = np.clip((HEAD_FADE[1] - past) / (HEAD_FADE[1] - HEAD_FADE[0]), 0, 1) ** 1.2
    fo = along(head_moved(HEAD_ARM), ys, xs, back=True)
    keep_fo = np.clip((HEAD_ARM_END[1] - fo) / (HEAD_ARM_END[1] - HEAD_ARM_END[0]), 0, 1) ** 1.2
    fore = sd.grow(mask_of(shp, "arm"), 1) & (fo > HEAD_ARM_END[0])
    keep = np.where(fore, np.minimum(keep, keep_fo), keep)
    fade(img, sky, drawn & (keep < 1), keep, line)
    return close(img, sky, HEAD_L)


def paint_head():
    return painted(head_shapes, head_strokes, HEAD_L, HEAD_SIZES, head_finish)


# --- stage 2: the Wing ---------------------------------------------------------------------

WING_L = [(96, 206), (72, 184), (54, 156), (46, 124), (120, 184), (142, 158), (150, 126)]
WING_SIZES = ["S", "B", "M", "S", "B", "M", "S"]

# The final's raised arm (final game px).
WING_SHOULDER_F = (133.0, 154.0)
WING_ELBOW_F, WING_TIP_F = (107.0, 134.0), (98.8, 99.5)
WING_UPPER_UP = [(133, 154), (120, 144), (107, 134)]
WING_UPPER_UP_W = ([0, 0.1, 0.3, 0.55, 0.85, 1], [5.8, 6.0, 5.0, 4.2, 4.1, 4.5])
WING_FORE_UP = [(107, 134), (104.2, 122), (101, 110), (99.6, 104), (98.8, 99.5)]
WING_FORE_UP_W = ([0, 0.25, 0.72, 0.86, 1], [4.4, 3.7, 2.2, 2.5, 1.6])
WING_HAND_FADE = (0.88, 1.02)  # the hand: whole to this fraction of the forearm's spine, gone past it
# Each bone of the final's arm fitted onto its joints here (a similarity per bone, so its shape and
# widths stay the final's): shoulder, elbow, hand tip (stage px).
WING_ARM_JOINTS = [(86.0, 207.0), (60.0, 168.0), (47.6, 129.0)]
WING_ARM_WIDTH = 1.42         # the arm's widths x this (its own scale)
# The shoulders seen from behind: the two deltoids, the trapezius sloping up to the neck between
# them, the back fading out below.
WING_TRUNK = [(78, 213), (77.5, 205), (81, 199.5), (87, 197.5), (92.5, 196), (94, 191), (94.2, 184),
              (101.8, 184), (102, 191), (103.5, 196), (109, 197), (115, 198.5), (118.5, 204), (118, 213),
              (115, 226), (112, 240), (84, 240), (81, 226)]
WING_FADE_Y = (213.0, 232.0)  # the shoulders' back and chest fade out below
# The head seen from behind (the final's at about x1.35: 33 px from crown to nape): the skull's
# back, the hair drawn back into the final's low knot at the nape; one silhouette with the neck and
# shoulders (no line where it joins them).
WING_HEAD = [(98, 158), (104.5, 159.5), (109, 164), (110.5, 170), (110, 177), (108, 183), (104.5, 188),
             (102, 191.5), (94, 191.5), (91.5, 188), (88, 183), (86, 177), (85.5, 170), (87, 164),
             (91.5, 159.5)]
WING_KNOT = (98.0, 188.0, 6.0)  # the knot at the nape (centre x, y, radius)
WING_PARTING = [(98, 160.5), (97.6, 167), (97.8, 174), (98, 180.5)]   # the parting, down to the knot
# The wing (stage px). The leading edge, from behind the right shoulder blade up to the tip.
WING_LEADING = [(104, 199), (108, 190), (115, 180), (123, 171), (130, 161), (135, 149), (138.5, 136),
                (141, 122), (143, 108), (145.5, 95)]
# The trailing edge's feather tips, tip first; each notch between two cuts NOTCH px in.
WING_TIPS = [(153, 93), (161, 103), (168, 115), (172.5, 129), (174.5, 144), (172.5, 159), (167, 173),
             (159, 185), (149, 195), (138, 203), (126, 209)]
WING_NOTCH = 10.0
WING_ROOT_END = (111, 209)
WING_C = (138.0, 150.0)       # the notches cut toward here
WING_LOWER_ARM = [(108.0, 206.0), (113.5, 222.0), (116.5, 240.0)]   # the right arm, hanging (fades with the back)
WING_LOWER_ARM_W = 6.2
# Where the coverts end: one curved line, root to tip, along the wing's middle.
WING_COVERTS = [(113, 203), (122, 195), (132, 186), (141, 175), (147, 162), (150, 149), (150.5, 140)]
WING_FEATHER_IN = 0.75        # each line in from a notch runs this far toward the coverts' line


def wing_fit(a, b, to_a, to_b):
    """The similarity taking final points a, b onto stage points to_a, to_b."""
    fa, fb = complex(*a), complex(*b)
    ta, tb = complex(*to_a), complex(*to_b)
    k = (tb - ta) / (fb - fa)

    def move(p):
        z = ta + k * (complex(p[0], p[1]) - fa)
        return np.array([z.real, z.imag])
    return move


def wing_arm_movers():
    j = WING_ARM_JOINTS
    return (wing_fit(WING_SHOULDER_F, WING_ELBOW_F, j[0], j[1]),
            wing_fit(WING_ELBOW_F, WING_TIP_F, j[1], j[2]))


def wing_notches():
    tips = [np.array(t, float) for t in WING_TIPS] + [np.array(WING_ROOT_END, float)]
    cen = np.array(WING_C)
    out = []
    for k in range(len(tips) - 2):
        a, b = tips[k], tips[k + 1]
        mid = (a + b) / 2
        inward = (cen - mid) / np.linalg.norm(cen - mid)
        out.append(mid + inward * WING_NOTCH + (b - a) * 0.22)
    return out


def wing_outline():
    """The wing: the leading edge up to the tip, then down the trailing edge tongue by tongue (each
    a pointed tip and a notch, swept back toward the root), back to the root."""
    tips = [np.array(t, float) for t in WING_TIPS] + [np.array(WING_ROOT_END, float)]
    ns = wing_notches()
    lead_end = np.array(WING_LEADING[-1], float)
    runs = [WING_LEADING, [tuple(lead_end), tuple((lead_end + tips[0]) / 2 + np.array((0.5, -1.5))), tuple(tips[0])]]
    for k in range(len(tips) - 1):
        a, b = tips[k], tips[k + 1]
        if k == len(tips) - 2:
            runs.append([tuple(a), tuple((a + b) / 2 + (np.array(WING_C) - (a + b) / 2) * 0.08), tuple(b)])
            break
        n = ns[k]
        runs.append([tuple(a), tuple(a * 0.5 + n * 0.5 + (b - a) * 0.12), tuple(n)])
        runs.append([tuple(n), tuple(n * 0.45 + b * 0.55), tuple(b)])
    runs.append([WING_ROOT_END, (106, 206), (104, 199)])
    return chain(*runs, n=8)


def wing_shapes():
    tu, tf = wing_arm_movers()
    up = limb([tu(p) for p in WING_UPPER_UP], WING_UPPER_UP_W[0], [w * WING_ARM_WIDTH for w in WING_UPPER_UP_W[1]])
    fo = limb([tf(p) for p in WING_FORE_UP], WING_FORE_UP_W[0], [w * WING_ARM_WIDTH for w in WING_FORE_UP_W[1]])
    cx, cy, r = WING_KNOT
    knot = [np.array((cx + r * math.cos(a), cy + r * math.sin(a) * 0.82)) * 4
            for a in np.linspace(0, 2 * math.pi, 40, endpoint=False)]
    return [
        {"name": "wing", "part": "wing", "group": "wing", "d": cl.path_of(wing_outline())},
        {"name": "trunk", "part": "wing", "group": "body", "d": cl.path_of(cl.outline(WING_TRUNK, 8))},
        {"name": "lower_arm", "part": "wing", "group": "body",
         "d": cl.path_of(limb(WING_LOWER_ARM, [0, 1], [WING_LOWER_ARM_W, WING_LOWER_ARM_W * 0.85]))},
        {"name": "head", "part": "wing", "group": "body", "d": cl.path_of(cl.outline(WING_HEAD, 8))},
        {"name": "body_upper", "part": "wing", "group": "body", "d": cl.path_of(up)},
        {"name": "body_fore", "part": "wing", "group": "body", "d": cl.path_of(fo)},
        # the knot at the nape, its own round shape over the skull (its line breaks the head's
        # outline below, as the final's bun does at the back of her head)
        {"name": "knot", "part": "wing", "group": "knot", "d": cl.path_of(knot)},
    ]


def wing_strokes():
    out = [{"name": "strand0", "part": "wing", "d": stroke_d(WING_PARTING, 8)},
           {"name": "coverts", "part": "wing", "d": stroke_d(WING_COVERTS, 10)}]
    cov = cl.catmull([np.array(p, float) for p in WING_COVERTS], 20)
    for k, n in enumerate(wing_notches()):
        q = cov[np.argmin(np.linalg.norm(cov - n, axis=1))]
        out.append({"name": f"feather{k}", "part": "wing",
                    "d": stroke_d([n + (q - n) * 0.12, n + (q - n) * WING_FEATHER_IN], 4)})
    return out


def wing_finish(img, line):
    sky = sd.sky_index()
    shp = wing_shapes()
    ys, xs = np.mgrid[0:sd.H, 0:sd.W]
    # the hand fades into the sky short of its star
    hand = sd.grow(mask_of(shp, "body_fore"), 3) & (ys < 150)
    f = along([wing_arm_movers()[1](p) for p in WING_FORE_UP], ys, xs)
    keep = np.clip((WING_HAND_FADE[1] - f) / (WING_HAND_FADE[1] - WING_HAND_FADE[0]), 0, 1) ** 1.3 * 1.15
    fade(img, sky, hand & (img[..., 3] > 0) & (f > WING_HAND_FADE[0]), keep, line)
    # the shoulders' back and chest fade out below
    keep = np.clip((WING_FADE_Y[1] - ys) / (WING_FADE_Y[1] - WING_FADE_Y[0]), 0, 1) ** 1.2
    fade(img, sky, (img[..., 3] > 0) & (ys > WING_FADE_Y[0]), keep, line)
    return close(img, sky, WING_L)


def paint_wing():
    return painted(wing_shapes, wing_strokes, WING_L, WING_SIZES, wing_finish)


# --- stage 3: the Robe ---------------------------------------------------------------------

ROBE_L = [(90, 100), (68, 124), (50, 152), (90, 136), (90, 168), (90, 200), (112, 124), (130, 152)]
ROBE_SIZES = ["S", "B", "S", "M", "M", "S", "B", "S"]

# The robe (stage px): one outline of runs meeting at sharp corners. The bodice above the girdle
# (fades out upward), the right side down to the right fall's tongue, the hem tongue by tongue, and
# up the left side back to the bodice.
ROBE_OUTLINE = [
    [(99, 81), (98.5, 87.5), (97.5, 94), (100, 99.5), (105, 103.5), (112, 108), (119, 114), (126, 121.5),
     (132, 130), (136.5, 140), (139.5, 151), (141, 162), (141.5, 172), (141, 180)],    # right side: hip, then hanging
    [(141, 180), (137, 177), (132, 175.5)],                # the right fall's tongue, swept back left, to the notch
    [(132, 175.5), (128.5, 182), (124, 188)],              # a small tongue
    [(124, 188), (122, 184.5), (120, 182)],                # notch
    [(120, 182), (116.5, 190), (111.5, 197)],              # a middle-sized tongue
    [(111.5, 197), (109, 193), (106, 190)],                # notch
    [(106, 190), (102.5, 201), (96.5, 212.5), (88, 224)],  # the middle fall's long tongue, its tip swept left
    [(88, 224), (85, 212), (82, 200), (79, 190)],
    [(79, 190), (73.5, 193), (68, 196)],                   # notch, to a small tongue
    [(68, 196), (66, 191), (64, 186)],
    [(64, 186), (58, 188.5), (52, 190)],                   # another, smaller
    [(52, 190), (50, 185), (48, 180)],
    [(48, 180), (37, 177.5), (27, 174.5), (18, 170)],      # notch, under the left fall's long tongue, lifted by the wind
    [(18, 170), (22, 162.5), (28, 152), (36, 140), (45, 129), (55, 119), (64, 112), (71.5, 107.5),
     (77, 104), (80.5, 99.5), (82.5, 94), (81.5, 87.5), (81, 81)],      # left side, up to the waist
    [(81, 81), (90, 79.5), (99, 81)],                       # (the bodice's top, faded out)
]
ROBE_GIRDLE = [(79.5, 105.5), (84.5, 106.8), (90, 107.2), (95.5, 106.8), (100.5, 105.5)]
# The folds: two long ones from the gathered waist down beside the middle fall (the final's A and
# E, here hanging), and the cloth's folds running out from the waist to the hem's notches (the
# wind pulls the left ones long and low, the right ones hang).
ROBE_FOLDS = [
    [(86, 112), (83.5, 128), (79, 148), (74.5, 167), (72.5, 181)],
    [(94, 112), (96.5, 128), (101, 148), (104, 166), (105, 179)],
    [(84, 113.5), (75, 127), (65, 143), (55.5, 160), (50, 171)],
    [(29, 166.5), (36.5, 155.5), (45, 145), (54, 136)],
    [(97, 114), (106.5, 128), (115.5, 146), (122, 163), (127.5, 172)],
    [(95.5, 115), (101.5, 135), (108, 155), (114, 172)],
]
ROBE_TOP_FADE = (101.0, 82.0)  # the bodice: whole below the first row, gone at the second


def robe_shapes():
    return [{"name": "robe", "part": "robe", "group": "robe", "d": cl.path_of(chain(*ROBE_OUTLINE))}]


def robe_strokes():
    out = [{"name": "girdle", "part": "robe", "d": stroke_d(ROBE_GIRDLE, 12)}]
    for k, f in enumerate(ROBE_FOLDS):
        out.append({"name": f"fold{k}", "part": "robe", "d": stroke_d(f, 12)})
    return out


def top_fade(img, line, rows, landmarks):
    """The bodice fades out upward: whole below rows[0], gone at rows[1]."""
    sky = sd.sky_index()
    ys, xs = np.mgrid[0:sd.H, 0:sd.W]
    keep = np.clip((ys - rows[1]) / (rows[0] - rows[1]), 0, 1) ** 1.2
    fade(img, sky, (img[..., 3] > 0) & (ys < rows[0]), keep, line)
    return close(img, sky, landmarks)


def paint_robe():
    return painted(robe_shapes, robe_strokes, ROBE_L, ROBE_SIZES,
                   lambda img, line: top_fade(img, line, ROBE_TOP_FADE, ROBE_L))


# --- stage 4: the Feet ---------------------------------------------------------------------

FEET_L = [(90, 104), (66, 128), (52, 158), (30, 180), (64, 188), (114, 128), (128, 158), (150, 180), (116, 188)]
FEET_SIZES = ["M", "B", "M", "S", "S", "M", "B", "S", "S"]

# The robe over the thighs, the bare shins and pointed feet below it (stage px), at about the
# final's scale (head 24 px): hip to knee about 36 px, knee to ankle about 36, the pointed foot
# about 20 from heel to toe. The robe's left half (the right is its mirror, x -> 180 - x, joined in
# the middle of the hem: the cloth hangs between the parted knees in one fall, its hem sagging
# lowest in the middle).
FEET_ROBE_L = [
    [(82, 86), (81.5, 92), (81, 98), (77.5, 104), (72.5, 110.5), (67.5, 117), (62.5, 123.5),
     (58, 129.5)],                                                     # the waist, hip and outer thigh
    [(58, 129.5), (61.5, 131.5), (64, 135.5)],                          # the hem over the thigh (the knee bare)
    [(64, 135.5), (61.5, 142), (60.5, 155), (60, 168), (59.5, 181), (59.5, 192), (58.5, 199)],   # hanging inside the knee to T1
    [(58, 199), (62.5, 195.5), (66.5, 194)],                            # T1's underside, to a notch
    [(66.5, 194), (68.5, 200), (70, 206)],                              # T2
    [(70, 206), (73.5, 201), (78, 198.5)],
    [(78, 198.5), (80.5, 205), (82, 212)],                              # T3 (long, by the middle)
]
FEET_SHIN_L = [(63, 129), (58.5, 137), (55, 145), (52, 156), (49.5, 163.5), (47, 169)]   # mid-thigh, knee, shin, ankle (left)
FEET_SHIN_W = ([0, 0.3, 0.45, 0.62, 0.85, 1], [5.4, 4.1, 4.8, 4.6, 3.1, 2.5])
# The pointed foot, local px from the ankle along its pointing direction (x) with the instep on the
# -y side: the ankle, the instep arching down to the toes, the sole, the arch and the heel jutting back.
FEET_FOOT = [(-3, -2.8), (1.5, -3.0), (5.5, -2.7), (9.5, -2.0), (12, -1.0), (13, 0.2), (12.3, 1.3), (9.5, 1.9),
             (6.5, 2.0), (4, 2.8), (1.5, 4.4), (-1.5, 5.6), (-4.2, 5.4), (-5.4, 3.2), (-4.8, 0.2)]
FEET_FOOT_L = ((47.0, 169.0), 150.0)   # (the left ankle, its pointing angle in degrees: down and out)
FEET_FOOT_K = 1.3             # the foot's size: about 20 px heel to toe, a human foot by these legs
FEET_GIRDLE = [(80, 98.5), (85, 100), (90, 100.4), (95, 100), (100, 98.5)]
# The folds (left; each mirrored right): the thigh's top and the inside of the thigh under the cloth
# (the final's folds B and C), and short folds up from the hem's notches.
FEET_FOLDS_L = [
    [(82, 112), (76.5, 121), (70.5, 130.5), (63.5, 139.5)],      # the thigh's top, to the knee
    [(85.5, 122), (80.5, 136), (75.5, 152), (71.5, 170), (69.5, 186)],   # the fall from the crotch, down
    [(70, 140), (66.5, 156)],                                    # a short fold off the knee
    [(78, 194.5), (78.5, 186)],                                  # up from the hem's notches
]
FEET_TOP_FADE = (99.0, 88.0)  # the bodice: whole below the first row, gone at the second


def mirror(pts):
    return [(180 - x, y) for x, y in pts]


def feet_foot(ankle, ang, right):
    pts = [(x, -y if right else y) for x, y in FEET_FOOT]
    return [p * 4 for p in cl.placed(ankle, ang, [(x * FEET_FOOT_K, y * FEET_FOOT_K) for x, y in pts])]


def feet_robe_outline():
    """The left half, the middle of the hem (T3's tip, a notch on the axis, the right T3), the right
    half mirrored back up, and the bodice's top (faded out)."""
    left = [list(r) for r in FEET_ROBE_L]
    middle = [[(82, 212), (86, 207.5), (90, 206), (94, 207.5), (98, 212)]]
    right = [mirror(r)[::-1] for r in FEET_ROBE_L[::-1]]
    top = [[(98, 86), (90, 85.5), (82, 86)]]
    return chain(*left, *middle, *right, *top)


def feet_shapes():
    (ax, ay), ang = FEET_FOOT_L
    out = []
    for side, shin, ankle, a, right in (("l", FEET_SHIN_L, (ax, ay), ang, False),
                                         ("r", mirror(FEET_SHIN_L), (180 - ax, ay), 180 - ang, True)):
        out.append({"name": f"shin_{side}", "part": "feet", "group": f"leg_{side}",
                    "d": cl.path_of(limb(shin, *FEET_SHIN_W))})
        out.append({"name": f"foot_{side}", "part": "feet", "group": f"leg_{side}",
                    "d": cl.path_of(feet_foot(ankle, a, right))})
    out.append({"name": "robe", "part": "feet", "group": "robe", "d": cl.path_of(feet_robe_outline())})
    return out


def feet_strokes():
    out = [{"name": "girdle", "part": "feet", "d": stroke_d(FEET_GIRDLE, 12)}]
    for k, f in enumerate(FEET_FOLDS_L):
        out.append({"name": f"fold{k}l", "part": "feet", "d": stroke_d(f, 12)})
        out.append({"name": f"fold{k}r", "part": "feet", "d": stroke_d(mirror(f), 12)})
    return out


def paint_feet():
    return painted(feet_shapes, feet_strokes, FEET_L, FEET_SIZES,
                   lambda img, line: top_fade(img, line, FEET_TOP_FADE, FEET_L))


# --- stage 5: the Wheat --------------------------------------------------------------------

WHEAT_L = [(90, 222), (90, 190), (90, 158), (90, 126), (90, 96), (66, 178), (114, 146), (66, 114)]
WHEAT_SIZES = ["S", "M", "S", "M", "B", "S", "S", "S"]

# The ear: the final's, in its own frame (x along it from the base to the tip, y across).
WHEAT_EAR_LEN = 38.0
WHEAT_EAR_WIDTH = [(0, 1.0), (4, 3.0), (9, 4.5), (16, 4.8), (21, 5.4), (26, 4.9), (31, 4.6), (35.5, 2.6), (38, 0)]
WHEAT_NOTCHES = {1: (4, 9.5, 15, 26.5, 32), -1: (6.5, 12, 17.5, 29, 34.5)}
WHEAT_NOTCH_DEPTH = 2.6
WHEAT_NOTCH_LEAN = 1.2
WHEAT_GRAIN_IN = 3.2          # each grain's line runs in from its notch, down to the axis (local px)
WHEAT_SPICA_CLEAR = 3.5       # no grain line within this many local px of Spica along the ear
WHEAT_AWNS = ((0.0, 0.0, 0, 4.6), (2.4, 1.2, 32, 4.6), (2.4, -1.2, -32, 4.6), (6.0, 2.4, 52, 3.2), (6.0, -2.4, -52, 3.2))
WHEAT_EAR_BEND = -3.0         # the final's nod (-6) halved: it stands up here
WHEAT_EAR_K = 1.16            # along: the final's 38 px ear to 44 px
WHEAT_EAR_W = 1.4             # across
WHEAT_EAR_BASE = (90.0, 127.5)  # its base at the top joint, pointing straight up
WHEAT_EAR_ANGLE = -90.0
# The stalk, its joints and leaves (stage px).
WHEAT_STALK = [(90, 230), (90, 127.5)]
WHEAT_STALK_W = 2.7
WHEAT_NODE_W = 3.6            # the joints swell a little
# Each leaf: a blade from its joint out through its star, arching up and drooping at the tip
# (spine), and its half-widths along it.
WHEAT_LEAVES = [
    [(90, 191), (80, 183.5), (66, 178), (54, 176), (45, 178.5)],
    [(90, 159), (101, 151.5), (114, 146), (126, 144.5), (134, 147.5)],
    [(90, 127), (79, 119.5), (66, 114), (55, 111.5), (47, 113.5)],
]
WHEAT_LEAF_W = ([0, 0.15, 0.45, 0.8, 1], [2.6, 3.8, 3.6, 2.0, 0.5])
# The hand: the final's FIST (its game px, round (101, 185.4)), x HAND_K, round HAND_AT.
WHEAT_FIST_F = [(103, 181), (99.6, 180.8), (97.2, 182.4), (96.4, 185.4), (97.4, 188.6), (100.4, 190),
                (103.6, 189.2), (105.8, 186.8), (106, 183.4)]
WHEAT_FIST_C = (101.0, 185.4)
WHEAT_HAND_K = 2.0
WHEAT_HAND_AT = (92.0, 207.0)
WHEAT_FINGERS = (202.5, 206.5, 210.5)   # the finger creases' rows
WHEAT_FIST_LEFT = 84.0
WHEAT_FORE = [(97.5, 211), (106, 222), (114, 234), (120, 246)]     # the forearm, from the lower right
WHEAT_FORE_W = ([0, 0.3, 1], [3.6 * 1.6, 3.7 * 1.6, 3.4 * 1.6])
WHEAT_FORE_FADE = (214.0, 234.0)  # the forearm: whole above the first row, gone at the second


def wheat_ear_frame():
    a = math.radians(WHEAT_EAR_ANGLE)
    u = np.array([math.cos(a), math.sin(a)])
    w = np.array([-u[1], u[0]])
    o = np.array(WHEAT_EAR_BASE)

    def bend(x):
        return -WHEAT_EAR_BEND * (max(x, 0.0) / WHEAT_EAR_LEN) ** 2

    return lambda x, y: o + u * x * WHEAT_EAR_K + w * (y + bend(x)) * WHEAT_EAR_W


def wheat_ear():
    to = wheat_ear_frame()
    xs_, ws_ = zip(*WHEAT_EAR_WIDTH)

    def width(x):
        return float(np.interp(x, xs_, ws_))

    def notch(x, n):
        d = x - (n - WHEAT_NOTCH_LEAN)
        return WHEAT_NOTCH_DEPTH * max(0.0, 1.0 - (-d / 1.0 if d < 0 else d / 2.2))

    sides = {}
    for side, ns in WHEAT_NOTCHES.items():
        sides[side] = [(x, side * max(0.6, width(x) - max(notch(x, n) for n in ns)))
                       for x in np.linspace(0, WHEAT_EAR_LEN, 321)]
    pts = sides[1] + sides[-1][::-1]
    return [to(x, y) * 4 for x, y in pts]


def wheat_fist():
    return [(np.array(WHEAT_HAND_AT) + (np.array(p) - np.array(WHEAT_FIST_C)) * WHEAT_HAND_K) for p in WHEAT_FIST_F]


def wheat_shapes():
    out = [{"name": "stalk", "part": "wheat", "group": "wheat",
            "d": cl.path_of(limb(WHEAT_STALK, [0, 1], [WHEAT_STALK_W, WHEAT_STALK_W]))}]
    for k, (x, y) in enumerate(WHEAT_L[1:4]):
        w = WHEAT_NODE_W
        out.append({"name": f"node{k}", "part": "wheat", "group": "wheat",
                    "d": cl.path_of(cl.outline([(x - w, y - 2.5), (x, y - 3.2), (x + w, y - 2.5),
                                                (x + w, y + 2.5), (x, y + 3.2), (x - w, y + 2.5)], 6))})
    for k, sp in enumerate(WHEAT_LEAVES):
        out.append({"name": f"leaf{k}", "part": "wheat", "group": "wheat",
                    "d": cl.path_of(limb(sp, *WHEAT_LEAF_W, tip=3.0))})
    out.append({"name": "ear", "part": "wheat", "group": "wheat", "d": cl.path_of(wheat_ear())})
    out.append({"name": "forearm", "part": "wheat", "group": "arm", "d": cl.path_of(limb(WHEAT_FORE, *WHEAT_FORE_W))})
    out.append({"name": "fist", "part": "wheat", "group": "arm", "d": cl.path_of(cl.outline(wheat_fist(), 8))})
    return out


def wheat_strokes():
    out = []
    to = wheat_ear_frame()
    tip = to(WHEAT_EAR_LEN, 0)
    t = tip - to(WHEAT_EAR_LEN - 1, 0)
    t = t / np.linalg.norm(t)
    for k, (back, across, a, n) in enumerate(WHEAT_AWNS):
        r = math.radians(a)
        d = np.array([t[0] * math.cos(r) - t[1] * math.sin(r), t[0] * math.sin(r) + t[1] * math.cos(r)])
        o = to(WHEAT_EAR_LEN - back, across) + d * 0.8
        e = o + d * n * WHEAT_EAR_K
        out.append({"name": f"awn{k}", "part": "wheat",
                    "d": "M %s %s L %s %s" % (*np.round(o * 4 + 2, 1), *np.round(e * 4 + 2, 1))})
    # the grains: from each notch a line in and down to the axis (the final's notches, drawn on)
    spica = (WHEAT_EAR_BASE[1] - WHEAT_L[4][1]) / WHEAT_EAR_K
    xs_, ws_ = zip(*WHEAT_EAR_WIDTH)
    for side, ns in WHEAT_NOTCHES.items():
        for n in ns:
            x0 = n - WHEAT_NOTCH_LEAN
            if (x0 - WHEAT_GRAIN_IN < 3 or abs(x0 - spica) < WHEAT_SPICA_CLEAR
                    or abs(x0 - WHEAT_GRAIN_IN - spica) < WHEAT_SPICA_CLEAR - 1):
                continue
            w0 = float(np.interp(x0, xs_, ws_)) - WHEAT_NOTCH_DEPTH - 0.3
            p0, p1 = to(x0, side * w0), to(x0 - WHEAT_GRAIN_IN, side * 0.4)
            out.append({"name": f"grain{side}_{n}", "part": "wheat", "d": stroke_d([p0, p1], 3)})
    # the fingers wrapped round the stalk: short creases in from the fist's left side
    for k, y in enumerate(WHEAT_FINGERS):
        out.append({"name": f"finger{k}", "part": "wheat",
                    "d": stroke_d([(WHEAT_FIST_LEFT, y), (WHEAT_FIST_LEFT + 4.5, y + 0.4)], 3)})
    return out


def wheat_finish(img, line):
    sky = sd.sky_index()
    shp = wheat_shapes()
    ramp = {tuple(sd.PAL[n]): i for i, n in enumerate(sd.N)}
    ys, xs = np.mgrid[0:sd.H, 0:sd.W]
    # the fist keeps its whole outline (at line strength); only the pixels where the stalk enters
    # and leaves it soften (the hand closing round it, not a ring drawn across it)
    fm = mask_of(shp, "fist")
    for y, x in zip(*np.nonzero(line & sd.grow(fm, 1))):
        if ramp.get(tuple(img[y, x, :3]), 99) - sky[y, x] < 5:
            img[y, x, :3] = level(sky, y, x, 5)
            img[y, x, 3] = 255
    cross = line & sd.grow(fm, 1) & (np.abs(xs - WHEAT_STALK[0][0]) <= WHEAT_STALK_W + 0.6)
    for y, x in zip(*np.nonzero(cross)):
        img[y, x, :3] = level(sky, y, x, 2)
        img[y, x, 3] = 255
    # the forearm fades out toward the lower right
    fore = sd.grow(mask_of(shp, "forearm"), 2) & ~sd.grow(fm, 1) & ~mask_of(shp, "stalk")
    keep = np.clip((WHEAT_FORE_FADE[1] - ys) / (WHEAT_FORE_FADE[1] - WHEAT_FORE_FADE[0]), 0, 1) ** 1.2
    fade(img, sky, fore & (img[..., 3] > 0) & (ys > WHEAT_FORE_FADE[0]), keep, line)
    return close(img, sky, WHEAT_L)


def paint_wheat():
    return painted(wheat_shapes, wheat_strokes, WHEAT_L, WHEAT_SIZES, wheat_finish)


# --- the stages ----------------------------------------------------------------------------

STAGES = {
    "head": (HEAD_L, HEAD_SIZES, paint_head),
    "wing": (WING_L, WING_SIZES, paint_wing),
    "robe": (ROBE_L, ROBE_SIZES, paint_robe),
    "feet": (FEET_L, FEET_SIZES, paint_feet),
    "wheat": (WHEAT_L, WHEAT_SIZES, paint_wheat),
}
SIZE_CODES = {"SMALL": "S", "MEDIUM": "M", "BIG": "B"}


def stage_maps():
    """Each Virgo stage's landmarks and sizes, read from game/core/star_map.gd."""
    src = STAR_MAP.read_text()
    found = {}
    for part in PARTS:
        block = re.search(r"static func virgo_%s\(\) -> StarMap:(.*?)\n\n\n" % part, src, re.S).group(1)
        marks = re.search(r"map\.landmarks = \[(.*?)\]\n", block, re.S).group(1)
        sizes = re.search(r"map\.sizes = \[(.*?)\]\n", block, re.S).group(1)
        found[part] = ([(int(x), int(y)) for x, y in re.findall(r"Vector2i\((-?\d+), (-?\d+)\)", marks)],
                       [SIZE_CODES[s] for s in re.findall(r"Star\.Size\.(\w+)", sizes)])
    return found


def build_parts():
    """Writes each part stage's own painting, virgo_part_<part>.png."""
    ART.mkdir(parents=True, exist_ok=True)
    maps = stage_maps()
    for part in PARTS:
        landmarks, sizes, paint = STAGES[part]
        assert maps[part] == (landmarks, sizes), f"{part}: the painting's stars differ from StarMap.virgo_{part}()"
        img = paint()
        used = sd.check(img)
        print(f"part {part}: {sum(used.values())} px, {used}")
        sd.save(img, ART / f"virgo_part_{part}.png")


if __name__ == "__main__":
    build_parts()
