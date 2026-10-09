---
name: mpd-headless-music-void
description: "Headless MPD+ncmpcpp music on Void/PipeWire."
---

# 无头音乐栈: MPD + ncmpcpp (Void + PipeWire)

## 组成
- `~/.config/mpd/mpd.conf` — music_directory=~/Music, PipeWire 输出 + FIFO(/tmp/mpd.fifo) 供可视化
- `~/.config/ncmpcpp/config` — spectrum 可视化, 读 /tmp/mpd.fifo
- `~/.local/bin/mpd-toggle` — 按 pid 文件(~/.config/mpd/pid) 判断开关（别用 `mpc ping` 判断，mpc 0.35 无 ping 子命令）
- 守护进程不用 runit：用户起 `mpd ~/.config/mpd/mpd.conf` 即后台运行；`mpd-toggle` 热键开关

## 顶栏歌词 (dwm bar)
- `~/.local/bin/bar-lyric` = sh 包装器 → 跑 `~/.local/lib/bar-lyric.py`；运行时 glob `$HOME/.hermes/tools/python-*/bin/python3` 解析解释器（mutagen 只装在 Hermes python，路径含数字段会被显示遮蔽绝不能硬写 shebang）
- 数据源: 歌曲 ID3 `SYLT` 同步帧, mutagen 结构 `frame.text = [(text, ms), ...]`（本版本无 .iterate()）
- 播放进度从 `mpc status` 默认行 `[playing] #1/2  2:31/4:24` 正则取 elapsed
- 停止/清空判空: 用 `mpc current`（无当前曲输出空）; 不能用 `mpc -f %file% status`——mpc 0.35 停止时会漏出 volume/repeat 状态行混入结果
- sbar 集成: `update_lyric` 每秒跑, `display()` 用 `${lyric:+| $lyric}` 空则整段隐藏; 主循环改每秒 display
- 排查: `xprop -root WM_NAME` 直读顶栏内容验证

# 加歌流程
- spotdl 4.5.2 已装(Hermes pip): `spotdl download <spotify-url> --bitrate 320k --lyrics synced --output "{artists}/{artists} - {title}.{output-ext}"`; 需先 `spotdl --download-deno`(yt-dlp 解密)
- 同步歌词内嵌 SYLT+USLT 帧; `--audio-providers` 无 CLI 参数, 改 `~/.config/spotdl/config.json` 的 audio_providers (soundcloud 可补 YT 搜不到的, 用完改回)
- 下载完 `mpc update` 入库

## 热键 (sxhkdrc)
- Super+Ctrl+M 播放/暂停 | Super+Ctrl+, 打开 ncmpcpp(st) | . 下一首 | / 上一首 | ; 静音

## 坑
- Void 里 `mpc` 是独立包(mpc-0.35)，装 mpd 不会带上，须 `sudo xbps-install mpc`
- mpd 6600 端口残留进程会 bind IPv4 失败但 IPv6 成功——排查用 `pgrep -a mpd` 找全再 kill
- mpd.conf 里 playlist_directory 必须预先 mkdir，否则启动报 exception
- 验证链路: `mpc status` 播放中 + `wpctl status` Streams 段应见 "Music Player Daemon -> CS4208 Analog playback [active]"
- 加歌: 丢文件进 ~/Music 后 `mpc update`
