---
name: broadcom-wl-linux
description: Use when building or debugging Broadcom wl wifi freezes.
---

# Broadcom wl (broadcom-sta) driver — build, load, freeze triage

## When to Use
Loading `wl.ko` on a modern kernel, building broadcom-sta from source, or triaging whole-system freezes that follow wl load or real wifi traffic (typical on Mac BCM43xx hardware).

## Standing rules
- **Blacklist all conflicting drivers before loading wl** (`/etc/modprobe.d/broadcom-wl-dkms.conf`): `b43 b43legacy bcm43xx bcma brcm80211 brcmfmac brcmsmac ssb bcma-pci-bridge`. Conflicting drivers must be `=m` (not `=y`) in the kernel config — `=y` built-ins cannot be blacklisted and will fight wl for the device. Check with `grep -E 'CONFIG_B43=|CONFIG_BRCMSMAC=|CONFIG_SSB=|CONFIG_BCMA=' /boot/config-$(uname -r)`.
- **wl kernel-config requirements**: `CONFIG_CFG80211=m`, `CONFIG_WIRELESS_EXT=y`, `CONFIG_WEXT_PRIV=y` (wl uses SIOCDEVPRIVATE ioctls), `CONFIG_RFKILL=m`, `CONFIG_MODULE_SIG_FORCE` off (wl is unsigned/proprietary).
- **objtool kills the build on kernel 6.15+** because wl.o embeds the proprietary blob: add `wl.o: override objtool-enabled =` to the module Makefile (from JoanBruguera/broadcom-wl-linux-mainline patch 020). Third-party GitHub ports often omit this — add it yourself or the build dies with `objtool: unannotated intra-function call ... Error 255`.
- **vermagic must match** `uname -r` exactly; build against `/usr/src/kernel-headers-<ver>` (Void) or `/lib/modules/$(uname -r)/build`.

## Freeze triage order (do not guess)
1. **Rule out ASPM cheaply first, then stop**: `sudo setpci -s <dev> CAP_EXP+0x10.w=0x0000` on endpoint + upstream bridge. If it still freezes, ASPM is not the cause — do not revisit.
2. **`insmod wl.ko passivemode=1`** — loads without firmware upload/radio activation. If passive loads fine but normal load freezes, the hang is in the firmware-upload / DMA-init path. Watch dmesg for `osl_dma_map` / `dma_map_phys` WARN inside `wlc_bmac_init` — that is the DMA path signature.
3. **`piomode=1`** forces PIO instead of DMA — try when the freeze signature is DMA-related.
4. **Capture the crash with pstore/ramoops before blaming the driver blind** — see `references/pstore-ramoops-capture.md` for the exact boot-parameter setup and the config gotchas that silently void capture.
5. If the driver version is simply incompatible with the kernel series, the fallback is building an older kernel — see `references/void-kernel-build.md`.

## Runtime freeze root cause: IBT vs the 2015 blob
- The `wl.o: override objtool-enabled =` hack only disables the BUILD-time CFI check. At runtime the proprietary blob's unannotated indirect calls violate Intel IBT (CONFIG_X86_KERNEL_IBT=y) → #CP control-protection fault → hard freeze, typically on the scan path (wl_notify_scan_status → wl_inform_single_bss). Fix: boot with `ibt=off` (Garuda ships this by default on BCM4360+wl machines; kimptoc/bcm4360-re needed retbleed=off spectre_v2=off just to load wl on NixOS). Tradeoff: IBT off system-wide on a machine running an unmaintained blob with known CVEs.
- The `memcpy: field-spanning write ... wl_cp_ie/wl_inform_single_bss` WARNING is a FORTIFY_SOURCE false positive: kzalloc of sizeof(wl_cfg80211_bss_info)+sizeof(ieee80211_mgmt)-1+WL_BSS_INFO_MAX(2048) leaves ~1.5K slack past the max frame_len (36+2048). Benign with panic_on_warn=0; do not chase it as the freeze cause.
- Kernel-cmdline `modprobe.blacklist=wl` stops only auto-load; explicit `sudo modprobe wl` still works — safe way to let the user test without risking an accidental boot-time freeze.

## Known-bad combinations (as of late 2026)
- wl 6.30.223.271 freezes on 6.17/6.18 (and reportedly 6.6) on Haswell MacBook Air BCM4360 even with patched sources (mainline mirror, community 6.17 ports). Compile-success patches ≠ runtime stability; the freeze follows real traffic / DMA init, not insmod itself.

## References
- `references/void-kernel-build.md` — building custom kernels on Void (no old-stable repo), wl-compatible config checklist, GRUB/initramfs wiring.
- `references/pstore-ramoops-capture.md` — crash-capture setup that actually persists (suffix pitfall, PSTORE_CONSOLE gate).
