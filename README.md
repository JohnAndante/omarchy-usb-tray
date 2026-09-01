# omarchy-usb-tray

Bar widget for [Omarchy](https://omarchy.org/) that shows a removable-media
(USB pendrive / SD card / external USB drive) indicator, similar to what
other desktop environments show next to the Bluetooth/network tray icons.

The icon only appears in the bar when a removable device is detected, and
switches between two states:

- **Solid icon** — at least one removable device is mounted.
- **Outline icon** — a removable device is present but not mounted
  (e.g. after clicking "Desmontar" without ejecting).

Clicking it opens a popup listing every detected device with its label,
size, and mountpoint, plus per-device actions:

- **Montar** / **Desmontar** — mount or unmount the filesystem.
- **Abrir** — open the mountpoint in the default file manager.
- **Ejetar** — safely unmount and power off the USB port (same as "Safely
  Remove Hardware" on other OSes). This fully powers down the device at
  the kernel/USB level, so it disappears from `lsblk`/`lsusb` entirely
  until physically unplugged and replugged — that's expected, not a bug.

A right-click on the bar icon, or the **Ejetar tudo** button in the popup,
ejects every mounted device at once.

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

## How it works

There's no native Quickshell service for UDisks2 (unlike Bluetooth/Pipewire/
UPower), so this plugin shells out instead: a long-running `udisksctl
monitor` process signals *when* something changed (plug/unplug/mount/
unmount), and each signal triggers a one-shot `lsblk -J` to rebuild the
full device list. This avoids polling while staying reactive.

A device is considered removable when it (or its parent disk) reports
`RM=1` (pendrive, SD card) or `HOTPLUG=1` with `TRAN=usb` (external USB
SSD/HDD). Only partitions carrying a filesystem are listed.

## License

MIT — see [LICENSE](LICENSE).
