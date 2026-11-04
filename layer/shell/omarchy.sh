# Omarchy's shell additions for bash and zsh: herdr's layout commands and the coding-agent shortcuts.
# ~/.bashrc and ~/.zshrc source this only in the Hyprland (Omarchy) session, where OMARCHY_PATH is set,
# so GNOME terminals stay as they were.
[ -n "$OMARCHY_PATH" ] || return 0

for omarchy_ubuntu_rc in herdr agents; do
  . "$HOME/.local/share/omarchy-ubuntu/shell/$omarchy_ubuntu_rc.sh"
done
unset omarchy_ubuntu_rc
