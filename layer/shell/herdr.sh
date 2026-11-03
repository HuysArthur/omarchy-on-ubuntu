# Omarchy's herdr layout commands (hdl, hds, hdlm, hsl) and its `h` alias, for bash and zsh.
# ~/.bashrc and ~/.zshrc source this only in the Hyprland (Omarchy) session, where OMARCHY_PATH is set,
# so GNOME terminals stay as they were.
[ -n "$OMARCHY_PATH" ] && [ -r "$OMARCHY_PATH/default/bash/fns/herdr" ] || return 0

alias h=herdr

if [ -n "$ZSH_VERSION" ]; then
  # Omarchy writes these for bash (0-based arrays, word splitting). Functions defined under
  # `emulate -c` keep that emulation whenever they run, so they work as-is in zsh.
  emulate ksh -c '. "$OMARCHY_PATH/default/bash/fns/herdr"'
else
  . "$OMARCHY_PATH/default/bash/fns/herdr"
fi
