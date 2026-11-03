# Annex

**Omarchy's Hyprland desktop, built onto Ubuntu. GNOME stays exactly where it was.**

Annex adds a second login session to Ubuntu 26.04 that runs [Omarchy](https://omarchy.org) — its
keybindings, themes, bar, menus and lock screen — unmodified. Pick it on the login screen when you want
a tiling desktop; pick "Ubuntu" when you want GNOME back. No reinstall, no dual boot, no Arch.

> Unofficial: not affiliated with Basecamp or the Omarchy project.

## Install

```bash
git clone https://github.com/HuysArthur/omarchy-on-ubuntu && cd omarchy-on-ubuntu
./install.sh
```

Log out, click the gear icon on the login screen and choose **Hyprland (Omarchy)**.

- **Super + Space** opens the menu
- **Super + K** shows every keybinding

## Update

Use **Update > Omarchy** in the menu, or run `omarchy-update`. It upgrades your apt packages and brings
Annex up to date.

## Uninstall

```bash
./uninstall.sh
```

Everything Annex placed is removed or moved to `~/omarchy-ubuntu-removed-<date>/`, and anything it
replaced is restored.

## Your GNOME is safe

- Annex is a separate session with its own settings, so Omarchy's themes, fonts and dark mode never
  leak into GNOME.
- Your existing config files are kept; anything Annex has to replace is backed up first.
- Hyprland is installed in `/opt/hyprland`, away from Ubuntu's own packages.

## What doesn't work

Some Omarchy features depend on Arch Linux: pacman/AUR updates (Annex uses apt instead),
bootloader/plymouth/hibernation setup, snapper snapshots, factory reset, DNS presets and sudoless Docker.

A few apps Omarchy expects aren't in Ubuntu's archive (hyprsunset, gpu-screen-recorder, tensaku,
localsend, Obsidian). Their menu entries work once you install them yourself.

## Contributing

How it works, building the Hyprland package, releases and testing pull requests:
see [docs/development.md](docs/development.md).

## License

MIT (see `LICENSE`). The Hyprland package bundles Hyprland and its libraries (BSD-3-Clause),
Quickshell (LGPL-3.0) and ttfx (MIT), built unmodified from the sources pinned in `build/versions.env`.
Omarchy (MIT) is downloaded by `install.sh`, not included here.
