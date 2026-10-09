---
name: jellyfin-terminal-playback
description: Play Jellyfin in the terminal with fin, direct-play only.
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [jellyfin, media, terminal, mpv, tui]
---

# Jellyfin playback in the terminal (fin)

## When to Use
User wants to browse or play their Jellyfin server (movies/TV) from the terminal, or asks about terminal Jellyfin clients.

## Standing user preferences (embed, do not re-ask)
- Play the ORIGINAL file direct (fin's default mpv direct-play). NEVER build transcoding/HLS-transcode paths — user explicitly rejected transcoding.
- Play one file at a time via fin's native flow; do NOT hand-roll playlist scripts (a custom jfplay m3u generator was built and deleted at user request).
- Never accept or type the Jellyfin password in chat — `fin login <url> -u <user>` prompts hidden in the user's own terminal; have the user run it themselves.

## Install (Void Linux — not in repos)
Prebuilt tarball from GitHub releases (tsirysndr/fin), verify sha256 shipped alongside, install to `~/.local/bin/fin`. Needs mpv at runtime. Config lands in `~/.config/fin/config.toml` (holds url/user_id/access_token after login — readable for API calls, never echo the token).

## Key behavior: leaf vs container (the #1 gotcha)
`fin play "<query>"` only plays the first *playable leaf* (a specific episode, movie, or track). A series/show name matches a *container* → "nothing matched", even though `fin search "<show>"` shows it. Do not conclude the item is missing or retry variants of the query.
- Whole series / drill-in: use the TUI — `fin` → `2` Videos → `/` search → `Enter` enters the series episode list → `Enter` plays one episode; `x` queues the whole container; `<`/`>` prev/next; `s` stop; `q` quit.
- Single episode from CLI: query the concrete episode title (e.g. `fin play "S01E01"` or the episode name), not the show name.

## Renderer
Default renderer is local mpv (direct play). Chromecast/UPnP available via `--chromecast`/`--upnp` and `fin devices`. fin also advertises itself as a UPnP render target by default (`--no-media-renderer` to disable).

## Pitfalls
- Jellyfin API with the saved token: use `recursive=true` on `/Items` searches or you only get top-level folders back; `userId` param needed on `/Shows/<id>/Episodes`.
- In bash scripts `UID` is readonly — name such vars differently (e.g. `JFUID`).
- `master.m3u8?...&Static=true` can 400 on libraries whose sources aren't HLS-packaged; another reason to stay on fin's native playback instead of hand-built stream URLs.
- Other clients for context: jtui (Go, video-focused, Quick Connect login) and jellyfin-tui (music-only) exist; user chose fin.
