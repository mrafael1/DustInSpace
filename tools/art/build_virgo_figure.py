"""Builds the painted Virgo (chapter 4's reward) and its pieces, in assets/art/:

  virgo_figure.png         the whole maiden, the final's reward and the chart's
  virgo_piece_<part>.png   the same painting cut into the chapter's five parts (head, wing, robe,
                           feet, wheat), in the same full-screen home layout: the chapter chart
                           assembles them as parts are won
  virgo_part_<part>.png    each part stage's own painting, the same body part fitted to that stage's
                           own landmarks (game/core/star_map.gd, read from the source), shown when the
                           stage is complete

Drawn exactly as the Aquarius and the Leo are (tools/art/build_aquarius_figure.py): smooth outlines
at native size, each given roundness from its own shape, then lit and shaded as the Scorpio is
(light from the top left, the N ramp in flat bands with a Bayer checker only along each seam, dark
creases where one part lies over another, a rose rim on lit edges, stardust specks, a thin aura),
so the four chapters match.

The winged maiden flies to the right, east to the left as on the sky, as a winged Victory would;
her stars are points on the body. Her head turns to look back and up at the stars, Zavijava at her
nape and eta on her breast; her wing rises from her back through delta to its tip at Vindemiatrix;
her near arm is bent, the fist at her hip (Porrima) holding a long stalk of wheat that trails down
past theta to its ear at Spica; the long ends of her girdle stream back and up through zeta and tau
to 109; below a knee-length chiton her legs part like scissors, iota on the back shin, the back foot
pointed at mu, the front foot at kappa.
The hair is its own material (the N ramp's deeper steps, as Leo's mane), so the face stands out
against it; the wing is the same carved stone a step lighter in its shadows.
No colour outside the Stellar Sun palette; every pixel opaque or empty.

Run: python tools/art/build_virgo_figure.py   (needs Pillow and numpy)
     python tools/art/build_virgo_figure.py --preview   (only a review sheet, nothing in assets/)
"""

import importlib.util
import re
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
_spec = importlib.util.spec_from_file_location("aquarius_art", ROOT / "tools" / "art" / "build_aquarius_figure.py")
aq = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(aq)
sc = aq.sc

ART = aq.ART
STAR_MAP = aq.STAR_MAP
W, H = aq.W, aq.H
v, lerp, unit, bezier = aq.v, aq.lerp, aq.unit, aq.bezier
limb = aq.limb
RGB = aq.RGB
PARTS = ("head", "wing", "robe", "feet", "wheat")

# Virgo's landmarks (StarMap.virgo): 0 Zavijava (the nape), 1 eta (the breast), 2 Porrima (the
# fist, at the hip), 3 delta (the wing), 4 Vindemiatrix (the wing's tip), 5 theta (the stalk),
# 6 Spica (the ear of wheat), 7 zeta, 8 tau, 9 109 (the girdle's ends), 10 iota (the back shin),
# 11 mu (the back foot), 12 kappa (the front foot).
L = [(162, 136), (140, 152), (116, 160), (106, 132), (98, 96), (100, 186), (86, 216), (78, 150),
     (56, 134), (24, 126), (50, 178), (22, 172), (48, 206)]

# Which part owns each landmark (ChapterDef.virgo).
STAR_PARTS = {0: "head", 1: "head", 3: "wing", 4: "wing", 7: "robe", 8: "robe", 9: "robe",
              10: "feet", 11: "feet", 12: "feet", 6: "wheat", 5: "wheat", 2: "wheat"}

# The hair: the N ramp's deeper steps, as Leo's mane, so the face reads in front of it.
aq.RAMPS["hair"] = (["N1", "N1", "N2", "N2", "N3", "N4", "N5", "N6"], ["N7", "N8"])
# The wing: the body's ramp a step lighter in the shadows, carved stone as the rest of her.
aq.RAMPS["wing"] = (["N2", "N3", "N3", "N4", "N5", "N6", "N7", "N8"], ["N9", "N10"])


class Shapes(aq.Shapes):
    """The Aquarius's shapes, with marks drawn over the shading (the face)."""

    def __init__(self):
        super().__init__()
        self.marks = []

    def shape(self, outline, depth=8.0, lift=0.0, smooth=True, soften=2):
        """As the Aquarius's, but a long slanted part (the chiton) can take a softer dome
        (`soften` blur passes), or its erosion steps show as a comb in the highlight."""
        mask = aq.mask_of(outline, smooth)
        d = aq.distance(mask)
        h = np.sqrt(np.clip(d / max(d.max(), 1.0), 0.0, 1.0)) * depth
        gy, gx = np.gradient(aq.blur(h * mask, soften))
        self._put(mask, h, -gx, -gy, np.full(h.shape, 0.9), lift)


# --- parts ---------------------------------------------------------------------------------

def rotate(p, degrees):
    a = np.radians(degrees)
    c, s_ = np.cos(a), np.sin(a)
    return np.array([p[0] * c - p[1] * s_, p[0] * s_ + p[1] * c])


def head_in_profile(S, head, lift, tilt=0.0):
    """A head in profile looking back and up, towards the light: the Aquarius's head (a round
    skull, brow, straight nose, lips, a soft chin) tipped back by `tilt` degrees; a dark eye.
    Returns the head's own frame, for the hair."""
    head = v(head)

    def P(x, y):
        return head + rotate((x, y), tilt)

    face = [P(-5, -8), P(-7, -4), P(-7, -2), P(-9.5, 2), P(-7, 3), P(-7.5, 5), P(-6.5, 6), P(-6.5, 8),
            P(-4, 10), P(1, 10), P(5, 7), P(7, 1), P(7, -5), P(2, -9)]
    S.shape(face, depth=7, lift=lift)
    S.marks.append((tuple(np.round(P(-4.5, 0)).astype(int)), "N1"))
    return P


def hair(S, P, lift):
    """Hair over the crown and the back of the head (`P`: the head's own frame), gathered into a
    knot at the back, Greek fashion; a band across the crown."""
    S.mat = "hair"
    cap = [P(-6, -7), P(-1, -10), P(5, -9), P(9, -5), P(10, 0), P(9, 5), P(6, 7), P(3, 3), P(1, -2),
           P(-3, -4), P(-6, -4)]
    S.shape(cap, depth=4, lift=lift + 1.5)
    S.ellipsoid(P(11, 2), P(15, 3) - P(11, 2), 4.2, 3.6, depth=2.5, lift=lift + 1.0)
    S.mat = "body"
    S.shape(limb([P(-5, -6), P(0, -8.5), P(6, -7)], [0.8, 0.9, 0.8]), depth=1.0, lift=lift + 3)


def wing(S, root, tip, lift):
    """A bird's wing raised from the back at `root` to its tip at `tip`, as a statue's: a bowed
    leading edge, the flight feathers from it back to a scalloped trailing edge (the secondaries
    from the root, longer primaries fanning to the tip), two rows of coverts over their roots."""
    S.mat = "wing"
    R, T = v(root), v(tip)
    along = unit(T - R)
    back = np.array([along[1], -along[0]])
    if back[0] > 0:
        back = -back  # the trailing edge lies to the left of the leading edge
    length = float(np.linalg.norm(T - R))

    def at(t, out):
        """`t` of the way from root to tip, `out` px back from the line between them."""
        return R + along * length * t + back * out

    # The leading edge's bow (px forward of the line) and the trailing edge's reach back from it.
    lead = [(0.0, 3), (0.3, 6), (0.55, 7), (0.8, 5), (1.0, 0)]
    trail = [(0.0, 6), (0.15, 16), (0.35, 23), (0.55, 24), (0.72, 19), (0.88, 10), (1.0, 2)]

    def front(t):
        return -float(np.interp(t, [p[0] for p in lead], [p[1] for p in lead]))

    def edge(t):
        return float(np.interp(t, [p[0] for p in trail], [p[1] for p in trail]))

    outline = [at(t, front(t)) for t in np.linspace(0.0, 1.0, 7)]
    outline += [at(t, edge(t) - 2) for t in np.linspace(1.0, 0.0, 9)]
    S.shape(outline, depth=1.5, lift=lift)
    # Three tiers of feathers, each a row of broad overlapping blades with rounded ends: the
    # flight feathers out to the trailing edge (the last the tip), the greater coverts over their
    # roots, the lesser coverts along the leading edge. In each row the one nearer the body lies
    # over the next, so every blade shows a crease along its edge.
    tiers = [(1.0, 12, 4.2, 0.0), (0.55, 10, 3.6, 2.0), (0.28, 8, 3.0, 4.0)]
    for reach, count, width, up in tiers:
        for k, t in enumerate(np.linspace(1.0, 0.04, count)):
            t_tip = min(t + 0.05, 1.0)
            base = at(t * 0.92, front(t) + 2.5)
            tipf = at(t_tip, front(t_tip) + (edge(t_tip) + 1.5 - front(t_tip)) * reach)
            if reach == 1.0 and k == 0:
                tipf = T + along * 2
            w = width * (0.75 + 0.25 * (1 - t))
            S.shape(limb([base, lerp(base, tipf, 0.55), tipf], [w * 0.8, w, w * 0.6]), depth=1.6, lift=lift + 2 + up + 0.06 * k)
    S.shape(limb([at(t, front(t) + 2.5) for t in (0.0, 0.3, 0.6, 0.85, 1.0)], [3.4, 3.2, 2.8, 2.2, 1.2]), depth=2.5, lift=lift + 7)
    S.mat = "body"


def ear_of_wheat(S, base, tip, lift):
    """One ear of wheat from `base` to `tip`: a slim core, plump grains in pairs along it, each
    leaning out towards the tip and apart from the next, so the ear reads as a braid; long awns
    fanning past the tip."""
    A, B = v(base), v(tip)
    d = unit(B - A)
    side = np.array([-d[1], d[0]])
    S.shape(limb([A, lerp(A, B, 0.5), B], [1.4, 1.6, 0.8]), depth=1.5, lift=lift)
    for k, t in enumerate(np.linspace(0.1, 0.9, 6)):
        size = 1.0 - 0.35 * t
        for sgn in (-1.0, 1.0):
            c = lerp(A, B, t + (0.06 if sgn > 0 else 0.0)) + side * sgn * 2.2 * size
            S.ellipsoid(c, d + side * sgn * 0.8, 2.8 * size, 1.9 * size, depth=1.6, lift=lift + 0.5 + 0.05 * k)
    for spread in (-0.6, -0.2, 0.2, 0.6):
        S.shape(limb([B - d * 2, B + d * 8 + side * spread * 6], [0.6, 0.5]), depth=0.6, lift=lift + 0.2)


def ribbon(S, points, r0, r1, twists=2.5, lift=0.0):
    """A long piece of cloth streaming through `points`, twisting as it flutters: it narrows where
    it turns edge-on (Aquarius's water, in cloth). Returns its path."""
    pts = [v(p) for p in points]
    path = []
    for k in range(len(pts) - 1):
        a, b = pts[k], pts[k + 1]
        bend = np.array([-(b - a)[1], (b - a)[0]]) * (0.12 if k % 2 else -0.12)
        path += bezier(a, (a + b) / 2 + bend, b, 8)[:-1]
    path.append(tuple(pts[-1]))
    n = len(path)
    for k in range(n - 1):
        a, b = v(path[k]), v(path[k + 1])
        t = k / (n - 1)
        width = (r0 + (r1 - r0) * t) * (0.4 + 0.6 * abs(np.cos(np.pi * twists * t)))
        S.ellipsoid((a + b) / 2, b - a, np.linalg.norm(b - a) / 2 + 1.5, max(width, 1.2), depth=2.0, lift=lift, squash=1.6, along_flat=0.2)
    return path


def leg(S, knee, ankle, toes, lift):
    """A bare shin from under the hem at `knee` to the ankle, the calf full, and the foot pointed
    from the ankle to its toes: the heel a bump behind the ankle, the sole on the calf's side (up),
    the instep arched, so it reads as a foot and not the tip of a horn."""
    K, A, T = v(knee), v(ankle), v(toes)
    S.shape(limb([K, lerp(K, A, 0.4), A], [4.4, 4.4, 2.5]), depth=4, lift=lift)
    d = unit(T - A)
    sole = np.array([-d[1], d[0]])
    if sole[1] > 0:
        sole = -sole
    s = float(np.linalg.norm(T - A)) / 13.5

    def F(x, y):
        return A + d * x * s + sole * y * max(s, 1.0)

    foot = [F(-3, 2.2), F(-4, 0.2), F(-2.5, -2.4), F(1, -3.0), F(5, -2.4), F(9.5, -1.2), F(13.5, 0.3),
            F(13, 1.6), F(9.5, 2.0), F(5, 2.6), F(1, 3.2)]
    S.shape(foot, depth=2.5, lift=lift + 0.4)


def build_figure(S):
    zav, eta, porrima, delta, vin, theta, spica, zeta, tau, s109, iota, mu, kappa = map(v, L)
    head = v((161, 127))

    # The wing, behind: raised from her back to its tip at Vindemiatrix.
    S.tag = "wing"
    wing(S, root=(132, 143), tip=vin + v((-2, -6)), lift=-10)

    # The legs, bare below the hem: the back one out straight through iota, its foot pointed at
    # mu; the front one bent at the knee, its foot pointed down at kappa.
    S.tag = "feet"
    leg(S, (62, 177), (25, 171), (13, 183), lift=-3)
    leg(S, (68, 186), (58, 203), (42, 208), lift=-2)

    # The chiton: from the waist over the hips and both thighs to a hem just below the knees; a
    # long fold down each leg.
    S.tag = "robe"
    chiton = [(112, 149), (98, 153), (86, 157), (74, 161), (64, 164), (60, 170), (62, 177), (64, 184),
              (68, 190), (72, 196), (80, 195), (90, 190), (102, 184), (114, 176), (120, 167)]
    S.shape(chiton, depth=5, lift=0, soften=5)
    for fold in ([(108, 158), (88, 164), (68, 172)], [(110, 168), (90, 178), (74, 190)]):
        S.shape(limb(bezier(fold[0], fold[1], fold[2], 6), [0.7, 1.0, 1.3, 1.6, 1.8, 1.9]), depth=1.2, lift=4.2)

    # The bust: the torso from the shoulders to the waist; her neck; the head turned to look back
    # and up, at the wing and the stars.
    S.tag = "head"
    torso = [(150, 134), (140, 137), (128, 142), (116, 147), (106, 151), (106, 166), (118, 168), (130, 165),
             (142, 161), (151, 156), (157, 149), (158, 141)]
    S.shape(torso, depth=14, lift=2)
    S.shape(limb([head + v((-2, 6)), head + v((-5, 14))], [4.4, 5.0]), depth=4, lift=3)
    P = head_in_profile(S, head, lift=8, tilt=35)
    hair(S, P, lift=7)

    # The girdle, and its long ends streaming back and up through zeta and tau to 109.
    S.tag = "robe"
    S.shape(limb([(113, 153), (115, 165)], [2.2, 2.2]), depth=2, lift=4)
    ribbon(S, [(112, 156), (98, 153), (88, 152), zeta, (66, 141), tau, (40, 129), s109, s109 + v((-8, 3))],
           5.0, 4.0, lift=5)

    # The near arm: down from the shoulder to the elbow, the forearm back up to her hip, the fist
    # (Porrima) holding a long stalk of wheat that trails down past theta, a leaf off it, its ear
    # (Spica) hanging at the end.
    S.tag = "wheat"
    shoulder = v((148, 149))
    elbow = v((140, 173))
    wrist = porrima + v((5, 4))
    S.shape(limb([shoulder, lerp(shoulder, elbow, 0.5) + v((1, 0)), elbow], [4.8, 4.2, 3.6]), depth=5, lift=16)
    S.shape(limb([elbow, lerp(elbow, wrist, 0.5) + v((0, 1)), wrist], [3.6, 3.2, 2.8]), depth=4, lift=16.5)
    ear_base = spica + v((5, -13))
    stalk = bezier(porrima + v((5, -6)), theta + v((2, -2)), ear_base, 10)
    S.shape(limb(stalk, [1.1] * len(stalk)), depth=1.0, lift=17)
    leaf = bezier(theta + v((5, -8)), theta + v((-6, -4)), theta + v((-14, 4)), 6)
    S.shape(limb(leaf, list(np.linspace(1.4, 0.5, len(leaf)))), depth=0.8, lift=16.8)
    S.ellipsoid(porrima + v((1, 1)), wrist - elbow, 3.8, 3.3, depth=2.5, lift=17.5)  # the fist
    ear_of_wheat(S, ear_base, spica + v((-3, 11)), lift=18)


# --- shading, review sheet -----------------------------------------------------------------

def paint(S):
    img = aq.shade(S)
    aq.stardust(img)
    for (x, y), colour in S.marks:
        if 0 <= x < W and 0 <= y < H and img[y, x, 3]:
            img[y, x, :3] = RGB[colour]
    return img


def palette():
    """Every Stellar Sun colour by name (assets/palettes/stellar_sun.gpl)."""
    names = {}
    for line in (ROOT / "assets" / "palettes" / "stellar_sun.gpl").read_text().splitlines():
        parts = line.split()
        if len(parts) == 4 and all(p.isdigit() for p in parts[:3]):
            names[parts[3]] = tuple(int(p) for p in parts[:3])
    return names


def preview(img, path, landmarks=L, strings=None):
    """A review sheet: the painting on the stage's background at 1x and 3x, with its stars and
    strings over it, and a flat silhouette."""
    pal = palette()
    bg = Image.open(ART / "background.png").convert("RGBA")
    art = Image.fromarray(img, "RGBA")
    over = bg.copy()
    over.alpha_composite(art)
    stars = over.copy()
    d = ImageDraw.Draw(stars)
    for a, b in strings or []:
        d.line([landmarks[a], landmarks[b]], fill=pal["N8"])
    for x, y in landmarks:
        d.rectangle([x - 1, y - 1, x + 1, y + 1], fill=pal["C1"])
    flat = Image.new("RGBA", (W, H), pal["N0"] + (255,))
    flat.paste(Image.new("RGBA", (W, H), pal["N8"] + (255,)), mask=art.split()[3])
    box = (0, 70, W, 250)
    tiles = [over.crop(box), stars.crop(box), flat.crop(box)]
    sheet = Image.new("RGB", (W * 3 * 3 + W + 40, (box[3] - box[1]) * 3), (0, 0, 0))
    sheet.paste(over.crop(box).convert("RGB"), (0, 0))
    for k, tile in enumerate(tiles):
        sheet.paste(tile.convert("RGB").resize((W * 3, (box[3] - box[1]) * 3), Image.NEAREST), (W + 10 + k * (W * 3 + 10), 0))
    sheet.save(path)
    print(f"wrote {path}")


SEGMENTS = [(0, 1), (1, 2), (2, 3), (3, 4), (2, 5), (5, 6), (3, 7), (7, 8), (8, 9), (7, 10), (10, 11), (10, 12)]


def main():
    S = Shapes()
    build_figure(S)
    img = paint(S)
    if "--preview" in sys.argv:
        out = ROOT / "tools" / "capture" / "out" / "virgo"
        out.mkdir(parents=True, exist_ok=True)
        preview(img, out / "figure_sheet.png", L, SEGMENTS)
        return
    ART.mkdir(parents=True, exist_ok=True)
    sc.save(img, ART / "virgo_figure.png")


if __name__ == "__main__":
    main()
