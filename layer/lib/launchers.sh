# Sourced by install.sh, uninstall.sh and lib/mise-launchers.sh.

# omarchy_launcher PATH: true if PATH is one of Omarchy's mise launchers (written by omarchy-mise-install), not
# something of yours: an agent's own installer (Claude Code's, Cursor's) writes a binary or a link to the same
# path, and from then on it's yours.
omarchy_launcher() { [[ -f $1 && ! -L $1 ]] && grep -q '^mise use -g' "$1"; }
