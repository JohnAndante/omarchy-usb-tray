# omarchy-usb-tray

Bar widget for [Omarchy](https://omarchy.org/) that shows a removable-media
(USB pendrive / SD card / external USB drive) indicator, similar to what
other desktop environments show next to the Bluetooth/network tray icons.

The icon only appears in the bar when a removable device is detected, and
switches between two states:

- **Solid icon** — at least one removable device is mounted.
- **Outline icon** — a removable device is present but not mounted
  (e.g. after clicking "Unmount" without ejecting).

Clicking it opens a popup listing every detected device with its label,
size, and mountpoint, plus per-device actions:

- **Mount** / **Unmount** — mount or unmount the filesystem.
- **Open** — open the mountpoint in the default file manager.
- **Eject** — safely unmount and power off the USB port (same as "Safely
  Remove Hardware" on other OSes). This fully powers down the device at
  the kernel/USB level, so it disappears from `lsblk`/`lsusb` entirely
  until physically unplugged and replugged — that's expected, not a bug.

A right-click on the bar icon, or the **Eject all** button in the popup,
ejects every mounted device at once (configurable — see Settings below).

## Requirements

- `udisks2` (already the default on most desktop setups; provides
  `udisksctl`, used for mount/unmount/power-off).
- `util-linux` (`lsblk`, used to enumerate devices).
- A file manager registered as the default handler for directories, for
  the "Abrir" action (`xdg-open`).

## Install

```bash
omarchy plugin add https://github.com/JohnAndante/omarchy-usb-tray.git --enable
```

Or clone manually into `~/.config/omarchy/plugins/johnandante.removable-media/`
and enable it with `omarchy plugin enable johnandante.removable-media`.

## Settings

Set any of these as extra keys on the widget's `shell.json` layout entry,
alongside its `id`:

```json
{
  "id": "johnandante.removable-media",
  "popupWidth": 460,
  "minSizeMb": 32,
  "includeAllHotplug": false,
  "rightClickAction": "eject-all",
  "mountedIcon": "󱊞",
  "ejectedIcon": "󱊟"
}
```

| Setting             | Type    | Default   | What it does                                                                          |
|----------------------|---------|-----------|----------------------------------------------------------------------------------------|
| `popupWidth`         | number  | `420`     | Popup content width in px.                                                             |
| `minSizeMb`          | number  | `0`       | Ignore partitions smaller than this size (e.g. skip tiny EFI/recovery partitions).      |
| `includeAllHotplug`  | boolean | `false`   | Treat any hotplug block device as removable, not just `TRAN=usb` ones.                 |
| `rightClickAction`   | string  | `"eject-all"` | `"eject-all"` or `"open-popup"` — what a right-click on the bar icon does.         |
| `mountedIcon`        | string  | nf-md-usb_flash_drive glyph | Bar/popup glyph shown while at least one device is mounted.          |
| `ejectedIcon`        | string  | nf-md-usb_flash_drive_outline glyph | Bar/popup glyph shown while devices are present but unmounted. |

## How it works

There's no native Quickshell service for UDisks2 (unlike Bluetooth/Pipewire/
UPower), so this plugin shells out instead: a long-running `udisksctl
monitor` process signals *when* something changed (plug/unplug/mount/
unmount), and each signal triggers a one-shot `lsblk -b -J` to rebuild the
full device list (`-b` reports sizes in raw bytes, so `minSizeMb`
filtering is exact). This avoids polling while staying reactive.

A device is considered removable when it (or its parent disk) reports
`RM=1` (pendrive, SD card) or `HOTPLUG=1` with `TRAN=usb` (external USB
SSD/HDD), or any `HOTPLUG=1` device when `includeAllHotplug` is set. Only
partitions carrying a filesystem are listed.

## License

MIT — see [LICENSE](LICENSE).
