// Run by omarchy-idle-inhibit-bridge while an app holds a DBus screensaver inhibit.
// Omarchy's idle service only honours Wayland idle inhibitors; Hyprland honours one on any mapped
// surface, so a transparent 1x1 surface on the background layer is enough.
import QtQuick
import Quickshell
import Quickshell.Wayland

ShellRoot {
  PanelWindow {
    id: surface

    anchors.top: true
    anchors.left: true
    implicitWidth: 1
    implicitHeight: 1
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "omarchy-idle-inhibitor"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  }

  // Hyprland checks the surface's visibility only when the inhibitor is created, and Quickshell
  // creates it before the surface is mapped. Wait for the map, or the inhibitor is ignored.
  IdleInhibitor {
    id: inhibitor
    window: surface
    enabled: false
  }

  Timer {
    interval: 500
    running: true
    onTriggered: inhibitor.enabled = true
  }
}
