# Full original game foundation

OpenClonk 8.1, tag v8.1, commit 5c6fadfb266d97b27904fd77f3f6e7f808bcb85e.
https://github.com/openclonk/openclonk/tree/v8.1

The complete source is pinned in foundations/openclonk. The earlier master revision remains part of the import history; the playable scenario uses the matching 8.1 release.

Official Windows engine: https://www.openclonk.org/builds/release/8.1/openclonk-8.1-x64.exe
Installer SHA256: cb595b8b7495b9c68cb21db01c852ff3c12f20de51d72dfc99009aa1093f0b01

Original engine, tools, command movement, ladder control, inventory, construction and dialogue code remain upstream code. Scenario files add map geometry, room/guest/economy state, NPC routing policy and dialogue options. No old Godot simulation/controller is imported.

Engine code: ISC (COPYING). Content: planet/COPYING and per-file notices; retain original AUTHORS and Credits.txt. Also preserve third-party notices including LGPL.txt and TRADEMARK. No extended soundtrack is added. The portable pack keeps the original game files and notices and adds a scenario, launcher, player profile and documentation.
