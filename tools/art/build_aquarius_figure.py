"""Builds the painted Aquarius (chapter 2's reward) and its pieces, in assets/art/:

  aquarius_figure.png         the whole water carrier, the final's reward and the chart's
  aquarius_piece_<part>.png   the same painting cut into the chapter's five parts (hand, body, legs,
                              stream, jar), in the same full-screen home layout: the chapter chart
                              assembles them as parts are won
  aquarius_part_<part>.png    each part stage's own painting, the same body part fitted to that
                              stage's own landmarks (game/core/star_map.gd, read from the source),
                              shown when the stage is complete

The same modelling as the Scorpio (tools/art/build_scorpio_figure.py, whose solids, lighting and
stepped shading it reuses): overlapping solids lit from the top left, shaded on a stepped palette
ramp with a Bayer checker only along each seam, dark creases at joints, a rose rim on lit edges,
stardust specks and a thin aura. Every body part is anchored to Aquarius's 14 landmarks (the
chart's figure, StarMap.aquarius): the head on Sadalmelik, the right arm through the shoulder
(Sadalsuud) to the hand (epsilon), the left arm holding up the tilted jar (Sadachbia, zeta and eta
its Y, pi its handle), the torso down to theta, the kneeling leg through the knee (lambda) and tau
to the foot (Skat), and the water pouring from the jar's mouth down the left through phi, psi and 98.
The water is its own material, shaded on the cool M ramp (M2-M6, with a D0 rim), so it reads apart
from the figure's N ramp. No colour outside the Stellar Sun palette; every pixel opaque or empty.

Run: python tools/art/build_aquarius_figure.py   (needs Pillow and numpy)
"""

import importlib.util
import re
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
_spec = importlib.util.spec_from_file_location("scorpio_art", ROOT / "tools" / "art" / "build_scorpio_figure.py")
sc = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(sc)

ART = sc.ART
STAR_MAP = sc.STAR_MAP
W, H = sc.W, sc.H
v, lerp, unit, bezier = sc.v, sc.lerp, sc.unit, sc.bezier
PARTS = ("hand", "body", "legs", "stream", "jar")

HEX = dict(sc.HEX)
HEX.update({"M2": "1B2150", "M3": "2B3470", "M4": "4A5AA8", "M5": "9FB0EE", "M6": "D9E2FF"})
RGB = {k: tuple(int(c[i:i + 2], 16) for i in (0, 2, 4)) for k, c in HEX.items()}
sc.RGB.update(RGB)

# Each material's shading ramp (darkest first) and rim (lit edge, then brightest).
RAMPS = {
    "body": (list(sc.RAMP), list(sc.RIM)),
    "water": (["M3", "M3", "M4", "M4", "M4", "M5", "M5", "M6"], ["M6", "D0"]),
}

# Aquarius's landmarks (StarMap.aquarius): 0 epsilon (hand), 1 Sadalsuud (shoulder), 2 Sadalmelik
# (head), 3 Sadachbia, 4 zeta, 5 eta (the jar's Y), 6 pi (its handle), 7 theta (the body), 8 lambda
# (the knee), 9 tau, 10 Skat (the foot), 11 phi, 12 psi, 13 98 (the stream).
L = [(150, 156), (124, 140), (98, 124), (74, 118), (50, 112), (26, 118), (52, 88), (90, 150),
     (66, 160), (70, 186), (88, 206), (42, 170), (30, 192), (24, 218)]

# Which part owns each landmark (ChapterDef.aquarius).
STAR_PARTS = {0: "hand", 1: "hand", 2: "body", 7: "body", 8: "legs", 9: "legs", 10: "legs",
              11: "stream", 12: "stream", 13: "stream", 3: "jar", 4: "jar", 5: "jar", 6: "jar"}


class Solids(sc.Solids):
    """The Scorpio's solids, each also tagged with its material (`mat`: body or water)."""

    def __init__(self):
        super().__init__()
        self.mat = "body"
        self.mats = []

    def _put(self, *args, **kwargs):
        self.mats.append(self.mat)
        super()._put(*args, **kwargs)


def water(S, points, r0, r1, lift=0.0):
    """A pouring ribbon of water through `points` (smoothed), widening from r0 to r1."""
    S.mat = "water"
    path = []
    for k in range(len(points) - 1):
        a, b = v(points[k]), v(points[k + 1])
        bend = np.array([-(b - a)[1], (b - a)[0]]) * (0.12 if k % 2 else -0.12)
        path += bezier(a, (a + b) / 2 + bend, b, 6)[:-1]
    path.append(tuple(v(points[-1])))
    radii = np.linspace(r0, r1, len(path))
    # Flat lozenges along the path, not a round pipe: water lies in a sheet and catches the light
    # evenly, glinting along its middle.
    for k in range(len(path) - 1):
        a, b = v(path[k]), v(path[k + 1])
        S.ellipsoid((a + b) / 2, b - a, np.linalg.norm(b - a) / 2 + radii[k] * 0.9, radii[k], depth=1.6, lift=lift, squash=2.5, along_flat=0.2)
    S.mat = "body"


def jar(S, base, mouth, centre, handle, size=1.0):
    """The urn, tilted to pour: a round belly round `centre` from its base towards its mouth, a neck
    and lip at the mouth, and a looped handle up through `handle`."""
    along = unit(v(mouth) - v(base))
    S.ellipsoid(centre, along, 21.0 * size, 14.0 * size, depth=11.0 * size, lift=2.0)
    S.ellipsoid(lerp(centre, base, 0.75), along, 9.0 * size, 9.0 * size, depth=6.0 * size, lift=1.0)
    S.capsule(lerp(centre, mouth, 0.55), mouth, 6.5 * size, 5.5 * size, lift=2.5)
    S.ellipsoid(mouth, along, 3.0 * size, 7.0 * size, depth=3.0 * size, lift=3.0)
    top = v(handle)
    left, right = lerp(centre, mouth, 0.35) + v((0, -9)) * size, lerp(centre, base, 0.35) + v((0, -9)) * size
    S.chain(bezier(left, top + v((-5, -2)) * size, top, 5) + bezier(top, top + v((5, -2)) * size, right, 5)[1:],
            [2.6 * size] * 9, lift=1.0)


def build_figure(S):
    hand, shoulder, head, sadachbia, zeta, eta, pi, theta, knee, tau, skat, phi, psi, s98 = map(v, L)

    # The far leg, kneeling behind the body (under everything).
    S.tag = "legs"
    far_knee = theta + v((22, 20))
    S.chain([theta + v((4, 4)), far_knee, far_knee + v((-6, 26)), far_knee + v((10, 32))], [8.5, 6.8, 5.0, 3.6], lift=-6.0)
    # The near leg: the thigh to the knee (lambda), the shin down through tau, the foot on Skat.
    S.chain([theta + v((-2, 4)), knee], [10.0, 8.0], lift=-1.0)
    S.chain([knee, tau, skat], [7.0, 5.6, 4.2], lift=-2.0)
    S.ellipsoid(skat + v((6, 1)), (1.0, 0.15), 8.0, 4.2, depth=3.5, lift=-1.5)

    # The torso, from the neck down to theta; the head on Sadalmelik, with hair.
    S.tag = "body"
    S.ellipsoid(lerp(head, theta, 0.45) + v((3, 2)), theta - head, 20.0, 15.0, depth=11.0, lift=0.0, along_flat=0.6)
    S.ellipsoid(head + v((8, 10)), (1.0, 0.3), 10.0, 7.0, depth=6.0, lift=0.5)
    S.ellipsoid(theta + v((3, 3)), (1.0, 0.2), 13.0, 10.0, depth=8.0, lift=0.5)
    S.capsule(head + v((1, 2)), head + v((2, 10)), 4.5, 5.0, lift=1.0)
    S.ellipsoid(head + v((0, -5)), (0.2, -1.0), 9.0, 8.0, depth=7.0, lift=3.0)
    S.ellipsoid(head + v((4, -10)), (1.0, -0.4), 7.5, 5.0, depth=4.5, lift=3.5)

    # The right arm, out through the shoulder (Sadalsuud) to the hand (epsilon), palm open.
    S.tag = "hand"
    root = head + v((14, 10))
    S.chain([root, shoulder, hand], [6.5, 5.4, 4.2], lift=1.5)
    S.ellipsoid(hand + v((4, 2)), unit(hand - shoulder), 6.0, 4.4, depth=4.0, lift=2.0)

    # The left arm holding up the jar, and the jar, tilted to pour from eta's side.
    S.tag = "jar"
    S.chain([head + v((-8, 12)), lerp(head, sadachbia, 0.5) + v((-4, 14)), sadachbia + v((6, 6))], [6.0, 5.2, 4.4], lift=1.0)
    jar(S, base=sadachbia + v((6, 2)), mouth=eta + v((-2, 2)), centre=zeta + v((2, 0)), handle=pi)

    # The water: from the jar's mouth down the left, through phi, psi and 98, to a pool.
    S.tag = "stream"
    water(S, [eta + v((-3, 6)), (eta[0] + 4, 146), phi, psi, s98, s98 + v((8, 14))], 3.0, 6.5, lift=-0.5)
    S.mat = "water"
    S.ellipsoid(s98 + v((10, 16)), (1.0, 0.0), 13.0, 3.8, depth=2.5, lift=-2.0)
    S.mat = "body"


# The part stages' own paintings: the same body parts, fitted to each stage's landmarks.

def stage_landmarks():
    """Each Aquarius stage's landmarks, read from game/core/star_map.gd (one source of truth)."""
    src = STAR_MAP.read_text()
    found = {}
    for part in PARTS:
        block = re.search(r"static func aquarius_%s\(\) -> StarMap:(.*?)\n\n\n" % part, src, re.S).group(1)
        marks = re.search(r"map\.landmarks = \[(.*?)\]\n", block).group(1)
        found[part] = [(int(x), int(y)) for x, y in re.findall(r"Vector2i\((-?\d+), (-?\d+)\)", marks)]
    return found


def build_hand(S, M):
    """The Hand: the arm from the shoulder (the first star) down to the open hand (the last)."""
    M = [v(p) for p in M]
    S.ellipsoid(M[0], (1.0, 0.4), 9.0, 7.5, depth=6.0, lift=1.0)
    S.chain(M, list(np.linspace(6.0, 3.6, len(M))), lift=0.0)
    S.ellipsoid(M[-1] + unit(M[-1] - M[-2]) * 4.0, unit(M[-1] - M[-2]), 6.5, 4.6, depth=4.0, lift=1.0)
    for k, spread in enumerate((-0.5, -0.15, 0.2, 0.55)):
        out = unit(M[-1] - M[-2])
        side = np.array([-out[1], out[0]])
        base = M[-1] + out * 8.0 + side * spread * 6.0
        S.capsule(base, base + out * (5.0 - abs(spread) * 2.0) + side * spread * 3.0, 1.6, 1.1, lift=0.5)


def build_body(S, M):
    """The Body: the head (first), the torso down the neck and body stars, the near leg to the knee
    and foot, and the far leg out to the hip branch."""
    M = [v(p) for p in M]
    S.ellipsoid(M[0] + v((0, -2)), (0.3, -1.0), 10.0, 9.0, depth=7.0, lift=3.0)
    S.capsule(M[0], M[1], 5.5, 7.0, lift=1.5)
    S.ellipsoid(lerp(M[1], M[2], 0.45), M[2] - M[0], 20.0, 15.0, depth=11.0, lift=0.5, along_flat=0.6)
    S.chain([M[2], M[3]], [9.0, 7.0], lift=-1.0)
    S.chain([M[3], M[4]], [6.0, 4.0], lift=-2.0)
    S.ellipsoid(M[4] + v((-4, 2)), (-1.0, 0.2), 6.5, 3.4, depth=3.0, lift=-1.5)
    S.chain([M[2], M[5]], [8.0, 5.0], lift=-4.0)


def build_legs(S, M):
    """The Legs: the hip (first), the near leg through the knee and shin to the foot, the far leg
    through the calf to the heel."""
    M = [v(p) for p in M]
    S.ellipsoid(M[0], (1.0, 0.3), 11.0, 9.0, depth=7.0, lift=1.0)
    S.chain([M[0], M[1]], [8.5, 7.0], lift=0.0)
    S.chain([M[1], M[2], M[3]], [6.5, 5.0, 3.8], lift=-1.0)
    S.ellipsoid(M[3] + v((-4, 2)), (-1.0, 0.2), 6.5, 3.4, depth=3.0, lift=-0.5)
    S.chain([M[1], M[4], M[5]], [6.0, 4.8, 3.8], lift=-3.0)
    S.ellipsoid(M[5] + v((4, 2)), (1.0, 0.2), 6.5, 3.4, depth=3.0, lift=-2.5)


def build_stream(S, M):
    """The Stream: water winding down through every star, widening, to a pool past the last."""
    water(S, M + [tuple(v(M[-1]) + v((6, 10)))], 3.0, 6.5, lift=0.0)
    S.mat = "water"
    S.ellipsoid(v(M[-1]) + v((8, 12)), (1.0, 0.0), 15.0, 4.0, depth=2.5, lift=-1.0)
    S.mat = "body"


def build_jar(S, M):
    """The Jar: the urn round its Y (zeta its centre, eta and Sadachbia its sides, pi its handle),
    upright, its lip below, pouring water out through the spout star."""
    M = [v(p) for p in M]
    top, centre, left, right, lip, spout = M
    S.ellipsoid(lerp(centre, lip, 0.5), (0.0, 1.0), 26.0, 34.0, depth=16.0, lift=1.0)
    S.ellipsoid(lip, (1.0, 0.0), 12.0, 4.5, depth=4.0, lift=2.0)
    S.chain(bezier(left + v((6, -14)), top + v((-14, -4)), top, 5) + bezier(top, top + v((14, -4)), right + v((-6, -14)), 5)[1:],
            [3.2] * 9, lift=-1.0)
    water(S, [lip + v((-4, 3)), lerp(lip, spout, 0.5), spout, spout + v((-6, 12))], 3.2, 5.0, lift=-0.5)


STAGE_BUILDERS = {"hand": build_hand, "body": build_body, "legs": build_legs, "stream": build_stream, "jar": build_jar}


def shade(S):
    """The Scorpio's shading, per material: the body on the N ramp, the water on the M ramp."""
    img = np.zeros((H, W, 4), dtype=np.uint8)
    inside = S.z >= 0.0
    mats = np.array(S.mats + [""], dtype=object)[np.where(S.owner >= 0, S.owner, len(S.mats))]
    for mat, (ramp, rim) in RAMPS.items():
        sc.RAMP[:] = ramp
        sc.RIM[:] = rim
        part = sc.shade(S)
        mask = inside & (mats == mat)
        img[mask] = part[mask]
        aura = (~inside) & (part[..., 3] > 0) & (img[..., 3] == 0)
        img[aura] = part[aura]
    sc.RAMP[:] = RAMPS["body"][0]
    sc.RIM[:] = RAMPS["body"][1]
    return img


def stardust(img):
    """The Scorpio's stardust specks on the figure's dark steps, and glints on the water."""
    dark = {RGB[k] for k in ("N2", "N3", "N4")}
    wet = {RGB[k] for k in ("M4", "M5")}
    for y in range(H):
        for x in range(W):
            if img[y, x, 3] and tuple(img[y, x, :3]) in wet:
                h = ((x * 2246822519 + y * 3266489917) & 0xFFFFFFFF)
                h = ((h ^ (h >> 15)) * 668265263) & 0xFFFFFFFF
                if h % 11 == 0:
                    img[y, x, :3] = RGB["M6"] if h % 4 else RGB["D0"]
    for y in range(H):
        for x in range(W):
            if img[y, x, 3] and tuple(img[y, x, :3]) in dark:
                h = (x * 374761393 + y * 668265263) & 0xFFFFFFFF
                h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
                if h % 37 == 0:
                    img[y, x, :3] = RGB["N8"] if h % 3 else RGB["D0"]


def pieces(S, img):
    """The whole cut by part, as the Scorpio's: each pixel with its solid's part, each aura pixel
    with the body pixel beside it; a joint carrying a star goes with that star's part."""
    for star, part in STAR_PARTS.items():
        x, y = L[star]
        S.tags[S.owner[y, x]] = part
    for star, part in STAR_PARTS.items():
        x, y = L[star]
        assert S.owner[y, x] >= 0, f"landmark {star} sits on no solid"
        assert S.tags[S.owner[y, x]] == part, f"landmark {star} sits on a solid of two parts"
    tags = np.full((H, W), "", dtype=object)
    inside = S.z >= 0.0
    for y, x in zip(*np.nonzero(inside)):
        tags[y, x] = S.tags[S.owner[y, x]]
    for y, x in zip(*np.nonzero(img[..., 3] > 0)):
        if tags[y, x]:
            continue
        for dy, dx in ((0, 1), (1, 0), (0, -1), (-1, 0)):
            ny, nx = (y + dy) % H, (x + dx) % W
            if tags[ny, nx] and inside[ny, nx]:
                tags[y, x] = tags[ny, nx]
                break
    assert all(tags[y, x] for y, x in zip(*np.nonzero(img[..., 3] > 0))), "every pixel has a part"
    out = {}
    for part in PARTS:
        piece = img.copy()
        piece[tags != part] = 0
        out[part] = piece
    return out


def main():
    ART.mkdir(parents=True, exist_ok=True)
    S = Solids()
    build_figure(S)
    img = shade(S)
    stardust(img)
    sc.save(img, ART / "aquarius_figure.png")
    for part, piece in pieces(S, img).items():
        sc.save(piece, ART / f"aquarius_piece_{part}.png")
    for part, landmarks in stage_landmarks().items():
        stage = Solids()
        STAGE_BUILDERS[part](stage, landmarks)
        painting = shade(stage)
        stardust(painting)
        for x, y in landmarks:
            assert stage.owner[y, x] >= 0, f"{part}: landmark ({x}, {y}) sits on no solid"
        sc.save(painting, ART / f"aquarius_part_{part}.png")


if __name__ == "__main__":
    main()
