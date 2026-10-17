#!/usr/bin/env bash
set -euo pipefail
# A whole upstream game, pinned; no scripts are merged into the inn prototype.
root_dir="$PWD"
source_dir="$root_dir/build/foundation-source"
upstream_commit=bc5b7de9cc696fdd8ff235aadf1a702300568269
if [ ! -d "$source_dir/.git" ]; then
  git clone --no-checkout https://github.com/destinjones/ironbound.git "$source_dir"
fi
git -C "$source_dir" checkout --detach "$upstream_commit"
GODOT="${GODOT:-godot}" bash "$source_dir/tools/web/export.sh" "$root_dir/build/web/foundation"
mkdir -p "$root_dir/build/web/foundation/licenses"
cp "$source_dir/LICENSE" "$root_dir/build/web/foundation/licenses/ironbound-MIT.txt"
cp "$source_dir/ASSET_CREDITS.md" "$root_dir/build/web/foundation/licenses/ASSET_CREDITS.md"
printf '%s\n' "$upstream_commit" > "$root_dir/build/web/foundation/upstream-commit.txt"
