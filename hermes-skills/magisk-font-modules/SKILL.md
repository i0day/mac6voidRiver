---
name: magisk-font-modules
description: Build flashable Magisk/OMF Android font modules.
version: 1.0.0
author: james
license: OFL-1.1
metadata:
  hermes:
    tags: [magisk, android, fonts, omf, adb]
    related_skills: []
---

# Magisk / OMF Font Modules

## When to Use
Use when packaging desktop TTF/OTF fonts into a flashable Magisk/KernelSU/APatch module that replaces Android system fonts (OMF framework), or transferring module zips to a rooted phone over wireless adb.

Build a flashable font module that replaces Android system fonts via the OMF (Oh My Font) framework, then transfer to the phone with wireless adb.

## Preferred build: simple override module (proven on Pixel 8 Pro / Magisk)

Do NOT use the OMF framework or khirendra03/Font-modules `create_module.sh` unless the user explicitly wants OMF features (line-spacing tweaks, family switching). The script's output is broken (its Template customize.sh expects a `PAYLOAD:`-appended tarball it never appends; `rename_fonts.sh` silently skips files lacking a weight word), and even a hand-rebuilt OMF module installed "Done" while leaving the module dir empty. The simple Magisk overlay works reliably:

```
moddir/
  module.prop                          # id, name, version, versionCode (date), author, description
  system/fonts/DroidSansMono.ttf       # replacement font renamed to the target system font
zip -r9q out.zip -C moddir .          # module.prop + system/ at zip root
```

- Monospace replacement = override `DroidSansMono.ttf` — Android's `monospace` family maps to that filename in /system/etc/fonts.xml, so a same-name file overlay just works (no fontxml patching needed).
- Sans replacement: on modern Pixels (fonts.xml uses Roboto-Regular.ttf variable + RobotoFlex), overriding Roboto-Regular.ttf alone misses Chinese UI text. Proven approach (Pixel 8 Pro, Android 17): include a patched `/system/etc/fonts.xml` in the module — replace the `<family name="sans-serif">` block and the `<family lang="zh-Hans">` block to point at your TTF (weights 400/500/700 entries), keep the serif fallbackFor font. Validate the patched XML with minidom before zipping; extract the original from the device via `adb shell su -c cat` (not head — binary truncation breaks parsing).
- No customize.sh / ohmyfont / data.xz needed.

If OMF is truly required, the known-good structure (ohmyfont engine + data.xz + config.cfg family switches, short-name table) is in `references/omf-structure.md` — but treat it as fallback, not default.

## Procedure

1. Pick the font file(s). For monospace-only replacement, rename to OMF short name before packaging: monospace Regular = `mr.ttf` (style letter + weight code; full table in reference).
2. Assemble the module dir (layout in reference):
   - `module.prop` — must include `omfversion=` (copy from a known-good module, e.g. `2025011401`); OMF reads it.
   - `ohmyfont` — copy verbatim from a known-good module zip (the real install engine; the repo Template's version is the broken older one).
   - `customize.sh` — the ~15-line shim that sources `$MODPATH/ohmyfont` and calls prep/config/install_font/src/rom/fontspoof/svc/finish (copy from known-good).
   - `config.cfg` — copy from known-good, then set family switches near top: `SANS=false SERF=false SRMO=false MONO=true` to replace only monospace (or true for each family you want).
   - `data.xz` — `tar -cJf data.xz -C <stage> fonts/` where stage/fonts/ holds the short-named TTFs. ohmyfont extracts this after the PAYLOAD line.
   - `META-INF/com/google/android/{update-binary,updater-script}` — copy from known-good.
3. Zip from inside the module dir: `zip -r9q out.zip .` — module.prop and META-INF at zip root.
4. Verify zip contents (`unzip -l`) before pushing: module.prop, ohmyfont, customize.sh, config.cfg, data.xz, META-INF present; fonts inside data.xz (`tar tJf`).
5. Install on device: `adb -s <dev> shell su -c 'magisk --install-module "/sdcard/Download/<file>.zip"'` — gives real error output, unlike the GUI. Then reboot.

## Wireless adb transfer

1. `adb pair <ip>:<pair-port> <6-digit-code>` (phone: Developer options → Wireless debugging → Pair device with pairing code).
2. `adb connect <ip>:<connect-port>` — the CONNECT port shown on the wireless-debugging main page is DIFFERENT from the pairing port; ask the user for it separately.
3. `adb push <zip> /sdcard/Download/` and verify with `adb shell ls -lh`.
4. Wireless adb ports rotate when debugging toggles off/on — a `device not found` mid-session means re-check the current connect port, not a broken setup.

## Critical pitfall: staged installs look empty before reboot

Magisk stages large modules in `/data/adb/modules_update/<id>/` and only merges into `/data/adb/modules/<id>/` at reboot. NEVER conclude an install failed by listing `/data/adb/modules/<id>` before rebooting — check `modules_update` instead. Verify success only after reboot:
- `ls -la /system/fonts/DroidSansMono.ttf` — size must equal the replacement font's size (Magisk bind-mounts over /system).
- `/data/adb/modules/<id>/` contains `system/`.

## Pitfalls

- Avoid `[ ]` in the final zip filename — some root-manager file pickers choke on brackets; use `_v1.522.zip` style.
- `update.json` OTA URLs in cloned repos point at the original author's paths; they are inert unless you push your module dir to that repo. Harmless, but don't promise OTA.
- A simple same-filename overlay does NOT break fontxml — Android resolves fonts by filename reference, so overriding `DroidSansMono.ttf` / `Roboto-Regular.ttf` is the correct mechanism.
- System font replacement NEVER reaches every app — set user expectations up front. Apps that bundle fonts in their APK and load via `Typeface.createFromAsset` (WeChat/QQ ship WeChatSans*, SF Pro) or render with their own engine (Firefox/Gecko, Chrome web content) ignore /system/etc/fonts.xml entirely. Diagnose per-app with `adb shell su -c "unzip -l <base.apk> | grep -iE '\.(ttf|otf|ttc)'"` before claiming the module failed. Browser apps are fixable in-app (Firefox: Settings → Fonts → set family name to the installed font's family); bundled-font apps are not safely fixable (integrity checks / ban risk). See `references/app-font-coverage.md`.
- Verify WHICH font is actually mounted, not just that a mount exists: pull the live file (`adb shell su -c "cat /system/fonts/X.ttf"`) and parse its TTF `name` table (nameIDs 1/4/6) to confirm the internal font name matches the intended replacement — a bind-mount of the wrong file looks identical in `mount` output.
- On Pixel/GMS devices also check `/product/etc/fonts_customization.xml`: it defines `google-sans*` families that apps can request explicitly, bypassing your patched `sans-serif`. Patching /system/etc/fonts.xml does not cover those named families.
