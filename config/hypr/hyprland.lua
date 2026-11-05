-- Learn how to configure Hyprland: https://wiki.hypr.land/Configuring/Start/
-- Omarchy on Ubuntu: Omarchy's defaults come from $OMARCHY_PATH (a pinned checkout),
-- Ubuntu fixups from ~/.local/share/omarchy-ubuntu.

dofile((os.getenv("OMARCHY_PATH") or (os.getenv("HOME") .. "/.local/share/omarchy")) .. "/default/hypr/bootstrap.lua")

-- Disable all Omarchy default bindings. Add your own in hypr/bindings.lua.
-- omarchy_default_bindings = false
--
-- Or disable only bindings for Omarchy's preinstalled apps/web apps while
-- keeping core window-manager bindings (Remove > Preinstalls does this too):
-- omarchy_preinstalled_bindings = false

require("default.hypr.omarchy")
dofile(os.getenv("HOME") .. "/.local/share/omarchy-ubuntu/lua/hypr.lua")

-- Personal overrides, loaded after Omarchy's defaults.
require("hypr.monitors")
require("hypr.input")
require("hypr.bindings")
require("hypr.looknfeel")
require("hypr.autostart")

-- Toggle config flags dynamically.
require("default.hypr.toggles")

-- Add any other personal Hyprland configuration below.
