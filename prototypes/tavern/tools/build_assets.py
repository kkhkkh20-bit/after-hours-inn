"""
Build every asset in the game and write assets/manifest.json.

    python tools/build_assets.py

The manifest is what the engine reads to learn frame counts and sizes, so the
art pipeline and the game never disagree about how many frames a walk cycle
has. Regenerating is fast (a few seconds) and fully deterministic - every
generator is seeded, so the same source always produces byte-identical art.
"""
import json
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, ".."))
sys.path.insert(0, HERE)

import gen_characters
import gen_environment
import gen_food
import gen_ui
import gen_vfx
import gen_audio
import gen_icon
import gen_font


def main():
    t0 = time.time()
    manifest = []
    print("Restaurant for Monsters - asset build")
    for mod in (gen_characters, gen_environment, gen_food, gen_ui, gen_vfx,
                gen_icon, gen_font, gen_audio):
        mod.build(manifest)

    # No timestamp: the manifest must be byte-identical across builds so a
    # regenerated tree shows no diff. Build time is what git log is for.
    index = {"spec": {"resolution": [1280, 720], "tile": 32,
                      "aspect": "16:9", "style": "hd-pixel-art"},
             "assets": manifest}
    # Also emit lookup tables keyed by kind so GDScript does not scan a list.
    by_kind = {}
    for a in manifest:
        by_kind.setdefault(a["kind"], {})
        key = a["id"] if "anim" not in a else "%s/%s" % (a["id"], a["anim"])
        by_kind[a["kind"]][key] = a
    index["by_kind"] = by_kind

    out = os.path.join(ROOT, "assets", "manifest.json")
    with open(out, "w", encoding="utf-8", newline="\n") as f:
        json.dump(index, f, indent=1)
    print("  manifest: %d entries -> assets/manifest.json" % len(manifest))
    print("done in %.1fs" % (time.time() - t0))


if __name__ == "__main__":
    main()
