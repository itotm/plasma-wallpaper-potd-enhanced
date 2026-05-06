#!/bin/bash
set -e

PLUGIN_ID="com.plasma.wallpaper.potd-enhanced"
PLUGIN_DIR="$HOME/.local/share/plasma/wallpapers/$PLUGIN_ID"

# Prefer in-place upgrade to avoid Plasma reverting the active wallpaper
# to a different plugin while ours is momentarily uninstalled.
if [[ -d "$PLUGIN_DIR" ]]; then
    if ! kpackagetool6 --type Plasma/Wallpaper --upgrade package/; then
        echo "Upgrade failed, falling back to remove + install"
        kpackagetool6 --type Plasma/Wallpaper --remove "$PLUGIN_ID" 2>/dev/null || true
        kpackagetool6 --type Plasma/Wallpaper --install package/
    fi
else
    kpackagetool6 --type Plasma/Wallpaper --install package/
fi

# Clear plugin cache
rm -rf ~/.cache/plasma-wallpaper-potd-enhanced

# Clear plasmashell compiled QML/JS bytecode cache
# (hashed filenames, no way to target selectively)
rm -rf ~/.cache/plasmashell/qmlcache

# Restart plasmashell so the new QML is picked up.
# Use a detached subshell with setsid so it survives this script exiting,
# and redirect all stdio so the terminal isn't held open.
if command -v setsid >/dev/null 2>&1; then
    setsid -f plasmashell --replace </dev/null >/dev/null 2>&1 || \
        nohup plasmashell --replace </dev/null >/dev/null 2>&1 &
else
    nohup plasmashell --replace </dev/null >/dev/null 2>&1 &
fi
disown 2>/dev/null || true

cat <<'EOF'

Installation complete.
EOF
