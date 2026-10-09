---
name: password-vault-migration
description: Use when migrating browser/app passwords into Bitwarden.
version: 1.0.0
license: MIT
metadata:
  hermes:
    tags: [bitwarden, vaultwarden, firefox, chrome, android, adb, frida, csv]
---

# Password Vault Migration

Migrate saved logins between browsers, Android credential stores, and Bitwarden (hosted or Vaultwarden).

## When to Use

- Asked to export saved passwords from Chrome/Firefox (desktop or Android) and import into Bitwarden or another manager.
- Diagnosing `bw` CLI login failures against a self-hosted Vaultwarden.
- Root-level forensic extraction of browser credential DBs from an Android device over adb.

## Golden rule: prefer official export over forensic extraction

On modern Android, browser passwords are hardware-keystore-bound and NOT decryptable offline, even with root. Try the official export path first; it is faster and reliable:

- **Chrome on Android** → passwords live in Google Password Manager (GMS), not a local `Login Data` file. Export at `passwords.google.com` (CSV), or use Bitwarden app's built-in "Import from Google Password Manager" (system-level vault-to-vault transfer).
- **Firefox on Android (Fenix)** → `logins2.sqlite` + `key4.db` are useless offline: Fenix keeps its SDR key in the Android Keystore (`shared_prefs/loginsCrypto.xml` canary proves it; `nssPrivate` table is empty). Export inside the app: Settings → Passwords → ⋮ → Export. Desktop Firefox: `about:logins` → ⋮ → Export to CSV (needs `signon.export.enabled=true` in about:config if hidden).
- **Desktop Chrome** is the exception — `Login Data` + DPAPI/keychain extraction works normally.

Root-only runtime extraction (hook the keystore key with Frida) is a last resort; see references/android-root-extraction.md.

## CSV conversion: Google/Firefox export → Bitwarden import

Bitwarden CSV columns: `folder,favorite,login_uri,login_username,login_password,notes`.
Map `url→login_uri`, `username→login_username`, `password→login_password`; put realm/httpRealm in notes. **Drop `chrome://` internal entries** (e.g. Firefox Accounts sync keys) — they are not logins. Parse with a real CSV reader (fields contain commas/quotes), not string splitting.

## Bitwarden CLI + Vaultwarden: version-match is mandatory

CLI and server versions must match closely or auth fails in misleading ways (new CLI → key-backfill 404; old CLI → "Username or password is incorrect" even with a correct password). Workflow:
1. Read server version: `curl -s https://<vault>/api/config` → `version` field.
2. `npm install -g @bitwarden/cli@<matching-version>` (check `npm view @bitwarden/cli versions`).
3. **`bw config server https://<vault>/` BEFORE `bw login`** — skipping this makes login fail with a misleading "Invalid master password / account created on vault.bitwarden.com" even with correct credentials. Then `bw login <email> --passwordenv BW_PASSWORD` (env var, never inline password).
4. If status is inconsistent (login says 'already logged in' but unlock says 'not logged in'), delete `~/.config/Bitwarden CLI/data.json` and re-login with the matched CLI.
5. Import: `bw import bitwardencsv file.csv` after unlock (format is a positional arg — there is no `--format` flag).
6. Verify by reading back: `bw sync` then `bw list items --search <term>` and match the entry count/names against the source CSV before telling the user the import succeeded.

When the server rejects credentials, verify server-side independently before doubting the user: `POST <vault>/identity/accounts/prelogin` with `{"email":...}` returning KDF params proves the account exists; `POST <vault>/identity/connect/token` with `grant_type=password&scope=api offline_access&client_id=desktop&deviceType=7&DeviceIdentifier=<id>&deviceName=<name>` reproduces the real auth verdict (Vaultwarden requires the device fields). Check the password bytes are ASCII-clean (`od -c`) — IME full-width lookalikes silently corrupt credentials typed in chat.

No-CLI fallback: web vault → Vault → Tools → Import → format "Bitwarden (csv)".

## Pitfalls

- Never echo or log the master password; pass via `BW_PASSWORD` env or `--passwordenv`. Advise rotating any password that appeared in chat.
- `bw login --email` is not a flag; positional email. Unlock needs `bw unlock --passwordenv BW_PASSWORD` even right after login.
- Long installs (npm) can hit approval timeouts — warn the user to watch for the approval prompt, and offer the web-vault import as the zero-approval path.
