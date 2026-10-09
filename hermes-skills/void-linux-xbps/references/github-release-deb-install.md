# Installing upstream GitHub-release apps on Void (no xbps package)

When `xbps-query -Rs` finds nothing and no community repo carries the app, install from the upstream GitHub release. Prefer the **.deb** over tar.gz/AppImage: the deb has the correct on-disk layout and ships the .desktop file and icons. This is critical for Flutter Linux apps (LocalSend and friends) — their tar.gz layout (`bin/`-style split) breaks the engine while the deb layout works.

## Procedure

1. Latest release + assets: `curl -s https://api.github.com/repos/<owner>/<repo>/releases/latest` and list `assets[].name`.
2. Download the `linux-x86-64.deb` (not the tar.gz). Void has no dpkg, but `ar` does:
   ```
   cd /tmp && mkdir -p appdeb
   ar p <app>.deb data.tar.zst | zstd -d | tar -x -C appdeb
   ```
   (`zstd` itself: `sudo xbps-install -y zstd` if missing.)
3. App payload lands in `appdeb/opt/<app>/` — copy to `/opt`: `sudo cp -r appdeb/opt/<app> /opt/<app>`.
4. Typical Flutter layout inside: `data/` (icudtl.dat, flutter_assets), `lib/` (libapp.so + plugin .so files), and the launcher binary at the top. Keep this structure exactly — the binary locates `data/` relative to itself and dlopens from `lib/`.
5. Launcher wrapper in `~/.local/bin/<app>`:
   ```
   #!/bin/sh
   exec env LD_LIBRARY_PATH="/opt/<app>/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" /opt/<app>/<binary> "$@"
   ```
6. Missing system libs: `ldd /opt/<app>/<binary> | grep 'not found'` and install each via xbps (Flutter tray apps typically need `libayatana-appindicator`, which pulls ayatana-ido, libayatana-indicator, libdbusmenu-glib, libdbusmenu-gtk3).
7. Menu entry + icon: copy the deb's `usr/share/applications/<app>.desktop` to `~/.local/share/applications/`, patch `Exec=` to the wrapper's absolute path, validate with `desktop-file-validate` (hints are OK, errors are not). Copy icons to `~/.local/share/icons/hicolor/<size>/apps/`.

## Verification

Launch the wrapper as a background terminal, then poll the process log: a healthy Flutter app shows no `Failed to create AOT data` / `Invalid ELF path` lines and (for network apps) logs its discovered interfaces/addresses. A window that renders all-black with those AOT errors means the payload layout is wrong — redo with the deb, not the tar.gz.

Benign noise to ignore: `org.freedesktop.NetworkManager ... ServiceUnknown` from connectivity_plus on hosts without NM — does not affect functionality.
