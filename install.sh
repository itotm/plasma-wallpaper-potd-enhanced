#!/bin/bash
set -e

PLUGIN_ID="com.plasma.wallpaper.potd-enhanced"
PLUGIN_DIR="$HOME/.local/share/plasma/wallpapers/$PLUGIN_ID"
TYPE="Plasma/Wallpaper"

if [[ -d "$PLUGIN_DIR" ]]; then
    kpackagetool6 --type "$TYPE" --upgrade package/ || {
        kpackagetool6 --type "$TYPE" --remove "$PLUGIN_ID" 2>/dev/null || true
        kpackagetool6 --type "$TYPE" --install package/
    }
else
    kpackagetool6 --type "$TYPE" --install package/
fi

rm -rf ~/.cache/plasma-wallpaper-potd-enhanced ~/.cache/plasmashell/qmlcache

nohup plasmashell --replace </dev/null >/dev/null 2>&1 &
disown 2>/dev/null || true

echo "Installation complete."
