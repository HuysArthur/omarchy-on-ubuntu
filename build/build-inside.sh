#!/usr/bin/env bash
# Runs inside the builder container. /src = repo (ro), /work = cache, /out = .deb output.
set -euo pipefail

source /src/build/versions.env

PREFIX=/opt/hyprland
SRC=/work/src
BLD=/work/build
STAGE=/work/pkg
JOBS=${JOBS:-$(nproc)}

export PKG_CONFIG_PATH=$PREFIX/lib/pkgconfig:$PREFIX/share/pkgconfig
export CMAKE_PREFIX_PATH=$PREFIX
export PATH=$PREFIX/bin:$PATH
export LD_LIBRARY_PATH=$PREFIX/lib
# Hyprland needs C++26 library features GCC 15 lacks. Ubuntu 26.04's libstdc++6 already comes from GCC 16.
export CC=gcc-16 CXX=g++-16

mkdir -p "$SRC" "$BLD"

fetch() {
  local name=$1 url=$2 rev=$3
  [ -d "$SRC/$name/.git" ] || git clone -q --filter=blob:none "$url" "$SRC/$name"
  git -C "$SRC/$name" fetch -q --tags origin
  git -C "$SRC/$name" checkout -q --detach "$rev"
  git -C "$SRC/$name" submodule update -q --init --recursive
}

cmake_build() {
  local name=$1; shift
  echo "==> $name"
  cmake -S "$SRC/$name" -B "$BLD/$name" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=$PREFIX \
    -DCMAKE_INSTALL_LIBDIR=lib \
    -DCMAKE_INSTALL_RPATH=$PREFIX/lib \
    -DBUILD_TESTING=OFF \
    "$@"
  cmake --build "$BLD/$name" -j"$JOBS"
  cmake --install "$BLD/$name"
}

GH=https://github.com/hyprwm

# wayland-protocols >= 1.49 needs wayland-scanner >= 1.25 (Ubuntu has 1.24). Build-time only, not packaged.
TOOLS=/opt/buildtools
export PATH=$TOOLS/bin:$PATH
fetch wayland https://gitlab.freedesktop.org/wayland/wayland.git "$WAYLAND_SCANNER_TAG"
echo "==> wayland-scanner"
[ -d "$BLD/wayland" ] || meson setup "$BLD/wayland" "$SRC/wayland" --prefix=$TOOLS --libdir=lib \
  -Dlibraries=false -Ddocumentation=false -Dtests=false -Ddtd_validation=false
meson install -C "$BLD/wayland" --quiet
export PKG_CONFIG_PATH=$TOOLS/lib/pkgconfig:$TOOLS/share/pkgconfig:$PREFIX/lib/pkgconfig:$PREFIX/share/pkgconfig

fetch wayland-protocols https://gitlab.freedesktop.org/wayland/wayland-protocols.git "$WAYLAND_PROTOCOLS_TAG"
echo "==> wayland-protocols"
[ -d "$BLD/wayland-protocols" ] || meson setup "$BLD/wayland-protocols" "$SRC/wayland-protocols" --prefix=$PREFIX -Dtests=false
meson install -C "$BLD/wayland-protocols" --quiet

fetch hyprwayland-scanner "$GH/hyprwayland-scanner" "$HYPRWAYLAND_SCANNER_REV"; cmake_build hyprwayland-scanner
fetch hyprutils           "$GH/hyprutils"           "$HYPRUTILS_REV";           cmake_build hyprutils
fetch hyprlang            "$GH/hyprlang"            "$HYPRLANG_REV";            cmake_build hyprlang
fetch hyprcursor          "$GH/hyprcursor"          "$HYPRCURSOR_REV";          cmake_build hyprcursor
fetch hyprgraphics        "$GH/hyprgraphics"        "$HYPRGRAPHICS_REV";        cmake_build hyprgraphics
fetch aquamarine          "$GH/aquamarine"          "$AQUAMARINE_REV";          cmake_build aquamarine
fetch hyprwire            "$GH/hyprwire"            "$HYPRWIRE_REV";            cmake_build hyprwire
fetch hyprland-protocols  "$GH/hyprland-protocols"  "$HYPRLAND_PROTOCOLS_REV";  cmake_build hyprland-protocols

fetch Hyprland "$GH/Hyprland" "$HYPRLAND_TAG"
cmake_build Hyprland -DNO_HYPRPM=ON -DNO_UWSM=ON

fetch quickshell https://git.outfoxxed.me/quickshell/quickshell "$QUICKSHELL_REV"
cmake_build quickshell -DDISTRIBUTOR="omarchy-ubuntu" -DCRASH_HANDLER=OFF -DINSTALL_QML_PREFIX=lib/qt6/qml

fetch ttfx https://github.com/omacom/ttfx "$TTFX_TAG"
echo "==> ttfx"
CARGO_HOME=/work/cargo cargo build --locked --release --manifest-path "$SRC/ttfx/Cargo.toml" --target-dir "$BLD/ttfx"
install -m755 "$BLD/ttfx/release/ttfx" "$PREFIX/bin/ttfx"

# Omarchy's screenshot tool (omarchy-capture-screenshot runs it since Omarchy 4.5); not in Ubuntu's archive.
fetch omasnap https://github.com/omacom/omasnap "$OMASNAP_TAG"
cmake_build omasnap

# owe, Omarchy's wallpaper engine (video backgrounds, theme intros), and its lock-screen QML module.
# install.sh places the user unit and the theme-set hook from share/owe.
fetch owe https://github.com/omacom/owe "$OWE_TAG"
echo "==> owe"
[ -d "$BLD/owe" ] || meson setup "$BLD/owe" "$SRC/owe" --prefix=$PREFIX --libdir=lib --buildtype=release
meson install -C "$BLD/owe" --quiet
install -Dm755 "$SRC/owe/hooks/owe-idle" "$PREFIX/bin/owe-idle"
install -Dm644 "$SRC/owe/hooks/theme-set.d/10-owe-sync" "$PREFIX/share/owe/10-owe-sync"
sed "s|%h/.local/bin/owed|$PREFIX/bin/owed|" "$SRC/owe/systemd/owed.service" > "$PREFIX/share/owe/owed.service"
echo "==> owe-lockfeed"
cmake -S "$SRC/owe/qml-plugin" -B "$BLD/owe-lockfeed" -G Ninja -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=$PREFIX -DCMAKE_INSTALL_LIBDIR=lib -DBUILD_TESTING=OFF
cmake --build "$BLD/owe-lockfeed" -j"$JOBS"
cmake --install "$BLD/owe-lockfeed"

# Titlebars for Omarchy's floating workspaces: a Hyprland plugin, so it has to match this exact Hyprland.
# Hyprland's headers include lua.h, which hyprland.pc doesn't point at (Ubuntu keeps it in /usr/include/lua5.5).
fetch omarchy-hyprland-titlebars https://github.com/omacom/omarchy-hyprland-titlebars "$TITLEBARS_TAG"
cmake_build omarchy-hyprland-titlebars -DCMAKE_CXX_FLAGS="$(pkg-config --cflags lua55)"

# ---- Omarchy's apps ----
# Launchers and icons go to $PREFIX/share, which only the Hyprland session adds to XDG_DATA_DIRS.
APPS=$PREFIX/share/applications
ICONS=$PREFIX/share/icons/hicolor

# download URL SHA256 FILE: a release asset, checked against the pinned checksum.
download() {
  [ -f "$3" ] && echo "$2  $3" | sha256sum -c --quiet - 2>/dev/null && return
  curl -fsSL -o "$3.part" "$1"
  echo "$2  $3.part" | sha256sum -c --quiet -
  mv "$3.part" "$3"
}

# Disktree, the disk-usage treemap (Omarchy's Disk Usage). Its source needs a newer Rust than Ubuntu has,
# so this is the upstream release binary.
echo "==> disktree"
dt=disktree-${DISKTREE_TAG#v}-x86_64-linux
download "https://github.com/tobi/disktree/releases/download/$DISKTREE_TAG/$dt.tar.gz" "$DISKTREE_SHA256" "$SRC/$dt.tar.gz"
rm -rf "$BLD/$dt" && tar -xzf "$SRC/$dt.tar.gz" -C "$BLD"
install -Dm755 "$BLD/$dt/disktree" "$PREFIX/bin/disktree"
mkdir -p "$APPS"
sed -e 's|@BINDIR@/||' -e "s|@VERSION@|${DISKTREE_TAG#v}|" "$BLD/$dt/disktree.desktop.in" > "$APPS/disktree.desktop"
install -Dm644 "$BLD/$dt/disktree.svg" "$ICONS/scalable/apps/disktree.svg"

# Gliff, Hyprland remote desktop over SSH (the bar shows its sessions).
fetch gliff https://github.com/omacom/gliff "$GLIFF_TAG"
echo "==> gliff"
CARGO_HOME=/work/cargo cargo build --locked --release --manifest-path "$SRC/gliff/Cargo.toml" --target-dir "$BLD/gliff"
for bin in gliff gliff-server gliff-probe; do install -m755 "$BLD/gliff/release/$bin" "$PREFIX/bin/$bin"; done
install -Dm644 "$SRC/gliff/pkgbuild/gliff.desktop" "$APPS/gliff.desktop"
install -Dm644 "$SRC/gliff/pkgbuild/gliff.svg" "$ICONS/scalable/apps/gliff.svg"

# ---- package ----
VERSION="${HYPRLAND_TAG#v}-${PKG_REVISION}~ubuntu26.04"
PKG=hyprland-opt
echo "==> packaging $PKG $VERSION"

rm -rf "$STAGE"
mkdir -p "$STAGE/opt" "$STAGE/DEBIAN" "$STAGE/usr/share/wayland-sessions"
cp -a $PREFIX "$STAGE/opt/"
R="$STAGE$PREFIX"
rm -rf "$R/include" "$R/lib/pkgconfig" "$R/share/pkgconfig" "$R/lib/cmake" \
       "$R/share/wayland-sessions" "$R/share/wayland-protocols" "$R/share/hyprland-protocols"
find "$R/lib" -name '*.a' -delete

cat > "$R/bin/hyprland-session" <<'EOF'
#!/bin/sh
# Login entry point for the "Hyprland (Omarchy)" session. Per-user environment lives in ~/.config/uwsm/env.
export PATH="/opt/hyprland/bin:$PATH"
export QML_IMPORT_PATH="/opt/hyprland/lib/qt6/qml${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}"
# The session adds /opt/hyprland/share to XDG_DATA_DIRS (~/.config/uwsm/env); remember the user manager's own.
data_dirs=$(systemctl --user show-environment 2>/dev/null | sed -n 's/^XDG_DATA_DIRS=//p')

if command -v uwsm >/dev/null 2>&1; then
  uwsm start -e -D Hyprland -N "Hyprland (Omarchy)" -- /opt/hyprland/bin/start-hyprland
else
  /opt/hyprland/bin/start-hyprland
fi

# The systemd user manager can outlive this session; keep its variables out of a following GNOME login.
systemctl --user unset-environment DCONF_PROFILE OMARCHY_PATH QML_IMPORT_PATH HYPRLAND_INSTANCE_SIGNATURE 2>/dev/null
if [ -n "$data_dirs" ]; then
  systemctl --user set-environment "XDG_DATA_DIRS=$data_dirs" 2>/dev/null
else
  systemctl --user unset-environment XDG_DATA_DIRS 2>/dev/null
fi
EOF
chmod 755 "$R/bin/hyprland-session"

cat > "$STAGE/usr/share/wayland-sessions/hyprland-opt.desktop" <<'EOF'
[Desktop Entry]
Name=Hyprland (Omarchy)
Comment=Hyprland compositor from /opt/hyprland
Exec=/opt/hyprland/bin/hyprland-session
Type=Application
DesktopNames=Hyprland
EOF

mapfile -t ELFS < <(find "$R" -type f -exec sh -c 'file -b "$1" | grep -q "^ELF" && echo "$1"' _ {} \;)
strip --strip-unneeded "${ELFS[@]}"

# dpkg-shlibdeps wants a debian/control in cwd; our own libs in /opt are resolved via -l and skipped.
# Every other library an ELF needs must be installed in the builder (the Containerfile), prebuilt ones included.
TMPC=$(mktemp -d); mkdir -p "$TMPC/debian"; printf 'Source: x\n\nPackage: x\nArchitecture: any\n' > "$TMPC/debian/control"
SHLIBS=$(cd "$TMPC" && dpkg-shlibdeps -O -l"$R/lib" --ignore-missing-info "${ELFS[@]}" | sed -n 's/^shlibs:Depends=//p')
rm -rf "$TMPC"

cat > "$STAGE/DEBIAN/control" <<EOF
Package: $PKG
Version: $VERSION
Architecture: amd64
Maintainer: Arthur Huys <arthur.huys@gmail.com>
Depends: $SHLIBS, xwayland, uwsm, qt6-wayland, qt6-svg-plugins, qt6-image-formats-plugins, layer-shell-qt,
 qml6-module-qtquick, qml6-module-qtquick-controls, qml6-module-qtquick-layouts,
 qml6-module-qtquick-shapes, qml6-module-qtquick-effects, qml6-module-qtquick-window,
 qml6-module-qtqml-models, qml6-module-qtqml-workerscript, libvulkan1
Recommends: xdg-desktop-portal-hyprland, xdg-desktop-portal-gtk
Section: x11
Priority: optional
Installed-Size: $(du -sk "$STAGE/opt" | cut -f1)
Description: Hyprland $HYPRLAND_TAG and Omarchy's programs, self-contained in /opt/hyprland
 Built for Ubuntu 26.04. Adds a "Hyprland (Omarchy)" login session next to GNOME
 and does not touch any files from Ubuntu's own packages.
 .
 Includes Quickshell ${QUICKSHELL_REV:0:7}, ttfx $TTFX_TAG, omasnap $OMASNAP_TAG,
 owe $OWE_TAG and Omarchy's titlebars plugin $TITLEBARS_TAG, Disktree and Gliff.
EOF

dpkg-deb --root-owner-group -Zzstd --build "$STAGE" "/out/${PKG}_${VERSION}_amd64.deb"
echo "==> /out/${PKG}_${VERSION}_amd64.deb"
