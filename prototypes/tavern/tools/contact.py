"""Art QA contact sheet. Lays generated assets out on a neutral field at 2x
nearest-neighbour so pixel clusters, palette drift and silhouette failures are
visible at a glance. This is the tool used for the art quality gate in
CLAUDE.md - if an asset looks wrong here it does not ship."""
import glob
import os
import sys

from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
BG = (58, 43, 63, 255)


def build(patterns, out, scale=2, pad=8, cols=1, bg=BG):
    paths = []
    for p in patterns:
        paths.extend(sorted(glob.glob(os.path.join(ROOT, p))))
    ims = [Image.open(p).convert("RGBA") for p in paths]
    if not ims:
        print("no images matched", patterns)
        return None
    rows = (len(ims) + cols - 1) // cols
    cw = [max(ims[r * cols + c].width
              for r in range(rows) if r * cols + c < len(ims))
          for c in range(cols)]
    rh = [max(ims[r * cols + c].height
              for c in range(cols) if r * cols + c < len(ims))
          for r in range(rows)]
    W = sum(cw) + pad * (cols + 1)
    H = sum(rh) + pad * (rows + 1)
    sheet = Image.new("RGBA", (W, H), bg)
    for i, im in enumerate(ims):
        r, c = divmod(i, cols)
        x = pad + sum(cw[:c]) + pad * c
        y = pad + sum(rh[:r]) + pad * r
        sheet.alpha_composite(im, (x, y))
    if scale != 1:
        sheet = sheet.resize((W * scale, H * scale), Image.NEAREST)
    op = os.path.join(ROOT, out)
    os.makedirs(os.path.dirname(op), exist_ok=True)
    sheet.save(op)
    print("%s  %dx%d  (%d images)" % (out, sheet.width, sheet.height, len(ims)))
    return op


if __name__ == "__main__":
    out = sys.argv[1]
    scale = int(os.environ.get("SCALE", "2"))
    cols = int(os.environ.get("COLS", "1"))
    build(sys.argv[2:], out, scale=scale, cols=cols)
