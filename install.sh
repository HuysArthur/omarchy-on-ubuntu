#!/usr/bin/env bash
# Installs Hyprland + the Omarchy desktop on Ubuntu 26.04 as an extra login session next to GNOME.
# Safe to re-run: it updates in place and backs up any file it replaces.
set -euo pipefail

REPO=$(cd "$(dirname "$0")" && pwd)
OMARCHY_REPO=https://github.com/basecamp/omarchy
OMARCHY_REF=v4.0.6
NERD_FONTS_VERSION=v3.4.0

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

# Start the Hyprland session's settings from a copy of the GNOME ones (fonts, keyboard, app prefs).
if [[ ! -e $C/dconf/hyprland && -f $C/dconf/user ]]; then
  cp "$C/dconf/user" "$C/dconf/hyprland"
  record "$C/dconf/hyprland"
fi

# Omarchy's personal-override templates: only when you don't have your own yet.
for f in bindings looknfeel autostart; do
  put "$OMARCHY_PATH/config/hypr/$f.lua" "$C/hypr/$f.lua" --if-missing
done

if [[ ! -e $C/hypr/input.lua ]]; then
  # shellcheck disable=SC1091
  . /etc/default/keyboard 2>/dev/null || true
  tmp=$(mktemp)
  cat >"$tmp" <<EOF
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
  put "$tmp" "$C/hypr/input.lua"
  rm -f "$tmp"
fi

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
  "$OMARCHY_PATH/config/imv" "$OMARCHY_PATH/config/lazygit" -type f -print0)

# Screensaver and About text, as Omarchy's own installer seeds them.
put "$OMARCHY_PATH/logo.txt" "$C/omarchy/branding/screensaver.txt" --if-missing
put "$OMARCHY_PATH/icon.txt" "$C/omarchy/branding/about.txt" --if-missing

# Portal choice (screen sharing, file pickers) for the Hyprland session; only read when the desktop is Hyprland.
put /opt/hyprland/share/xdg-desktop-portal/hyprland-portals.conf "$C/xdg-desktop-portal/hyprland-portals.conf" --if-missing

# Default apps and terminal for the Hyprland session only (desktop-specific files GNOME ignores).
put "$OMARCHY_PATH/config/hyprland-mimeapps.list" "$C/hyprland-mimeapps.list" --if-missing
if [[ ! -e $C/hyprland-xdg-terminals.list ]]; then
  echo com.mitchellh.ghostty.desktop >"$C/hyprland-xdg-terminals.list"
  record "$C/hyprland-xdg-terminals.list"
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
Undo everything with: $REPO/uninstall.sh
EOF
