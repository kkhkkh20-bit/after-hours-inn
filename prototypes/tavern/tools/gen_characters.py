"""
Original character sprites for Restaurant for Monsters.

Each character is authored as a rig: a function that takes a pose (limb
angles, squash, breathing offset, expression) and builds the sprite from
shaded solids. Animation frames are re-posed rather than pixel-shifted, so
every frame is genuinely redrawn and the volumes stay correct - that is what
gives the walk cycles weight instead of the sliding-cutout look.

Silhouette budget (see CLAUDE.md):
    player   72px tall     slime  56px     ghost 64px
    vampire  88px tall     golem  80px     witch 76px
    dragon  116px tall

Expressions are a separate overlay pass so any body pose can carry any face.
"""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixelforge as pf
import palette as P

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                   "..", "assets", "characters")

EXPRESSIONS = ["neutral", "happy", "excited", "hungry", "confused", "angry",
               "shocked", "embarrassed", "sad", "proud", "satisfied", "surprised"]


# ---------------------------------------------------------------- helpers ---
def eye(sp, cx, cy, rx, ry, white, iris, pupil, look=(0, 0), lid=0.0,
        shine=True):
    """A readable expressive eye. `lid` closes from the top, `look` shifts the
    iris. Eyes are the single most important cluster on every character, so
    they get a dedicated routine rather than being drawn inline."""
    m = pf.m_ellipse(sp.w, sp.h, cx, cy, rx, ry)
    if lid > 0:
        cut = pf.m_rect(sp.w, sp.h, 0, 0, sp.w, cy - ry + 2 * ry * lid)
        m = m & ~cut
    sp.mask_fill(m, white)
    # socket shadow along the top of the eye
    top = m & pf.m_rect(sp.w, sp.h, 0, 0, sp.w, cy - ry * 0.35)
    sp.mask_fill(top, pf.mix(white, P.INK, 0.22))
    ir = max(1.0, rx * 0.62)
    icx, icy = cx + look[0], cy + look[1] + ry * 0.12
    sp.mask_fill(pf.m_ellipse(sp.w, sp.h, icx, icy, ir, ir) & m, iris)
    sp.mask_fill(pf.m_ellipse(sp.w, sp.h, icx, icy, ir * 0.52, ir * 0.62) & m, pupil)
    if shine:
        sp.px(icx - ir * 0.5, icy - ir * 0.55, P.CHALK)
        sp.px(icx - ir * 0.5 + 1, icy - ir * 0.55, pf.mix(P.CHALK, iris, .35))


def brow(sp, x0, y0, x1, y1, col, thick=2):
    for t in range(thick):
        sp.line(x0, y0 + t, x1, y1 + t, col)


def mouth_arc(sp, cx, cy, w, curve, col, thick=1):
    """curve > 0 smiles, < 0 frowns, 0 is a flat line."""
    for i in range(-w, w + 1):
        t = i / max(w, 1)
        y = cy - curve * (1 - t * t)
        for k in range(thick):
            sp.px(cx + i, y + k, col)


def blush(sp, cx, cy, r, col=(232, 120, 128), a=110):
    m = pf.m_ellipse(sp.w, sp.h, cx, cy, r, r * 0.62)
    ys, xs = np.nonzero(m)
    for y, x in zip(ys, xs):
        p = sp.get(int(x), int(y))
        if p[3]:
            sp.px(int(x), int(y), pf.mix(p[:3], col, a / 255), p[3])


def sweat(sp, x, y, col=(168, 214, 255)):
    sp.px(x, y, col)
    sp.px(x, y + 1, col)
    sp.px(x - 1, y + 1, col)
    sp.px(x + 1, y + 1, col)
    sp.px(x, y + 2, pf.mix(col, P.CHALK, .6))


def anger_mark(sp, x, y, col=(232, 76, 60)):
    sp.line(x, y, x + 3, y + 3, col)
    sp.line(x + 3, y, x, y + 3, col)
    sp.px(x + 1, y + 1, col)


# =========================================================== THE COOK =======
# The player. Human, small, quick. Reads instantly by the white apron wedge
# and the red sleeves - the two loudest clusters in the silhouette.
PW, PH = 48, 72


SKIN = None  # built lazily; skin needs a flatter, less saturated ramp than
             # cloth or the rim light turns every face into an orange smear.


def skin_ramp(base):
    return pf.ramp(base, spread=0.17, hue_shift=0.018, sat_curve=0.40)


def cook(pose=None, expr="neutral", carry=None):
    p = {"bob": 0, "lean": 0, "armL": 0.0, "armR": 0.0, "legL": 0.0,
         "legR": 0.0, "squash": 0.0, "turn": 0}
    p.update(pose or {})
    sp = pf.Sprite(PW, PH)
    cx = PW // 2 + p["turn"]
    bob = p["bob"]
    sq = p["squash"]

    # STARDEW PROPORTIONS: the head is roughly 40% of total height and the
    # body is short and stubby underneath it. Anatomically-correct ratios read
    # as a stiff little mannequin; this reads as a character.
    hip_y = 58 + bob
    sh_y = 44 + bob
    head_y = 24 + bob
    skin = skin_ramp(P.PLAYER_SKIN)

    pf.drop_shadow(sp, np.zeros((PH, PW), bool), PW // 2, 68, 13, 4)

    # legs -------------------------------------------------------------------
    for side, ang in ((-1, p["legL"]), (1, p["legR"])):
        fx = cx + side * 4 + math.sin(ang) * 5
        fy = 66 - abs(math.sin(ang)) * 3
        m = pf.m_capsule(PW, PH, cx + side * 4, hip_y, fx, fy, 3.6)
        pf.render_solid(sp, m, pf.ramp(P.PLAYER_TROUSER), bulge=.9, ambient=.34)
        boot = pf.m_capsule(PW, PH, fx - 2, fy + 2, fx + 3, fy + 2, 3.0)
        pf.render_solid(sp, boot, pf.ramp(P.OAK_DARK), bulge=.8, ambient=.34)

    # torso ------------------------------------------------------------------
    torso = pf.m_capsule(PW, PH, cx + p["lean"], sh_y, cx, hip_y - 4, 9 + sq)
    torso &= ~pf.m_rect(PW, PH, 0, hip_y + 2, PW, PH)
    pf.render_solid(sp, torso, pf.ramp(P.PLAYER_SHIRT), bulge=1.0, ambient=.34)

    # apron: the identity cluster. Narrower than the torso so the red sleeves
    # stay visible either side - the apron reading as the whole body was the
    # first thing that made the cook look like a blank doll.
    ap = pf.m_poly(PW, PH, [(cx - 5, sh_y + 5), (cx + 5, sh_y + 5),
                            (cx + 6, hip_y + 3), (cx - 6, hip_y + 3)])
    ap &= pf.dilate(torso)
    pf.render_solid(sp, ap, pf.ramp(P.PLAYER_APRON), bulge=.55, flat=.5,
                    ambient=.46)
    strap = pf.mix(P.PLAYER_APRON, P.INK, .34)
    sp.line(cx - 4, sh_y + 4, cx - 2, sh_y - 1, strap)
    sp.line(cx + 4, sh_y + 4, cx + 2, sh_y - 1, strap)
    # apron pocket + a stain, because this apron has seen service
    sp.line(cx - 4, hip_y - 6, cx + 4, hip_y - 6, pf.mix(P.PLAYER_APRON, P.OAK, .5))
    sp.line(cx - 4, hip_y - 6, cx - 4, hip_y - 2, pf.mix(P.PLAYER_APRON, P.OAK, .5))
    sp.line(cx + 4, hip_y - 6, cx + 4, hip_y - 2, pf.mix(P.PLAYER_APRON, P.OAK, .5))
    sp.px(cx + 2, hip_y - 9, pf.mix(P.PLAYER_APRON, P.SOUP_BASE, .55))
    sp.px(cx + 3, hip_y - 9, pf.mix(P.PLAYER_APRON, P.SOUP_BASE, .4))

    # arms -------------------------------------------------------------------
    for side, ang in ((-1, p["armL"]), (1, p["armR"])):
        sx = cx + side * 7
        hx = sx + side * (2 + math.cos(ang) * 3)
        hy = sh_y + 11 + math.sin(ang) * 8
        m = pf.m_capsule(PW, PH, sx, sh_y + 2, hx, hy, 2.8)
        pf.render_solid(sp, m, pf.ramp(P.PLAYER_SHIRT), bulge=.9, ambient=.30)
        # cuff, so the sleeve reads as a sleeve and not as a bare arm
        sp.line(hx - 2, hy - 2, hx + 2, hy - 2, pf.mix(P.PLAYER_APRON, P.INK, .12))
        hand = pf.m_ellipse(PW, PH, hx, hy + 2, 2.4, 2.4)
        pf.render_solid(sp, hand, skin, bulge=1.0, ambient=.52, rim=False,
                        contrast=1.0)
        if carry is not None and side == 1:
            sp.paste(carry, int(hx - carry.w / 2), int(hy - carry.h - 1))

    # head -------------------------------------------------------------------
    # rim=False on skin: a rim light on a 20px head lands exactly on the chin
    # and reads as an open mouth. Skin gets ambient bounce instead.
    head = pf.m_ellipse(PW, PH, cx, head_y, 13, 14)
    pf.render_solid(sp, head, skin, bulge=1.0, ambient=.62, rim=False)
    ear = pf.m_ellipse(PW, PH, cx - 13, head_y + 3, 2.4, 3.2)
    ear |= pf.m_ellipse(PW, PH, cx + 13, head_y + 3, 2.4, 3.2)
    pf.render_solid(sp, ear, skin, bulge=.9, ambient=.58, rim=False)

    # Hair is one solid shape with a single highlight band - not a shaded
    # volume. That flat, graphic treatment is a Stardew signature.
    hair = (pf.m_ellipse(PW, PH, cx, head_y - 3.5, 13.6, 13.0)
            & ~pf.m_ellipse(PW, PH, cx, head_y + 3.0, 12.0, 11.0))
    hair |= pf.m_ellipse(PW, PH, cx - 12, head_y - 1, 3.2, 5.0)
    hair |= pf.m_ellipse(PW, PH, cx + 12, head_y - 1, 3.2, 5.0)
    hair |= pf.m_poly(PW, PH, [(cx - 12, head_y - 8), (cx + 5, head_y - 11),
                               (cx + 12, head_y - 3), (cx + 2, head_y - 5)])
    hcol = pf.ramp(P.PLAYER_HAIR)
    sp.mask_fill(hair, hcol[1])
    band = hair & pf.m_ellipse(PW, PH, cx - 4, head_y - 10, 8, 4)
    sp.mask_fill(band, hcol[3])

    face_cook(sp, cx, head_y, expr)
    pf.outline(sp)
    return sp


def face_cook(sp, cx, cy, expr):
    ink = pf.hex2rgb(P.INK)
    white = pf.hex2rgb(P.CHALK)
    iris = pf.hex2rgb("#4a6f9c")
    look = (0, 0)
    lid = 0.0
    ex, ey = 3.4, 1.0
    if expr in ("happy", "satisfied"):
        lid = 0.42
    if expr == "excited":
        ex, ey = 3.9, 1.15
    if expr in ("sad", "embarrassed"):
        lid = 0.30
        look = (0, 1)
    if expr == "shocked" or expr == "surprised":
        ex, ey = 4.0, 1.25
    if expr == "confused":
        look = (1, 0)

    eye(sp, cx - 5.4, cy + 2, 3.2 * (ex / 3.4), 3.6 * ey, white, iris, ink, look, lid)
    eye(sp, cx + 5.4, cy + 2, 3.2 * (ex / 3.4), 3.6 * ey, white, iris, ink, look, lid)

    if expr == "angry":
        brow(sp, cx - 6, cy - 2, cx - 2, cy - 1, ink, 1)
        brow(sp, cx + 6, cy - 2, cx + 2, cy - 1, ink, 1)
        mouth_arc(sp, cx, cy + 9, 2, -1, ink)
        anger_mark(sp, cx + 7, cy - 6)
    elif expr in ("happy", "excited", "proud", "satisfied"):
        mouth_arc(sp, cx, cy + 8, 3, 2, ink)
        if expr == "excited":
            blush(sp, cx - 6, cy + 4, 2.6)
            blush(sp, cx + 6, cy + 4, 2.6)
    elif expr in ("shocked", "surprised"):
        sp.mask_fill(pf.m_ellipse(sp.w, sp.h, cx, cy + 6, 1.6, 2.0), ink)
    elif expr == "sad":
        mouth_arc(sp, cx, cy + 6, 2, -1, ink)
    elif expr == "embarrassed":
        mouth_arc(sp, cx, cy + 9, 2, .5, ink)
        blush(sp, cx - 6, cy + 4, 3.0, a=150)
        blush(sp, cx + 6, cy + 4, 3.0, a=150)
        sweat(sp, cx + 8, cy - 4)
    elif expr == "confused":
        mouth_arc(sp, cx + 1, cy + 9, 2, .6, ink)
        brow(sp, cx - 6, cy - 3, cx - 2, cy - 1, ink, 1)
    elif expr == "hungry":
        mouth_arc(sp, cx, cy + 8, 2, 1.4, ink)
        sp.px(cx + 8, cy + 2, (168, 214, 255))
    else:
        mouth_arc(sp, cx, cy + 9, 2, .4, ink)


# ============================================================== BLAZE ======
# Dragon. Proud, impatient, generous. Reads as a wide warm wedge: heavy jaw,
# barrel chest, horns swept back. Biggest silhouette in the game.
DW, DH = 96, 116


def dragon(pose=None, expr="neutral"):
    p = {"bob": 0, "wing": 0.0, "tail": 0.0, "armL": 0.0, "armR": 0.0,
         "legL": 0.0, "legR": 0.0, "squash": 0.0, "jaw": 0.0, "turn": 0}
    p.update(pose or {})
    sp = pf.Sprite(DW, DH)
    cx = DW // 2 + p["turn"]
    bob = p["bob"]
    sq = p["squash"]
    scale = pf.ramp(P.DRAGON_SCALE)
    belly = pf.ramp(P.DRAGON_BELLY)
    horn = pf.ramp(P.DRAGON_HORN)
    wingc = pf.ramp(P.DRAGON_WING)

    # Chibi rebalance: big head, short heavy body.
    hip_y = 90 + bob
    sh_y = 64 + bob
    head_y = 34 + bob

    pf.drop_shadow(sp, np.zeros((DH, DW), bool), cx, 110, 26, 6)

    # tail (behind) ----------------------------------------------------------
    tpts = []
    for i in range(9):
        t = i / 8
        tx = cx + 12 + t * 26
        ty = hip_y - 2 + math.sin(p["tail"] + t * 2.4) * 9 * t + t * 12
        tpts.append((tx, ty, 6.5 * (1 - t) + 1.6))
    for i in range(len(tpts) - 1):
        x0, y0, r0 = tpts[i]
        x1, y1, _ = tpts[i + 1]
        m = pf.m_capsule(DW, DH, x0, y0, x1, y1, r0)
        pf.render_solid(sp, m, scale, bulge=1.0, ambient=.30, rim=False)
    # tail spade
    tx, ty, _ = tpts[-1]
    pf.render_solid(sp, pf.m_poly(DW, DH, [(tx, ty - 5), (tx + 9, ty),
                                           (tx, ty + 5), (tx + 2, ty)]),
                    wingc, bulge=.7, ambient=.34)

    # wings (behind) ---------------------------------------------------------
    for side in (-1, 1):
        spread = 20 + math.sin(p["wing"]) * 9
        base = (cx + side * 10, sh_y - 4)
        tip = (cx + side * (14 + spread), sh_y - 22 - abs(math.sin(p["wing"])) * 8)
        mid = (cx + side * (12 + spread * .55), sh_y + 10)
        m = pf.m_poly(DW, DH, [base, tip,
                               (cx + side * (10 + spread * .75), sh_y - 4), mid])
        pf.render_solid(sp, m, wingc, bulge=.5, flat=.55, ambient=.26, rim=False)
        sp.line(base[0], base[1], tip[0], tip[1], pf.mix(P.DRAGON_WING, P.INK, .4))
        sp.line(base[0], base[1], mid[0], mid[1], pf.mix(P.DRAGON_WING, P.INK, .4))

    # legs -------------------------------------------------------------------
    for side, ang in ((-1, p["legL"]), (1, p["legR"])):
        fx = cx + side * 10 + math.sin(ang) * 8
        fy = 106 - abs(math.sin(ang)) * 5
        m = pf.m_capsule(DW, DH, cx + side * 10, hip_y, fx, fy - 4, 7.0)
        pf.render_solid(sp, m, scale, bulge=1.0, ambient=.30)
        foot = pf.m_capsule(DW, DH, fx - 4, fy, fx + 5, fy, 4.4)
        pf.render_solid(sp, foot, scale, bulge=.85, ambient=.32)
        for c in range(3):
            sp.px(fx + 5 + c % 2, fy - 2 + c * 2, pf.hex2rgb(P.DRAGON_HORN))

    # torso ------------------------------------------------------------------
    torso = pf.m_capsule(DW, DH, cx, sh_y, cx, hip_y - 8, 20 + sq)
    pf.render_solid(sp, torso, scale, bulge=1.05, ambient=.30)
    bel = pf.m_ellipse(DW, DH, cx + 4, (sh_y + hip_y) / 2 + 5, 9, 14) & torso
    pf.render_solid(sp, bel, belly, bulge=.8, flat=.35, ambient=.34, rim=False)
    # belly scutes - horizontal plates, tapering with the belly's width
    for i in range(5):
        yy = int(sh_y + 13 + i * 5)
        half = int(8 - abs(i - 2) * 1.4)
        sp.line(cx + 4 - half, yy, cx + 4 + half, yy,
                pf.mix(P.DRAGON_BELLY, P.INK, .28))
    # back scutes
    for i in range(4):
        yy = sh_y + 4 + i * 8
        m = pf.m_poly(DW, DH, [(cx - 18, yy), (cx - 22, yy - 3), (cx - 18, yy - 6)])
        pf.render_solid(sp, m, horn, bulge=.6, ambient=.36, rim=False)

    # arms - held close to the barrel chest. Arms swung wide read as a T-pose
    # and kill the heavy, self-important posture Blaze is supposed to have.
    for side, ang in ((-1, p["armL"]), (1, p["armR"])):
        sx = cx + side * 15
        hx = sx + side * (1 + math.cos(ang) * 2)
        hy = sh_y + 20 + math.sin(ang) * 7
        m = pf.m_capsule(DW, DH, sx, sh_y + 6, hx, hy, 4.6)
        pf.render_solid(sp, m, scale, bulge=.95, ambient=.28)
        claw = pf.m_ellipse(DW, DH, hx, hy + 3, 4.0, 3.6)
        pf.render_solid(sp, claw, scale, bulge=1.0, ambient=.30)
        for c in range(3):
            sp.px(hx + side * (2 - c), hy + 6, pf.mix(P.DRAGON_HORN, P.OAK, .2))

    # head -------------------------------------------------------------------
    # Built as a wedge: broad skull at the back, tapering to a heavy snout on
    # the right. The taper is what sells "dragon" over "lizard".
    skull = pf.m_ellipse(DW, DH, cx - 1, head_y, 21, 18)
    snout = pf.m_poly(DW, DH, [(cx + 4, head_y - 8), (cx + 26, head_y + 1),
                               (cx + 26, head_y + 9),
                               (cx + 4, head_y + 13 + p["jaw"])])
    cheek = pf.m_ellipse(DW, DH, cx + 4, head_y + 5, 14, 11)
    pf.render_solid(sp, skull | snout | cheek, scale, bulge=1.05, ambient=.28)

    # brow ridge, sitting over the eye
    ridge = pf.m_capsule(DW, DH, cx - 10, head_y - 7, cx + 7, head_y - 6, 3.0)
    pf.render_solid(sp, ridge, pf.ramp(pf.mix(P.DRAGON_SCALE, P.INK, .22)),
                    bulge=.8, ambient=.30, rim=False)

    # horns - anchored at the BACK of the skull, sweeping back and up, in a
    # dull amber bone rather than cream. Bright horns on top of the head read
    # as a crown or a pair of ears.
    hb = pf.ramp(pf.mix(P.DRAGON_HORN, P.OAK, .38))
    for side, dy in ((1, -4), (-1, 2)):
        hx0, hy0 = cx - 6, head_y - 8 + dy
        seg = [(hx0, hy0), (hx0 - 9, hy0 - 5), (hx0 - 18, hy0 - 7)]
        for i in range(len(seg) - 1):
            m = pf.m_capsule(DW, DH, seg[i][0], seg[i][1],
                             seg[i + 1][0], seg[i + 1][1], 3.2 - i * 1.0)
            pf.render_solid(sp, m, hb, bulge=.9, ambient=.28, rim=False)
        pf.render_solid(sp, pf.m_poly(DW, DH, [(seg[-1][0], seg[-1][1] - 2),
                                               (seg[-1][0] - 5, seg[-1][1]),
                                               (seg[-1][0], seg[-1][1] + 2)]),
                        hb, bulge=.7, ambient=.30, rim=False)
        for i in range(3):
            sp.px(hx0 - 4 - i * 5, hy0 - 3 - i * 2,
                  pf.mix(pf.mix(P.DRAGON_HORN, P.OAK, .38), P.INK, .40))

    # cheek frill - small, tight to the jaw, behind the head
    for dy in (-2, 3):
        m = pf.m_poly(DW, DH, [(cx - 12, head_y + dy),
                               (cx - 21, head_y + dy + 4),
                               (cx - 12, head_y + dy + 6)])
        pf.render_solid(sp, m, wingc, bulge=.6, ambient=.26, rim=False)

    # lower jaw + teeth
    jaw = pf.m_poly(DW, DH, [(cx + 3, head_y + 7 + p["jaw"]),
                             (cx + 19, head_y + 6 + p["jaw"]),
                             (cx + 17, head_y + 11 + p["jaw"]),
                             (cx + 3, head_y + 11 + p["jaw"])])
    pf.render_solid(sp, jaw, belly, bulge=.7, ambient=.32, rim=False)
    for i in range(3):
        tx = cx + 8 + i * 4
        sp.px(tx, head_y + 6 + p["jaw"], pf.hex2rgb(P.BONE))
        sp.px(tx, head_y + 7 + p["jaw"], pf.mix(P.BONE, P.INK, .25))
    # tusk poking up from the lower jaw - Blaze's signature
    sp.px(cx + 16, head_y + 4 + p["jaw"], pf.hex2rgb(P.BONE))
    sp.px(cx + 16, head_y + 5 + p["jaw"], pf.hex2rgb(P.BONE))
    sp.px(cx + 17, head_y + 5 + p["jaw"], pf.mix(P.BONE, P.INK, .3))
    # nostril
    sp.px(cx + 18, head_y + 1, pf.hex2rgb(P.INK))
    sp.px(cx + 18, head_y + 2, pf.mix(P.DRAGON_SCALE, P.INK, .55))

    face_dragon(sp, cx, head_y, expr)
    pf.outline(sp)
    return sp


def face_dragon(sp, cx, cy, expr):
    ink = pf.hex2rgb(P.INK)
    white = pf.hex2rgb("#fff0d6")
    iris = pf.hex2rgb(P.LAMP)
    lid = 0.0
    look = (0, 0)
    sz = 1.0
    if expr in ("happy", "satisfied", "proud"):
        lid = .40
    if expr == "excited":
        sz = 1.25
    if expr in ("shocked", "surprised"):
        sz = 1.35
    if expr == "sad":
        lid = .35
        look = (0, 1)
    if expr == "confused":
        look = (1, -1)
    if expr == "angry":
        lid = .28

    # 3/4 view facing right: the far eye is smaller and sits deeper.
    eye(sp, cx - 5, cy - 3, 3.8 * sz, 3.8 * sz, white, iris, ink, look, lid)
    eye(sp, cx + 8, cy - 2, 4.6 * sz, 4.6 * sz, white, iris, ink, look, lid)

    if expr == "angry":
        brow(sp, cx - 8, cy - 7, cx - 1, cy - 5, ink, 2)
        brow(sp, cx + 11, cy - 7, cx + 3, cy - 5, ink, 2)
        anger_mark(sp, cx - 14, cy - 13)
        # smoke curling out of the nostril
        for i in range(3):
            sp.px(cx + 20 + i, cy - i * 2, pf.mix(P.STONE_L, P.CHALK, .3))
    elif expr in ("happy", "excited", "satisfied"):
        # fire sparks - the dragon's reward tell
        for i in range(4):
            sp.px(cx + 22 + i, cy - 4 - i * 2, pf.hex2rgb(P.LAMP_HOT))
        sp.px(cx + 24, cy - 10, pf.hex2rgb(P.EMBER))
        blush(sp, cx - 8, cy + 5, 4.0)
    elif expr == "proud":
        brow(sp, cx - 8, cy - 8, cx - 1, cy - 7, ink, 2)
        brow(sp, cx + 11, cy - 8, cx + 3, cy - 7, ink, 2)
    elif expr == "hungry":
        sweat(sp, cx - 13, cy - 4)
        sp.px(cx + 14, cy + 13, pf.hex2rgb("#a8d6ff"))
        sp.px(cx + 14, cy + 14, pf.hex2rgb("#a8d6ff"))
    elif expr in ("shocked", "surprised"):
        brow(sp, cx - 8, cy - 9, cx - 1, cy - 9, ink, 1)
        brow(sp, cx + 11, cy - 10, cx + 3, cy - 10, ink, 1)
    elif expr == "embarrassed":
        blush(sp, cx - 9, cy + 5, 5.0, a=160)
        sweat(sp, cx - 13, cy - 6)


# ========================================================= COUNTESS VEX ====
# Vampire. Elegant, sarcastic, perfectionist. Tall narrow silhouette, high
# collar reading as two dark blades either side of a pale face.
VW, VH = 56, 88


def vampire(pose=None, expr="neutral"):
    p = {"bob": 0, "armL": 0.0, "armR": 0.0, "legL": 0.0, "legR": 0.0,
         "cape": 0.0, "squash": 0.0, "turn": 0}
    p.update(pose or {})
    sp = pf.Sprite(VW, VH)
    cx = VW // 2 + p["turn"]
    bob = p["bob"]
    coat = pf.ramp(P.VAMP_COAT)
    skin = pf.ramp(P.VAMP_SKIN)
    trim = pf.ramp(P.VAMP_TRIM)
    hair = pf.ramp(P.VAMP_HAIR)

    hip_y = 66 + bob
    sh_y = 46 + bob
    head_y = 25 + bob

    pf.drop_shadow(sp, np.zeros((VH, VW), bool), cx, 84, 14, 4)

    # cape (behind) ----------------------------------------------------------
    sway = math.sin(p["cape"]) * 5
    cape = pf.m_poly(VW, VH, [(cx - 10, sh_y - 4), (cx + 10, sh_y - 4),
                              (cx + 15 + sway, 80), (cx - 15 + sway, 80)])
    pf.render_solid(sp, cape, pf.ramp(pf.mix(P.VAMP_COAT, P.INK, .35)),
                    bulge=.45, flat=.6, ambient=.24, rim=False)
    # cape lining catches the light at the hem
    hem = cape & pf.m_rect(VW, VH, 0, 74, VW, 8)
    pf.render_solid(sp, hem, trim, bulge=.4, flat=.7, ambient=.30, rim=False)

    # legs -------------------------------------------------------------------
    for side, ang in ((-1, p["legL"]), (1, p["legR"])):
        fx = cx + side * 4 + math.sin(ang) * 6
        m = pf.m_capsule(VW, VH, cx + side * 4, hip_y, fx, 80, 3.2)
        pf.render_solid(sp, m, pf.ramp(pf.mix(P.VAMP_COAT, P.INK, .25)),
                        bulge=.9, ambient=.28)
        boot = pf.m_capsule(VW, VH, fx - 1, 80, fx + 3, 80, 3.0)
        pf.render_solid(sp, boot, hair, bulge=.85, ambient=.30)

    # torso ------------------------------------------------------------------
    torso = pf.m_poly(VW, VH, [(cx - 9, sh_y), (cx + 9, sh_y),
                               (cx + 7, hip_y + 2), (cx - 7, hip_y + 2)])
    pf.render_solid(sp, torso, coat, bulge=.95, ambient=.30)
    # waistcoat + cravat: the one warm cluster on a cold character
    vest = pf.m_poly(VW, VH, [(cx - 4, sh_y + 3), (cx + 4, sh_y + 3),
                              (cx + 3, hip_y), (cx - 3, hip_y)])
    pf.render_solid(sp, vest, trim, bulge=.6, flat=.45, ambient=.34, rim=False)
    for i in range(3):
        sp.px(cx, sh_y + 8 + i * 6, pf.hex2rgb(P.UI_GOLD))
    cravat = pf.m_poly(VW, VH, [(cx - 3, sh_y - 1), (cx + 3, sh_y - 1),
                                (cx, sh_y + 6)])
    pf.render_solid(sp, cravat, pf.ramp(P.CHALK), bulge=.7, ambient=.44, rim=False)

    # arms -------------------------------------------------------------------
    for side, ang in ((-1, p["armL"]), (1, p["armR"])):
        sx = cx + side * 9
        hx = sx + side * (4 + math.cos(ang) * 4)
        hy = sh_y + 14 + math.sin(ang) * 8
        m = pf.m_capsule(VW, VH, sx, sh_y + 2, hx, hy, 2.8)
        pf.render_solid(sp, m, coat, bulge=.9, ambient=.30)
        hand = pf.m_ellipse(VW, VH, hx, hy + 1, 2.4, 2.4)
        pf.render_solid(sp, hand, skin, bulge=1.0, ambient=.46)

    # high collar ------------------------------------------------------------
    for side in (-1, 1):
        col = pf.m_poly(VW, VH, [(cx + side * 3, sh_y - 2),
                                 (cx + side * 13, sh_y - 14),
                                 (cx + side * 9, sh_y + 1)])
        pf.render_solid(sp, col, pf.ramp(pf.mix(P.VAMP_COAT, P.VAMP_TRIM, .3)),
                        bulge=.5, flat=.6, ambient=.30)

    # head -------------------------------------------------------------------
    head = pf.m_ellipse(VW, VH, cx, head_y, 12, 13)
    jaw = pf.m_poly(VW, VH, [(cx - 9, head_y + 6), (cx + 9, head_y + 6),
                             (cx, head_y + 15)])
    pf.render_solid(sp, head | jaw, skin, bulge=1.0, ambient=.46)
    hm = (pf.m_ellipse(VW, VH, cx, head_y - 4, 12.8, 12.4)
          & ~pf.m_ellipse(VW, VH, cx, head_y + 3, 11.2, 10.4))
    hm |= pf.m_poly(VW, VH, [(cx - 13, head_y - 3), (cx - 9, head_y + 16),
                             (cx - 13, head_y + 16)])
    hm |= pf.m_poly(VW, VH, [(cx + 13, head_y - 3), (cx + 9, head_y + 16),
                             (cx + 13, head_y + 16)])
    hm |= pf.m_poly(VW, VH, [(cx - 6, head_y - 13), (cx, head_y - 6),
                             (cx + 6, head_y - 13)])   # widow's peak
    sp.mask_fill(hm, hair[1])
    sp.mask_fill(hm & pf.m_ellipse(VW, VH, cx - 5, head_y - 10, 6, 3), hair[3])

    face_vampire(sp, cx, head_y, expr)
    pf.outline(sp)
    return sp


def face_vampire(sp, cx, cy, expr):
    ink = pf.hex2rgb(P.INK)
    white = pf.hex2rgb("#fbf4ff")
    iris = pf.hex2rgb("#c8304a")
    lid = .18
    look = (0, 0)
    sz = 1.0
    if expr in ("happy", "satisfied", "proud"):
        lid = .46
    if expr == "excited":
        sz, lid = 1.2, 0
    if expr in ("shocked", "surprised"):
        sz, lid = 1.3, 0
    if expr == "sad":
        lid, look = .40, (0, 1)
    if expr == "confused":
        look = (1, 0)
    if expr == "angry":
        lid = .30

    eye(sp, cx - 5.0, cy + 2, 3.2 * sz, 3.4 * sz, white, iris, ink, look, lid)
    eye(sp, cx + 5.0, cy + 2, 3.2 * sz, 3.4 * sz, white, iris, ink, look, lid)

    if expr == "angry":
        brow(sp, cx - 7, cy - 3, cx - 2, cy - 1, ink, 1)
        brow(sp, cx + 7, cy - 3, cx + 2, cy - 1, ink, 1)
        mouth_arc(sp, cx, cy + 6, 2, -1, ink)
    elif expr in ("happy", "satisfied", "proud"):
        mouth_arc(sp, cx, cy + 5, 2, 1, ink)
        # a single fang shows when amused
        sp.px(cx - 1, cy + 6, pf.hex2rgb(P.CHALK))
        sp.px(cx - 1, cy + 7, pf.hex2rgb(P.CHALK))
    elif expr == "excited":
        mouth_arc(sp, cx, cy + 5, 3, 2, ink)
        sp.px(cx - 2, cy + 6, pf.hex2rgb(P.CHALK))
        sp.px(cx + 2, cy + 6, pf.hex2rgb(P.CHALK))
    elif expr in ("shocked", "surprised"):
        sp.mask_fill(pf.m_ellipse(sp.w, sp.h, cx, cy + 6, 1.4, 1.8), ink)
    elif expr == "hungry":
        mouth_arc(sp, cx, cy + 5, 2, 1.2, ink)
        sp.px(cx - 2, cy + 6, pf.hex2rgb(P.CHALK))
        sp.px(cx + 2, cy + 6, pf.hex2rgb(P.CHALK))
        sp.px(cx - 2, cy + 7, pf.hex2rgb(P.CHALK))
        sp.px(cx + 2, cy + 7, pf.hex2rgb(P.CHALK))
    elif expr == "embarrassed":
        blush(sp, cx - 6, cy + 4, 2.6, a=140)
        blush(sp, cx + 6, cy + 4, 2.6, a=140)
        mouth_arc(sp, cx, cy + 6, 2, .4, ink)
    elif expr == "sad":
        mouth_arc(sp, cx, cy + 6, 2, -1, ink)
    elif expr == "confused":
        mouth_arc(sp, cx + 1, cy + 6, 1, .5, ink)
    else:
        mouth_arc(sp, cx, cy + 6, 2, .2, ink)


# =============================================================== GLOOP =====
# Slime. Curious, playful, chaotic. No skeleton - the whole body is the
# performance, so the rig is squash/stretch plus a wobbling silhouette and
# floating inclusions (things it has swallowed).
SW, SH = 64, 60


def slime(pose=None, expr="neutral", swallowed=None):
    p = {"squash": 0.0, "wob": 0.0, "bob": 0, "lean": 0.0, "stretch": 0.0,
         "turn": 0}
    p.update(pose or {})
    sp = pf.Sprite(SW, SH)
    cx = SW // 2 + p["turn"]
    body = pf.ramp(P.SLIME_BODY)
    core = pf.ramp(P.SLIME_CORE)

    sq = p["squash"]
    rx = 20 + sq * 5
    ry = 17 - sq * 6 + p["stretch"] * 5
    cy = 40 - p["bob"] - p["stretch"] * 3

    pf.drop_shadow(sp, np.zeros((SH, SW), bool), cx, 55, rx * .8, 4)

    # body: blob silhouette with an animated wobble, flat bottom where it
    # meets the floor
    m = pf.m_blob(SW, SH, cx + p["lean"], cy, max(rx, ry),
                  3, seed=7, wob=.16 + .07 * math.sin(p["wob"]))
    m &= pf.m_ellipse(SW, SH, cx + p["lean"], cy, rx, ry)
    m &= ~pf.m_rect(SW, SH, 0, 55, SW, SH)
    pf.render_solid(sp, m, body, bulge=1.05, ambient=.36, strength=2.2)

    # translucency: a brighter gel core, offset from centre so it reads as
    # volume rather than a highlight decal
    inner = pf.m_ellipse(SW, SH, cx + p["lean"] - 2, cy + 3, rx * .55, ry * .5) & m
    pf.render_solid(sp, inner, core, bulge=.7, ambient=.55, rim=False, alpha=170)

    # swallowed props drift inside
    if swallowed:
        for i, item in enumerate(swallowed):
            ox = int(cx + p["lean"] - 4 + i * 7)
            oy = int(cy + 4 + math.sin(p["wob"] + i) * 2)
            sp.paste(item, ox - item.w // 2, oy - item.h // 2)

    # surface highlight + a couple of bubbles
    hl = pf.m_ellipse(SW, SH, cx - rx * .35, cy - ry * .45, rx * .22, ry * .16) & m
    sp.mask_fill(hl, pf.hex2rgb("#e8fff2"))
    for i, (bx, by, br) in enumerate([(-8, 6, 1.6), (6, -2, 1.2), (10, 7, 1.0)]):
        bm = pf.m_ellipse(SW, SH, cx + bx, cy + by + math.sin(p["wob"] + i * 2) * 2,
                          br, br) & m
        sp.mask_fill(bm, pf.mix(P.SLIME_CORE, P.CHALK, .4))

    # a drip forming at the rim
    if math.sin(p["wob"] * .7) > .4:
        dm = pf.m_capsule(SW, SH, cx + rx * .7, cy + ry * .6,
                          cx + rx * .7, cy + ry * .6 + 4, 1.8) & ~m
        pf.render_solid(sp, dm, body, bulge=1.0, ambient=.40, rim=False)

    face_slime(sp, cx + p["lean"], cy - 2, expr, rx, ry)
    pf.outline(sp)
    return sp


def face_slime(sp, cx, cy, expr, rx, ry):
    ink = pf.hex2rgb(P.INK)
    white = pf.hex2rgb("#f2fff8")
    iris = pf.hex2rgb("#1d5c3f")
    lid = 0.0
    look = (0, 0)
    sz = 1.0
    if expr in ("happy", "satisfied"):
        lid = .45
    if expr == "excited":
        sz = 1.3
    if expr in ("shocked", "surprised"):
        sz = 1.45
    if expr == "sad":
        lid, look = .35, (0, 1)
    if expr == "confused":
        look = (1, -1)
    if expr == "angry":
        lid = .30

    eye(sp, cx - 6, cy, 4.4 * sz, 4.8 * sz, white, iris, ink, look, lid)
    eye(sp, cx + 6, cy, 4.4 * sz, 4.8 * sz, white, iris, ink, look, lid)

    if expr == "angry":
        brow(sp, cx - 9, cy - 5, cx - 2, cy - 3, ink, 1)
        brow(sp, cx + 9, cy - 5, cx + 2, cy - 3, ink, 1)
        mouth_arc(sp, cx, cy + 8, 3, -1.5, ink)
    elif expr in ("happy", "satisfied"):
        mouth_arc(sp, cx, cy + 7, 4, 2.5, ink)
    elif expr == "excited":
        mouth_arc(sp, cx, cy + 6, 5, 4, ink, 2)
        blush(sp, cx - 11, cy + 4, 3.4)
        blush(sp, cx + 11, cy + 4, 3.4)
    elif expr in ("shocked", "surprised"):
        sp.mask_fill(pf.m_ellipse(sp.w, sp.h, cx, cy + 8, 2.4, 3.0), ink)
    elif expr == "hungry":
        mouth_arc(sp, cx, cy + 6, 4, 3, ink, 2)
        sp.px(cx + 12, cy + 6, pf.hex2rgb("#a8d6ff"))
        sp.px(cx + 12, cy + 7, pf.hex2rgb("#a8d6ff"))
    elif expr == "confused":
        mouth_arc(sp, cx + 1, cy + 8, 2, .8, ink)
    elif expr == "sad":
        mouth_arc(sp, cx, cy + 9, 3, -2, ink)
    elif expr == "embarrassed":
        blush(sp, cx - 11, cy + 4, 4.0, a=160)
        blush(sp, cx + 11, cy + 4, 4.0, a=160)
        mouth_arc(sp, cx, cy + 8, 2, .6, ink)
    elif expr == "proud":
        lid = .5
        mouth_arc(sp, cx, cy + 7, 3, 1.6, ink)
    else:
        mouth_arc(sp, cx, cy + 8, 3, .8, ink)


# ============================================== SUPPORTING REGULARS =========
GW, GH = 52, 64


def ghost(pose=None, expr="neutral"):
    """Mothwick - a shy moth-ghost regular. Tail dissolves into the floor."""
    p = {"bob": 0, "wob": 0.0, "turn": 0}
    p.update(pose or {})
    sp = pf.Sprite(GW, GH)
    cx = GW // 2 + p["turn"]
    cy = 26 - p["bob"]
    body = pf.ramp(P.GHOST_BODY)

    m = pf.m_ellipse(GW, GH, cx, cy, 15, 16)
    tail = pf.m_poly(GW, GH, [(cx - 13, cy + 8), (cx + 13, cy + 8),
                              (cx + 9 + math.sin(p["wob"]) * 3, 54),
                              (cx - 9 + math.sin(p["wob"]) * 3, 54)])
    m |= tail
    pf.render_solid(sp, m, body, bulge=1.0, ambient=.44, strength=2.2, alpha=228)
    # scalloped, fading hem
    for i in range(5):
        hx = cx - 10 + i * 5 + math.sin(p["wob"]) * 3
        sp.mask_fill(pf.m_ellipse(GW, GH, hx, 54, 2.6, 2.0) & m,
                     pf.mix(P.GHOST_BODY, P.NIGHT, .1))
    for y in range(48, 58):
        for x in range(GW):
            pp = sp.get(x, y)
            if pp[3]:
                sp.buf[y, x, 3] = int(pp[3] * max(0, (56 - y) / 10))
    # moth antennae + wings
    for side in (-1, 1):
        sp.line(cx + side * 4, cy - 14, cx + side * 9, cy - 21,
                pf.mix(P.GHOST_BODY, P.INK, .45))
        sp.px(cx + side * 9, cy - 22, pf.hex2rgb(P.MAGIC_LIGHT))
        w = pf.m_ellipse(GW, GH, cx + side * 15, cy + 1, 6, 9)
        pf.render_solid(sp, w, pf.ramp(pf.mix(P.GHOST_BODY, P.MAGIC, .3)),
                        bulge=.45, flat=.5, ambient=.40, rim=False, alpha=170)

    ink = pf.hex2rgb(P.INK)
    lid = .4 if expr in ("happy", "satisfied") else 0.0
    eye(sp, cx - 5.6, cy, 3.6, 3.9, pf.hex2rgb(P.CHALK), pf.hex2rgb("#5f7fa8"), ink,
        (0, 0), lid)
    eye(sp, cx + 5.6, cy, 3.6, 3.9, pf.hex2rgb(P.CHALK), pf.hex2rgb("#5f7fa8"), ink,
        (0, 0), lid)
    if expr in ("happy", "excited", "satisfied"):
        mouth_arc(sp, cx, cy + 7, 3, 1.6, ink)
    elif expr in ("shocked", "surprised", "hungry"):
        sp.mask_fill(pf.m_ellipse(GW, GH, cx, cy + 7, 1.6, 2.0), ink)
    elif expr == "embarrassed":
        blush(sp, cx - 9, cy + 4, 3.0, a=150)
        blush(sp, cx + 9, cy + 4, 3.0, a=150)
        mouth_arc(sp, cx, cy + 8, 2, .3, ink)
    else:
        mouth_arc(sp, cx, cy + 7, 2, .4, ink)
    pf.outline(sp)
    return sp


OW, OH = 60, 80


def golem(pose=None, expr="neutral"):
    """Grit - a stone mason built from stacked blocks. Deliberately the most
    angular silhouette in the cast to contrast with Gloop."""
    p = {"bob": 0, "armL": 0.0, "armR": 0.0, "legL": 0.0, "legR": 0.0, "turn": 0}
    p.update(pose or {})
    sp = pf.Sprite(OW, OH)
    cx = OW // 2 + p["turn"]
    bob = p["bob"]
    rock = pf.ramp(P.GOLEM_BODY)
    moss = pf.ramp(P.LEAF)
    pf.drop_shadow(sp, np.zeros((OH, OW), bool), cx, 74, 18, 5)

    for side, ang in ((-1, p["legL"]), (1, p["legR"])):
        fx = cx + side * 7 + math.sin(ang) * 5
        m = pf.m_round_rect(OW, OH, fx - 5, 56 + bob, 10, 16, 2)
        pf.render_solid(sp, m, rock, bulge=.7, flat=.6, ambient=.30)

    torso = pf.m_round_rect(OW, OH, cx - 14, 26 + bob, 28, 32, 4)
    pf.render_solid(sp, torso, rock, bulge=.8, flat=.55, ambient=.32)
    # cracks + moss patches keep a grey character from reading as dead space
    sp.line(cx - 6, 30 + bob, cx - 2, 40 + bob, pf.mix(P.GOLEM_BODY, P.INK, .45))
    sp.line(cx - 2, 40 + bob, cx + 4, 44 + bob, pf.mix(P.GOLEM_BODY, P.INK, .45))
    pf.render_solid(sp, pf.m_blob(OW, OH, cx + 8, 32 + bob, 5, 3, seed=3) & torso,
                    moss, bulge=.5, ambient=.42, rim=False)

    for side, ang in ((-1, p["armL"]), (1, p["armR"])):
        sx = cx + side * 14
        hy = 36 + bob + math.sin(ang) * 8
        m = pf.m_round_rect(OW, OH, sx - 4 + side * 2, 28 + bob, 9, 22, 3)
        pf.render_solid(sp, m, rock, bulge=.7, flat=.55, ambient=.30)
        fist = pf.m_round_rect(OW, OH, sx - 5 + side * 2, hy + 12, 11, 10, 3)
        pf.render_solid(sp, fist, rock, bulge=.8, flat=.4, ambient=.32)

    head = pf.m_round_rect(OW, OH, cx - 14, 4 + bob, 28, 26, 5)
    pf.render_solid(sp, head, rock, bulge=.85, flat=.45, ambient=.34)
    ink = pf.hex2rgb(P.INK)
    gl = pf.hex2rgb(P.LAMP)
    for side in (-1, 1):
        m = pf.m_rect(OW, OH, cx + side * 6 - 3, 14 + bob, 6, 5)
        sp.mask_fill(m, gl)
        pf.glow(sp, cx + side * 5, 17 + bob, 5, gl, .5)
    if expr in ("happy", "excited", "satisfied"):
        mouth_arc(sp, cx, 24 + bob, 4, 1.6, ink)
    elif expr == "angry":
        brow(sp, cx - 9, 13 + bob, cx - 2, 15 + bob, ink, 2)
        brow(sp, cx + 9, 13 + bob, cx + 2, 15 + bob, ink, 2)
    else:
        sp.line(cx - 4, 24 + bob, cx + 4, 24 + bob, ink)
    pf.outline(sp)
    return sp


WW, WH = 52, 76


def witch(pose=None, expr="neutral"):
    """Marrow - runs the ingredient shop. Hat brim is the silhouette hook."""
    p = {"bob": 0, "armL": 0.0, "armR": 0.0, "turn": 0}
    p.update(pose or {})
    sp = pf.Sprite(WW, WH)
    cx = WW // 2 + p["turn"]
    bob = p["bob"]
    robe = pf.ramp(P.WITCH_ROBE)
    skin = pf.ramp(P.WITCH_SKIN)
    pf.drop_shadow(sp, np.zeros((WH, WW), bool), cx, 71, 15, 4)

    body = pf.m_poly(WW, WH, [(cx - 8, 36 + bob), (cx + 8, 36 + bob),
                              (cx + 16, 70), (cx - 16, 70)])
    pf.render_solid(sp, body, robe, bulge=.85, ambient=.30)
    # hem trim
    pf.render_solid(sp, body & pf.m_rect(WW, WH, 0, 65, WW, 6),
                    pf.ramp(P.MAGIC), bulge=.4, flat=.7, ambient=.36, rim=False)

    for side, ang in ((-1, p["armL"]), (1, p["armR"])):
        hx = cx + side * (11 + math.cos(ang) * 3)
        hy = 48 + bob + math.sin(ang) * 6
        m = pf.m_capsule(WW, WH, cx + side * 8, 38 + bob, hx, hy, 3.2)
        pf.render_solid(sp, m, robe, bulge=.85, ambient=.30)
        pf.render_solid(sp, pf.m_ellipse(WW, WH, hx, hy + 2, 2.4, 2.4), skin,
                        bulge=1.0, ambient=.44)

    head = pf.m_ellipse(WW, WH, cx, 27 + bob, 11.5, 12)
    pf.render_solid(sp, head, skin, bulge=1.0, ambient=.44)
    # nose - a witch needs a nose
    pf.render_solid(sp, pf.m_poly(WW, WH, [(cx + 2, 27 + bob), (cx + 9, 29 + bob),
                                           (cx + 2, 30 + bob)]),
                    skin, bulge=.9, ambient=.40, rim=False)
    hair = pf.m_poly(WW, WH, [(cx - 9, 24 + bob), (cx - 6, 44 + bob),
                              (cx - 11, 44 + bob)])
    hair |= pf.m_poly(WW, WH, [(cx + 9, 24 + bob), (cx + 6, 44 + bob),
                               (cx + 11, 44 + bob)])
    pf.render_solid(sp, hair, pf.ramp(P.STONE_L), bulge=.8, ambient=.32)

    brim = pf.m_ellipse(WW, WH, cx, 18 + bob, 19, 4.2)
    cone = pf.m_poly(WW, WH, [(cx - 9, 18 + bob), (cx + 9, 18 + bob),
                              (cx + 3, -2 + bob)])
    pf.render_solid(sp, cone, pf.ramp(pf.mix(P.WITCH_ROBE, P.INK, .2)),
                    bulge=.7, flat=.4, ambient=.28)
    pf.render_solid(sp, brim, robe, bulge=.6, flat=.5, ambient=.32)
    pf.render_solid(sp, pf.m_ellipse(WW, WH, cx + 4, 8 + bob, 2.2, 2.2),
                    pf.ramp(P.MAGIC_LIGHT), bulge=1.0, ambient=.6, rim=False)
    pf.glow(sp, cx + 4, 8 + bob, 6, pf.hex2rgb(P.MAGIC_LIGHT), .45)

    ink = pf.hex2rgb(P.INK)
    lid = .45 if expr in ("happy", "satisfied", "proud") else .1
    eye(sp, cx - 4.6, 28 + bob, 3.0, 3.2, pf.hex2rgb(P.CHALK),
        pf.hex2rgb(P.MAGIC), ink, (0, 0), lid)
    eye(sp, cx + 4.6, 28 + bob, 3.0, 3.2, pf.hex2rgb(P.CHALK),
        pf.hex2rgb(P.MAGIC), ink, (0, 0), lid)
    if expr in ("happy", "excited", "satisfied", "proud"):
        mouth_arc(sp, cx, 32 + bob, 2, 1.2, ink)
    elif expr == "angry":
        mouth_arc(sp, cx, 33 + bob, 2, -1, ink)
    else:
        mouth_arc(sp, cx, 33 + bob, 2, .3, ink)
    pf.outline(sp)
    return sp


# ============================================================ ANIMATION =====
def anim_walk(rig, n=8, amp=1.0):
    out = []
    for i in range(n):
        t = i / n * math.tau
        out.append(rig({"bob": int(round(abs(math.sin(t)) * 2 - 1)),
                        "legL": math.sin(t) * .9 * amp,
                        "legR": math.sin(t + math.pi) * .9 * amp,
                        "armL": math.sin(t + math.pi) * .7 * amp,
                        "armR": math.sin(t) * .7 * amp,
                        "wing": t, "tail": t, "cape": t, "wob": t}))
    return out


def anim_idle(rig, n=6):
    out = []
    for i in range(n):
        t = i / n * math.tau
        out.append(rig({"bob": int(round(math.sin(t) * 1.2)),
                        "armL": math.sin(t) * .12,
                        "armR": math.sin(t) * .12,
                        "squash": math.sin(t) * .5,
                        "wing": t * .5, "tail": t * .5, "cape": t * .5,
                        "wob": t}))
    return out


def anim_eat(rig, n=6):
    out = []
    for i in range(n):
        t = i / n * math.tau
        out.append(rig({"bob": int(round(abs(math.sin(t * 2)) * 2)),
                        "armL": .5 + math.sin(t * 2) * .5,
                        "armR": .5 + math.sin(t * 2) * .5,
                        "jaw": int(abs(math.sin(t * 2)) * 4),
                        "squash": math.sin(t * 2) * 1.2,
                        "stretch": abs(math.sin(t * 2)) * .4,
                        "wob": t * 2, "wing": t, "tail": t, "cape": t}))
    return out


def anim_react(rig, n=4):
    """Big anticipation-then-pop used for reaction beats."""
    out = []
    keys = [(-1, -.4), (0, .2), (3, 1.0), (1, .6)]
    for i in range(n):
        bob, s = keys[i % len(keys)]
        out.append(rig({"bob": bob, "squash": s * 2, "stretch": max(0, s) * .5,
                        "armL": -s, "armR": -s, "wing": s * 2, "wob": i,
                        "tail": s, "cape": s, "jaw": int(max(0, s) * 4)}))
    return out


# ================================================================= BUILD ====
def build(manifest):
    rigs = {
        "cook": (cook, PW, PH),
        "dragon": (dragon, DW, DH),
        "vampire": (vampire, VW, VH),
        "slime": (slime, SW, SH),
        "ghost": (ghost, GW, GH),
        "golem": (golem, OW, OH),
        "witch": (witch, WW, WH),
    }
    for name, (rig, w, h) in rigs.items():
        d = os.path.join(OUT, name)
        for anim, fn, cnt in (("idle", anim_idle, 6), ("walk", anim_walk, 8),
                              ("eat", anim_eat, 6), ("react", anim_react, 4)):
            frames = fn(rig, cnt)
            path, fw, fh, n = pf.sheet(frames, os.path.join(d, anim + ".png"))
            manifest.append({"kind": "character", "id": name, "anim": anim,
                             "path": rel(path), "fw": fw, "fh": fh, "frames": n})
        # expression portrait sheet - one row of every emotional state
        faces = [rig({"bob": 0}, e) for e in EXPRESSIONS]
        path, fw, fh, n = pf.sheet(faces, os.path.join(d, "expressions.png"))
        manifest.append({"kind": "character", "id": name, "anim": "expressions",
                         "path": rel(path), "fw": fw, "fh": fh, "frames": n,
                         "labels": EXPRESSIONS})
        print("  %-8s %dx%d  idle/walk/eat/react + %d expressions"
              % (name, w, h, len(EXPRESSIONS)))
    return manifest


def rel(p):
    p = os.path.abspath(p)
    root = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
    return "res://" + os.path.relpath(p, root).replace("\\", "/")


if __name__ == "__main__":
    import json
    m = build([])
    print(json.dumps(m[:2], indent=1))
