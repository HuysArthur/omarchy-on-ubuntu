# Sourced by the layer's omarchy-remove-preinstalls and omarchy-install-preinstalls.
# Omarchy's preinstalled apps that the Hyprland package bundles, by launcher (in /opt/hyprland/share/applications).
PREINSTALL_LAUNCHERS=(
  aether.desktop li.oever.aether.url-handler.desktop cliamp.desktop omacalc.desktop omawrite.desktop
  omacut.desktop hype.desktop monologue.desktop signed.desktop
)
PREINSTALL_APPS_DIR=$HOME/.local/share/applications
# First line of the launchers that hide them, so only those are removed again.
PREINSTALL_MARKER='# omarchy-ubuntu: preinstall removed (Remove > Preinstalls)'
PREINSTALLS_REMOVED=$HOME/.local/state/omarchy/preinstalls-removed
