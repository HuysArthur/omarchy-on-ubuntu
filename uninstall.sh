#!/usr/bin/env bash
# Removes the Hyprland (Omarchy) session and everything install.sh placed. GNOME is not touched.
# Files install.sh put in ~/.config are moved aside (not deleted), and backups of what they replaced are restored.
set -euo pipefail

STATE=$HOME/.local/state/omarchy-ubuntu
MANIFEST=$STATE/manifest
ASIDE=$HOME/omarchy-ubuntu-removed-$(date +%Y%m%d-%H%M%S)

say() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }

if dpkg-query -W -f='${db:Status-Abbrev}' hyprland-opt 2>/dev/null | grep -q '^ii'; then
  say "Removing the hyprland-opt package (sudo)"
  sudo apt-get remove -y hyprland-opt
fi

if [[ -f $STATE/managed ]]; then
  while IFS= read -r path; do
    [[ -e $path || -L $path ]] || continue
    if [[ $path == */systemd/user/* && ! -L $path ]]; then
      systemctl --user disable --now "$(basename "$path")" 2>/dev/null || true
    fi
    # Files in $HOME are moved aside with the rest of the manifest below.
    [[ $path == "$HOME"/* ]] && continue
    say "Removing $path (sudo)"
    sudo rm -f "$path"
  done <"$STATE/managed"
fi

if [[ -f $MANIFEST ]]; then
  say "Moving installed files to $ASIDE"
  while IFS= read -r path; do
    [[ $path == "$HOME"/* && ( -e $path || -L $path ) ]] || continue
    rel=${path#"$HOME"/}
    mkdir -p "$ASIDE/$(dirname "$rel")"
    mv "$path" "$ASIDE/$rel"
  done <"$MANIFEST"

  # Restore the oldest backup of each file, i.e. what was there before the first install.
  if [[ -d $STATE/backup ]]; then
    say "Restoring files that install.sh had replaced"
    for dir in $(ls -1d "$STATE"/backup/*/ | sort -r); do
      (cd "$dir" && find . -type f -o -type l) | while IFS= read -r f; do
        mkdir -p "$HOME/$(dirname "${f#./}")"
        cp -a "$dir/$f" "$HOME/${f#./}"
      done
    done
  fi
fi

say "Removing Omarchy checkout and Ubuntu layer"
rm -rf "$HOME/.local/share/omarchy" "$HOME/.local/share/omarchy-ubuntu" "$STATE"
fc-cache -f >/dev/null 2>&1 || true

cat <<EOF

Done. Pick "Ubuntu" on the login screen if it isn't selected already.
Desktop packages installed from apt (ghostty, gum, grim, ...) were left in place;
remove them with apt if you don't want them.
EOF
[[ -d $ASIDE ]] && echo "Moved-aside files are in $ASIDE (delete when you're sure)."
