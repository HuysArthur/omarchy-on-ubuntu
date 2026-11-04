# Omarchy's coding-agent shortcuts, for bash and zsh: a (the default agent, inline), c (OpenCode),
# cx (Claude Code), cy (Codex) and mup (update everything mise installed). Taken from Omarchy's aliases file so
# they follow the pinned release; the rest of that file (ls -> eza and so on) is not loaded.
[ -n "$OMARCHY_PATH" ] && [ -r "$OMARCHY_PATH/default/bash/aliases" ] || return 0

eval "$(grep -E '^alias (a|c|cx|cy|mup)=' "$OMARCHY_PATH/default/bash/aliases")"
