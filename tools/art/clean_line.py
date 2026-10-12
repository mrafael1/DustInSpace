"""Clean-line figures: a constellation drawn as one thin unbroken line round each of its parts, the
way modern zodiac line art draws it, for a builder to colour and fill (tools/art/stardust.py).

A figure is a list of closed shapes authored in 4x space (720x1280; game pixel (x, y) covers 4x..4x+3):

    {"name": "plate0", "part": "heart", "group": "plate0", "d": "M 400 800 L ... Z"}

* "d" is an SVG path: M L H V C S Q T Z, absolute or relative (upper or lower case).
* Shapes are stacked in list order (later on top). Shapes sharing a "group" merge into one part of
  the drawing with no line between them; each group draws its outline except where a later group
  covers it, so an overlap reads as one part in front of another.
* "part" is the chapter part (chart piece) the shape's pixels go with.

`draw` turns the shapes into a 1 px line (thinned, no 2x2 blocks, no L elbows, no specks) and says
which group and part lies on top at each pixel. `semi_hollow` paints a figure from them: the line in
the Stardust ramp, stardust dithered inside each group so the sky shows through its middle, and the
landmark stars kept clear; `part_tags` cuts it into the chapter's pieces. The shape helpers (`Axis`,
`segment`, `tube`, `placed`, `cubic`, `path_of`) build shapes from spines and local outlines.
Needs Pillow and numpy.
"""

import math
import re

import numpy as np
from PIL import Image, ImageDraw

import stardust as sd

W, H, S = 180, 320, 4

TOK = re.compile(r"[MmLlHhVvCcSsQqTtZz]|[-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?")
ELBOWS = (((-1, 0), (0, 1)), ((0, 1), (1, 0)), ((1, 0), (0, -1)), ((0, -1), (-1, 0)))
# The end panel's top row on the home screen after a final's win (game/ui/end_screen.gd, TOP
# shifted with the sky): a painting stops above it.
END_PANEL_TOP = 243

# The painting over the line (`semi_hollow`): the line LINE_STEPS above the sky (one more on its
# lit side), stardust dithered inside each segment (thick along its edge over BAND px, thin in its
# middle), specks, and a few rose glints on the brightest stretches of the line.
LINE_STEPS = 4
LIT_FACING = 0.15
NEBULA_CELL = 8
BAND = 5.0
CORE = 0.16
FILL = 1.45
SECOND = 0.40
GLINT_FACING = 0.45
GLINTS = 0.14


def _bez(pts, n):
    t = np.linspace(0, 1, n)[:, None]
    if len(pts) == 3:
        p0, p1, p2 = (np.array(p, float) for p in pts)
        return (1 - t) ** 2 * p0 + 2 * (1 - t) * t * p1 + t ** 2 * p2
    p0, p1, p2, p3 = (np.array(p, float) for p in pts)
    return (1 - t) ** 3 * p0 + 3 * (1 - t) ** 2 * t * p1 + 3 * (1 - t) * t ** 2 * p2 + t ** 3 * p3


def flatten(d: str) -> list:
    """An SVG path as a list of subpaths, each (points Nx2, closed)."""
    toks = TOK.findall(d)
    i, cmd = 0, None
    cur, start = np.zeros(2), np.zeros(2)
    last_ctrl = None
    subs, pts = [], []

    def num():
        nonlocal i
        i += 1
        return float(toks[i - 1])

    def flush(closed):
        nonlocal pts
        if len(pts) > 1:
            subs.append((np.array(pts), closed))
        pts = []

    while i < len(toks):
        if re.match(r"[A-Za-z]", toks[i]):
            cmd = toks[i]
            i += 1
            if cmd in "Zz":
                if pts:
                    pts.append(tuple(start))
                flush(True)
                cur = start.copy()
                last_ctrl = None
                continue
        if cmd is None:
            raise ValueError("a path starts with a command")
        rel = cmd.islower()
        c = cmd.upper()
        base = cur if rel else np.zeros(2)
        if c == "M":
            flush(False)
            cur = base + (num(), num())
            start = cur.copy()
            pts = [tuple(cur)]
            cmd = "l" if rel else "L"
            last_ctrl = None
        elif c == "L":
            cur = base + (num(), num())
            pts.append(tuple(cur))
            last_ctrl = None
        elif c == "H":
            x = num()
            cur = np.array([cur[0] + x if rel else x, cur[1]])
            pts.append(tuple(cur))
            last_ctrl = None
        elif c == "V":
            y = num()
            cur = np.array([cur[0], cur[1] + y if rel else y])
            pts.append(tuple(cur))
            last_ctrl = None
        elif c in "CS":
            c1 = base + (num(), num()) if c == "C" else (2 * cur - last_ctrl if last_ctrl is not None else cur.copy())
            c2 = base + (num(), num())
            e = base + (num(), num())
            pts.extend(map(tuple, _bez([cur, c1, c2, e], 48)[1:]))
            last_ctrl, cur = c2, e
        elif c in "QT":
            c1 = base + (num(), num()) if c == "Q" else (2 * cur - last_ctrl if last_ctrl is not None else cur.copy())
            e = base + (num(), num())
            pts.extend(map(tuple, _bez([cur, c1, e], 40)[1:]))
            last_ctrl, cur = c1, e
        else:
            raise ValueError(f"unsupported path command {cmd}")
    flush(False)
    return subs


def fill_4x(d: str) -> np.ndarray:
    """A closed path filled in 4x space."""
    img = Image.new("L", (W * S, H * S), 0)
    dr = ImageDraw.Draw(img)
    for pts, _ in flatten(d):
        if len(pts) >= 3:
            dr.polygon([tuple(p) for p in pts], fill=255)
    return np.array(img) > 0


def down(mask4: np.ndarray, thr: int = 8) -> np.ndarray:
    """A 4x mask at 1x: a pixel is in where at least `thr` of its 16 sub-pixels are."""
    return mask4.reshape(H, S, W, S).sum((1, 3)) >= thr


def edge_inner(m: np.ndarray) -> np.ndarray:
    """The pixels of `m` with a 4-neighbour outside it."""
    n = np.zeros(m.shape + (4,), bool)
    n[1:, :, 0] = m[:-1]
    n[:-1, :, 1] = m[1:]
    n[:, 1:, 2] = m[:, :-1]
    n[:, :-1, 3] = m[:, 1:]
    return m & ~n.all(-1)


def thin(m: np.ndarray) -> np.ndarray:
    """Zhang-Suen thinning: `m` down to 1 px strokes."""
    m = m.copy().astype(np.uint8)
    changed = True
    while changed:
        changed = False
        for step in (0, 1):
            p = np.pad(m, 1)
            P2, P3, P4, P5 = p[:-2, 1:-1], p[:-2, 2:], p[1:-1, 2:], p[2:, 2:]
            P6, P7, P8, P9 = p[2:, 1:-1], p[2:, :-2], p[1:-1, :-2], p[:-2, :-2]
            seq = [P2, P3, P4, P5, P6, P7, P8, P9, P2]
            B = sum(seq[:8])
            A = sum(((seq[k] == 0) & (seq[k + 1] == 1)).astype(int) for k in range(8))
            if step == 0:
                c = (P2 * P4 * P6 == 0) & (P4 * P6 * P8 == 0)
            else:
                c = (P2 * P4 * P8 == 0) & (P2 * P6 * P8 == 0)
            rm = (m == 1) & (B >= 2) & (B <= 6) & (A == 1) & c
            if rm.any():
                m[rm] = 0
                changed = True
    return m.astype(bool)


def drop_elbows(m: np.ndarray) -> np.ndarray:
    """Pixel-perfect: drops each elbow pixel whose two orthogonal neighbours already touch."""
    m = m.copy()
    for _ in range(4):
        changed = False
        for y, x in zip(*np.nonzero(m)):
            def on(dy, dx):
                return 0 <= y + dy < H and 0 <= x + dx < W and m[y + dy, x + dx]
            if sum(on(dy, dx) for dy in (-1, 0, 1) for dx in (-1, 0, 1) if dy or dx) != 2:
                continue
            for a, b in ELBOWS:
                if on(*a) and on(*b):
                    m[y, x] = False
                    changed = True
                    break
        if not changed:
            break
    return m


def drop_specks(m: np.ndarray, min_size: int = 4) -> np.ndarray:
    """Drops each 8-connected bit of `m` smaller than `min_size` pixels."""
    m = m.copy()
    seen = np.zeros_like(m)
    for y, x in zip(*np.nonzero(m)):
        if seen[y, x]:
            continue
        stack, comp = [(y, x)], []
        seen[y, x] = True
        while stack:
            cy, cx = stack.pop()
            comp.append((cy, cx))
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    yy, xx = cy + dy, cx + dx
                    if 0 <= yy < H and 0 <= xx < W and m[yy, xx] and not seen[yy, xx]:
                        seen[yy, xx] = True
                        stack.append((yy, xx))
        if len(comp) < min_size:
            for cy, cx in comp:
                m[cy, cx] = False
    return m


def stroke(d: str) -> np.ndarray:
    """An open path drawn as a 1 px pixel-perfect line (no doubled steps, no L elbows)."""
    m = np.zeros((H, W), bool)
    for pts, _ in flatten(d):
        dense = []
        for a, b in zip(pts[:-1], pts[1:]):
            n = max(2, int(np.hypot(*(b - a)) / 0.5))
            dense.extend(a + (b - a) * t for t in np.linspace(0, 1, n, endpoint=False))
        dense.append(pts[-1])
        path = []
        for p in dense:
            q = (int(p[1] // S), int(p[0] // S))
            if not path or path[-1] != q:
                path.append(q)
        full = [path[0]]
        for q in path[1:]:
            py, px = full[-1]
            while max(abs(q[0] - py), abs(q[1] - px)) > 1:
                py += int(np.sign(q[0] - py))
                px += int(np.sign(q[1] - px))
                full.append((py, px))
            full.append(q)
        kept = [full[0]]
        for k in range(1, len(full)):
            if k + 1 < len(full):
                a, b, c = kept[-1], full[k], full[k + 1]
                if a[0] != c[0] and a[1] != c[1] and (a[0] == b[0] or a[1] == b[1]) and (b[0] == c[0] or b[1] == c[1]):
                    continue
            kept.append(full[k])
        for y, x in kept:
            if 0 <= y < H and 0 <= x < W:
                m[y, x] = True
    return m


def draw(shapes: list, strokes=()):
    """The figure's line and layout: (line, groups, parts), where `line` is the 1 px line mask,
    `groups` the index of the group on top at each pixel (-1 none; groups numbered bottom to top)
    and `parts` that group's part ("" none). A shape with "outline": False only fills (it carries
    the stardust and its part, with no line round it). `strokes` are open paths
    ({"name", "part", "d"}) drawn as 1 px lines over everything; off the shapes their pixels go
    with their own part."""
    masks, top, part_of, outlined = {}, {}, {}, {}
    for k, s in enumerate(shapes):
        g = s.get("group", s["name"])
        masks[g] = masks[g] | fill_4x(s["d"]) if g in masks else fill_4x(s["d"])
        if not masks[g].any():
            raise ValueError(f"shape {s['name']} is empty")
        top[g] = k
        part_of[g] = s["part"]
        outlined[g] = outlined.get(g, True) and s.get("outline", True)
    order = sorted(masks, key=lambda g: top[g])
    small = [down(masks[g]) for g in order]
    line = np.zeros((H, W), bool)
    for i, m in enumerate(small):
        if not outlined[order[i]]:
            continue
        above = np.zeros((H, W), bool)
        for g2, m2 in zip(order[i + 1:], small[i + 1:]):
            if outlined[g2]:
                above |= m2
        line |= edge_inner(m) & ~(above & ~edge_inner(above))
    line = drop_elbows(drop_specks(drop_elbows(thin(line)), 4))
    groups = np.full((H, W), -1)
    for i, m in enumerate(small):
        groups[m] = i
    parts = np.array([part_of[g] for g in order] + [""], dtype=object)[groups]
    # Within a group, each pixel goes with the part of its own shape on top (one outline can span
    # two parts).
    index = {g: i for i, g in enumerate(order)}
    for s in shapes:
        g = index[s.get("group", s["name"])]
        mine = down(fill_4x(s["d"])) & (groups == g)
        parts[mine] = s["part"]
    if strokes:
        drawn = np.zeros((H, W), bool)
        for st in strokes:
            m = stroke(st["d"])
            parts[m & (groups < 0) & ~drawn] = st["part"]
            drawn |= m
        line = drop_elbows(line | drawn)
    return line, groups, parts


# ---- Shape helpers, in 4x space ----

def catmull(pts, n=40):
    """A Catmull-Rom curve through `pts`, `n` points per span."""
    pts = [np.array(p, float) for p in pts]
    P = [pts[0] * 2 - pts[1]] + pts + [pts[-1] * 2 - pts[-2]]
    out = []
    for i in range(1, len(P) - 2):
        p0, p1, p2, p3 = P[i - 1], P[i], P[i + 1], P[i + 2]
        for t in np.linspace(0, 1, n, endpoint=False):
            t2, t3 = t * t, t * t * t
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2
                              + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    out.append(P[-2])
    return np.array(out)


class Axis:
    """A smooth spine, walked by arclength: its point, tangent and normal (left of travel)."""

    def __init__(self, pts):
        self.p = catmull(pts, 60)
        d = np.linalg.norm(np.diff(self.p, axis=0), axis=1)
        self.s = np.concatenate([[0], np.cumsum(d)])
        self.L = self.s[-1]

    def at(self, s):
        s = min(max(s, 0), self.L)
        return np.array([np.interp(s, self.s, self.p[:, 0]), np.interp(s, self.s, self.p[:, 1])])

    def tan(self, s):
        s = min(max(s, 0), self.L)
        t = self.at(min(s + 3, self.L)) - self.at(max(s - 3, 0))
        if np.linalg.norm(t) < 1e-6:
            t = self.p[-1] - self.p[-2] if s > self.L / 2 else self.p[1] - self.p[0]
        return t / np.linalg.norm(t)

    def frame(self, s):
        t = self.tan(s)
        return self.at(s), t, np.array([-t[1], t[0]])


def path_of(pts):
    """A closed polygon as an SVG path (0.1 px)."""
    pts = [(round(float(x), 1), round(float(y), 1)) for x, y in pts]
    return "M %s %s " % pts[0] + " ".join("L %s %s" % p for p in pts[1:]) + " Z"


def segment(axis, s0, s1, w0, w1, p=4.0, n=48, pinch=0.0):
    """A body segment from arclength s0 to s1, half-width w0 to w1, with superellipse ends."""
    left, right = [], []
    for u in np.linspace(-1, 1, n):
        s = s0 + (u + 1) / 2 * (s1 - s0)
        c, t, nrm = axis.frame(s)
        w = w0 + (w1 - w0) * (u + 1) / 2
        k = (1 - abs(u) ** p) ** (1 / p)
        k *= 1 - pinch * (u * u)
        left.append(c + nrm * w * k)
        right.append(c - nrm * w * k)
    return left + right[::-1]


def tube(spine, w0, w1, n=50):
    """A tapered tube along a smoothed spine, with round end caps."""
    ax = Axis(spine)
    left, right = [], []
    for s in np.linspace(0, ax.L, n):
        c, t, nrm = ax.frame(s)
        w = w0 + (w1 - w0) * s / ax.L
        left.append(c + nrm * w)
        right.append(c - nrm * w)
    c1, t1, n1 = ax.frame(ax.L)
    cap_end = [c1 + t1 * w1 * math.sin(a) + n1 * w1 * math.cos(a) for a in np.linspace(0, math.pi, 9)[1:-1]]
    c0, t0, n0 = ax.frame(0)
    cap_start = [c0 - t0 * w0 * math.sin(a) - n0 * w0 * math.cos(a) for a in np.linspace(0, math.pi, 9)[1:-1]]
    return left + cap_end + right[::-1] + cap_start


def placed(origin, ang_deg, pts):
    """Local points (x along the pointing direction `ang_deg`, y to its upper side) on the screen."""
    a = math.radians(ang_deg)
    u = np.array([math.cos(a), math.sin(a)])
    w = np.array([math.sin(a), -math.cos(a)])
    o = np.array(origin, float)
    return [o + u * x + w * y for x, y in pts]


def cubic(p0, p1, p2, p3, n=16):
    p0, p1, p2, p3 = (np.array(p, float) for p in (p0, p1, p2, p3))
    return [((1 - t) ** 3) * p0 + 3 * ((1 - t) ** 2) * t * p1 + 3 * (1 - t) * t * t * p2 + t ** 3 * p3
            for t in np.linspace(0, 1, n)]


# ---- The painting ----

def blur(a, r):
    """`a` box-blurred three times with radius `r` (about a Gaussian)."""
    out = a.astype(float)
    k = 2 * r + 1
    for _ in range(3):
        c = np.pad(np.cumsum(np.cumsum(np.pad(out, r, mode="edge"), 0), 1), ((1, 0), (1, 0)))
        out = (c[k:, k:] - c[:-k, k:] - c[k:, :-k] + c[:-k, :-k]) / (k * k)
    return out


def semi_hollow(shapes: list, landmarks, sizes, seed: int, light, bottom: int = END_PANEL_TOP, strokes=(),
                along_lines: bool = False):
    """A figure painted semi-hollow: the clean line in the Stardust ramp, and stardust dithered inside each
    segment, thick at its edge and thin in its middle so the sky shows through (semi-hollow). With
    `along_lines` (line art over fill-only shapes) the stardust gathers along the lines instead of
    the shapes' borders. Returns the painting and each pixel's part (the group's on top, "" off the
    form)."""
    line, groups, parts = draw(shapes, strokes)
    form = groups >= 0
    core = CORE * (0.4 if along_lines else 1.0)
    rng = np.random.default_rng(seed)
    # Which way each pixel faces, read off the silhouette: the blurred form's slope points out.
    gy, gx = np.gradient(blur(form, 3))
    light = np.array(light[:2], float) / np.linalg.norm(light[:2])
    mag = np.hypot(gx, gy) + 1e-6
    facing = (-gx * light[0] - gy * light[1]) / mag * np.clip(mag * 6, 0, 1)
    lit = np.clip(0.5 + 0.6 * facing, 0, 1)
    # Each segment hollow on its own: the distance to its own visible border.
    dist = np.zeros((H, W))
    for g in range(groups.max() + 1):
        dist = np.maximum(dist, sd.distance_inside(groups == g))
    if along_lines:
        dist = np.where(form, 1.0 + sd.distance_inside(~line), 0.0)
    inside = form & ~line

    dust = sd.Dust()
    dust.put(line, LINE_STEPS)
    dust.put(line & (facing > LIT_FACING), LINE_STEPS + 1)
    neb = sd.value_noise(rng, NEBULA_CELL, 3)
    band = np.clip(1.0 - (dist - 1.0) / BAND, 0.0, 1.0)
    dens = (band * (0.35 + 0.55 * lit) + core + 0.15 * lit) * np.clip((neb - 0.22) * 2.4, 0, 1.2) * FILL
    dust.put(inside & (sd.BAY < dens), 1)
    dust.put(inside & (sd.BAY < dens * SECOND) & (lit > 0.5), 2)
    sd.specks(dust, form, dist, sd.distance_inside(~form), lit)
    dust.fixed[line] = ""
    for y, x in zip(*np.nonzero(line & (facing > GLINT_FACING))):
        if sd.hsh(x, y, 4) < GLINTS:
            dust.fixed[y, x] = "N9"
    sd.star_gaps(dust, landmarks, sizes)
    sky = sd.sky_index()
    img = sd.resolve(dust, sky)
    # Each star on one faint pixel of its own (one step above the sky, hidden under the star): its
    # piece holds it, so the chart can grow that piece from its stars.
    for x, y in landmarks:
        if not img[y, x, 3]:
            img[y, x, :3] = sd.PAL[sd.N[sky[y, x] + 1]]
            img[y, x, 3] = 255
    # Nothing at or below the end panel, so the whole figure stays in view after the win.
    img[bottom:] = 0
    return sd.sun_clamp(img), parts


def part_tags(parts: np.ndarray, img: np.ndarray, landmarks, star_parts: dict) -> np.ndarray:
    """Each painted pixel's part: the part of the segment under it, else the nearest tagged pixel's
    (the specks off the form). Each star's own pixel goes with its part, and each star must sit on
    a segment of its part."""
    for star, part in star_parts.items():
        x, y = landmarks[star]
        assert parts[y, x] == part, f"landmark {star} sits on {parts[y, x] or 'nothing'}, not {part}"
    tags = sd.spread_tags(parts, img[..., 3] > 0)
    for star, part in star_parts.items():
        x, y = landmarks[star]
        tags[y, x] = part
    return tags


def outline(points, n: int = 12) -> list:
    """A smooth closed outline through `points` (game pixels), as 4x polygon points: a closed
    Catmull-Rom curve, `n` points per span."""
    pts = [np.array(p, float) * S for p in points]
    k = len(pts)
    out = []
    for i in range(k):
        p0, p1, p2, p3 = pts[i - 1], pts[i], pts[(i + 1) % k], pts[(i + 2) % k]
        for t in np.linspace(0, 1, n, endpoint=False):
            t2, t3 = t * t, t * t * t
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2
                              + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    return out
