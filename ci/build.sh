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
