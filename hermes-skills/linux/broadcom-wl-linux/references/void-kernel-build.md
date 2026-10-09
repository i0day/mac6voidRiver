# Building custom kernels on Void Linux (wl-compatible)

Void has **no old-stable repo** — the current repo only carries the latest of each series; removed series (e.g. linux6.1) are gone from official mirrors (the community h4x0rd archive is also unreachable). To run an older LTS kernel, build from kernel.org source.

## Recipe
1. Download: `curl -fLO https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-<ver>.tar.xz` (check kernel.org for latest point release of the series).
2. Build deps: `gcc bc flex bison rsync openssl cpio xz` + `xbps-install -y openssl-devel` (needed for module signing support; missing `/usr/include/openssl/ssl.h` breaks build).
3. Baseline config from the running kernel: `cp /boot/config-$(uname -r) .config` then `make olddefconfig`. This keeps wl-compatible options (CFG80211/WEXT_PRIV as modules) intact.
4. Localversion tag: older `scripts/config` (6.1 era) has **no `--set-version-string`** — edit directly: `sed -i 's/^CONFIG_LOCALVERSION=.*/CONFIG_LOCALVERSION="-wl61"/' .config` before `make olddefconfig`.
5. `make -j$(nproc)` (2-core Haswell: 30-45 min; ~7000 .o files). Progress probe: `find <tree> -name '*.o' | wc -l` and presence of `vmlinux.o` / `arch/x86/boot/bzImage` (drivers compile last).
6. Install: `sudo make modules_install && sudo cp arch/x86/boot/bzImage /boot/vmlinuz-<ver>-wl61`.
7. Initramfs: Void uses dracut — `sudo dracut /boot/initramfs-<ver>-wl61.img <ver>-wl61`.
8. GRUB: `sudo grub-mkconfig -o /boot/grub/grub.cfg` picks it up automatically (detects /boot/vmlinuz-* + matching initramfs).

## wl-compatibility checklist (verify in new .config)
- `CONFIG_CFG80211=m`, `CONFIG_WIRELESS_EXT=y`, `CONFIG_WEXT_PRIV=y`, `CONFIG_RFKILL=m`
- Conflicting drivers all `=m` not `=y`: B43, B43LEGACY, BRCMSMAC, BRCMFMAC, SSB, BCMA
- `CONFIG_MODULE_SIG=y` with `CONFIG_MODULE_SIG_FORCE` unset
- Old baseline configs satisfy all of these by default — olddefconfig from a wl-working kernel config is safe.

## Build a wl.ko for the custom kernel
`make KBUILD_DIR=/usr/src/kernel-headers-<ver> -j4` in the wl source tree (Void headers live under /usr/src/kernel-headers-*), or copy the tree and build out-of-place to keep the original intact. Verify `modinfo wl.ko | grep vermagic` matches the target kernel before insmod.
