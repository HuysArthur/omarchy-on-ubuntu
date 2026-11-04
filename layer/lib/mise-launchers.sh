#!/bin/bash
# Creates Omarchy's coding-agent launchers (claude, codex, opencode, ...): runs Omarchy's own list,
# install/user/mise.sh, so it follows the pinned release. Each launcher is a small script in ~/.local/bin that
# installs its tool with mise on first use. A command you already have from somewhere else (apt, npm, a vendor
# installer such as Claude Code's) is left alone. Prints the path of each launcher it wrote, for install.sh to
# manage. Needs OMARCHY_PATH, Omarchy's bin/ on PATH and mise.
set -uo pipefail

list=$OMARCHY_PATH/install/user/mise.sh
if [[ ! -f $list ]]; then
  echo "Omarchy's agent list ($list) is missing; no agent launchers installed." >&2
  exit 1
fi

# Omarchy's launchers are the only files there that start a line with this.
omarchy_launcher() { [[ -f $1 && ! -L $1 ]] && grep -q '^mise use -g' "$1"; }

# Called by install/user/mise.sh for each tool, with Omarchy's arguments: <package> [command-name [bin-name]].
omarchy-mise-install() {
  local name=${2:-$1}
  local launcher=$HOME/.local/bin/$name found
  # Something of yours at that path (a binary, or a link like the one Claude Code's installer makes).
  if [[ -e $launcher || -L $launcher ]] && ! omarchy_launcher "$launcher"; then
    return 0
  fi
  # The same command elsewhere on PATH: yours wins, so don't add a second one.
  while IFS= read -r found; do
    [[ $found == "$launcher" ]] || return 0
  done < <(type -aP "$name")
  "$OMARCHY_PATH/bin/omarchy-mise-install" "$@" && echo "$launcher"
}

# shellcheck source=/dev/null
source "$list"
