# ytermusic: install + cookie import from Firefox

ytermusic (ccgauche/ytermusic) authenticates to YouTube Music by replaying the user's browser session — it reads `~/.config/ytermusic/headers.txt` containing exactly two lines: `Cookie: ...` and `User-Agent: ...`. Missing/empty file → panic on startup (`Result::unwrap() ... headers.txt`).

## Install (Void Linux / any distro without a native pkg)
Prebuilt Linux binary from GitHub releases; no cargo needed:
- Releases are all **prerelease** — `releases/latest` 404s. Query `GET /repos/ccgauche/ytermusic/releases` and take the newest `x86_64-unknown-linux-gnu.tar.gz`.
- `install -m755 ytermusic ~/.local/bin/ytermusic` (ensure `~/.local/bin` on PATH).
- Verify with `ytermusic --files` — it prints log/headers/cache paths and only panics if headers.txt is absent.

## Cookie import from Firefox (the working recipe)
1. Have the user log into music.youtube.com in Firefox (or confirm an existing session).
2. Copy the profile's cookie DB (never query the locked live one): `cp <profile>/cookies.sqlite /tmp/x.sqlite`.
3. Extract: `select host,name,value from moz_cookies where host like '%youtube%'` — the needed set is SID, __Secure-1PSID, __Secure-3PSID, SAPISID, __Secure-1PAPISID, LOGIN_INFO, VISITOR_INFO1_LIVE etc. Join as `name=value; name=value`.
4. Write `Cookie: <joined>` and `User-Agent: <matching the browser>` to `~/.config/ytermusic/headers.txt`.
5. **Verify the login state before declaring success**: `curl -s -o /dev/null -w '%{http_code}' https://music.youtube.com/ -H "Cookie: ..." -H "User-Agent: ..."` must be 200, and the youtubei/v1 API (clientName WEB_REMIX) must return a responseContext.

## Firefox profile location gotcha
This user's Firefox keeps profiles in `~/.config/mozilla/firefox/` (not the classic `~/.mozilla/firefox/`). Read `profiles.ini` there and pick the Default/`IsRelative` path; check every profile's cookies.sqlite if unsure which one holds the YouTube session.

## Cookie lifecycle
Google session cookies expire (days–weeks). When ytermusic stops fetching data, re-login in Firefox and re-run the import — do not debug the player.

## UA note
No `general.useragent.override` in prefs means stock Firefox UA; a plain matching UA string works for the YouTube Music API — no need to extract the exact one.
