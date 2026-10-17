"""
Original UI art: panels, buttons, icons, bars, bubbles, logo.

Visual direction (CLAUDE.md): fantasy cookbook + restaurant ledger. Warm
parchment surfaces, dark wood frames, brass fittings, chunky pixel borders.
Nothing here may look like a modern flat dashboard.

Panels are authored as 9-slice textures; the corner size is fixed at 8px for
every panel so NinePatchRect margins are the same everywhere.
"""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixelforge as pf
import palette as P

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..",
                   "assets", "ui")
SLICE = 8


def rel(p):
    root = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
    return "res://" + os.path.relpath(os.path.abspath(p), root).replace("\\", "/")


# =============================================================== PANELS =====
def panel(w=48, h=48, fill=P.UI_PANEL, edge=P.UI_EDGE, parchment=False,
          seed=0):
    """9-slice panel. Corners are drawn so they survive stretching."""
    sp = pf.Sprite(w, h)
    body = pf.m_rect(w, h, 2, 2, w - 4, h - 4)
    if parchment:
        cols = pf.ramp(fill, spread=.12)
        sp.rect(2, 2, w - 4, h - 4, cols[2])
        rng = np.random.RandomState(seed + 3)
        # aged fibre speckle - a flat fill reads as plastic
        for _ in range(int(w * h * .08)):
            x, y = rng.randint(2, w - 2), rng.randint(2, h - 2)
            sp.px(x, y, cols[1] if rng.rand() < .5 else cols[3])
        # warm inner glow toward the top-left, matching the world light
        for y in range(2, h - 2):
            for x in range(2, w - 2):
                t = 1 - (x / w * .5 + y / h * .5)
                if t > .55:
                    sp.px(x, y, pf.mix(cols[2], P.LAMP, (t - .55) * .35))
    else:
        # Flat vertical gradient, NOT dome shading. A 9-slice centre tile gets
        # stretched arbitrarily, so any diagonal or radial shading inside it
        # smears into a visible seam. Only the vertical axis is safe.
        cols = pf.ramp(fill, spread=.16)
        for y in range(2, h - 2):
            t = (y - 2) / max(1, h - 5)
            c = pf.mix(cols[3], cols[1], t)
            sp.rect(2, y, w - 4, 1, c)

    # frame: dark outer, bright bevel, dark inner shadow line
    outer = pf.mix(edge, P.INK, .55)
    sp.rect(0, 0, w, 2, outer)
    sp.rect(0, h - 2, w, 2, outer)
    sp.rect(0, 0, 2, h, outer)
    sp.rect(w - 2, 0, 2, h, outer)
    sp.rect(1, 1, w - 2, 1, edge)
    sp.rect(1, 1, 1, h - 2, edge)
    sp.rect(1, h - 2, w - 2, 1, pf.mix(edge, P.INK, .35))
    sp.rect(w - 2, 1, 1, h - 2, pf.mix(edge, P.INK, .35))
    # inner shadow so content sits in a recess
    sp.rect(2, 2, w - 4, 1, pf.mix(fill, P.INK, .40))
    sp.rect(2, 2, 1, h - 4, pf.mix(fill, P.INK, .40))
    # brass corner studs
    for (cx, cy) in ((3, 3), (w - 4, 3), (3, h - 4), (w - 4, h - 4)):
        sp.px(cx, cy, P.UI_GOLD)
        sp.px(cx, cy + 1, pf.mix(P.UI_GOLD, P.INK, .45))
    return sp


def button(w=64, h=24, state="normal", label=None):
    tints = {"normal": P.UI_PANEL_L, "hover": pf.mix(P.UI_PANEL_L, P.LAMP, .22),
             "pressed": pf.mix(P.UI_PANEL_L, P.INK, .28),
             "disabled": pf.mix(P.UI_PANEL_L, P.STONE, .55)}
    fill = tints.get(state, P.UI_PANEL_L)
    sp = pf.Sprite(w, h)
    off = 1 if state == "pressed" else 0
    if state != "pressed":
        sp.rect(2, h - 2, w - 4, 2, pf.mix(P.INK, P.UI_PANEL, .25))
    body = pf.m_round_rect(w, h, 1, off, w - 2, h - 2 - off, 3)
    pf.render_solid(sp, body, pf.ramp(fill, spread=.18), bulge=.45, flat=.72,
                    ambient=.50, rim=False, contrast=1.0)
    sp.rect(3, 1 + off, w - 6, 1, pf.mix(fill, P.LAMP, .40))
    edge = P.UI_EDGE if state != "disabled" else P.STONE_L
    for x in range(2, w - 2):
        sp.px(x, off, pf.mix(edge, P.INK, .35))
        sp.px(x, h - 3, pf.mix(edge, P.INK, .55))
    for y in range(1 + off, h - 3):
        sp.px(1, y, pf.mix(edge, P.INK, .35))
        sp.px(w - 2, y, pf.mix(edge, P.INK, .45))
    if label:
        tw = pf.text_w(label)
        c = P.UI_TEXT if state != "disabled" else P.UI_TEXT_DIM
        pf.text(sp, label, (w - tw) // 2, (h - 7) // 2 + off, pf.hex2rgb(c),
                shadow=pf.hex2rgb(P.INK))
    return sp


def bubble(w=72, h=40, tail=True):
    """Speech bubble with a pixel tail. Used for orders and reactions."""
    sp = pf.Sprite(w, h)
    body = pf.m_round_rect(w, h, 1, 1, w - 2, h - 9, 5)
    pf.render_solid(sp, body, pf.ramp(P.PAPER, spread=.10), bulge=.3, flat=.9,
                    ambient=.62, rim=False, contrast=1.0)
    if tail:
        t = pf.m_poly(w, h, [(14, h - 10), (26, h - 10), (16, h - 1)])
        pf.render_solid(sp, t, pf.ramp(P.PAPER, spread=.10), bulge=.3, flat=.9,
                        ambient=.62, rim=False, contrast=1.0)
    pf.outline(sp, tint=pf.hex2rgb(P.OAK_DARK), amount=.75)
    return sp


# ================================================================ ICONS =====
IC = 16


def icon_coin():
    sp = pf.Sprite(IC, IC)
    pf.render_solid(sp, pf.m_ellipse(IC, IC, 8, 8, 6.5, 6.5),
                    pf.ramp(P.UI_GOLD, spread=.22), bulge=1.0, ambient=.40)
    pf.render_solid(sp, pf.m_ellipse(IC, IC, 8, 8, 4.2, 4.2),
                    pf.ramp(pf.mix(P.UI_GOLD, P.LAMP_HOT, .35), spread=.16),
                    bulge=.5, ambient=.56, rim=False)
    sp.px(6, 5, P.LAMP_HOT)
    pf.text(sp, "G", 6, 5, pf.hex2rgb(pf.mix(P.UI_GOLD, P.INK, .55)))
    pf.outline(sp)
    return sp


def icon_star(filled=True):
    sp = pf.Sprite(IC, IC)
    m = pf.m_star(IC, IC, 8, 8, 7.0, 3.0, 5, -math.pi / 2)
    c = P.UI_STAR if filled else P.STONE
    pf.render_solid(sp, m, pf.ramp(c, spread=.20), bulge=.7, ambient=.44)
    pf.outline(sp)
    return sp


def icon_heart(filled=True):
    sp = pf.Sprite(IC, IC)
    m = (pf.m_ellipse(IC, IC, 5.5, 6, 3.6, 3.4)
         | pf.m_ellipse(IC, IC, 10.5, 6, 3.6, 3.4)
         | pf.m_poly(IC, IC, [(2, 7), (14, 7), (8, 14)]))
    c = "#e0506a" if filled else P.STONE
    pf.render_solid(sp, m, pf.ramp(c, spread=.20), bulge=.9, ambient=.42)
    sp.px(5, 5, pf.mix(c, P.CHALK, .6))
    pf.outline(sp)
    return sp


def icon_clock():
    sp = pf.Sprite(IC, IC)
    pf.render_solid(sp, pf.m_ellipse(IC, IC, 8, 8, 6.5, 6.5),
                    pf.ramp(P.PAPER, spread=.14), bulge=.8, ambient=.52)
    pf.render_solid(sp, pf.m_ellipse(IC, IC, 8, 8, 5.0, 5.0),
                    pf.ramp(P.CHALK, spread=.10), bulge=.3, ambient=.66,
                    rim=False)
    sp.line(8, 8, 8, 4, P.INK)
    sp.line(8, 8, 11, 9, P.INK)
    pf.outline(sp)
    return sp


def icon_bag():
    sp = pf.Sprite(IC, IC)
    pf.render_solid(sp, pf.m_round_rect(IC, IC, 2, 5, 12, 10, 3),
                    pf.ramp(P.OAK, spread=.20), bulge=.7, flat=.4, ambient=.40)
    for x in (5, 10):
        sp.line(x, 5, x, 2, pf.mix(P.OAK_DARK, P.INK, .2))
    sp.line(5, 2, 10, 2, pf.mix(P.OAK_DARK, P.INK, .2))
    sp.rect(2, 8, 12, 2, pf.mix(P.OAK, P.LAMP, .3))
    pf.outline(sp)
    return sp


def icon_book():
    sp = pf.Sprite(IC, IC)
    pf.render_solid(sp, pf.m_round_rect(IC, IC, 1, 2, 14, 12, 1),
                    pf.ramp("#8f3a3a", spread=.20), bulge=.5, flat=.7,
                    ambient=.42)
    pf.render_solid(sp, pf.m_rect(IC, IC, 3, 3, 11, 10),
                    pf.ramp(P.PAPER, spread=.10), bulge=.3, flat=.9,
                    ambient=.62, rim=False)
    for i in range(3):
        sp.line(5, 5 + i * 3, 12, 5 + i * 3, pf.hex2rgb(P.UI_TEXT_DIM))
    sp.rect(1, 2, 2, 12, pf.mix("#8f3a3a", P.INK, .35))
    pf.outline(sp)
    return sp


def icon_orders():
    sp = pf.Sprite(IC, IC)
    pf.render_solid(sp, pf.m_round_rect(IC, IC, 3, 1, 10, 14, 1),
                    pf.ramp(P.PAPER, spread=.10), bulge=.3, flat=.9,
                    ambient=.62, rim=False)
    for i in range(4):
        sp.line(5, 4 + i * 3, 11, 4 + i * 3, pf.hex2rgb(P.UI_TEXT_DIM))
    sp.line(5, 4, 6, 4, pf.hex2rgb(P.UI_BAD))
    pf.outline(sp)
    return sp


def icon_restaurant():
    sp = pf.Sprite(IC, IC)
    pf.render_solid(sp, pf.m_poly(IC, IC, [(1, 8), (8, 2), (15, 8)]),
                    pf.ramp("#8f4a3f", spread=.20), bulge=.6, ambient=.40)
    pf.render_solid(sp, pf.m_rect(IC, IC, 3, 8, 10, 7),
                    pf.ramp(P.WALL_PLASTER, spread=.14), bulge=.3, flat=.9,
                    ambient=.54, rim=False)
    pf.render_solid(sp, pf.m_rect(IC, IC, 6, 10, 4, 5),
                    pf.ramp(P.LAMP, spread=.16), bulge=.3, ambient=.62,
                    rim=False)
    pf.outline(sp)
    return sp


def icon_tag(kind):
    """Taste / property tags shown on orders and recipes."""
    sp = pf.Sprite(IC, IC)
    if kind == "hot":
        for i in range(3):
            m = pf.m_poly(IC, IC, [(5 + i * 2, 14), (8, 3 + i * 3), (11 - i * 2, 14)])
            pf.render_solid(sp, m, pf.ramp([P.FLAME, P.EMBER, P.FLAME_CORE][i],
                                           spread=.18),
                            bulge=.7, ambient=.48, rim=False)
    elif kind == "spicy":
        pf.render_solid(sp, pf.m_capsule(IC, IC, 6, 5, 9, 13, 3.0),
                        pf.ramp(P.FLAME, spread=.20), bulge=.9, ambient=.40)
        sp.line(6, 4, 8, 1, pf.hex2rgb(P.LEAF))
    elif kind == "sweet":
        pf.render_solid(sp, pf.m_ellipse(IC, IC, 8, 9, 5.5, 5.0),
                        pf.ramp(P.SUGAR, spread=.16), bulge=.9, ambient=.50)
        pf.render_solid(sp, pf.m_ellipse(IC, IC, 8, 4, 2.4, 2.4),
                        pf.ramp(P.MUSHROOM, spread=.18), bulge=1.0, ambient=.44)
    elif kind == "cold":
        for a in range(3):
            ang = a / 3 * math.pi
            sp.line(8 - math.cos(ang) * 6, 8 - math.sin(ang) * 6,
                    8 + math.cos(ang) * 6, 8 + math.sin(ang) * 6,
                    pf.hex2rgb("#9fd8ef"))
        sp.px(8, 8, P.CHALK)
    elif kind == "large":
        pf.render_solid(sp, pf.m_ellipse(IC, IC, 8, 9, 6.5, 5.0),
                        pf.ramp(P.MEAT_COOKED, spread=.20), bulge=.9,
                        ambient=.40)
        pf.render_solid(sp, pf.m_capsule(IC, IC, 11, 6, 14, 3, 1.6),
                        pf.ramp(P.BONE, spread=.14), bulge=.9, ambient=.48)
    elif kind == "magical":
        m = pf.m_star(IC, IC, 8, 8, 6.5, 2.6, 4, -math.pi / 2)
        pf.render_solid(sp, m, pf.ramp(P.MAGIC, spread=.22), bulge=.7,
                        ambient=.48)
        pf.glow(sp, 8, 8, 7, pf.hex2rgb(P.MAGIC_LIGHT), .5)
    elif kind == "bitter":
        pf.render_solid(sp, pf.m_ellipse(IC, IC, 8, 8, 5.5, 6.5),
                        pf.ramp(P.LEAF_DEEP, spread=.20), bulge=.9, ambient=.38)
        sp.line(8, 2, 8, 14, pf.mix(P.LEAF_DEEP, P.INK, .4))
    elif kind == "rare":
        m = pf.m_poly(IC, IC, [(8, 1), (14, 7), (8, 15), (2, 7)])
        pf.render_solid(sp, m, pf.ramp("#5ad0e0", spread=.22), bulge=.7,
                        ambient=.46)
        sp.px(6, 6, P.CHALK)
    elif kind == "meat":
        pf.render_solid(sp, pf.m_blob(IC, IC, 8, 9, 5.5, 3, seed=1),
                        pf.ramp(P.MEAT_COOKED, spread=.20), bulge=.9,
                        ambient=.40)
    else:  # vegetable
        pf.render_solid(sp, pf.m_ellipse(IC, IC, 8, 10, 4.5, 5.0),
                        pf.ramp(P.LEAF, spread=.20), bulge=.9, ambient=.40)
        sp.line(8, 5, 8, 1, pf.hex2rgb(P.LEAF_DEEP))
    pf.outline(sp)
    return sp


ICONS = {"coin": icon_coin, "clock": icon_clock, "bag": icon_bag,
         "book": icon_book, "orders": icon_orders,
         "restaurant": icon_restaurant}
TAGS = ["hot", "spicy", "sweet", "cold", "large", "magical", "bitter", "rare",
        "meat", "vegetable"]


# ================================================================= BARS =====
def bar_frame(w=64, h=10):
    sp = pf.Sprite(w, h)
    sp.rect(0, 0, w, h, pf.mix(P.UI_PANEL, P.INK, .55))
    sp.rect(1, 1, w - 2, h - 2, pf.mix(P.INK, P.UI_PANEL, .35))
    for x in range(1, w - 1):
        sp.px(x, 1, pf.mix(P.INK, P.UI_PANEL, .12))
    sp.rect(0, 0, w, 1, pf.mix(P.UI_EDGE, P.INK, .45))
    sp.rect(0, h - 1, w, 1, pf.mix(P.UI_EDGE, P.INK, .60))
    return sp


def bar_fill(w=64, h=10, col=P.UI_GOOD):
    sp = pf.Sprite(w, h)
    cols = pf.ramp(col, spread=.20)
    sp.rect(0, 0, w, h, cols[2])
    sp.rect(0, 0, w, 2, cols[3])
    sp.rect(0, 1, w, 1, cols[4])
    sp.rect(0, h - 2, w, 2, cols[1])
    # diagonal ticks give the fill motion when it animates
    for x in range(0, w, 4):
        for y in range(2, h - 2):
            sp.px(x + y, y, pf.mix(cols[3], P.CHALK, .18))
    return sp


def slider_knob():
    sp = pf.Sprite(12, 16)
    pf.render_solid(sp, pf.m_round_rect(12, 16, 1, 1, 10, 14, 3),
                    pf.ramp(P.UI_EDGE, spread=.18), bulge=.6, flat=.5,
                    ambient=.48)
    sp.line(4, 5, 4, 10, pf.mix(P.UI_EDGE, P.INK, .45))
    sp.line(7, 5, 7, 10, pf.mix(P.UI_EDGE, P.INK, .45))
    pf.outline(sp)
    return sp


def cooking_gauge(w=160, h=20):
    """The heat/timing track: a recessed brass rail with a marked sweet spot."""
    sp = pf.Sprite(w, h)
    sp.rect(0, 0, w, h, pf.mix(P.UI_PANEL, P.INK, .40))
    rail = pf.m_round_rect(w, h, 3, 5, w - 6, h - 10, 3)
    pf.render_solid(sp, rail, pf.ramp(pf.mix(P.INK, P.UI_PANEL, .30),
                                      spread=.14),
                    bulge=.3, flat=.9, ambient=.50, rim=False, contrast=1.0)
    # gradient cold -> hot along the rail
    for x in range(4, w - 4):
        t = (x - 4) / max(1, w - 9)
        c = pf.mix(pf.mix("#4a86b8", P.LAMP, min(1, t * 2)),
                   P.FLAME, max(0, t * 2 - 1))
        for y in range(6, h - 6):
            sp.px(x, y, pf.mix(c, P.INK, .30))
    # sweet spot band
    s0, s1 = int(w * .58), int(w * .74)
    for x in range(s0, s1):
        for y in range(5, h - 5):
            sp.px(x, y, pf.mix(P.UI_GOOD, P.LAMP, .3))
    sp.rect(s0, 4, 1, h - 8, P.LAMP_HOT)
    sp.rect(s1 - 1, 4, 1, h - 8, P.LAMP_HOT)
    sp.rect(0, 0, w, 1, pf.mix(P.UI_EDGE, P.INK, .5))
    sp.rect(0, h - 1, w, 1, pf.mix(P.UI_EDGE, P.INK, .6))
    return sp


# ================================================================ LOGO ======
def logo():
    """Title logo. Carved sign over a plate silhouette."""
    w, h = 420, 150
    sp = pf.Sprite(w, h)
    board = pf.m_round_rect(w, h, 10, 24, w - 20, 96, 8)
    pf.render_solid(sp, board, pf.ramp(P.OAK_WARM, spread=.20), bulge=.45,
                    flat=.7, ambient=.44)
    sp.rect(14, 28, w - 28, 2, pf.mix(P.OAK_WARM, P.LAMP, .40))
    sp.rect(14, 116, w - 28, 2, pf.mix(P.OAK_WARM, P.INK, .40))
    # wood grain
    rng = np.random.RandomState(4)
    for _ in range(46):
        y = rng.randint(30, 116)
        x = rng.randint(16, w - 60)
        sp.line(x, y, x + rng.randint(14, 44), y,
                pf.mix(P.OAK_WARM, P.INK, .14))

    def big(s, ox, oy, col, sh, sc=3):
        cx = ox
        for ch in s.upper():
            g = pf.FONT.get(ch)
            if not g:
                cx += 3 * sc
                continue
            for j, row in enumerate(g):
                for i, bit in enumerate(row):
                    if bit == "1":
                        for a in range(sc):
                            for b in range(sc):
                                sp.px(cx + i * sc + a, oy + j * sc + b + sc, sh)
            for j, row in enumerate(g):
                for i, bit in enumerate(row):
                    if bit == "1":
                        for a in range(sc):
                            for b in range(sc):
                                sp.px(cx + i * sc + a, oy + j * sc + b, col)
            cx += (5 + 1) * sc
        return cx - ox

    tw = pf.text_w("RESTAURANT") * 4
    big("RESTAURANT", (w - tw) // 2, 36, pf.hex2rgb(P.PAPER),
        pf.hex2rgb(P.OAK_DARK), 4)
    tw2 = pf.text_w("FOR MONSTERS") * 3
    big("FOR MONSTERS", (w - tw2) // 2, 76, pf.hex2rgb(P.LAMP),
        pf.hex2rgb(P.OAK_DARK), 3)
    pf.outline(sp, tint=pf.hex2rgb(P.INK), amount=.8)

    # brass hanging rings + a lick of flame either side of the board
    for x in (40, w - 40):
        pf.render_solid(sp, pf.m_ellipse(w, h, x, 18, 6, 6),
                        pf.ramp(P.UI_GOLD, spread=.18), bulge=.8, ambient=.44)
        pf.render_solid(sp, pf.m_ellipse(w, h, x, 18, 3, 3),
                        pf.ramp(P.DUSK, spread=.10), bulge=.2, ambient=.40,
                        rim=False)
    for i, x in enumerate((22, w - 22)):
        for k in range(4):
            m = pf.m_blob(w, h, x, 130 - k * 7, 9 - k * 1.6, 3, seed=i * 4 + k)
            c = [P.FLAME, P.EMBER, P.FLAME_CORE, P.LAMP_HOT][k]
            pf.render_solid(sp, m, pf.ramp(c, spread=.16), bulge=.8,
                            ambient=.56, rim=False)
        pf.glow(sp, x, 124, 22, pf.hex2rgb(P.EMBER), .5)
    return sp


def cursor():
    sp = pf.Sprite(16, 16)
    m = pf.m_poly(16, 16, [(1, 1), (11, 8), (7, 9), (9, 14), (6, 15), (4, 10),
                           (1, 12)])
    pf.render_solid(sp, m, pf.ramp(P.PAPER, spread=.14), bulge=.5, flat=.6,
                    ambient=.60, rim=False)
    pf.outline(sp, tint=pf.hex2rgb(P.INK), amount=.85)
    return sp


def build(manifest):
    def emit(sp, sub, name, extra=None):
        p = sp.save(os.path.join(OUT, sub, name + ".png"))
        rec = {"kind": "ui", "group": sub, "id": name, "path": rel(p),
               "w": sp.w, "h": sp.h}
        if extra:
            rec.update(extra)
        manifest.append(rec)

    ninep = {"slice": SLICE}
    emit(panel(48, 48, P.UI_PANEL, P.UI_EDGE), "panels", "panel_dark", ninep)
    emit(panel(48, 48, P.PARCHMENT, P.OAK, parchment=True), "panels",
         "panel_parchment", ninep)
    emit(panel(48, 48, P.UI_PANEL_L, P.UI_EDGE_HI), "panels", "panel_light",
         ninep)
    emit(panel(48, 48, pf.mix(P.UI_PANEL, P.INK, .35), P.OAK), "panels",
         "panel_inset", ninep)
    emit(bubble(72, 40), "panels", "bubble", ninep)

    for st in ("normal", "hover", "pressed", "disabled"):
        emit(button(64, 24, st), "buttons", "button_" + st, ninep)
    for st in ("normal", "hover", "pressed"):
        emit(button(28, 28, st), "buttons", "button_sq_" + st, ninep)

    for name, fn in ICONS.items():
        emit(fn(), "icons", "icon_" + name)
    emit(icon_star(True), "icons", "icon_star")
    emit(icon_star(False), "icons", "icon_star_empty")
    emit(icon_heart(True), "icons", "icon_heart")
    emit(icon_heart(False), "icons", "icon_heart_empty")
    for t in TAGS:
        emit(icon_tag(t), "icons", "tag_" + t)

    emit(bar_frame(64, 10), "bars", "bar_frame", ninep)
    for name, c in (("good", P.UI_GOOD), ("warn", P.UI_WARN),
                    ("bad", P.UI_BAD), ("gold", P.UI_GOLD),
                    ("magic", P.MAGIC), ("heart", "#e0506a")):
        emit(bar_fill(64, 10, c), "bars", "bar_" + name, ninep)
    emit(slider_knob(), "bars", "knob")
    emit(cooking_gauge(160, 20), "bars", "gauge")

    emit(logo(), "brand", "logo")
    emit(cursor(), "brand", "cursor")
    print("  ui: %d assets" % len([m for m in manifest if m["kind"] == "ui"]))
    return manifest


if __name__ == "__main__":
    build([])
