---
name: omarchy-ubuntu
description: >
  REQUIRED on this machine together with the omarchy skill: Omarchy here runs on Ubuntu, as a second login
  session next to GNOME (omarchy-on-ubuntu), not on Arch. Use whenever the omarchy or diagnose-crash skill
  applies, and for any task touching Hyprland, ~/.config/hypr/, ~/.config/omarchy/, omarchy commands,
  installing or removing packages, system settings, shell startup files, or crash reports.
  Where this skill and the omarchy skill disagree, this one is right for this machine.
---

# Omarchy on Ubuntu

This machine runs Ubuntu 26.04 with the real Omarchy desktop (Hyprland, the Omarchy shell, menus, themes) installed as an extra login session by [omarchy-on-ubuntu](https://github.com/HuysArthur/omarchy-on-ubuntu). GNOME is still installed and the user switches between the two on the login screen. Everything in the omarchy skill about Hyprland, the bar, plugins, themes, hooks and `omarchy` commands still applies; this skill corrects what is different.

## Which session you are in

- Omarchy session: `$OMARCHY_PATH` and `$HYPRLAND_INSTANCE_SIGNATURE` are set. Omarchy commands, `hyprctl` and `omarchy-shell` work.
- GNOME session: neither is set (`$XDG_CURRENT_DESKTOP` is `ubuntu:GNOME`). Omarchy commands are not on PATH and there is no Hyprland to talk to. You can still edit Omarchy's config files; they take effect the next time the user logs into the Omarchy session. Say so instead of trying to apply them live.

## Where things live

| Omarchy skill says | On this machine |
|---|---|
| `/usr/share/omarchy/` (read-only package) | `$OMARCHY_PATH` = `~/.local/share/omarchy`, a git checkout of a pinned Omarchy release (`git -C "$OMARCHY_PATH" describe --tags`) with a few patches applied. Still read-only: `install.sh` resets it with `git checkout -f` on every run. |
| Omarchy commands in `/usr/bin` | `$OMARCHY_PATH/bin`, behind `~/.local/share/omarchy-ubuntu/bin` (the Ubuntu layer), which comes first on PATH and replaces some Omarchy commands with Ubuntu versions or stubs. The layer is also replaced on every install: never edit it. |
| Hyprland from pacman | `/opt/hyprland` (the `hyprland-opt` package, with Quickshell). Never install Ubuntu's `hyprland` or `quickshell` packages. |

Read the source of any command with `cat "$(command -v omarchy-<name>)"`; that shows the layer's version when there is one.

## Config files

- `~/.config/hypr/hyprland.lua` and `~/.config/uwsm/env` belong to omarchy-on-ubuntu: they load the Ubuntu layer. `install.sh` replaces them on every run, so never put changes there. The omarchy skill suggests `hyprland.lua` for window rules; here, put them in `~/.config/hypr/looknfeel.lua` (or a file you `require` from it). Keybindings go in `bindings.lua`, as usual.
- Session environment variables go in `~/.config/uwsm/default`, which the session loads after `uwsm/env`.
- Everything else in `~/.config/hypr/` and `~/.config/omarchy/` works as the omarchy skill describes.
- `omarchy refresh config <path>` and **Update > Config** restore Omarchy's defaults as usual; for `hypr/hyprland.lua`, `hypr/input.lua`, `hypr/monitors.lua` and `uwsm/env` they restore omarchy-on-ubuntu's versions instead.

## What GNOME shares

The Omarchy session keeps its own GNOME-settings database (`DCONF_PROFILE` points at `~/.config/dconf/hyprland`), its own `~/.config/hyprland-mimeapps.list`, and everything under `~/.config/hypr/`, `~/.config/omarchy/` and `~/.config/uwsm/`. Changes there never reach GNOME.

Everything else is shared with GNOME. Before changing any of it, tell the user it affects GNOME too and ask:

- anything under `/etc` (PAM, sudoers, systemd units, NetworkManager, DNS, apt sources), system services, the kernel command line, GRUB, the initramfs and Plymouth;
- installed packages: installing or removing one does it for both sessions;
- shell startup files (`~/.bashrc`, `~/.zshrc`, `~/.profile`), `~/.config/environment.d/`, `~/.config/autostart/` and `~/.local/bin`;
- app settings such as VS Code, Claude Code, browsers and Obsidian. For that reason Omarchy's theme sync to them is switched off here (`omarchy-theme-set-vscode`, `-claude`, `-pi`, `-hermes`, `-obsidian`, `-t3code` and `-browser-policy` do nothing). Don't turn it back on.

Omarchy's own bash configuration (`$OMARCHY_PATH/default/bash/rc`) is not loaded. The only addition is one line in `~/.bashrc`/`~/.zshrc` marked `# omarchy-ubuntu`, which loads a few Omarchy shell commands in the Omarchy session only. Leave that line as it is, and don't source Omarchy's bash files from the rc files: GNOME terminals would get them too.

`gsettings` and `dconf` write to whichever session's database is active: the Omarchy one inside the Omarchy session, GNOME's from GNOME.

## Packages

Ubuntu uses apt. There is no pacman, AUR, yay or paru here.

- `omarchy pkg add <names>` installs with `apt-get install` (it asks for the sudo password). Omarchy names packages the Arch way; many match Ubuntu's, but when apt says a package doesn't exist, find the Ubuntu name (`apt-cache search <words>`, `apt-cache policy <name>`) and install that.
- `pacman` is a read-only stand-in that answers `-Q` queries from dpkg so Omarchy's "is it installed?" checks work. Anything else is refused. Never try to make it install.
- `omarchy pkg aur add` is not available. For software that isn't in Ubuntu's archive, prefer the vendor's apt repository or `.deb`, then Flathub. Ask before adding an apt repository: it is system-wide.
- To remove packages, use `omarchy pkg drop <names>`: it refuses to remove more than the packages named. (`omarchy pkg remove` is an interactive picker for the user.) Don't work around the refusal with `apt-get remove -y` or `apt autoremove`: GNOME may need what they would take.
- `omarchy update` (**Update > Omarchy**) upgrades apt and Flatpak packages and updates omarchy-on-ubuntu on its channel. Omarchy itself stays at the pinned release: never `git pull` or check out another version in `$OMARCHY_PATH`. A newer Omarchy comes with a new omarchy-on-ubuntu release.

## Not available on Ubuntu

These are Arch-only and print "not available on Ubuntu": the Limine bootloader, Plymouth themes (**Style > Unlock**), hibernation setup, snapper snapshots (`omarchy snapshot`), factory reset, AUR installs, pacman/AUR updates, keyring updates, `omarchy reinstall pkgs`, and the Arch upgrade path (`omarchy-upgrade-to-quattro`). Most of their menu entries are hidden; any that still show only print that message. Don't work around them: Ubuntu's equivalents (GRUB, `update-initramfs`, Plymouth) change how the whole machine boots, GNOME included. If the user asks for one, explain that and let them decide.

## Undoing changes

Use the smallest reset that undoes the change:

- `omarchy refresh config <path>` resets a single file, keeping a `.bak.<time>` copy next to it.
- `omarchy refresh hyprland` resets Omarchy's files in `~/.config/hypr/` the same way.
- **Ask the user before running `omarchy reinstall configs`**, even to undo your own changes. It puts the default back for the config files omarchy-on-ubuntu seeds for the Omarchy session (`~/.config/hypr/`, `~/.config/omarchy/`, `~/.config/uwsm/env` and the like), after backing the current ones up to `~/.local/state/omarchy-ubuntu/reset-backup/<date-time>/`. It needs no sudo or network. Apps GNOME shares (ghostty, btop, lazygit, imv, herdr) keep their configs; reset one of those with `omarchy refresh config <path>`, after telling the user it affects GNOME too. Use it instead of `omarchy reinstall`, whose first step (reinstalling packages with pacman) isn't available here.
- Every file the installer has replaced is also in `~/.local/state/omarchy-ubuntu/backup/`.
- The omarchy-on-ubuntu checkout the installer runs from is named in `~/.local/state/omarchy-ubuntu/repo`.

## Crashes

The crash watcher isn't set up on Ubuntu yet, so there are no "Process crashed" notifications. When the diagnose-crash skill is used anyway:

- Ubuntu records crashes with apport (`/var/crash/*.crash`). `coredumpctl` only works if the user installed `systemd-coredump`.
- For symbols, use Ubuntu's debuginfod server, `https://debuginfod.ubuntu.com`, not Arch's.
- A crash in Hyprland or Quickshell may come from the Ubuntu build, which runs on Ubuntu's libraries and Qt.

## Reporting bugs

Problems that come from running on Ubuntu (missing packages, paths, apt, GNOME interaction, the `hyprland-opt` build) belong at https://github.com/HuysArthur/omarchy-on-ubuntu/issues, not at basecamp/omarchy. Report upstream only when the problem is in Omarchy's own code and not caused by Ubuntu, and even then say in the report that it was seen on Omarchy on Ubuntu. When unsure, start with omarchy-on-ubuntu. As the omarchy skill says, ask before filing anything.

## Privileges

The omarchy skill's sudo and `pkexec` rules apply. Ubuntu's admin group is `sudo`, not `wheel`.
