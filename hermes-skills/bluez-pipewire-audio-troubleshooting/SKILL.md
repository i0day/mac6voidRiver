---
name: bluez-pipewire-audio-troubleshooting
description: Use when BT earbud shows connected but no sound on PipeWire.
---

# BlueZ + PipeWire 蓝牙耳机「已连接但无声」

## 症状与根因
- BlueZ `Connected: yes` 但无声 → 先查 PipeWire 卡 profile：`pactl list cards | grep -A1 bluez_card`。
  profile 停在 `off` 时 sink 节点根本不存在，默认输出无处可去。
- 修复：`pactl set-card-profile bluez_card.<MAC下划线> a2dp-sink`，再 `pactl set-default-sink`。

## 关键坑（本机实测）
1. **PipeWire 的 bluez 命名保留 MAC 原始大写**：`bluez_card.98_52_3D_DF_A6_32`。脚本里若做
   `tr lower` 会匹配不上——用 `grep -i` 或 awk `tolower()` 比较。
2. **双 wireplumber 实例会弄乱状态**：`pgrep -c wireplumber` 应为 1；多余实例 kill 后重启一个。
3. `br-connection-key-missing` = 配对密钥失效，须 `bluetoothctl remove` 后重新配对（耳机进配对模式白灯闪烁）。
4. A2DP 协商没建立时 PipeWire 只列 HSP/HFP 档；断开重连（或重启 wireplumber）后
   `a2dp-sink*` 档才会出现。耳机侧 `busctl introspect org.bluez .../sepN` 有 110b (Audio Sink) 说明支持高音质。
5. 验证出声：`pactl list short sinks` 看 bluez sink 是否 RUNNING + 播放 `paplay /usr/share/sounds/freedesktop/stereo/bell.oga`。

## 本机脚本
`~/.local/bin/bt-earbud`（Super+Alt+B，dwm 绑定）：连接后 `ensure_sink()` 自动等卡→激活 a2dp→设默认 sink。
注意 bash 里多词命令存字符串再 `$var` 展开会被单词分割破坏（`-p '...'` 拆坏 dmenu 参数），必须用数组 `"${DMENU[@]}"`。

## 坑6: profile 卡在 audio-gateway（本机实锤根因）
WirePlumber 给 `audio-gateway` 档 priority 256，重连时自动选中；该档 sinks:0，
且档位列表里 **完全没有 a2dp-sink\***（BlueZ 无 sep 端点，transport 未协商），
`pactl set-card-profile ... a2dp-sink` 报 `Failure: No such entity`。此时断开重连也无效。
修复阶梯（已固化进 bt-earbud 的 ensure_sink）：
① `pkill -x wireplumber` + 重新拉起 → Media1 端点重新注册，a2dp 档出现；
② 仍无则 `sudo sv restart bluetoothd` + connect + 等 ServicesResolved + 再重启 wireplumber。
判定函数：`pactl list cards` 耳机区块 `grep a2dp-sink`（a2dp_ready）。
注：本机 bluetoothd 由 runit 管理；用 `bluetoothd -n -d` 手启会和 runit 实例抢 D-Bus 名失败，restart 要走 `sv restart bluetoothd`。

## 坑7: 开机时序——耳机回连比 wireplumber 起得早，每次开机必现
用户反馈「每次重启电脑都无声」。ensure_sink 只在手动菜单 connect 路径触发，开机自动回连
（BlueZ trusted device 自动 reconnect）没人管。解决（已实施）：
- bt-earbud 加了 fix 模式：`bt-earbud fix [MAC]` 无 TUI，自动挑已连的已配对耳机跑
  ensure_sink。fix 分发块必须在 dmenu 之前（曾误插在选单后导致脚本卡 dmenu 等输入）。
- ~/.xinitrc 在 dunst 之后加后台循环：每 5s 查一次已配对且 Connected 的耳机，
  最多 12 轮（60s），发现即 exec bt-earbud fix <MAC>。无耳机则静默退出。
验证方法：`pactl set-card-profile bluez_card.<MAC> off` 人为制造故障后跑 fix，
确认 Active Profile 回到 a2dp-sink 且 Default Sink 指向 bluez_output。
