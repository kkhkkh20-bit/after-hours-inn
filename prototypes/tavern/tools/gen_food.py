"""
Food and ingredient art.

Two rules drive everything here:

1. Food must be readable at 24-32px. Silhouette first, garnish second.
2. Cooking quality must be visible without reading a number. Every dish is
   generated at six quality tiers and the player learns the language:
   pink = raw, gold = perfect, black = burnt.

That second rule is why dishes are generated as a function of quality rather
than as six hand-drawn variants - the tiers stay consistent across the whole
menu, so the feedback is trustworthy.
"""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixelforge as pf
import palette as P

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..",
                   "assets", "food")
TIERS = ["raw", "undercooked", "good", "perfect", "overcooked", "burnt"]
FS = 32   # food canvas


def rel(p):
    root = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
    return "res://" + os.path.relpath(os.path.abspath(p), root).replace("\\", "/")


def cook_tint(base, tier):
    """Shift a base colour along the raw -> burnt axis."""
    if tier == "raw":
        return pf.mix(base, P.MEAT_RAW, .62)
    if tier == "undercooked":
        return pf.mix(base, P.MEAT_RAW, .30)
    if tier == "good":
        return base
    if tier == "perfect":
        return pf.mix(base, P.LAMP, .22)
    if tier == "overcooked":
        return pf.mix(base, P.MEAT_BURNT, .38)
    return pf.mix(base, P.MEAT_BURNT, .80)


def finish(sp, tier, cx, cy, r=9, hot=True):
    """Outline the dish, THEN add soft volatiles on top.

    Steam and smoke must never go through the outline pass - a 1px outline
    around a translucent puff turns it into a hard floating pebble. Everything
    soft happens after the silhouette is sealed.
    """
    pf.outline(sp)
    if hot and tier in ("good", "perfect"):
        steam(sp, cx, cy - r + 1, 3, seed=pf.stable_seed(tier) % 97)
    garnish(sp, tier, cx, cy, r)


def garnish(sp, tier, cx, cy, r=9):
    """Quality flourish. Perfect food sparkles; burnt food smokes. This is the
    at-a-glance read the player actually uses mid-service."""
    if tier == "perfect":
        for i, (dx, dy) in enumerate(((-r, -r + 2), (r - 1, -r), (0, -r - 2),
                                      (r - 3, r - 4))):
            c = P.LAMP_HOT if i % 2 else P.UI_STAR
            sp.px(cx + dx, cy + dy, c)
            sp.px(cx + dx - 1, cy + dy, pf.mix(c, P.LAMP, .5))
            sp.px(cx + dx, cy + dy - 1, pf.mix(c, P.LAMP, .5))
    elif tier == "burnt":
        for i in range(4):
            m = pf.m_blob(sp.w, sp.h, cx - 3 + i * 2, cy - r - i * 3,
                          2.4 + i * .7, 3, seed=i + 20)
            pf.render_solid(sp, m, pf.ramp(P.STONE, spread=.14), bulge=.7,
                            ambient=.44, rim=False,
                            alpha=max(30, 130 - i * 26))
    elif tier == "overcooked":
        for i in range(2):
            m = pf.m_blob(sp.w, sp.h, cx + i * 3, cy - r - i * 3, 2.0, 3,
                          seed=i + 44)
            pf.render_solid(sp, m, pf.ramp(P.STONE, spread=.12), bulge=.6,
                            ambient=.42, rim=False, alpha=70 - i * 20)
    elif tier == "raw":
        # cold shimmer
        sp.px(cx - r + 1, cy - r + 2, pf.hex2rgb("#bcd8f0"))
        sp.px(cx + r - 2, cy - r + 3, pf.hex2rgb("#bcd8f0"))


def steam(sp, cx, cy, n=3, seed=0):
    for i in range(n):
        m = pf.m_blob(sp.w, sp.h, cx - 2 + i * 3, cy - 8 - i * 4,
                      2.0 + i * .5, 3, seed=seed + i)
        pf.render_solid(sp, m, pf.ramp(P.CHALK, spread=.10), bulge=.6,
                        ambient=.60, rim=False, alpha=max(28, 110 - i * 30))


# ============================================================== DISHES ======
def dish_dragon_steak(tier):
    """Blaze's signature. A slab of dragon-cattle with a charred crust."""
    sp = pf.Sprite(FS, FS)
    base = cook_tint(P.MEAT_COOKED, tier)
    m = pf.m_blob(FS, FS, 16, 18, 11, 3, seed=2, wob=.22)
    pf.render_solid(sp, m, pf.ramp(base, spread=.22), bulge=.9, ambient=.34)
    # sear marks (not on raw)
    if tier not in ("raw",):
        for i in range(3):
            sp.line(8 + i * 5, 12 + i, 12 + i * 5, 24 + i,
                    pf.mix(base, P.MEAT_BURNT, .55))
    # bone handle - the silhouette hook that makes it read as a STEAK
    pf.render_solid(sp, pf.m_capsule(FS, FS, 24, 12, 29, 7, 2.2),
                    pf.ramp(P.BONE, spread=.16), bulge=.9, ambient=.44)
    pf.render_solid(sp, pf.m_ellipse(FS, FS, 29, 6, 2.6, 2.2),
                    pf.ramp(P.BONE, spread=.16), bulge=1.0, ambient=.46)
    if tier in ("good", "perfect"):
        for i in range(3):
            sp.px(11 + i * 4, 13 + (i % 2), pf.hex2rgb(P.LEAF_LIGHT))
    finish(sp, tier, 16, 18, 11)
    return sp


def dish_soul_soup(tier):
    """Bowl of glowing broth. The glow tracks quality."""
    sp = pf.Sprite(FS, FS)
    base = cook_tint(P.SOUP_BASE, tier)
    bowl = pf.m_ellipse(FS, FS, 16, 20, 12, 8) & ~pf.m_rect(FS, FS, 0, 0, FS, 15)
    pf.render_solid(sp, bowl, pf.ramp(P.CHALK, spread=.14), bulge=.6, flat=.3,
                    ambient=.48)
    broth = pf.m_ellipse(FS, FS, 16, 15, 10.5, 4)
    pf.render_solid(sp, broth, pf.ramp(base, spread=.22), bulge=.35, flat=.6,
                    ambient=.46, rim=False)
    if tier in ("good", "perfect"):
        pf.glow(sp, 16, 15, 11, pf.hex2rgb(P.MAGIC_LIGHT), .40)
        for i, (dx, dy) in enumerate(((-4, -1), (3, 1), (6, -1))):
            pf.render_solid(sp, pf.m_ellipse(FS, FS, 16 + dx, 15 + dy, 1.8, 1.2),
                            pf.ramp(P.MAGIC_LIGHT, spread=.12), bulge=.8,
                            ambient=.60, rim=False)
    else:
        for dx in (-4, 2):
            sp.px(16 + dx, 15, pf.mix(base, P.INK, .3))
    pf.render_solid(sp, pf.m_ellipse(FS, FS, 16, 27, 6, 2),
                    pf.ramp(P.CHALK, spread=.12), bulge=.5, ambient=.44)
    finish(sp, tier, 16, 16, 11)
    return sp


def dish_slime_pudding(tier):
    """Wobbling dessert. Gloop's favourite and a total mess when burnt."""
    sp = pf.Sprite(FS, FS)
    base = cook_tint(P.SLIME_BODY, tier)
    m = pf.m_poly(FS, FS, [(7, 25), (25, 25), (21, 9), (11, 9)])
    m |= pf.m_ellipse(FS, FS, 16, 9, 5, 3)
    pf.render_solid(sp, m, pf.ramp(base, spread=.24), bulge=.85, ambient=.38)
    pf.render_solid(sp, pf.m_ellipse(FS, FS, 13, 12, 2.2, 1.6),
                    pf.ramp(pf.mix(base, P.CHALK, .5), spread=.12), bulge=.7,
                    ambient=.62, rim=False)
    # cherry on top, unless it is ruined
    if tier not in ("burnt", "overcooked"):
        pf.render_solid(sp, pf.m_ellipse(FS, FS, 16, 6, 2.6, 2.6),
                        pf.ramp(P.MUSHROOM, spread=.18), bulge=1.0, ambient=.40)
        sp.px(16, 3, pf.hex2rgb(P.LEAF))
    pf.render_solid(sp, pf.m_ellipse(FS, FS, 16, 26, 10, 2.6),
                    pf.ramp(P.CHALK, spread=.12), bulge=.5, ambient=.46)
    finish(sp, tier, 16, 16, 10)
    return sp


def dish_blood_pasta(tier):
    """Countess Vex's order. Crimson sauce, exact portion, no exceptions."""
    sp = pf.Sprite(FS, FS)
    base = cook_tint("#c33a4f", tier)
    pf.render_solid(sp, pf.m_ellipse(FS, FS, 16, 20, 12.5, 6),
                    pf.ramp(P.CHALK, spread=.14), bulge=.5, flat=.4, ambient=.50)
    noodles = pf.m_ellipse(FS, FS, 16, 17, 9.5, 4.5)
    pf.render_solid(sp, noodles, pf.ramp(P.BREAD, spread=.18), bulge=.5,
                    flat=.4, ambient=.44, rim=False)
    for i in range(5):
        sp.line(8 + i * 4, 15 + (i % 2), 10 + i * 4, 20 - (i % 2),
                pf.mix(P.BREAD, P.INK, .28))
    sauce = pf.m_blob(FS, FS, 16, 16, 6.5, 3, seed=9, wob=.30) & noodles
    pf.render_solid(sp, sauce, pf.ramp(base, spread=.22), bulge=.6,
                    ambient=.42, rim=False)
    if tier in ("good", "perfect"):
        for dx, dy in ((-3, -2), (2, 1), (5, -1)):
            sp.px(16 + dx, 15 + dy, pf.hex2rgb(P.LEAF_LIGHT))
    finish(sp, tier, 16, 17, 11)
    return sp


def dish_ember_pie(tier):
    sp = pf.Sprite(FS, FS)
    base = cook_tint(P.BREAD, tier)
    crust = pf.m_ellipse(FS, FS, 16, 19, 12, 7)
    pf.render_solid(sp, crust, pf.ramp(base, spread=.20), bulge=.7, ambient=.40)
    for i in range(6):
        a = i / 6 * math.pi
        sp.line(16 - math.cos(a) * 10, 19 - math.sin(a) * 5,
                16 - math.cos(a) * 6, 19 - math.sin(a) * 3,
                pf.mix(base, P.INK, .30))
    vent = pf.m_ellipse(FS, FS, 16, 17, 4, 2.2)
    pf.render_solid(sp, vent, pf.ramp(cook_tint(P.EMBER, tier), spread=.20),
                    bulge=.5, ambient=.52, rim=False)
    if tier in ("good", "perfect"):
        pf.glow(sp, 16, 17, 8, pf.hex2rgb(P.EMBER), .45)
    # crimped rim
    for i in range(9):
        sp.px(5 + i * 3, 22 + (i % 2), pf.mix(base, P.LAMP, .25))
    finish(sp, tier, 16, 18, 11)
    return sp


def dish_moth_dumplings(tier):
    sp = pf.Sprite(FS, FS)
    base = cook_tint("#e2d3b0", tier)
    for i, (dx, dy) in enumerate(((-6, 2), (5, 3), (0, -3))):
        m = pf.m_ellipse(FS, FS, 16 + dx, 18 + dy, 6, 5)
        pf.render_solid(sp, m, pf.ramp(base, spread=.20), bulge=.95,
                        ambient=.42)
        for k in range(3):
            sp.px(13 + dx + k * 2, 14 + dy, pf.mix(base, P.INK, .26))
    pf.render_solid(sp, pf.m_ellipse(FS, FS, 16, 24, 12, 3.4),
                    pf.ramp("#8f6b4a", spread=.16), bulge=.5, ambient=.42)
    finish(sp, tier, 16, 17, 11)
    return sp


def dish_stone_stew(tier):
    sp = pf.Sprite(FS, FS)
    base = cook_tint("#7a6a4a", tier)
    bowl = pf.m_ellipse(FS, FS, 16, 20, 12, 8) & ~pf.m_rect(FS, FS, 0, 0, FS, 15)
    pf.render_solid(sp, bowl, pf.ramp(P.STONE, spread=.16), bulge=.6, flat=.3,
                    ambient=.44)
    pf.render_solid(sp, pf.m_ellipse(FS, FS, 16, 15, 10.5, 4),
                    pf.ramp(base, spread=.22), bulge=.35, flat=.6, ambient=.44,
                    rim=False)
    rng = np.random.RandomState(5)
    for _ in range(5):
        x = rng.randint(9, 23)
        y = rng.randint(13, 17)
        pf.render_solid(sp, pf.m_ellipse(FS, FS, x, y, 2.0, 1.4),
                        pf.ramp(P.STONE_L, spread=.16), bulge=.8, ambient=.44,
                        rim=False)
    finish(sp, tier, 16, 16, 11)
    return sp


def dish_star_tart(tier):
    sp = pf.Sprite(FS, FS)
    base = cook_tint(P.BREAD, tier)
    pf.render_solid(sp, pf.m_ellipse(FS, FS, 16, 20, 11, 6),
                    pf.ramp(base, spread=.20), bulge=.6, flat=.4, ambient=.42)
    pf.render_solid(sp, pf.m_ellipse(FS, FS, 16, 18, 8.5, 4.2),
                    pf.ramp(cook_tint(P.MAGIC, tier), spread=.22), bulge=.4,
                    ambient=.48, rim=False)
    st = pf.m_star(FS, FS, 16, 17, 5.0, 2.2, 5, -math.pi / 2)
    pf.render_solid(sp, st, pf.ramp(cook_tint(P.UI_STAR, tier), spread=.18),
                    bulge=.7, ambient=.52, rim=False)
    if tier in ("good", "perfect"):
        pf.glow(sp, 16, 17, 10, pf.hex2rgb(P.MAGIC_LIGHT), .45)
    finish(sp, tier, 16, 18, 11)
    return sp


DISHES = {
    "dragon_steak": dish_dragon_steak,
    "soul_soup": dish_soul_soup,
    "slime_pudding": dish_slime_pudding,
    "blood_pasta": dish_blood_pasta,
    "ember_pie": dish_ember_pie,
    "moth_dumplings": dish_moth_dumplings,
    "stone_stew": dish_stone_stew,
    "star_tart": dish_star_tart,
}


# ========================================================= INGREDIENTS ======
IS = 24


def ing_generic(base, shape, seed=0, accent=None):
    sp = pf.Sprite(IS, IS)
    if shape == "round":
        m = pf.m_ellipse(IS, IS, 12, 13, 8, 8)
    elif shape == "long":
        m = pf.m_capsule(IS, IS, 6, 16, 18, 7, 4.0)
    elif shape == "leaf":
        m = pf.m_ellipse(IS, IS, 12, 12, 5, 9)
    elif shape == "chunk":
        m = pf.m_blob(IS, IS, 12, 13, 8, 4, seed=seed, wob=.34)
    elif shape == "cluster":
        m = (pf.m_ellipse(IS, IS, 8, 15, 5, 5) | pf.m_ellipse(IS, IS, 15, 13, 5, 5)
             | pf.m_ellipse(IS, IS, 12, 8, 4.5, 4.5))
    else:
        m = pf.m_round_rect(IS, IS, 4, 5, 16, 15, 3)
    pf.render_solid(sp, m, pf.ramp(base, spread=.22), bulge=.95, ambient=.36)
    if shape == "leaf":
        sp.line(12, 4, 12, 21, pf.mix(base, P.INK, .35))
        for i in range(4):
            sp.line(12, 7 + i * 3, 8 + (i % 2), 9 + i * 3, pf.mix(base, P.INK, .25))
            sp.line(12, 7 + i * 3, 16 - (i % 2), 9 + i * 3, pf.mix(base, P.INK, .25))
    if accent:
        pf.render_solid(sp, pf.m_ellipse(IS, IS, 12, 6, 3, 2.4),
                        pf.ramp(accent, spread=.16), bulge=.8, ambient=.44,
                        rim=False)
    pf.outline(sp)
    return sp


def ing_mushroom(base):
    sp = pf.Sprite(IS, IS)
    pf.render_solid(sp, pf.m_capsule(IS, IS, 12, 21, 12, 13, 2.8),
                    pf.ramp(P.BONE, spread=.14), bulge=.8, ambient=.46)
    cap = pf.m_ellipse(IS, IS, 12, 11, 9, 6.5) & ~pf.m_rect(IS, IS, 0, 12, IS, 12)
    pf.render_solid(sp, cap, pf.ramp(base, spread=.22), bulge=1.0, ambient=.34)
    for dx, dy in ((-4, 8), (2, 6), (5, 9)):
        pf.render_solid(sp, pf.m_ellipse(IS, IS, 12 + dx, dy, 1.5, 1.2),
                        pf.ramp(P.CHALK, spread=.10), bulge=.7, ambient=.62,
                        rim=False)
    pf.outline(sp)
    return sp


def ing_bottle(base):
    sp = pf.Sprite(IS, IS)
    body = pf.m_round_rect(IS, IS, 6, 9, 12, 13, 3)
    pf.render_solid(sp, body, pf.ramp(base, spread=.24), bulge=.9, ambient=.38)
    pf.render_solid(sp, pf.m_rect(IS, IS, 10, 3, 4, 7),
                    pf.ramp(pf.mix(base, P.CHALK, .35), spread=.16), bulge=.8,
                    ambient=.46)
    pf.render_solid(sp, pf.m_rect(IS, IS, 9, 1, 6, 3),
                    pf.ramp(P.OAK_DARK, spread=.16), bulge=.7, ambient=.40)
    sp.px(8, 12, pf.mix(base, P.CHALK, .6))
    sp.px(8, 13, pf.mix(base, P.CHALK, .45))
    pf.glow(sp, 12, 15, 8, pf.hex2rgb(base), .30)
    pf.outline(sp)
    return sp


INGREDIENTS = {
    "dragon_beef": (P.MEAT_RAW, "chunk"),
    "shadow_herb": (P.LEAF_DEEP, "leaf"),
    "ember_pepper": (P.FLAME, "long"),
    "moon_berry": (P.BERRY, "cluster"),
    "cave_mushroom": (P.MUSHROOM, "mush"),
    "ghost_mushroom": ("#cfe4ff", "mush"),
    "gold_mushroom": (P.CHEESE, "mush"),
    "frost_root": ("#9fc4cf", "long"),
    "bone_meal": (P.BONE, "round"),
    "wheat_flour": (P.BREAD, "round"),
    "night_cheese": (P.CHEESE, "chunk"),
    "witch_salt": (P.SUGAR, "round"),
    "star_syrup": (P.MAGIC, "bottle"),
    "crimson_sap": ("#c33a4f", "bottle"),
    "swamp_greens": (P.LEAF, "leaf"),
    "thunder_egg": ("#e8e0c4", "round"),
}


def build(manifest):
    for name, fn in DISHES.items():
        frames = [fn(t) for t in TIERS]
        p, fw, fh, n = pf.sheet(frames, os.path.join(OUT, "dishes", name + ".png"))
        manifest.append({"kind": "food", "group": "dish", "id": name,
                         "path": rel(p), "fw": fw, "fh": fh, "frames": n,
                         "labels": TIERS})
    for name, (base, shape) in INGREDIENTS.items():
        if shape == "mush":
            sp = ing_mushroom(base)
        elif shape == "bottle":
            sp = ing_bottle(base)
        else:
            sp = ing_generic(base, shape, seed=pf.stable_seed(name) % 500)
        p = sp.save(os.path.join(OUT, "ingredients", name + ".png"))
        manifest.append({"kind": "food", "group": "ingredient", "id": name,
                         "path": rel(p), "w": sp.w, "h": sp.h})
    print("  food: %d dishes x %d tiers, %d ingredients"
          % (len(DISHES), len(TIERS), len(INGREDIENTS)))
    return manifest


if __name__ == "__main__":
    build([])
