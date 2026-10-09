---
name: x11-hotkey-notify-daemons
description: "Debug X11 hotkeys, dunst notify, sxhkd grab conflicts."
---

# X11 热键 + dunst 通知 + sxhkd 守护进程调试

## When to Use

- Adding sxhkd hotkeys that "don't work", dunst notifications that never appear, or daemons (sxhkd/MPD etc.) whose keybindings silently misbehave on dwm/X11.

## Always-on rules

- **通知要在静音状态下仍可见，必须带 `-h int:transient:1`，且先发通知再 `dunstctl set-paused true`。** dunst 暂停期间普通通知永久不可见——脚本照跑但屏幕无反馈，用户断定热键失灵（`pgrep` 能看到堆积的脚本进程就是铁证：触发成功了，只是看不见）。
- **sxhkd 配置改了没有生效，先数实例再谈配置**：`pgrep -a sxhkd`。若此前某条命令在 `pkill -USR1` 重载之前就死了（如被 pkill 误杀），重载从未执行——旧实例仍持旧配置，再起新实例会导致对所有键报 "already grabbed"，全键变死键。修复：`pkill -x -TERM sxhkd` 清空全部实例，等 1 秒确认 `pgrep` 为空，再起单实例。
- **验证 grab 是否成功看 sxhkd 启动 stderr**：用 `background=true` 起 `exec sxhkd ... 2>/tmp/err.log`，再 grep 对应 keysym。keysym 对照：f=41, 逗号=51 附近；modfield 12=Super+Ctrl，14/28/30=加 Shift/NumLock 变体。0 条失败记录 = 绑定成功，此后"不工作"要查脚本层而不是 X 层。
- **st 新窗口继承终端残留按键：绝不能用 `read _` 等按键关闭刚从 fzf 交权的窗口**。上一级 fzf 的 Enter 会立即被 `read` 吞掉 → 窗口瞬关连带清理逻辑秒杀自己的服务（表现：下游 UI「完全没出现」）。用 `sleep N` 定时关闭 + `trap 'kill ...' EXIT` 兜底。
- **测试会 fork 后台计时/守护子进程的脚本，调用侧必须 stdout/stderr=DEVNULL**：子进程继承管道会使 `subprocess.run` 阻塞到计时结束，所有断言实际在「计时完成后」的状态执行，测试假阴性且极慢。

## Pitfalls
- **「切换」类脚本只会单向切换（如 WiFi 只能关不能开），几乎都是状态解析 bug 而不是逻辑 bug**：先跑一次原始命令看真实输出格式再写解析——`rfkill list wlan` 首行是 `0: phy0: Wireless LAN`（不含小写 wlan，且状态在后续缩进行 `Soft blocked: yes/no`），任何按首行取字段的解析都读不到状态、恒走 else 分支。正确做法：grep `blocked: yes` 行判定，改完连按两次并对照 `rfkill list` 验证双向都翻转。
- **用户报「通知不显示了」而 dunst 进程活着：第一步查 `dunstctl is-paused`**——暂停态下 dunst 静默吞掉所有普通通知（history 还能进），`dunstctl set-paused false` 即恢复，别急着怀疑配置或重启 dunst。
- 用户报「热键没反应」时先用 xdotool 模拟按键端到端验证（`xdotool key super+ctrl+f` 后检查副作用状态），区分 X 层 grab 问题与脚本可见性问题，别急着怀疑键位冲突。
- `sxhkd -c` 自定义路径配置；USR1=重载配置，USR2=切换 grab 开关（来自 man sxhkd）。
- 手机扫局域网二维码打不开而本机服务正常时：查路由器 AP 隔离，本机 iptables ACCEPT 不代表路由层放行。