# Arch/Artix → Debian/Ubuntu/Mint adaptation table

## Package name mapping

| Arch/Artix package | Debian/Mint equivalent | Note |
|---|---|---|
| `ttf-jetbrains-mono-nerd` | manual: nerd-fonts release zip → `~/.local/share/fonts` | not in apt |
| `brillo` | `brightnessctl` (scripts calling `brillo -G/-A/-U` need rewriting to `brightnessctl --get/--set`) | brillo absent from Ubuntu repos |
| `polkit` / polkit-gnome | `policykit-1-gnome` | agent at `/usr/lib/policykit-1-gnome/polkit-gnome-authentication-agent-1` |
| `pywal` | `pipx install pywal` (pipx from apt) | AUR-only otherwise |
| `st`/`dwm`/`dmenu` | compile from repo source | no apt equivalents with the author's patches |
| `librewolf` | `firefox` (or user's actual browser) | patch `#define BROWSER` in dwm config.h |
| `slock` | NOT in Ubuntu/Mint repos — substitute `betterlockscreen` or drop the lock keybinding | |
| `picom` (Arch git) | `picom` 10.x from apt | flag set differs, see below |

## Compile dependency set (suckless, Debian family)

`libx11-dev libxinerama-dev libxkbcommon-dev libxkbcommon-x11-dev libxrandr-dev libfreetype-dev libxft-dev libxrender-dev libfontconfig1-dev libx11-xcb-dev libxcb-res0-dev libharfbuzz-dev`

- dwm with vanitygaps/shiftview: needs xcb-res (`libxcb-res0-dev`).
- st with hb.c (harfbuzz shaping): needs `libharfbuzz-dev`.
- `/usr/X11R6/include` and `/usr/X11R6/lib` in stock `config.mk` are valid on Debian family — no edit needed once -dev packages installed.

## Per-file adaptation checklist

`.xinitrc`:
- [ ] polkit agent path → installed location
- [ ] `picom --experimental-backends` → drop flag (removed in picom 10+)
- [ ] `~/.fehbg` works only if `feh` installed and previously run; otherwise swap to `xwallpaper --zoom <img>`
- [ ] pipewire line: fine on Mint (pipewire default); skip if pulse-only

`.zprofile` / `.zshenv`:
- [ ] comment out bare `startx` if user runs a DE (nested-session hazard)
- [ ] `loadkeys .../larbs/ttymaps.kmap` — harmless if file missing (stderr suppressed), but remove for cleanliness
- [ ] `shortcuts` command (larbs) absent — the `[ ! -f ... ] && setsid shortcuts` line silently no-ops; fine

`.xbindkeysrc`:
- [ ] each launched app: `which` it; comment out missing ones (rhythmbox, virt-manager, brave, thunar variants)

WM `config.h`:
- [ ] `#define BROWSER` → installed browser
- [ ] `#define TERMINAL "st"` → valid only after st is compiled+installed
- [ ] audio keys calling `mpc`/`ncmpcpp` → install `mpc ncmpcpp` or comment bindings
- [ ] `slock` binding → substitute or comment (not packaged)
- [ ] `zzz`/`sudo -A` sleep binding → Artix runit-specific; use `systemctl suspend` or remove

## Verification commands

```bash
fc-match "JetBrainsMono Nerd Font"          # font resolves, not fallback
which dwm st dmenu wal sbar picom          # every .xinitrc binary resolves
grep -rhoE '"[a-z][a-z0-9-]+"' ~/.xinitrc | sort -u   # audit list of binaries to check
```
