# 本机热键完整手册

机器: MacBookAir6,1 · Void Linux (runit+elogind) · dwm 6.5 (Mod4 = Super 键)
更新: 2026-10-06（与旧本合并：补语音输入键、清理 oldmacmint/xbindkeys 残留） · 配置文件: `~/mac6void/dwm/config.h` · `~/.config/sxhkd/sxhkdrc` · `~/.config/fcitx5/config`

约定：下文 **Super** = Windows/Cmd 键 (Mod4)。dwm 改配置后需 `cd ~/mac6void/dwm && make && sudo make install` 并重启 dwm 生效；sxhkd 改后 `pkill -USR1 -x sxhkd` 热重载（xbindkeys 已弃用卸载，不再使用）；fcitx5 改配置必须先停 fcitx5（退出时会重写 conf）。

---

## 一、dwm 窗口管理 (MODKEY = Super)

### 1. 开关窗口
| 按键 | 功能 | 说明 |
|---|---|---|
| Super+Return | 打开终端 (st) | 主力终端 |
| Super+Shift+Return | 呼出/收起下拉终端 | scratchpad "spterm"，再按收起，位置状态保留 |
| Super+q | 关闭当前窗口 | 普通关闭 |
| Super+Shift+q | 电源菜单 (sysact) | 锁定/挂起/重启/关机/注销 |
| Super+f | 全屏 | 当前窗口切全屏 |
| Super+Shift+f | 浮动布局 | 切到 floating（无平铺函数） |

### 2. 焦点与窗口移动
| 按键 | 功能 | 说明 |
|---|---|---|
| Super+j / Super+k | 焦点下移 / 上移 | 在堆栈中循环移动焦点 |
| Super+v | 焦点跳堆栈首位 | |
| Super+Shift+j / Shift+k | 窗口下推 / 上推 | 把当前窗口在堆栈中换位 |
| Super+Shift+v | 窗口推到首位 | |
| Super+h / Super+l | master 区变窄 / 变宽 | mfact ∓0.05 |
| Super+o / Super+Shift+o | master 窗口数 +1 / -1 | nmaster |
| Super+space | zoom | 当前窗口与 master 互换位置 |
| Super+Shift+space | 浮动/平铺切换 | 当前窗口脱离或加入平铺 |
| Super+s | 窗口粘滞 (sticky) | 该窗口跟随所有工作区 |

### 3. 工作区（标签）
| 按键 | 功能 |
|---|---|
| Super+1 … Super+9 | 切换到工作区 n |
| Super+Ctrl+1…9 | 显示/隐藏工作区 n（可多标签同屏） |
| Super+Shift+1…9 | 当前窗口移到工作区 n |
| Super+Ctrl+Shift+1…9 | 给窗口叠加/摘除标签 n（一窗多标签） |
| Super+0 | 查看全部 9 个标签 |
| Super+Shift+0 | 当前窗口打上全部标签 |
| Super+Tab | 回到工作区 1 |
| Super+g / Super+; | 视图向左 / 向右平移一格 |
| Super+Shift+g / Shift+; | 当前窗口跟着视图一起左 / 右移 |
| Super+PageUp / PageDown | 同 g / ;（左移 / 右移） |
| Super+Shift+PageUp / PageDown | 窗口跟视图左 / 右移 |
| Super+Left / Right | 焦点切到左 / 右显示器 |
| Super+Shift+Left / Right | 当前窗口送到左 / 右显示器 |

### 4. 布局切换
| 按键 | 布局 | 图标 |
|---|---|---|
| Super+t | tile 左主右辅（默认） | []= |
| Super+Shift+t | bstack 上主下辅 | TTT |
| Super+y | spiral 斐波那契螺旋 | [@] |
| Super+Shift+y | dwindle 左右递减 | [\] |
| Super+u | deck 主左、其余等分 | [D] |
| Super+Shift+u | monocle 全部叠放 | [M] |
| Super+i | centeredmaster 主居中辅两侧 | \|M\| |
| Super+Shift+i | centeredfloatingmaster 浮动版主窗 | >M> |

### 5. 间隙 (gaps)
| 按键 | 功能 |
|---|---|
| Super+a | 临时关闭全部间隙 |
| Super+Shift+a | 恢复默认间隙 |
| Super+z / Super+x | 所有间隙 +3px / -3px |
| Super+Shift+' | 智能间隙开关（单窗口时自动去外边距） |

### 6. 启动程序
| 按键 | 程序 | 说明 |
|---|---|---|
| Super+d | dmenu_run | 输入即搜启动器 |
| Super+Shift+d | passmenu | pass 密码库自动输入 |
| Super+F8 | rofi 应用菜单 | 带图标 drun |
| Super+w | Firefox 浏览器 | 用户偏好保持 firefox |
| Super+Shift+w | nmtui | 终端 WiFi/网络配置 |
| Super+Shift+r | htop | 进程监视 |
| Super+e | neomutt | 终端邮件 |
| Super+Shift+e | abook | 通讯录 |
| Super+n | Vimwiki 首页 | nvim -c VimwikiIndex |
| Super+Shift+n | newsboat | RSS 阅读器 |
| Super+m | ncmpcpp | 音乐播放器 |
| Super+c | profanity | XMPP 聊天（已弃用可改绑） |
| Super+` (grave) | dmenuunicode | emoji/特殊字符选择进剪贴板 |
| Super+Insert | 文本片段 | 从 ~/.local/share/larbs/snippets 选一条打字出来 |

### 7. 小工具层 (Super+Ctrl)
| 按键 | 工具 | 用法 |
|---|---|---|
| Super+Ctrl+c | dcalc | rofi 计算器，bc 语法，结果自动进剪贴板 |
| Super+Ctrl+q | qrshare | 剪贴板内容生成二维码，通知里扫码 |
| Super+Ctrl+o | ocrpick | 框选屏幕区域 → tesseract 中英 OCR → 剪贴板 |
| Super+Ctrl+s | sleeptimer | 输入分钟数定时提醒；再按一次可取消 |
| Super+Ctrl+r | redshift-toggle | 护眼色温开/关 |
| Super+Ctrl+b | bt-toggle | 蓝牙 rfkill 秒开秒关 |
| Super+Alt+b | bt-earbud | dmenu 切换蓝牙耳机（见下方「蓝牙耳机切换说明」），含 bluetui 完整 TUI 入口 |
| Super+Ctrl+t | touchpad-toggle | 触摸板开/关（bcm5974 专用） |
| Super+Ctrl+e | dwm-quit | 退出 X 回 tty1（一次性旗标阻止自动重登拉起；再进桌面输 `startx`） |

### 蓝牙耳机切换说明 (Super+Alt+b → bt-earbud)

菜单列出已配对设备，条目显示 `名称 (MAC) [已连接/未连接 🔋电量]`：
- **未连接** → 连接，随后自动：等 PipeWire `bluez_card` 出现 → profile 停在 `off` 时激活 `a2dp-sink`（高音质）→ 设为默认输出。通知带当前音质档名（aptX / AAC / SBC 等）。
- **已连接** → 断开。
- `🛠 bluetui`：完整蓝牙 TUI（重配对、改设置用它）；`⏻ rfkill`：蓝牙总开关（等效 Super+Ctrl+b）。

排障：
- 「已连接但不响」根因是 PipeWire 卡 profile=`off`（sink 不存在）。脚本已自动处理；手动修：
  `pactl set-card-profile bluez_card.<MAC下划线> a2dp-sink && pactl set-default-sink bluez_output.<MAC下划线>.1`
- 连接报 `br-connection-key-missing` = 配对密钥失效：`bluetoothctl remove <MAC>`，耳机放盒开盖长按功能键至白灯交替闪烁，重新 pair/trust/connect。
- 已验证机型：Soundcore Liberty Air 2（98:52:3D:DF:A6:32）。

### 8. 音量 / 电源 / 显示
| 按键 | 功能 |
|---|---|
| Super+- / Super+Shift+- | 音量 -5% / -15% |
| Super+= / Super+Shift+= | 音量 +5% / +15% |
| Super+Shift+m | 静音切换 |
| Super+BackSpace | sysact 电源菜单（同 Super+Shift+q） |
| Super+p | powermenu（rofi 版电源菜单） |
| Super+Shift+p | wifimenu WiFi 菜单 |
| Super+[ | caffeine 禁止休眠 |
| Super+] | 解除禁止休眠 |
| Super+F3 | displayselect 外接屏模式切换 |
| Super+F4 | pulsemixer 终端音量配置 |
| Super+F5 | 重载 Xresources（换主题色） |
| Super+F9 | mounter U盘挂载菜单 |
| Super+F10 | unmounter U盘卸载 |
| Super+F11 | mpv 打开摄像头 |
| Super+F1 | LARBS 帮助手册 (PDF) |
| Super+F2 | 下拉计算器 scratchpad (spcalc, bc) |

### 9. 截图 / 录屏
| 按键 | 功能 |
|---|---|
| Print | 全屏截图存 ~（maim） |
| Shift+Print | maimpick：菜单选 全屏/选区/窗口，存 ~/Pictures |
| Super+Print | dmenurecord 开始录屏 |
| Super+Shift+Print | 停止录屏 |
| Super+Del | 停止录屏（同上，备用） |
| Super+ScrollLock | screenkey 按键上屏开关（录教程用） |

### 10. 鼠标操作
| 操作 | 功能 |
|---|---|
| Super+左键拖动 | 移动窗口 |
| Super+右键拖动 | 缩放窗口 |
| Super+滚轮 | 间隙 +1 / -1 |
| Super+中键 | 重置默认间隙 |
| 标签栏 左键 | 切到该标签 |
| 标签栏 右键 | 显示/隐藏该标签 |
| 标签栏 滚轮 | 视图左右平移 |
| Super+标签栏 左键 | 当前窗口打到该标签 |
| Super+标签栏 右键 | 窗口叠加/摘除该标签 |
| 状态栏 左/中/右键、滚轮 | 触发对应 dwmblocks 模块刷新/动作 |
| 状态栏 Shift+右键 | 编辑 dwmblocks 配置 |
| 标题栏 中键 | zoom 当前窗口 |
| 桌面 中键 | 显示/隐藏 bar |

---

## 二、sxhkd 全局快捷键 (~/.config/sxhkd/sxhkdrc)

xbindkeys 已弃用卸载，统一 sxhkd（@前缀=按下触发）。改后 `pkill -USR1 sxhkd` 热重载，USR2 暂停/恢复。

### 启动应用
| 按键 | 程序 |
|---|---|
| Ctrl+Alt+b | Brave 浏览器 |
| Ctrl+Alt+k | ~/term 终端 |
| Ctrl+Alt+l | Thunar 文件管理器 |
| Ctrl+Alt+t | Transmission-qt 下载 |
| Ctrl+Alt+d | ~/bt 种子下载脚本 |
| Ctrl+Alt+a | ~/cliptask |
| Ctrl+Alt+n | blueman 蓝牙管理器 |
| Ctrl+Alt+p | pavucontrol 音量面板 |
| Super+Shift+b / h | st 内 btop / htop |

### 剪贴板 / 效率
| 按键 | 功能 |
|---|---|
| Ctrl+Alt+c | clipmenu 剪贴板历史选择 |
| Ctrl+Alt+y | paste-type：把剪贴板逐字"打字"进输入框（对付不认粘贴的框） |
| Ctrl+Alt+g | gsearch：选中文字 → Google 搜索 |
| Ctrl+Alt+o | openurl：剪贴板里的 URL 直接用浏览器打开 |

### 通知 / 系统
| 按键 | 功能 |
|---|---|
| Ctrl+Alt+s | dunst-quiet 勿扰模式（暂停/恢复所有通知） |
| Ctrl+Alt+z | dunst-clear 清空当前所有通知 |
| Ctrl+Alt+f | wifi-toggle WiFi 秒开/秒关 |
| Ctrl+Alt+e | saysel 朗读选中文字（edge-tts 真人语音，中英自动切换） |
| Ctrl+Alt+Shift+e | 停止朗读 (pkill sd-edge-tts) |
| Ctrl+Alt+Shift+r | reader 阅读模式后备脚本（about:reader 等效） |
| Super+Ctrl+v | voice-ctl 语音输入：按下录 6 秒 → whisper.cpp 本地识别 → 粘贴到光标 |
| Ctrl+Super+Space | fcitx5 原生输入法循环：言泉→拼音→Rime（唯一入口） |
| Eject 键 | Vaultwarden 备份拉取 + 通知 |

### 无头音乐 / 专注 / 传文件 (Super+Ctrl 系)
| 按键 | 功能 |
|---|---|
| Super+Ctrl+m | mpc toggle 播放/暂停 (MPD) |
| Super+Ctrl+, | st 打开 ncmpcpp（含频谱可视化） |
| Super+Ctrl+. / / | 下一首 / 上一首 |
| Super+Ctrl+; | 静音 |
| Super+Ctrl+f | focus 番茄钟 25 分钟（自动静音通知+暂停音乐，到时叮声提醒；再按=取消恢复） |
| Super+Ctrl+Shift+f | sendfile 一键传文件到手机（fzf 选文件→局域网直传+二维码，10 分钟有效，关窗即停；`sendfile-stop` 手动停） |

无头音乐栈配置: `.config/mpd/mpd.conf`（PipeWire 输出 + /tmp/mpd.fifo 可视化）、`.config/ncmpcpp/config`。守护进程手动 `mpd ~/.config/mpd/mpd.conf` 或 `mpd-toggle` 开关。

### Firefox 原生 Ctrl+Alt+R（阅读模式）
Void 的 Firefox 构建 `MOZILLA_OFFICIAL=false`，会注入 "Restart (Developer)" 抢占 Ctrl+Alt+R，
导致原生阅读模式失效、按了变重启。已用 `firefox-patch/` 里的补丁禁用该注入键，
原生 Ctrl+Alt+R 恢复为阅读模式。**注意：xbps 升级 firefox 会覆盖补丁，复发时按
`firefox-patch/README` 重新套用。**

---

## 三、fcitx5 输入法 (~/.config/fcitx5/config)

| 按键 | 功能 |
|---|---|
| Ctrl+Space | 激活 / 停用输入法（在英文和中文间切） |
| Ctrl+Super+Space | 循环切换输入法：cassotis(言泉) → pinyin → rime(雾凇) → … |
| Alt+Ctrl+n / Alt+Ctrl+Shift+n | 向前 / 向后枚举输入法（备用） |

- 输入法循环顺序由 `~/.config/fcitx5/profile` 的 Groups/Items 决定。
- 原 Ctrl+Super+O / Ctrl+Super+P（激活/停用）**已删除**——与 dwm 的 ocrpick (Super+Ctrl+O) 撞键。
- 改输入法配置的正确姿势：先 `pkill -x fcitx5`，改文件，再 `fcitx5 -d`（运行中改会被退出时重写覆盖）。

---

## 四、硬件 / 多媒体键（无需修饰键）

| 按键 | 功能 |
|---|---|
| F5 / F6 (背光) | Apple 键盘背光 减 / 增 (kbdbrightness) |
| 屏幕亮度键 | changebrightness 降 / 升 + 状态栏刷新 |
| 音量 +/− / 静音 | volume.sh +5% / -5% / 切换静音 |
| 麦克风键 | 麦克风静音切换 (pactl) |
| 播放 / 暂停 / 停止 | mpc play / pause / stop |
| 上一首 / 下一首 | mpc prev / next |
| 快退 / 快进 | mpc seek ∓10s |
| AudioMedia 键 | ncmpcpp |
| Calculator 键 | st -e bc |
| WWW 键 | 浏览器 |
| DOS 键 | 终端 |
| Mail 键 | neomutt |
| MyComputer 键 | st -e lfub / （文件管理） |
| TaskPane 键 | htop |
| Sleep 键 | 挂起 (zzz) |
| ScreenSaver 键 | slock 锁屏 + 关屏 + 暂停所有播放器 |
| Launch1 | 直接关屏 (xset dpms force off) |

---

## 五、注意事项 / 已知坑

1. **dwm 改键生效流程**：编辑 `~/mac6void/dwm/config.h` → `make && sudo make install` → 注销重进（当前运行中的 dwm 不会自动换）。
2. **sxhkd 失效恢复**：热键突然不响应时确认进程在 `pgrep -x sxhkd || sxhkd -c ~/.config/sxhkd/sxhkdrc &`；改配置后 `pkill -USR1 -x sxhkd` 热重载。（旧 xbindkeys 已弃用卸载，Super+Ctrl+i imnext、Ctrl+Alt+v virt-manager、Rhythmbox 等 Mint 旧绑定未迁移。）
3. **fcitx5 退出重写 conf**：任何配置改动都要先停 fcitx5 再改文件。
4. **撞键已清理**：Super+Ctrl+O 现归 ocrpick 独占（fcitx5 的 activate 键已删）。
5. **Super+Ctrl+i (fcitx5-imnext) 已废弃**：输入法循环统一走 fcitx5 原生 Ctrl+Super+Space
   （EnumerateForwardKeys）。旧 xbindkeys 绑定随 xbindkeys 卸载消失，sxhkd 未接管该键；
   `~/.local/bin/fcitx5-imnext` 脚本保留但无键绑定，需要时可重新绑。
6. 键位分层逻辑：**Super 单层/Shift = dwm 窗口操作**；**Super+Ctrl = 小工具**；**Ctrl+Alt = 日常应用与剪贴板**；**Ctrl+Space 系 = 输入法**；**硬件键 = 音量亮度播放**。
