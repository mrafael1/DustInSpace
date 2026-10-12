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
which group and part lies on top at each pixel. Needs Pillow and numpy.
"""

import re

import numpy as np
from PIL import Image, ImageDraw

W, H, S = 180, 320, 4

TOK = re.compile(r"[MmLlHhVvCcSsQqTtZz]|[-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?")
ELBOWS = (((-1, 0), (0, 1)), ((0, 1), (1, 0)), ((1, 0), (0, -1)), ((0, -1), (-1, 0)))


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


def draw(shapes: list):
    """The figure's line and layout: (line, groups, parts), where `line` is the 1 px line mask,
    `groups` the index of the group on top at each pixel (-1 none; groups numbered bottom to top)
    and `parts` that group's part ("" none)."""
    masks, top, part_of = {}, {}, {}
    for k, s in enumerate(shapes):
        g = s.get("group", s["name"])
        masks[g] = masks[g] | fill_4x(s["d"]) if g in masks else fill_4x(s["d"])
        if not masks[g].any():
            raise ValueError(f"shape {s['name']} is empty")
        top[g] = k
        part_of[g] = s["part"]
    order = sorted(masks, key=lambda g: top[g])
    small = [down(masks[g]) for g in order]
    line = np.zeros((H, W), bool)
    for i, m in enumerate(small):
        above = np.zeros((H, W), bool)
        for m2 in small[i + 1:]:
            above |= m2
        line |= edge_inner(m) & ~(above & ~edge_inner(above))
    line = drop_elbows(drop_specks(drop_elbows(thin(line)), 4))
    groups = np.full((H, W), -1)
    for i, m in enumerate(small):
        groups[m] = i
    parts = np.array([part_of[g] for g in order] + [""], dtype=object)[groups]
    return line, groups, parts
