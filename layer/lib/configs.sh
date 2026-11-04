# The config files omarchy-on-ubuntu places in ~/.config, and where it keeps track of them. Sourced by install.sh
# and omarchy-reinstall-configs, which needs nothing but what's already installed (no sudo, network or checkout).

OMARCHY_PATH=$HOME/.local/share/omarchy
LAYER=$HOME/.local/share/omarchy-ubuntu
STATE=$HOME/.local/state/omarchy-ubuntu
C=$HOME/.config
stamp=$(date +%Y%m%d-%H%M%S)
BACKUP=$STATE/backup/$stamp
# Your versions of files we seeded, from omarchy-reinstall-configs. Separate from BACKUP, which uninstall.sh and
# prune restore as what was there before the install.
RESET_BACKUP=$STATE/reset-backup/$stamp
MANIFEST=$STATE/manifest
# Set by omarchy-reinstall-configs: put the default back for every file seed_configs places with --if-missing,
# instead of only creating the ones you don't have.
RESET_CONFIGS=

# Ours: session environment, Hyprland entry point, separate dconf profile.
OWN_CONFIGS=(uwsm/env hypr/hyprland.lua dconf/hyprland.profile)

record() { mkdir -p "$STATE"; grep -qxF "$1" "$MANIFEST" 2>/dev/null || echo "$1" >>"$MANIFEST"; }

backup() {
  local rel=${1#"$HOME"/} root=$BACKUP
  [[ -n $RESET_CONFIGS ]] && grep -qxF "$1" "$MANIFEST" 2>/dev/null && root=$RESET_BACKUP
  mkdir -p "$root/$(dirname "$rel")"
  cp -a "$1" "$root/$rel"
}

# put SRC DEST [--if-missing|--keep]: copy a config file into place, backing up whatever was there.
# Both flags leave an existing file alone: --if-missing unless configs are being reset, --keep always.
put() {
  local src=$1 dest=$2 mode=${3:-}
  if [[ -e $dest || -L $dest ]]; then
    [[ $mode == --keep ]] && return 0
    [[ $mode == --if-missing && -z $RESET_CONFIGS ]] && return 0
    cmp -s "$src" "$dest" && { record "$dest"; return 0; }
    backup "$dest"
    # A link (dotfile managers) is replaced, not written through: the backup is the link, so its target has to stay.
    [[ ! -L $dest ]] || rm -f "$dest"
  fi
  mkdir -p "$(dirname "$dest")"
  cp "$src" "$dest"
  record "$dest"
}

seed_configs() {
  local f src status w max_width=0 tmp

  # Omarchy's personal-override templates: only when you don't have your own yet.
  for f in bindings looknfeel autostart; do
    put "$OMARCHY_PATH/config/hypr/$f.lua" "$C/hypr/$f.lua" --if-missing
  done

  # input.lua and monitors.lua are generated for this machine. They go in the layer's config/ first, where
  # omarchy-refresh-config finds them.
  mkdir -p "$LAYER/config/hypr"

  # shellcheck disable=SC1091
  . /etc/default/keyboard 2>/dev/null || true
  cat >"$LAYER/config/hypr/input.lua" <<EOF
-- Personal input overrides; settings here replace Omarchy's defaults.
-- Keyboard layout taken from Ubuntu (/etc/default/keyboard) at install time.
-- See $OMARCHY_PATH/config/hypr/input.lua for more examples.
hl.config({
  input = {
    kb_layout = "${XKBLAYOUT:-us}",
    kb_variant = "${XKBVARIANT:-}",
    kb_options = "compose:caps${XKBOPTIONS:+,$XKBOPTIONS}",
  },
})
EOF
  put "$LAYER/config/hypr/input.lua" "$C/hypr/input.lua" --if-missing

  # Omarchy assumes HiDPI (scale 2). Use 1 when every connected screen is at most 1920px wide.
  for status in /sys/class/drm/card*-*/status; do
    [[ $(<"$status") == connected ]] || continue
    w=$(head -1 "$(dirname "$status")/modes" 2>/dev/null | cut -dx -f1)
    [[ $w =~ ^[0-9]+$ ]] && ((w > max_width)) && max_width=$w
  done
  sed -e 's/^local omarchy_gdk_scale = .*/local omarchy_gdk_scale = '"$( ((max_width > 1920)) && echo 2 || echo 1)"'/' \
      -e 's/^local omarchy_monitor_scale = .*/local omarchy_monitor_scale = '"$( ((max_width > 1920)) && echo '"auto"' || echo 1)"'/' \
      "$OMARCHY_PATH/config/hypr/monitors.lua" >"$LAYER/config/hypr/monitors.lua"
  put "$LAYER/config/hypr/monitors.lua" "$C/hypr/monitors.lua" --if-missing

  # Omarchy app configs, only where you have none. (config/autostart is skipped on purpose: GNOME would run it too.)
  # GNOME uses the same apps and the same files, so a reset leaves those alone; only config/omarchy is the session's.
  while IFS= read -r -d '' src; do
    put "$src" "$C/${src#"$OMARCHY_PATH"/config/}" --if-missing
  done < <(find "$OMARCHY_PATH/config/omarchy" -type f -print0)
  while IFS= read -r -d '' src; do
    put "$src" "$C/${src#"$OMARCHY_PATH"/config/}" --keep
  done < <(find "$OMARCHY_PATH/config/ghostty" "$OMARCHY_PATH/config/btop" "$OMARCHY_PATH/config/imv" \
    "$OMARCHY_PATH/config/lazygit" "$OMARCHY_PATH/config/herdr" -type f -print0)

  # Screensaver and About text, as Omarchy's own installer seeds them.
  put "$OMARCHY_PATH/logo.txt" "$C/omarchy/branding/screensaver.txt" --if-missing
  put "$OMARCHY_PATH/icon.txt" "$C/omarchy/branding/about.txt" --if-missing

  # Portal choice (screen sharing, file pickers) for the Hyprland session; only read when the desktop is Hyprland.
  put /opt/hyprland/share/xdg-desktop-portal/hyprland-portals.conf "$C/xdg-desktop-portal/hyprland-portals.conf" --if-missing

  # Default apps and terminal for the Hyprland session only (desktop-specific files GNOME ignores).
  put "$OMARCHY_PATH/config/hyprland-mimeapps.list" "$C/hyprland-mimeapps.list" --if-missing
  tmp=$(mktemp)
  echo com.mitchellh.ghostty.desktop >"$tmp"
  put "$tmp" "$C/hyprland-xdg-terminals.list" --if-missing
  rm -f "$tmp"
}
