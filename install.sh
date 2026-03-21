kpackagetool6 --type Plasma/Wallpaper --remove com.plasma.wallpaper.potd-enhanced
rm -rf ~/.cache/plasma-wallpaper-potd-enhanced
kpackagetool6 --type Plasma/Wallpaper --install package/
plasmashell --replace & disown
