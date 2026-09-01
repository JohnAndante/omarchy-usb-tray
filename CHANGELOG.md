# Changelog

## 1.1.1 - 2026-09-01

- Fixed the plugin's IPC target (`omarchy-shell johnandante.usb-tray open`,
  and `close`/`show`/`hide`/`toggle`) not working — a redundant `IpcHandler`
  copied from the Bluetooth plugin was losing the naming race against the
  base `Panel` component's own handler. Clicking the bar icon was never
  affected, only direct IPC calls.

## 1.1.0 - 2026-09-01

- **Breaking:** the plugin id changed from `johnandante.removable-media` to
  `johnandante.usb-tray` (to match the repo name), and the display name
  changed from "Removable Media" to "USB Tray". If you installed 1.0.0,
  the widget will silently disappear from your bar on upgrade — update
  the `id` in your `~/.config/omarchy/shell.json` bar layout entry from
  `johnandante.removable-media` to `johnandante.usb-tray`, and rename the
  plugin folder from `~/.config/omarchy/plugins/johnandante.removable-media/`
  to `~/.config/omarchy/plugins/johnandante.usb-tray/` (or just reinstall
  via `omarchy plugin add`).
- Translated all popup UI strings to English (title, section headers,
  button labels, tooltips, empty-state text). English is the standard
  across every Omarchy plugin, and there's no i18n framework in the shell.
- Added `popupWidth` setting — override the popup's default width (420px).
- Added `minSizeMb` setting — ignore partitions smaller than this size
  (e.g. EFI/recovery partitions on a partitioned pendrive). Switched the
  underlying `lsblk` query to raw bytes (`-b`) so this filters exactly.
- Added `includeAllHotplug` setting — treat any hotplug block device as
  removable, not just `TRAN=usb` ones (e.g. Thunderbolt external drives).
- Added `rightClickAction` setting — `"eject-all"` (default) or
  `"open-popup"`, controlling what a right-click on the bar icon does.
- Added `mountedIcon`/`ejectedIcon` settings — override the bar glyphs
  without editing `Panel.qml`.

## 1.0.0

- Initial release: removable/USB storage bar indicator with a popup to
  mount, unmount, and safely eject devices. Icon switches between a solid
  and an outline glyph depending on whether any device is mounted, and
  only appears in the bar while at least one removable device is present.
