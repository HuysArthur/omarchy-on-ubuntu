-- Ubuntu fixups, loaded right after Omarchy's defaults.

-- envs.lua moves Omarchy's bin/ to the front of PATH. Put the Ubuntu overrides
-- (pacman stand-in, apt-based update, Arch-only stubs) back in front of it.
local home = os.getenv("HOME")
local ubuntu_bin = home .. "/.local/share/omarchy-ubuntu/bin"
local omarchy_bin = require("default.hypr.paths").omarchy_path .. "/bin"

local path = { ubuntu_bin, omarchy_bin, "/opt/hyprland/bin" }
for entry in (os.getenv("PATH") or "/usr/local/bin:/usr/bin:/bin"):gmatch("[^:]+") do
  if entry ~= ubuntu_bin and entry ~= omarchy_bin and entry ~= "/opt/hyprland/bin" then
    table.insert(path, entry)
  end
end
hl.env("PATH", table.concat(path, ":"))
