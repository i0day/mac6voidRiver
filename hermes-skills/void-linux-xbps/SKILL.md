---
name: void-linux-xbps
description: Void Linux xbps installs incl. third-party signed repos.
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [void-linux, xbps, packages, repos]
---

# Void Linux xbps package installation

## When to Use
Installing, upgrading, or troubleshooting packages on a Void Linux host (`/etc/os-release` ID=void), especially apps missing from the official repos (Brave, Chrome, Zen, Obsidian, other Chromium forks).

Void uses `xbps` (not apt/dpkg). Many popular GUI apps (Brave, Chrome, Zen, Obsidian) are NOT in official repos because Void avoids building heavy Chromium/Firefox forks. Prefer a signed community xbps repo over zip extraction or flatpak (flatpak/snap are often not installed).

## Adding a third-party signed repo (GitHub-releases-backed)

1. Verify the repo actually carries the package before configuring anything: fetch `x86_64-repodata` from the repo URL and grep for the package name+version. Community repos: `github.com/grvn/void-packages` (brave-browser, obsidian, zen-browser, vesktop), `repo.osowoso.org` (brave-browser-bin), `github.com/sofijacom/void-package`.
2. Register: write `repository=<url>/releases/latest/download/` to `/etc/xbps.d/<name>-repository.conf`, then `xbps-install -Sy`.
3. Key import often fails over HTTPS (`Failed to import pubkey ... Resource temporarily unavailable`). Fix: locate the repo's published key plist (e.g. `repo-keys/x86_64/<fingerprint>.plist` in the repo tree), download it from raw.githubusercontent.com, and `sudo cp` it to `/var/db/xbps/keys/<fingerprint>.plist`. The fingerprint is printed by xbps during `-Sy`. Then install normally — signature verification passes.

## Apps not in any repo: install from upstream GitHub release

If no xbps source exists, prefer the upstream `.deb` over tar.gz/AppImage and extract with `ar` + `zstd` into `/opt` — see `references/github-release-deb-install.md` for the full procedure (launcher wrapper with LD_LIBRARY_PATH, .desktop/icon install, Flutter AOT-layout verification). Especially for Flutter Linux apps: the tar.gz layout renders a black window (`Failed to create AOT data`); the deb layout works.

## Pitfalls

- **Void package binaries often differ from the common upstream names**: the `tesseract-ocr` package installs `/usr/bin/tesseract-ocr` (NOT `tesseract`), and the file manager is `Thunar` (capital T). Before writing or porting a script that calls a tool, check the real binary name with `xbps-query -lp <pkg> | grep bin` — a wrong name inside a script with `2>/dev/null` produces silent empty results that masquerade as application-level failure (e.g. an OCR script reporting "no text recognized" when the binary was simply not found).
- **Lightweight PDF stack**: `zathura` + `zathura-pdf-mupdf` (~28MB total) is the light working combo; the poppler backend (`zathura-pdf-poppler`) drags a 5MB+ chain including GnuPG, and the standalone mupdf GUI is 83MB — prefer mupdf-backend zathura. For markdown→PDF conversion `wkhtmltopdf --enable-local-file-access` (with a generated styled HTML intermediate) works well on Void.
- `pkill -f '<pattern>'` from a shell whose own command line contains the pattern kills the shell itself (exit -15 before the real target runs). Bracket a character (`brav[e]`) or run the kill and the follow-up command in separate terminal calls.
- Interrupted downloads leave `<pkg>.xbps.part` in `/var/cache/xbps` that can stall silently (file mtime frozen, socket dead). Diagnose with `stat -c '%y %s' <file>` twice a minute apart; if frozen, kill the xbps-install process and re-run `xbps-install` — it resumes/restarts cleanly.
- Long downloads: run `xbps-install` as a background terminal with notify=true instead of blocking foreground calls in wait loops; large Chromium forks are 150-200MB.
- Do not guess repo URLs from blog posts — confirm the repodata actually lists the package first; several listed community repos return HTML or 404 for repodata.

## Verification

After install: `xbps-query <pkg>` for version/homepage and `<binary> --version` for the real thing. `xbps-query -Rs <name>` lists available candidates across all configured repos.
