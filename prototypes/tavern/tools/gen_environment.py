"""
Original environment art: tiles, restaurant fittings, town and forest.

Tiles are 32x32 and authored as variant sets (a floor is never one repeated
plank) because a visible grid is the fastest way to make a hand-made world
look machine-made. Props are individual sprites with their own origin so the
scenes can place and y-sort them.
"""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixelforge as pf
import palette as P

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..",
                   "assets", "environment")
T = 32


def rel(p):
    root = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
    return "res://" + os.path.relpath(os.path.abspath(p), root).replace("\\", "/")


def noise_speck(sp, mask, col, density=0.06, seed=0, a=255):
    """Scatter single-pixel grain inside a mask. Texture at the pixel level is
    what stops big flat props from looking like coloured rectangles."""
    rng = np.random.RandomState(seed)
    ys, xs = np.nonzero(mask)
    for y, x in zip(ys, xs):
        if rng.rand() < density:
            sp.px(int(x), int(y), col, a)


# ================================================================ TILES =====
def tile_floor_plank(seed=0):
    """Restaurant floor: warm oak boards.

    Two 16px boards per tile, not four 8px ones. Narrow boards with dark gaps
    every 8px read as brick courses once the floor is tiled across a room -
    which is exactly what the first build looked like. Wide boards with a low
    contrast seam read as a wooden floor.
    """
    sp = pf.Sprite(T, T)
    rng = np.random.RandomState(seed)
    base = P.FLOOR_A
    cols = pf.ramp(base, spread=.13)
    sp.rect(0, 0, T, T, cols[2])
    # ONE tone for every variant. Any per-tile tone shift produces a visible
    # checkerboard which, crossed with the 16px board seams, is read as
    # brickwork - the single most persistent bug in this tileset. Variants
    # differ only in grain, knots and joints.
    tone = base
    tcols = pf.ramp(tone, spread=.13)
    sp.rect(0, 0, T, T, tcols[2])
    for row in range(2):
        y = row * 16
        # board seam: one soft dark line, one light catch
        sp.line(0, y, T - 1, y, pf.mix(tone, P.INK, .11))
        sp.line(0, y + 1, T - 1, y + 1, pf.mix(tone, P.LAMP, .06))
        # Butt joints only on ONE of the four variants. A joint in every tile
        # produces a regular staggered grid - i.e. brickwork.
        if seed == 3 and row == 1:
            off = 11
            sp.line(off, y + 2, off, y + 15, pf.mix(tone, P.INK, .20))
            sp.line(off + 1, y + 2, off + 1, y + 15, pf.mix(tone, P.LAMP, .05))
        for _ in range(5):
            gy = y + 3 + rng.randint(0, 12)
            gx = rng.randint(0, 18)
            sp.line(gx, gy, gx + rng.randint(10, 22), gy,
                    pf.mix(tone, P.INK, .07))
        if seed == 1 and row == 0:
            kx, ky = 22, y + 8
            sp.mask_fill(pf.m_ellipse(T, T, kx, ky, 2.2, 1.4),
                         pf.mix(tone, P.INK, .16))
            sp.mask_fill(pf.m_ellipse(T, T, kx, ky, 1.1, 0.7),
                         pf.mix(tone, P.INK, .26))
    noise_speck(sp, sp.alpha(), pf.mix(tone, P.INK, .09), .03, seed)
    return sp


def tile_floor_tile(seed=0):
    """Kitchen floor: glazed terracotta squares, worn unevenly.

    The grout is deliberately low contrast and the squares vary in tone. An
    even grid of identical squares with dark grout reads as graph paper.
    """
    sp = pf.Sprite(T, T)
    rng = np.random.RandomState(seed + 17)
    base = "#a8613f"
    cols = pf.ramp(base, spread=.14)
    sp.rect(0, 0, T, T, pf.mix(base, P.INK, .30))       # grout
    for j in range(2):
        for i in range(2):
            x, y = i * 16, j * 16
            tone = pf.mix(base, P.LAMP if rng.rand() < .5 else P.INK,
                          rng.uniform(0.03, 0.14))
            m = pf.m_rect(T, T, x + 1, y + 1, 14, 14)
            pf.render_solid(sp, m, pf.ramp(tone, spread=.13), bulge=.35,
                            flat=.9, ambient=.56, rim=False, contrast=1.0)
            # glaze catch in the upper-left corner, matching the world light
            sp.line(x + 2, y + 2, x + 7, y + 2, pf.mix(tone, P.CHALK, .26))
            sp.px(x + 2, y + 3, pf.mix(tone, P.CHALK, .18))
            if rng.rand() < .25:                         # chip
                sp.px(x + 13, y + 13, pf.mix(base, P.INK, .35))
    noise_speck(sp, sp.alpha(), pf.mix(base, P.INK, .16), .04, seed + 4)
    return sp


def tile_wall(seed=0):
    """Papered wall. Stardew interiors use real wallpaper - vertical stripes
    with a small repeated motif - not blank plaster. A flat cream slab across
    the top quarter of the screen is dead space."""
    sp = pf.Sprite(T, T)
    base = P.WALL_PLASTER
    cols = pf.ramp(base, spread=.13)
    sp.rect(0, 0, T, T, cols[2])
    # vertical stripes
    for x in range(0, T, 8):
        sp.rect(x, 0, 3, T, cols[3])
        sp.line(x + 3, 0, x + 3, T - 1, pf.mix(base, P.WALL_TRIM, .16))
    # a small diamond motif on alternating stripes, offset per variant
    off = (seed % 2) * 8
    for y in range(2 + off, T, 16):
        for x in range(5, T, 16):
            c = pf.mix(base, P.WALL_TRIM, .30)
            sp.px(x, y - 1, c)
            sp.line(x - 1, y, x + 1, y, c)
            sp.px(x, y + 1, c)
    return sp


def tile_wainscot():
    sp = pf.Sprite(T, T)
    cols = pf.ramp(P.WALL_TRIM, spread=.20)
    sp.rect(0, 0, T, T, cols[2])
    # vertical panelling
    for i in range(0, T, 8):
        m = pf.m_rect(T, T, i + 1, 3, 6, T - 6)
        pf.render_solid(sp, m, cols, bulge=.5, flat=.7, ambient=.44, rim=False)
    # top rail catches the lamplight
    sp.rect(0, 0, T, 3, pf.mix(P.WALL_TRIM, P.LAMP, .30))
    sp.line(0, 3, T - 1, 3, pf.mix(P.WALL_TRIM, P.INK, .40))
    return sp


def tile_grass(seed=0):
    sp = pf.Sprite(T, T)
    cols = pf.ramp(P.GRASS, spread=.20)
    sp.rect(0, 0, T, T, cols[2])
    rng = np.random.RandomState(seed + 3)
    # Blades, not speckle. A field of single pixels averages out to flat felt
    # at 32px tiles; short 2-3px strokes keep texture at viewing distance.
    for _ in range(34):
        x, y = rng.randint(0, T), rng.randint(0, T)
        c = cols[rng.choice([1, 1, 3])]
        h = rng.randint(2, 4)
        for k in range(h):
            sp.px(x + (1 if k == h - 1 and rng.rand() < .5 else 0), y - k, c)
    for _ in range(6):
        x, y = rng.randint(0, T), rng.randint(0, T)
        sp.px(x, y, cols[4])
        sp.px(x, y - 1, cols[4])
    return sp


def tile_path(seed=0):
    sp = pf.Sprite(T, T)
    cols = pf.ramp("#9c8468", spread=.18)
    sp.rect(0, 0, T, T, cols[2])
    rng = np.random.RandomState(seed + 9)
    for _ in range(6):
        cx, cy = rng.randint(2, 30), rng.randint(2, 30)
        r = rng.uniform(2.0, 4.2)
        m = pf.m_blob(T, T, cx, cy, r, 3, seed=int(rng.randint(99)))
        pf.render_solid(sp, m, pf.ramp(P.STONE, spread=.16), bulge=.6,
                        flat=.5, ambient=.46, rim=False)
    noise_speck(sp, sp.alpha(), pf.mix("#9c8468", P.INK, .25), .07, seed)
    return sp


def tile_cobble(seed=0):
    sp = pf.Sprite(T, T)
    cols = pf.ramp(P.STONE, spread=.18)
    sp.rect(0, 0, T, T, pf.mix(P.STONE, P.INK, .45))
    rng = np.random.RandomState(seed + 21)
    for j in range(4):
        for i in range(4):
            off = 4 if j % 2 else 0
            x, y = i * 8 + off, j * 8
            m = pf.m_round_rect(T, T, x + 1, y + 1, 6, 6, 2)
            c = pf.ramp(pf.mix(P.STONE, P.STONE_L, rng.rand() * .5), spread=.16)
            pf.render_solid(sp, m, c, bulge=.7, flat=.4, ambient=.46, rim=False)
    return sp


def tile_water(frame=0):
    sp = pf.Sprite(T, T)
    cols = pf.ramp(P.WATER, spread=.22)
    sp.rect(0, 0, T, T, cols[1])
    for y in range(T):
        for x in range(T):
            w = math.sin((x + frame * 4) * .38 + y * .22) + \
                math.sin((y - frame * 3) * .3) * .6
            sp.px(x, y, cols[2 if w > .2 else 1])
    for i in range(5):
        x = int((i * 7 + frame * 3) % T)
        y = int((i * 11 + math.sin(frame + i) * 3) % T)
        sp.line(x, y, x + 3, y, cols[4])
    return sp


def tile_dirt(seed=0):
    """Worn ground. Deliberately close in value to the grass - a dark brown
    patch surrounded by bright green reads as a hole in the world, not as a
    trodden path."""
    sp = pf.Sprite(T, T)
    base = "#8a8352"
    cols = pf.ramp(base, spread=.15)
    sp.rect(0, 0, T, T, cols[2])
    rng = np.random.RandomState(seed + 31)
    # surviving tufts of grass keep the patch tied to the field around it
    for _ in range(14):
        x, y = rng.randint(0, T), rng.randint(0, T)
        c = pf.mix(P.GRASS, base, 0.35)
        sp.px(x, y, c)
        sp.px(x, y - 1, c)
    noise_speck(sp, sp.alpha(), cols[1], .14, seed)
    noise_speck(sp, sp.alpha(), cols[3], .10, seed + 1)
    return sp


# ====================================================== RESTAURANT PROPS ====
def prop_stove():
    """Cast-iron range: the single most important prop in the game."""
    sp = pf.Sprite(56, 56)
    iron = pf.ramp("#4a4450", spread=.22)
    body = pf.m_round_rect(56, 56, 4, 16, 48, 38, 3)
    pf.render_solid(sp, body, iron, bulge=.7, flat=.6, ambient=.32)
    # cooktop slab
    top = pf.m_round_rect(56, 56, 2, 12, 52, 8, 2)
    pf.render_solid(sp, top, pf.ramp("#5c5560", spread=.20), bulge=.6, flat=.6,
                    ambient=.40)
    # burner rings
    for i in range(2):
        cxx = 16 + i * 24
        pf.render_solid(sp, pf.m_ellipse(56, 56, cxx, 15, 7, 3), iron,
                        bulge=.5, flat=.6, ambient=.26, rim=False)
        pf.render_solid(sp, pf.m_ellipse(56, 56, cxx, 15, 4.4, 1.8),
                        pf.ramp(P.COAL, spread=.16), bulge=.4, flat=.7,
                        ambient=.30, rim=False)
    # oven door with a fire-lit window
    door = pf.m_round_rect(56, 56, 9, 26, 38, 22, 2)
    pf.render_solid(sp, door, pf.ramp("#3e3946", spread=.20), bulge=.5,
                    flat=.7, ambient=.34)
    win = pf.m_round_rect(56, 56, 14, 30, 28, 13, 2)
    pf.render_solid(sp, win, pf.ramp(P.FLAME, spread=.26), bulge=.4, flat=.7,
                    ambient=.55, rim=False)
    for i in range(9):
        fx = 16 + i * 3
        fh = 4 + int(abs(math.sin(i * 1.4)) * 4)
        sp.line(fx, 42, fx, 42 - fh, pf.mix(P.FLAME_CORE, P.LAMP_HOT, .3))
    pf.glow(sp, 28, 38, 16, pf.hex2rgb(P.EMBER), .40)
    sp.line(12, 29, 44, 29, pf.mix("#5c5560", P.LAMP, .5))   # handle
    sp.line(12, 30, 44, 30, pf.mix("#5c5560", P.INK, .3))
    # brass knobs
    for i in range(3):
        pf.render_solid(sp, pf.m_ellipse(56, 56, 14 + i * 14, 51, 3, 3),
                        pf.ramp(P.UI_GOLD, spread=.20), bulge=1.0, ambient=.40)
    # chimney pipe
    pf.render_solid(sp, pf.m_rect(56, 56, 44, 0, 7, 13), iron, bulge=.6,
                    flat=.4, ambient=.30)
    pf.outline(sp)
    return sp


def prop_counter(w=64):
    """Prep counter: butcher block over painted panels."""
    sp = pf.Sprite(w, 40)
    wood = pf.ramp(P.OAK, spread=.18)
    body = pf.m_round_rect(w, 40, 2, 10, w - 4, 28, 2)
    pf.render_solid(sp, body, pf.ramp(P.WALL_TRIM, spread=.18), bulge=.6,
                    flat=.7, ambient=.36)
    top = pf.m_round_rect(w, 40, 0, 4, w, 9, 2)
    pf.render_solid(sp, top, wood, bulge=.6, flat=.6, ambient=.44)
    for i in range(0, w, 6):
        sp.line(i, 6, i, 11, pf.mix(P.OAK, P.INK, .16))
    sp.line(0, 13, w - 1, 13, pf.mix(P.OAK, P.INK, .45))
    # panel doors + handles
    for i in range(max(1, (w - 8) // 26)):
        x = 6 + i * 26
        m = pf.m_round_rect(w, 40, x, 17, 20, 16, 2)
        pf.render_solid(sp, m, pf.ramp(pf.mix(P.WALL_TRIM, P.INK, .12),
                                       spread=.16),
                        bulge=.4, flat=.8, ambient=.40, rim=False)
        sp.line(x + 14, 24, x + 17, 24, pf.hex2rgb(P.UI_GOLD))
    pf.outline(sp)
    return sp


def prop_fridge():
    """Ice cabinet: oak case, frosted iron door, a faint chill haze."""
    sp = pf.Sprite(36, 60)
    pf.render_solid(sp, pf.m_round_rect(36, 60, 2, 4, 32, 54, 3),
                    pf.ramp(P.OAK_DARK, spread=.18), bulge=.6, flat=.65,
                    ambient=.34)
    door = pf.m_round_rect(36, 60, 5, 8, 26, 46, 2)
    pf.render_solid(sp, door, pf.ramp("#9fc4cf", spread=.18), bulge=.5,
                    flat=.75, ambient=.46)
    sp.line(5, 32, 30, 32, pf.mix("#9fc4cf", P.INK, .35))
    for i in range(3):
        pf.render_solid(sp, pf.m_ellipse(36, 60, 10 + i * 6, 20 + i * 9, 2.4, 2.4),
                        pf.ramp(P.CHALK, spread=.12), bulge=.8, ambient=.6,
                        rim=False)     # frost patches
    sp.line(27, 14, 27, 24, pf.hex2rgb(P.UI_GOLD))
    sp.line(27, 38, 27, 48, pf.hex2rgb(P.UI_GOLD))
    pf.outline(sp)
    return sp


def prop_shelf(w=52):
    sp = pf.Sprite(w, 34)
    wood = pf.ramp(P.OAK, spread=.18)
    for j in range(2):
        y = j * 16 + 2
        pf.render_solid(sp, pf.m_rect(w, 34, 0, y + 10, w, 4), wood,
                        bulge=.5, flat=.7, ambient=.38)
    # jars and bottles on the shelves
    rng = np.random.RandomState(5)
    tints = [P.MAGIC, P.LEAF, P.SOUP_BASE, P.WATER, P.BERRY, P.CHEESE]
    for j in range(2):
        y = j * 16 + 12
        x = 3
        while x < w - 8:
            t = tints[rng.randint(len(tints))]
            hh = rng.randint(6, 10)
            m = pf.m_round_rect(w, 34, x, y - hh, 6, hh, 2)
            pf.render_solid(sp, m, pf.ramp(t, spread=.20), bulge=.8, flat=.3,
                            ambient=.38)
            sp.px(x + 1, y - hh + 2, pf.mix(t, P.CHALK, .55))
            sp.line(x + 1, y - hh - 1, x + 4, y - hh - 1, pf.hex2rgb(P.OAK_DARK))
            x += rng.randint(8, 12)
    pf.outline(sp)
    return sp


def prop_table():
    """Round dining table. Y-sorted; customers sit behind it."""
    sp = pf.Sprite(52, 40)
    wood = pf.ramp(P.OAK_WARM, spread=.18)
    pf.drop_shadow(sp, np.zeros((40, 52), bool), 26, 36, 17, 4)
    pf.render_solid(sp, pf.m_rect(52, 40, 23, 18, 6, 16),
                    pf.ramp(P.OAK_DARK, spread=.18), bulge=.7, ambient=.30)
    pf.render_solid(sp, pf.m_ellipse(52, 40, 26, 34, 15, 4.0),
                    pf.ramp(P.OAK_DARK, spread=.16), bulge=.5, ambient=.30)
    top = pf.m_ellipse(52, 40, 26, 15, 25, 11)
    pf.render_solid(sp, top, wood, bulge=.5, flat=.55, ambient=.46)
    # cloth runner - a warm accent so tables are not all brown
    cloth = pf.m_ellipse(52, 40, 26, 15, 18, 7.5)
    pf.render_solid(sp, cloth, pf.ramp("#c25a52", spread=.18), bulge=.4,
                    flat=.6, ambient=.44, rim=False)
    for i in range(6):
        sp.px(11 + i * 6, 22, pf.mix("#c25a52", P.CHALK, .5))
    sp.line(4, 17, 48, 17, pf.mix(P.OAK_WARM, P.INK, .30))
    pf.outline(sp)
    return sp


def prop_chair(facing=1):
    sp = pf.Sprite(24, 36)
    wood = pf.ramp(P.OAK, spread=.18)
    pf.drop_shadow(sp, np.zeros((36, 24), bool), 12, 33, 8, 3)
    back = pf.m_round_rect(24, 36, 5, 2, 14, 16, 2)
    pf.render_solid(sp, back, wood, bulge=.6, flat=.6, ambient=.38)
    sp.mask_fill(pf.m_rect(24, 36, 8, 5, 8, 10), pf.mix(P.OAK, P.INK, .35))
    for i in range(3):
        sp.line(9 + i * 3, 5, 9 + i * 3, 14, pf.mix(P.OAK, P.LAMP, .18))
    seat = pf.m_round_rect(24, 36, 3, 18, 18, 6, 2)
    pf.render_solid(sp, seat, pf.ramp("#b3564c", spread=.18), bulge=.6,
                    flat=.5, ambient=.42)
    for x in (5, 17):
        pf.render_solid(sp, pf.m_rect(24, 36, x, 24, 3, 10), wood,
                        bulge=.6, ambient=.32)
    pf.outline(sp)
    return sp


def prop_lamp(lit=True):
    """Hanging lamp. The restaurant's warmth comes from these."""
    sp = pf.Sprite(28, 40)
    sp.line(14, 0, 14, 9, pf.mix(P.OAK_DARK, P.INK, .3))
    shade = pf.m_poly(28, 40, [(6, 20), (22, 20), (18, 10), (10, 10)])
    pf.render_solid(sp, shade, pf.ramp("#b8543f", spread=.20), bulge=.6,
                    flat=.5, ambient=.40)
    sp.line(6, 20, 22, 20, pf.mix("#b8543f", P.INK, .40))
    if lit:
        bulb = pf.m_ellipse(28, 40, 14, 23, 3.4, 3.6)
        pf.render_solid(sp, bulb, pf.ramp(P.LAMP_HOT, spread=.14), bulge=1.0,
                        ambient=.72, rim=False)
        pf.glow(sp, 14, 23, 13, pf.hex2rgb(P.LAMP), .55)
    else:
        pf.render_solid(sp, pf.m_ellipse(28, 40, 14, 23, 3.4, 3.6),
                        pf.ramp(P.STONE, spread=.16), bulge=1.0, ambient=.34)
    pf.outline(sp)
    # The cast light goes on AFTER the outline pass, otherwise the outline
    # traces the soft cone and it reads as a solid glass triangle. The real
    # pool of light is a Light2D at runtime; this is just the visible shaft.
    if lit:
        for y in range(25, 39):
            spread = int((y - 25) * .85)
            for x in range(14 - spread, 14 + spread + 1):
                sp.px(x, y, pf.hex2rgb(P.LAMP), max(4, int(30 - (y - 25) * 2)))
    return sp


def prop_plant():
    sp = pf.Sprite(28, 40)
    pf.drop_shadow(sp, np.zeros((40, 28), bool), 14, 37, 9, 3)
    pot = pf.m_poly(28, 40, [(7, 24), (21, 24), (19, 38), (9, 38)])
    pf.render_solid(sp, pot, pf.ramp("#b06a44", spread=.20), bulge=.7,
                    flat=.4, ambient=.40)
    sp.rect(6, 22, 16, 3, pf.mix("#b06a44", P.LAMP, .25))
    rng = np.random.RandomState(12)
    for i in range(7):
        a = -math.pi / 2 + (i - 3) * .38
        ln = rng.uniform(11, 17)
        ex, ey = 14 + math.cos(a) * ln, 24 + math.sin(a) * ln
        m = pf.m_capsule(28, 40, 14, 24, ex, ey, 2.6)
        c = P.LEAF if i % 2 else P.LEAF_DEEP
        pf.render_solid(sp, m, pf.ramp(c, spread=.20), bulge=.8, ambient=.34,
                        rim=False)
        sp.line(14, 24, ex, ey, pf.mix(c, P.INK, .30))
    pf.outline(sp)
    return sp


def prop_painting():
    """Wall art of a monster feast - in-world decoration with its own joke."""
    sp = pf.Sprite(36, 28)
    frame = pf.m_round_rect(36, 28, 0, 0, 36, 28, 2)
    pf.render_solid(sp, frame, pf.ramp(P.UI_GOLD, spread=.20), bulge=.5,
                    flat=.6, ambient=.40)
    inner = pf.m_rect(36, 28, 3, 3, 30, 22)
    pf.render_solid(sp, inner, pf.ramp(P.DUSK, spread=.18), bulge=.3, flat=.9,
                    ambient=.50, rim=False)
    pf.render_solid(sp, pf.m_ellipse(36, 28, 26, 9, 5, 5),
                    pf.ramp(P.MOON, spread=.14), bulge=.9, ambient=.60, rim=False)
    for i in range(4):
        h = 6 + i * 2
        pf.render_solid(sp, pf.m_poly(36, 28, [(5 + i * 7, 25),
                                               (9 + i * 7, 25 - h),
                                               (12 + i * 7, 25)]),
                        pf.ramp(P.LEAF_DEEP, spread=.16), bulge=.6,
                        ambient=.34, rim=False)
    pf.outline(sp)
    return sp


def prop_window(night=False):
    sp = pf.Sprite(40, 44)
    fr = pf.m_round_rect(40, 44, 0, 0, 40, 44, 2)
    pf.render_solid(sp, fr, pf.ramp(P.WALL_TRIM, spread=.18), bulge=.5,
                    flat=.7, ambient=.38)
    glass = pf.m_rect(40, 44, 4, 4, 32, 36)
    sky = P.NIGHT if night else "#7fb4d8"
    pf.render_solid(sp, glass, pf.ramp(sky, spread=.16), bulge=.3, flat=.9,
                    ambient=.56, rim=False)
    if night:
        rng = np.random.RandomState(2)
        for _ in range(14):
            sp.px(rng.randint(5, 35), rng.randint(5, 30), pf.hex2rgb(P.CHALK))
        pf.render_solid(sp, pf.m_ellipse(40, 44, 27, 12, 4.5, 4.5),
                        pf.ramp(P.MOON, spread=.12), bulge=.9, ambient=.66,
                        rim=False)
    else:
        for i in range(3):
            m = pf.m_blob(40, 44, 10 + i * 10, 12 + (i % 2) * 6, 5, 3, seed=i)
            m &= glass
            pf.render_solid(sp, m, pf.ramp(P.CHALK, spread=.10), bulge=.5,
                            ambient=.70, rim=False)
    for i in range(1, 2):
        sp.rect(4 + i * 15, 4, 3, 36, pf.hex2rgb(P.WALL_TRIM))
    sp.rect(4, 20, 32, 3, pf.hex2rgb(P.WALL_TRIM))
    # sill
    pf.render_solid(sp, pf.m_rect(40, 44, 0, 40, 40, 4),
                    pf.ramp(P.OAK, spread=.16), bulge=.5, flat=.7, ambient=.42)
    pf.outline(sp)
    return sp


def prop_door():
    sp = pf.Sprite(40, 60)
    fr = pf.m_round_rect(40, 60, 0, 0, 40, 60, 2)
    pf.render_solid(sp, fr, pf.ramp(P.WALL_TRIM, spread=.18), bulge=.5,
                    flat=.75, ambient=.36)
    leaf = pf.m_rect(40, 60, 4, 4, 32, 56)
    pf.render_solid(sp, leaf, pf.ramp(P.OAK_DARK, spread=.20), bulge=.5,
                    flat=.7, ambient=.36)
    for i in range(2):
        m = pf.m_round_rect(40, 60, 8, 8 + i * 24, 24, 20, 2)
        pf.render_solid(sp, m, pf.ramp(P.OAK, spread=.18), bulge=.4, flat=.8,
                        ambient=.42, rim=False)
    pf.render_solid(sp, pf.m_ellipse(40, 60, 31, 32, 2.4, 2.4),
                    pf.ramp(P.UI_GOLD, spread=.18), bulge=1.0, ambient=.44)
    # the doorbell that announces every customer
    pf.render_solid(sp, pf.m_ellipse(40, 60, 20, 3, 3, 2.6),
                    pf.ramp(P.UI_GOLD, spread=.20), bulge=.9, ambient=.44)
    pf.outline(sp)
    return sp


def prop_sign():
    """Hanging shop sign. Baked lettering, painted board."""
    sp = pf.Sprite(76, 34)
    sp.line(6, 0, 6, 5, pf.mix(P.OAK_DARK, P.INK, .3))
    sp.line(69, 0, 69, 5, pf.mix(P.OAK_DARK, P.INK, .3))
    board = pf.m_round_rect(76, 34, 2, 5, 72, 26, 3)
    pf.render_solid(sp, board, pf.ramp(P.OAK_WARM, spread=.18), bulge=.5,
                    flat=.7, ambient=.42)
    sp.line(4, 8, 71, 8, pf.mix(P.OAK_WARM, P.LAMP, .30))
    pf.text(sp, "MONSTER", 12, 11, pf.hex2rgb(P.PAPER),
            shadow=pf.hex2rgb(P.OAK_DARK))
    pf.text(sp, "KITCHEN", 12, 21, pf.hex2rgb(P.LAMP),
            shadow=pf.hex2rgb(P.OAK_DARK))
    pf.outline(sp)
    return sp


def prop_pot():
    sp = pf.Sprite(28, 24)
    iron = pf.ramp("#4a4450", spread=.22)
    body = pf.m_ellipse(28, 24, 14, 15, 11, 8)
    pf.render_solid(sp, body, iron, bulge=.8, flat=.3, ambient=.32)
    rim = pf.m_ellipse(28, 24, 14, 8, 11, 3)
    pf.render_solid(sp, rim, pf.ramp("#5c5560", spread=.20), bulge=.6,
                    ambient=.44)
    pf.render_solid(sp, pf.m_ellipse(28, 24, 14, 8, 8.4, 2.2),
                    pf.ramp(P.SOUP_BASE, spread=.20), bulge=.4, ambient=.50,
                    rim=False)
    for x in (2, 25):
        pf.render_solid(sp, pf.m_ellipse(28, 24, x, 11, 2.2, 2.6), iron,
                        bulge=.8, ambient=.34)
    pf.outline(sp)
    return sp


def prop_pan():
    sp = pf.Sprite(34, 18)
    iron = pf.ramp("#4a4450", spread=.22)
    pf.render_solid(sp, pf.m_ellipse(34, 18, 13, 10, 11, 6), iron,
                    bulge=.6, flat=.35, ambient=.32)
    pf.render_solid(sp, pf.m_ellipse(34, 18, 13, 9, 8.6, 4.2),
                    pf.ramp("#3a3540", spread=.18), bulge=.3, flat=.7,
                    ambient=.40, rim=False)
    pf.render_solid(sp, pf.m_capsule(34, 18, 23, 8, 32, 6, 1.8),
                    pf.ramp(P.OAK_DARK, spread=.18), bulge=.8, ambient=.34)
    pf.outline(sp)
    return sp


def prop_barrel():
    sp = pf.Sprite(26, 32)
    wood = pf.ramp(P.OAK_DARK, spread=.20)
    pf.drop_shadow(sp, np.zeros((32, 26), bool), 13, 30, 9, 3)
    body = pf.m_round_rect(26, 32, 3, 4, 20, 26, 6)
    pf.render_solid(sp, body, wood, bulge=.9, flat=.25, ambient=.34)
    for i in range(4):
        sp.line(4 + i * 5, 5, 4 + i * 5, 28, pf.mix(P.OAK_DARK, P.INK, .28))
    for y in (9, 24):
        sp.line(3, y, 22, y, pf.mix(P.STONE_L, P.INK, .2))
        sp.line(3, y + 1, 22, y + 1, pf.mix(P.STONE, P.INK, .4))
    pf.render_solid(sp, pf.m_ellipse(26, 32, 13, 5, 10, 3),
                    pf.ramp(P.OAK, spread=.16), bulge=.5, ambient=.46)
    pf.outline(sp)
    return sp


def prop_crate():
    sp = pf.Sprite(28, 28)
    wood = pf.ramp(P.OAK, spread=.18)
    pf.drop_shadow(sp, np.zeros((28, 28), bool), 14, 26, 10, 3)
    pf.render_solid(sp, pf.m_round_rect(28, 28, 2, 4, 24, 22, 1), wood,
                    bulge=.5, flat=.75, ambient=.38)
    for i in range(3):
        sp.line(3, 6 + i * 7, 24, 6 + i * 7, pf.mix(P.OAK, P.INK, .30))
    sp.line(3, 5, 24, 24, pf.mix(P.OAK, P.INK, .22))
    sp.line(24, 5, 3, 24, pf.mix(P.OAK, P.INK, .22))
    pf.outline(sp)
    return sp


def prop_candle():
    sp = pf.Sprite(14, 22)
    pf.render_solid(sp, pf.m_ellipse(14, 22, 7, 19, 5, 2.4),
                    pf.ramp(P.UI_GOLD, spread=.18), bulge=.6, ambient=.42)
    pf.render_solid(sp, pf.m_rect(14, 22, 5, 8, 4, 11),
                    pf.ramp(P.PAPER, spread=.14), bulge=.7, ambient=.50)
    pf.render_solid(sp, pf.m_ellipse(14, 22, 7, 5, 2.0, 3.4),
                    pf.ramp(P.FLAME_CORE, spread=.16), bulge=.9, ambient=.74,
                    rim=False)
    pf.glow(sp, 7, 5, 8, pf.hex2rgb(P.LAMP), .6)
    pf.outline(sp)
    return sp


def prop_plate(food=None):
    sp = pf.Sprite(24, 14)
    pf.render_solid(sp, pf.m_ellipse(24, 14, 12, 8, 11, 5),
                    pf.ramp(P.CHALK, spread=.14), bulge=.4, flat=.4, ambient=.52)
    pf.render_solid(sp, pf.m_ellipse(24, 14, 12, 7, 7.5, 3.2),
                    pf.ramp("#e6dcc4", spread=.12), bulge=.3, flat=.7,
                    ambient=.56, rim=False)
    if food is not None:
        sp.paste(food, 12 - food.w // 2, 6 - food.h // 2)
    pf.outline(sp)
    return sp


def prop_rug():
    sp = pf.Sprite(64, 32)
    pf.render_solid(sp, pf.m_ellipse(64, 32, 32, 16, 31, 15),
                    pf.ramp("#8f4a6b", spread=.18), bulge=.25, flat=.9,
                    ambient=.48, rim=False)
    pf.render_solid(sp, pf.m_ellipse(64, 32, 32, 16, 24, 11),
                    pf.ramp("#a8586f", spread=.16), bulge=.2, flat=.95,
                    ambient=.50, rim=False)
    for i in range(12):
        a = i / 12 * math.tau
        sp.px(32 + math.cos(a) * 17, 16 + math.sin(a) * 8, pf.hex2rgb(P.UI_GOLD))
    pf.outline(sp)
    return sp


# ============================================================= TOWN =========
def prop_house(variant=0):
    """Town houses. Each variant gets its own roof colour, window layout and
    silhouette so the town never reads as copy-paste."""
    sp = pf.Sprite(88, 96)
    roofs = ["#8f4a3f", "#3f6a8f", "#6a4a8f", "#4a7a5a"]
    walls = ["#d8bd92", "#c9ae86", "#e0c9a0", "#cbb591"]
    rc = roofs[variant % len(roofs)]
    wc = walls[variant % len(walls)]
    h = 46 + (variant % 3) * 8
    top = 96 - h - 26

    body = pf.m_rect(88, 96, 10, 96 - h, 68, h)
    pf.render_solid(sp, body, pf.ramp(wc, spread=.16), bulge=.35, flat=.85,
                    ambient=.46)
    # Half-timbering: two heavy corner posts, one mid rail and a pair of
    # braces. An even grid of thin lines reads as plaid fabric, not timber.
    beam = pf.mix(wc, P.OAK_DARK, .62)
    for x in (11, 74):
        sp.rect(x, 96 - h, 3, h, beam)
    sp.rect(10, 96 - h + 15, 68, 3, beam)
    sp.line(16, 96 - h + 14, 26, 96 - h + 2, beam)
    sp.line(72, 96 - h + 14, 62, 96 - h + 2, beam)
    # stone foundation course grounds the building
    pf.render_solid(sp, pf.m_rect(88, 96, 9, 90, 70, 6),
                    pf.ramp(P.STONE, spread=.16), bulge=.4, flat=.7,
                    ambient=.40, rim=False)

    # roof, overhanging the walls either side
    roof = pf.m_poly(88, 96, [(2, 96 - h + 4), (44, top), (86, 96 - h + 4)])
    pf.render_solid(sp, roof, pf.ramp(rc, spread=.20), bulge=.5, flat=.55,
                    ambient=.38)
    for r in range(5):
        yy = top + 6 + r * 6
        half = int((yy - top) * .78)
        sp.line(44 - half, yy, 44 + half, yy, pf.mix(rc, P.INK, .28))
    # chimney
    pf.render_solid(sp, pf.m_rect(88, 96, 60, top + 4, 9, 18),
                    pf.ramp(P.STONE, spread=.18), bulge=.5, flat=.7, ambient=.40)

    # windows + door
    for i in range(2):
        wx = 20 + i * 32
        m = pf.m_round_rect(88, 96, wx, 96 - h + 20, 14, 14, 2)
        pf.render_solid(sp, m, pf.ramp(P.LAMP, spread=.18), bulge=.3, flat=.9,
                        ambient=.60, rim=False)
        sp.rect(wx + 6, 96 - h + 20, 2, 14, pf.hex2rgb(P.WALL_TRIM))
        sp.rect(wx, 96 - h + 26, 14, 2, pf.hex2rgb(P.WALL_TRIM))
        pf.glow(sp, wx + 7, 96 - h + 27, 10, pf.hex2rgb(P.LAMP), .3)
    d = pf.m_round_rect(88, 96, 38, 96 - 22, 16, 22, 2)
    pf.render_solid(sp, d, pf.ramp(P.OAK_DARK, spread=.18), bulge=.4, flat=.8,
                    ambient=.38)
    sp.px(50, 96 - 11, pf.hex2rgb(P.UI_GOLD))
    pf.outline(sp)
    return sp


def prop_stall(variant=0):
    """Market stall with a striped awning and goods on the counter."""
    sp = pf.Sprite(72, 64)
    stripe = ["#c9524a", "#3f7a9c", "#5a9c4a"][variant % 3]
    for x in (4, 64):
        pf.render_solid(sp, pf.m_rect(72, 64, x, 20, 4, 42),
                        pf.ramp(P.OAK_DARK, spread=.18), bulge=.7, ambient=.34)
    awn = pf.m_poly(72, 64, [(0, 22), (72, 22), (66, 8), (6, 8)])
    pf.render_solid(sp, awn, pf.ramp(P.PAPER, spread=.14), bulge=.4, flat=.7,
                    ambient=.48)
    for i in range(0, 72, 12):
        m = pf.m_poly(72, 64, [(i, 22), (i + 6, 22), (i + 6 + 5, 8), (i + 5, 8)])
        pf.render_solid(sp, m & awn, pf.ramp(stripe, spread=.18), bulge=.4,
                        flat=.7, ambient=.46, rim=False)
    # scalloped hem
    for i in range(0, 72, 8):
        pf.render_solid(sp, pf.m_ellipse(72, 64, i + 4, 23, 4, 3),
                        pf.ramp(stripe, spread=.16), bulge=.6, ambient=.44,
                        rim=False)
    top = pf.m_rect(72, 64, 2, 34, 68, 8)
    pf.render_solid(sp, top, pf.ramp(P.OAK, spread=.18), bulge=.5, flat=.7,
                    ambient=.44)
    rng = np.random.RandomState(variant + 30)
    goods = [P.MUSHROOM, P.LEAF, P.CHEESE, P.BERRY, P.MAGIC, P.SOUP_BASE]
    for i in range(6):
        gx = 8 + i * 10
        c = goods[rng.randint(len(goods))]
        pf.render_solid(sp, pf.m_ellipse(72, 64, gx, 31, 3.4, 3.0),
                        pf.ramp(c, spread=.20), bulge=1.0, ambient=.40)
    pf.render_solid(sp, pf.m_rect(72, 64, 6, 42, 60, 18),
                    pf.ramp(P.WALL_TRIM, spread=.16), bulge=.3, flat=.9,
                    ambient=.36, rim=False)
    pf.outline(sp)
    return sp


def prop_witch_shop():
    sp = pf.Sprite(92, 104)
    body = pf.m_poly(92, 104, [(12, 104), (12, 46), (46, 34), (80, 46), (80, 104)])
    pf.render_solid(sp, body, pf.ramp("#5a4a6e", spread=.18), bulge=.4,
                    flat=.8, ambient=.42)
    roof = pf.m_poly(92, 104, [(2, 50), (46, 8), (90, 50), (78, 50), (46, 22),
                               (14, 50)])
    pf.render_solid(sp, roof, pf.ramp(P.WITCH_ROBE, spread=.20), bulge=.5,
                    flat=.6, ambient=.36)
    # crooked chimney with a green plume
    pf.render_solid(sp, pf.m_poly(92, 104, [(58, 30), (68, 26), (72, 6), (62, 8)]),
                    pf.ramp(P.STONE, spread=.18), bulge=.5, flat=.7, ambient=.38)
    for i in range(5):
        pf.render_solid(sp, pf.m_ellipse(92, 104, 68 + math.sin(i) * 4,
                                         4 - i * 3, 3 + i * .6, 2.4 + i * .5),
                        pf.ramp(P.LEAF_LIGHT, spread=.14), bulge=.7,
                        ambient=.56, rim=False, alpha=max(40, 150 - i * 26))
    # round window
    pf.render_solid(sp, pf.m_ellipse(92, 104, 46, 58, 11, 11),
                    pf.ramp(P.MAGIC, spread=.20), bulge=.3, flat=.85,
                    ambient=.58, rim=False)
    pf.glow(sp, 46, 58, 16, pf.hex2rgb(P.MAGIC_LIGHT), .5)
    for a in range(6):
        ang = a / 6 * math.tau
        sp.line(46, 58, 46 + math.cos(ang) * 10, 58 + math.sin(ang) * 10,
                pf.hex2rgb(P.WALL_TRIM))
    d = pf.m_round_rect(92, 104, 38, 78, 18, 26, 6)
    pf.render_solid(sp, d, pf.ramp(P.OAK_DARK, spread=.18), bulge=.4, flat=.8,
                    ambient=.36)
    sp.px(52, 92, pf.hex2rgb(P.UI_GOLD))
    # hanging sign - width is derived from the text so it can never overflow
    label = "HERBS"
    tw = pf.text_w(label)
    bx = 92 - tw - 12
    pf.render_solid(sp, pf.m_round_rect(92, 104, bx, 62, tw + 8, 12, 2),
                    pf.ramp(P.OAK_WARM, spread=.16), bulge=.4, flat=.7,
                    ambient=.44)
    pf.text(sp, label, bx + 4, 65, pf.hex2rgb(P.PAPER))
    pf.outline(sp)
    return sp


def prop_fountain():
    sp = pf.Sprite(64, 52)
    stone = pf.ramp(P.STONE, spread=.18)
    pf.drop_shadow(sp, np.zeros((52, 64), bool), 32, 47, 24, 5)
    pf.render_solid(sp, pf.m_ellipse(64, 52, 32, 38, 28, 12), stone,
                    bulge=.5, flat=.5, ambient=.42)
    pf.render_solid(sp, pf.m_ellipse(64, 52, 32, 37, 23, 9),
                    pf.ramp(P.WATER, spread=.20), bulge=.3, flat=.8,
                    ambient=.52, rim=False)
    pf.render_solid(sp, pf.m_rect(64, 52, 28, 16, 8, 20), stone, bulge=.7,
                    ambient=.38)
    pf.render_solid(sp, pf.m_ellipse(64, 52, 32, 16, 13, 5), stone, bulge=.6,
                    ambient=.44)
    pf.render_solid(sp, pf.m_ellipse(64, 52, 32, 15, 9, 3),
                    pf.ramp(P.WATER, spread=.18), bulge=.3, ambient=.54,
                    rim=False)
    for i in range(7):
        a = i / 7 * math.tau
        for t in range(4):
            sp.px(32 + math.cos(a) * (9 + t * 2), 16 + abs(math.sin(a)) * 3 + t * 5,
                  pf.mix(P.WATER, P.CHALK, .5 - t * .1))
    pf.outline(sp)
    return sp


# ============================================================ FOREST ========
def prop_tree(variant=0):
    sp = pf.Sprite(80, 104)
    rng = np.random.RandomState(variant + 41)
    pf.drop_shadow(sp, np.zeros((104, 80), bool), 40, 100, 20, 5)
    # trunk with a slight lean and a root flare
    lean = (variant % 3 - 1) * 5
    trunk = pf.m_capsule(80, 104, 40, 100, 40 + lean, 56, 6.5)
    trunk |= pf.m_poly(80, 104, [(28, 102), (52, 102), (46, 88), (34, 88)])
    pf.render_solid(sp, trunk, pf.ramp(P.BARK, spread=.20), bulge=.8, ambient=.30)
    for i in range(5):
        yy = 62 + i * 8
        sp.line(36 + lean // 2, yy, 44 + lean // 2, yy - 2,
                pf.mix(P.BARK, P.INK, .30))
    for side in (-1, 1):
        b = pf.m_capsule(80, 104, 40 + lean, 66, 40 + lean + side * 13, 54, 3.0)
        pf.render_solid(sp, b, pf.ramp(P.BARK, spread=.18), bulge=.8, ambient=.30)

    # canopy: overlapping blobs, darkest first, so it has depth not a flat mass
    cx = 40 + lean
    layers = [(P.LEAF_DEEP, 30, 0, 4), (P.LEAF, 26, -6, 3), (P.LEAF_LIGHT, 17, -12, 2)]
    for ci, (c, r, dy, lo) in enumerate(layers):
        for k in range(3):
            ox = int(rng.randint(-10, 11))
            oy = int(rng.randint(-6, 7))
            m = pf.m_blob(80, 104, cx + ox, 40 + dy + oy, r * .72, lo,
                          seed=variant * 10 + ci * 3 + k, wob=.30)
            pf.render_solid(sp, m, pf.ramp(c, spread=.20), bulge=.85,
                            ambient=.30 + ci * .04, rim=(ci == 2), strength=2.2)
    # leaf clusters catching the light
    for _ in range(18):
        x, y = rng.randint(14, 66), rng.randint(16, 56)
        if sp.get(x, y)[3]:
            sp.px(x, y, pf.mix(P.LEAF_LIGHT, P.LAMP, .30))
    pf.outline(sp)
    return sp


def prop_bush(variant=0):
    sp = pf.Sprite(44, 34)
    rng = np.random.RandomState(variant + 7)
    pf.drop_shadow(sp, np.zeros((34, 44), bool), 22, 31, 14, 3)
    for ci, (c, r) in enumerate([(P.LEAF_DEEP, 13), (P.LEAF, 10)]):
        for k in range(3):
            m = pf.m_blob(44, 34, 12 + k * 9, 20 - ci * 3, r, 3,
                          seed=variant * 5 + ci * 2 + k, wob=.28)
            m &= ~pf.m_rect(44, 34, 0, 30, 44, 4)
            pf.render_solid(sp, m, pf.ramp(c, spread=.20), bulge=.9,
                            ambient=.32, strength=2.2)
    if variant % 2:
        for _ in range(4):
            x, y = rng.randint(8, 36), rng.randint(10, 26)
            if sp.get(x, y)[3]:
                pf.render_solid(sp, pf.m_ellipse(44, 34, x, y, 2.0, 2.0),
                                pf.ramp(P.BERRY, spread=.18), bulge=1.0,
                                ambient=.40, rim=False)
    pf.outline(sp)
    return sp


def prop_mushroom(kind="red"):
    sp = pf.Sprite(24, 26)
    tints = {"red": P.MUSHROOM, "blue": "#5a7fc9", "ghost": "#cfe4ff",
             "gold": P.CHEESE}
    c = tints.get(kind, P.MUSHROOM)
    pf.drop_shadow(sp, np.zeros((26, 24), bool), 12, 24, 7, 2)
    pf.render_solid(sp, pf.m_capsule(24, 26, 12, 23, 12, 14, 3.0),
                    pf.ramp(P.BONE, spread=.14), bulge=.8, ambient=.46)
    cap = pf.m_ellipse(24, 26, 12, 12, 10, 7) & ~pf.m_rect(24, 26, 0, 13, 24, 13)
    pf.render_solid(sp, cap, pf.ramp(c, spread=.22), bulge=1.0, ambient=.34)
    rng = np.random.RandomState(pf.stable_seed(kind) % 999)
    for _ in range(5):
        x, y = rng.randint(4, 20), rng.randint(6, 12)
        if sp.get(x, y)[3]:
            pf.render_solid(sp, pf.m_ellipse(24, 26, x, y, 1.6, 1.3),
                            pf.ramp(P.CHALK, spread=.10), bulge=.8,
                            ambient=.62, rim=False)
    if kind == "ghost":
        pf.glow(sp, 12, 12, 12, pf.hex2rgb(P.MOON), .55)
    pf.outline(sp)
    return sp


def prop_flower(variant=0):
    sp = pf.Sprite(18, 22)
    cols = ["#e8677f", "#f0c74e", "#9a6fd8", "#f28f5a"]
    c = cols[variant % len(cols)]
    sp.line(9, 21, 9, 12, pf.hex2rgb(P.LEAF_DEEP))
    pf.render_solid(sp, pf.m_ellipse(18, 22, 6, 16, 3.2, 2.0),
                    pf.ramp(P.LEAF, spread=.16), bulge=.7, ambient=.38, rim=False)
    for i in range(5):
        a = i / 5 * math.tau - math.pi / 2
        pf.render_solid(sp, pf.m_ellipse(18, 22, 9 + math.cos(a) * 3.6,
                                         9 + math.sin(a) * 3.6, 2.6, 2.6),
                        pf.ramp(c, spread=.20), bulge=.9, ambient=.40, rim=False)
    pf.render_solid(sp, pf.m_ellipse(18, 22, 9, 9, 2.0, 2.0),
                    pf.ramp(P.CHEESE, spread=.16), bulge=1.0, ambient=.50,
                    rim=False)
    pf.outline(sp)
    return sp


def prop_rock(variant=0):
    sp = pf.Sprite(32, 24)
    pf.drop_shadow(sp, np.zeros((24, 32), bool), 16, 21, 11, 3)
    m = pf.m_blob(32, 24, 16, 14, 10, 4, seed=variant + 60, wob=.34)
    m &= ~pf.m_rect(32, 24, 0, 21, 32, 4)
    pf.render_solid(sp, m, pf.ramp(P.STONE, spread=.20), bulge=.8, ambient=.34,
                    flat=.25)
    sp.line(11, 12, 16, 17, pf.mix(P.STONE, P.INK, .40))
    sp.line(16, 17, 22, 14, pf.mix(P.STONE, P.INK, .40))
    if variant % 2:
        pf.render_solid(sp, pf.m_blob(32, 24, 12, 9, 4, 3, seed=variant) & m,
                        pf.ramp(P.LEAF, spread=.18), bulge=.5, ambient=.40,
                        rim=False)
    pf.outline(sp)
    return sp


def prop_log():
    sp = pf.Sprite(40, 20)
    pf.drop_shadow(sp, np.zeros((20, 40), bool), 20, 18, 15, 3)
    pf.render_solid(sp, pf.m_capsule(40, 20, 8, 11, 32, 11, 6.5),
                    pf.ramp(P.BARK, spread=.20), bulge=.9, ambient=.32)
    pf.render_solid(sp, pf.m_ellipse(40, 20, 8, 11, 3.0, 6.2),
                    pf.ramp(P.OAK_WARM, spread=.18), bulge=.4, ambient=.46,
                    rim=False)
    for r in (1.8, 3.4):
        for a in range(12):
            ang = a / 12 * math.tau
            sp.px(8 + math.cos(ang) * r * .55, 11 + math.sin(ang) * r,
                  pf.mix(P.OAK_WARM, P.INK, .3))
    pf.outline(sp)
    return sp


# ============================================================== BUILD =======
def build(manifest):
    def emit(sp, sub, name):
        p = sp.save(os.path.join(OUT, sub, name + ".png"))
        manifest.append({"kind": "environment", "group": sub, "id": name,
                         "path": rel(p), "w": sp.w, "h": sp.h})

    for i in range(4):
        emit(tile_floor_plank(i), "tiles", "floor_plank_%d" % i)
        emit(tile_grass(i), "tiles", "grass_%d" % i)
        emit(tile_path(i), "tiles", "path_%d" % i)
        emit(tile_cobble(i), "tiles", "cobble_%d" % i)
        emit(tile_dirt(i), "tiles", "dirt_%d" % i)
    for i in range(2):
        emit(tile_floor_tile(i), "tiles", "floor_tile_%d" % i)
        emit(tile_wall(i), "tiles", "wall_%d" % i)
    emit(tile_wainscot(), "tiles", "wainscot")
    water = [tile_water(f) for f in range(4)]
    p, fw, fh, n = pf.sheet(water, os.path.join(OUT, "tiles", "water.png"))
    manifest.append({"kind": "environment", "group": "tiles", "id": "water",
                     "path": rel(p), "fw": fw, "fh": fh, "frames": n})

    for name, fn in (("stove", prop_stove), ("fridge", prop_fridge),
                     ("table", prop_table), ("plant", prop_plant),
                     ("painting", prop_painting), ("door", prop_door),
                     ("sign", prop_sign), ("pot", prop_pot), ("pan", prop_pan),
                     ("barrel", prop_barrel), ("crate", prop_crate),
                     ("candle", prop_candle), ("rug", prop_rug),
                     ("fountain", prop_fountain), ("log", prop_log)):
        emit(fn(), "props", name)
    emit(prop_counter(64), "props", "counter")
    emit(prop_counter(96), "props", "counter_long")
    emit(prop_shelf(52), "props", "shelf")
    emit(prop_chair(), "props", "chair")
    emit(prop_lamp(True), "props", "lamp_on")
    emit(prop_lamp(False), "props", "lamp_off")
    emit(prop_window(False), "props", "window_day")
    emit(prop_window(True), "props", "window_night")
    emit(prop_plate(), "props", "plate")
    emit(prop_witch_shop(), "town", "witch_shop")
    emit(prop_fountain(), "town", "fountain")
    for i in range(4):
        emit(prop_house(i), "town", "house_%d" % i)
    for i in range(3):
        emit(prop_stall(i), "town", "stall_%d" % i)
    for i in range(4):
        emit(prop_tree(i), "forest", "tree_%d" % i)
        emit(prop_bush(i), "forest", "bush_%d" % i)
        emit(prop_rock(i), "forest", "rock_%d" % i)
        emit(prop_flower(i), "forest", "flower_%d" % i)
    for k in ("red", "blue", "ghost", "gold"):
        emit(prop_mushroom(k), "forest", "mushroom_%s" % k)
    print("  environment: %d assets" % len([m for m in manifest
                                            if m["kind"] == "environment"]))
    return manifest


if __name__ == "__main__":
    build([])
