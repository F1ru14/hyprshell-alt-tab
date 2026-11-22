#!/usr/bin/env bash
# Windows-style Alt+Tab for Hyprland, using hyprshell.
# Tested on Fedora 42 + Hyprland 0.55.2. See README.md.
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
bindir="$HOME/.local/bin"
confdir="$HOME/.config/hyprshell"
unitdir="$HOME/.config/systemd/user"
legacy_tag=v4.9.5

die() { echo "error: $*" >&2; exit 1; }

command -v hyprctl >/dev/null || die "hyprctl not found; run this inside a Hyprland session"
hypr_ver=$(hyprctl version | sed -n '1s/^Hyprland \([0-9][0-9.]*\).*/\1/p')
[ -n "$hypr_ver" ] || die "could not detect Hyprland version"
read -r hypr_major hypr_minor < <(awk -F. '{print $1, $2}' <<<"$hypr_ver")
new_api=0
(( hypr_major > 0 || hypr_minor >= 57 )) && new_api=1

mkdir -p "$bindir" "$confdir" "$unitdir"

install_legacy() {
    echo "Hyprland $hypr_ver: building hyprshell $legacy_tag (legacy bind API)..."
    command -v dnf >/dev/null || die "install these first: gcc gcc-c++ make pkgconf-pkg-config gtk4-devel libadwaita-devel gtk4-layer-shell-devel cargo git"
    sudo dnf install -y gcc gcc-c++ make pkgconf-pkg-config gtk4-devel libadwaita-devel gtk4-layer-shell-devel cargo git
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    git clone -q --depth 1 --branch "$legacy_tag" https://github.com/H3rmt/hyprshell "$tmp/src"
    (cd "$tmp/src" && cargo build --release -j "$(nproc)" \
        --no-default-features --features "json5_config,launcher_calc,debug_command")
    install -m755 "$tmp/src/target/release/hyprshell" "$bindir/hyprshell"
}

install_new() {
    echo "Hyprland $hypr_ver: installing hyprshell 4.10+ (Lua bind API)..."
    if command -v dnf >/dev/null; then
        sudo dnf install -y dnf-plugins-core
        sudo dnf copr enable -y h3rmt/hyprshell
        sudo dnf install -y hyprshell
        ln -sf /usr/bin/hyprshell "$bindir/hyprshell"
    else
        die "install 'hyprshell' from your distro/AUR, then symlink it to $bindir/hyprshell"
    fi
}

if [ -x "$bindir/hyprshell" ]; then
    echo "hyprshell already installed at $bindir/hyprshell"
elif (( new_api )); then
    install_new
else
    install_legacy
fi

# Keep any existing config (your tweaks); only create a default on first install.
if [ ! -e "$confdir/config.ron" ]; then
    install -m644 "$script_dir/config.ron" "$confdir/config.ron"
fi

install -m644 "$script_dir/hyprshell.service" "$unitdir/hyprshell.service"

# Stop the old rofi Alt+Tab from winning on DMS-managed setups.
if [ -f "$HOME/.config/hypr/hyprland.conf" ] \
    && ! grep -q '^unbind = ALT, Tab' "$HOME/.config/hypr/hyprland.conf"; then
    printf '\n# hyprshell Alt+Tab\nunbind = ALT, Tab\n' >> "$HOME/.config/hypr/hyprland.conf"
fi

systemctl --user daemon-reload
systemctl --user enable --now hyprshell
systemctl --user restart hyprshell

echo
echo "Done. Hold Alt and tap Tab; release Alt to focus."
echo "Logs: journalctl --user -u hyprshell -n 30"
