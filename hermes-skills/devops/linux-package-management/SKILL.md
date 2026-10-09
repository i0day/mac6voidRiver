---
name: linux-package-management
description: Install upstream debs; audit apt disk usage before removals.
---

# Linux Package Management (Mint/Debian, apt + upstream .deb)

Class of task: installing apps from upstream releases without flatpak/snap, removing distro default apps safely, and auditing disk usage to propose uninstall candidates.

## Standing user preferences (apply every instance)
- User does NOT want flatpak or snap installs. Prefer native .deb (apt repo or upstream release .deb). Do not offer flatpak as an option.
- NEVER bulk-uninstall on a guess. For removal requests, first present a candidate list (size, last-used, what breaks) and let the user pick. The user explicitly wants to choose which apps go.
- Respond in Chinese (user is a Chinese speaker); plain-text aligned tables are fine in CLI.

## Installing from an upstream GitHub release .deb
1. Check what's already available first: `apt-cache policy <pkg>`, `apt-cache search <term>` — if absent from Mint repos, go upstream.
2. Resolve latest release: download the GitHub API JSON to a scratch file (`curl -sL -o rel.json https://api.github.com/repos/<owner>/<repo>/releases/latest`) then parse with `execute_code`/`json.load`. Do NOT pipe curl straight into an interpreter (security scanner flags it, and a failed parse loses the payload).
3. Repos get renamed/moved — the API `url` field shows the real repo; follow it for the download URL pattern `https://github.com/<owner>/<repo>/releases/download/<tag>/<asset>`.
4. Pick the .deb matching the Ubuntu base codename, not Mint's name: Mint 22.x = Ubuntu 24.04 noble → use the `noble` build. Check `dpkg-deb -I <file>.deb` Depends against installed libs before installing.
5. Install with `sudo apt-get install -y /path/to.pkg.deb` (apt resolves deps) — never bare `dpkg -i` (leaves broken deps).
6. Verify: `which <bin> && <bin> --version` and `dpkg -l <pkg> | tail -1`.

## Removing distro default apps safely
1. Enumerate installed matches: `dpkg -l | grep -E '^ii.*(names)'` — capture exact package names including -dbg, -plugins, locale, gir bindings.
2. DRY RUN FIRST: `sudo apt-get remove -s <pkgs>` and read the `Remv` lines. This catches meta-package (`mint-meta-*`) collateral before anything is touched.
3. Remove top-level apps with `apt-get remove -y`, then a second pass for orphaned support libs (common/core/data/style/uiconfig packages the metapackage pulled in), then `apt-get autoremove -y`.
4. Re-check with the same `dpkg -l | grep` afterward; report leftovers honestly (some -data/-locale packages linger because another package still depends on them — that's fine, don't force).
5. Pitfall: removing a meta-package dependency can cascade to `mint-meta-xfce`/`mint-meta-core` — if the dry run shows metas in the Remv list, stop and remove only the leaf apps instead.

## Disk-usage audit → uninstall candidate menu
Goal: present heavy, barely-used apps as a pick-list, never auto-remove.
1. Size ranking: `dpkg-query -W -f='${Package}\t${Installed-Size}\n' | sort -t$'\t' -k2 -rn | head -45` (Installed-Size is KiB → divide by 1024 for MB).
2. Usage signal: `stat -c %x $(command -v <bin>)` for atime (works on ext4 without noatime); cross-check with the user's own sense of usage. Recently-accessed apps go on the list with a 'recently used' note, not hidden.
3. Group candidates into categories the user reasons about: apps / themes-icons / old kernels / input-method data / dev packages. Exclude system-core (xorg, firmware for present hardware, libc).
4. Old kernels: current kernel from `uname -r`; older `linux-modules*`, `linux-headers*`, `linux-hwe-*` for other versions are safe removal candidates — but confirm the user considers the running kernel stable first.
5. Deliver as a compact table (name, size, one-line note) and ask which to remove. Do not proceed without the pick.

## Pitfalls
- `curl | python3` gets flagged by the security scanner as HIGH (executing uninspected downloads) — download to scratch file first, parse after.
- `dpkg-query ... | sort -rn` without `-t$'\t'` sorts on the wrong field; always set the tab delimiter when sorting the Package\tInstalled-Size output.
- Mint package names carry Mint suffixes (`+zena`, `+mint2+wilma`) — match on the base name in greps, not exact versions.
- apt autoremove won't remove packages a meta-package still 'wants'; check the dry-run output rather than assuming a clean sweep.
