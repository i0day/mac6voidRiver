---
name: tachiyomi-mihon-setup
version: 1.0.0
author: Hermes Agent
license: MIT
description: Set up Mihon/Tachiyomi readers and extension repos via adb.
metadata:
  hermes:
    tags: [android, adb, mihon, tachiyomi, manga]
---

# Tachiyomi → Mihon Migration & Extension Repos

## When to Use
Installing or migrating manga-reader apps in the Tachiyomi family (Mihon, Yokai, Komikku, Aniyomi) on an Android phone, adding extension repos, or diagnosing "extensions won't install / empty Browse tab".

## Key facts (verify versions fresh; ecosystem moves)
- Original Tachiyomi is dead (0.15.3, no updates, extensions incompatible). Mihon (github.com/mihonapp/mihon) is the maintained successor and upstream of most forks.
- **Package name changed**: old Tachiyomi = `eu.kanade.tachiyomi`; Mihon 0.20+ = `app.mihon`. They co-install side by side. Deep links/schemes must target the right package (`mihon://extension-store?url=...` resolves under `app.mihon`, not the old package).
- The live extension repo is Keiyoushi: `https://raw.githubusercontent.com/keiyoushi/extensions/repo/index.min.json` (or `index.pb` protobuf variant). Old tachiyomiorg repo URLs are dead.
- **Critical diagnostic**: if the Keiyoushi index returns only 1-2 stub entries named "Outdated App" / "Update to Mihon X+", the repo is fine — the *app* is too old for the current extension API. That stub list IS the correct response to an outdated client; don't hunt for a different repo.
- CN sources: filter Keiyoushi catalog by lang `zh` (Manhuafast, CopyManga, Mangabz etc.); extra CN repo: `https://raw.githubusercontent.com/LittleSurvival/copymanga-copy20/repo/index.min.json`.

## Procedure (adb-driven install)
1. Detect what's installed: `adb shell pm list packages | grep -iE "tachiyomi|mihon|komikku|aniyomi"` and check version: `dumpsys package <pkg> | grep versionName`.
2. Get latest Mihon APK from GitHub releases API (`api.github.com/repos/mihonapp/mihon/releases/latest`); pick `mihon-arm64-v8a` for modern phones. Verify download with `file` → "Android package (APK)".
3. Install without GUI: push to `/data/local/tmp` then `su -c 'pm install -r <apk>'` (or plain `adb install`). Success = "Success" line, not just exit 0.
4. Add the extension repo programmatically via deep link (opens confirm dialog on the phone — user taps confirm):
   `adb shell am start -a android.intent.action.VIEW -d "mihon://extension-store?url=https%3A%2F%2Fraw.githubusercontent.com%2Fkeiyoushi%2Fextensions%2Frepo%2Findex.pb" app.mihon`
   If "unable to resolve Intent", the scheme/package combo is wrong — check the installed package name first.
5. In-app: Browse → Extensions → refresh → install source → tap shield to **Trust** (extensions load nothing until trusted — tell the user).

## Migration (old Tachiyomi → Mihon)
- Backup first: old app Settings → Backup → Create backup (all boxes) → `.tachibk`; restore in new app.
- Downloaded chapters: rename internal-storage folder `Tachiyomi` → `Mihon` (matches new app's dir) — no re-download.
- Keep old app until user confirms library/progress migrated, then uninstall.

## Pitfalls
- Don't trust third-party APK sites — GitHub releases only (sideloaded readers are a malware magnet).
- `mihon://` deep link delivered to a running instance shows "intent delivered to top-most instance" — the confirm dialog appears on the phone screen; ask the user to look rather than retrying.
- Extensions require trust per install/update; a source showing zero results right after install is usually untrusted, not broken.
