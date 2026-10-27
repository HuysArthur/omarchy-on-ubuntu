# omarchy-ubuntu

[Omarchy](https://omarchy.org)'s Hyprland desktop on Ubuntu 26.04, as an extra login session next to GNOME.

- **Hyprland 0.56.2 + Quickshell 0.3.2**, compiled once into a self-contained `.deb` under `/opt/hyprland`
  (no conflicts with Ubuntu's packages).
- **Omarchy 4.0.6** (pinned checkout in `~/.local/share/omarchy`): its keybindings, look, window rules,
  themes and its Quickshell shell (bar, menus, notifications, OSD, lock screen) run unmodified.
- **Ubuntu layer** (`~/.local/share/omarchy-ubuntu`): a read-only `pacman` stand-in backed by dpkg,
  apt-based `omarchy-update`/`omarchy-pkg-add`, an `awk` -> `gawk` wrapper (Omarchy's scripts need GNU awk;
  the system-wide awk stays mawk), and stubs for Arch-only commands (limine, plymouth, AUR, snapshots,
  factory reset).
- **Patches** (`patches/`): applied to the Omarchy checkout by `install.sh`. Currently one: a variable
  named `transient` in the notifications service that Ubuntu's Qt 6.10 QML parser rejects.

## GNOME stays untouched

- Hyprland is a separate entry on the login screen (gear icon -> "Hyprland (Omarchy)"); "Ubuntu" is still GNOME.
- The Hyprland session uses its own GNOME-settings database (`~/.config/dconf/hyprland`, via `DCONF_PROFILE`),
  so Omarchy's dark mode, icons and fonts never change GNOME.
- Theme switching does not rewrite VS Code, Claude Code, Obsidian or browser policies (shared with GNOME).
- Omarchy's XDG autostart entries are not installed (GNOME would run them too).
- `install.sh` only creates config files you don't have yet, except `~/.config/hypr/hyprland.lua` and
  `~/.config/uwsm/env`; anything it replaces is backed up to `~/.local/state/omarchy-ubuntu/backup/`.

## Build the package (once, on any Ubuntu 26.04 machine)

```bash
sudo apt install podman
./build.sh            # -> dist/hyprland-opt_<version>_amd64.deb  (first run ~30-60 min)
```

The build runs in a clean `ubuntu:26.04` container. Versions are pinned in `build/versions.env`.
Quickshell is tied to the exact Qt version (6.10.2 today); if Ubuntu ships a Qt update, apt holds it back
until you rebuild and reinstall the `.deb`.
To move to a newer Hyprland, change `HYPRLAND_TAG` and copy the dependency revisions from that
tag's `flake.lock`.

## Install (every machine)

```bash
git clone https://github.com/<you>/omarchy-ubuntu && cd omarchy-ubuntu
./install.sh                          # newest .deb in dist/, else downloads it from this repo's release
./install.sh /path/to/hyprland-opt_0.56.2-1~ubuntu26.04_amd64.deb
```

Then log out and pick "Hyprland (Omarchy)". Super+K shows all keybindings, Super+Space opens the menu.

Publishing the build so other machines skip compiling (the download needs a public repo; for a private one,
copy the `.deb` over or fetch it with `gh release download`):

```bash
v=0.56.2-1   # HYPRLAND_TAG without the v, then PKG_REVISION
cp dist/hyprland-opt_${v}~ubuntu26.04_amd64.deb /tmp/hyprland-opt_${v}_ubuntu26.04_amd64.deb
gh release create hyprland-opt-$v /tmp/hyprland-opt_${v}_ubuntu26.04_amd64.deb --title "hyprland-opt $v"
```

## Uninstall

```bash
./uninstall.sh
```

Removes the package, the Omarchy checkout and the layer, moves the configs it placed to
`~/omarchy-ubuntu-removed-<date>/`, and restores anything it had replaced.

## Not available on Ubuntu

Omarchy features that need Arch: system updates through pacman/AUR (`omarchy-update` runs apt instead),
bootloader/plymouth/hibernation setup, snapper snapshots, factory reset, DNS presets, sudoless Docker.
Some apps Omarchy preinstalls aren't in Ubuntu's archive (hyprsunset night light, gpu-screen-recorder,
tensaku, localsend, Obsidian); their menu entries won't work until you install them yourself.
