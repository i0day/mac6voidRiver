#!/usr/bin/env bash
# wifimenu — rofi Wi-Fi menu for iwd (Void Linux, no NetworkManager)
# Scan/connect via iwctl; sudo only to drop a .psk profile for a new network.
set -u

IFACE=$(iw dev 2>/dev/null | awk '/Interface wl/{print $2; exit}')
[ -z "$IFACE" ] && { dunstify -a wifimenu "没有无线网卡 / no wlan interface found"; exit 1; }

strip_ansi() { sed 's/\x1b\[[0-9;?]*[a-zA-Z]//g'; }

# current state
state=$(iwctl station "$IFACE" show 2>/dev/null | strip_ansi)
connected_ssid=$(echo "$state" | awk '/Connected network/{print $NF}')

# saved networks (connect without password)
known=$(iwctl known-networks list 2>/dev/null | strip_ansi | awk 'NR>3 && NF>1 {print $1}')

# scan and wait for it to finish
dunstify -a wifimenu -u low "扫描 Wi-Fi 中… Scanning…"
iwctl station "$IFACE" scan 2>/dev/null
for _ in $(seq 1 30); do
    iwctl station "$IFACE" show 2>/dev/null | grep -q 'Scanning *no' && break
    sleep 1
done

# parse fixed-width get-networks table using header offsets
netlist=$(iwctl station "$IFACE" get-networks 2>/dev/null | strip_ansi)
rows=$(echo "$netlist" | awk -v known="$known" -v cur="$connected_ssid" '
    /Network name/ { name_at = index($0, "Network name"); sec_at = index($0, "Security"); next }
    name_at && sec_at {
        ssid = substr($0, name_at, sec_at - name_at); gsub(/^[ >-]+| +$/, "", ssid)
        if (ssid == "") next
        sec = substr($0, sec_at, 12); gsub(/ +$/, "", sec)
        tag = " "
        if (index("\n" known "\n", "\n" ssid "\n") > 0) tag = "★"
        if (ssid == cur) tag = "✅"
        printf "%s\t[secure=%s]\t%s\n", ssid, tag, sec
    }')
[ -z "$rows" ] && { dunstify -a wifimenu -u critical "没扫到网络 / no networks found"; exit 1; }

powered=$(iwctl device "$IFACE" get-property Powered 2>/dev/null | grep -o 'on\|off')
if [ "$powered" = "on" ]; then
    toggle="⏻  关闭 WiFi / power off"
else
    toggle="⏻  开启 WiFi / power on"
fi

display=$(printf '%s\n' "$toggle"; printf '%s\n' "$rows" | awk -F'\t' '{printf "%s %s %s\n", $3, $2, $1}' | sed 's/ \[secure= \]/  /')

chosen=$(printf '%s\n' "$display" | rofi -dmenu -i -p "Wi-Fi ($IFACE): " 2>/dev/null)
[ -z "$chosen" ] && exit 0

if [ "$chosen" = "$toggle" ]; then
    if [ "$powered" = "on" ]; then
        iwctl device "$IFACE" set-property Powered off
        dunstify -a wifimenu -u low "✈️ WiFi 已关闭 / powered off"
    else
        iwctl device "$IFACE" set-property Powered on
        sleep 2
        dunstify -a wifimenu -u low "📶 WiFi 已开启，再开一次菜单选网络"
    fi
    exit 0
fi

# ssid is the last whitespace-separated token of the display line
ssid=$(printf '%s' "$chosen" | sed 's/ \[secure=[^]]*\]//; s/^[^ ]* //' | sed 's/^ *//')
# safer: re-match against our known SSID list
ssid=$(printf '%s\n' "$rows" | awk -F'\t' -v c="$chosen" 'index(c, $1)>0 && length($1)>maxl {maxl=length($1); s=$1} END{print s}')
[ -z "$ssid" ] && exit 0

connect_now() {
    # already on this network? iwctl connect errors if you ask it to rejoin
    got=$(iwctl station "$IFACE" show 2>/dev/null | strip_ansi | awk '/Connected network/{print $NF}')
    if [ "$got" = "$1" ]; then
        ip=$(iwctl station "$IFACE" show 2>/dev/null | strip_ansi | awk '/IPv4 address/{print $NF; exit}')
        dunstify -a wifimenu "✅ 已连接 $1" "IP: ${ip:-?}"
        return 0
    fi
    iwctl station "$IFACE" connect "$1" </dev/null >/dev/null 2>&1
    for _ in $(seq 1 20); do
        got=$(iwctl station "$IFACE" show 2>/dev/null | strip_ansi | awk '/Connected network/{print $NF}')
        if [ "$got" = "$1" ]; then
            sleep 2   # let DHCP settle
            ip=$(iwctl station "$IFACE" show 2>/dev/null | strip_ansi | awk '/IPv4 address/{print $NF; exit}')
            dunstify -a wifimenu "✅ 已连接 $1" "IP: ${ip:-?}"
            return 0
        fi
        sleep 1
    done
    dunstify -a wifimenu -u critical "❌ 连接 $1 失败 / connection failed"
    return 1
}

if printf '%s\n' "$known" | grep -qxF "$ssid"; then
    connect_now "$ssid"
    exit $?
fi

# new network: hidden passphrase prompt -> write iwd profile -> connect
pass=$(rofi -dmenu -password -i -p "🔑 $ssid 密码 / password: " 2>/dev/null)
[ -z "$pass" ] && exit 0
if [ ${#pass} -lt 8 ] || [ ${#pass} -gt 63 ]; then
    dunstify -a wifimenu -u critical "WPA 密码需 8-63 位 / WPA passphrase must be 8-63 chars"
    exit 1
fi
printf '%s' "$pass" | sudo -n python3 "$HOME/.local/bin/iwd-psk-write" "$ssid" >/dev/null 2>&1 \
    || { dunstify -a wifimenu -u critical "写 profile 失败（需免密 sudo）/ cannot write iwd profile"; exit 1; }
connect_now "$ssid"
