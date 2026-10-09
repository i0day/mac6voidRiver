---
name: x11-desktop-theming
description: Style dwm bar fonts and dunst notification appearance.
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [dwm, dunst, fonts, x11, cjk]
---

# X11 Desktop Theming: dwm bar fonts, fontconfig, dunst notifications

Class: configuring fonts and notification appearance on a lightweight X11 desktop (dwm + status bar scripts + dunst), with Chinese/CJK fallback.

## When to Use

- Icon/text overlap, spacing, or sizing problems in the dwm status bar or in dunst brightness/volume popups.
- Changing font fallback chains (Latin + CJK + emoji) for dwm, or resizing/restyling notification boxes.

## Always-on rules

- **dunst config path is `~/.config/dunst/dunstrc`** — NOT `dunst.conf`, NOT `dunst.toml`. A wrong filename is silently ignored and you will be tuning defaults while believing your edits are live. Confirm the file exists (search_files target='files' under ~/.config/dunst) before editing.
- **dunst width/height range syntax is `(min, max)` — NOT `(min..max)`.** `width = (480..640)` fails with "Specify either a single value or two comma-separated values between parentheses" and the whole line silently falls back to default. Fix: `width = (480, 640)`.
- **Section name depends on dunst version.** dunst <1.10 (e.g. 1.9.2) requires `[global]`; `[dunst]` is 1.10+ syntax only. Wrong section → settings silently ignored with `WARNING: Setting X is in the wrong section` on stderr. Check `dunst --version` first.
- **Validate parsed config with `dunst -print`** — it echoes effective settings and emits the wrong-section warnings. Caveat: it may not exit cleanly; run it with a short timeout and kill it, grepping stderr for WARNING lines.
- **dunst 1.9.x has no `dunstctl reload`** — apply changes with `pkill -x dunst; sleep 1` then relaunch. Kill ALL instances first (multiple instances cause double-stacked notifications; check `pgrep -a dunst`).
- **Icon/geometry settings are global-only in dunst 1.9.x** — `icon_size`, `max_icon_size`, `width`, `height` do NOT work in a rule section (e.g. a `[qrshare]` match block); dunst warns "Setting icon_size in section X doesn't exist" / "height is in the wrong section" and silently keeps defaults. Rule sections only carry matching keys (appname/urgency/etc.) plus timeout/background/foreground. To make one app's notifications show big images: set `max_icon_size` + `height` + `shrink = true` in `[global]` (shrink keeps ordinary notifications compact despite the tall max) and give the special app its own rule just for `timeout`.
- **A dunst build without librsvg silently drops ALL `-i <icon>` SVG icons** — notification appears with no icon and no error. Check `ldd /usr/bin/dunst | grep -i rsvg`; if absent, do NOT fight the icon theme: put the icon inline in the notification TEXT as a Nerd Font glyph (e.g. `ICON_NIGHT=$'\uf186'` moon, `$'\uf185'` sun) — this is this user's preferred fix for day/night and similar OSD icons.
- **st terminal emoji rendering:** add `"Noto Color Emoji:pixelsize=15:antialias=true:autohint=true"` as a second entry in `font2[]` in st's `config.h` (st's harfbuzz backend picks it up), `make && sudo make install`. Verify by launching `st -e sh -c 'printf "🌙 test\n"'` and screenshotting — visible glyphs, not tofu.
- **Nerd Font variant choice prevents icon/text overlap in bars:** the `Nerd Font` (NF) variant has icons WIDER than a monospace cell — they bleed into adjacent text. Use `Nerd Font Mono` (NFM) where icons must occupy exactly one cell. `Nerd Font Propo` (NFP) is proportional, for non-terminal use.
- **dwm `fonts[]` fallback order sets the Latin advance width.** First font governs metrics; CJK fallback should be a CJK-mono font whose Han glyphs are exactly 2x the Latin cell (e.g. LXGW WenKai Mono Screen) so mixed 中文/latin tag and title strings stay aligned. Put the Latin+icon font first (JetBrainsMono Nerd Font Mono), CJK second, color emoji last.

## Workflow: resize/fix dunst notifications

1. `dunst --version` and `pgrep -a dunst` (note instance count).
2. Edit `~/.config/dunst/dunstrc` (create if absent — copy `templates/dunstrc-1.9.x`, a known-good base matching this user's fonts/palette). Key knobs: `font`, `width = (min, max)`, `height`, `progress_bar_height` (the brightness/volume bar), `progress_bar_min/max_width`, `horizontal_padding`, `text_icon_padding`, per-urgency `timeout`/colors.
3. Validate: `timeout 5 dunst -print 2>&1 | grep -i warning` — fix any wrong-section errors before restarting.
4. `pkill -x dunst; sleep 1`, relaunch dunst in background.
5. Test with a real payload including the progress hint: `notify-send -h int:value:65 "Brightness 亮度 65%"` — the `-h int:value:` hint is what renders the progress bar; test with the user's actual CJK+latin mix.
6. Screenshot-verify image legibility (QR codes especially): `DISPLAY=:0 import -window root shot.png` then vision_analyze the notification region. Render source images ~1.7x the displayed `max_icon_size` (e.g. `qrencode -s 14 -m 4` → ~518px shown at 300) so downscaling stays crisp; a QR generated at `-s 8` is unscannable at dunst's default ~48px icon. Note: some qrencode builds reject `-fg`/`-bg` — default black-on-white is already correct, don't pass them.

## Workflow: dwm bar font change

1. Locate the built config (`config.h` in the dwm source tree; check where the installed binary was built from — `ls` the scratch/source dir before assuming `~/.config/dwm`).
2. Edit `static char *fonts[]` per the fallback rule above.
3. `make -j4` in the source dir; installing to `/usr/local/bin` needs sudo (write to scratch then `sudo cp`; the password prompt gets swallowed by pipes/heredocs).
4. Change takes effect only after logging out of the X session.

## Workflow: status-bar (xsetroot) spacing fixes

1. The bar string lives in the sbar script (`~/.local/bin/sbar`, rendered via `xsetroot -name`). Spacing/gap edits need NO dwm rebuild — just restart the script (kill old PID, relaunch in background).
2. Icon↔text crowding inside a segment is fixed by widening the space between the icon and the value in the script (e.g. `"${ICON}  ${POWER}%"`), NOT by adding gaps between `[segments]` — when the user says icon and text are "too close", they mean inside the segment; confirm before widening inter-segment gaps.
3. Screenshot-verify before/after: `maim out.png` (Void has `maim`, not ImageMagick `import`; crop via `maim -g <WxH+X+Y>`) then vision_analyze the crop. dwm bar geometry from `xwininfo -root -tree`.

## Workflow: dwm color theming (borders, bar, fg/bg)

1. Find the TRUE build tree first: `cmp <repo>/dwm/dwm /usr/local/bin/dwm` — the tree whose built binary byte-matches the live one is the source of truth (dotfile repos often hold stale config.h copies; the live binary may build from a different clone). Edit config.h there, and sync the change back to the canonical repo copy.
2. **Check the `ResourcePref resources[]` block in config.h BEFORE editing color constants — xrdb mappings silently override compiled values at every startup.** A `{ "color0", STRING, &normbgcolor }` line means pywal/xrdb colors win no matter what you compile. To make compiled colors authoritative, delete the color STRING entries (keep INTEGER/FLOAT geometry prefs). Symptom of this trap: config.h edits + rebuild + restart show zero visual change.
3. Live dwm/dmenu/st build tree is `~/artix/{dwm,dmenu,st}` — binaries install to `/usr/local/bin`; the `~/mac6void` dotfiles repo holds only config.h mirrors, so after building, copy the edited config.h back into `~/mac6void/<app>/config.h` to keep the repo synced. Standing palette (current): accent = pale blue `#CBE4FD` used for dwm selected tag bg/border, dmenu SchemeSel bg, st cursor, and ANSI blue (wal color4/color12 manually overridden); bar bg `#101418`-ish dark, dmenu sel fg switched to dark `#101418` on the light accent (never white-on-pale-blue). Palette history: teal #0f9fae → #CBE4FD; always re-derive from current `~/.cache/wal/colors` / config.h rather than hardcoding. High contrast white-on-color is the constant goal across both the old dark scheme and this light one — low-contrast grays read as '费劲' (straining). When the user asks to 'match this screenshot', re-derive exact values from the image (see photo-palette workflow) rather than reusing stale constants.
4. Replace the live binary despite ETXTBSY: `cp new /usr/local/bin/dwm` fails 'Text file busy' while dwm runs. Fix: `sudo mv /usr/local/bin/dwm /usr/local/bin/dwm.old && sudo cp new /usr/local/bin/dwm` — mv unlinks the running inode, cp then creates a fresh file. Verify with `strings /usr/local/bin/dwm | grep <new-token>`.
5. Add a restart hotkey so the user can apply new colors without logout: `{ MODKEY|ControlMask, XK_e, spawn, SHCMD("pkill -x dwm") }` — with the tty1 autologin+auto-startx chain, killing dwm cascades: startx exits → getty re-logins → X + .xinitrc restart with the new binary. Check the key is free first (`grep XK_e config.h`); Mod+Shift+E was taken by abook, Mod+Ctrl+E was free. Warn the user it closes all windows.
6. **Never change fcitx5 theme colors unless the user explicitly asks for the IME.** User has twice cut off work touching fcitx5 palette during general recolor requests ('輸入法不用改') — even when dwm config comments claim colors are 'synced with fcitx5', treat fcitx5's theme.conf as out of scope. When the light accent lands, only dwm/dmenu/st/nvim/wal files change. Fcitx5 candidate-window contrast pairs (for when it IS requested): highlight = mid/saturated bg + pure white text (never gray-on-gray); the theme generator `~/.local/bin/fcitx5-waltheme` carries FIXED palette constants (BG/SEL/BORDER hardcoded, no longer reads wal's C[0]) so it stays in sync with the dwm scheme regardless of wal theme — change the constants there, regenerate (regenerating ALSO auto-syncs classicui.conf Theme=wal), then `fcitx5-remote -e; sleep 2; fcitx5 -d` (NEVER pkill from agent terminal) for instant effect (no dwm restart needed for the IME window). Always re-grep the generator after editing it and diff the generated `~/.local/share/fcitx5/themes/wal/theme.conf` to confirm the new hexes landed.

## Workflow: recolor an ANSI slot (e.g. 'blue') across all wal-themed terminals

nvim's wal.vim colorscheme hardcodes `ctermfg=4` — the visible blue comes from the *terminal's* ANSI 16, so editing nvim/wal.vim is useless. Change the ANSI slot at its sources, all four, then merge:
1. `~/.cache/wal/schemes/<scheme>.json` — keys are `color4`/`color12` (NOT bare `"4"`; adding `"4"` does nothing). Edit the `colors` dict via python json, keep other keys intact.
2. `~/.cache/wal/colors` — plain 16-line file; line 5 = color4, line 13 = color12 (`sed -i '5s/.*/#HEX/;13s/.*/#HEX/'`).
3. `~/.cache/wal/colors.Xresources` — replace hex on `*.color4:` and `*color4:` (and color12) lines.
4. `xrdb -merge ~/.cache/wal/colors.Xresources` then `xrdb -query | grep -i color4` to verify.
New st and nvim windows pick it up at launch (both read xrdb color0-15 via ResourcePref / ANSI). Caveat: re-running `wal -i <new img>` regenerates all of these and wipes the override — user must re-apply or use a fixed scheme.

## Workflow: find a wallpaper matching a target hex in the user's gallery

1. Collect candidates: `find ~/Pictures ... -iname '*.jpg' -o -iname '*.png'` (user's gallery lives in `~/Pictures`, incl. a cloned `mint-backgrounds` repo with 600+ official wallpapers).
2. Rank by average color with ffmpeg (no ImageMagick on this box): per image, `ffmpeg -i IMG -vf scale=8:8 -frames:v 1 -f rawvideo -pix_fmt rgb24 -` → average the RGB bytes → Euclidean distance to target. 672 images ≈ 2 min in execute_code.
3. Average color is only a first filter — grey/off-white tops the list for any pale target. Vision-check the top ~5 candidates and judge which has a real large area of the target tone; discard photos whose dominant hue differs (teal seas, pink-marble) despite small close regions.
4. If nothing matches, report the closest real ones and offer a generated solid/gradient image at the exact hex: `ffmpeg -f lavfi -i "color=c=0xHEX:s=2560x1600" -frames:v 1 out.png` (or `gradients=` filter for 2-3 tone). Only after showing the gallery verdict — user preference is 'look in my gallery first, don't just generate'.

## Workflow: derive exact palette from a photo of the screen

Phone photos of a laptop screen defeat vision models on color (warm bezel cast, tilt, glare) — sample pixels programmatically instead.

1. `python3 -m pip install pillow` if needed (no ImageMagick on this box).
2. Locate the screen area: the laptop bezel is warm/bright (`r > b + 20 and r > 120`); scan columns for the transition to cooler pixels to find the screen's top edge per column — the photo is tilted, so fit a slope (e.g. `top(x) = 158 + 0.021*x`) instead of one fixed y.
3. Sample each UI region (bar strip, border lines, candidate bar) as a median over a band, and a quantized histogram (`r//16*16`) to separate bg vs text vs highlight colors. Border lines show as a 2-4px run of a distinct hex between dark regions.
4. White-balance correction: compare sampled values against the bezel (known near-white in reality). A bar reading `#84ace0`-ish under a warm cast is a pale blue around `#a8d0f0` on screen — round to a clean palette rather than copying photo pixels verbatim.
5. Cross-check with vision_analyze on tight crops (bar-left, bar-right, candidate row) for STRUCTURE (which tag is selected, where borders are) — trust PIL for COLOR, vision for layout.

## Pitfalls

- **pywal16 on this box has NO ImageMagick** — plain `wal -i img` fails with "Imagemagick wasn't found". Use `wal --backend colorthief` (pip install --user colorthief). It does NOT set the wallpaper (that's feh's job: `DISPLAY=:0 feh --bg-scale <img>` writes ~/.fehbg, which .xinitrc replays). st needs NO rebuild for palette changes — its `ResourcePref resources[]` loads color0-15/background/foreground/cursorColor from xrdb at every launch, so `wal` (which pushes xrdb) + new st window = themed. dwm deliberately REMOVED its color xrdb mappings (comment in config.h), so dwm theme changes require the rebuild+mv-into-place dance above.
- **The patch tool can report success with a correct-looking diff while the file on disk is unchanged** — observed on a script in `~/.local/bin`. After patching any file whose change matters, verify with `grep`/`stat` (mtime!) before proceeding; if unchanged, rewrite via a python read-modify-write instead of retrying the same patch.
- **The patch tool's fuzzy matching silently destroys Nerd Font/PUA glyphs** — a replace on a line containing private-use icon chars can swap the icons for plain spaces while reporting success. After ANY patch touching a line with icon glyphs, verify bytes with `od -c`; restore lost icons with explicit escapes (`printf '\uf028  '` for speaker, etc.) via a python rewrite, not another fuzzy patch.
- **dunst 「通知不显示」先查暂停态**：进程存活（`pgrep -a dunst`）但弹窗消失，几乎总是勿扰暂停——`dunstctl is-paused` 确认后 `dunstctl set-paused false` 恢复，再 `dunstify` 测试并读 `dunstctl history` 验证送达（history 是 aa{sv} 嵌套结构，每条 notification 是含单 dict 的 list，解析时先取 `[0]`）。误判为崩溃而重启 dunst 会掩盖真正的暂停来源（本机 Ctrl+Alt+s dunst-quiet 热键）。
- Font fallback order is a user taste decision: CJK-first makes the CJK font render Latin text too (different Latin look); Latin-first keeps JetBrains latin with WenKai only for CJK. Present the tradeoff rather than assuming.
- Verify a config change actually loaded before iterating on size: if the user reports "nothing changed", suspect filename/section-name mismatch first, not the values. `dunst -print` settles it in one shot.
- Font size doubling (e.g. 16→32pt) inside a fixed-width box causes wrapping; raise `height` proportionally (~200px at 32pt) or lines clip.
- `dunst -print` hanging: it can stay attached; always wrap in `timeout`.
