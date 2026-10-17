# Whole-game foundation: Ironbound

This import is the complete upstream project, not selected components.

- Source: https://github.com/destinjones/ironbound
- Pinned commit: bc5b7de9cc696fdd8ff235aadf1a702300568269
- Code: MIT; retain LICENSE, LOGO_LICENSES.md and ASSET_CREDITS.md.
- Godot: 4.7.2. Original gameplay and assets are unchanged.
- Full source is linked as the `foundations/ironbound` Git submodule.
- Fetch it with `git submodule update --init --recursive`, open its project.godot and press Play.
- Original Windows release: https://github.com/destinjones/ironbound/releases/latest
- CI clones the complete project at the pinned revision and runs its own Web export script.
- Standalone original browser game: ../foundation/ on our Pages deployment.

## Why this candidate

This is an integrated playable 3D RTS/city-management project with construction, unit orders, resources, storage, AI, save/load, menus and a tutorial. Its camera, input, navigation, UI and gameplay stay together. No bridge to the old inn Simulation or main.gd is introduced.

It is NOT already an inn game. Bedrooms, guests, meals, underground floors, prisoners and stealth are not implemented by this import. The candidate is PC-oriented; right-click orders and landscape UI still need a focused touch adaptation. It is a candidate foundation, not evidence of a completed stable mobile inn.

## Actual execution evidence

Linux Godot 4.7.2, OpenGL Compatibility, real 1280x720 viewport. A separate capture script opens the original match setup and original Loading scene, then records the starting match. No upstream production gameplay file is modified. `ironbound-original.webp` shows that original match.

Observed: original match rendered with buildings, units, minimap, resource bar and tutorial. Duplicate UI sound signal connections were logged during setup. Renderer feature warnings and exit resource warnings were also observed. Headless editor/export also logged DesertMapGenerator Nil lookup errors; Web export still completed (73 MB PCK + 38 MB WASM). These are unresolved upstream issues and this baseline is not yet approved as the final game foundation. No claim of bug-free play, full campaign verification or mobile usability is made.

The older Open RTS was also downloaded in full; its fog rendered black under this environment's Compatibility renderer, so it was not selected for this runnable baseline.

## Adaptation boundary

1. Keep this untouched baseline playable.
2. Make one inn scenario inside the upstream project using upstream construction, selection and movement.
3. Establish a touch-only service loop and placement flow before adding underground simulation.
4. Add inn-specific data and systems inside that fork; do not reconnect the old custom controller.

No before/after visual comparison is claimed: this delivery imports the original game without changing its UI or camera.
