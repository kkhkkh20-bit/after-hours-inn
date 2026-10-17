"""Keep exported game canvases edge-to-edge on mobile browsers."""
from pathlib import Path
import sys
for name in sys.argv[1:]:
    p=Path(name)
    text=p.read_text().replace('<html lang="en">','<html lang="ko">')
    text=text.replace('width=device-width, user-scalable=no, initial-scale=1.0','width=device-width, user-scalable=no, initial-scale=1.0, viewport-fit=cover')
    text=text.replace('</head>', '<style>html,body{width:100%;height:100%;height:100dvh;overscroll-behavior:none}#canvas{touch-action:none}body{position:fixed;inset:0}</style></head>')
    p.write_text(text)
