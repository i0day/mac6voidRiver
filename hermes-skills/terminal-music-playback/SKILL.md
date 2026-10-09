---
name: terminal-music-playback
description: Terminal YouTube music via ytfzf+mpv (no login) or ytermusic (logged-in library).
version: 1.0.0
author: Hermes
license: MIT
metadata:
  hermes:
    tags: [music, youtube, terminal, mpv, ytfzf]
---

# Terminal music playback (free, no subscription)

## When to Use
User asks to play music from YouTube or another online source in the terminal, especially without a paid subscription.

## Two stacks, pick by need
- **No-login browsing**: `ytfzf` (search + fzf picker) → `yt-dlp` (must be recent) → `mpv` (audio out via PipeWire).
- **User's own YT Music library/playlists (logged-in)**: `ytermusic` (Rust TUI, ccgauche/ytermusic) — self-contained player (bundled Symphonia decoder, no mpv needed) driven by browser cookies. See `references/ytermusic-cookie-import.md` for install + cookie import from Firefox.

- Install: `sudo apt install ytfzf`; keep yt-dlp fresh via `pipx install yt-dlp` (PATH must put `~/.local/bin` first so pipx's newer yt-dlp wins over apt's stale one).
- Void Linux: ytfzf is NOT in the repos. Install from source: `git clone --depth 1 https://github.com/pystardust/ytfzf.git && sudo make install PREFIX=/usr/local && sudo make addons PREFIX=/usr/local` (addons target is `addons`, not `install-addons`). Deps via xbps: `fzf jq` (mpv usually present). ytfzf has no `-v` flag; first run fetches invidious instance list.
- Daily use:
  - `ytfzf -m <query>` — search, fzf list, Enter plays audio-only.
  - `ytfzf -m -a <query>` — auto-play first result (no picker; good for scripted verification).
  - `ytfzf -m -r <query>` — random pick.
  - fzf keys: `Ctrl-n`/`Ctrl-p` page, `Tab` multi-select queue, `q` quit. Playback control = mpv (space pause, `>`/`<` seek).
- Direct mpv one-liner (no ytfzf): `mpv --no-video "ytdl://ytsearch1:<query>"` — the `ytdl://` prefix is required or mpv treats the string as a filename.
- Verify sound actually plays before declaring success: run with `--length=8` and check mpv shows `A: 00:00:0x / ...` progress, or `wpctl status` shows an mpv client.

## Pitfalls
- Do NOT use mps-youtube (mpsyt): its pafy backend is dead (requires youtube-dl) and `PAFY_BACKEND=internal` still fails search silently. ytfzf is the maintained replacement.
- Stale yt-dlp breaks YouTube signature extraction — symptoms: `Precondition check failed`, `Signature extraction failed`, `Only images are available`, `Requested format is not available`. Fix is upgrading yt-dlp (pipx), not changing format flags or the player.
- Spotify terminal clients (spotify-tui, cmus spotify, spotifyd) all require Premium — free accounts have no playback API. For free listening, YouTube is the de-facto library.
- ytermusic (Rust TUI) is broken: its ANDROID-client stream URLs get 403 Forbidden from googlevideo (2026-10). Do not recommend; use ytfzf instead.
- `ytfzf -S` takes a sed address, not a query — use `-a`/`-r` for non-interactive selection.
