# Changelog

## Unreleased

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
