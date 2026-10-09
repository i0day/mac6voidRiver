---
name: sxhkd-script-hotkey-debugging
description: "Debug sxhkd-launched scripts that silently fail or die."
---

# sxhkd 热键脚本静默失败排查

适用于: 终端手动跑正常、sxhkd 热键跑不出效果/进程神秘消失的所有场景。

## 第一步永远是加追踪
脚本头部注入，不猜: `exec >>/tmp/<name>-debug.log 2>&1` + `set -x`。热键环境的差异全部现形。

## 热键环境的四大差异（挨个排）
1. **PATH 不含 ~/.local/bin、/usr/local/bin** → 脚本自 `export PATH="$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:$PATH"` 兜底
2. **无 tty**: fzf/ncurses 类程序裸调静默失败 → 热键包一层 `st -e <cmd>`
3. **notify-send 可能失败**（无 DBUS_SESSION 等）且 `set -e` 会中断脚本 → 关键 UI（弹窗）放在 notify 之前，notify 行尾 `2>/dev/null || true`
4. **SIGHUP 连坐（最阴险）**: dash 无 job control，后台子进程与 shell 同进程组；触发窗口（如 st -e fzf）关闭时 SIGHUP 杀掉整个进程组的后台服务。症状=弹窗活着但服务已死/扫旧码连不上。**所有后台服务必须 `setsid <cmd> &` 起**

## 验证法（不靠肉眼）
- 模拟热键完整链路: `script -qec "<cmd>" /dev/null` 造 pty，跑完窗口退出后查服务进程是否存活（`pgrep -af <svc>`）
- grab 失败检查: 杀干净后 `sxhkd -c <rc> 2>/tmp/err.log` 前台重起，grep "Could not grab"；0 条=键位没冲突
- **sxhkd 重载陷阱**: `pkill -USR1 -x sxhkd` 若前面命令被 SIGTERM 中断，USR1 根本没发出——旧实例还在跑旧配置。核对 `pgrep -a sxhkd` 只有一个实例且启动时间在配置修改之后

## 通知穿透静音
发通知前若已 `dunstctl set-paused true`，普通通知永远不可见（症状=功能生效但屏幕无反应）。加 `-h int:transient:1` 让通知穿透 paused 状态，或先发通知再静音。

## pkill 自杀坑（反复出现）
`pkill -f <pattern>` 会匹配到含同样字符串的自身包装进程，把自己的命令 SIGTERM 掉。改用 execute_code + 逐 pid 读 `/proc/<pid>/cmdline` 验证真身再 kill，或 `pkill -x <精确进程名>`。

## 定时清理超时设宽
二维码/一次性窗口服务的 sleep 超时别设 90 秒——用户扫码常超。设 600 秒；配合「每次启动先 pkill 残留服务」防旧服务占端口导致新 token 对不上（扫码 404 nothing matches 即新码对旧服务）。

## 网络层二分诊断
让用户手机浏览器直接输 URL: 收到任何 HTTP 响应页(含404)=网络通(查代码/服务生命周期)；连接超时=路由隔离(AP isolation)或 URL/IP 已失效，代码层无解。