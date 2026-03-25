#!/bin/bash
set -e

PLUGIN_ID="com.plasma.wallpaper.potd-enhanced"

# Remove old installation if present, then install fresh
kpackagetool6 --type Plasma/Wallpaper --remove "$PLUGIN_ID" 2>/dev/null || true
kpackagetool6 --type Plasma/Wallpaper --install package/

# Clear plugin cache
rm -rf ~/.cache/plasma-wallpaper-potd-enhanced

# Clear plasmashell compiled QML/JS bytecode cache (hashed filenames, no way to target selectively)
rm -rf ~/.cache/plasmashell/qmlcache

# Restart plasmashell to apply
plasmashell --replace & disown
