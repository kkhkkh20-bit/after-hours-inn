"""
Original VFX sprite sheets.

Effects are pixel art too - no soft additive quads, no blurred textures. Each
effect is a looping or one-shot strip built from the same solids and ramps as
the world art, so a fire in the kitchen belongs to the same drawing as the
stove it sits on.
"""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixelforge as pf
import palette as P

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..",
                   "assets", "vfx")


def rel(p):
    root = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
    return "res://" + os.path.relpath(os.path.abspath(p), root).replace("\\", "/")


def fx_fire(n=6, w=32, h=40):
    """Stove flame. Layered tongues, hottest core last."""
    out = []
    for f in range(n):
        sp = pf.Sprite(w, h)
        t = f / n * math.tau
        for li, (c, sc, dy) in enumerate([(P.FLAME, 1.0, 0),
                                          (P.EMBER, .74, 5),
                                          (P.FLAME_CORE, .48, 10),
                                          (P.LAMP_HOT, .24, 15)]):
            pts = []
            base = 12 * sc
            tip = 30 * sc
            for i in range(7):
                u = i / 6
                x = w / 2 + math.sin(t + u * 3 + li) * (3 * sc) * u
                y = h - 4 - dy - u * tip
                rr = base * (1 - u) * .5 + 1
                pts.append((x, y, rr))
            m = np.zeros((h, w), bool)
            for i in range(len(pts) - 1):
                x0, y0, r0 = pts[i]
                x1, y1, _ = pts[i + 1]
                m |= pf.m_capsule(w, h, x0, y0, x1, y1, r0)
            pf.render_solid(sp, m, pf.ramp(c, spread=.14), bulge=.7,
                            ambient=.60, rim=False, contrast=1.0)
        # rising sparks
        rng = np.random.RandomState(f)
        for _ in range(4):
            sx = w / 2 + rng.randint(-7, 8)
            sy = h - 18 - ((f * 5 + rng.randint(0, 20)) % 22)
            sp.px(sx, sy, P.LAMP_HOT)
        out.append(sp)
    return out


def fx_smoke(n=8, w=32, h=44):
    out = []
    for f in range(n):
        sp = pf.Sprite(w, h)
        t = f / n
        for i in range(4):
            u = (t + i * .25) % 1.0
            y = h - 6 - u * 34
            x = w / 2 + math.sin(u * 5 + i) * 6
            r = 2.5 + u * 6
            a = int(max(0, 150 * (1 - u) ** 1.4))
            if a < 8:
                continue
            m = pf.m_blob(w, h, x, y, r, 3, seed=i * 3 + f)
            pf.render_solid(sp, m, pf.ramp(P.STONE, spread=.12), bulge=.6,
                            ambient=.50, rim=False, alpha=a, contrast=1.0)
        out.append(sp)
    return out


def fx_steam(n=8, w=28, h=36):
    out = []
    for f in range(n):
        sp = pf.Sprite(w, h)
        t = f / n
        for i in range(3):
            u = (t + i / 3) % 1.0
            y = h - 4 - u * 28
            x = w / 2 + math.sin(u * 6 + i * 2) * 5
            r = 2.0 + u * 4.5
            a = int(max(0, 130 * (1 - u) ** 1.3))
            if a < 8:
                continue
            m = pf.m_blob(w, h, x, y, r, 3, seed=i + f * 2)
            pf.render_solid(sp, m, pf.ramp(P.CHALK, spread=.08), bulge=.6,
                            ambient=.66, rim=False, alpha=a, contrast=1.0)
        out.append(sp)
    return out


def fx_sparkle(n=6, w=32, h=32):
    """Perfect-dish burst. The single most important positive feedback."""
    out = []
    for f in range(n):
        sp = pf.Sprite(w, h)
        u = f / (n - 1)
        for i in range(6):
            a = i / 6 * math.tau + u * .6
            d = 3 + u * 12
            x, y = 16 + math.cos(a) * d, 16 + math.sin(a) * d
            s = max(0.6, (1 - u) * 3.4)
            m = pf.m_star(w, h, x, y, s, s * .38, 4, a)
            c = P.UI_STAR if i % 2 else P.LAMP_HOT
            pf.render_solid(sp, m, pf.ramp(c, spread=.14), bulge=.6,
                            ambient=.70, rim=False, contrast=1.0,
                            alpha=int(255 * (1 - u * .7)))
        cs = max(0.5, (1 - u) * 7)
        m = pf.m_star(w, h, 16, 16, cs, cs * .35, 4, u * 1.2)
        pf.render_solid(sp, m, pf.ramp(P.LAMP_HOT, spread=.10), bulge=.6,
                        ambient=.80, rim=False, contrast=1.0,
                        alpha=int(255 * (1 - u * .5)))
        out.append(sp)
    return out


def fx_puff(n=5, w=28, h=28):
    """Generic dust/impact puff - chopping, footsteps, dropped plates."""
    out = []
    for f in range(n):
        sp = pf.Sprite(w, h)
        u = f / (n - 1)
        for i in range(5):
            a = i / 5 * math.tau
            d = 2 + u * 9
            x, y = 14 + math.cos(a) * d, 16 + math.sin(a) * d * .5
            r = max(.8, 4 * (1 - u))
            m = pf.m_blob(w, h, x, y, r, 3, seed=i + f)
            pf.render_solid(sp, m, pf.ramp("#c9b89c", spread=.12), bulge=.6,
                            ambient=.56, rim=False, contrast=1.0,
                            alpha=int(190 * (1 - u)))
        out.append(sp)
    return out


def fx_slime_bubble(n=6, w=24, h=24):
    out = []
    for f in range(n):
        sp = pf.Sprite(w, h)
        u = f / (n - 1)
        r = 2 + u * 7
        m = pf.m_ellipse(w, h, 12, 14 - u * 4, r, r * .92)
        pf.render_solid(sp, m, pf.ramp(P.SLIME_CORE, spread=.16), bulge=.9,
                        ambient=.52, rim=False, alpha=int(200 * (1 - u * .55)))
        if u > .7:   # pop
            for i in range(6):
                a = i / 6 * math.tau
                sp.px(12 + math.cos(a) * (r + 2), 14 - u * 4 + math.sin(a) * (r + 2),
                      P.SLIME_CORE)
        else:
            sp.px(12 - r * .4, 14 - u * 4 - r * .4, P.CHALK)
        out.append(sp)
    return out


def fx_heart(n=6, w=24, h=28):
    """Relationship gain."""
    out = []
    for f in range(n):
        sp = pf.Sprite(w, h)
        u = f / (n - 1)
        y = 20 - u * 16
        s = .7 + math.sin(u * math.pi) * .5
        m = (pf.m_ellipse(w, h, 12 - 2.4 * s, y, 3.2 * s, 3.0 * s)
             | pf.m_ellipse(w, h, 12 + 2.4 * s, y, 3.2 * s, 3.0 * s)
             | pf.m_poly(w, h, [(12 - 5.4 * s, y + 1), (12 + 5.4 * s, y + 1),
                                (12, y + 6.6 * s)]))
        pf.render_solid(sp, m, pf.ramp("#e0506a", spread=.18), bulge=.9,
                        ambient=.46, alpha=int(255 * (1 - max(0, u - .6) * 2.4)))
        pf.outline(sp)
        out.append(sp)
    return out


def fx_anger(n=5, w=24, h=24):
    out = []
    for f in range(n):
        sp = pf.Sprite(w, h)
        u = f / (n - 1)
        s = 1 + math.sin(u * math.pi) * .5
        c = pf.hex2rgb(P.UI_BAD)
        for k in range(2):
            o = k * 6
            sp.line(6 + o, 6, 6 + o + 4 * s, 6 + 4 * s, c)
            sp.line(6 + o + 4 * s, 6, 6 + o, 6 + 4 * s, c)
        sp.line(8, 14, 15, 14, c)
        sp.line(9, 16, 14, 16, c)
        out.append(sp)
    return out


def fx_coin(n=6, w=20, h=28):
    out = []
    for f in range(n):
        sp = pf.Sprite(w, h)
        u = f / (n - 1)
        y = 20 - math.sin(u * math.pi) * 14
        rx = abs(math.cos(u * math.tau)) * 6 + 1.2   # spin
        m = pf.m_ellipse(w, h, 10, y, rx, 6)
        pf.render_solid(sp, m, pf.ramp(P.UI_GOLD, spread=.20), bulge=.9,
                        ambient=.44, alpha=int(255 * (1 - max(0, u - .7) * 3)))
        pf.outline(sp)
        out.append(sp)
    return out


def fx_magic(n=8, w=32, h=32):
    out = []
    for f in range(n):
        sp = pf.Sprite(w, h)
        t = f / n * math.tau
        for i in range(7):
            a = t + i / 7 * math.tau
            d = 5 + math.sin(t * 2 + i) * 5
            x, y = 16 + math.cos(a) * d, 16 + math.sin(a) * d * .7
            m = pf.m_ellipse(w, h, x, y, 1.8, 1.8)
            pf.render_solid(sp, m, pf.ramp(P.MAGIC_LIGHT, spread=.14),
                            bulge=.9, ambient=.66, rim=False, contrast=1.0)
        pf.glow(sp, 16, 16, 14, pf.hex2rgb(P.MAGIC), .45)
        out.append(sp)
    return out


def fx_rain(n=4, w=64, h=64):
    """Tiling rain overlay for the town in bad weather."""
    out = []
    for f in range(n):
        sp = pf.Sprite(w, h)
        rng = np.random.RandomState(7)
        for _ in range(46):
            x = rng.randint(0, w)
            y = (rng.randint(0, h) + f * (h // n)) % h
            sp.line(x, y, x - 2, y + 6, pf.mix("#a8c8e8", P.DUSK, .35), 170)
            sp.px(x - 2, y + 6, pf.hex2rgb("#cfe4ff"), 200)
        out.append(sp)
    return out


def fx_slash(n=4, w=32, h=32):
    """Knife chop impact - sells the cutting minigame."""
    out = []
    for f in range(n):
        sp = pf.Sprite(w, h)
        u = f / (n - 1)
        for k in range(3):
            off = k * 3 - 3
            x0, y0 = 4 + u * 6 + off, 26 - u * 4
            x1, y1 = 26 - u * 4 + off, 6 + u * 6
            m = pf.m_capsule(w, h, x0, y0, x1, y1, max(.6, 2.2 * (1 - u)))
            pf.render_solid(sp, m, pf.ramp(P.CHALK, spread=.10), bulge=.5,
                            ambient=.78, rim=False, contrast=1.0,
                            alpha=int(220 * (1 - u)))
        out.append(sp)
    return out


def fx_dustmote(n=8, w=64, h=64):
    """Ambient floating dust for the restaurant interior."""
    out = []
    rng = np.random.RandomState(3)
    motes = [(rng.randint(0, w), rng.randint(0, h), rng.uniform(.3, 1.0))
             for _ in range(18)]
    for f in range(n):
        sp = pf.Sprite(w, h)
        t = f / n
        for (mx, my, sp_) in motes:
            y = (my - t * 10 * sp_) % h
            x = (mx + math.sin(t * math.tau + my) * 3) % w
            a = int(60 + 60 * math.sin(t * math.tau + mx))
            sp.px(x, y, pf.hex2rgb(P.LAMP_HOT), max(20, a))
        out.append(sp)
    return out


EFFECTS = {
    "fire": (fx_fire, 6), "smoke": (fx_smoke, 8), "steam": (fx_steam, 8),
    "sparkle": (fx_sparkle, 6), "puff": (fx_puff, 5),
    "slime_bubble": (fx_slime_bubble, 6), "heart": (fx_heart, 6),
    "anger": (fx_anger, 5), "coin": (fx_coin, 6), "magic": (fx_magic, 8),
    "rain": (fx_rain, 4), "slash": (fx_slash, 4), "dust": (fx_dustmote, 8),
}


def build(manifest):
    for name, (fn, n) in EFFECTS.items():
        frames = fn(n)
        p, fw, fh, cnt = pf.sheet(frames, os.path.join(OUT, name + ".png"))
        manifest.append({"kind": "vfx", "id": name, "path": rel(p),
                         "fw": fw, "fh": fh, "frames": cnt})
    print("  vfx: %d effects" % len(EFFECTS))
    return manifest


if __name__ == "__main__":
    build([])
