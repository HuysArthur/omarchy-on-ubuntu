#!/usr/bin/env bash
# Installs Hyprland + the Omarchy desktop on Ubuntu 26.04 as an extra login session next to GNOME.
# Safe to re-run: it updates in place and backs up any file it replaces.
set -euo pipefail

REPO=$(cd "$(dirname "$0")" && pwd)
OMARCHY_REPO=https://github.com/basecamp/omarchy
OMARCHY_REF=v4.5.0
NERD_FONTS_VERSION=v3.4.0
# Herdr (Omarchy's terminal workspace manager, Super+Ctrl+Return) is an Arch package; on Ubuntu we use the
# static release binary. Checksum from https://herdr.dev/latest.json. herdr updates itself afterwards (herdr update).
HERDR_VERSION=v0.9.5
HERDR_SHA256=14d9e8bc8b4a9e0118d77c32266f76d461f09b40342eb23752960bd89f59929d

OMARCHY_PATH=$HOME/.local/share/omarchy
LAYER=$HOME/.local/share/omarchy-ubuntu
STATE=$HOME/.local/state/omarchy-ubuntu
BACKUP=$STATE/backup/$(date +%Y%m%d-%H%M%S)
MANIFEST=$STATE/manifest
# Files every run places (a subset of MANIFEST). A run that no longer places one removes it, so switching
# back from a pull request (omarchy-channel-set) undoes what it installed.
MANAGED=$STATE/managed

# Desktop pieces Omarchy expects, by their Ubuntu names. Nothing here replaces or reconfigures GNOME.
PACKAGES=(
  ghostty xdg-terminal-exec xdg-desktop-portal-hyprland xdg-desktop-portal-gtk gnome-keyring
  gawk gum jq socat inotify-tools wl-clipboard wtype grim slurp hyprpicker imagemagick
  brightnessctl pamixer playerctl wireplumber bluez bluez-tools udiskie upower ddcutil
  imv mpv mpv-mpris ffmpegthumbnailer evince nautilus gnome-themes-extra yaru-theme-icon
  btop fzf ripgrep bat eza fd-find zoxide fastfetch tree-sitter-cli lazygit neovim
  tesseract-ocr tesseract-ocr-eng zbar-tools qrencode libnotify-bin libxkbcommon-tools
  fonts-noto-color-emoji fonts-noto-cjk fonts-jetbrains-mono git curl xz-utils unzip
  x11-xserver-utils  # xsetroot, for the startup cursor
  python3-gi  # omarchy-idle-inhibit-bridge
)

say() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }
die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

record() { mkdir -p "$STATE"; grep -qxF "$1" "$MANIFEST" 2>/dev/null || echo "$1" >>"$MANIFEST"; }

backup() {
  local rel=${1#"$HOME"/}
  mkdir -p "$BACKUP/$(dirname "$rel")"
  cp -a "$1" "$BACKUP/$rel"
}

# manage PATH: PATH is placed on every run; prune removes it once a run stops placing it.
manage() {
  record "$1"
  grep -qxF "$1" "$MANAGED.new" 2>/dev/null || echo "$1" >>"$MANAGED.new"
}

# Remove what the previous run managed and this one didn't, restoring what it had replaced.
prune() {
  local path rel dir units=
  [[ -f $MANAGED ]] || return 0
  while IFS= read -r path; do
    grep -qxF "$path" "$MANAGED.new" 2>/dev/null && continue
    [[ -e $path || -L $path ]] || continue
    say "Removing $path (no longer installed)"
    if [[ $path == */systemd/user/* ]]; then
      [[ -L $path ]] || systemctl --user disable --now "$(basename "$path")" 2>/dev/null || true
      units=1
    fi
    if [[ $path == "$HOME"/* ]]; then
      rm -f "$path"
      rel=${path#"$HOME"/}
      for dir in $(ls -1d "$STATE"/backup/*/ 2>/dev/null | sort); do
        [[ -e $dir/$rel || -L $dir/$rel ]] && { cp -a "$dir/$rel" "$path"; break; }
      done
    else
      sudo rm -f "$path"
    fi
  done <"$MANAGED"
  [[ -z $units ]] || systemctl --user daemon-reload
}

# put SRC DEST [--if-missing]: copy a config file into place, backing up whatever was there.
put() {
  local src=$1 dest=$2 mode=${3:-}
  if [[ -e $dest || -L $dest ]]; then
    [[ $mode == --if-missing ]] && return 0
    cmp -s "$src" "$dest" && { record "$dest"; return 0; }
    backup "$dest"
  fi
  mkdir -p "$(dirname "$dest")"
  cp "$src" "$dest"
  record "$dest"
}

# ---- preflight ----------------------------------------------------------------
[[ $EUID -ne 0 ]] || die "Run as your normal user, not root. sudo is used where needed."
. /etc/os-release
[[ ${ID:-} == ubuntu && ${VERSION_ID:-} == 26.04 ]] || die "Built for Ubuntu 26.04, found ${PRETTY_NAME:-unknown}."
[[ $(dpkg --print-architecture) == amd64 ]] || die "Only amd64 is supported."

# shellcheck disable=SC1091
. "$REPO/build/versions.env"
pkg_version=${HYPRLAND_TAG#v}-$PKG_REVISION
# A local build (./build.sh: "~ubuntu") or an earlier download ("_ubuntu") of the pinned version.
DEB=${1:-$(ls -t "$REPO"/dist/hyprland-opt_"$pkg_version"[~_]ubuntu26.04_amd64.deb 2>/dev/null | head -1 || true)}
if [[ -z $DEB ]]; then
  # No local build: fetch the prebuilt package from this repo's GitHub release.
  origin=$(git -C "$REPO" remote get-url origin 2>/dev/null || true)
  slug=$(sed -nE 's#^(https://github\.com/|git@github\.com:)([^/]+/[^/]+)$#\2#p' <<<"$origin")
  slug=${slug%.git}
  [[ -n $slug ]] || die "No hyprland-opt .deb found. Run ./build.sh first, or pass one: ./install.sh path/to/hyprland-opt.deb"
  DEB=$REPO/dist/hyprland-opt_${pkg_version}_ubuntu26.04_amd64.deb
  say "Downloading hyprland-opt $pkg_version from github.com/$slug"
  mkdir -p "$REPO/dist"
  # Private repos need a logged-in gh; public ones download anonymously.
  if command -v gh >/dev/null && gh auth status >/dev/null 2>&1; then
    gh release download "hyprland-opt-$pkg_version" -R "$slug" -p "$(basename "$DEB")" -O "$DEB.part" --clobber
  else
    curl -fL --progress-bar -o "$DEB.part" \
      "https://github.com/$slug/releases/download/hyprland-opt-$pkg_version/$(basename "$DEB")"
  fi || die "Download failed (private repo? install gh and run gh auth login). Or build with ./build.sh, or copy the .deb over and pass its path."
  mv "$DEB.part" "$DEB"
fi
[[ -f $DEB ]] || die "$DEB not found."
DEB=$(realpath "$DEB")

# ---- packages -----------------------------------------------------------------
say "Installing $(basename "$DEB") and desktop packages (sudo)"
awk_before=$(readlink -f /usr/bin/awk)
sudo apt-get update -q
sudo apt-get install -y "$DEB" "${PACKAGES[@]}"
# Omarchy needs GNU awk; it gets it through the layer's awk wrapper. Installing gawk would also make it the
# system-wide awk, so put the system default back to what it was.
if [[ $(readlink -f /usr/bin/awk) != "$awk_before" ]]; then
  sudo update-alternatives --set awk "$awk_before" >/dev/null
fi

# Herdr goes to ~/.local/bin, where `herdr update` can replace it. An existing herdr is left alone.
# It's an extra: if it can't be downloaded, the rest of the install goes ahead.
HERDR_BIN=$HOME/.local/bin/herdr
if ! command -v herdr >/dev/null && [[ ! -x $HERDR_BIN ]]; then
  say "Installing herdr $HERDR_VERSION into ~/.local/bin"
  mkdir -p "$(dirname "$HERDR_BIN")"
  if curl -fL --progress-bar -o "$HERDR_BIN.part" \
      "https://github.com/herdrdev/herdr/releases/download/$HERDR_VERSION/herdr-linux-x86_64" &&
    echo "$HERDR_SHA256  $HERDR_BIN.part" | sha256sum -c --quiet -; then
    chmod +x "$HERDR_BIN.part"
    mv "$HERDR_BIN.part" "$HERDR_BIN"
    record "$HERDR_BIN"
  else
    rm -f "$HERDR_BIN.part"
    warn "Couldn't install herdr (download or checksum failed). Super+Ctrl+Return needs it; re-run install.sh to retry."
  fi
fi

# ---- Omarchy checkout (pinned) ------------------------------------------------
say "Fetching Omarchy $OMARCHY_REF into $OMARCHY_PATH"
# Shallow: the full Omarchy history is well over 1 GB, we only need the pinned release.
if [[ -d $OMARCHY_PATH/.git ]]; then
  git -C "$OMARCHY_PATH" fetch --quiet --depth 1 origin tag "$OMARCHY_REF"
elif [[ -e $OMARCHY_PATH ]]; then
  die "$OMARCHY_PATH exists but is not a git checkout. Move it away and re-run."
else
  git -c advice.detachedHead=false clone --quiet --depth 1 --branch "$OMARCHY_REF" "$OMARCHY_REPO" "$OMARCHY_PATH"
fi
# -f resets earlier patches; this checkout is managed by install.sh, keep personal changes in ~/.config.
git -C "$OMARCHY_PATH" -c advice.detachedHead=false checkout --quiet -f "$OMARCHY_REF" \
  || die "Could not check out $OMARCHY_REF in $OMARCHY_PATH."
for patch in "$REPO"/patches/*.patch; do
  [[ -e $patch ]] || continue
  git -C "$OMARCHY_PATH" apply "$patch" || die "Patch $(basename "$patch") does not apply to Omarchy $OMARCHY_REF."
done

# ---- Ubuntu layer ---------------------------------------------------------------
say "Installing the Ubuntu layer into $LAYER"
rm -rf "$LAYER"
cp -a "$REPO/layer" "$LAYER"

# ---- configs ------------------------------------------------------------------
say "Placing configs (replaced files are backed up to $BACKUP)"
C=$HOME/.config

# Ours: session environment, Hyprland entry point, separate dconf profile.
rm -f "$MANAGED.new"
for f in uwsm/env hypr/hyprland.lua dconf/hyprland.profile; do
  put "$REPO/config/$f" "$C/$f"
  manage "$C/$f"
done

# Lock screen: Omarchy's Quickshell lock reads this PAM stack and won't lock at all without it.
sudo install -m 0644 -o root -g root "$REPO/config/pam.d/omarchy-lock-password" /etc/pam.d/omarchy-lock-password
manage /etc/pam.d/omarchy-lock-password

# DNS presets (network panel, Setup > DNS). omarchy-dns re-runs itself as root from a root-owned path that the
# sudoers rule names; on Arch that's /usr/bin, here a copy outside PATH (the layer's omarchy-dns calls it).
DNS_HELPER=/usr/local/libexec/omarchy-dns
tmp=$(mktemp)
sed "s|^PACKAGED_PATH=.*|PACKAGED_PATH=$DNS_HELPER|" "$OMARCHY_PATH/bin/omarchy-dns" >"$tmp"
grep -qxF "PACKAGED_PATH=$DNS_HELPER" "$tmp" || die "Omarchy's omarchy-dns no longer sets PACKAGED_PATH; update install.sh."
sudo install -D -m 0755 -o root -g root "$tmp" "$DNS_HELPER"
manage "$DNS_HELPER"
# Omarchy's rule, for Ubuntu's admin group (sudo, not wheel): the stock presets switch without a password,
# Custom still asks.
sed -e "s|/usr/bin/omarchy-dns|$DNS_HELPER|g" -e 's|^%wheel |%sudo |' \
  "$OMARCHY_PATH/etc/sudoers.d/omarchy-dns" >"$tmp"
grep -q "^%sudo ALL=(root) NOPASSWD: $DNS_HELPER " "$tmp" || die "Omarchy's DNS sudoers rule changed; update install.sh."
sudo visudo -cqf "$tmp" || die "The DNS sudoers rule doesn't validate."
sudo install -m 0440 -o root -g root "$tmp" /etc/sudoers.d/omarchy-ubuntu-dns
manage /etc/sudoers.d/omarchy-ubuntu-dns
rm -f "$tmp"

# Lock before suspend (lid close). Omarchy's unit points at /usr/bin, where Arch packages the script.
tmp=$(mktemp)
sed 's|^ExecStart=.*|ExecStart=%h/.local/share/omarchy/bin/omarchy-system-sleep-monitor|' \
  "$OMARCHY_PATH/default/systemd/user/omarchy-sleep-lock.service" >"$tmp"
put "$tmp" "$C/systemd/user/omarchy-sleep-lock.service"
manage "$C/systemd/user/omarchy-sleep-lock.service"
rm -f "$tmp"
# Only starts in the Hyprland session: the unit requires OMARCHY_PATH, which GNOME doesn't set.
systemctl --user daemon-reload
systemctl --user enable --now omarchy-sleep-lock.service
manage "$C/systemd/user/graphical-session.target.wants/omarchy-sleep-lock.service"

# owe, Omarchy's wallpaper engine (video backgrounds, theme intros), from the Hyprland package. Its daemon
# draws the desktop background, so like sleep-lock it only starts where OMARCHY_PATH is set (not in GNOME).
tmp=$(mktemp)
sed 's|^\[Unit\]$|[Unit]\nConditionEnvironment=OMARCHY_PATH\nConditionEnvironment=WAYLAND_DISPLAY|' \
  /opt/hyprland/share/owe/owed.service >"$tmp"
grep -q '^ConditionEnvironment=OMARCHY_PATH$' "$tmp" || die "owed.service has no [Unit] section; update install.sh."
put "$tmp" "$C/systemd/user/owed.service"
manage "$C/systemd/user/owed.service"
rm -f "$tmp"
systemctl --user daemon-reload
systemctl --user enable --now owed.service
manage "$C/systemd/user/graphical-session.target.wants/owed.service"
# Tells owe to pick up a new theme's background (Omarchy runs `omarchy-hook-install theme-set` with it).
put /opt/hyprland/share/owe/10-owe-sync "$C/omarchy/hooks/theme-set.d/10-owe-sync"
manage "$C/omarchy/hooks/theme-set.d/10-owe-sync"

# Start the Hyprland session's settings from a copy of the GNOME ones (fonts, keyboard, app prefs).
if [[ ! -e $C/dconf/hyprland && -f $C/dconf/user ]]; then
  cp "$C/dconf/user" "$C/dconf/hyprland"
  record "$C/dconf/hyprland"
fi

# Omarchy's personal-override templates: only when you don't have your own yet.
for f in bindings looknfeel autostart; do
  put "$OMARCHY_PATH/config/hypr/$f.lua" "$C/hypr/$f.lua" --if-missing
done

# Keyboard layout. Omarchy reads it from ~/.config/omarchy/keyboard-layouts, which Setup > Typing > Keyboard
# Layouts writes (on Arch it falls back to /etc/vconsole.conf). Start it from Ubuntu's /etc/default/keyboard.
# shellcheck disable=SC1091
. /etc/default/keyboard 2>/dev/null || true
if [[ ! -e $C/omarchy/keyboard-layouts ]]; then
  mkdir -p "$C/omarchy"
  printf 'XKBLAYOUT=%s\nXKBVARIANT=%s\n' "${XKBLAYOUT:-us}" "${XKBVARIANT:-}" >"$C/omarchy/keyboard-layouts"
  record "$C/omarchy/keyboard-layouts"
fi

# Omarchy's own XKB option, omarchy:shift_caps_compose (Caps Lock stays Caps Lock, Shift + Caps Lock is
# Compose). Omarchy puts it in /etc/xkb; libxkbcommon also reads ~/.config/xkb. The rules file includes the
# system's rules and only adds that option, so every other keymap, GNOME's included, comes out the same.
# A file of your own there is left alone.
for f in rules/evdev symbols/omarchy; do
  if [[ -e $C/xkb/$f ]] && ! grep -qxF "$C/xkb/$f" "$MANIFEST" 2>/dev/null; then
    warn "Keeping your $C/xkb/$f. Omarchy's Shift + Caps Lock compose key needs $OMARCHY_PATH/etc/xkb/$f there."
    continue
  fi
  put "$OMARCHY_PATH/etc/xkb/$f" "$C/xkb/$f"
  manage "$C/xkb/$f"
done

# Personal input overrides: Omarchy's template, plus Ubuntu's own XKB options after Omarchy's.
tmp=$(mktemp)
cp "$OMARCHY_PATH/config/hypr/input.lua" "$tmp"
if [[ -n ${XKBOPTIONS:-} ]]; then
  cat >>"$tmp" <<EOF

-- Keyboard options from Ubuntu (/etc/default/keyboard), after Omarchy's own.
hl.config({ input = { kb_options = "omarchy:shift_caps_compose,$XKBOPTIONS" } })
EOF
fi
# Before Omarchy 4.5 this installer wrote the layout into input.lua, which would now override Setup > Typing >
# Keyboard Layouts. Replace that file if it's still exactly as it was written.
old=$(mktemp)
cat >"$old" <<EOF
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
if cmp -s "$old" "$C/hypr/input.lua"; then
  put "$tmp" "$C/hypr/input.lua"
else
  put "$tmp" "$C/hypr/input.lua" --if-missing
fi
rm -f "$tmp" "$old"

if [[ ! -e $C/hypr/monitors.lua ]]; then
  # Omarchy assumes HiDPI (scale 2). Use 1 when every connected screen is at most 1920px wide.
  max_width=0
  for status in /sys/class/drm/card*-*/status; do
    [[ $(<"$status") == connected ]] || continue
    w=$(head -1 "$(dirname "$status")/modes" 2>/dev/null | cut -dx -f1)
    [[ $w =~ ^[0-9]+$ ]] && ((w > max_width)) && max_width=$w
  done
  tmp=$(mktemp)
  sed -e 's/^local omarchy_gdk_scale = .*/local omarchy_gdk_scale = '"$( ((max_width > 1920)) && echo 2 || echo 1)"'/' \
      -e 's/^local omarchy_monitor_scale = .*/local omarchy_monitor_scale = '"$( ((max_width > 1920)) && echo '"auto"' || echo 1)"'/' \
      "$OMARCHY_PATH/config/hypr/monitors.lua" >"$tmp"
  put "$tmp" "$C/hypr/monitors.lua"
  rm -f "$tmp"
fi

# Omarchy app configs, only where you have none. (config/autostart is skipped on purpose: GNOME would run it too.)
while IFS= read -r -d '' src; do
  put "$src" "$C/${src#"$OMARCHY_PATH"/config/}" --if-missing
done < <(find "$OMARCHY_PATH/config/ghostty" "$OMARCHY_PATH/config/btop" "$OMARCHY_PATH/config/omarchy" \
  "$OMARCHY_PATH/config/imv" "$OMARCHY_PATH/config/lazygit" "$OMARCHY_PATH/config/herdr" -type f -print0)

# Screensaver and About text, as Omarchy's own installer seeds them.
put "$OMARCHY_PATH/logo.txt" "$C/omarchy/branding/screensaver.txt" --if-missing
put "$OMARCHY_PATH/icon.txt" "$C/omarchy/branding/about.txt" --if-missing

# Portal choice (screen sharing, file pickers, and since Omarchy 4.5 GNOME Keyring as the Secret portal) for the
# Hyprland session; only read when the desktop is Hyprland. Earlier installs copied Hyprland's own file, which
# lacks the Secret portal: replace it if it's unchanged.
portals=$C/xdg-desktop-portal/hyprland-portals.conf
if cmp -s /opt/hyprland/share/xdg-desktop-portal/hyprland-portals.conf "$portals"; then
  put "$OMARCHY_PATH/config/xdg-desktop-portal/hyprland-portals.conf" "$portals"
else
  put "$OMARCHY_PATH/config/xdg-desktop-portal/hyprland-portals.conf" "$portals" --if-missing
fi

# Default apps and terminal for the Hyprland session only (desktop-specific files GNOME ignores).
put "$OMARCHY_PATH/config/hyprland-mimeapps.list" "$C/hyprland-mimeapps.list" --if-missing
if [[ ! -e $C/hyprland-xdg-terminals.list ]]; then
  echo com.mitchellh.ghostty.desktop >"$C/hyprland-xdg-terminals.list"
  record "$C/hyprland-xdg-terminals.list"
fi

# ---- shell --------------------------------------------------------------------
# Omarchy's herdr layout commands (hdl, hds, hdlm, hsl) and `h`, for bash and zsh. The line only sources them
# when OMARCHY_PATH is set, i.e. in the Hyprland session; GNOME terminals skip it. Not backed up on purpose:
# uninstall.sh removes just this line, so later edits to your rc files survive.
RC_LINE='if [ -n "$OMARCHY_PATH" ] && [ -f ~/.local/share/omarchy-ubuntu/shell/herdr.sh ]; then . ~/.local/share/omarchy-ubuntu/shell/herdr.sh; fi # omarchy-ubuntu'
for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
  [[ -f $rc ]] || continue
  if ! grep -qF '# omarchy-ubuntu' "$rc"; then
    printf '\n%s\n' "$RC_LINE" >>"$rc"
  elif ! grep -qxF "$RC_LINE" "$rc"; then
    # An older version of the line: replace it in place. Written back with cat so a symlinked rc file
    # (dotfile managers) keeps its link and permissions.
    tmp=$(mktemp)
    awk -v line="$RC_LINE" '/# omarchy-ubuntu$/ { print line; next } { print }' "$rc" >"$tmp"
    cat "$tmp" >"$rc"
    rm -f "$tmp"
  fi
done

# The herdr binary is downloaded only when missing, so a run that doesn't download it still manages it if
# an earlier run did (the manifest says so): switching back from this branch then removes it.
if grep -qxF "$HERDR_BIN" "$MANIFEST" 2>/dev/null && [[ -e $HERDR_BIN ]]; then
  manage "$HERDR_BIN"
fi

# ---- fonts --------------------------------------------------------------------
FONTS=$HOME/.local/share/fonts
if [[ -z $(fc-list "JetBrainsMono Nerd Font" family) ]]; then
  say "Installing JetBrainsMono Nerd Font $NERD_FONTS_VERSION"
  mkdir -p "$FONTS/JetBrainsMonoNerd"
  curl -fsSL "https://github.com/ryanoasis/nerd-fonts/releases/download/$NERD_FONTS_VERSION/JetBrainsMono.tar.xz" \
    | tar -xJ -C "$FONTS/JetBrainsMonoNerd" --wildcards '*.ttf'
  record "$FONTS/JetBrainsMonoNerd"
fi
mkdir -p "$FONTS/omarchy"
cp "$OMARCHY_PATH/default/fonts/omarchy/omarchy.ttf" "$FONTS/omarchy/"
record "$FONTS/omarchy"
fc-cache -f >/dev/null

# ---- theme --------------------------------------------------------------------
# Runs with the Hyprland session's PATH and dconf profile, so GNOME settings are untouched.
if [[ ! -s $HOME/.local/state/omarchy/current/theme.name ]]; then
  say "Setting the Tokyo Night theme"
  mkdir -p "$C/omarchy/themes"
  env OMARCHY_PATH="$OMARCHY_PATH" \
      PATH="$LAYER/bin:$OMARCHY_PATH/bin:/opt/hyprland/bin:$PATH" \
      DCONF_PROFILE="$C/dconf/hyprland.profile" \
      OMARCHY_THEME_HEADLESS=1 \
      omarchy-theme-set "Tokyo Night" || warn "Theme setup failed; pick one later from the Omarchy menu."
fi
record "$HOME/.local/state/omarchy"

mkdir -p "$C/btop/themes"
ln -snf "$HOME/.local/state/omarchy/current/theme/btop.theme" "$C/btop/themes/current.theme"
record "$C/btop/themes/current.theme"

prune
mv "$MANAGED.new" "$MANAGED"
# For omarchy-channel-set: where this checkout lives and which branch it installed.
echo "$REPO" >"$STATE/repo"
echo "${OMARCHY_UBUNTU_CHANNEL:-$(git -C "$REPO" branch --show-current 2>/dev/null || true)}" >"$STATE/channel"
git -C "$REPO" rev-parse HEAD >"$STATE/commit" 2>/dev/null || true

cat <<EOF

$(say "Done.")
Log out, click your name on the login screen, use the gear icon to pick
"Hyprland (Omarchy)", then log in. Pick "Ubuntu" the same way to go back to GNOME.

Press Super+K in Hyprland for the keybindings, Super+Space for the Omarchy menu.
Super+Ctrl+Return opens herdr (prefix Ctrl+Space), Super+Ctrl+K lists its keys.
Undo everything with: $REPO/uninstall.sh
EOF
