#!/usr/bin/env bash
# Run from an extracted Linux package. Installs for the current user only.
set -euo pipefail
case "${1:-}" in
  '') register=1 ;;
  --no-register) register=0 ;;
  *) echo 'Usage: ./install.sh [--no-register]' >&2; exit 1 ;;
esac
source_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
version="$(cat "$source_dir/VERSION")"
case "$version" in
  ''|*[!a-zA-Z0-9._+-]*) echo 'Invalid package version' >&2; exit 1 ;;
esac
[[ -x "$source_dir/bundle/gopher_flutter_client" ]] || { echo 'Missing application bundle' >&2; exit 1; }
data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
case "$data_home" in
  /*) ;;
  *) echo 'XDG_DATA_HOME must be an absolute path' >&2; exit 1 ;;
esac
case "$data_home" in
  *$'\n'*|*$'\r'*) echo 'Installation paths cannot contain newlines' >&2; exit 1 ;;
esac
app_dir="$data_home/gopher-client/$version"
mkdir -p "$app_dir" "$data_home/applications"
cp -a "$source_dir/bundle/." "$app_dir/"
# Desktop Exec entries have their own quoting and percent field syntax.
executable="$(printf '%s' "$app_dir/gopher_flutter_client" | sed 's/[\\"`$]/\\&/g; s/%/%%/g')"
cat > "$data_home/applications/org.gopherclient.gopher_flutter_client.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Gopher Client
Comment=Read Gopher menus and text documents
Exec="$executable" %u
Terminal=false
Categories=Network;
MimeType=x-scheme-handler/gopher;
StartupWMClass=org.gopherclient.gopher_flutter_client
DESKTOP
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$data_home/applications"
fi
if [[ "$register" == 1 ]] && command -v xdg-mime >/dev/null 2>&1; then
  xdg-mime default org.gopherclient.gopher_flutter_client.desktop x-scheme-handler/gopher
fi
printf 'Installed Gopher Client in %s\n' "$app_dir"
