# .bash_profile

# Get the aliases and functions
[ -f $HOME/.bashrc ] && . $HOME/.bashrc

# Hermes Agent command
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac

# 自动启动 X（tty1 自动登录后直接进 dwm）
# 条件：交互式 shell、在 tty1、非 SSH、X 还没跑
if [ -f "$HOME/.cache/x_stop" ]; then
    # 一次性旗标：dwm-quit / sysact 注销 设置的，跳过本次自动 startx，留在 tty1 shell。
    rm -f "$HOME/.cache/x_stop"
    echo "[.bash_profile] X 已手动停止，留在 tty1。要再进 dwm 直接输: startx"
elif [ -z "$SSH_CLIENT" ] && [ -z "$SSH_TTY" ] && \
   [ "$(tty)" = "/dev/tty1" ] && ! pgrep -x Xorg >/dev/null 2>&1 && ! pgrep -x river >/dev/null 2>&1; then
    # 开机会话选择：1=dwm(X11) 2=river(Wayland)；10 秒无选择默认 dwm。
    # 教训(2026-10-05): 不用 exec——会话秒挂时 exec 已吞掉登录 shell，
    # agetty 重生后 tty1 只剩光标，无法排查。
    choice=""
    if command -v fzf >/dev/null 2>&1; then
        choice=$(printf '1\tdwm  (X11)\n2\triver (Wayland)\n' \
            | timeout 10 fzf --height=6 --reverse --no-info \
                --header='选择会话（10s 后默认 dwm）' \
                --prompt='> ' 2>/dev/null | cut -f1) || choice=""
    fi
    case "$choice" in
        2)
            river-run
            rc=$?
            [ $rc -ne 0 ] && echo "[.bash_profile] river-run failed (rc=$rc). 留在 shell 里排查（常见: 缺 seat/DRM 权限, river -l debug 看日志）。" || exit
            ;;
        *)
            startx
            rc=$?
            if [ $rc -ne 0 ]; then
                echo "[.bash_profile] startx failed (rc=$rc). 留在 shell 里排查（常见: xauth 缺失、.xinitrc 报错）。"
            else
                exit
            fi
            ;;
    esac
fi
