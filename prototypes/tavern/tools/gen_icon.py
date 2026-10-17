"""Application icon - the restaurant sign motif at 128px."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixelforge as pf
import palette as P

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..",
                   "assets", "ui", "brand")


def rel(p):
    root = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
    return "res://" + os.path.relpath(os.path.abspath(p), root).replace("\\", "/")


def icon():
    S = 128
    sp = pf.Sprite(S, S)
    pf.render_solid(sp, pf.m_round_rect(S, S, 4, 4, S - 8, S - 8, 10),
                    pf.ramp(P.OAK_WARM, spread=.20), bulge=.4, flat=.75,
                    ambient=.42)
    pf.render_solid(sp, pf.m_round_rect(S, S, 10, 10, S - 20, S - 20, 7),
                    pf.ramp(P.DUSK, spread=.16), bulge=.3, flat=.9,
                    ambient=.46, rim=False)
    # cloche over a plate
    pf.render_solid(sp, pf.m_ellipse(S, S, 64, 92, 44, 10),
                    pf.ramp(P.CHALK, spread=.14), bulge=.5, ambient=.52)
    dome = pf.m_ellipse(S, S, 64, 88, 36, 34) & ~pf.m_rect(S, S, 0, 88, S, S)
    pf.render_solid(sp, dome, pf.ramp(P.STONE_L, spread=.20), bulge=1.0,
                    ambient=.38)
    pf.render_solid(sp, pf.m_ellipse(S, S, 64, 50, 6, 6),
                    pf.ramp(P.UI_GOLD, spread=.18), bulge=1.0, ambient=.46)
    # two horns rising behind the cloche: monsters, not fine dining
    for side in (-1, 1):
        m = pf.m_capsule(S, S, 64 + side * 30, 74, 64 + side * 46, 34, 7)
        pf.render_solid(sp, m, pf.ramp(pf.mix(P.DRAGON_HORN, P.OAK, .35),
                                       spread=.18),
                        bulge=.9, ambient=.34)
    # eyes glowing under the dome
    for side in (-1, 1):
        pf.render_solid(sp, pf.m_ellipse(S, S, 64 + side * 13, 80, 6, 7),
                        pf.ramp(P.LAMP_HOT, spread=.12), bulge=.9,
                        ambient=.70, rim=False)
        pf.glow(sp, 64 + side * 13, 80, 12, pf.hex2rgb(P.LAMP), .5)
    pf.outline(sp)
    return sp


def build(manifest):
    p = icon().save(os.path.join(OUT, "icon.png"))
    manifest.append({"kind": "ui", "group": "brand", "id": "icon",
                     "path": rel(p), "w": 128, "h": 128})
    print("  icon: 128x128")
    return manifest


if __name__ == "__main__":
    build([])
