---
name: linux-package-slimming
description: Safely audit and remove bulky unused apt packages.
version: 1.0.0
author: Hermes
license: MIT
metadata:
  hermes:
    tags: [linux, apt, disk-space, mint]
---

## When to Use
User asks to free disk space, review heavy/unused apps, uninstall distro-default packages, or identify what an unknown .desktop launcher is, on an apt-based system (Linux Mint / Ubuntu).

# Linux Package Slimming (apt / Linux Mint)

Class of task: reviewing installed packages to free disk space or shed distro defaults, then removing the user-chosen set safely.

## Standing user preferences (embed in every instance)
- **No flatpak** — install apps from official vendor .deb packages instead (download to scratch, `dpkg-deb -I` to inspect, then `sudo apt install ./pkg.deb`).
- **Long lists go to a file.** The terminal truncates; when presenting any review longer than ~15 lines, write it to `~/<topic>.txt` via write_file and tell the user the path. The user reads the file, then replies with choices.
- **User picks, agent executes.** Never bulk-remove on a guess; present a table (name, size, what it is, keep/remove suggestion) and wait for explicit selection.
- Reply in Chinese; keep final reports short plain-text bullets.

## Procedure
1. **Size triage:** `dpkg-query -W -f='${Package}\t${Installed-Size}\n' | sort -t$'\t' -k2 -rn | head -45` (sizes in KB; divide by 1024 for MB). Exclude kernel/firmware/driver packages from the "app" list but note them separately.
2. **Usage signal:** check `stat -c %x $(command -v app)` atime to mark recently-used apps; don't suggest removing those without flagging.
3. **Identify unknown .desktop entries:** `grep '^Exec=' /usr/share/applications/<name>.desktop` plus `dpkg -S <binary>` to map to packages. Several desktop files the user pastes as one string may be separate files — split and check each.
4. **ALWAYS simulate before removing:** `sudo apt-get remove -s <pkgs>` and read the REMOVED list for collateral damage. This is the mandatory gate.
5. **Dependency red flags to surface to the user before proceeding:**
   - `dkms` + vendor driver modules (e.g. broadcom-sta `wl`): removing gcc/build-essential cascades to the Wi-Fi driver build chain. Check `dkms status` and `lspci -k | grep -A3 -i network` first; if the active Wi-Fi driver is a dkms module, keep the toolchain or get explicit user sign-off.
   - `mint-meta-*` metapackages: removal is harmless for a dwm/custom-WM setup but breaks distro upgrade tooling expectations — mention once.
   - Mesa/LLVM (`libllvm*`, `mesa-*`): never remove — core graphics stack.
6. **Remove, then clean:** `sudo apt-get remove -y <pkgs>` followed by `sudo apt-get autoremove -y` to sweep orphaned libs.
7. **Verify:** `dpkg -l | grep -E '<patterns>'` should show nothing; re-install anything the cascade removed that the user wants (do this immediately after, before reporting).
8. If the removal command is long-running and the user messages mid-run, it moves to background — poll it to completion before the follow-up install so dpkg locks don't collide.

## Pitfalls
- Run the simulation with the EXACT final package list; a package added later (e.g. old-kernel image) can change the cascade (it dragged metapackages, dev headers).
- `apt-get remove` keeps configs; use `purge` only if the user asks to erase settings too.
- Old-kernel removal: keep the currently running kernel (`uname -r`) and at least one other; verify with `linux-image-*` listing after.
- After removing a GUI package manager (captain/gdebi), tell the user the CLI replacement: `sudo apt install ./file.deb`.
