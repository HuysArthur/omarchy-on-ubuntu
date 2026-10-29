# omarchy-on-ubuntu

[Omarchy](https://omarchy.org)'s Hyprland desktop on Ubuntu 26.04, as an extra login session next to GNOME.
Unofficial: not affiliated with Basecamp or the Omarchy project.

- **Hyprland 0.56.2 + Quickshell 0.3.2**, compiled once into a self-contained `.deb` under `/opt/hyprland`
  (no conflicts with Ubuntu's packages).
- **Omarchy 4.0.6** (pinned checkout in `~/.local/share/omarchy`): its keybindings, look, window rules,
  themes and its Quickshell shell (bar, menus, notifications, OSD, lock screen) run unmodified.
- **Ubuntu layer** (`~/.local/share/omarchy-ubuntu`): a read-only `pacman` stand-in backed by dpkg,
  apt-based `omarchy-update`/`omarchy-pkg-add`, an `awk` -> `gawk` wrapper (Omarchy's scripts need GNU awk;
  the system-wide awk stays mawk), and stubs for Arch-only commands (limine, plymouth, AUR, snapshots,
  factory reset).
- **Patches** (`patches/`): applied to the Omarchy checkout by `install.sh`: a variable named `transient`
  in the notifications service that Ubuntu's Qt 6.10 QML parser rejects, and the Update > Channel menu
  (see [Trying a pull request](#trying-a-pull-request)).

## GNOME stays untouched

- Hyprland is a separate entry on the login screen (gear icon -> "Hyprland (Omarchy)"); "Ubuntu" is still GNOME.
- The Hyprland session uses its own GNOME-settings database (`~/.config/dconf/hyprland`, via `DCONF_PROFILE`),
  so Omarchy's dark mode, icons and fonts never change GNOME.
- Theme switching does not rewrite VS Code, Claude Code, Obsidian or browser policies (shared with GNOME).
- Omarchy's XDG autostart entries are not installed (GNOME would run them too).
- The only file outside your home and `/opt/hyprland` is `/etc/pam.d/omarchy-lock-password`, the PAM
  stack Omarchy's lock screen authenticates against (GNOME doesn't read it).
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
git clone https://github.com/HuysArthur/omarchy-on-ubuntu && cd omarchy-on-ubuntu
./install.sh                          # newest .deb in dist/, else downloads it from this repo's release
./install.sh /path/to/hyprland-opt_0.56.2-1~ubuntu26.04_amd64.deb
```

Then log out and pick "Hyprland (Omarchy)". Super+K shows all keybindings, Super+Space opens the menu.

Other machines don't compile: the **Package** workflow (`.github/workflows/package.yml`) builds the `.deb`
on GitHub whenever a push changes `build/`, and publishes it as release `hyprland-opt-<version>`, which
`install.sh` downloads (a private repo needs `gh auth login` on the machine). A branch gets a pre-release;
when the same `build/` reaches `main` it becomes the latest release without building again. Changing
`build/` means bumping `PKG_REVISION` in `build/versions.env`: a branch that changes `build/` again
rebuilds its pre-release, but a version already released from `main` is never rebuilt, and the workflow
fails instead.

## Trying a pull request

Omarchy's **Update > Channel** menu switches this checkout between `main` and an open pull request:

- **Pull request** lists the open PRs (needs a logged-in `gh`). Picking one checks out its branch and
  re-runs `install.sh` in a terminal.
- **Stable** goes back to `main` (pulling the latest) and re-runs `install.sh`, which removes whatever the
  pull request installed and restores anything it had replaced.

**Update > Omarchy** (`omarchy-update`) runs the apt upgrade and then brings this checkout up to date on its
channel: on Stable it pulls `main`, on a pull request it pulls the branch, and a pull request that has
been merged or closed goes back to Stable. `install.sh` only re-runs when that changed something. When the
Hyprland package that `build/versions.env` names is still being built by the Package workflow, it offers to
wait for that build; if it fails, the checkout goes back to where it was.

The checkout must have no uncommitted changes. Changes to the session environment (`config/uwsm/env`)
apply after logging out and back in. From a terminal: `omarchy-channel-set stable` or
`omarchy-channel-set pr 12`.

For a PR to be undone cleanly, `install.sh` must record what it places on every run: use `manage` (see
`install.sh`) for files, unit files and their `.wants` links, including files outside your home.

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

## License

The scripts and configs in this repo are MIT (see `LICENSE`). The `.deb` contains Hyprland and its hyprwm
libraries (BSD-3-Clause) and Quickshell (LGPL-3.0), built unmodified from the sources pinned in
`build/versions.env`. Omarchy (MIT) is downloaded by `install.sh`, not included here.
