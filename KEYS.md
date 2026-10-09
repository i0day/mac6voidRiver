# mac6void 热键清单 & 定制说明

机器: MacBookAir6,1 · Void Linux (runit+elogind) · dwm (Mod4=Super)

## 一、dwm 内置热键 (dwm/config.h)
| 键 | 功能 |
|---|---|
| Super+Enter | 开终端 (st) |
| Super+P | 电源菜单 (rofi powermenu) |
| Super+BackSpace / Super+Shift+Q | sysact 电源菜单 |
| Super+Shift+P | WiFi 菜单 (wifimenu.sh) |
| Super+Q | 关闭当前窗口 |
| Super+W | 开浏览器 (brave-browser) |
| Super+Tab | 切回 tag 1 |
| Super+1..9 / 0 | 切 tag / 全部 tag |
| Super+Ctrl+1..9 | 显示/隐藏 tag (多标签同屏) |
| Super+Shift+1..9/0 | 窗口打 tag |
| Super+T/Y/U/I | tile / bstack / spiral / dwindle 布局 |
| Super+Shift+T/Y/U/I | bstack / dwindle / monocle / centeredfloatingmaster |
| Super+O / Shift+O | master 数量 +1/-1 |
| Super+H/L | master 区宽度 -0.05 / +0.05 (mfact) |
| Super+J/K | 堆栈内移动焦点 (Shift 推窗口, V 跳首位) |
| Super+Space / Shift+Space | zoom 主窗互换 / 浮动切换 |
| Super+G / ; | 视图左移 / 右移 (Shift 带窗口同行) |
| Super+Grave | dmenuunicode (符号选择) |
| Super+Shift+R | htop |
| Super+Shift+W | nmtui (终端网络配置) |
| Super+Ctrl+T | 触摸板开关 |
| Super+Ctrl+R | redshift-toggle (色温) |
| Super+Ctrl+C / Q / O / S | dcalc 计算器 / qrshare 二维码 / ocrpick 截屏OCR / sleeptimer 定时提醒 |
| Super+- / = (Shift=15%) | 音量 -5% / +5% |
| Super+Shift+M | 静音切换 |
| Super+Print / Shift+Print | 全屏截图 / maimpick 选区截图 |
| Super+Ctrl+B | bt-toggle 蓝牙开关 |

## 二、sxhkd 热键 (~/.config/sxhkd/sxhkdrc)
全部 `@` 前缀 = 松开触发（防按住连发）。改后 `pkill -USR1 -x sxhkd` 即时生效。

| 键 | 功能 |
|---|---|
| Ctrl+Super+I | fcitx5 输入法循环: 言泉cassotis→拼音→rime雾凇 |
| Ctrl+Alt+C | 剪贴板历史 (clipmenu/cliphist) |
| Ctrl+Alt+S | 勿扰开关 (dunst 暂停/恢复) |
| Ctrl+Alt+Z | 清空所有通知 |
| Ctrl+Alt+G | 选中文字 → Google 搜索 |
| Ctrl+Alt+O | 剪贴板 URL → 浏览器直开 (ff-open) |
| Ctrl+Alt+Y | 剪贴板内容"打字"进输入框 |
| Ctrl+Alt+F | WiFi 秒开/秒关 (rfkill) |
| Eject | Vaultwarden 备份拉取 (rsync oldmac:/opt/backups) |

## 三、fcitx5 输入法
- Ctrl+Space 开关输入法
- Ctrl+Super+Space 循环切换输入法 (EnumerateForwardKeys)
- 循环顺序: cassotis(言泉) → pinyin → rime(雾凇) → 英文
- 原 Ctrl+Super+O/P (激活/停用) 已删除：与 dwm 的 ocrpick (Super+Ctrl+O) 撞键
- 云拼音「来自云」标签补丁 (源码重编译 ~/src/fcitx5-chinese-addons)
- 主题随 pywal 联动 (wal on_change 50-fcitx5.sh)

## 四、本机定制要点 (相对 oldmacmint/Mint 仓库)
1. **xbindkeys → sxhkd**: xbindkeys grab 会静默失效 (Firefox 切不了输入法)；
   sxhkd 0.6.3 grab 稳定，支持 `@`=release 触发、`~`=事件转发
2. **powermenu**: Void 无 systemd → `sudo -n /usr/sbin/reboot|poweroff`，挂起 `zzz`；
   rofi 2.0 + power.rasi 仓库主题
3. **xinitrc**: 弃用 dbus-launch (socket 被 tmpfiles 清理导致总线静默死)，
   直连 systemd 用户总线；gnome-keyring secrets (Bitwarden 需要)；
   sctd 夜间色温 (替代 redshift.service，Void 无 systemd --user)
4. **dunst 1.13**: 区间语法 `height = (0, 340)`，只认 [global]
5. **rofi 2.0**: 仓库全套主题 (topbox 布局 + colors.rasi 墨青配色) + Papirus 图标
6. **字体**: 霞鹜文楷屏幕版 v1.522 (sans/mono) + JetBrainsMono Nerd Font +
   Roboto/Inconsolata (xbps)；fontconfig strong alias
7. **触摸板**: bcm5974 设备 clickfinger 模式 (1指左/2指右)，tap-to-click 开机自开
8. **wl 驱动已移除**: BCM4360 闭源 blob 在 6.6/6.12/6.18 均死机
   (dma_map_phys WARN → 整机冻结)，blacklist 保留防止误加载

## 五、已知坑
- sxhkd 松开触发是 `@keysym` 前缀，**不是** `:release` 后缀 (写错=静默不注册)
- xbindkeys 若回退使用: grab 失效需 `pkill -x xbindkeys && xbindkeys`
- fcitx5 退出时会重写 conf，改配置须先停 fcitx5
- Void 无 systemctl/loginctl 授权: 电源操作全部 sudo -n
