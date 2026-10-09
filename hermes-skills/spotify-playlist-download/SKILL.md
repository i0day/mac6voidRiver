---
name: spotify-playlist-download
description: "Download Spotify playlists locally via spotdl for MPD."
---

# Spotify 歌单 → 本地曲库 (spotdl)

## 流程
1. 装: `python3 -m pip install -U spotdl`（用本机 Hermes 自带 python，二进制在其 bin/，需把该 bin 加进 PATH 调用）
2. 下到 MPD 曲库目录（本机 `~/Music`）:
   `spotdl download <playlist-url> --bitrate 320k --lyrics synced --output "{artists}/{artists} - {title}.{output-ext}" --m3u`
3. 长任务: terminal background=true + heartbeat + persist，别阻塞等待
4. 完成 `mpc update` 入 MPD 库，ncmpcpp 立即可见

## 用户偏好
- 格式 mp3 320k。用户问过 flac——已解释无损=体积 3-6 倍不可兼得，用户选 mp3。别再推 flac
- 要歌词: `--lyrics synced`（带时间轴嵌入）

## 坑
- 报 "require Deno / YT-DLP download error" → `spotdl --download-deno`（装到 ~/.config/spotdl/deno）后重跑同命令
- YouTube Music 搜不到 / ReadTimeout / "reinitializing song: Failed to complete request"（Spotify API 限流）都是暂态：重跑同一命令自动跳过已存在文件、只补失败歌，无需改参数
- 中文歌名混多语言（如 사랑해요只對你說）首跑常失败，二跑通常成功
- 二跑后仍 "no usable results" 的冷门/feat 歌：切 SoundCloud 源——该版本 spotdl **没有** `--audio-providers` CLI 参数，provider 列表在 `~/.config/spotdl/config.json` 的 `audio_providers` 字段，直接编辑该 json 改 `["soundcloud"]` 再跑同命令；补完**必须改回** `["youtube-music"]`。soundcloud 码率不保证 320k 但能捞缺
- 同命令第三跑无意义（错误集合不收缩）；两源后剩余缺口直接报告用户，不必死磕
