# hyprshell Alt+Tab for Hyprland

Windows-style Alt+Tab on Hyprland:

- hold **Alt**, tap **Tab** to cycle through windows by last use
- **Shift+Tab** or **Alt+\`** cycles backwards
- release **Alt** to focus the highlighted window
- **Q** closes the highlighted window while the switcher is open

Uses [hyprshell](https://github.com/H3rmt/hyprshell) in switch-only mode.

## Install

```bash
git clone https://github.com/<you>/hyprshell-alt-tab
cd hyprshell-alt-tab
./install.sh
```

The script installs the binary, `~/.config/hyprshell/config.ron`, a systemd user
service, and appends `unbind = ALT, Tab` to `~/.config/hypr/hyprland.conf`.
It never overwrites an existing config or an existing `hyprshell` binary, so
safe to re-run.

Fedora only (uses `dnf`). Hyprland must already be installed and running.

## Hyprland version matters

hyprshell 4.10+ dropped the old `hyprctl` API. The install script picks for you:

| Hyprland | hyprshell | Why |
| --- | --- | --- |
| ≤ 0.56 | 4.9.5, built from source | last release using legacy binds and old `hyprctl` JSON |
| ≥ 0.57 | latest (COPR) | needs the Lua bind API |

For Hyprland 0.55.2 on Fedora 42, the 4.9.5 source build takes ~5 minutes and
pulls `gtk4-devel`, `libadwaita-devel`, `gtk4-layer-shell-devel`, `cargo`.

Fedora 42's libadwaita (1.7) and glibc are too old for the official 4.10
binaries, which is why the script does not download them for older Hyprland.

## Config

`~/.config/hyprshell/config.ron`:

```ron
(
    version: 3,
    windows: (
        switch: (
            modifier: "alt",
            key: "Tab",
            filter_by: [],   // use ["current_workspace"] for Windows-desktop behavior
        ),
    ),
)
```

`version: 3` works on both branches; 4.10 migrates it on load.

## Troubleshooting

### "Unable to load hyprland plugin" notification

hyprshell 4.9.5 compiles its C++ plugin on every start and Hyprland config
reload. That build needs `gcc-c++` and Hyprland headers matching the running
compositor; Fedora 42 ships no matching `hyprland-devel`, so it fails and the
notification reappears each time. The service disables the plugin with
`HYPRSHELL_NO_USE_PLUGIN=1`, so hyprshell uses exec binds instead. Alt+Tab works
the same; the `bindrtni` binds close the switcher on Alt release.

### Switcher stays open after a quick Alt+Tab

Releasing Alt before the overlay gets keyboard focus used to leave the switcher
on screen. hyprshell 4.9.5 only closes on the GTK key-release event, so the
release went to the previously focused window instead. The release binds in
`hyprland.conf` cover that gap.

The flags on those binds are required: `bindrtni` = release, transparent,
non-consuming, ignore-mods. With plain `bindrn`, Hyprland skips the bind because
Alt is still in the modifier mask at release time, and shadows it while Alt is
held. This is the same bug fixed upstream in hyprshell 4.10.10 (issue #537),
which cannot run on Hyprland 0.55.

If it still sticks, close it manually:

```bash
hyprshell socat '"CloseSwitch"'
```

Re-run `./install.sh` to replace old `bindrn` lines with `bindrtni` ones.

If you have matching headers and want the plugin, drop the `Environment=` line
from `~/.config/systemd/user/hyprshell.service`, install `gcc-c++` plus that
`hyprland-devel`, and restart the service.

```bash
systemctl --user status hyprshell
journalctl --user -u hyprshell -n 30
hyprctl binds | grep hyprshell     # should list Alt+Tab, Alt+grave, Alt+Shift+Tab
hyprshell config explain
```

`hyprctl reload` removes runtime binds for a second or two; the daemon
re-adds them automatically.

## Uninstall

```bash
systemctl --user disable --now hyprshell
rm -f ~/.local/bin/hyprshell ~/.config/systemd/user/hyprshell.service
rm -rf ~/.config/hyprshell
# remove the "hyprshell Alt+Tab" block from ~/.config/hypr/hyprland.conf
```
