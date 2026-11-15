# Omarchy's coding-agent shortcuts, for bash and zsh: a (the default agent, inline), c (OpenCode),
# cx (Claude Code), cy (Codex) and mup (update everything mise installed). Taken from Omarchy's aliases file so
# they follow the pinned release; the rest of that file (ls -> eza and so on) is not loaded. A name you already
# use (an alias, a function or a command) stays yours.
[ -n "$OMARCHY_PATH" ] && [ -r "$OMARCHY_PATH/default/bash/aliases" ] || return 0

while IFS= read -r omarchy_ubuntu_alias; do
  omarchy_ubuntu_name=${omarchy_ubuntu_alias#alias }
  type "${omarchy_ubuntu_name%%=*}" >/dev/null 2>&1 || eval "$omarchy_ubuntu_alias"
done <<EOF
$(grep -E '^alias (a|c|cx|cy|mup)=' "$OMARCHY_PATH/default/bash/aliases")
EOF
unset omarchy_ubuntu_alias omarchy_ubuntu_name
