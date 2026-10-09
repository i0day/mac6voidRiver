---
name: yazi-ueberzugpp-void
description: Set up yazi image/PDF/video preview on Void X11.
---

# yazi + ueberzugpp 终端图片/PDF/视频预览（Void X11）

## 安装 ueberzugpp（Void 仓库没有此包）
- openSUSE 的 deb **不能用**：依赖 opencv 406/fmt9/spdlog1.12，Void 是 opencv 4.12/fmt12/spdlog1.17，ABI 不匹配（ldd 一堆 not found）。
- 正确做法 = 源码编译：`git clone --depth 1 github.com/jstkdng/ueberzugpp`，依赖 `xbps-install cmake libvips-devel libsixel-devel chafa-devel tbb-devel libxcb-devel xcb-util-image-devel pkg-config`（注意包名是 `tbb-devel` 不是 libtbb-devel），`cmake -DENABLE_OPENCV=OFF ..`（关 OpenCV 省依赖）+ `cmake --build . -j4`（4G 内存约 2-3 分钟），产物 `build/ueberzug` 拷成 `/usr/local/bin/ueberzugpp`。
- GitHub release 页面**没有二进制资产**，别浪费时间找。

## yazi 配置要点（~/.config/yazi/yazi.toml）
- yazi 在 X11 下自动选 X11 adapter（st 无 sixel 也走 ueberzugpp overlay），无需显式指定协议；只要 `ueberzugpp` 在 PATH + DISPLAY 存在。
- 高分辨率：`[preview] max_width/max_height = 1600`，`image_quality = 90`，`image_filter = "lanczos3"`。偏移用 `ueberzug_offset = [x,y,w,h]`。
- 依赖分工：图片=ueberzugpp(vips)；视频缩略=ffmpegthumbnailer；PDF 首页=pdftoppm(poppler-utils)；兜底 ASCII=chafa。Void 都要显式装。

## 验证方法（无 PTY 环境 yazi --debug 报 ioctl 错，别用）
- `st -e yazi <dir>` 后台起 → `pgrep -a ueberzugpp` 看到 `ueberzugpp layer -so x11` = adapter 已选中 → xdotool 激活窗口按 Down 移到图片 → `maim` 截图看预览区有真图像。
- 测完 `pkill -f 'st -e yazi'`，ueberzugpp layer 随 yazi 退出自动清理。
