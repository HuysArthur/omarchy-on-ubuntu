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
- **Patches** (`patches/`), applied to the Omarchy checkout by `install.sh`: variables named `native` in the
  background services that Ubuntu's Qt 6.10 QML parser rejects (it reserves Java's keywords), the Update >
  Channel menu, the app launcher's uninstall action (apt and snap instead of pacman), Remove menu entries that
  would take packages away from GNOME or turn off its services (Fingerprint, SSH Agent), the browser installer
  (it skips Omarchy's browser policies under `/etc` and `~/.config/environment.d`, which GNOME would pick up
  too), menu entries hidden because they need Arch, the Ubuntu names of browsers in `omarchy-default-browser`
  (which installs a browser it doesn't find) and `omarchy-remove-browser`, the titlebars plugin's path under
  `/opt/hyprland`, Superwhisper's paths under `/usr/local`, a note at the top of Omarchy's agent skills that
  sends agents to the Ubuntu skill, and `omarchy <command>` looking commands up on PATH, so it reaches the
  layer's versions (upstream it only runs the ones next to it).
- **Agent skills**: Omarchy's skills (`omarchy` for changing the desktop, `omarchy-app` for building apps,
  `diagnose-crash`) and the layer's `omarchy-ubuntu` skill (`layer/agents/skills/`) are linked into
  `~/.agents/skills`, `~/.claude/skills`, `~/.codex/skills`, `~/.pi/agent/skills` and `~/.gemini/config/skills`,
  as Omarchy's `omarchy-provision-user` does; into `~/.hermes/skills` and its profiles only if you have
  `~/.hermes`. A skill of yours with the same name is left alone. The Ubuntu skill tells agents what differs
  here: apt instead of pacman, `$OMARCHY_PATH` instead of `/usr/share/omarchy`, which files `install.sh`
  overwrites, what GNOME shares, how to tell the sessions apart, what's Arch-only, and where to report bugs.
  Those folders are shared with GNOME, so agents see the skills there too. When changing how the port works,
  update that skill.
- **Resetting configs**: `omarchy-reinstall-configs` (`omarchy reinstall configs`; the `omarchy-ubuntu` skill
  has agents ask before using it, and try `omarchy refresh` first) places `layer/lib/configs.sh`'s files with
  `RESET_CONFIGS=1`, without `install.sh`, so it needs no sudo, network or checkout. That makes `put
  --if-missing` replace your file. `put --keep` files, the apps GNOME shares (ghostty, btop, imv, lazygit,
  herdr), are never replaced. Your edited versions of files we seeded go to
  `~/.local/state/omarchy-ubuntu/reset-backup/`, not `backup/`, which `uninstall.sh` restores as what was there
  before the install; `uninstall.sh` moves `reset-backup/` aside. `omarchy-refresh-config` (also behind **Update
  > Config > Hyprland**) restores `hypr/hyprland.lua`, `uwsm/env` and the generated `omarchy/keyboard-layouts`,
  `hypr/input.lua` and `hypr/monitors.lua` from the layer's `config/`, since Omarchy's own would start the
  session without the layer or lose this machine's keyboard layout and scale; other files go to Omarchy's
  command. `omarchy reinstall pkgs` is a stub (it would run pacman).

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
