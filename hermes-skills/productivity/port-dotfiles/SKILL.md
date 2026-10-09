---
name: port-dotfiles
description: "Port Arch/Artix dotfiles to Debian/Mint: deps, paths, fixes."
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [dotfiles, linux, dwm, suckless, migration]
    category: productivity
---

# Port dotfiles across Linux distros

## When to Use

Installing a dotfiles/config repo written for one distro (esp. Arch/Artix suckless-style setups) onto a different distro (Debian/Ubuntu/Mint). Goal: adapt packages, paths, and session assumptions rather than blindly copying.

## Procedure

1. **Clone and inventory first** (`git clone --depth 1`, then `search_files target='files'` for the tree). Classify contents: WM (dwm/sway/i3), terminal (st), launcher (dmenu/rofi), shell config (zsh/omz), daemon scripts (bars, volume, brightness), system files (`etc/` — usually skip or adapt).
2. **Read the session-start files** (`.xinitrc`, `.zprofile`, `.xbindkeysrc`, WM `config.h`) before touching anything — they reveal every external binary and path assumption (browser name, polkit agent path, wallpaper command, IME, audio daemon).
3. **Map every referenced binary to a package** with `apt-cache policy <pkg>` (Debian family) and build an install list. Arch names often differ (`ttf-jetbrains-mono-nerd` → manual font install; `brillo` → `brightnessctl`; `polkit` → `policykit-1-gnome` on Mint).
4. **Install deps in one batched apt call** after `sudo -v` (see pitfalls on sudo/confirm timeouts).
5. **Compile suckless tools from the repo's own source** (dwm/st/dmenu ship their `config.h` — that IS the config). On Debian family the X11INC `/usr/X11R6/include` paths in `config.mk` work as-is once `-dev` packages are installed: libx11-dev libxinerama-dev libxkbcommon(-x11)-dev libxrandr-dev libfreetype-dev libxft-dev libxrender-dev libfontconfig1-dev libx11-xcb-dev libxcb-res0-dev libharfbuzz-dev (st with hb.c needs harfbuzz; dwm vanitygaps needs xcb-res).
6. **Fonts**: the configs usually name a Nerd Font; download the zip from ryanoasis/nerd-fonts releases, drop .ttf into `~/.local/share/fonts`, `fc-cache -f`, verify with `fc-list | grep -ci <name>`.
7. **AUR-only Python tools** (pywal etc.): `pipx install <tool>` (install pipx via apt first).
8. **Copy dotfiles to home**, `chmod +x` all scripts, then apply distro adaptations (see references/adaptations.md) with targeted patches, not wholesale rewrites.
9. **Verify before declaring done**: each binary referenced in `.xinitrc`/`config.h` resolves (`which`), fonts resolve (`fc-match "JetBrainsMono Nerd Font"`), and note explicitly which features are unavailable rather than silently dropping them.

## Pitfalls

- **Replacing a RUNNING binary (dwm etc.)**: `cp` fails with "Text file busy" — copy to `<binary>.new` then `sudo mv <binary>.new <binary>` (mv over a running executable is allowed; cp is not). The change takes effect on next session start, not the live process.
- **dwm font changes live in `config.h` `fonts[]`** (rebuild required). For a bar mixing Nerd Font icons with text, put **"JetBrainsMono Nerd Font Mono" (NFM)** first: the plain NF variant's icons are wider than a mono cell and bleed into adjacent words; NFM clamps icons to single-cell width. Put the CJK font second as fallback (CJK glyphs are exactly 2x the Latin cell width, so mixed tag names stay aligned). Desktop-wide font defaults are separate: `~/.Xresources` Xft.* (merge with `xrdb -merge`) + `~/.config/gtk-3.0/settings.ini` gtk-font-name; in a bare dwm session there is no xfsettingsd, so xfconf font keys don't exist — don't chase them.
- **Never auto-start a WM from `.zprofile`/`.zshenv` when the user runs a DE (XFCE/GNOME)** — comment out bare `startx` lines during the copy; a login shell inside the DE would try to spawn a nested X session. Same for `loadkeys`/`setxkbmap` lines that assume tty login.
- **polkit agent path differs by distro**: Artix/Arch uses `/usr/lib/polkit-gnome/...`, Debian/Mint installs to `/usr/lib/policykit-1-gnome/...`. Grep `.xinitrc` for the agent path and fix to the installed location.
- **picom flag drift**: `--experimental-backends` was removed in picom 10+; an old `.xinitrc` using it will fail to start the compositor. Strip the flag or pin config to the installed version's options.
- **Browser/launcher binaries named in configs are the author's, not the user's** — check `which` for each (librewolf, brave, etc.) and patch the `#define BROWSER` / xbindkeys entries to what's actually installed.
- **Run `apt-cache`/`apt` with `LC_ALL=C`** on localized systems — non-English locales break `grep 'Candidate:'` parsing (e.g. Chinese shows 候选 instead).
- **Long multi-step sudo work: call `sudo -v` once up front** to cache credentials; chained `sudo` commands can stall on a mid-chain password prompt and get auto-blocked on confirmation timeout.
- **Batch small file adaptations into one approval-friendly step** and preview them to the user first — a long `&&`-chained sed/cp command that dies on a confirmation timeout leaves the setup half-done and must be re-planned.
- **Skip the repo's `etc/` system files by default** (pam.d, runit services) — they belong to the author's init system (runit vs systemd) and can break the target machine; only copy with explicit user direction.

- **dunst config: filename and section name are version-trapped.** The file must be `~/.config/dunst/dunstrc` — any other name (e.g. `dunst.conf`) is silently ignored and defaults render. dunst 1.9.x requires the `[global]` section; `[dunst]` is 1.10+ syntax and in 1.9.x every key warns "Setting X is in the wrong section" and is dropped. Diagnose with `dunst -print` (wrap in `timeout` — the process keeps running after printing). No live reload in 1.9.x: apply changes with `pkill -x dunst` then relaunch. Kill ALL stale instances (double instances cause double-stacked notifications).
- **Porting rofi themes from another machine's repo**: grep the `.rasi` files for three porting bugs before first use — (1) self-import (`@import "<own-file>.rasi"` inside the same file = circular, delete the line), (2) the author's home path in `directory:` entries, (3) `terminal:` naming a terminal not installed here (e.g. footclient → st). Verify with `rofi -show drun` under a timeout (exit 124 = launched fine).
- **rofi-calc plugin on custom themes: the result line lives in the `message` widget.** If the theme's `mainbox { children: [...] }` omits `message`, calc results render invisibly (window shows input + mode-switcher + listview but no "Result: ..." line). Fix: add `message` to the children list. Also rofi-calc v2.1.0 (autotools, compatible with rofi 1.7.x; master needs newer rofi API) spawns `qalc -s update_exchange_rates 1days` which HANGS when offline — patch out the `-s update_exchange_rates` args in src/calc.c and rebuild. Needs pkgs: rofi-dev libqalculate-dev qalc autoconf automake libtool. Plugin installs to /usr/lib/x86_64-linux-gnu/rofi/calc.so.
- **xdotool type into rofi under fcitx**: symbols like `*` `+` get swallowed/mangled by the IM engine; use `xdotool key --clearmodifiers` per-keys or `setxkbmap -layout us` before typing test strings.
- **Upstream sync direction**: when pulling upstream dotfile updates after making local changes, `git diff main origin/main` per file and flag where upstream will clobber local tuning (e.g. a synced dunstrc reverting local font/size changes); offer to reverse-sync the live local config into the repo instead of accepting the overwrite. Do not push to the author's repo unless explicitly asked — keep adaptation commits local.
- **Mirroring a shallow clone to a NEW GitHub remote fails** with `remote unpack failed: index-pack failed / did not receive expected object` — GitHub rejects pushes from shallow repos (check `git rev-parse --is-shallow-repository`). Fix: `git fetch --unshallow origin` first, then push. Create the target repo via the API (`POST https://api.github.com/user/repos` with a Bearer token) rather than assuming `gh` CLI is installed. Feed the token to git via a temporary `GIT_ASKPASS` helper script that echoes the username / cats the token file per prompt word, then delete the helper — never embed the token in the remote URL (it persists in `.git/config`).

## References
- `references/adaptations.md` — concrete Arch/Artix → Debian/Mint mapping table and per-file adaptation checklist.
