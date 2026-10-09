# Android root extraction of browser passwords (last resort)

Only when official export is impossible. Requires root (Magisk verified via `adb shell su -c id`).

## What's where

- Firefox Fenix logins: `/data/data/org.mozilla.firefox/databases/logins2.sqlite` (table `loginsL`, `secFields` = base64 `AES`+16-byte-IV+ct JSON). Key is NOT in key4.db (`nssPrivate` empty) — it's an Android Keystore key; canary in `shared_prefs/loginsCrypto.xml`.
- Chrome on Android: no local Login Data; GMS `password_manager.db` holds only breach-check hashes (`leak_check_reencryption`), not credentials.

## Pulling DBs via adb+root

```
su -c "cp <db> /data/local/tmp/ && chmod 644 /data/local/tmp/<db>"
adb pull /data/local/tmp/<db>
```
Pull -wal/-shm siblings too for live DBs.

## Frida keystore-key hooking

Pattern: hook `javax.crypto.Cipher.doFinal` (DECRYPT_MODE) and `SecretKeySpec.<init>` / `Cipher.init` key dump; spawn the app (`frida -f <pkg>`) and drive UI to the saved-logins screen to trigger decryption; capture plaintexts via `send()`.

Pitfalls learned:
- Frida 17.x agent segfaults injecting into apps on devices with zygisk/tricky_store (crash inside frida-agent during linker constructors). Frida 16.6.4 is the known-good line for such setups; frida-server version must match the frida python package version exactly.
- `setenforce 0` alone does not fix agent-injection crashes — not SELinux if avc shows permissive=1.
- Attach to already-running Fenix often times out ('waiting for stop'); force-stop the app and use spawn mode.
- Fenix settings activity is not exported (`LoginListActivity` doesn't exist); trigger decryption by opening the app normally and navigating in-app, or any code path that reads logins.
- If the target app's key is hardware-backed (StrongBox/Titan M2), even Frida cannot extract the raw key — only decrypted plaintexts at doFinal time. Capture plaintext, not keys.
- Python 3.14 has no frida 16 wheels — build a python3.12 venv for the old-line client.

## Desktop Firefox offline decryption (works, for reference)

key4.db PBE with empty master password: PBES2 params in `metaData.item2` (OID 1.2.840.113549.1.5.13), key = PBKDF2-HMAC-SHA256(SHA1(globalSalt+""), entrySalt, iters); IV quirk: use the full DER encoding of the IV OctetString (tag+len+value = 16 bytes) as the AES IV. Then SDR key from `nssPrivate.a11` (3-byte header, SEQUENCE{algoSeq, OCTETSTRING ct}). Desktop logins.json fields are base64 DER; Fenix logins2 uses raw `AES`+IV+ct. Verify the empty-master-password check decrypts before trusting.
