"""Builds the Virgo's paintings (chapter 4's rewards), in assets/art/:

  virgo_figure.png          the whole maiden, the final stage's reward (StarMap.virgo's painting)
  virgo_piece_<part>.png    the same painting cut into the chapter's five parts (head, wing, robe,
                            feet, wheat: game/core/chapter_def.gd), in the same full-screen home
                            layout: the chapter chart shows the won ones dormant, then the whole
                            figure once the final is won
  virgo_part_<part>.png     each part stage's own painting, in the same clean-line style, drawn
                            round each stage's stars (tools/art/virgo_part_paintings.py, run from
                            here)

The Virgo is drawn in the Scorpio's clean-line semi-hollow (tools/art/clean_line.py and
stardust.py, see build_scorpio_figure.py): one unbroken line round each shape, Bayer-dithered
stardust inside, thick along the edge and thin in the middle.

The pieces partition the whole: each pixel goes with the part of the shape under it, else with the
nearest tagged pixel; each star's own pixel goes with its part. The torso's hip (x < 127, round
Porrima) goes with WHEAT, the robe above the upper fold with ROBE and below it with FEET, and
Vindemiatrix's own pixel with WING.

This is a port of the approved release draft. It keeps the draft's revision history as the draft
built it: rev 7 is rendered from rev 6 (itself rev 5 with rev 6's neck pasted in) with rev 7's arm
pasted in, then the reworked upper body (the eye on Zavijava) is pasted over rev 7 near the upper
body, so every pixel stays exactly as the user approved it. The draft's notes follow.

Virgo, release draft (rev 4): the v2 concept (flying head first to the right, the arm raised to
Vindemiatrix, no wing, the robe trailing left, wheat in the lowered hand by Spica) in the Scorpio's
clean-line semi-hollow.

Rev 4, after the user's review of rev 3 ("the idea isn't bad"; rev 3 is kept in before_rev1/):
  * ONE silhouette: the head, neck, torso, robe and the raised arm are one group (one outline,
    no seam where the arm leaves the shoulder or the neck meets the head). The only inner line is
    the lowered arm in front of the body, and it fades out toward the shoulder.
  * the raised hand has no finger strokes: the forearm runs on into a tapering hand that fades
    out (line and dust dissolving in a Bayer ramp) a few pixels short of Vindemiatrix;
  * the wheat is longer: a longer ear (six grains a side) whose stalk runs up into the lowered
    fist, is hidden by it, and shows again as a short stub above it. The fist is smaller (no separate thumb) and not
    outlined where the stalk enters it (the hand fades into the stalk);
  * the head is redrawn smaller (about 24 px, crown to chin), a calm woman's profile facing right
    (forehead, straight nose, lips, chin), the eye a short slot, the hair gathered back into a low
    knot at the nape (a short hairline and one strand). The laurel and the three streaming
    locks are gone.
  * kept: the robe (its tongues, folds, foot), the edge-heavy stardust, the star clearances.
  * Piece notes: Porrima belongs to the WHEAT piece (game data) and sits in the hip, so the
    torso's hip (x < 127) goes with WHEAT; the robe above the upper fold is ROBE, below it FEET;
    Vindemiatrix's own pixel (off the shapes) goes with WING.

Rev 5 (review of rev 4; rev 4 kept in before_rev2/):
  * the lowered hand is a small closed fist round theta, joined to the forearm, its outline at
    full strength; only the pixel or two where the stalk enters and leaves it are softened;
  * the ear nods out to the left (EAR_BEND < 0) and is 1 px wider at Spica; three straight awns
    fan from its tip without crossing and end by y 232;
  * the back of the skull and the knot are one round mass (no notch), the knot's lower edge at
    line brightness, no stray specks round it;
  * the raised hand's fade reaches 2 px closer to Vindemiatrix.

Rev 6 (user: "I'd like the head to feel more connected, not just attached to the body"; rev 5 kept
in before_rev4/, its exact script as virgo_draft_as_rendered.py):
  * the knot no longer tucks back in under the skull: the hair falls from it down the nape onto the
    shoulder, one S line from the crown into the back, so the thin neck column is gone; the lock's
    front edge is a short inner line over the neck that fades out as it melts into the back;
  * only the neck zone changes (main pastes rev 6 into rev 5 near where they differ); the face,
    robe, arms, hands and wheat are pixel-identical.

Rev 7 (user: "virgo right arm is weird because the shoulder begin way ahead compared to other arm
creating a weird figure"; rev 6 kept in before_rev5/):
  * the lowered arm's shoulder moves back from (162, 148), out at the front of the chest, to sit by
    the raised arm's (one shoulder girdle seen in 3/4); the upper arm runs down-left across the body
    to the unchanged elbow, forearm and fist, its inner line still fading out toward the shoulder;
  * the torso's front loses the hump (x 168.5 at y 137-148) that carried the old shoulder: a chest
    round Zavijava curving down into the belly;
  * only that zone changes (main pastes rev 7 into rev 6 near where the arm and torso differ, and
    near where the upper arm alone differs, so no rev 6 arm line is left across the chest); the
    bend ARM_MID sits so the arm's back line keeps 6 px off eta; ARM_ZONE 5 takes the whole
    shoulder (no flat-topped cut through its dust) and rev 6's halo speck off the old hump.

Run: python tools/art/build_virgo_figure.py [--preview out.png]   (needs Pillow and numpy)
"""
import argparse
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import clean_line as cl  # noqa: E402
import stardust as sd  # noqa: E402
import virgo_part_paintings  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / "assets" / "art"
OUT = ART / "virgo_figure.png"
PARTS = ("head", "wing", "robe", "feet", "wheat")

SEED = 11
LIGHT = (-0.55, -0.65, 0.52)

# StarMap.virgo() (game/core/star_map.gd): 0 Zavijava, 1 eta, 2 Porrima, 3 delta, 4 Vindemiatrix,
# 5 theta, 6 Spica, 7 zeta, 8 tau, 9 109, 10 iota, 11 mu, 12 kappa.
L = [(162, 136), (140, 152), (116, 160), (106, 132), (98, 96), (100, 186), (86, 216), (78, 150),
     (56, 134), (24, 126), (50, 178), (22, 172), (48, 206)]
SIZES = ["M", "S", "M", "S", "B", "S", "B", "M", "S", "M", "S", "S", "S"]
SEGMENTS = [(0, 1), (1, 2), (2, 3), (3, 4), (2, 5), (5, 6), (3, 7), (7, 8), (8, 9), (7, 10),
            (10, 11), (10, 12)]
STAR_PARTS = {0: "head", 1: "head", 3: "wing", 4: "wing", 7: "robe", 8: "robe", 9: "robe",
              10: "feet", 11: "feet", 12: "feet", 6: "wheat", 5: "wheat", 2: "wheat"}

# The face's profile, pixel by pixel from the forehead down (stamped over the line after the
# painting): forehead, brow, a straight nose out to its tip and the nostril under it, the
# philtrum, the upper lip, the mouth, the lower lip, the chin's dip, the chin, under the chin.
PROFILE = [(157, 98), (158, 99), (159, 100), (159, 101), (160, 102), (160, 103), (160, 104),
           (160, 105), (161, 106), (161, 107), (162, 108), (163, 109), (164, 110), (163, 111),
           (162, 111), (161, 112), (162, 113), (161, 114), (162, 115), (161, 116), (160, 117),
           (161, 118), (161, 119), (160, 120), (159, 121), (158, 121), (157, 121), (156, 122)]
BRIGHT = range(8, 20)          # the PROFILE pixels one step brighter (nose and lips)
EYE = [(157, 106), (158, 106)]  # a 2 px slot of sky behind the bridge
LID = [(156, 105), (157, 105)]  # the lid over it, one step above the face
FACE_FILL = 2                  # the face's solid fill, N steps above the sky
# The hair's front line (forehead, temple, before the ear) and its jaw, closing the face's fill.
HAIRLINE = [(157, 98.4), (154.4, 99.4), (152.4, 101.6), (151.4, 104.6)]
JAW = [(151.4, 108.4), (152, 112.4), (153.6, 116.6), (156.5, 121.8)]
FACE_SOLID = 9                 # solid this far back from the profile, then fading over FACE_FADE
FACE_FADE = 3.0

# The arms' joints (game px).
SHOULDER_UP, ELBOW_UP, WRIST_UP = (143, 143), (106, 132), (101.5, 114)
HAND_TIP = (99.2, 101.5)       # the raised hand's tip (it fades out before it)
HAND_FADE = (100.5, 115.0)     # the raised hand fades from y 115 (whole) to y 100.5 (gone)
SHOULDER, ELBOW, WRIST = (151, 144), (137, 170), (104.5, 183)
SHOULDER_REV6 = (162, 148)     # rev 6's shoulder, out at the front of the chest
ARM_MID = (149, 158)           # the upper arm's bend (rev 6: (151, 159.5)); further left brings its back line onto eta
TORSO_FRONT = [(155, 156), (160.5, 150.5), (164.5, 144.5), (166.5, 138.5), (165.5, 132.5)]   # belly to chest
TORSO_FRONT_REV6 = [(160, 152), (166, 148), (168.5, 143), (168.5, 137), (167, 131)]
FIST = [(103, 181), (99.6, 180.8), (97.2, 182.4), (96.4, 185.4), (97.4, 188.6), (100.4, 190),
        (103.6, 189.2), (105.8, 186.8), (106, 183.4)]   # the small fist round the stalk at theta
ARM_FADE = (6.0, 22.0)         # the lowered arm's inner line: gone within 6 px of the shoulder, whole past 22
NOSTRIL = (162, 111)           # the profile's second nostril pixel (left out of the head's outline)
HEADBOX = (128, 152, 92, 122)  # (x0, x1, y0, y1): nothing stray round the head in here
KNOT_Y = 108                   # the knot's lower edge (line brightness) from this row down
NAPE_BOX = (132, 146, 122, 136)


# ---------------------------------------------------------------------------------------------
# REWORK eye_h22 (from v1 "reach"; the user: "maybe virgo can be smaller an eye in star, removing a
# constraint"): the head is about 22 px (crown y 125, chin y 147) and her EYE is Zavijava (162, 136):
# the star is the eye's glint in a dark almond, as Leo's epsilon. The head sits down on the shoulders;
# the far shoulder R under the bun, the near shoulder L under the chin; the raised arm abducted, elbow
# on delta, a forearm of 1.15 heads; the lowered arm hangs nearly straight past eta to the kept fist.
NEW_PROFILE = [(164, 128), (165, 129), (165, 130), (166, 131), (166, 132), (166, 133), (167, 134),
               (167, 135), (167, 136), (168, 137), (169, 138), (170, 139), (169, 140), (168, 140),
               (167, 141), (168, 142), (167, 143), (167, 144), (166, 145), (167, 146), (166, 147),
               (165, 147), (164, 147), (163, 148)]
NEW = dict(                    # main switches these in (use_new) for the reworked pass
    PROFILE=NEW_PROFILE,
    NOSTRIL=(168, 140),
    BRIGHT=range(9, 18),
    EYE=[],
    LID=[],
    HAIRLINE=[(164, 128.4), (160.2, 129), (157.4, 131), (156.2, 134.4)],
    JAW=[(156.8, 137.5), (157.4, 141), (159, 144.6), (162.5, 148.4)],
    HAIR_LINES=[],
    HAIR_LOCK=[],
    LOCK_FADE=(138.0, 143.0),
    SHOULDER_UP=(137, 147), ELBOW_UP=(107, 134), WRIST_UP=(101, 110),
    HAND_TIP=(98.8, 99.5), HAND_FADE=(100.5, 106.0),
    SHOULDER=(154, 156), ELBOW=(123.5, 167), ARM_FADE=(4.0, 15.0),
    ROBE_TOP=[(127.5, 157.6), (120, 156.4), (111, 154.6), (100, 153)],
    ROBE_IN=[(118.5, 187), (122, 177), (122, 162), (127.5, 157.6)],
    ARM_MID=(138, 162),
    HEADBOX=(143, 175, 118, 134), KNOT_Y=131, NAPE_BOX=(128, 152, 128, 147),
)
# The eye, Leo's way: a dark almond round the star (the corners between its arms and the back
# corner), its upper lid lit; the star's own pixels are left to the game.
EYE_C = (162, 136)
EYE_DARK = [(161, 135), (163, 135), (161, 137), (163, 137), (159, 136)]
EYE_LID = [(159, 135), (160, 134), (161, 133), (162, 133), (163, 133), (164, 134)]
EYE_R = (3.4, 1.8)            # the ring of eye-white stardust round the star
# the reworked limbs and torso (game px): spines and (u, half-width) profiles
UPPER_UP = [(133, 154), (120, 144), (107, 134)]          # far shoulder R, elbow at delta
UPPER_UP_W = ([0, 0.1, 0.3, 0.55, 0.85, 1], [5.8, 6.0, 5.0, 4.2, 4.1, 4.5])   # a deltoid swell by the shoulder
FORE_UP = [(107, 134), (104.2, 122), (101, 110), (99.6, 104), (98.8, 99.5)]   # elbow, wrist, hand
FORE_UP_W = ([0, 0.25, 0.72, 0.86, 1], [4.4, 3.7, 2.2, 2.5, 1.6])
ARM_W = ([0, 0.45, 1], [4.6, 4.6, 3.7])
FORE_MID = (114, 175.4)
FORE_W = ([0, 0.3, 1], [3.7, 3.6, 3.1])
TORSO_NEW = [(149.6, 141.4), (146.8, 145.2), (143.2, 147.5), (139.8, 147.0), (136.8, 145.4), (133.6, 143.6), (130.4, 142.6), (127.4, 142.7),
             (129.5, 150), (130, 155), (127.5, 157.6), (121, 156.8), (115, 156.2), (112, 158), (114, 172), (117, 184), (121, 184.5), (128, 177), (138, 170.5),
             (146, 167), (152, 164.5), (157.5, 163), (160.2, 160.6), (161.6, 157.4), (161.8, 154.2), (160.6, 151.4), (159, 149.8), (154, 146)]
ROBE_TOP = [(124, 145), (117, 150), (109, 153), (100, 153)]   # rev 7's robe top at the waist
ROBE_IN = [(118.5, 187), (122, 177), (122, 162), (124, 145)]
NEW_ON = False
HEAD_D = (0, 0)
HEAD_KEYS = ("PROFILE", "NOSTRIL", "EYE", "LID", "HAIRLINE", "JAW", "HAIR_LINES", "HAIR_LOCK")


def _moved(v):
    if isinstance(v, tuple) and len(v) == 2 and not isinstance(v[0], (list, tuple)):
        return (v[0] + HEAD_D[0], v[1] + HEAD_D[1])
    return [_moved(e) for e in v]


def use_new():
    """Switch the module to the reworked upper body (the rev 7 constants are replaced)."""
    global NEW_ON
    globals().update(NEW)
    for k in HEAD_KEYS:
        globals()[k] = _moved(NEW[k])
    globals()["LOCK_FADE"] = (NEW["LOCK_FADE"][0] + HEAD_D[1], NEW["LOCK_FADE"][1] + HEAD_D[1])
    h = NEW["HEADBOX"]
    globals()["HEADBOX"] = (h[0] + HEAD_D[0], h[1] + HEAD_D[0], h[2] + HEAD_D[1], h[3] + HEAD_D[1])
    globals()["KNOT_Y"] = NEW["KNOT_Y"] + HEAD_D[1]
    NEW_ON = True


def chain(*segs, n=8):
    """A closed outline (4x points) of smooth runs meeting at sharp corners: each run a
    Catmull-Rom curve through its points (game px), each run starting where the last one ended."""
    out = []
    for seg in segs:
        c = cl.catmull([np.array(p, float) * 4 for p in seg], n)
        out.extend(c[:-1])
    return out


def limb(spine, us, ws, n=60):
    """A limb along a smooth spine (game px) whose half-width follows (us, ws) along its length
    (0..1), with round ends: 4x points."""
    ax = cl.Axis([np.array(p, float) * 4 for p in spine])
    left, right = [], []
    for s in np.linspace(0, ax.L, n):
        c, t, nrm = ax.frame(s)
        w = float(np.interp(s / ax.L, us, ws)) * 4
        left.append(c + nrm * w)
        right.append(c - nrm * w)
    c1, t1, n1 = ax.frame(ax.L)
    w1 = ws[-1] * 4
    cap_end = [c1 + t1 * w1 * math.sin(a) + n1 * w1 * math.cos(a) for a in np.linspace(0, math.pi, 9)[1:-1]]
    c0, t0, n0 = ax.frame(0)
    w0 = ws[0] * 4
    cap_start = [c0 - t0 * w0 * math.sin(a) - n0 * w0 * math.cos(a) for a in np.linspace(0, math.pi, 9)[1:-1]]
    return left + cap_end + right[::-1] + cap_start


REV6_ARM = False    # True paints rev 6's lowered arm and torso front (the approved painting the
                    # rev 7 arm is pasted into: see main)
ARM_STRAYS = [(167, 142), (165, 145)]   # specks just off the new chest line, cleared after the paste
ARM_ZONE = 5       # rev 7 takes its pixels within this many px of the changed arm and torso
REV5_HEAD = False   # True paints rev 5's head and neck (the approved painting the rev 6 neck is
                    # pasted into: see main)
NECK_STRAYS = [(135, 130)]   # outside the back line, cleared after the rev 6 paste
NECK_ZONE = 3      # rev 6 takes its pixels within this many px of the changed silhouette and the lock


def head_outline():
    """The head and neck (4x points): the forehead over the crown round the back of the skull, the
    hair falling from the knot down the nape onto the shoulder and on into the back (rev 6; rev 5
    tucked a knot in under the skull and ran a thin neck down into the torso), then from inside the
    body back up the throat and the face's profile to the forehead."""
    face = [(x + 0.5, y + 0.5) for x, y in PROFILE[::-1] if (x, y) != NOSTRIL]
    if NEW_ON:
        return chain(
            [(164.5, 128.4), (162.6, 126.2), (159, 125.3), (155.4, 126), (152.4, 128), (150.8, 130.6),
             (150.2, 133)],                                                 # forehead, crown, back of the skull
            [(150.2, 133), (148.6, 133.4), (147.4, 135), (147.4, 137.6), (148.6, 139.6), (150, 140.4)],  # a small bun at the nape
            [(150, 140.4), (152, 144), (155, 147.5), (158.5, 150)],      # (inside the body)
            [(158.5, 150), (161.4, 149.6), (163.4, 148.8)],                # the throat
        ) + [np.array(p, float) * 4 for p in face] + [np.array((164.5, 128.4)) * 4]
    if REV5_HEAD:
        return chain(
            [(157.5, 98.4), (155, 95.8), (150.8, 94.8), (146.8, 95.8), (144, 98.4), (142.4, 101.8),
             (140.6, 105), (138.4, 108), (137.6, 111.6), (139, 115), (142.4, 116.8), (145.2, 116)],
            [(145.2, 116), (147.6, 118.6), (149.6, 121.6), (150.4, 125), (150, 128)],
            [(150, 128), (157, 130), (163, 129)],
            [(163, 129), (159.6, 126.8), (156.8, 124.4), (156.2, 122.6)],
        ) + [np.array(p, float) * 4 for p in face] + [np.array((157.5, 98.4)) * 4]
    return chain(
        [(157.5, 98.4), (155, 95.8), (150.8, 94.8), (146.8, 95.8), (144, 98.4), (142.4, 101.8),
         (140.6, 105), (138.4, 108), (137.6, 111.6)],      # crown, back of skull and knot
        [(137.6, 111.6), (138.6, 115.5), (140.2, 119.5), (140.4, 124), (138.6, 128.5), (135.6, 133),
         (131.5, 137.5), (128, 140)],          # the hair falling from the knot over the nape onto the
                                               # shoulder: one S from the crown into the back
        [(128, 140), (140, 138), (150, 132), (157, 130), (163, 129)],      # (inside the body)
        [(163, 129), (159.6, 126.8), (156.8, 124.4), (156.2, 122.6)],       # the throat
    ) + [np.array(p, float) * 4 for p in face] + [np.array((157.5, 98.4)) * 4]


def shapes():
    out = []

    def add(name, part, pts4, group=None, **kw):
        out.append({"name": name, "part": part, "group": group or name, "d": cl.path_of(pts4), **kw})

    # --- the raised arm (one outline with the body): the upper arm slanting up and back from the
    # shoulder to the elbow at delta, the forearm tapering up to the wrist and on into the hand,
    # which fades out short of Vindemiatrix (finish).
    if NEW_ON:
        add("arm_up", "wing", limb(UPPER_UP, UPPER_UP_W[0], UPPER_UP_W[1]), "body")
        add("forearm_up", "wing", limb(FORE_UP, FORE_UP_W[0], FORE_UP_W[1]), "body")
    else:
        add("arm_up", "wing", limb([SHOULDER_UP, (125, 139.2), ELBOW_UP], [0, 0.45, 0.85, 1],
                                   [4.6, 5.0, 4.4, 4.3]), "body")
        add("forearm_up", "wing", limb([ELBOW_UP, (104, 123.5), WRIST_UP, HAND_TIP], [0, 0.32, 0.72, 1],
                                       [4.3, 3.1, 2.2, 1.5]), "body")
    # --- the foot (behind the robe): its toes peep out of the notch between the two lowest tongues.
    add("foot", "feet", cl.outline([(31.5, 209.5), (32.5, 207.2), (36, 206.2), (42, 206.5), (46, 207.5),
                                    (46, 211.5), (40, 211.8), (34.5, 211.5)], 6))
    # --- the robe: one silhouette from the hip. Its top runs straight back from the hip curve, its
    # trailing edge is six pointed swept-back tongues (varied sizes), its hem sags under kappa and
    # sweeps up behind the wheat and the forearm.
    robe = chain(
        ROBE_TOP + [(89, 148.5), (79, 142.5), (71, 138),
         (63, 131), (56, 125.8), (49, 123.8), (42, 124), (35, 121.5), (28, 116.5), (20, 112.5),
         (11, 110), (2, 109.5)],                                # top (a soft ripple), to T1
        [(2, 109.5), (8, 114), (14, 118.5)],                   # T1 underside, notch
        [(14, 118.5), (7, 123), (2, 129)],                     # T2 (small)
        [(2, 129), (8, 135), (15, 139.5)],
        [(15, 139.5), (8, 145), (2, 153)],                     # T3 (large)
        [(2, 153), (9, 158), (17, 161)],
        [(17, 161), (11, 168), (6, 177)],                      # T4 (small)
        [(6, 177), (11, 183), (18, 187)],
        [(18, 187), (12, 193), (4, 201)],                      # T5 (large)
        [(4, 201), (16, 204), (30, 206), (41, 206.5)],          # its long underside, to the foot notch
        [(41, 206.5), (36, 211), (28, 217)],                   # T6 (medium)
        [(28, 217), (40, 219), (52, 219.5), (63, 217), (74, 213), (86, 208.5), (98, 203),
         (110, 196), (118.5, 187)],                              # the hem, behind the ear and forearm
        ROBE_IN,                                                 # inside the forearm and torso
    )
    add("robe", "feet", robe, "body")
    # --- the torso (one outline with the robe and the head): the back from the nape dips to a slim
    # waist and runs on into the robe's top; the front a small chest curve under the throat, the
    # rest of the front behind the lowered arm.
    if NEW_ON:
        add("torso", "head", cl.outline(TORSO_NEW, 8), "body")
    else:
        add("torso", "head", cl.outline([
            (151, 120), (147, 125), (141, 131), (133, 138), (124, 145), (117, 150), (112, 158),
            (114, 170), (126, 173), (138, 168), (150, 160)] + (TORSO_FRONT_REV6 if REV6_ARM else TORSO_FRONT) + [
            (162.5, 127.5), (158.5, 125), (154, 122)], 8), "body")
    # --- the head and neck (one outline with the body).
    add("head", "head", head_outline(), "body")
    # --- the face: fill only (its profile is stamped pixel by pixel).
    face = HAIRLINE + JAW + [(x + 0.5, y + 0.5) for x, y in PROFILE[::-1]]
    add("face", "head", [np.array(p, float) * 4 for p in face], outline=False)
    # --- the wheat (in front of the robe, behind the hand).
    add("ear", "wheat", ear(), "wheat")
    # --- the lowered arm, one diagonal in front of the body: the shoulder under the throat, a slight
    # elbow, the forearm on to a small fist round the stalk at theta.
    if NEW_ON:
        add("arm", "wheat", limb([SHOULDER, ARM_MID, ELBOW], ARM_W[0], ARM_W[1]), "arm")
        add("forearm", "wheat", limb([ELBOW, FORE_MID, WRIST], FORE_W[0], FORE_W[1]), "arm")
    else:
        if REV6_ARM:
            add("arm", "wheat", limb([SHOULDER_REV6, (151, 159.5), ELBOW], [0, 0.4, 1], [4.4, 4.4, 3.8]), "arm")
        else:
            add("arm", "wheat", limb([SHOULDER, ARM_MID, ELBOW], [0, 0.4, 1], [4.4, 4.3, 3.8]), "arm")
        add("forearm", "wheat", limb([ELBOW, (121, 176.5), WRIST], [0, 0.5, 1], [3.8, 3.4, 3.1]), "arm")
    add("fist", "wheat", cl.outline(FIST, 8),
        "arm")
    return out


# The ear, in its own frame (x along it from the base below the fist to the tip, y across, + to
# the right of its travel): a slight curve toward the horizontal, a long lozenge with V notches
# between its grains (alternating sides), a pointed tip and two awns fanning past it. Spica sits
# on its axis. The stalk is the axis run on back (x < 0) up through the fist.
EAR_ANGLE = 113.0     # the ear's direction at its base (deg; screen, y down): down-left
EAR_LEN = 38.0
EAR_SPICA = 21.0      # Spica's place along the ear
EAR_BEND = -6.0       # the curve toward the horizontal over its length (px; - bends the tip out to the left)
EAR_WIDTH = [(0, 1.0), (4, 3.0), (9, 4.5), (16, 4.8), (21, 5.4), (26, 4.9), (31, 4.6), (35.5, 2.6), (38, 0)]   # (x, half-width)
NOTCHES = {1: (4, 9.5, 15, 26.5, 32), -1: (6.5, 12, 17.5, 29, 34.5)}   # grain notches along each side
NOTCH_DEPTH = 2.6
NOTCH_LEAN = 1.2       # each notch's inner point leans back toward the base
AWNS = ((0.0, 0.0, 0, 3.0), (2.4, 1.2, 40, 3.2), (2.4, -1.2, -40, 3.2))
# each awn: (back from the tip along the axis, across, angle off the axis in deg, length)
STALK_LOW = (-7.0, -0.5)    # the stalk from under the fist to the ear's base (along the axis)
STALK_TOP = (-23.0, -28.5)  # its stub above the fist


def ear_frame():
    """The ear's local-to-screen map (game px)."""
    a = math.radians(EAR_ANGLE)
    u = np.array([math.cos(a), math.sin(a)])
    w = np.array([-u[1], u[0]])        # + to the right of its travel
    bend = lambda x: -EAR_BEND * (max(x, 0.0) / EAR_LEN) ** 2
    origin = np.array(L[6], float) - u * EAR_SPICA - w * bend(EAR_SPICA)
    return lambda x, y: origin + u * x + w * (y + bend(x))


def ear():
    """The ear's outline (4x points)."""
    to = ear_frame()
    xs_, ws_ = zip(*EAR_WIDTH)
    width = lambda x: float(np.interp(x, xs_, ws_))
    def notch(x, n):
        d = x - (n - NOTCH_LEAN)       # a V: steep on the base side, a long lean out toward the tip
        return NOTCH_DEPTH * max(0.0, 1.0 - (-d / 1.0 if d < 0 else d / 2.2))

    sides = {}
    for side, notches in NOTCHES.items():
        sides[side] = [(x, side * max(0.6, width(x) - max(notch(x, n) for n in notches)))
                       for x in np.linspace(0, EAR_LEN, 321)]
    pts = sides[1] + sides[-1][::-1]
    return [to(x, y) * 4 for x, y in pts]


def ear_tip():
    to = ear_frame()
    tip = to(EAR_LEN, 0)
    t = tip - to(EAR_LEN - 1, 0)
    return tip, t / np.linalg.norm(t)


def stalk_pts(run):
    to = ear_frame()
    return [to(x, 0) for x in np.linspace(run[0], run[1], 4)]


FOLDS = [
    # A, the upper fold (the ROBE/FEET split): from the waist under zeta, back to the notch under T2
    [(106, 157.5), (96, 160.5), (86, 160), (77, 157), (68, 156), (58, 154.5), (48, 150.5), (39, 146),
     (30, 143.5), (21, 142.5)],
    # E, a short fold under the robe's top, between tau and the upper fold, toward T2's notch
    [(71, 146.5), (65, 145.5), (59, 143.5), (51, 139.5), (44, 136.5), (37, 135), (29, 132)],
    # B, the thigh's top under the cloth, from the hip, flowing on toward T4's notch
    [(108, 166), (96, 168.5), (84, 171), (73, 171), (64, 168.5), (55, 166.5), (45, 166.5),
     (35, 165.5), (25, 163)],
    # C, the leg's underside: thigh, knee and shin, from the hip toward the foot
    [(86, 180.5), (79, 181.5), (73, 183.5), (67, 187.5), (60, 192), (52, 196), (45, 199)],
]
# The hair: the front line (forehead, temple, before the ear), one strand from the crown back to the
# knot, and the tie where it is gathered.
HAIR_LINES = [
    [(150.8, 103.2), (147.8, 104.6), (145.4, 107)],
]
# The lock of hair falling from the knot down the nape onto the shoulder: its front edge, an inner
# line over the neck that fades out as the lock melts into the back (whole above LOCK_FADE[0], gone
# by LOCK_FADE[1]).
HAIR_LOCK = [(146.6, 108.6), (146.4, 113), (145.4, 118), (143.6, 123), (141, 128), (137.6, 132.5)]
LOCK_FADE = (122.0, 132.0)


def strokes():
    out = []

    def line(name, part, pts, n=16):
        c = cl.catmull([np.array(p, float) * 4 for p in pts], n)
        d = "M %s %s " % tuple(np.round(c[0], 1)) + " ".join("L %s %s" % tuple(np.round(p, 1)) for p in c[1:])
        out.append({"name": name, "part": part, "d": d})

    for k, pts in enumerate(FOLDS):
        line(f"fold{k}", "robe" if k < 2 else "feet", pts)
    line("hairline", "head", HAIRLINE, 10)
    for k, pts in enumerate(HAIR_LINES):
        line(f"hair{k}", "head", pts, 10)
    if not REV5_HEAD and HAIR_LOCK:
        line("hair_lock", "head", HAIR_LOCK, 10)
    line("stalk", "wheat", stalk_pts(STALK_LOW), 8)
    line("stalk_top", "wheat", stalk_pts(STALK_TOP), 8)
    # the awns: three straight 1 px bristles fanning out from the ear's tip
    to = ear_frame()
    c, t = ear_tip()
    for k, (back, across, a, n) in enumerate(AWNS):
        r = math.radians(a)
        d = np.array([t[0] * math.cos(r) - t[1] * math.sin(r), t[0] * math.sin(r) + t[1] * math.cos(r)])
        o = to(EAR_LEN - back, across) + d * 0.8
        e = o + d * n
        out.append({"name": f"awn{k}", "part": "wheat",
                    "d": "M %s %s L %s %s" % (*np.round(o * 4, 1), *np.round(e * 4, 1))})
    return out


def upper_fold_y(x):
    """The upper fold's y at column x (the ROBE/FEET split), extended flat past its ends."""
    pts = cl.catmull([np.array(p, float) for p in FOLDS[0]], 16)
    order = np.argsort(pts[:, 0])
    return float(np.interp(x, pts[order, 0], pts[order, 1]))


def level(sky, y, x, steps):
    return sd.PAL[sd.N[int(min(sky[y, x] + steps, 8))]]


def streaks(sky):
    """The background's thin bright cloud streaks: pixels two or more steps above the sky three rows
    up and down (the fill's dither there would read as a dotted fold)."""
    up = np.roll(sky, 3, 0)
    dn = np.roll(sky, -3, 0)
    return sky - np.minimum(up, dn) >= 2


RAMP = {tuple(sd.PAL[n]): i for i, n in enumerate(sd.N)}   # each N colour's step


def mask_of(shp, *names):
    m = np.zeros((sd.H, sd.W), bool)
    for s in shp:
        if s["name"] in names:
            m |= cl.down(cl.fill_4x(s["d"]))
    return m


def fade(img, sky, px, keep, line, ghost=0.25):
    """Each pixel of `px` kept where the Bayer value is under `keep` (0..1 per pixel), a line pixel
    just past that left as a ghost one step above the sky, the rest cleared."""
    for y, x in zip(*np.nonzero(px)):
        b = sd.BAY[y, x]
        if b < keep[y, x]:
            continue
        if line[y, x] and b < keep[y, x] + ghost:
            img[y, x, :3] = level(sky, y, x, 1)
        else:
            img[y, x, 3] = 0


def finish(img, line):
    """The solid face, its profile and eye stamped over the line; the raised hand fading out
    toward Vindemiatrix; the lowered arm's inner line fading toward the shoulder; the fist fading
    into the stalk; only a sparse dither on the background's streaks."""
    sky = sd.sky_index()
    shp = shapes()
    ys, xs = np.mgrid[0:sd.H, 0:sd.W]
    # --- the face: solid, fading back into the hair; the outline under the profile dropped
    face = mask_of(shp, "face")
    prof = dict()
    for x, y in PROFILE:
        prof[y] = max(prof.get(y, 0), x)
    front = np.zeros_like(face)
    for y, x in prof.items():
        front[y, x - 2:x] = True
    for y, x in zip(*np.nonzero(face | (front & line))):
        if (x, y) in PROFILE or (line[y, x] and not front[y, x]):
            continue
        back = max(0, prof.get(y, prof[min(prof, key=lambda r: abs(r - y))]) - x - FACE_SOLID)
        if back == 0 or sd.BAY[y, x] < 1.0 - back / FACE_FADE:
            img[y, x, :3] = level(sky, y, x, FACE_FILL)
            img[y, x, 3] = 255
    for k, (x, y) in enumerate(PROFILE):
        img[y, x, :3] = level(sky, y, x, 6 if k in BRIGHT else 5)
        img[y, x, 3] = 255
        if y in prof and x == prof[y]:
            for xx in range(x + 1, min(x + (6 if NEW_ON else 4), sd.W)):
                img[y, xx, 3] = 0
    for x, y in EYE:
        img[y, x, 3] = 0
    if NEW_ON:
        eye_star(img, sky, line)
    for x, y in LID:
        img[y, x, :3] = level(sky, y, x, FACE_FILL + 2)
        img[y, x, 3] = 255
    # --- the raised hand fades out toward its star
    hand_box = (xs > 88) & (xs < 112) & (ys < HAND_FADE[1] + 1) & (ys > 88)
    keep = np.clip((ys - HAND_FADE[0]) / (HAND_FADE[1] - HAND_FADE[0]), 0, 1) ** 1.3 * 1.15
    fade(img, sky, hand_box & (img[..., 3] > 0), keep, line)
    # --- the lowered arm's line across the body fades out toward the shoulder (the arm grows out
    # of the body there); its line off the body (the silhouette) stays whole
    body = mask_of(shp, "torso", "head", "robe", "arm_up")
    inner = body & sd.shift(body, 1, 0) & sd.shift(body, -1, 0) & sd.shift(body, 0, 1) & sd.shift(body, 0, -1)
    arm = mask_of(shp, "arm", "forearm")
    sh = SHOULDER_REV6 if REV6_ARM else SHOULDER
    r = np.hypot(xs - sh[0], ys - sh[1])
    keep = np.clip((r - ARM_FADE[0]) / (ARM_FADE[1] - ARM_FADE[0]), 0, 1)
    fade(img, sky, line & inner & sd.grow(arm, 1) & (r < ARM_FADE[1]), keep, line, ghost=0.35)
    # --- the fist keeps its whole outline; only the pixel or two where the stalk enters and leaves
    # it soften (the hand closing round the stalk, not a ring drawn across it)
    to = ear_frame()
    a, b = to(STALK_LOW[0], 0), to(STALK_TOP[0], 0)
    ab = b - a
    t = np.clip(((xs - a[0]) * ab[0] + (ys - a[1]) * ab[1]) / (ab @ ab), 0, 1)
    d = np.hypot(xs - (a[0] + t * ab[0]), ys - (a[1] + t * ab[1]))
    fist = mask_of(shp, "fist")
    for y, x in zip(*np.nonzero(line & sd.grow(fist, 1))):
        if RAMP.get(tuple(img[y, x, :3]), 99) - sky[y, x] < 5:
            img[y, x, :3] = level(sky, y, x, 5)
            img[y, x, 3] = 255
    hidden = mask_of(shp, "fist", "forearm")
    cross = line & sd.grow(hidden, 1) & (d < 1.0) & (t > 0) & (t < 1)
    for y, x in zip(*np.nonzero(cross)):
        img[y, x, :3] = level(sky, y, x, 2)
        img[y, x, 3] = 255
    # --- the head: nothing stray round the knot, and its lower edge at line brightness
    head = mask_of(shp, "head", "face")
    box = (xs > HEADBOX[0]) & (xs < HEADBOX[1]) & (ys > HEADBOX[2]) & (ys < HEADBOX[3])
    img[box & ~head & ~line, 3] = 0
    lock = np.zeros_like(line)
    for s in strokes():
        if s["name"] == "hair_lock":
            lock = cl.stroke(s["d"]) & line
    knot = box & line & (xs < 147) & (ys >= KNOT_Y) & ~lock
    for y, x in zip(*np.nonzero(knot)):
        if RAMP.get(tuple(img[y, x, :3]), 99) - sky[y, x] < 5:
            img[y, x, :3] = level(sky, y, x, 5)
            img[y, x, 3] = 255
    # nothing stray against the hair's back line where it runs down onto the shoulder (a speck
    # beside the line there reads as a shelf in it)
    if not REV5_HEAD:
        nape = (xs >= NAPE_BOX[0]) & (xs < NAPE_BOX[1]) & (ys >= NAPE_BOX[2]) & (ys < NAPE_BOX[3])
        form = mask_of(shp, "head", "torso", "arm_up")
        img[nape & ~form & ~line & sd.grow(line, 1), 3] = 0
    # the hair lock's front edge fades out down the neck (the lock melts into the back)
    keep = np.clip((LOCK_FADE[1] - ys) / (LOCK_FADE[1] - LOCK_FADE[0]), 0, 1)
    fade(img, sky, lock & (ys >= LOCK_FADE[0]), keep, line, ghost=0.35)
    img[:, sd.W - 3:, 3] = 0
    # the background's streaks: the fill carried across them as it is just above (same colours, same
    # Bayer phase four rows up), so neither a bright dotted row nor an empty slash shows
    st = streaks(sky) & ~line & (img[..., 3] > 0)
    src = img.copy()
    for y, x in zip(*np.nonzero(st)):
        yy = y - 4
        while yy > 0 and st[yy, x]:
            yy -= 4
        if src[yy, x, 3] and not line[yy, x] and RAMP.get(tuple(src[yy, x, :3]), 99) > sky[y, x]:
            img[y, x] = src[yy, x]
        else:
            img[y, x, 3] = 0
    # each star keeps its own faint pixel (its piece holds it)
    for x, y in L:
        if not img[y, x, 3]:
            img[y, x, :3] = level(sky, y, x, 1)
            img[y, x, 3] = 255
    return img


def eye_star(img, sky, line):
    """Zavijava as the eye's glint: a ring of eye-white stardust round the star, the dark almond
    corners between its arms, the lit upper lid."""
    cx, cy = EYE_C
    for y in range(cy - 3, cy + 4):
        for x in range(cx - 4, cx + 5):
            if ((x - cx) / EYE_R[0]) ** 2 + ((y - cy) / EYE_R[1]) ** 2 <= 1.0:
                img[y, x, :3] = level(sky, y, x, 3)
                img[y, x, 3] = 255
    for x, y in EYE_LID:
        img[y, x, :3] = level(sky, y, x, 5)
        img[y, x, 3] = 255
    for x, y in EYE_DARK:
        img[y, x, 3] = 0


def star_clearance(img, line):
    """Each star's distance to the nearest drawn line pixel still at line brightness."""
    sky = sd.sky_index()
    drawn = line & (img[..., 3] > 0)
    for x, y in PROFILE:
        drawn[y, x] = True
    for y, x in zip(*np.nonzero(drawn)):
        if RAMP.get(tuple(img[y, x, :3]), 0) - sky[y, x] < 3:
            drawn[y, x] = False
    ys, xs = np.nonzero(drawn)
    names = ["Zavijava", "eta", "Porrima", "delta", "Vindemiatrix", "theta", "Spica", "zeta", "tau",
             "109", "iota", "mu", "kappa"]
    out = {}
    for n, (x, y) in zip(names, L):
        d = np.hypot(xs - x, ys - y)
        k = int(np.argmin(d))
        out[n] = (round(float(d[k]), 1), (int(xs[k]), int(ys[k])))
    return out


def paint():
    shp = shapes()
    img, parts = cl.semi_hollow(shp, L, SIZES, SEED, LIGHT, strokes=strokes())
    line, groups, _ = cl.draw(shp, strokes())
    return finish(img, line), parts, line, mask_of(shp, "head") | stroke_of("hair_lock")


def stroke_of(name):
    out = np.zeros((sd.H, sd.W), bool)
    for s in strokes():
        if s["name"] == name:
            out |= cl.stroke(s["d"])
    return out


def arm_mask():
    """The lowered upper arm and the torso (the shapes rev 7 changes)."""
    return mask_of(shapes(), "arm", "torso")


def rev6():
    """Rev 6 changes only the neck: the painting is rendered with rev 5's head and with rev 6's, and
    rev 6's pixels are taken only near where the two differ (the silhouette and the hair lock), so
    the stardust and specks everywhere else stay exactly as approved."""
    global REV5_HEAD
    REV5_HEAD = True
    old, old_parts, _, old_head = paint()
    REV5_HEAD = False
    img, parts, line, new_head = paint()
    zone = sd.grow(old_head ^ new_head, NECK_ZONE)
    img = np.where(zone[..., None], img, old)
    parts = np.where(zone, parts, old_parts)
    # a lone line-coloured nub two px off the new back line (reads as a burr, not a speck)
    for x, y in NECK_STRAYS:
        img[y, x] = 0
    return img, parts, line


UPPER = ("head", "face", "torso", "arm_up", "forearm_up", "arm", "forearm")
NEW_ZONE = 3       # the rework takes its pixels within this many px of the old and new upper body
NEW_STRAYS = [(116, 146), (161, 163), (93, 104), (106, 109), (115, 131), (139, 141), (132, 141)]   # line-coloured specks off the armpit, chest and raised hand


def upper_mask():
    """The upper body's shapes and the hair strokes (what the rework redraws)."""
    return sd.grow(mask_of(shapes(), *UPPER) | stroke_of("hair_lock") | stroke_of("hair0"), 1)


def rev7():
    """Rev 7 exactly as approved: the rev 6 painting with rev 7's lowered arm pasted in near where
    the arm and torso differ."""
    global REV6_ARM
    REV6_ARM = True
    old, old_parts, old_line = rev6()
    old_arm, old_limb = arm_mask(), mask_of(shapes(), "arm")
    REV6_ARM = False
    img, parts, line = rev6()
    zone = sd.grow((old_arm ^ arm_mask()) | (old_limb ^ mask_of(shapes(), "arm")), ARM_ZONE)
    img = np.where(zone[..., None], img, old)
    parts = np.where(zone, parts, old_parts)
    line = np.where(zone, line, old_line)
    for x, y in ARM_STRAYS:
        img[y, x] = 0
    return img, parts, line


def figure():
    """The rework: rev 7 is rendered exactly as approved, then the reworked upper body, and the new
    pixels are taken only near the old and new upper body (head, neck, torso, both arms), never on
    the fist, so the robe, legs, wheat and fist stay pixel-identical to rev 7 elsewhere. Returns the
    painting, each pixel's part (the pieces' split) and the line."""
    old, old_parts, old_line = rev7()
    old_upper = upper_mask()
    old_robe = mask_of(shapes(), "robe")
    fist = mask_of(shapes(), "fist")
    use_new()
    img, parts, line, _ = paint()
    zone = sd.grow(old_upper | upper_mask() | (old_robe ^ mask_of(shapes(), "robe")), NEW_ZONE) & ~fist
    img = np.where(zone[..., None], img, old)
    parts = np.where(zone, parts, old_parts)
    line = np.where(zone, line, old_line)
    for x, y in NEW_STRAYS:
        img[y, x] = 0
    shp = shapes()
    ys, xs = np.mgrid[0:sd.H, 0:sd.W]
    fold = np.array([upper_fold_y(x) for x in range(sd.W)])
    robe = (parts == "feet") & (ys < fold[xs]) & (xs < 104)
    parts[robe] = "robe"
    torso = cl.down(cl.fill_4x([s for s in shp if s["name"] == "torso"][0]["d"]))
    parts[(parts == "head") & torso & (xs < 127)] = "wheat"
    # the rework's lowered upper arm carries eta: right of x 127 it goes with the torso (HEAD piece),
    # the same split as the torso's own
    upper_arm = sd.grow(mask_of(shp, "arm"), 1)
    parts[(parts == "wheat") & upper_arm & (xs >= 127)] = "head"
    parts[L[4][1], L[4][0]] = "wing"
    return img, parts, line


def save(img: np.ndarray, path: Path):
    Image.fromarray(img, "RGBA").save(path)
    print(f"wrote {path.relative_to(ROOT)}")


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--preview", type=Path, help="also write the figure over the sky, x3, here")
    args = parser.parse_args()
    ART.mkdir(parents=True, exist_ok=True)
    img, parts, line = figure()
    used = sd.check(img)
    print(f"figure: {sum(used.values())} px, {used}")
    print("clearance:", star_clearance(img, line))
    save(img, OUT)
    for part, piece in sd.pieces(img, cl.part_tags(parts, img, L, STAR_PARTS), PARTS).items():
        save(piece, ART / f"virgo_piece_{part}.png")
    if args.preview:
        sd.preview(img, L, SIZES, SEGMENTS).save(args.preview)
        print(f"wrote {args.preview}")
    virgo_part_paintings.build_parts()


if __name__ == "__main__":
    main()
