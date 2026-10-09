---
name: iwd-psk-profile-connect
description: Connect iwd headlessly via .psk profile files.
---

# iwd headless PSK connect (no interactive passphrase)

Symptom: `iwctl station X connect SSID` always prompts "Type the network passphrase" even though a profile exists in /var/lib/iwd.

Two root causes (check both):

1. **Network config disabled** — iwd defaults to NOT managing network config. Log shows `station: Network configuration is disabled.` Fix in `/etc/iwd/main.conf` (key goes in `[General]`, NOT `[network]`):
   ```
   [General]
   EnableNetworkConfiguration=true
   ```

2. **Wrong .psk file format** — file must be `/var/lib/iwd/<SSID>.psk` (plain name if SSID is alnum/-/_/space only; hex-encoded `=<hex>.psk` otherwise — NOT `<hex>_psk.psk`). Content:
   ```
   [Security]
   PreSharedKey=<64-hex PMK>
   ```
   PMK = PBKDF2-HMAC-SHA1(passphrase, ssid, 4096 iterations, 32 bytes):
   `hashlib.pbkdf2_hmac('sha1', passphrase.encode(), ssid.encode(), 4096, 32).hex()`
   Note: section is `[Security]` (not `[psk]`), key is `PreSharedKey` (not `pmk`/`pmk32` — those are wpa_supplicant names). A raw `Passphrase=` also works but stores plaintext; PreSharedKey is preferred. For WPA3/SAE-only networks the raw Passphrase is required (PMK alone insufficient — network_load_psk: `if (!psk || is_sae) { if (!passphrase) return -ENOKEY; }`).

Debug: run `iwd -d` in foreground (no `-f` option in 3.x), watch `network_connect_psk() ask_passphrase: true` — true means profile not found/unloadable. Source: iwd tarball src/network.c `network_load_psk()`, src/storage.c `storage_get_network_file_path()`.

ANDROID PHONE HOTSPOTS (Pixel_XXXX etc.) are WPA2/WPA3-SAE transition: a PreSharedKey-only profile FAILS silently — iwctl then prompts "Type the network passphrase" even with the .psk present, and headless connect hangs/times out. ALWAYS write `Passphrase=<raw>` instead of PreSharedKey for any network whose RSN advertises `Authentication suites: PSK SAE` (check with `iw dev <iface> scan` raw output). Our iwd-psk-write now always stores Passphrase= (raw passphrase in file, 0600) — works for both WPA2-only and SAE. Verify SAE suites with: `iw dev wlp3s0 scan | grep -B12 '<SSID>' | grep 'Authentication suites'`.

After fixing: restart iwd, `iwctl station X scan` then `connect SSID` connects silently. On Void/runit: `sv up iwd` (sv status may need root). iwctl non-TTY quirks: passphrase cannot be passed as CLI arg, and piping via stdin aborts — the profile file is the only headless path.

iwctl output parsing quirks (for menus/scripts): tables have NO colons — parse `station show` with `awk '/Connected network/{print $NF}'` after stripping ANSI (`sed 's/\x1b\[[0-9;?]*[a-zA-Z]//g'`); `get-networks` is fixed-width — locate columns via header `index()` offsets, and the current-network row uses a `>` marker while separator lines are dashes (strip leading `[ >-]+`). `iwctl` is iwd 3.x CLI: no `-j`/JSON. Helper script pair on this machine: `~/.local/bin/wifimenu` (rofi menu) + `~/.local/bin/iwd-psk-write` (passphrase on stdin → PMK .psk at /var/lib/iwd, hex-encodes unsafe SSIDs with leading `=`).

Boot-time module autoload (Void): `/etc/modules-load.d/<name>.conf` listing the module is read by `modules-load` from /etc/runit/core-services/02-kmods.sh. Pitfall: modules-load calls `modprobe -ab` — the `-b` (--use-blacklist) means a kernel cmdline `modprobe.blacklist=<mod>` makes it SILENTLY skip the module while manual `modprobe <mod>` still works. Check `cat /proc/cmdline` for modprobe.blacklist= and remove from /etc/default/grub + grub-mkconfig. Verify with: rmmod the module, run `modules-load -v`, confirm it reloads.
