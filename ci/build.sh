#!/usr/bin/env bash
set -euo pipefail
mkdir -p build/web build/windows/licenses
godot --headless --editor --import
godot --headless -- --verify
godot --headless -- --input-verify
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
godot --headless --path "$sideview_project" -- --verify
godot --headless --path "$sideview_project" -- --input-verify
godot --headless --path "$sideview_project" --export-release "Web" "$PWD/build/web/sideview/index.html"
godot --headless --path "$sideview_project" --export-release "Windows Desktop" "$PWD/build/windows/sideview/AfterHours2D.exe"
cp prototypes/sideview/assets/THIRD_PARTY.md build/windows/sideview/licenses/
cp prototypes/sideview/assets/OFL.txt build/windows/sideview/licenses/
printf '%s\n' "${GITHUB_SHA:-local}" > build/web/sideview/version.txt
