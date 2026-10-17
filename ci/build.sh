#!/usr/bin/env bash
set -euo pipefail
mkdir -p build/web build/windows/licenses
touch build/.gdignore
godot --headless --editor --import
cmp scripts/object_context.gd prototypes/sideview/object_context.gd
cmp scripts/episode.gd prototypes/sideview/episode.gd
cmp scripts/episode_ui.gd prototypes/sideview/episode_ui.gd
timeout 45 godot --headless -- --episode-playthrough
godot --headless -- --episode-verify
godot --headless -- --verify
timeout 60 godot --headless -- --input-verify
godot --headless --export-release "Web" build/web/index.html
godot --headless --export-release "Windows Desktop" build/windows/AfterHours.exe
cp assets/furniture/License.txt build/windows/licenses/furniture-CC0.txt
cp assets/town/License.txt build/windows/licenses/town-CC0.txt
cp assets/fonts/OFL.txt build/windows/licenses/font-OFL.txt
cp README.md build/windows/README.md
touch build/web/.nojekyll
printf '%s\n' "${GITHUB_SHA:-local}" > build/web/version.txt

# Independent 2D experiment. Root 3D project and its save directory stay intact.
mkdir -p build/web/sideview build/windows/sideview/licenses
sideview_project="$PWD/prototypes/sideview"
godot --headless --path "$sideview_project" --editor --import
timeout 45 godot --headless --path "$sideview_project" -- --episode-playthrough
godot --headless --path "$sideview_project" -- --episode-verify
godot --headless --path "$sideview_project" -- --verify
timeout 110 godot --headless --path "$sideview_project" -- --input-verify
godot --headless --path "$sideview_project" --export-release "Web" "$PWD/build/web/sideview/index.html"
godot --headless --path "$sideview_project" --export-release "Windows Desktop" "$PWD/build/windows/sideview/AfterHours2D.exe"
cp prototypes/sideview/assets/THIRD_PARTY.md build/windows/sideview/licenses/
cp prototypes/sideview/assets/OFL.txt build/windows/sideview/licenses/
printf '%s\n' "${GITHUB_SHA:-local}" > build/web/sideview/version.txt

python3 ci/mobile_shell.py build/web/index.html build/web/sideview/index.html
