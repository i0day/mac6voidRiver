---
name: dbus-keyring-troubleshooting
description: Fix login failures from D-Bus keyring bus mismatch.
version: 1.0.0
author: hermes-agent
license: MIT
metadata:
  hermes:
    tags: [dbus, gnome-keyring, libsecret, bitwarden, vaultwarden, linux-desktop]
---

# D-Bus session bus & keyring troubleshooting

## When to Use

A desktop app on this user's Mint/dwm session (Bitwarden desktop, browsers, any libsecret consumer) cannot log in, unlock, or keep credentials — errors mentioning `org.freedesktop.secrets` or credential storage, or the user reporting "密码是对的但登不上" (password is correct but login fails).

The usual cause is `org.freedesktop.secrets` activation timing out because the keyring daemon is registered on a different session bus than the app uses. Same class of failure hits any session-bus consumer (dunst/notify-send "Could not connect: No such file or directory"): `~/.xinitrc` used `dbus-launch` whose `/tmp/dbus-*` socket gets garbage-collected by systemd-tmpfiles on long-running sessions, silently killing the whole desktop's session bus. Durable fix (applied 2026-09): xinitrc no longer uses dbus-launch — it exports `DBUS_SESSION_BUS_ADDRESS=unix:path=$XDG_RUNTIME_DIR/bus` (systemd user bus, never cleaned) and launches keyring/dunst/bitwarden directly on it.

## Diagnostic path (fast to slow)

1. **Read the app's own log first** - e.g. `~/.config/Bitwarden/app.log`. Look for `getPassword failed`, `Failed to activate service 'org.freedesktop.secrets': timed out (service_start_timeout=120000ms)`, `Access token key not found to decrypt encrypted access token. Logging user out`. These prove the failure is keyring/D-Bus, not the password - say that up front so the user stops re-testing credentials.
2. **Compare bus addresses** - the app's view vs where the keyring actually lives:
   - `tr '\0' '\n' < /proc/<app-pid>/environ | grep DBUS`
   - `echo $DBUS_SESSION_BUS_ADDRESS` in the same shell context
   - The correct modern bus is `unix:path=/run/user/1000/bus` (systemd user bus). A legacy `dbus-launch` bus (`/tmp/dbus-*`) with no activatable `org.freedesktop.secrets` is the classic mismatch on dwm/xinit-style sessions.
3. **Probe liveness, not just registration:**
   `busctl --user call org.freedesktop.secrets /org/freedesktop/secrets org.freedesktop.Secret.Service OpenSession "sv" "plain" variant s ""`
   Any response (even an argument-type error) means the service answers; a hang or timeout means the bus wiring is dead. The signature is `(sv)`, not `(ss)`.

## Fix (temporary, per boot)

1. Kill the stale keyring: `pkill -f "[g]nome-keyring-daemon"` (see pkill pitfalls).
2. Relaunch on the correct bus as a tracked background process:
   `env -u DBUS_SESSION_BUS_ADDRESS XDG_RUNTIME_DIR=/run/user/1000 gnome-keyring-daemon --foreground --components=secrets`
   (start with `background=true`; it self-registers on the systemd user bus).
3. Restart the app with the bus pinned explicitly:
   `DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus <app-binary>`
4. Verify by tailing the app log for a successful unlock line and the absence of `Logging user out`.

Tell the user this is per-session. The durable fix is repairing the dbus-launch chain in `~/.xinitrc` / the LightDM session so the desktop uses the XDG_RUNTIME_DIR bus. If it recurs, ask for `echo $DBUS_SESSION_BUS_ADDRESS` from a terminal inside the desktop session before doing anything else.

## Pitfalls (each cost time in this task class)

- **`pkill -f <name>` matches the invoking shell itself** - the pattern appears in your own `bash -c` command line, so the command SIGTERMs itself mid-run. Use the bracket trick (`pkill -f "[g]nome-keyring-daemon"`) or resolve PIDs with `pgrep` first and `kill` the exact PIDs.
- **`pkill`/`pgrep -x` silently matches nothing for names longer than 15 chars** (Linux `comm` truncation; `gnome-keyring-daemon` is 19). Use `-f` with a bracketed pattern, never `-x` for long daemon names.
- **`busctl --user status <name>` printing `Failed to get credentials: No such device or address` is a red herring** - a busctl credential quirk, not proof the service is dead. Use the OpenSession call probe instead.
- **Shell-level `nohup ... &` is rejected by the terminal tool** - launch daemons with `terminal(background=true)` and `exec` so the process stays tracked.
- **Check the server side independently before blaming credentials** - for Vaultwarden, `curl -X POST <host>/identity/accounts/prelogin -d '{"email":"..."}'` returning 200 with KDF settings matching the client's stored config confirms the credential pipeline is fine and isolates the fault to client-side secret storage.
- **Kill-type and long-running commands may block awaiting user consent.** Present the fix plan and get an explicit go-ahead; never retry a blocked command as a workaround.
