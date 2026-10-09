---
name: void-custom-kernel
description: 在 Void Linux 上自编译内核、装第三方模块、配 pstore/ramoops 死机取证。
version: 1.0
license: MIT
metadata:
  hermes:
    tags: [void, kernel, dracut, grub, pstore, ramoops, broadcom-wl]
    related_skills: [linux-package-slimming, dbus-keyring-troubleshooting]
---

# Void Linux 自编译内核 + 崩溃取证（ramoops/pstore）

## When to Use
- 需要在 Void 上跑仓库没有的内核版本（回退旧 LTS / 试补丁）
- 机器反复死机，需要 pstore/ramoops 抓崩溃现场
- 给自编译内核装第三方 out-of-tree 模块（如 broadcom-wl）

## 编译流程（已验证）
1. 源码：`curl -fLO https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-<ver>.tar.xz`（kernel.org CDN 快，~6.7MB/s）。
2. 基线配置：直接 `cp /boot/config-<当前内核> .config` 再 `make olddefconfig` —— Void 内核 config 向下兼容良好，非交互即可完成。
3. 版本标记用 `sed -i 's/^CONFIG_LOCALVERSION=.*/CONFIG_LOCALVERSION="-tag"/' .config`。坑：6.1 的 `scripts/config` **没有** `--set-version-string`（只有 --enable/--set-str 等），别用。
4. 依赖：gcc/bc/flex/bison/rsync/cpio + `openssl-devel`（缺了 menuconfig/模块签名报错）。
5. `make -j4`（i5 双核四线程约 30-45 分钟）→ `sudo make modules_install` → `sudo cp arch/x86/boot/bzImage /boot/vmlinuz-<ver>-tag`。
6. initramfs：`sudo dracut --force /boot/initramfs-<ver>-tag.img <ver>-tag`。
7. `sudo grub-mkconfig -o /boot/grub/grub.cfg` 自动加条目（在 "Advanced options" 子菜单里，`grep menuentry` 时别被 head 截断误判为没生成）。默认项不变，安全。
8. 第三方模块：`make KBUILD_DIR=/path/to/kernel/src -j4` 直接指向源码树编译，产物 `sudo cp` 进 `/lib/modules/<ver>-tag/extra/` + `sudo depmod <ver>-tag`。
9. 一次性引导指定条目：`sudo grub-reboot '<条目名>'`（写 grubenv，下次重启生效一次）。

## ramoops/pstore 取证配置（关键坑）
- **boot 参数不接受 K/M 后缀**：`ramoops.mem_size=2M` 直接 invalid，必须纯字节数 `2097152`。/etc/default/grub 里写 `ramoops.mem_address=0x<预留地址> ramoops.mem_size=2097152 ramoops.record_size=524288 ramoops.console_size=262144 ramoops.pmsg_size=65536`。
- 地址从 `dmesg | grep BIOS-e820` 的 usable 顶端选（如顶端 0x8cd13fff → 用 0x8cb00000），必须落在 usable 内。
- 运行期 `modprobe ramoops` 也能注册但 base=0x0 无效且无预留，不可靠——用 boot 参数让内核早期预留。
- **Void 内核 config 没编 `CONFIG_PSTORE_CONSOLE`/`PSTORE_PMSG`**（只有 PSTORE_RAM/BLK）→ console-ramoops 和 /dev/pmsg0 都不会有内容。抓死机前必须 `grep PSTORE /boot/config-*` 确认，没有就得自编译带 console 的内核，或改用 netconsole/串口。
- 配合 `softlockup_panic=1 hardlockup_panic=1 panic=15` 让软锁变 panic 自动重启；但**纯 hard hang（总线级冻结）绕过一切 panic 机制**，pstore 也救不了。
- 读回：`sudo mount -t pstore pstore /sys/fs/pstore`。

## broadcom-wl (BCM4360) 死机结论（MacBookAir6,1 实测）
- wl 6.30.223.271 blob 在本机于 6.1/6.6/6.18 全部死机，与内核版本无关：passivemode=1 不死（不上传固件），正常加载后固件 DMA 阶段整机冻结。
- 排除项（都试过无效）：ASPM（端点+桥 setpci 关）、pcie_aspm=off、piomode、社区补丁版 broadcom-sta（只解决编译期 API，不解决运行时冻结）。
- 加载瞬间的 `dma_map_phys WARNING + osl_dma_map/wlc_bmac_init` 栈是固件 DMA 初始化的前兆信号。
- 结论方向：该卡在此机上是固件/PCIe 交互级 hard hang，换内核无效；b43 不支持 BCM4360（AC PHY）→ 出路是换网卡或 USB WiFi。
