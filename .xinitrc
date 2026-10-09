export PATH="$HOME/.local/bin:$PATH"
# --- session bus 必须先于 fcitx5 建立 ---
# 教训(2026-10-04): fcitx5 曾在 DBUS_SESSION_BUS_ADDRESS 导出之前启动，
# 无总线实例照样抢走 X 键盘过滤，Ctrl+Space 被它吞掉，浏览器里输入法全哑。
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
# 自愈：runtime dir 可能被别的 tmpfs 挂载遮蔽/清空（2026-10-05 实际发生：
# 一个 none tmpfs 挂在 /run/user 上盖住了 elogind 的 /run/user/1000）。
# 目录不可写就用 sudo -n 重建，保证后面 dbus-daemon/keyring 有落脚处。
if [ ! -w "$XDG_RUNTIME_DIR" ]; then
    sudo -n mkdir -m 700 -p "$XDG_RUNTIME_DIR" 2>/dev/null \
      || sudo mkdir -m 700 -p "$XDG_RUNTIME_DIR"
    sudo -n chown "$(id -u):$(id -g)" "$XDG_RUNTIME_DIR" 2>/dev/null || true
fi
[ -S "$XDG_RUNTIME_DIR/bus" ] || dbus-daemon --session --address="unix:path=$XDG_RUNTIME_DIR/bus" --fork --print-address >/dev/null
export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"
export GTK_IM_MODULE=fcitx5
export QT_IM_MODULE=fcitx5
export XMODIFIERS=@im=fcitx
# 自愈：若已有 fcitx5 但它是「无总线」实例（环境缺 DBUS_SESSION_BUS_ADDRESS），
# 它会抢走 X 键盘过滤导致 Ctrl+Space 失效——杀掉重启成带总线的。
for p in $(pgrep -x fcitx5); do
  if ! tr '\0' '\n' < /proc/$p/environ 2>/dev/null | grep -q '^DBUS_SESSION_BUS_ADDRESS='; then
    kill "$p" 2>/dev/null
  fi
done
sleep 1
pgrep -x fcitx5 >/dev/null || fcitx5 -d
pgrep -x sxhkd >/dev/null || sxhkd -c ~/.config/sxhkd/sxhkdrc &
# fcitx4 已停用，改用 fcitx5 + Cassotis 言泉（本地 LLM 补全）
# pgrep -x fcitx >/dev/null || fcitx -d
#setxkbmap -option caps:swapescape
#xset r rate 300 50
#amixer sset Master unmute
#amixer sset Master 1000
picom --config ~/picom/picom.conf -b 2>/dev/null || picom -b  # Mint 的 picom 10.2 已移除 --experimental-backends
# 夜间色温改用 sctd（Void 无 systemd --user，旧 redshift.service 已废弃删除）
pgrep -x sctd >/dev/null || sctd --latitude 40.7128 --longitude -74.0060 >/dev/null 2>&1 &
~/.fehbg &
pipewire & pipewire-pulse & wireplumber &
~/.local/bin/sbar &
#sxhkd &
# Add this to your .xinitrc or whatever file starts programs on startup.
# -R restores the last colorscheme that was in use.
wal -R
/usr/lib/policykit-1-gnome/polkit-gnome-authentication-agent-1 &
# 不再用 dbus-launch：它的 /tmp/dbus-* socket 会被 systemd-tmpfiles 清理，
# 长跑会话的 session bus 会静默死掉（notify-send 连不上就是这个原因）。
# Void/runit 无 systemd 用户总线——上面顶部已手动拉起 dbus-daemon 并导出地址。
# gnome-keyring: Bitwarden 需要 org.freedesktop.secrets，裸 dwm 会话不会自动拉起
# keyring 子目录必须先存在，否则报 control socket 缺失、secrets 组件起不来
mkdir -p "$XDG_RUNTIME_DIR/keyring"
eval "$(gnome-keyring-daemon --start --components=secrets 2>/dev/null)"
export SSH_AUTH_SOCK="${SSH_AUTH_SOCK:-$XDG_RUNTIME_DIR/keyring/ssh}"
# Bitwarden 不再开机自启（用户手动运行）
# pgrep -x bitwarden-app >/dev/null || setsid /opt/Bitwarden/bitwarden-app --enable-features=UseOzonePlatform --ozone-platform=x11 >/dev/null 2>&1 &
# dunst 通知守护（配置 ~/.config/dunst/dunstrc，1.9.2 只认 [global] 段）
pgrep -x dunst >/dev/null || dunst &
# 开机蓝牙无声自愈：耳机回连常与 wireplumber 抢时序，profile 卡在 audio-gateway/off
# （sinks:0，无声）。等耳机连上（最多 60s）后跑 fix 模式激活 a2dp 并设默认输出。
( for _i in $(seq 1 12); do
    sleep 5
    for _m in $(timeout 5 bluetoothctl devices Paired 2>/dev/null | awk '{print $2}'); do
        timeout 3 bluetoothctl info "$_m" 2>/dev/null | grep -q 'Connected: yes' \
            && exec ~/.local/bin/bt-earbud fix "$_m"
    done
  done ) &
# 触摸板 tap-to-click 默认开启（bcm5974 设备，libinput 默认是关的）
~/.local/bin/touchpad-toggle on >/dev/null 2>&1 &
# 剪贴板历史监视（cliphist owner 模式：每次剪贴板被读取即存一条；选择器 Super+Ctrl+c -> clipmenu）
pgrep -f 'cliphist store' >/dev/null || ( while :; do xclip -selection clipboard -out | cliphist store || exit 1; done ) &
exec dwm
#startx ~/.config/chadwm/scripts/run.sh
