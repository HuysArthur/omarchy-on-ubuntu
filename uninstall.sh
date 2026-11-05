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
    # Folders made just for a skill link (agents you don't have) go with it.
    [[ $path != */skills/* ]] || (cd "$HOME" && rmdir -p --ignore-fail-on-non-empty "$(dirname "$rel")")
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

# The herdr line install.sh added to the rc files, with the blank line it put before it. Written back with
# cat so a symlinked rc file keeps its link and permissions.
for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
  [[ -f $rc ]] && grep -qF '# omarchy-ubuntu' "$rc" || continue
  tmp=$(mktemp)
  awk '/# omarchy-ubuntu$/ { pending = 0; next }
    { if (pending) print ""; if ($0 == "") pending = 1; else { pending = 0; print } }
    END { if (pending) print "" }' "$rc" >"$tmp"
  cat "$tmp" >"$rc"
  rm -f "$tmp"
done

# Your versions from omarchy-reinstall-configs: not what was there before the install, so kept with the rest.
if [[ -d $STATE/reset-backup ]]; then
  mkdir -p "$ASIDE"
  mv "$STATE/reset-backup" "$ASIDE/"
fi

# Launchers Remove > Preinstalls wrote to hide Omarchy's apps (layer/bin/omarchy-remove-preinstalls).
for f in "$HOME"/.local/share/applications/*.desktop; do
  [[ -f $f && $(head -1 "$f") == '# omarchy-ubuntu: preinstall removed (Remove > Preinstalls)' ]] && rm -f "$f"
done

say "Removing Omarchy checkout and Ubuntu layer"
rm -rf "$HOME/.local/share/omarchy" "$HOME/.local/share/omarchy-ubuntu" "$STATE"
fc-cache -f >/dev/null 2>&1 || true

cat <<EOF

Done. Pick "Ubuntu" on the login screen if it isn't selected already.
Desktop packages installed from apt (ghostty, gum, grim, ...) were left in place;
remove them with apt if you don't want them.
EOF
[[ -d $ASIDE ]] && echo "Moved-aside files are in $ASIDE (delete when you're sure)."
