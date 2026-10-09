# OMF (Oh My Font) Module Structure

Reference layout distilled from known-good modules in khirendra03/Font-modules `Modules/` (HarmonyOS Sans, Inconsolata VF, MiSans). These install cleanly on Magisk (target example: Pixel 8 Pro, Magisk 30700).

## Zip layout (all at zip root)

```
module.prop
ohmyfont            # real install engine (~39KB shell+payload loader), copy verbatim from a known-good module
customize.sh        # ~15-line shim: . ${SH:=$MODPATH/ohmyfont}; prep; config; install_font; src; rom; fontspoof; svc; finish
config.cfg          # user-tunable config (family switches, line spacing, weights)
data.xz             # tar.xz containing fonts/ dir with OMF short-named TTFs
LICENSE
META-INF/com/google/android/update-binary
META-INF/com/google/android/updater-script   # content: #MAGISK
```

Note: the repo's `Template/` directory is the BROKEN variant (customize.sh expects an appended PAYLOAD tar that create_module.sh never appends, and its module.prop lacks `omfversion`). Always lift files from a working `Modules/<font>/` zip instead.

## module.prop required keys

```
id=<snake_case_id>
name=<Display Name>
version=<ver>
versionCode=<YYYYMMDD>
omfversion=2025011401      # REQUIRED by ohmyfont (grep ^omfversion=); copy from known-good
author=<you>
description=<one line>
```

## OMF short-name convention (style letter + weight code)

Style prefix:
- `u` upright sans, `i` italic sans, `c` condensed, `d` condensed-italic
- `m` monospace, `n` monospace italic
- `s` serif, `t` serif italic, `o` serif-monospace, `p` serif-monospace italic

Weight suffix:
- `t` Thin, `el` ExtraLight, `l` Light, `r` Regular, `m` Medium, `sb` SemiBold, `b` Bold, `eb` ExtraBold, `bl` Black

Examples: monospace Regular = `mr.ttf`; monospace Bold = `mb.ttf`; upright Regular = `ur.ttf`. A single-style static font only needs its one short name (e.g. `mr.ttf` for a mono-only module).

## config.cfg family switches

Insert near the top (after the LINE/OTL block) to control which families get replaced:

```
SANS = false
SERF = false
SRMO = false
MONO = true
```

Defaults if omitted: SANS/SERF/MONO/SRMO all true. For a mono-only module set the other three false. The `### <omfversion> ###` integrity marker at the bottom of config.cfg must stay intact (ohmyfont compares it to reset user config on version change).

## Building data.xz

```bash
mkdir -p stage/fonts
cp <font>.ttf stage/fonts/mr.ttf
tar -cJf data.xz -C stage fonts
```

ohmyfont does: `tail -n +<PAYLOAD line+1> $SH | tar xJf -` then `tar xf $MODPATH/*xz` — so data.xz lands in MODPATH and its `fonts/` becomes $FONTS.

## Verification before flashing

```bash
unzip -l out.zip                      # root-level files present
tar tJf data.xz                       # fonts/mr.ttf inside
adb shell su -c 'magisk --install-module "/sdcard/Download/out.zip"'   # real errors vs GUI
```
