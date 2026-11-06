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

-- Omarchy's shell only honours Wayland idle inhibitors; browsers ask over DBus (org.freedesktop.ScreenSaver),
-- which nothing else in the session answers. Without this, the screensaver starts during video calls.
-- uwsm-app sends output to /dev/null; systemd-cat keeps the bridge's inhibit/release lines in the journal.
o.launch_on_start("systemd-cat -t omarchy-idle-inhibit-bridge omarchy-idle-inhibit-bridge")

-- Omarchy's config migrations (the ones reviewed for Ubuntu, see layer/migrations.list). Some ask the shell
-- over IPC, so they run here (omarchy-migrate waits for the shell) rather than from install.sh, which usually
-- runs in GNOME. Upstream's omarchy-migrate-notify.service only offers to run them; these just edit user
-- config, so run them quietly.
o.launch_on_start("systemd-cat -t omarchy-migrate omarchy-migrate")

