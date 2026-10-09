---
name: void-x-session-autologin
description: 本机 tty1 自动登录拉起 X 的链路；杀 dwm 会重启，退出回 tty1 用旗标。
---

# Void 机 tty1 自动登录 → X 会话生命周期

## When to Use
- 用户报告「kill/pkill dwm 后 dwm 又重启」「想退出 X 回 tty1」。
- 修改 tty1 自动登录、自动 startx、或 dwm 退出/注销相关脚本（dwm-quit、sysact、.bash_profile、.xinitrc）。
- 需要理解本机 X 会话拉起/退出链路做诊断。

## 链路（为什么会「杀不死」）
runit `agetty-tty1`（`/etc/sv/agetty-tty1/conf`：`GETTY_ARGS="-a james --noclear"` 自动登录）→ `.bash_profile` 检测 tty1 且无 Xorg 就 `startx` → `.xinitrc` `exec dwm`。任何一环里 kill dwm/Xorg 都会让整链自动重来：dwm 退出 → startx 退出 → 登录 shell 结束 → agetty 重生 → 又自动登录 → 又 startx。所以 `pkill dwm` 表现为「dwm 重启」。

## 想真正退出 X 留在 tty1：一次性旗标
`~/.bash_profile` 在自动 startx 前先查 `~/.cache/x_stop`：存在则删除、打印提示、留在 shell。旗标一次性，重启后照常自动进桌面。
- `~/.local/bin/dwm-quit`：`touch ~/.cache/x_stop; pkill -x dwm`（dwm 热键 Super+Ctrl+E 调它）。
- `sysact` 注销 分支同样先 touch 旗标。
- 再进桌面：tty1 shell 里直接 `startx`。

## 诊断顺序（遇到「X 杀不掉/自动重开」）
1. `cat /etc/sv/agetty-tty*/conf` 看 `-a <user>` 自动登录在哪个 tty。
2. 读 `~/.bash_profile` / `.profile` 找条件 startx（判据：tty、SSH、pgrep Xorg）。
3. 改「是否自动拉起」的逻辑一律放旗标文件，别改 agetty 服务本身——自动登录还要留给正常开机。

## 坑
- 别用 `exec startx`：startx 秒挂时 exec 吞掉登录 shell，agetty 重生后 tty1 只剩光标无法排查（.bash_profile 已按此写成非 exec）。
- LightDM 机器上自动登录优先级不同（AccountsService > .dmrc > lightdm.conf）；本机是裸 startx 链，无 LightDM。
- dwm 改 config.h 后须 `cd ~/oldmacmint/dwm && make && sudo make install`（live 二进制在 /usr/local/bin/dwm），运行中的 dwm 仍是旧二进制直到重启；config.h 要另 cp 同步进 ~/mac6void 仓库。
- 多行中文 commit message 别内嵌进 execute_code 的 terminal() 字符串（换行破坏 Python 字面量）：write_file 到 scratch 再 `git commit -F <file>`。
