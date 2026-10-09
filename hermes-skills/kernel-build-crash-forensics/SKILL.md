---
name: kernel-build-crash-forensics
description: Build custom kernels; capture hard-freeze logs via pstore.
---

# 自编译内核 + 死机取证（Void Linux）

## When to Use
需要编译特定版本内核（如回退 LTS 测驱动兼容性）、系统 hard freeze 无日志要抓崩溃现场，或给新内核重编第三方模块（wl / dkms 类）。

## 死机取证：ramoops/pstore 配置
- **ramoops 必须在内核早期预留内存**：运行期 `modprobe ramoops` 的地址未经内核预留，crash 记录不可靠甚至完全不落盘。正确做法 = GRUB 命令行参数 + 开机自动加载：
  - `/etc/default/grub` 加 `ramoops.mem_address=<物理地址> ...`，地址从 `dmesg | grep BIOS-e820` 取 usable 区顶端往下 2M（避开 ACPI NVS）
  - `/etc/modules-load.d/ramoops.conf` → `ramoops`；`/etc/modprobe.d/ramoops.conf` → 同参数 options
- **致命语法坑：内核 boot 参数和模块参数都不接受 `2M`/`512K` 带后缀写法**（`ramoops: '2M' invalid for parameter 'mem_size'`），必须纯字节数：`mem_size=2097152 record_size=524288 console_size=262144 pmsg_size=65536`。
- 让死机变可捕获：boot 参数加 `softlockup_panic=1 hardlockup_panic=1 panic=15`（软锁→panic→15 秒自动重启）；运行期 `dmesg -n 8` 解除控制台抑制。
- **先验证发行版内核 config 支持**：`grep PSTORE /boot/config-$(uname -r)` —— Void 内核 `CONFIG_PSTORE_CONSOLE` / `PSTORE_PMSG` 未编译，只有 `PSTORE_RAM=m`：ramoops 注册成功但 console 日志根本不会被写入 pstore，`/sys/fs/pstore` 永远为空。这种情况 pstore 路线不可用，要么自编译带 `PSTORE_CONSOLE=y` 的内核，要么用 netconsole（需第二台机器收）。
- 崩溃后读取：`sudo mount -t pstore pstore /sys/fs/pstore; cat /sys/fs/pstore/console-ramoops-0`。
- 无 pstore 时的替代取证：崩溃前开 `sudo dmesg -w > live.log`（配 sync 循环），至少保住 panic 前最后几屏；对比 live log 尾部与重启后 dmesg 时间戳可判断死机时刻。

## 自编译内核流程（Void）
1. 依赖：`gcc bc flex bison rsync cpio xz openssl-devel`（Void 上 openssl-devel 默认没装，缺了 menuconfig/模块签名报错）。
2. 下载：`curl -fLO https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-X.Y.Z.tar.xz`（版本列表看 kernel.org 首页，LTS 系列最后一个小版本即最新安全版）。
3. 配置：`cp /boot/config-<现有内核> .config` 作基线 → 改 `CONFIG_LOCALVERSION="-tag"`（用 sed 直接改 .config；旧内核的 scripts/config 没有 `--set-version-string` 选项）→ `make olddefconfig`。
4. 编译安装：`make -j$(nproc)` → `sudo make modules_install` → `sudo cp arch/x86/boot/bzImage /boot/vmlinuz-<version>`。
5. initramfs：`sudo dracut --force /boot/initramfs-<version>.img <version>`。
6. GRUB：`sudo grub-mkconfig -o /boot/grub/grub.cfg` 自动加 Advanced options 条目（默认项不动，安全）；`grub-reboot '<条目名>'` 可一次性下次启动选择。
7. 第三方模块（如 wl）：`make KBUILD_DIR=/path/to/kernel/source -j4` 指向新内核源码树重编，`modinfo wl.ko | grep vermagic` 必须与新内核版本串完全一致才能 insmod。

## 驱动死机排查方法论（以 broadcom-wl 闭源 blob 为例）
- 分层缩小爆炸面：先用驱动自带降级参数跑（wl 的 `passivemode=1` 不上传固件）区分「固件上传阶段炸」还是「DMA/正常流量炸」；再试 `piomode=1`（PIO 代 DMA）。
- 看 WARN 栈找机制：wl 在 6.18 上 `dma_map_phys` WARN + `osl_dma_map` 栈 = DMA 映射失败前兆；WARN 本身不死但同路径后续真流量会整机冻结。
- 跨内核二分：同一驱动分别对多个内核大版本编译测试（6.1/6.6/6.12/6.18），全挂 = blob 本身与硬件/PCIe 交互问题而非内核回归，别继续追补丁。
- 结论若是闭源 blob 无解：记录进 dotfiles README（防止未来误重装），保留 modprobe blacklist。
