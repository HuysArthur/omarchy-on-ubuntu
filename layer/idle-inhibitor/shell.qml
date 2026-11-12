// Run by omarchy-idle-inhibit-bridge while an app holds a DBus screensaver inhibit.
// Omarchy's idle service only honours Wayland idle inhibitors; Hyprland honours one on a mapped surface
// with non-zero alpha, so a transparent 1x1 surface is enough. It must be on the overlay layer: while a
// window is fullscreen, Hyprland sets every lower layer's alpha to 0 and then ignores its inhibitor, so
// fullscreen video would let the screensaver start.
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
    WlrLayershell.layer: WlrLayer.Overlay
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
