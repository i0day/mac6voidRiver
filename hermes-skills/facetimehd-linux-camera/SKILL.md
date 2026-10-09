---
name: facetimehd-linux-camera
description: MacBook FaceTime HD webcam on Linux, no /dev/video* yet.
---

# MacBook FaceTime HD 摄像头 Linux 驱动 (facetimehd)

Mac 的 FaceTime HD 是 Broadcom PCIe 摄像头（lspci: "Broadcom 720p FaceTime HD Camera"），内核无原生驱动，`/dev/video*` 不存在。需第三方 bcwc_pcie 驱动 + 从 macOS 提取的固件。

## 步骤 (Void Linux 实测, kernel 6.18)
1. 固件: clone `patjak/facetimehd-firmware`，`make`（提取 firmware.bin + 11 个 sensor 校准 .dat），`sudo ./facetimehd-firmware-install.sh` → 装到 `/usr/lib/firmware/facetimehd/`（注意子目录，不是直接放 /usr/lib/firmware 根）。
2. 驱动: clone `patjak/bcwc_pcie`，需 kernel-headers 匹配运行内核。直接 `make -j4` 即可（dkms.conf 存在但手动装更简单）。
3. 安装: `sudo cp facetimehd.ko /usr/lib/modules/$(uname -r)/extra/ && sudo depmod -a $(uname -r)`。
4. 自动加载: `echo facetimehd | sudo tee /etc/modules-load.d/facetimehd.conf`；**必须 blacklist bdc_pci**（会抢设备）: `echo blacklist bdc_pci | sudo tee /etc/modprobe.d/facetimehd.conf`。
   坑: conf 文件内容必须只有模块名一行。若误写成 `echo facetimehd`（把 tee 命令本身写进文件），Void 的 modules-load 会把 "echo" 当模块名传给 modprobe，开机报 `modprobe: FATAL: Module echo not found`（facetimehd 本身仍会加载，摄像头正常）。排查: `od -c /etc/modules-load.d/facetimehd.conf`。
5. `sudo modprobe facetimehd` → `/dev/video0` 出现。用户在 video 组即可用。

## 验证
- `ffmpeg -f v4l2 -list_formats all -i /dev/video0` 应列 1280x720 YUYV。
- 抓帧: `sg video -c "ffmpeg -f v4l2 -video_size 1280x720 -i /dev/video0 -frames:v 1 out.jpg"` — 非黑屏即成功。当前 shell 组不含新加的 video 组时用 `sg video -c` 绕过重新登录。

## 坑
- 只支持 1280x720；YVYU 格式 ffmpeg 报 Unsupported 是正常的（YUYV 可用）。
- 内核升级后要重编译模块（Void 无 dkms hook 自动跑的话）。
- 固件 install 脚本装到 `facetimehd/` 子目录，找文件别在 /usr/lib/firmware 根目录找。