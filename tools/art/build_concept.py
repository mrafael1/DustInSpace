"""Stellar Sun — pixel-art gameplay mockup generator.
Native canvas 180x320, exported per layer + composited, scaled with nearest neighbour."""
from PIL import Image, ImageDraw, ImageFont
import math, random, os

W, H = 180, 320
SCALE = 4
random.seed(7)

def hx(s): s = s.lstrip('#'); return tuple(int(s[i:i+2], 16) for i in (0, 2, 4)) + (255,)

PAL = {
 # night sky ramp (dark -> horizon)
 'N0':'#07091F','N1':'#0E1438','N2':'#151D4A','N3':'#1E2860','N4':'#2A3375','N5':'#3E3F8A',
 'N6':'#5A51A6','N7':'#7E68C8','N8':'#A77FD8','N9':'#D08FC8','N10':'#F2A9C2',
 # silhouettes
 'M0':'#0A0C26','M1':'#121638','M2':'#1B2150','M3':'#2B3470','M4':'#4A5AA8','M5':'#9FB0EE','M6':'#D9E2FF',
 # starlight (collectibles, links, sun light)
 'C0':'#FFFBEA','C1':'#FFE59A','C2':'#FFC062','C3':'#E88A57','C4':'#A45A78','C5':'#6A3F7A',
 # dying sun
 'S0':'#2A1230','S1':'#45193A','S2':'#6B2238','S3':'#9A3232','S4':'#D0542E',
 # blue pack
 'B0':'#12245A','B1':'#1D4696','B2':'#2F78D0','B3':'#62B4F0','B4':'#B8E6FF',
 # red pack
 'R0':'#4A1226','R1':'#862032','R2':'#C8413A','R3':'#F07A4E','R4':'#FFC09A',
 # dust
 'D0':'#D9CCFF',
}
C = {k: hx(v) for k, v in PAL.items()}

BAYER = [[0,8,2,10],[12,4,14,6],[3,11,1,9],[15,7,13,5]]
def bay(x, y): return (BAYER[y % 4][x % 4] + .5) / 16

def new(): return Image.new('RGBA', (W, H), (0, 0, 0, 0))
def put(im, x, y, c):
    if 0 <= x < W and 0 <= y < H: im.putpixel((int(x), int(y)), C[c] if isinstance(c, str) else c)
def get(im, x, y): return im.getpixel((x, y))
def sprite(im, ox, oy, rows, key):
    for j, r in enumerate(rows):
        for i, ch in enumerate(r):
            if ch in key: put(im, ox + i, oy + j, key[ch])

# ---------------------------------------------------------------- sky
def layer_sky():
    im = new()
    ramp = ['N1','N1','N2','N2','N3','N3','N4','N5','N6','N7','N8','N9','N10']
    stops = [0,30,60,95,130,160,190,212,228,240,250,258,266]
    for y in range(H):
        # piecewise position in ramp
        k = 0
        while k < len(stops) - 1 and y >= stops[k + 1]: k += 1
        if k >= len(stops) - 1: f = len(ramp) - 1
        else: f = k + (y - stops[k]) / (stops[k + 1] - stops[k])
        for x in range(W):
            i = int(f); fr = f - i
            nxt = min(i + 1, len(ramp) - 1)
            # dither only in the last 45% of each band: clean bands, checker seams
            c = ramp[nxt] if fr > .55 and bay(x, y) < (fr - .55) / .45 else ramp[i]
            put(im, x, y, c)
    # milky-way arc (quiet: one step lighter, sparse ordered dither)
    for y in range(40, 200):
        for x in range(W):
            d = math.hypot((x - 90) / 1.25, y - 330)
            band = abs(d - 245)
            if band < 16:
                strength = 1 - band / 16
                if bay(x, y) < strength * .45:
                    cur = get(im, x, y)
                    for idx, name in enumerate(ramp[:-1]):
                        if C[name] == cur: put(im, x, y, ramp[idx + 1]); break
    # wisp clouds (flat strips with stepped ends, like ref 1)
    for (cx, cy, ln, col) in [(20,64,38,'N3'),(150,52,30,'N3'),(40,176,44,'N5'),(140,196,50,'N6'),(70,226,60,'N7'),(10,236,30,'N8'),(150,238,36,'N8')]:
        for x in range(cx - ln // 2, cx + ln // 2):
            put(im, x, cy, col)
        for x in range(cx - ln // 2 + 5, cx + ln // 2 - 7):
            put(im, x, cy - 1, col)
    return im

def layer_bgstars(keepout):
    """Decorative stars: cool, dim, single pixels. Never warm, never cross-shaped near play."""
    im = new()
    n = 0
    while n < 150:
        x, y = random.randrange(W), random.randrange(4, 250)
        if any(math.hypot(x - kx, y - ky) < kr for kx, ky, kr in keepout): continue
        r = random.random()
        c = 'N6' if y > 150 else ('N7' if r < .55 else ('N8' if r < .85 else 'M5'))
        if y > 200: c = 'N8' if r < .7 else 'N9'
        put(im, x, y, c); n += 1
    # a handful of 3px glints in the quiet top corners only
    for (x, y) in [(8, 12), (171, 20), (14, 58), (164, 70)]:
        put(im, x, y, 'M5'); put(im, x-1, y, 'N7'); put(im, x+1, y, 'N7'); put(im, x, y-1, 'N7'); put(im, x, y+1, 'N7')
    return im

# ---------------------------------------------------------------- mountains / forest
def ridge(x, base, amp, seed, sharp=1.0):
    return base - amp * (0.55 * math.sin(x * .045 + seed) + .3 * math.sin(x * .11 + seed * 2.1) + .15 * math.sin(x * .27 + seed * 3.7)) ** 1 * sharp

def layer_land():
    im = new()
    # far range with one snow peak (ref 2)
    for x in range(W):
        top = int(ridge(x, 252, 7, 1.3))
        dxp = x - 126
        peak = 233 + abs(dxp) * (1.25 if dxp < 0 else 1.0) + (1 if (x * 7) % 5 == 0 else 0) + (abs(dxp) > 5) * ((x * 3) % 3 == 0)
        top = int(min(top, peak))
        snow_line = 233 + 6 + int(2 * math.sin(x * 1.7))
        for y in range(top, H):
            c = 'M3'
            if top == int(peak) and y < snow_line:
                c = ('M6' if dxp < -1 and bay(x, y) < .6 else 'M5') if dxp <= 0 else ('M5' if bay(x, y) < .3 else 'M4')
            elif top == int(peak) and y < snow_line + 3 and bay(x, y) < .35: c = 'M4'
            put(im, x, y, c)
        put(im, x, top, 'M4' if x < 126 else 'M3')
    # mid hills
    for x in range(W):
        top = int(ridge(x, 266, 6, 4.2))
        for y in range(top, H): put(im, x, y, 'M2')
        if bay(x, top) < .5: put(im, x, top, 'M3')
    # near forest: stepped pine silhouettes
    for x in range(W):
        for y in range(284, H): put(im, x, y, 'M0')
    random.seed(11)
    x = -4
    while x < W + 4:
        h = random.randint(8, 20); w = h // 2 + 2
        tx = x; base = 286 + random.randint(-1, 2)
        for j in range(h):
            half = int((j / h) * w / 2 + .5)
            half = half - (1 if j % 3 == 0 and j > 2 else 0)  # stepped tiers
            for i in range(-half, half + 1): put(im, tx + i, base - h + j, 'M1' if j < h - 3 or abs(i) > 1 else 'M1')
        # dark foreground line
        x += random.randint(5, 9)
    for x in range(W):
        for y in range(284, H): put(im, x, y, 'M0' if y > 287 else 'M1')
    return im

# ---------------------------------------------------------------- sun
SUN = (90, 40, 17)
def draw_sun(im, cx, cy, r, prog, rays=12, halo=True, t=0):
    # stepped, dithered halo that grows with progress
    if halo:
        h1, h2 = ('C3', 'C4') if prog >= 1 else ('S1', 'S0')
        rings = [(r + 2, r + 6, h1, .45 + .4 * prog), (r + 6, r + 11 + int(6 * prog), h2, .3 + .3 * prog), (r + 11 + int(6 * prog), r + 15 + int(10 * prog), 'C5' if prog >= 1 else 'S0', .08 + .12 * prog)]
        if prog >= 1:
            rings = [(r, r + 4, 'C2', .55), (r + 4, r + 8, 'C3', .3), (r + 8, r + 12, 'C4', .14)]
        for y in range(cy - r - 40, cy + r + 40):
            for x in range(cx - r - 40, cx + r + 40):
                d = math.hypot(x - cx, y - cy)
                for a, b, col, dens in rings:
                    if a <= d < b and bay(x, y) < dens: put(im, x, y, col); break
    # rays = progress ring (clockwise from 12 o'clock)
    lit = round(rays * prog)
    for k in range(rays):
        ang = -math.pi / 2 + k * 2 * math.pi / rays
        on = k < lit
        L = 7 if on else 3
        for s in range(L):
            d = r + 3 + s
            px, py = cx + math.cos(ang) * d, cy + math.sin(ang) * d
            if on: col = 'C0' if s < 2 else ('C1' if s < 4 else ('C2' if s < 6 else 'C3'))
            else: col = 'S2' if s < 2 else 'S1'
            put(im, round(px), round(py), col)
            if on and s < 4:  # 2px thick at root
                put(im, round(px + math.cos(ang + math.pi / 2) * .8), round(py + math.sin(ang + math.pi / 2) * .8), 'C2')
    # disk: dim ember top, pooled light bottom
    level = cy + r - 2 * r * prog
    random.seed(3)
    craters = [(cx - 6, cy - 7, 3), (cx + 5, cy - 3, 2), (cx - 1, cy + 3, 2), (cx + 8, cy - 10, 2), (cx - 9, cy + 1, 2)]
    for y in range(cy - r, cy + r + 1):
        for x in range(cx - r, cx + r + 1):
            d = math.hypot(x - cx, y - cy)
            if d > r + .3: continue
            surf = level + math.sin(x * .55 + t) * 1.2
            if y >= surf:
                q = d / r
                col = 'C3' if q > .9 else ('C2' if q > .7 else 'C1')
                if y < surf + 1.5: col = 'C0'
                elif q < .45 and bay(x, y) < .4: col = 'C0'
            else:
                q = d / r
                col = 'S1' if q > .88 else 'S2'
                if (x - cx) + (y - cy) < -r * .6 and bay(x, y) < .5: col = 'S3'  # rim light top-left
                for (kx, ky, kr) in craters:
                    if math.hypot(x - kx, y - ky) <= kr: col = 'S1'
                # ember glints just above the light pool
                if surf - 3 < y < surf and bay(x, y) < .25: col = 'S4'
            put(im, x, y, col)

# ---------------------------------------------------------------- collectible stars
STAR_S = ["..E..","..Y..","EYCYE","..Y..","..E.."]
STAR_M = [".....E.....",".....O.....","..E..Y..E..","...O.Y.O...","....YCY....","EOYYCCCYYOE","....YCY....","...O.Y.O...","..E..Y..E..",".....O.....",".....E....."]
STAR_L = [".......E.......",".......O.......",".......Y.......","...E...Y...E...","....O.OYO.O....",".....OYYYO.....","....OYCCCYO....","EOYYYCCCCCYYYOE","....OYCCCYO....",".....OYYYO.....","....O.OYO.O....","...E...Y...E...",".......Y.......",".......O.......",".......E......."]
SKEY = {'C': 'C0', 'Y': 'C1', 'O': 'C2', 'E': 'C3'}
STARS = {1: (STAR_S, 2, 4), 2: (STAR_M, 5, 8), 3: (STAR_L, 7, 11)}

def draw_star(im, cx, cy, t, selected=False):
    rows, half, halo = STARS[t]
    # stepped dithered halo: warm mauve, reads as glow without blur
    for y in range(cy - halo, cy + halo + 1):
        for x in range(cx - halo, cx + halo + 1):
            d = math.hypot(x - cx, y - cy)
            if d <= halo * .55 and bay(x, y) < .5: put(im, x, y, 'C4')
            elif d <= halo and bay(x, y) < .22: put(im, x, y, 'C5')
    if selected:
        rr = half + 4
        for a in range(0, 360, 4):
            if (a // 12) % 2: continue
            put(im, round(cx + math.cos(math.radians(a)) * rr), round(cy + math.sin(math.radians(a)) * rr), 'C1')
    sprite(im, cx - half, cy - half, rows, SKEY)

def line(im, a, b, cols, glow=None):
    (x0, y0), (x1, y1) = a, b
    n = max(abs(x1 - x0), abs(y1 - y0))
    for i in range(n + 1):
        x = round(x0 + (x1 - x0) * i / n); y = round(y0 + (y1 - y0) * i / n)
        if glow:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                if (x + y + dx) % 2 == 0: put(im, x + dx, y + dy, glow)
        yield x, y, i

# ---------------------------------------------------------------- planets (packs)
def planet(im, cx, cy, r, ramp, bands=True, ring=None, seed=0):
    """ramp: dark->light 5 names. Light from top-left, stepped + band texture (ref 3)."""
    lx, ly = -.55, -.65
    if ring:  # back half of ring first
        ring_pass(im, cx, cy, r, ring, back=True)
    for y in range(cy - r, cy + r + 1):
        for x in range(cx - r, cx + r + 1):
            dx, dy = (x - cx) / (r + .4), (y - cy) / (r + .4)
            dd = dx * dx + dy * dy
            if dd > 1: continue
            nz = math.sqrt(1 - dd)
            l = dx * lx + dy * ly + nz * .6
            v = (l + .45) / 1.25 * 4
            if bands:
                v += .9 * math.sin((y - cy) * 1.3 + math.sin(x * .7 + seed) * 1.1 + seed) * .55
            v += (bay(x, y) - .5) * .9
            i = max(0, min(4, int(v)))
            if dd > .82: i = min(i, 1)
            put(im, x, y, ramp[i])
    if ring: ring_pass(im, cx, cy, r, ring, back=False)

def ring_pass(im, cx, cy, r, ramp, back):
    a, b = r * 1.9, r * .5
    for t in range(0, 720):
        ang = math.radians(t / 2)
        for k, s in ((0, 1.0), (1, .86)):
            x = cx + math.cos(ang) * a * s; y = cy + math.sin(ang) * b * s - math.cos(ang) * 1.2
            isback = math.sin(ang) < 0
            if isback != back: continue
            if not back or math.hypot(x - cx, y - cy) > r + .5:
                put(im, round(x), round(y), ramp[3] if k == 0 else ramp[2])

# ---------------------------------------------------------------- tiny pixel fonts
F5 = {
'0':[".###.","#...#","#..##","#.#.#","##..#","#...#",".###."],'1':["..#..",".##..","..#..","..#..","..#..","..#..",".###."],
'2':[".###.","#...#","....#","...#.","..#..",".#...","#####"],'3':["####.","....#","....#",".###.","....#","....#","####."],
'4':["...#.","..##.",".#.#.","#..#.","#####","...#.","...#."],'5':["#####","#....","####.","....#","....#","#...#",".###."],
'6':["..##.",".#...","#....","####.","#...#","#...#",".###."],'7':["#####","....#","...#.","..#..",".#...",".#...",".#..."],
'8':[".###.","#...#","#...#",".###.","#...#","#...#",".###."],'9':[".###.","#...#","#...#",".####","....#","...#.",".##.."],
'x':[".....",".....","#...#",".#.#.","..#..",".#.#.","#...#"],'+':[".....","..#..","..#..","#####","..#..","..#..","....."],
'/':["....#","....#","...#.","..#..",".#...","#....","#...."]}
F3 = {
'0':["###","#.#","#.#","#.#","###"],'1':[".#.","##.",".#.",".#.","###"],'2':["###","..#","###","#..","###"],'3':["###","..#",".##","..#","###"],
'4':["#.#","#.#","###","..#","..#"],'5':["###","#..","###","..#","###"],'6':["###","#..","###","#.#","###"],'7':["###","..#",".#.",".#.",".#."],
'8':["###","#.#","###","#.#","###"],'9':["###","#.#","###","..#","###"],'+':["...",".#.","###",".#.","..."],'/':["..#","..#",".#.","#..","#.."],
'x':["...","#.#",".#.","#.#","..."]}
def text(im, x, y, s, col, font=F5, shadow='N0'):
    for ch in s:
        g = font[ch]
        if shadow: sprite(im, x + 1, y + 1, g, {'#': shadow})
        sprite(im, x, y, g, {'#': col})
        x += len(g[0]) + 1
    return x

DUST_L = ["....#....","...#D#...","..#DDo#..",".#DDoon#.","#DDoonnn#",".#Doonn#.","..#onn#..","...#n#...","....#...."]
DUST_S = ["..D..",".DDo.","DDoon",".oon.","..n.."]
DKEY = {'#': 'N0', 'D': 'D0', 'o': 'N8', 'n': 'N7'}
SUNI = [".C.","CCC",".C."]

# ================================================================= compose
def build():
    L = {}
    L['01_sky'] = layer_sky()

    seq = [(38, 150, 1), (80, 116, 2), (126, 158, 3)]           # linked small-medium-big
    loose = [(146, 96, 1), (24, 98, 2), (104, 84, 1), (28, 208, 3), (152, 212, 2), (98, 204, 1), (66, 178, 1), (138, 118, 2)]
    keep = [(x, y, 16) for x, y, _ in seq + loose] + [(SUN[0], SUN[1], 34)]
    L['02_bg_stars'] = layer_bgstars(keep)
    L['03_land'] = layer_land()

    sun = new(); draw_sun(sun, *SUN, prog=.42)
    for (x, y) in [(76, 22), (104, 18), (70, 50), (110, 56), (96, 66)]:  # embers
        put(sun, x, y, 'C3' if (x + y) % 2 else 'S4')
    L['04_sun'] = sun

    # aim guide + link line (fx layer under stars)
    fx = new()
    for x, y, i in line(fx, (90, 280), (90, 262), None):
        if i % 4 == 0: put(fx, x, y, 'C2')
    for a, b in zip(seq, seq[1:]):
        for x, y, i in line(fx, a[:2], b[:2], None, glow='C5'):
            put(fx, x, y, 'C0' if i % 5 == 0 else 'C1')
    random.seed(5)
    for sx, sy, _ in seq:  # scattered particles
        for _ in range(7):
            a = random.random() * 6.28; d = random.uniform(9, 17)
            put(fx, round(sx + math.cos(a) * d), round(sy + math.sin(a) * d), random.choice(['C1', 'C2', 'C3', 'C0']))
    L['05_link_fx'] = fx

    st = new()
    for x, y, t in loose: draw_star(st, x, y, t)
    for x, y, t in seq: draw_star(st, x, y, t, selected=True)
    L['06_stars'] = st

    # launcher + packs
    pk = new()
    # slingshot: a crescent-moon fork (celestial, not wooden)
    fork = [(90, 318), (90, 312), (90, 306)]
    for y in range(300, 318):
        put(pk, 89, y, 'M3'); put(pk, 90, y, 'M4'); put(pk, 91, y, 'M2')
    for i in range(0, 16):
        # two curved prongs
        for side in (-1, 1):
            x = 90 + side * (2 + i * .9 - (i * i) * .012); y = 301 - i * 1.05
            put(pk, round(x), round(y), 'M4'); put(pk, round(x) + side, round(y), 'M3'); put(pk, round(x) - side, round(y), 'M5' if i > 10 else 'M3')
    for side in (-1, 1):  # star gems on tips
        gx, gy = 90 + side * 14, 284
        sprite(pk, gx - 1, gy - 1, SUNI, {'C': 'C1'}); put(pk, gx, gy, 'C0')
    # band behind planet
    for x in range(77, 104):
        y = 286 + int(2.2 * (1 - ((x - 90) / 13) ** 2))
        put(pk, x, y, 'C2' if x % 2 else 'C3')
    planet(pk, 90, 287, 8, ['B0', 'B1', 'B2', 'B3', 'B4'], seed=1.7)
    L['07_launcher'] = pk

    ui = new()
    # sun progress text
    text(ui, 76, 70, '42/100', 'C1', F3)
    # dust counter (left)
    sprite(ui, 10, 294, DUST_L, DKEY)
    text(ui, 22, 295, '12', 'D0', F5)
    # pack inventory (right): blue x2 / red x1, prices under
    planet(ui, 128, 293, 6, ['B0', 'B1', 'B2', 'B3', 'B4'], seed=0.4)
    planet(ui, 158, 293, 6, ['R0', 'R1', 'R2', 'R3', 'R4'], seed=2.2, ring=['R0', 'R1', 'C3', 'R4'])
    text(ui, 136, 298, 'x2', 'M6', F3); text(ui, 166, 298, 'x1', 'M6', F3)
    sprite(ui, 123, 306, DUST_S, {'D': 'D0', 'o': 'N8', 'n': 'N7'}); text(ui, 130, 306, '4', 'D0', F3)
    sprite(ui, 153, 306, DUST_S, {'D': 'D0', 'o': 'N8', 'n': 'N7'}); text(ui, 160, 306, '7', 'D0', F3)
    # reward preview plaque above the last linked star
    px, py, pw, ph = 104, 130, 46, 11
    for y in range(py, py + ph):
        for x in range(px, px + pw):
            edge = x in (px, px + pw - 1) or y in (py, py + ph - 1)
            corner = (x in (px, px + pw - 1)) and (y in (py, py + ph - 1))
            if corner: continue
            put(ui, x, y, 'N6' if edge else 'N0')
    put(ui, 124, py + ph, 'N6'); put(ui, 125, py + ph + 1, 'N6'); put(ui, 125, py + ph, 'N0'); put(ui, 126, py + ph, 'N6')
    xx = text(ui, px + 3, py + 3, '+3', 'D0', F3, shadow=None)
    sprite(ui, xx, py + 3, DUST_S, {'D': 'D0', 'o': 'N8', 'n': 'N7'})
    xx = text(ui, xx + 8, py + 3, '+25', 'C1', F3, shadow=None)
    sprite(ui, xx, py + 4, SUNI, {'C': 'C1'}); put(ui, xx + 1, py + 4, 'C0')
    L['08_ui'] = ui

    os.makedirs('layers', exist_ok=True)
    comp = new()
    for k in sorted(L):
        L[k].save(f'layers/{k}.png')
        comp = Image.alpha_composite(comp, L[k])
    comp.save('mockup_1x.png')
    comp.resize((W * SCALE, H * SCALE), Image.NEAREST).save('mockup_4x.png')
    # gameplay-only preview (no UI text) to check the art stands on its own
    return L, comp

def palette_files():
    with open('stellar_sun.gpl', 'w') as f:
        f.write('GIMP Palette\nName: Stellar Sun\nColumns: 8\n#\n')
        for k, v in PAL.items():
            r, g, b, _ = hx(v); f.write(f'{r:3d} {g:3d} {b:3d}\t{k}\n')
    with open('stellar_sun.hex', 'w') as f:
        f.write('\n'.join(v.lstrip('#').lower() for v in PAL.values()) + '\n')

def sheet():
    """Asset breakdown sheet: palette ramps + sprites at 8x with labels."""
    Z = 6
    sh = Image.new('RGBA', (164, 150), C['N1'])
    groups = [('Sky', ['N0','N1','N2','N3','N4','N5','N6','N7','N8','N9','N10']), ('Land', ['M0','M1','M2','M3','M4','M5','M6']),
              ('Starlight', ['C0','C1','C2','C3','C4','C5']), ('Dim Sun', ['S0','S1','S2','S3','S4']),
              ('Blue', ['B0','B1','B2','B3','B4']), ('Red', ['R0','R1','R2','R3','R4']), ('Dust', ['N7','N8','D0'])]
    d = ImageDraw.Draw(sh)
    y = 3
    for name, keys in groups:
        for i, k in enumerate(keys):
            d.rectangle([34 + i * 9, y, 34 + i * 9 + 7, y + 6], fill=C[k])
        y += 9
    # sprites row
    global W, H
    tmp = Image.new('RGBA', (164, 150), (0, 0, 0, 0))
    oW, oH = W, H; W, H = 164, 150
    draw_star(tmp, 10, 84, 1); draw_star(tmp, 28, 84, 2); draw_star(tmp, 52, 84, 3); draw_star(tmp, 80, 84, 3, selected=True)
    planet(tmp, 104, 84, 8, ['B0','B1','B2','B3','B4'], seed=1.7)
    planet(tmp, 126, 84, 6, ['R0','R1','R2','R3','R4'], seed=2.2, ring=['R0','R1','C3','R4'])
    for i, p in enumerate((0, .42, 1.0)):
        draw_sun(tmp, 26 + i * 54, 122, 12, p, halo=True)
    sprite(tmp, 146, 80, DUST_L, DKEY)
    W, H = oW, oH
    sh = Image.alpha_composite(sh, tmp)
    big = sh.resize((164 * Z, 150 * Z), Image.NEAREST)
    d = ImageDraw.Draw(big)
    try: font = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf', 18)
    except Exception: font = ImageFont.load_default()
    y = 3
    for name, keys in groups:
        d.text((6, y * Z + 4), name, fill=(237, 230, 211), font=font); y += 9
    labels = [(4, 96, 'small'), (20, 96, 'medium'), (44, 96, 'big'), (70, 96, 'linked'), (96, 96, 'blue pack'), (116, 96, 'red pack'), (144, 96, 'dust'),
              (14, 141, 'Sun 0%'), (66, 141, 'Sun 42%'), (118, 141, 'Sun 100%')]
    for x, yy, s in labels: d.text((x * Z, yy * Z), s, fill=(237, 230, 211), font=font)
    big.save('asset_sheet.png')

if __name__ == '__main__':
    build(); palette_files(); sheet(); print('ok')
