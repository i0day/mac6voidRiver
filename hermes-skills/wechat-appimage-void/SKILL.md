---
name: wechat-appimage-void
description: "Install Weixin on Void from AppImage when no native pkg."
---

# Void Linux 安装微信 (Weixin 4.x 官方 AppImage 解包)

Void 仓库无 wechat 包，官方提供 deb/rpm/AppImage（https://linux.weixin.qq.com/，x86_64: dldir1v6.qq.com/weixin/Universal/Linux/WeChatLinux_x86_64.AppImage）。AppImage 解包安装最干净。

## 步骤
1. `sudo xbps-install -y squashfs-tools`（解包不需要 FUSE 挂载）。
2. 下载 AppImage；用 python 从文件尾向前找 `hsqs` magic 定位 squashfs 偏移（本例 944632），`dd bs=8 skip=<offset/8>` 切出。
3. `unsquashfs -d squashfs-root wechat.sqs`。结构: `opt/wechat/`(主程序+全部自带 .so+RadiumWMPF)、`usr/bin/wechat`(符号链接!)、AppRun、wechat.desktop。
4. `sudo cp -a squashfs-root/opt/wechat/. /opt/wechat/`。**坑**: `usr/bin/wechat` 是 `-> ../../opt/wechat/wechat` 的符号链接，cp -a 过去会自指向死循环（"Too many levels of symbolic links"）。必须 `sudo cp` 真实二进制 `squashfs-root/opt/wechat/wechat`（~181MB）覆盖。
5. 启动器 /usr/local/bin/wechat: `export LD_LIBRARY_PATH=/opt/wechat` + fcitx5 三件套 (XMODIFIERS=@im=fcitx, GTK_IM_MODULE=fcitx, QT_IM_MODULE=fcitx)，exec /opt/wechat/wechat "$@"。
6. desktop 文件改 Exec=/usr/local/bin/wechat %U、Categories=Network;InstantMessaging;，装到 ~/.local/share/applications + 图标 hicolor/256x256/apps。

## 验证
- `ldd /opt/wechat/wechat | grep 'not found'` 应为空（自带 .so 全齐，LD_LIBRARY_PATH 指向 /opt/wechat）。
- 启动后 `xdotool search --class wechat getwindowname %@` 应见 "Weixin" + "WeChatAppEx"。
- 升级 = 重新下载新 AppImage 覆盖 /opt/wechat（用户数据在 ~/.local 不受影响）。
