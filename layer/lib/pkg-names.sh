# Sourced by the layer's package commands (pacman, omarchy-pkg-drop, omarchy-pkg-aur-add).
# Omarchy names a few apps by their Arch (AUR) package. On Ubuntu they come from elsewhere under another name:
# "deb:<package>" for a .deb or apt repository, "flatpak:<app id>" for Flathub, "vendor:<name>" for an app the
# layer installs from its vendor with libexec/<name>. Other names are used as they are.
declare -A UBUNTU_PKG_SOURCE=(
  [google-chrome]=deb:google-chrome-stable
  [microsoft-edge-stable-bin]=deb:microsoft-edge-stable
  [brave-bin]=deb:brave-browser
  [brave-origin-bin]=deb:brave-origin
  [zen-browser-bin]=flatpak:app.zen_browser.zen
  [superwhisper-bin]=vendor:superwhisper
)

PKG_LIBEXEC=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../libexec

# pkg_source NAME: where NAME comes from on Ubuntu, as deb:<package> or flatpak:<app id>.
pkg_source() { echo "${UBUNTU_PKG_SOURCE[$1]:-deb:$1}"; }

# pkg_mapped NAME: true if NAME is an Arch name with an Ubuntu counterpart above.
pkg_mapped() { [[ -n ${UBUNTU_PKG_SOURCE[$1]:-} ]]; }

# pkg_installed NAME: true if NAME (an Arch name above, or a Ubuntu package) is installed.
pkg_installed() {
  local src
  src=$(pkg_source "$1")
  case $src in
  deb:*) dpkg-query -W -f='${db:Status-Abbrev}' "${src#deb:}" 2>/dev/null | grep -q '^ii' ;;
  flatpak:*) command -v flatpak >/dev/null && flatpak info "${src#flatpak:}" >/dev/null 2>&1 ;;
  vendor:*) [[ -f /opt/${src#vendor:}/.omarchy-ubuntu-version ]] ;;
  esac
}
