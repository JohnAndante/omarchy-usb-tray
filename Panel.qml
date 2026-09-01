import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons
import "Model.js" as Model

// Bar icon for removable/USB storage. No native Quickshell service exists
// for UDisks2 (unlike Bluetooth/Pipewire/UPower), so state comes from
// shelling out: a long-running `udisksctl monitor` process signals *when*
// something changed (plug/unplug/mount), and each signal triggers a
// one-shot `lsblk -J` to rebuild the full device list. This avoids polling
// while staying reactive.
Panel {
  id: root
  moduleName: "johnandante.usb-tray"
  ipcTarget: "johnandante.usb-tray"
  manageIpc: false

  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color foreground: bar ? bar.barForeground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.5)

  // nf-md-usb_flash_drive (U+F129E) for at least one mounted device, and
  // nf-md-usb_flash_drive_outline (U+F129F) when devices are present but
  // none are mounted (unmounted/ejected but still known to the system).
  // Both confirmed against the official nerd-fonts glyphnames.json.
  // Overridable via the "mountedIcon"/"ejectedIcon" shell.json settings.
  readonly property string deviceGlyphMounted: root.setting("mountedIcon", "󱊞")
  readonly property string deviceGlyphEjected: root.setting("ejectedIcon", "󱊟")

  property var devices: []
  property var commandQueue: []
  readonly property var mountedDevices: devices.filter(function(d) { return d.mountpoint !== "" })

  readonly property string icon: mountedDevices.length > 0 ? deviceGlyphMounted : deviceGlyphEjected

  // BarIconButton always reports a fixed slotSize as implicitWidth
  // regardless of text content, so an empty icon does NOT collapse the bar
  // slot on its own. Hiding the whole widget (like omarchy.system-update's
  // `visible: updateAvailable`) is what actually frees the bar space —
  // QtQuick's Row/Flow positioners skip invisible children entirely.
  visible: devices.length > 0

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function refreshDevices() {
    if (lsblkProc.running) return
    lsblkProc.running = true
  }

  function enqueue(cmd) {
    root.commandQueue = root.commandQueue.concat([cmd])
  }

  function runQueue() {
    if (actionProc.running || root.commandQueue.length === 0) return
    var next = root.commandQueue[0]
    root.commandQueue = root.commandQueue.slice(1)
    actionProc.command = next
    actionProc.running = true
  }

  function mountDevice(dev) {
    enqueue(["udisksctl", "mount", "-b", dev.path])
    runQueue()
  }

  function unmountDevice(dev) {
    enqueue(["udisksctl", "unmount", "-b", dev.path])
    runQueue()
  }

  // udisksctl power-off refuses a device with a mounted filesystem
  // (org.freedesktop.UDisks2.Error.Busy), so unmount first whenever the
  // device is still mounted.
  function ejectDevice(dev) {
    if (dev.mountpoint !== "") enqueue(["udisksctl", "unmount", "-b", dev.path])
    enqueue(["udisksctl", "power-off", "-b", dev.path])
    runQueue()
  }

  function openDevice(dev) { if (dev.mountpoint !== "") Quickshell.execDetached(["xdg-open", dev.mountpoint]) }

  function ejectAll() {
    if (root.mountedDevices.length === 0) return
    root.mountedDevices.forEach(function(dev) {
      enqueue(["udisksctl", "unmount", "-b", dev.path])
      enqueue(["udisksctl", "power-off", "-b", dev.path])
    })
    runQueue()
  }

  Component.onCompleted: refreshDevices()

  // Long-running: any output line means *something* changed. udisksctl
  // monitor prints multi-line, multi-event bursts for a single physical
  // plug/unplug, so the actual refresh is debounced below.
  Process {
    id: monitorProc
    command: ["udisksctl", "monitor"]
    running: true
    stdout: SplitParser {
      onRead: function(line) {
        if (String(line).trim() !== "") refreshDebounce.restart()
      }
    }
  }

  Timer {
    id: refreshDebounce
    interval: 400
    repeat: false
    onTriggered: root.refreshDevices()
  }

  // "-b" reports SIZE in raw bytes so the "minSizeMb" setting can filter
  // exactly instead of parsing lsblk's human-readable size strings.
  Process {
    id: lsblkProc
    command: ["lsblk", "-b", "-J", "-o", "NAME,LABEL,SIZE,FSTYPE,MOUNTPOINT,RM,HOTPLUG,TRAN,UUID,TYPE"]
    stdout: StdioCollector {
      onStreamFinished: function() {
        root.devices = Model.parseDevices(text, {
          minSizeMb: root.setting("minSizeMb", 0),
          includeAllHotplug: root.setting("includeAllHotplug", false) === true
        })
      }
    }
  }

  // Shared by all mount/unmount/eject actions, including the eject-all
  // and unmount-then-power-off queues — udisksctl calls are quick, and
  // serializing them avoids clobbering `command` from overlapping clicks.
  Process {
    id: actionProc
    stderr: SplitParser {
      onRead: function(line) {
        var text = String(line).trim()
        if (text !== "") console.warn("[usb-tray]", actionProc.command.join(" "), "->", text)
      }
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) console.warn("[usb-tray] command failed with exit code", exitCode)
      if (root.commandQueue.length > 0) root.runQueue()
      else root.refreshDevices()
    }
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.icon
    tooltipText: root.devices.length > 0
      ? (root.devices.length === 1 ? "1 removable device" : root.devices.length + " removable devices")
      : ""
    // "rightClickAction" shell.json setting: "eject-all" (default) or
    // "open-popup".
    onPressed: function(b) {
      if (b === Qt.RightButton && root.setting("rightClickAction", "eject-all") !== "open-popup") root.ejectAll()
      else root.toggle()
    }
  }

  PopupCard {
    id: popup
    anchorItem: button
    bar: root.bar
    owner: root
    open: root.opened
    // "popupWidth" shell.json setting overrides the default popup width.
    contentWidth: popup.fittedContentWidth(Style.space(Number(root.setting("popupWidth", 420))))
    contentHeight: popup.fittedContentHeight(column.implicitHeight)

    Column {
      id: column
      width: parent.width
      spacing: Style.spacing.lg

      PanelHero {
        width: parent.width
        title: "USB Tray"
        meta: root.devices.length === 0
          ? "Nothing connected"
          : (root.devices.length === 1 ? "1 device" : root.devices.length + " devices")
        foreground: root.foreground
        fontFamily: root.fontFamily
        iconComponent: Component {
          Text {
            text: root.icon
            font.family: root.fontFamily
            font.pixelSize: Style.font.display
            color: root.foreground
          }
        }
      }

      PanelSeparator {
        width: parent.width
        foreground: root.foreground
      }

      Item {
        width: parent.width
        height: Math.max(deviceHeader.implicitHeight, ejectAllButton.implicitHeight)
        visible: root.mountedDevices.length > 0

        PanelSectionHeader {
          id: deviceHeader
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          text: "DEVICES"
          foreground: root.foreground
          fontFamily: root.fontFamily
        }

        Button {
          id: ejectAllButton
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          text: "Eject all"
          fontFamily: root.fontFamily
          foreground: root.foreground
          onClicked: root.ejectAll()
        }
      }

      // Section header alone, for the no-mounted-devices case (still shows
      // "DEVICES" above an unmounted-but-present drive without an
      // eject-all button that would have nothing to do).
      PanelSectionHeader {
        visible: root.devices.length > 0 && root.mountedDevices.length === 0
        text: "DEVICES"
        foreground: root.foreground
        fontFamily: root.fontFamily
      }

      Text {
        width: parent.width
        visible: root.devices.length === 0
        text: "No removable device connected"
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.WordWrap
      }

      Repeater {
        model: root.devices

        delegate: Column {
          id: deviceRow
          required property var modelData
          required property int index
          width: column.width
          spacing: Style.spacing.sm

          Item {
            width: parent.width
            height: Math.max(labelColumn.implicitHeight, actionsFlow.implicitHeight)

            Column {
              id: labelColumn
              anchors.left: parent.left
              anchors.right: actionsFlow.left
              anchors.rightMargin: Style.spacing.md
              anchors.verticalCenter: parent.verticalCenter
              spacing: 2

              Text {
                width: parent.width
                text: deviceRow.modelData.label
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                font.bold: true
                elide: Text.ElideRight
              }
              Text {
                width: parent.width
                text: deviceRow.modelData.size + (deviceRow.modelData.mountpoint !== ""
                  ? " · " + deviceRow.modelData.mountpoint
                  : " · not mounted")
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
              }
            }

            Flow {
              id: actionsFlow
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.spacing.sm

              Button {
                visible: deviceRow.modelData.mountpoint === ""
                text: "Mount"
                fontFamily: root.fontFamily
                foreground: root.foreground
                onClicked: root.mountDevice(deviceRow.modelData)
              }
              Button {
                visible: deviceRow.modelData.mountpoint !== ""
                text: "Open"
                fontFamily: root.fontFamily
                foreground: root.foreground
                onClicked: root.openDevice(deviceRow.modelData)
              }
              Button {
                visible: deviceRow.modelData.mountpoint !== ""
                text: "Unmount"
                fontFamily: root.fontFamily
                foreground: root.foreground
                onClicked: root.unmountDevice(deviceRow.modelData)
              }
              Button {
                text: "Eject"
                fontFamily: root.fontFamily
                foreground: root.foreground
                onClicked: root.ejectDevice(deviceRow.modelData)
              }
            }
          }

          PanelSeparator {
            width: parent.width
            foreground: root.foreground
            visible: deviceRow.index < root.devices.length - 1
          }
        }
      }
    }
  }
}
