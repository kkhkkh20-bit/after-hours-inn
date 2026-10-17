#!/usr/bin/env bash
set -euo pipefail
mkdir -p build/web build/windows/licenses
touch build/.gdignore
godot --headless --editor --import
godot --headless --export-release "Web" build/web/index.html
godot --headless --export-release "Windows Desktop" build/windows/AfterHours.exe
cp assets/furniture/License.txt build/windows/licenses/furniture-CC0.txt
cp assets/town/License.txt build/windows/licenses/town-CC0.txt
cp assets/fonts/OFL.txt build/windows/licenses/font-OFL.txt
cp assets/audio/LICENSE.txt build/windows/licenses/audio-original.txt
cp README.md build/windows/README.md
touch build/web/.nojekyll
printf '%s\n' "${GITHUB_SHA:-local}" > build/web/version.txt

# Independent 2D experiment. Root 3D project and its save directory stay intact.
mkdir -p build/web/sideview build/windows/sideview/licenses
sideview_project="$PWD/prototypes/sideview"
godot --headless --path "$sideview_project" --editor --import
godot --headless --path "$sideview_project" --export-release "Web" "$PWD/build/web/sideview/index.html"
godot --headless --path "$sideview_project" --export-release "Windows Desktop" "$PWD/build/windows/sideview/AfterHours2D.exe"
cp prototypes/sideview/assets/THIRD_PARTY.md build/windows/sideview/licenses/
cp prototypes/sideview/assets/OFL.txt build/windows/sideview/licenses/
printf '%s\n' "${GITHUB_SHA:-local}" > build/web/sideview/version.txt

python3 ci/mobile_shell.py build/web/index.html build/web/sideview/index.html

# Separate top-down inn fork. Restore original source-generated assets at build time.
tavern_project="$PWD/prototypes/tavern"
python3 -m pip install --quiet -r "$tavern_project/requirements-assets.txt"
python3 "$tavern_project/tools/build_assets.py"
cp assets/fonts/OFL.txt "$tavern_project/assets/ui/font/OFL.txt"
mkdir -p build/web/tavern build/windows/tavern/licenses
godot --headless --path "$tavern_project" --editor --import
godot --headless --path "$tavern_project" --export-release "Web" "$PWD/build/web/tavern/index.html"
godot --headless --path "$tavern_project" --export-release "Windows Desktop" "$PWD/build/windows/tavern/AfterHoursTavern.exe"
cp "$tavern_project/LICENSE" build/windows/tavern/licenses/restaurant-for-monsters-MIT.txt
cp "$tavern_project/UPSTREAM.md" build/windows/tavern/licenses/
cp assets/fonts/OFL.txt build/windows/tavern/licenses/font-OFL.txt
cp "$tavern_project/README.md" build/windows/tavern/
printf '%s\n' "${GITHUB_SHA:-local}" > build/web/tavern/version.txt
python3 ci/mobile_shell.py build/web/tavern/index.html
