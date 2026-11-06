# Development notes

Details for people changing this project. Users only need the [README](../README.md).

## What gets installed

- **Hyprland 0.57.1 + Quickshell 0.3.2** (plus the fixes Omarchy ships, up to `2b4501a`), compiled into a
  self-contained `.deb` under `/opt/hyprland` (no conflicts with Ubuntu's packages), together with Omarchy's own
  programs that Ubuntu doesn't package: `ttfx` (screensaver text effects), `omasnap` (screenshots), `owe` (the
  wallpaper engine behind video backgrounds and theme intros, plus its lock-screen module), the titlebars plugin
  for floating workspaces, and Omarchy's apps (Omacalc, Omawrite, Omacut, Hype, Monologue, Signed, Aether,
  cliamp, Disktree, Gliff). Versions are pinned in `build/versions.env`; Aether and Disktree are upstream
  release binaries (checksums pinned), the rest is built from source. The apps' launchers and icons are in
  `/opt/hyprland/share`, which only the Hyprland session adds to `XDG_DATA_DIRS` (`config/uwsm/env`;
  `hyprland-session` puts the user manager's value back when the session ends), so they don't show up in GNOME.
  `install.sh` places owe's user unit (`owed.service`, only started where `OMARCHY_PATH` is set, so not in
  GNOME) and its theme-set hook.
- **Omarchy 4.5.0**, a pinned checkout in `~/.local/share/omarchy`: its keybindings, look, window rules,
  themes and Quickshell shell (bar, menus, notifications, OSD, lock screen) run unmodified.
- **Ubuntu layer** (`~/.local/share/omarchy-ubuntu`): a read-only `pacman` stand-in backed by dpkg,
  apt-based `omarchy-update` and package commands (Install > Package and Remove > Package pick from apt;
  Install > Browser installs from the vendors' Ubuntu sources or Flathub, and `layer/lib/pkg-names.sh` maps
  those browsers' Arch package names to what Ubuntu installs), an `awk` -> `gawk` wrapper (Omarchy's scripts need GNU awk;
  the system-wide awk stays mawk), and stubs for Arch-only commands (limine, plymouth, AUR, snapshots,
  factory reset, kernel switching, pacman repositories). Remove > Preinstalls and Install > Preinstalls have
  layer versions: upstream uninstalls the preinstalled packages (some shared with GNOME, Omarchy's own are
  part of the Hyprland package), so these hide and show the bundled apps' launchers (`Hidden=true` copies in
  `~/.local/share/applications`, for apps GNOME doesn't have) and set the state file that turns their
  shortcuts off. Superwhisper (dictation, proprietary) is installed from its vendor on demand by
  `layer/libexec/superwhisper`, mapped from `superwhisper-bin` in `layer/lib/pkg-names.sh`: Arch's package
  layout with `/usr/local` for `/usr`, the daemon and launcher limited to the Hyprland session, version and
  checksum pinned, refreshed by `install.sh` when the pin changes.
- **Keyboard**: the layout goes to `~/.config/omarchy/keyboard-layouts` (taken from `/etc/default/keyboard`),
  where Omarchy reads it and Setup > Typing > Keyboard Layouts writes it. Omarchy's own XKB option
  `omarchy:shift_caps_compose` (Caps Lock stays Caps Lock, Shift + Caps Lock is Compose) lives in `/etc/xkb` on
  Arch; here it goes to `~/.config/xkb`, which libxkbcommon also reads. Its rules file includes the system's
  rules and only adds that option, so every other keymap (GNOME's too) compiles exactly as before.
- **Herdr** (Omarchy's terminal workspace manager): the static release binary goes to `~/.local/bin/herdr`
  (pinned in `install.sh`, self-updates with `herdr update`) unless you already have one, plus Omarchy's
  tmux-style config if you have none. If the download fails, the install carries on without it.
  Omarchy's layout commands work in bash and zsh: `hdl <ai> [<ai2>]` (editor + AI + terminal),
  `hdlm <ai>` (an `hdl` tab per subdirectory), `hsl <n> <cmd>` (n panes running cmd), `hds` (needs `hunk`
  and `opencode`), and `h` for `herdr`. A line `install.sh` keeps in `~/.bashrc`/`~/.zshrc` (marked
  `# omarchy-ubuntu`) loads `layer/shell/herdr.sh`, which only does something when `OMARCHY_PATH` is set.
  To take Omarchy's config over your own: `omarchy-refresh-herdr` (keeps yours as `config.toml.bak.<time>`).
  Super+Ctrl+Return is one of Omarchy's preinstalled-app bindings, so Remove > Preinstalls turns it off too,
  as upstream.
- **Screensaver inhibit bridge** (`omarchy-idle-inhibit-bridge`): answers apps that ask over DBus to keep the
  screen awake (browsers during video calls, video players) by holding a Wayland idle inhibitor, the only kind
  Omarchy's shell honours.
- **Config migrations** (`layer/bin/omarchy-migrate`): upstream runs every new script in Omarchy's
  `migrations/` once; many of them call pacman, change `/etc` or set up Arch-only hardware. Here only the ones
  `layer/migrations.list` marks `run` are run, at Hyprland login (`layer/lua/hypr.lua`, logged to the journal
  as `omarchy-migrate`) and after **Update > Omarchy**, restarting the shell when one ran; `skip` ones are
  marked done, unlisted ones stay pending. They run in the session, not from `install.sh`, because some talk
  to the shell over IPC. Done migrations are marked in `~/.local/state/omarchy/migrations`, as upstream.
  `install.sh` writes those markers once: on a first install every migration of the checkout (its configs are
  current), on an install from before migrations ran here the ones in `layer/migrations.baseline` (what
  v4.0.6, the first pinned Omarchy, shipped).
- **Patches** (`patches/`), applied to the Omarchy checkout by `install.sh`: variables named `native` in the
  background services that Ubuntu's Qt 6.10 QML parser rejects (it reserves Java's keywords), the Update >
  Channel menu, the app launcher's uninstall action (apt and snap instead of pacman), Remove menu entries that
  would take packages away from GNOME or turn off its services (Fingerprint, SSH Agent), the
  browser installer (it skips Omarchy's browser policies under `/etc` and `~/.config/environment.d`, which GNOME
  would pick up too), menu entries hidden because they need Arch, and the Ubuntu names of browsers in
  `omarchy-default-browser` (which installs a browser it doesn't find) and `omarchy-remove-browser`, the
  titlebars plugin's path under `/opt/hyprland`, and Superwhisper's paths under `/usr/local`.

## Moving to a newer Omarchy

Changing `OMARCHY_REF` in `install.sh` brings new migrations. Read each one that isn't in
`layer/migrations.list` (`comm -13 <(git ls-tree --name-only <old> migrations/ | sort) <(git ls-tree --name-only
<new> migrations/ | sort)` in an Omarchy clone) and add it as `run` or `skip` with the reason. Only `run` what
edits user config and leaves a config that's already current as it is; anything with sudo, `/etc`, pacman or
Arch-only hardware is `skip`. Migration names are timestamps but aren't in release order, so compare by name.

## How GNOME is kept separate

- The Hyprland session uses its own GNOME-settings database (`~/.config/dconf/hyprland`, via `DCONF_PROFILE`),
  so Omarchy's dark mode, icons and fonts never change GNOME.
- Theme switching does not rewrite VS Code, Claude Code, Obsidian or browser policies (shared with GNOME).
- Omarchy's XDG autostart entries are not installed (GNOME would run them too).
- Omarchy's speaker tuning (`omarchy audio tuning on`) runs as a user service started with the graphical
  session, which GNOME starts too. A drop-in
  (`~/.config/systemd/user/omarchy-speaker-tuning.service.d/omarchy-ubuntu.conf`) adds
  `ConditionEnvironment=OMARCHY_PATH`, so GNOME plays straight to the speakers.
  The tunings Omarchy ships (Dell XPS 14/16 2026) don't load on Ubuntu, though: their limiter is an LV2
  plugin and Ubuntu's PipeWire is built without LV2 support (LADSPA works, e.g. `lsp-plugins-ladspa`).
- Shell additions (the herdr commands) load only when `OMARCHY_PATH` is set, which only the Hyprland session
  does; GNOME terminals behave as before. The rc files aren't backed up: `uninstall.sh` removes only that line,
  so other edits survive.
- Outside your home and `/opt/hyprland` it places only `/etc/pam.d/omarchy-lock-password`, the PAM
  stack Omarchy's lock screen authenticates against (GNOME doesn't read it), and Omarchy's DNS preset helper
  (`/usr/local/libexec/omarchy-dns` plus `/etc/sudoers.d/omarchy-ubuntu-dns`, so Cloudflare/Google/DHCP switch
  without a password). DNS is system-wide, so a preset picked in Hyprland applies under GNOME too.
- `omarchy-pkg-drop` refuses to remove anything beyond the packages it was asked for (pacman's `-Rns` refuses
  the same way; `apt-get remove -y` would take the dependents along).
- `install.sh` only creates config files you don't have yet, except `~/.config/hypr/hyprland.lua` and
  `~/.config/uwsm/env`; anything it replaces is backed up to `~/.local/state/omarchy-ubuntu/backup/`.

## Building the package

```bash
sudo apt install podman
./build.sh            # -> dist/hyprland-opt_<version>_amd64.deb  (first run ~30-60 min)
```

The build runs in a clean `ubuntu:26.04` container. Versions are pinned in `build/versions.env`.
Quickshell is tied to the exact Qt version (6.10.2 today); if Ubuntu ships a Qt update, apt holds it back
until you rebuild and reinstall the `.deb`.
To move to a newer Hyprland, change `HYPRLAND_TAG` and copy the dependency revisions from that
tag's `flake.lock`.

`install.sh` uses the newest `.deb` in `dist/`, or a path you pass it, before falling back to the release.

## Releases

The **Package** workflow (`.github/workflows/package.yml`) builds the `.deb` on GitHub whenever a push
changes `build/`, and publishes it as release `hyprland-opt-<version>`, which `install.sh` downloads
(a private repo needs `gh auth login` on the machine). A branch gets a pre-release; when the same `build/`
reaches `main` it becomes the latest release without building again.

Changing `build/` means bumping `PKG_REVISION` in `build/versions.env`: a branch that changes `build/` again
rebuilds its pre-release, but a version already released from `main` is never rebuilt, and the workflow
fails instead.

## Trying a pull request

Omarchy's **Update > Channel** menu switches the checkout between `main` and an open pull request:

- **Pull request** lists the open PRs (needs a logged-in `gh`). Picking one checks out its branch and
  re-runs `install.sh` in a terminal.
- **Stable** goes back to `main` (pulling the latest) and re-runs `install.sh`, which removes whatever the
  pull request installed and restores anything it had replaced.

From a terminal: `omarchy-channel-set stable` or `omarchy-channel-set pr 12`.

**Update > Omarchy** (`omarchy-update`) runs the apt upgrade and then brings the checkout up to date on its
channel: on Stable it pulls `main`, on a pull request it pulls the branch, and a pull request that has
been merged or closed goes back to Stable. `install.sh` only re-runs when that changed something. When the
Hyprland package that `build/versions.env` names is still being built by the Package workflow, it offers to
wait for that build; if it fails, the checkout goes back to where it was.

The checkout must have no uncommitted changes. Changes to the session environment (`config/uwsm/env`)
apply after logging out and back in.

For a PR to be undone cleanly, `install.sh` must record what it places on every run: use `manage` (see
`install.sh`) for files, unit files and their `.wants` links, including files outside your home.
Something placed only once (like the herdr binary, downloaded only when missing) is managed on later runs
by checking the manifest for it. The `~/.bashrc`/`~/.zshrc` line stays after switching back, but does
nothing once the layer's `shell/herdr.sh` is gone.
