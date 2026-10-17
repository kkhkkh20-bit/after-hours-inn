"""
Original bitmap font: "Monsterplate".

Godot's default font is a smooth vector face and looks wrong against pixel art
at 1:1, so the game ships its own. Glyphs are designed here as pixel grids and
exported as an AngelCode BMFont (.fnt + .png), which Godot 4's FontFile loads
directly.

Design: 7px cap height, 2px descender, 1px sidebearing, proportional widths.
Chunky enough to read at 1280x720 without a scale, open enough to stay legible
in a parchment panel.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixelforge as pf
import palette as P

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..",
                   "assets", "ui", "font")

# Each glyph: list of row strings, '#' = ink. Baseline sits after row 7.
# Rows 8-9 are the descender zone.
G = {
    "A": ["  ##  ", " #  # ", "#    #", "#    #", "######", "#    #", "#    #"],
    "B": ["##### ", "#    #", "#    #", "##### ", "#    #", "#    #", "##### "],
    "C": [" #### ", "#    #", "#     ", "#     ", "#     ", "#    #", " #### "],
    "D": ["####  ", "#   # ", "#    #", "#    #", "#    #", "#   # ", "####  "],
    "E": ["######", "#     ", "#     ", "##### ", "#     ", "#     ", "######"],
    "F": ["######", "#     ", "#     ", "##### ", "#     ", "#     ", "#     "],
    "G": [" #### ", "#    #", "#     ", "#  ###", "#    #", "#    #", " #### "],
    "H": ["#    #", "#    #", "#    #", "######", "#    #", "#    #", "#    #"],
    "I": [" ### ", "  #  ", "  #  ", "  #  ", "  #  ", "  #  ", " ### "],
    "J": ["   ###", "    # ", "    # ", "    # ", "    # ", "#   # ", " ###  "],
    "K": ["#    #", "#   # ", "#  #  ", "###   ", "#  #  ", "#   # ", "#    #"],
    "L": ["#     ", "#     ", "#     ", "#     ", "#     ", "#     ", "######"],
    "M": ["#    #", "##  ##", "# ## #", "#    #", "#    #", "#    #", "#    #"],
    "N": ["#    #", "##   #", "# #  #", "#  # #", "#   ##", "#    #", "#    #"],
    "O": [" #### ", "#    #", "#    #", "#    #", "#    #", "#    #", " #### "],
    "P": ["##### ", "#    #", "#    #", "##### ", "#     ", "#     ", "#     "],
    "Q": [" #### ", "#    #", "#    #", "#    #", "#  # #", "#   # ", " ### #"],
    "R": ["##### ", "#    #", "#    #", "##### ", "#  #  ", "#   # ", "#    #"],
    "S": [" #####", "#     ", "#     ", " #### ", "     #", "     #", "##### "],
    "T": ["#####", "  #  ", "  #  ", "  #  ", "  #  ", "  #  ", "  #  "],
    "U": ["#    #", "#    #", "#    #", "#    #", "#    #", "#    #", " #### "],
    "V": ["#    #", "#    #", "#    #", "#    #", " #  # ", " #  # ", "  ##  "],
    "W": ["#    #", "#    #", "#    #", "#  # #", "# ## #", "##  ##", "#    #"],
    "X": ["#    #", " #  # ", "  ##  ", "  ##  ", "  ##  ", " #  # ", "#    #"],
    "Y": ["#    #", " #  # ", "  ##  ", "  #   ", "  #   ", "  #   ", "  #   "],
    "Z": ["######", "     #", "    # ", "  ##  ", "  #   ", " #    ", "######"],

    "a": ["      ", "      ", " #### ", "     #", " #####", "#    #", " #####"],
    "b": ["#     ", "#     ", "##### ", "#    #", "#    #", "#    #", "##### "],
    "c": ["      ", "      ", " #### ", "#     ", "#     ", "#    #", " #### "],
    "d": ["     #", "     #", " #####", "#    #", "#    #", "#    #", " #####"],
    "e": ["      ", "      ", " #### ", "#    #", "######", "#     ", " #### "],
    "f": ["  ### ", " #    ", "##### ", " #    ", " #    ", " #    ", " #    "],
    "g": ["      ", "      ", " #####", "#    #", "#    #", " #####", "     #", "#    #", " #### "],
    "h": ["#     ", "#     ", "##### ", "#    #", "#    #", "#    #", "#    #"],
    "i": ["  #  ", "     ", " ##  ", "  #  ", "  #  ", "  #  ", " ### "],
    "j": ["   # ", "     ", " ### ", "   # ", "   # ", "   # ", "   # ", "   # ", "###  "],
    "k": ["#     ", "#     ", "#   # ", "#  #  ", "###   ", "#  #  ", "#   # "],
    "l": [" ##  ", "  #  ", "  #  ", "  #  ", "  #  ", "  #  ", " ### "],
    "m": ["      ", "      ", "## ## ", "# # # ", "# # # ", "# # # ", "# # # "],
    "n": ["      ", "      ", "##### ", "#    #", "#    #", "#    #", "#    #"],
    "o": ["      ", "      ", " #### ", "#    #", "#    #", "#    #", " #### "],
    "p": ["      ", "      ", "##### ", "#    #", "#    #", "##### ", "#     ", "#     ", "#     "],
    "q": ["      ", "      ", " #####", "#    #", "#    #", " #####", "     #", "     #", "     #"],
    "r": ["      ", "      ", "# ### ", "##    ", "#     ", "#     ", "#     "],
    "s": ["      ", "      ", " #####", "#     ", " #### ", "     #", "##### "],
    "t": [" #    ", " #    ", "##### ", " #    ", " #    ", " #   #", "  ### "],
    "u": ["      ", "      ", "#    #", "#    #", "#    #", "#   ##", " ### #"],
    "v": ["      ", "      ", "#    #", "#    #", "#    #", " #  # ", "  ##  "],
    "w": ["      ", "      ", "#    #", "#    #", "# ## #", "##  ##", "#    #"],
    "x": ["      ", "      ", "#    #", " #  # ", "  ##  ", " #  # ", "#    #"],
    "y": ["      ", "      ", "#    #", "#    #", "#    #", " #####", "     #", "#    #", " #### "],
    "z": ["      ", "      ", "######", "    # ", "  ##  ", " #    ", "######"],

    "0": [" #### ", "#    #", "#   ##", "# ## #", "##   #", "#    #", " #### "],
    "1": ["  #   ", " ##   ", "  #   ", "  #   ", "  #   ", "  #   ", " #### "],
    "2": [" #### ", "#    #", "     #", "   ## ", "  #   ", " #    ", "######"],
    "3": ["##### ", "     #", "     #", " #### ", "     #", "     #", "##### "],
    "4": ["   ## ", "  # # ", " #  # ", "#   # ", "######", "    # ", "    # "],
    "5": ["######", "#     ", "##### ", "     #", "     #", "#    #", " #### "],
    "6": ["  ### ", " #    ", "#     ", "##### ", "#    #", "#    #", " #### "],
    "7": ["######", "     #", "    # ", "   #  ", "  #   ", "  #   ", "  #   "],
    "8": [" #### ", "#    #", "#    #", " #### ", "#    #", "#    #", " #### "],
    "9": [" #### ", "#    #", "#    #", " #####", "     #", "    # ", " ###  "],

    " ": ["    ", "    ", "    ", "    ", "    ", "    ", "    "],
    ".": ["  ", "  ", "  ", "  ", "  ", "  ", "##"],
    ",": ["  ", "  ", "  ", "  ", "  ", "##", "##", " #"],
    ":": ["  ", "  ", "##", "  ", "  ", "##", "  "],
    ";": ["  ", "  ", "##", "  ", "  ", "##", "  ", " #"],
    "!": ["##", "##", "##", "##", "##", "  ", "##"],
    "?": [" #### ", "#    #", "     #", "   ## ", "  #   ", "      ", "  #   "],
    "'": ["##", "##", "  ", "  ", "  ", "  ", "  "],
    "\"": ["## ##", "## ##", "     ", "     ", "     ", "     ", "     "],
    "-": ["      ", "      ", "      ", "##### ", "      ", "      ", "      "],
    "+": ["      ", "  #   ", "  #   ", "##### ", "  #   ", "  #   ", "      "],
    "/": ["     #", "    # ", "   #  ", "  #   ", " #    ", "#     ", "#     "],
    "(": [" ##", "#  ", "#  ", "#  ", "#  ", "#  ", " ##"],
    ")": ["## ", "  #", "  #", "  #", "  #", "  #", "## "],
    "[": ["###", "#  ", "#  ", "#  ", "#  ", "#  ", "###"],
    "]": ["###", "  #", "  #", "  #", "  #", "  #", "###"],
    "%": ["##   #", "##  # ", "   #  ", "  #   ", " #  ##", "#   ##", "      "],
    "*": ["      ", " # #  ", "  #   ", " ###  ", "  #   ", " # #  ", "      "],
    "&": [" ###  ", "#   # ", "#   # ", " ###  ", "#  # #", "#   # ", " ### #"],
    "#": [" # #  ", " # #  ", "##### ", " # #  ", "##### ", " # #  ", " # #  "],
    "=": ["      ", "      ", "##### ", "      ", "##### ", "      ", "      "],
    "<": ["   # ", "  #  ", " #   ", "#    ", " #   ", "  #  ", "   # "],
    ">": [" #   ", "  #  ", "   # ", "    #", "   # ", "  #  ", " #   "],
    "_": ["      ", "      ", "      ", "      ", "      ", "      ", "######"],
    "|": [" # ", " # ", " # ", " # ", " # ", " # ", " # "],
    "@": [" #### ", "#    #", "# ## #", "# ## #", "# ### ", "#     ", " #### "],
    "$": ["  #   ", " #### ", "#  #  ", " ###  ", "   #  ", " #### ", "  #   "],
}

LINE_HEIGHT = 12
BASE = 8          # baseline from the top of the cell
PAD = 1


def build_atlas():
    """Pack every glyph into a PNG and emit the .fnt descriptor alongside."""
    glyphs = []
    for ch, rows in G.items():
        w = max(len(r) for r in rows)
        h = len(rows)
        glyphs.append((ch, rows, w, h))

    # simple shelf packer, 256px wide
    aw = 256
    x = PAD
    y = PAD
    shelf_h = 0
    placed = []
    for ch, rows, w, h in glyphs:
        if x + w + PAD > aw:
            x = PAD
            y += shelf_h + PAD
            shelf_h = 0
        placed.append((ch, rows, w, h, x, y))
        x += w + PAD
        shelf_h = max(shelf_h, h)
    ah = y + shelf_h + PAD
    # round up to a power of two, which keeps some drivers happier
    ah = 1 << (ah - 1).bit_length()

    sp = pf.Sprite(aw, ah)
    ink = (255, 255, 255)      # white glyphs, tinted at runtime by Godot
    for ch, rows, w, h, gx, gy in placed:
        for j, row in enumerate(rows):
            for i, c in enumerate(row):
                if c == "#":
                    sp.px(gx + i, gy + j, ink)

    os.makedirs(OUT, exist_ok=True)
    png = os.path.join(OUT, "monsterplate.png")
    sp.save(png)

    lines = [
        'info face="Monsterplate" size=%d bold=0 italic=0 charset="" unicode=1 '
        'stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=1,1' % LINE_HEIGHT,
        'common lineHeight=%d base=%d scaleW=%d scaleH=%d pages=1 packed=0'
        % (LINE_HEIGHT, BASE, aw, ah),
        'page id=0 file="monsterplate.png"',
        'chars count=%d' % len(placed),
    ]
    for ch, rows, w, h, gx, gy in placed:
        lines.append(
            'char id=%d x=%d y=%d width=%d height=%d xoffset=0 yoffset=%d '
            'xadvance=%d page=0 chnl=15'
            % (ord(ch), gx, gy, w, h, 1, w + 1))
    fnt = os.path.join(OUT, "monsterplate.fnt")
    with open(fnt, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    return png, fnt, len(placed), (aw, ah)


def rel(p):
    root = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
    return "res://" + os.path.relpath(os.path.abspath(p), root).replace("\\", "/")


def build(manifest):
    png, fnt, n, size = build_atlas()
    manifest.append({"kind": "ui", "group": "font", "id": "monsterplate",
                     "path": rel(fnt), "atlas": rel(png), "glyphs": n,
                     "line_height": LINE_HEIGHT})
    print("  font: %d glyphs, atlas %dx%d" % (n, size[0], size[1]))
    return manifest


if __name__ == "__main__":
    build([])
