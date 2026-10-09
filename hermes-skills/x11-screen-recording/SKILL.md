---
name: x11-screen-recording
description: Screen-record this X11 box; force yuv420p for Android.
version: 1.0.0
author: Hermes
license: MIT
---

## When to Use
User asks to screen-record (录屏) on this Void/X11 dwm machine, optionally with system audio, or a recorded video shows black on the phone.

# X11 screen recording (this machine)

- Tool: `~/.hermes/tools/ffmpeg-9.0.1-linux-x64/bin/ffmpeg` (x11grab input supported).
- Screen size is **1366x768** (not 1920x1080 — wrong size errors out: "Capture area outside the screen size").
- System audio: Pulse input source `alsa_output.pci-0000_00_1b.0.analog-stereo.monitor` (PipeWire pulse compat). Confirm live names with `pactl list short sources`.
- Standard command (video + system audio, N seconds):
  `ffmpeg -f x11grab -framerate 30 -video_size 1366x768 -i "$DISPLAY" -f pulse -i <monitor> -t N -c:v libx264 -preset ultrafast -crf 23 -pix_fmt yuv420p -c:a aac -b:a 192k -shortest out.mp4`
- **PITFALL: omitting `-pix_fmt yuv420p` produces High 4:4:4 / yuv444p which Android stock player shows as black video with working audio.** Always force yuv420p. If a file is already recorded, remux: `-c:v libx264 -pix_fmt yuv420p -profile:v high -movflags +faststart -c:a copy`.
- Verify before sending: extract a frame (`-frames:v 1`) and check ffprobe profile/pix_fmt.
- Phone: Pixel 8 Pro wireless adb — `adb pair ip:pairport CODE`, then `adb connect ip:connectport` (the port on the Wireless debugging main page differs from the pairing port; mDNS discovery unavailable in android-tools 36.0.1). Push to `/sdcard/Movies/` and verify with `adb shell ls -l`.
