---
name: x11-keyboard-productivity
version: 1.0.0
author: Hermes Agent
license: MIT
description: Add keyboard-first convenience hotkeys on dwm/xbindkeys.
metadata:
  hermes:
    tags: [x11, dwm, xbindkeys, cliphist, dunst, keyboard]
---

# X11 keyboard-first convenience shortcuts (dwm + xbindkeys)

Class: adding/managing shortcut-driven utilities that replace mouse clicks on this user's dwm desktop — clipboard history, notification control, search, paste-as-typing, radio toggles — including the daemon wiring each one needs.

## When to Use

- User wants fewer mouse clicks: new Alt+Ctrl / Super+Ctrl hotkeys for clipboard, notifications, WiFi, screenshots, search.
- Wiring a clipboard-history stack (cliphist), dunst do-not-disturb, or rfkill toggles into an existing xbindkeys/dwm setup.

## Always-on rules

- **Check key collisions in BOTH binding layers before choosing a hotkey**: dwm's `config.h` (`grep XK_ dwm/config.h` in the dotfiles clone) AND `~/.xbindkeysrc`. dwm grabs first for its combos; xbindkeys grabs first for its own. Also avoid focused-app claims (Firefox devtools, terminal shells).
- **Bind every convenience hotkey with the `Release` modifier** (`Release + Mod1 + control + c`) so one physical press = one fire; press-bindings multiply on auto-repeat. (Full mechanics in fcitx5-input-method skill.)
- **Every OSD/notification script must force the systemd user bus** — never trust inherited env (LightDM sessions can carry a dead `/tmp/dbus-*` address; dunstify then fails SILENTLY, the action works but no popup). Scalable fix: PATH shims in `~/.local/bin/` (ahead of /usr/bin):
  ```sh
  #!/bin/sh
  export DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/bus"
  exec /usr/bin/dunstify "$@"
  ```
  Same for notify-send. One shim pair covers every current and future caller; harmless once the session bus is fixed.
- **New scripts live in `~/.local/bin/`, chmod +x, and get copied to the dotfiles repo `usr/bin/`** (repo convention) with a commit pushed to the private mirror only. Live config is source of truth; repo drifts silently.
- **Verify each new hotkey by running the script directly first** (state check before/after: `dunstctl is-paused`, `cliphist list`, `xinput list-props`, `rfkill list`). xdotool CANNOT verify Release-bound grabs — tell the user to press by hand.

## Recipes (all installed on this machine, patterns reusable)

- **Clipboard history (cliphist)**: `apt install cliphist`. Version 0.4 has NO `watch` subcommand — the watcher is a systemd user service looping the classic xclip-owner trick:
  ```
  ExecStart=/usr/bin/sh -c 'while :; do xclip -selection clipboard -out | cliphist store || exit 1; done'
  Environment=DISPLAY=:0
  ```
  Each clipboard READ feeds one store (dedupe built-in, 750-item cap). `xclip -loops 0` exits immediately — do NOT use it for a watcher. Selector: `cliphist list | dmenu -i -l 15` then `printf '%s\n' "$sel" | cliphist decode | xclip -selection clipboard` (pipe the selection line into decode; herestring `<<<` breaks in sh).
- **Do-not-disturb**: `dunstctl set-paused true/false` (toggle on current `dunstctl is-paused`). Clear all: `dunstctl close-all`. Both are instant, no config needed, dunst ≥1.6.
- **Paste-as-typing** (forms that block Ctrl+V or need per-char events): `xdotool type --clearmodifiers --delay 15 -- "$text"` after a 1.5 s grace period + heads-up notification (user needs time to focus the field).
- **Selection→search**: read X `primary` selection first (mouse-selected text), fall back to clipboard, URL-encode with `urllib.parse.quote`, then open via **ff-open** (next recipe) — NOT `xdg-open`, which pops "Firefox is already running" when Firefox's remote/lock state is bad. Take only the first line — multiline selections explode the URL.
- **Open URL in running Firefox (ff-open)**: Firefox's own remote mechanism (`firefox -new-tab`, xdg-open forwarding) hangs or pops "already running" when its remote/parent.lock state is broken (typical after a session-bus fix — the running Firefox still carries the dead bus). Bypass entirely with xdotool window driving: `xdotool search --class firefox`, pick the **largest-area window** (small "Close tab"/popup windows also match the class), `windowactivate --sync` → `key ctrl+t` → `type <url>` → `Return`; if no window exists, launch a fresh instance. Verify by window-title change (`wmctrl -l`), never by exit code — backgrounding swallows failures.
- **WiFi kill switch**: `sudo -n rfkill block/unblock wlan` (test `-n` first; fall back to `pkexec`). Parse `rfkill list wlan` for `Soft blocked:`. Same pattern for bluetooth — but first confirm the device actually appears in `rfkill list`.

## Auditing an existing binding layer (before adding anything)

- **Grep every `spawn` target out of dwm config.h and check each binary exists** (`command -v`). Ported dotfiles commonly bind programs never installed on the new machine (mail clients, downloaders, wrappers) — the hotkey then "does nothing" and reads as a broken binding. Report the binding↔install mismatch table and let the user choose: install or comment out.
- **Debian/Mint renamed the modern CLI replacements**: `fd` installs as `fdfind`, `bat` as `batcat`. Symlink them into `~/.local/bin/` (`ln -sf $(which fdfind) ~/.local/bin/fd`) or muscle-memory and scripts break. Also check PATH shadowing (a user tool dir earlier in PATH can hide the apt binary).
- **System-level daemon times out but user-level works**: some packaged daemons (e.g. the transmission-daemon systemd unit) hang at start on minimal desktops. Disable the system unit (`sudo systemctl disable --now`) to stop the conflict and run the daemon as the user — hotkey scripts that self-start the daemon (`pgrep || daemon`) then work unchanged.

## Pitfalls

- **MacBook touchpad tap-to-click lives on the `bcm5974` pointer device, NOT the composite `Apple ... Keyboard / Trackpad` device** — the composite is the keyboard half and has no `libinput Tapping Enabled` property, so setting it there silently does nothing. Find the right device: `xinput list --id-only bcm5974`. libinput defaults Tapping OFF, so add `touchpad-toggle on` to session startup or every login reverts to press-only.
- `xinput list-device-props` is not a real command (silent empty) — it's `xinput list-props`. Parse with `awk -F'\t' '/Tapping Enabled \(/ && !/Default/'` to avoid matching the `...Default` twin property.
- **`xbindkeys_show` needs Tk (`wish`)** — with only tclsh installed the hotkey fires but no window appears, looking like a dead binding. `apt install tk` or drop the binding.
- xbindkeys reads `~/.xbindkeysrc` only at start: after editing, `pkill -x xbindkeys; sleep 1; xbindkeys` (plain SIGHUP does not reload).
- dwm keybinding changes need `make -j2 && sudo make install` in the dwm source dir AND a dwm restart (no restart binding in this config — relogin); the running binary's actual bindings are readable via `strings /proc/<dwm-pid>/exe | grep <cmd>` — check that before assuming config.h matches what's live.
- **This machine's Bluetooth is dead at firmware level**: the combo chip enumerates as `05ac:f007 "Broadcom Bluetooth Download Device"` and never transitions to a working adapter — no matching firmware in linux-firmware or the broadcom-bt-firmware community repo, `btusb` loads but claims nothing, `rfkill` shows no bluetooth device. Do not chase this software-side; a USB BT dongle is the practical route. The bt-toggle script is installed for when a working adapter appears.
- `dunstctl history` returns nested `data: [[{field-dict}]]` — index `item[0]` before reading fields; the parsed entry count can lag `dunstctl count history` (entries expire between calls), so when a parser and the counter disagree, grep the raw JSON for `"data" : "..."` instead.
- **Firefox remote hang masquerading as success**: `firefox -new-tab &` returns exit 0 while the real process hangs or pops a dialog — never background-and-trust; drive the window via ff-open and confirm via `wmctrl -l` title change.
