// Turns `lsblk -J -o NAME,LABEL,SIZE,FSTYPE,MOUNTPOINT,RM,HOTPLUG,TRAN,UUID,TYPE`
// output into a flat list of mountable removable rows.
//
// A device counts as removable when it (or its parent disk) is RM=1
// (pendrive, SD card) or HOTPLUG=1 with TRAN=usb (external USB SSD/HDD).
// The flag propagates from a disk down to its partitions, since lsblk only
// reports rm/hotplug/tran reliably on the physical device row. Only rows
// that actually carry a filesystem are surfaced — an unformatted disk or
// an unformatted partition has nothing to mount.
function parseDevices(jsonText) {
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
    var ownRemovable = !!node.rm || (!!node.hotplug && node.tran === "usb")
    var removable = ownRemovable || parentRemovable

    if (isPartOrDisk && removable && node.fstype) {
      result.push({
        name: node.name || "",
        path: "/dev/" + (node.name || ""),
        label: node.label || node.name || "",
        size: node.size || "",
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
    parseDevices: parseDevices
  }
}
