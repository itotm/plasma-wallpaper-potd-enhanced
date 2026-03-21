# Picture of the Day Enhanced

A KDE Plasma 6 wallpaper plugin that displays Bing's daily "Picture of the Day"
with enhanced features like copyright overlay, region selection, automatic
refresh, and system notifications.

<!-- screenshot.png -->

## Features

- Displays Bing's daily high-resolution wallpaper (UHD landscape or portrait).
- Copyright overlay with configurable position (top/bottom, left/right).
- Region/market selection to get localized daily images.
- Automatic wallpaper refresh at configurable intervals.
- Right-click context menu: "Open in Browser" and "Refresh Wallpaper".
- System notifications on refresh and on error (both individually toggleable).
- Retry mechanism for network failures with configurable attempts and delay.
- Multiple fill modes: scaled and cropped, scaled, fit, centered, tiled.
- Blur background option for letterboxed images.
- Smooth fade transition between wallpaper changes.

## Known Issues

- The plugin cannot be set as lock screen wallpaper due to
  [networking restrictions](https://bugs.kde.org/show_bug.cgi?id=483094) in the
  lock screen context.
- Current wallpaper may not be shown on first plugin activation.

## Installation

### From source

Installation requires `kpackagetool6`, available as:

- `kpackage` on Arch-based distros
- `kpackagetool6` on openSUSE-based distros
- `kf6-kpackage` on Debian-based distros

```bash
git clone https://github.com/itotm/plasma-wallpaper-potd-enhanced.git
cd plasma-wallpaper-potd-enhanced
kpackagetool6 --type Plasma/Wallpaper --install package/

# restart plasmashell
plasmashell --replace & disown
```

To update an existing installation:

```bash
kpackagetool6 --type Plasma/Wallpaper --upgrade package/
plasmashell --replace & disown
```

### Setup

1. Right-click on the desktop and select **Configure Desktop and Wallpaper**.
2. Choose **Picture of the Day Enhanced** as the wallpaper type.
3. Close the settings window, then re-open it — the daily image should load.

If the wallpaper is not fetched or applied, try refreshing from the right-click
context menu or restarting the shell.

## Reporting Bugs

Please use the
[issue tracker](https://github.com/itotm/plasma-wallpaper-potd-enhanced/issues)
to report bugs.

## Credits

- Originally forked from [plasma-wallpaper-wallhaven-reborn](https://github.com/Blacksuan19/plasma-wallpaper-wallhaven-reborn)

## License

[GPL-2.0-or-later](LICENSE)
