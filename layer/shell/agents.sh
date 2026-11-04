# Omarchy's coding-agent shortcuts, for bash and zsh: a (the default agent, inline), c (OpenCode),
# cx (Claude Code), cy (Codex) and mup (update everything mise installed). Taken from Omarchy's aliases file so
# they follow the pinned release; the rest of that file (ls -> eza and so on) is not loaded. A name you already
# use (an alias, a function or a command) stays yours.
[ -n "$OMARCHY_PATH" ] && [ -r "$OMARCHY_PATH/default/bash/aliases" ] || return 0

for omarchy_ubuntu_alias in a c cx cy mup; do
  type "$omarchy_ubuntu_alias" >/dev/null 2>&1 && continue
  eval "$(grep -E "^alias $omarchy_ubuntu_alias=" "$OMARCHY_PATH/default/bash/aliases")"
done
unset omarchy_ubuntu_alias
