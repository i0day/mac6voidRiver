---
name: void-kernel-build-forensics
description: Build custom/old kernels on Void; ramoops crash capture.
---

# Void Linux 自编译内核 + 死机取证（ramoops/pstore）

适用：用户要求装旧内核、试特定内核版本、或需要抓死机现场（panic/softlockup 前最后日志）。

## 自编译内核流程（已验证）
1. 下源码：`curl -fLO https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-<ver>.tar.xz`（kernel.org 有 6.1.188 等 longterm 末版）。
2. 以现内核 config 为基线：`cp /boot/config-<current> .config`，改 `CONFIG_LOCALVERSION="-tag"`（sed 直接改；旧内核的 `scripts/config` 没有 `--set-version-string`，只有 `--set-str`），然后 `make olddefconfig`。
3. `make -j4`（i5 双核四线程约 30-45 分钟）→ `sudo make modules_install` → `sudo cp arch/x86/boot/bzImage /boot/vmlinuz-<ver>-tag`。
4. initramfs：Void 用 dracut — `sudo dracut --force /boot/initramfs-<ver>-tag.img <ver>-tag`。
5. `sudo grub-mkconfig -o /boot/grub/grub.cfg` — 新内核自动进 "Advanced options" 子菜单（默认项不变，安全）；验证 `sudo grep -c '<ver>' /boot/grub/grub.cfg`（head 截断容易误判为没生成）。
6. 第三方模块（如 wl.ko）：`make KBUILD_DIR=/path/to/kernel/src -j4` 直接指向自编译内核树，vermagic 自动匹配；装入 `/lib/modules/<ver>-tag/extra/` 后 `sudo depmod <ver>-tag`。

## 死机取证配置（ramoops）
- **boot 参数只接受纯字节数**：`ramoops.mem_size=2097152` 有效，`2M`/`512K` 直接 `invalid for parameter` 静默不加载。record_size/console_size/pmsg_size 同理。
- 地址从 `dmesg | grep BIOS-e820` 取 usable 顶端往下留 2M，避开 ACPI NVS。
- 固化三处：`/etc/default/grub` 的 `GRUB_CMDLINE_LINUX_DEFAULT`（ramoops.mem_address=... 等）+ `/etc/modules-load.d/ramoops.conf` + `/etc/modprobe.d/ramoops.conf`，再 grub-mkconfig。
- 配合 `softlockup_panic=1 hardlockup_panic=1 panic=15` 让软锁变 panic 自动重启留档。
- **Void 官方内核坑**：`CONFIG_PSTORE_CONSOLE` 和 `CONFIG_PSTORE_PMSG` 均未编译（6.6/6.12/6.18 皆然）——ramoops 注册成功但 console-ramoops / pmsg 永远不会出现，`/dev/pmsg0` 写了也丢。要真抓到崩溃前日志必须自编译内核打开这两项，或用 netconsole/串口。先 `grep PSTORE /boot/config-*` 确认再承诺能抓到。

## 已排除的死路（勿重复浪费回合）
- broadcom-wl 6.30.223.271 在 BCM4360 上的加载死机与 ASPM 无关（端点+桥全关仍死）、与内核版本无关（6.1/6.6/6.18 全死）、与 passivemode/piomode 无关。insmod 本身能过，死在后续固件 DMA（`dma_map_phys` WARNING 是前兆）。换内核/换补丁仓库（Nurozen、develeacid）都不解决——别再走这条路，方向应是 b43 替代或换网卡。
- Void 无官方旧包仓库（h4x0rd.space 已停服）；旧内核只能自编译。

## 清理还原
删自编译内核 = 删 /boot 的 vmlinuz+initramfs + /lib/modules/<ver> + grub-mkconfig；删包用 `xbps-remove`（注意 linux-lts meta 包会阻塞删除，一并列进 remove）。GRUB 还原改 /etc/default/grub 后必须重跑 grub-mkconfig 并 grep 验证旧条目清零。