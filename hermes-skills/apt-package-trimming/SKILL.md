---
name: apt-package-trimming
description: "Trim unwanted Debian/Mint packages safely."
---

# apt Package Trimming (Debian/Ubuntu/Mint)

Class of task: reviewing installed apps/packages the user barely uses and removing them without breaking the system.

## User preferences (standing)
- User does NOT want flatpak — prefer native .deb packages (download official release .deb from GitHub releases, install with `sudo apt install ./pkg.deb`).
- Terminal cannot display long output comfortably. Any review list, table, or long explanation MUST also be written to a plain-text file in `~/` (e.g. `~/apps-review-N.txt`) via write_file, numbered per batch. User reads the file, then replies with package names to delete.
- User decides what gets deleted — never bulk-remove on your own judgment when cascades are involved. Present the tradeoff, let them pick (clarify tool works well for risky forks).
- Tables render as literal characters in CLI, so the saved .txt file is the real deliverable.

## Procedure
1. **Identify what's installed and how big:**
   `dpkg-query -W -f='${Package}\t${Installed-Size}\n' | sort -t$'\t' -k2 -rn | head -45`
2. **Map .desktop entries to packages** (user often pastes menu entry names, not package names):
   `grep '^Exec=' /usr/share/applications/<name>.desktop` then `dpkg -S <exec-path>`.
   Note: names the user types may be two files concatenated (e.g. "seahorse" + "org.xfce.Catfish") — verify with `ls`/`find`.
3. **ALWAYS simulate before removing:**
   `sudo apt-get remove -s <pkgs> 2>&1 | sed -n '/REMOVED/,/^0 upgraded/p'`
   Read the full cascade list. If it removes anything beyond the requested set, surface it explicitly with a keep/remove recommendation before executing.
4. **Check reverse dependencies before removing a small lib:**
   `apt-cache showpkg <pkg> | sed -n '/^Reverse Depends:/,/^Dependencies:/p'` — tiny packages (bubblewrap ~50KB) can gate big stacks (webkit, xdg-desktop-portal); removing them is net-negative.
5. **Remove + clean:**
   `sudo apt-get remove -y <pkgs> && sudo apt-get autoremove -y` (long timeout, 600s).
6. **Verify:** `dpkg -l <pkgs>` shows `un` for removed; re-check the desktop file list.

## Critical cascades on this machine (MacBook Air + Mint 22.3 + dwm)
- **gcc-13 → dkms → broadcom-sta**: user's Wi-Fi (BCM4360) uses the `wl` driver built via dkms. Removing gcc/build-essential breaks Wi-Fi on every future kernel upgrade until reinstalled. Keep the toolchain unless user explicitly accepts the risk.
- **Compositor**: dwm session (`~/.xinitrc`) launches **picom**, not compton/compiz — those are safe to remove; picom is not.
- **dracut-install**: needed to build initramfs on kernel upgrades — never remove.
- **casper**: Mint update tooling may reference it — keep.
- **Old kernels**: safe to remove all but the running one (`uname -r`); remove linux-image/modules/headers/tools of the old version together.
- **captain** removal means double-clicking .deb no longer opens a GUI installer — user installs via `apt install ./file.deb` anyway.

## Pitfalls
- 删 ibus 全家时级联会带走 **fcitx-sunpinyin**（共享 sunpinyin-data 依赖）——用户实际用 fcitx，删完立即 `apt-get install -y fcitx-sunpinyin` 补回。同理留意其它 IM 框架共享数据包的连带移除。
- 批量 purge rc 残留配置：`dpkg -l | awk '/^rc/{print $2}' | sudo xargs -r apt-get purge -y`，一次清干净。
- `curl | python3` gets flagged by the security scanner — download JSON to scratch with `curl -o` first, then parse with execute_code.
- A package the user names may not be installed at all (e.g. brasero) — check `dpkg -l` and say so rather than assuming.
- After removing a metapackage cascade, run autoremove once; if the user then wants back a casualty (e.g. feh), reinstall it individually — it won't come back with the metapackage.
- flatpak with zero installed apps (`flatpak list` empty) is safe to purge with no data loss — check and state this before removal.
