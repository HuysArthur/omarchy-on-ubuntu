# Omarchy on Ubuntu

**Run [Omarchy](https://omarchy.org) on Ubuntu 26.04, next to GNOME. No reinstall, no dual boot, no Arch.**

This adds a second login session that runs the real Omarchy desktop (Hyprland with its keybindings,
themes, bar, menus and lock screen), unmodified. Pick it on the login screen when you want Omarchy;
pick "Ubuntu" when you want GNOME back. Hyprland comes prebuilt, so there's nothing to compile.

> Unofficial: not affiliated with Basecamp or the Omarchy project.

## Install

```bash
git clone https://github.com/HuysArthur/omarchy-on-ubuntu && cd omarchy-on-ubuntu
./install.sh
```

Log out, click the gear icon on the login screen and choose **Hyprland (Omarchy)**.

- **Super + Space** opens the menu
- **Super + K** shows every keybinding
- **Super + Ctrl + Return** opens [herdr](https://herdr.dev), Omarchy's terminal workspace manager
  (prefix Ctrl+Space, **Super + Ctrl + K** lists its keys)
- **Super + Shift + Ctrl + A** opens your coding agent. Pick one under **Setup > Defaults > Agent**: Claude
  Code, Codex, OpenCode, Gemini, Copilot and the rest are ready to go and download the first time you use them

Omarchy's own apps come with it, as on Arch: Omacalc, Omawrite, Omacut, Hype, Monologue, Signed, Aether,
cliamp, Disktree and Gliff. They only appear in the Omarchy session. **Remove > Preinstalls** hides the
preinstalled ones and turns off their shortcuts; **Install > Preinstalls** brings them back.

## Update

Use **Update > Omarchy** in the menu, or run `omarchy-update`. It upgrades your apt packages and everything mise installed
(the coding agents, plus any tools of your own in mise's global config), and brings Omarchy on Ubuntu up to date.

## Uninstall

```bash
./uninstall.sh
```

Everything the installer placed is removed or moved to `~/omarchy-ubuntu-removed-<date>/`, and anything it
replaced is restored.

## Your GNOME is safe

- Omarchy runs in a separate session with its own settings, so Omarchy's themes, fonts and dark mode never
  leak into GNOME.
- Your existing config files are kept; anything the installer has to replace is backed up first.
- Hyprland is installed in `/opt/hyprland`, away from Ubuntu's own packages.
- The installer adds one line to `~/.bashrc` and `~/.zshrc` for Omarchy's herdr commands and agent shortcuts;
  it only does something in the Omarchy session, and uninstalling removes it.
- The coding-agent commands (`claude`, `codex`, `opencode`, ...) go in `~/.local/bin`, which GNOME also has on
  its PATH, so they work there too. Any you already have are left alone.
- For agents you've used, the installer adds herdr's hooks to their config (`~/.claude/settings.json` and the
  like). GNOME shares those files, but the hooks only act inside herdr. It isn't backed up; uninstalling removes
  the hooks, and if you remove one yourself (`herdr integration uninstall <agent>`), it stays removed.
- DNS is shared too. A preset you pick in Omarchy (network panel or Setup > DNS) is system-wide, so
  GNOME uses it too. It also replaces the DNS servers set on your Wi-Fi and Ethernet connections and rewrites
  `/etc/systemd/resolved.conf`; uninstalling doesn't undo that. Nothing changes until you pick a preset.

## What doesn't work

Some Omarchy features depend on Arch Linux: pacman/AUR updates (apt is used instead),
bootloader/plymouth/hibernation setup, kernel switching, snapper snapshots and factory reset. Their menu
entries are hidden: Install > AUR, Install > Editor > Emacs, Install > AI > Hermes Desktop, OpenClaw, Claude
Desktop and Amp Desktop (Hermes and OpenClaw under Setup > Default agent too), Install > Service > Notion and
Slack, Setup > Defaults > Dictation > Voxtype, Setup > Language, Setup > Typing > Input Methods, Appearance > Unlock,
Update > Kernel and Update > Config > Plymouth.

Install > Browser gets Chrome and Edge from their vendors' `.deb`, Brave from Brave's apt repository and Zen
from Flathub, so they stay up to date with the rest of your system. Superwhisper, Omarchy's dictation
(Setup > Defaults > Dictation), is downloaded from superwhisper.com when you pick it.

A few apps Omarchy expects aren't in Ubuntu's archive (hyprsunset, gpu-screen-recorder, tensaku,
localsend, Obsidian). Their menu entries work once you install them yourself.

## Contributing

How it works, building the Hyprland package, releases and testing pull requests:
see [docs/development.md](docs/development.md).

## License

MIT (see `LICENSE`). The Hyprland package bundles Hyprland and its libraries (BSD-3-Clause),
Quickshell (LGPL-3.0) and Omarchy's ttfx, omasnap, owe and titlebars plugin (MIT), built unmodified from the sources pinned in `build/versions.env`.
Omarchy (MIT) is downloaded by `install.sh`, not included here.
