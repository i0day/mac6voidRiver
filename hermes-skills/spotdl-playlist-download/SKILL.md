---
name: spotdl-playlist-download
description: "Download Spotify playlists to local MPD library via spotdl."
---

# Spotify 歌单 → 本地曲库 (spotDL)

## 安装与位置
- `python3 -m pip install -U spotdl`（装进 Hermes python bin，不在用户 PATH——一律用绝对路径调用，如 `~/.hermes/tools/python-*/bin/spotdl`）
- 依赖 ffmpeg（系统已有即可）；部分 YouTube 视频需 Deno：`spotdl --download-deno`（装到 `~/.config/spotdl/deno`，报错 "require Deno" 后跑一次即永久生效）
- 配置文件：`~/.config/spotdl/config.json`（含 Spotify client_id/secret、providers、bitrate 默认值）

## 标准下载命令（用户偏好：mp3 320k + 同步歌词）
```
cd ~/Music && spotdl download "<playlist-url>" --bitrate 320k --lyrics synced --output "{artists}/{artists} - {title}.{output-ext}" --m3u
```
- 输出进 MPD 曲库目录 ~/Music，艺人分目录；完成后 `mpc update` 入库，`mpc load <歌单名>` 播放
- 歌词是内嵌进 mp3 的（ffprobe 见 `TAG:lyrics-XXX`），不生成独立 .lrc，属正常
- 长任务后台跑（heartbeat 5min）；spotdl 自动跳过已存在文件，重跑=免费补漏轮

## 音源切换（YouTube Music 查不到时）
- 症状：`LookupError: No results found` / `YouTube Music returned no usable results`——该 provider 无此音源，重跑整单无效，别无限重试
- spotdl 4.5.2 **没有** `--audio-providers` CLI 参数；provider 只能改 `config.json` 的 `audio_providers` 数组（如改为 `["soundcloud"]`），跑完改回 `["youtube-music"]`
- SoundCloud 音源码率不保证 320k（重压缩源），用户知情可接受
- 判断止损：同一批歌连续两轮全失败即停止重跑，切 provider 或告知用户缺源清单

## 坑
- `--generate-config` 交互读 stdin，无 tty 会 EOFError——直接编辑 config.json 即可，别跑该命令
- bitrate 概念问答：FLAC=无损但体积是 mp3 的 3-6 倍，「无损又小」不存在；用户要 mp3 时先纠正预期再执行
