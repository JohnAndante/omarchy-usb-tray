// Turns `lsblk -b -J -o NAME,LABEL,SIZE,FSTYPE,MOUNTPOINT,RM,HOTPLUG,TRAN,UUID,TYPE`
// output into a flat list of mountable removable rows. The `-b` flag reports
// SIZE in raw bytes so minSizeMb filtering is exact; formatSize() below
// turns it back into a human-readable string for display.
//
// A device counts as removable when it (or its parent disk) is RM=1
// (pendrive, SD card) or HOTPLUG=1 with TRAN=usb (external USB SSD/HDD), or
// simply HOTPLUG=1 regardless of transport when includeAllHotplug is set.
// The flag propagates from a disk down to its partitions, since lsblk only
// reports rm/hotplug/tran reliably on the physical device row. Only rows
// that actually carry a filesystem are surfaced — an unformatted disk or
// an unformatted partition has nothing to mount.
function formatSize(bytes) {
  var value = Number(bytes) || 0
  var units = ["B", "K", "M", "G", "T", "P"]
  var i = 0
  while (value >= 1024 && i < units.length - 1) {
    value /= 1024
    i++
  }
  var rounded = i === 0 ? String(Math.round(value)) : value.toFixed(1)
  return rounded + units[i]
}

function parseDevices(jsonText, options) {
  options = options || {}
  var minSizeBytes = (Number(options.minSizeMb) || 0) * 1024 * 1024
  var includeAllHotplug = !!options.includeAllHotplug

  var result = []
  var data

  try {
    data = JSON.parse(jsonText)
  } catch (e) {
    return result
  }

  function walk(node, parentRemovable) {
    if (!node) return

    var isPartOrDisk = node.type === "part" || node.type === "disk"
    var ownRemovable = !!node.rm || (!!node.hotplug && (includeAllHotplug || node.tran === "usb"))
    var removable = ownRemovable || parentRemovable
    var sizeBytes = Number(node.size) || 0

    if (isPartOrDisk && removable && node.fstype && sizeBytes >= minSizeBytes) {
      result.push({
        name: node.name || "",
        path: "/dev/" + (node.name || ""),
        label: node.label || node.name || "",
        size: formatSize(sizeBytes),
        fstype: node.fstype || "",
        mountpoint: node.mountpoint || "",
        uuid: node.uuid || ""
      })
    }

    if (node.children) {
      for (var i = 0; i < node.children.length; i++) walk(node.children[i], removable)
    }
  }

  var blockdevices = (data && data.blockdevices) || []
  for (var j = 0; j < blockdevices.length; j++) walk(blockdevices[j], false)

  return result
}

if (typeof module !== "undefined") {
  module.exports = {
    formatSize: formatSize,
    parseDevices: parseDevices
  }
}
