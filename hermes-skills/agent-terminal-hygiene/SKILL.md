---
name: agent-terminal-hygiene
description: Safe deletes and kills from the persistent agent terminal.
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [terminal, process, cleanup, appimage]
---

# Agent terminal hygiene: deletions, kills, and persistent shell state

Class: deleting directories, killing processes, and uninstalling apps from the Hermes agent's persistent terminal session, where shell state survives across calls and bites back.

## When to Use

- Deleting scratch/home directories, killing daemons or GUI apps, or fully uninstalling an AppImage from the agent terminal.

## Always-on rules

- **Never `rm -rf` the current working directory (or a dir you'll `cd` back into) from `terminal()`.** The persistent shell's cwd stays pinned to the deleted path and EVERY subsequent terminal call fails with `cd: <old path>: No such file or directory` — including calls that pass a different `workdir`, because the session wrapper's own `cd` runs first. Recovery: use `execute_code` (fresh `os.chdir` works) to `os.makedirs` the target dir or chdir elsewhere, then terminal() recovers. Prevention: `cd /home/<user>` before deleting scratch dirs, or delete via `execute_code`/`shutil.rmtree` from a safe cwd.
- **Never `pkill -f <name>` where `<name>` also appears in your own command line.** The wrapping `bash -c` contains the pattern string, so pkill kills the agent's own command (SIGTERM, exit -15) before it finishes the cleanup steps. Find the real PID first (`pgrep -x <exact-binary>` or `ps`), then `kill <pid>` / `kill -9 <pid>` by number, and verify with `ps -p <pid>` in a separate call.
- **Split kill and cleanup into separate calls.** A combined `pkill ...; rm ...` that dies mid-way leaves half-cleaned state with no output; separate calls show which step failed.
- **Never trust that a `pkill`/reload in the middle of a long command actually ran** — if the wrapper was SIGTERM'd earlier in the chain, every step after the kill silently never executed (e.g. a `pkill -USR1 <daemon>` reload never reached → new config invisible while the stale instance keeps serving old config; a later second daemon launch then fails every grab against the first). Verify reload/kill effects in a SEPARATE follow-up call (`pgrep -a <daemon>` for the exact instance count, config tail, functional probe) before concluding.
- **When testing scripts that fork background timers with `subprocess.run`, pass stdout/stderr=DEVNULL.** The forked child inherits the pipe, so the parent's run() blocks until the timer exits — every check printed afterward runs in post-completion state and the test reads as falsely broken. Kill leftover timer bursts by PID enumeration via /proc cmdline filtering, excluding os.getpid().

## Uninstalling an AppImage / GUI app cleanly

1. Kill by explicit PID (rule above); check FUSE leftovers: `mount | grep -i appimage`.
2. Remove the binary AND the out-of-band state it self-installs: `~/.config/autostart/<App>.desktop`, `~/.config/<App>/`, `~/.local/share/<reverse-dns-bundle-id>/` (Tauri/Electron apps keep sqlite dbs there), `~/.cache/<App>/`.
3. Verify with `find ~ -iname '*<app>*'` — the binary alone is never the whole footprint.

## Pitfalls

- Deleting in a burst trips mass-deletion security scans (CRITICAL flag). That's fine when the user asked for the delete — just expect approval prompts; batch intentionally and state what's being removed.
- `sha256sum -c <SUMS>` against a sums file listing many artifacts reports FAILED open or read for the ones you didn't download — check only the line for your file, don't treat the overall exit as failure.
