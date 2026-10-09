---
name: dwm-session-dbus-keyring
description: Use when apps hit secrets-bus timeouts in bare dwm sessions.
---

# dwm 会话的 D-Bus / gnome-keyring 链路

## 症状
Bitwarden 桌面版密码正确却反复登出；`~/.config/Bitwarden/app.log` 出现：
`Failed to activate service 'org.freedesktop.secrets': timed out` → `Access token key not found ... Logging user out`。

## 根因
LightDM 会话残留旧 `DBUS_SESSION_BUS_ADDRESS=/tmp/dbus-*`（dbus-launch 遗留，socket 已被 tmpfiles 清理），
而 keyring/secrets 服务在 systemd 用户总线 `/run/user/1000/bus`。两个总线错开。

## 诊断
1. `tr '\0' '\n' < /proc/<pid>/environ | grep DBUS` 对比 dwm 进程与 keyring 守护所在总线。
2. `busctl --user status org.freedesktop.secrets`（先 export 正确地址）——超时=没挂上；有应答=正常。
3. prelogin 能通（curl Vaultwarden `/identity/accounts/prelogin` 返回 200）说明不是密码/网络问题。

## 修复（~/.xinitrc）
```sh
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"   # 覆盖 LightDM 残留地址
eval "$(gnome-keyring-daemon --start --components=secrets 2>/dev/null)"
```

## 坑
- Bitwarden 新桌面版进程名是 `bitwarden-app`（不是 bitwarden），`pgrep -x bitwarden` 永远匹配不到 → 重复启动。
- `pkill -f bitwarden` / `pkill -f gnome-keyring` 会匹配到自己的 shell 自杀；用精确 PID 或 `[b]itwarden` 括号技巧。
- `pkill -x` 对 >15 字符进程名无效（gnome-keyring-daemon），需 `-f`。
- gnome-keyring-daemon.socket 是 systemd socket 激活，杀掉后按需自启，不必手动常驻。
