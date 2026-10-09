---
name: linux-bluez-audio
description: Use when BT audio on PipeWire is silent or mis-profiled.
---

# Linux 蓝牙音频（BlueZ + PipeWire）

## When to use
蓝牙耳机显示已连接但没有声音、需要切音质档（aptX/AAC/SBC 与通话档）、配对密钥失效、或改蓝牙热键工具后需补文档。

## 根治：杜绝 audio-gateway 档（优先于每次重启阶梯）
耳机广播 hfp_ag/a2dp_source 能力是 gateway 档存在的前提。在
`~/.config/wireplumber/wireplumber.conf.d/51-bluez-roles.conf` 里限制角色：
```
monitor.bluez.properties = {
  bluez5.roles = [ a2dp_sink hsp_hs hfp_hf ]   # 只保留「耳机当接收方」角色
}
wireplumber.settings = {
  bluetooth.autoswitch-to-headset-profile = false # 禁 app 开麦即降音质；切通话档走显式选择
}
```
之后 `audio-gateway` 档不再被选中；A2DP 听歌与耳机麦通话均不受影响。
改后重启 wireplumber 生效。验证：`pactl list cards` 耳机档位列表只剩 off/a2dp-sink*/headset-head-unit*。
注意：此配置救不了「耳机侧 AVDTP 没协商」的情形（无 sep、无 Media1，见诊断第 0 步与坑10）——roles 限制管的是档位选择，不是链路。
角色名映射：HS Headset=hs_hs, HS AG=hsp_ag, HF Handset=hfp_hf, HF AG=hfp_ag（gateway 由 *_ag 产生）。

## 冷开机（cold boot）必现的完整修复时序（本机实锤，2026-10）
冷开机 pipewire 栈先于耳机回连启动 → bluez 卡不注册；耳机连上后卡出现但 profile 卡在 `audio-gateway`，`pactl set-card-profile a2dp-sink` 报 `No such entity`。有效顺序：
1. `bluetoothctl connect <MAC>` 后**等 ServicesResolved: yes**（`busctl tree org.bluez | grep -c sep` 变 11）；
2. `pkill -x wireplumber` 重起单个 wireplumber → Active Profile **自动**变 a2dp-sink、默认输出自动指向 bluez（无需再 pactl set）；
3. `pw-play --target=<bluez_sink> 生成的.wav` 验证出声。
注意：刚连上立刻 set-profile 必败（sep 未注册），必须等 ServicesResolved。bt-earbud 的 fix 阶梯①与此一致。

## 「已连接但无声」诊断顺序
0. 先定界（比盲目重启阶梯省数轮）：`busctl introspect org.bluez /org/bluez/hci0/dev_<MAC下划线>` 数接口。无 `org.bluez.Media1`、`busctl tree org.bluez | grep -c sep` 为 0 ⇒ 失败在链路层（AVDTP/SEP 从未建立），WirePlumber 怎么重启都没用；此时「已连接」只是 AVRCP/BREDR 残留（只有 Device1/MediaControl1/Bearer），常伴 `br-connection-page-timeout`（耳机休眠/链路劣化），唯一出路是唤醒耳机或删绑定重配。有 Media1+seps 而档位仍卡 off/gateway ⇒ WirePlumber 管理层，走坑8阶梯。WirePlumber 侧佐证：日志 `WIREPLUMBER_DEBUG=3` 下出现 "BT device 0 connected" 紧接 "Not activating device"——即 SPA 插件判 `api.bluez5.connection ≠ connected`，与 busctl 查接口互相印证。
0b. 「全绿仍无声」要临出门前复查在不在：a2dp-sink 激活、transport State=active、sink RUNNING、默认 sink 和 sink-input 路由全对，用户仍听不到 ⇒ 立即 `bluetoothctl info <MAC>` / `busctl tree org.bluez` 复查设备是否还在总线上。「Device not available」= 链路层刚断（耳机休眠/走远/劣化），软件层全绿只是断流前快照，任何 stack 重启都无意义——出路是让用户物理唤醒耳机（戴上/开盖），唤醒后再走 connect + ensure_sink；若重连报 key-missing 则删绑定重配（坑3）。诊断结论必须基于最后时刻的设备状态，不能基于几分钟前的健康快照。
1. `pactl list cards | grep -A1 bluez_card` 看 Active Profile。`off` 或 `audio-gateway` = sinks:0，sink 节点根本不存在，声音无处可去——最常见根因，与 BlueZ 的连接状态无关。`audio-gateway` 是 WirePlumber 高优先级档（priority 256），重连时会被自动选中，且档位列表里可能完全没有 a2dp-sink*（transport 未协商），此时 `pactl set-card-profile ... a2dp-sink` 报 `Failure: No such entity`，断开重连也无效。
2. 修（若档位里没有 a2dp-sink*，此步无效，先走坑8重启 wireplumber）：`pactl set-card-profile bluez_card.<MAC下划线> a2dp-sink`，然后 `pactl set-default-sink bluez_output.<MAC下划线>.1`。
3. 验证出声：`pactl list short sinks` 看 bluez sink 是否 RUNNING，并实际推一段测试音。只看状态不播声不算验证。bell.oga 不一定存在，且 **`pw-cat/pw-play 没有 `-t sine` 参数**（旧文档有误，实测 invalid option）——可靠替代：Python wave 生成 2~4s 440Hz WAV 到 scratch，再 `pw-play --target=<sink> file.wav`（注意是 `--target=`，不是 `-t`）。（长音还便于让用户确认音量——sink 音量偏低时须明确告知）。验证 sink-input 确实路由到目标：`pactl list sink-inputs | grep 'Sink:'` 的编号应与 bluez sink 编号一致。

## 通用坑（规则）
1. PipeWire 的 bluez 对象命名保留 MAC 原始大写（`bluez_card.98_52_3D_DF_A6_32`）。匹配一律大小写不敏感；awk 无 portable IGNORECASE——在 shell 里先把 pattern `tr` 成小写，awk 对每行 `tolower($0)` 再比。
2. 双 wireplumber 实例会弄乱 profile/设备状态。`pgrep -c wireplumber` 必须为 1，多出的 kill 后重启一个再重测。
3. `br-connection-key-missing` = 配对密钥失效。`bluetoothctl remove <MAC>` 后重新配对（TWS 一般是放盒开盖长按功能键至白灯交替闪烁），别在旧绑定上反复 connect。
4. A2DP 未协商时 PipeWire 只列 HSP/HFP 档。判断耳机是否支持高音质：`busctl introspect org.bluez /org/bluez/hci0/dev_<MAC下划线>/sepN` 的 UUID 含 `110b`（Audio Sink）。断开重连或重启 wireplumber 后 a2dp 档才出现。
5. busctl 查属性用点号形式 `org.bluez.MediaTransport1.UUID`（空格分隔接口与属性会报 No such interface）；用 `busctl introspect` 拿值，别猜输出列位。
6. bash 里多词命令存字符串再 `$var` 展开会被单词分割破坏参数（`-p 'xx yy'` 拆坏 dmenu 参数导致其直接打 usage 退出）。带引号参数的命令必须用数组 + `"${CMD[@]}"`。热键「没反应」先 `bash -x <脚本>` 验脚本本体，再怀疑按键被抢。
7. 假报成功不可接受。设默认 sink / 激活 profile 的每步都要失败传播（`[ -n "$x" ] && ... || return 1`），通知区分 ✅（带音质档名）与 ❌（带手动补救命令）。
8. profile 卡在 `audio-gateway`（sinks:0）且设备确有 Media1+seps（先过诊断第 0 步）时修复阶梯：① `pkill -x wireplumber` 后重新拉起 → BlueZ Media1 端点重新注册，a2dp 档出现，profile 自动切到 a2dp-sink；② 仍无则 `sudo sv restart bluetoothd` + connect + 等 ServicesResolved + 再重启 wireplumber。判定：`pactl list cards` 耳机区块 `grep a2dp-sink`。第 0 步未过（无 Media1/sep）就不要跑本阶梯——必败，直接走重配。本机 wireplumber 不经 runit，由 `~/.xinitrc` 裸起（`pipewire & pipewire-pulse & wireplumber &`）——重启用 `pkill -x wireplumber` 后把 `wireplumber` 作为后台守护进程重新拉起即可，无需 xinitrc 参与。
9. bluetoothd 由 runit 管理时用 `sv restart bluetoothd`；`bluetoothd -n -d` 手启会和 runit 实例抢 D-Bus 名失败（bluetoothd 不在 PATH，实路径 /usr/libexec/bluetooth/bluetoothd）。
12. **USB 自动挂起把 BCM 芯片挂死（本机实锤根因，已根治）**：全局 autosuspend=2s + 设备 `power/control=auto` → suspend 后唤不醒，HCI 全 timeout（-110）、重枚举出坏描述符。诊断顺序：先 `cat /sys/bus/usb/devices/<dev>/power/control`（读 sysfs 设备节点用 sudo cat，别用 read_file，udev sysfs 对普通读不可靠）；btmgmt power on / sv restart bluetoothd / authorize 切换 / modprobe -r btusb 全救不回，当时唯一出路是物理断电重插。根治= `/etc/udev/rules.d/99-bt-no-autosuspend.rules`：`ACTION=="add", ATTR{idVendor}=="0a5c", ATTR{idProduct}=="2148", TEST=="power/control", ATTR{power/control}="on"`（99 排序压过系统 60-autosuspend.rules；验证 `udevadm test <devpath> 2>&1 | grep 99-bt` 应显示 writing 'on'）。耳机另须 `bluetoothctl trust` 才会开机自动回连。
13. **重插/换新适配器后旧配对失效**（identity 变了），须重新扫描 pair；且若 pipewire 栈是在耳机不存在时起的，bluez 卡不会出现、无 Media1/sep——wireplumber 单独重启无效，必须整套重启 pipewire+pipewire-pulse+wireplumber（本机不经 runit，pkill 后用 background 进程逐个拉起）。bt-earbud fix 在 bluez 卡不存在时**静默返回 0**，勿信 rc，须以 `pactl list cards short | grep bluez` 为准。
10. **不要用 `bluez5.roles` 限制角色来消灭 audio-gateway**（本机实锤反例）：限制成 [a2dp_sink hsp_hs hfp_hf] 后 PipeWire 注册的本地端点与耳机类别不匹配，AVDTP 协商不出本地 sep，设备对象缺 org.bluez.Media1 接口，卡上 a2dp 档根本不出现（只剩 off+gateway），且重连/重配对都救不回；撤掉角色限制恢复默认全角色后 a2dp-sink 立即回来并被默认选中（profile-preference=quality）。判断依据：`busctl get-property org.bluez <dev> org.bluez.Media1 RegisteredEndpoints` 报 No such interface = 本地端点没挂上，先怀疑自己的 roles 配置而不是耳机。
11. 默认全角色下 WirePlumber 自己就优先 a2dp（quality），gateway 只是回连时序踩坑时的坑（坑8阶梯修）；长期静音保险是 xinitrc 里开机 fix 循环 + `bluetooth.autoswitch-to-headset-profile=false`（防 app 录音偷降通话档，切换交给 bt-earbud 菜单 🎵/📞）。要看 AVDTP 协商日志：在 /etc/bluetooth/main.conf 的 [General] 临时加 `Debug=true` 再 restart（排障后记得删）；注意 bluetoothd 二进制在 /usr/libexec/bluetooth/bluetoothd，不在 PATH。WirePlumber 侧对应 `WIREPLUMBER_DEBUG=3|4` 重启抓日志。本机 Void（runit）没有 systemd journal：`journalctl -u bluetooth` 静默返回空，别把它当「无异常」——bluetoothd 调试输出走 runit log（/var/log/runit/bluetoothd/）或临时手启 `-n -d` 看（注意坑9 抢名）。

## 改键/改工具后的文档义务
改 dwm/sxhkd 键位或工具行为后同步仓库 KEYBINDINGS.md：更新头部日期，并在正文加独立「使用说明/排障」小节，内含菜单行为、失败模式的手动补救命令、已验证机型。

## 本机参考实现
`~/.local/bin/bt-earbud`（Super+Alt+B，dwm 绑定，仓库镜像 `local/bin/bt-earbud`）：dmenu 列已配对设备（Trusted 兜底）。用户要求「音乐/通话」显式两档选择：未连接设备先问用途（🎵 A2DP / 📞 带麦），已连接设备弹「切音乐档 / 切通话档 / 断开」。`ensure_sink <music|call>` 按模式选档列表（music: a2dp-sink > aac > sbc_xq > sbc；call: headset-head-unit(mSBC) > cvsd）切档并设默认输出；通话档同时 `pactl set-default-source` 设耳机麦，音乐模式补设默认 sink。失败通知带手动补救命令。已验证机型 Soundcore Liberty Air 2（配置了上述 roles 限制根治 gateway 复发）。

## 重叠提示
`bluez-pipewire-audio-troubleshooting` 是本主题的窄版且 user-owned（自动 curation 拒写）。本技能为类级超集；建议用户执行 `hermes curator adopt bluez-pipewire-audio-troubleshooting` 以便后续合并。`dotfiles-sync-mac6void` 同为 user-owned——其 KEYBINDINGS.md 同步义务已并入上文「文档义务」一节。
