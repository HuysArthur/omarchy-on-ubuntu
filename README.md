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

## Logging in automatically

Omarchy on Arch logs you in without asking for a password. It relies on disk encryption instead: the one
password you type is the disk's, at boot. You can do the same here with timed login:

```bash
~/.local/share/omarchy-ubuntu/bin/omarchy-ubuntu-timed-login on
```

(In the Omarchy session, `omarchy-ubuntu-timed-login on` is enough.) From the next boot, the login screen counts
down 10 seconds (`on 30` for longer) and then logs you into Omarchy. Before that, you can still pick Ubuntu with
the gear icon, and logging out brings the normal login screen back. Remote access needs this: Gliff shows a
running Omarchy session, it doesn't start one. `omarchy-ubuntu-timed-login off` turns it off, and `status`
shows what's set.

- **Encrypt your disk.** Without encryption, anyone who switches the computer on gets your desktop, so the Omarchy
  session locks the screen right after a timed login and you unlock it with your password (over Gliff too).
  Ubuntu's installer sets up encryption ("Use LVM and encryption", or hardware-backed encryption); it can't be
  added to an existing install.
- A disk that unlocks itself at boot (hardware-backed encryption without a PIN or passphrase) counts as
  encrypted, but it doesn't keep out someone who switches the computer on. Add a PIN.
- With a disk password, a computer that restarts waits for it before its network is up, so you can't reach it
  remotely until someone types it.
- The login screen remembers the session you pick: after you choose Ubuntu, the countdown logs into GNOME until
  you choose Hyprland (Omarchy) again.

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
- The coding-agent commands (`claude`, `codex`, `opencode`, ...) come from mise and only exist in the Omarchy
  session; in GNOME, `claude` and the others stay whatever you installed yourself. One you install yourself in
  `~/.local/bin` is used in the Omarchy session too.
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
localsend, Obsidian). Their menu entries work once you install them yourself. Screen recording uses
wf-recorder instead of gpu-screen-recorder: it encodes on the CPU, and portal capture and `--resolution`
need gpu-screen-recorder.

## Changing it with an agent

Omarchy's agent skills are set up for agents that read `~/.agents/skills`, and for Claude Code, Codex, Pi
and Gemini if you have them (re-run `install.sh` after installing one),
together with an `omarchy-ubuntu` skill that tells them how this setup differs from Arch Omarchy. Ask your
agent to change the bar, keybindings, window rules or theme. If it makes a mess, `omarchy reinstall configs`
puts Omarchy's defaults back for the Omarchy session (your versions are backed up under
`~/.local/state/omarchy-ubuntu/`; it prints where). Apps GNOME shares, like Ghostty and btop, keep their configs.

## Contributing

How it works, building the Hyprland package, releases and testing pull requests:
see [docs/development.md](docs/development.md).

## License

MIT (see `LICENSE`). The Hyprland package bundles Hyprland and its libraries (BSD-3-Clause),
Quickshell (LGPL-3.0) and Omarchy's ttfx, omasnap, owe and titlebars plugin (MIT), built unmodified from the sources pinned in `build/versions.env`.
Omarchy (MIT) is downloaded by `install.sh`, not included here.
