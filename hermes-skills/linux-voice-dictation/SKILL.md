---
name: linux-voice-dictation
version: 1.0.0
author: Hermes Agent
license: MIT
description: "Use when building voice dictation or voice control on Linux."
metadata:
  hermes:
    tags: [voice-input, whisper-cpp, st, nvim, xdotool, xclip, void-linux]
---

# Local voice dictation / voice control on Linux (whisper.cpp + LLM)

## When to Use
- Setting up or debugging hotkey-triggered voice-to-text input on Linux (whisper.cpp, st/nvim clipboard paste, sxhkd).
- Adding an LLM voice-command layer (dictate control intents vs plain text) on a machine without GPU.
- Debugging "voice input 没反应 / 上一次还在处理中" complaints in this stack.

Class: building press-hotkey → speak → text-or-action in the focused app, fully local STT, optional LLM command parsing. Built for low-RAM laptops (i5-4250U/4GB: works).

## Architecture (this box)
- `~/.local/bin/voice-type` — dictation; `~/.local/bin/voice-ctl` — unified entry (dictation + control commands); hotkey `Super+Ctrl+V` via sxhkd `@super+ctrl+v`.
- whisper.cpp built at `~/src/whisper.cpp` (cmake Release, ~5 min on 4 cores); models in `~/src/whisper.cpp/models`.
- LLM: qwen3.8 gateway, key `Q38_API_KEY` in `~/.hermes/.env` — chat/completions only, NO audio endpoint (probe with empty POST to /audio/transcriptions before promising voice via LLM). Whisper does the listening; LLM does polish + intent parsing.
- Log: `~/.cache/voice-type.log` (script `exec >>` redirect — debug hotkeys by reading this file, never guess). Lock: `~/.cache/voice-type.lock` via flock.

## Model choice (measured, 5s Chinese clip, no GPU)
base=5s (outputs 繁體), small=19s, medium=63s, q5_0-quant of small=17s (quantize barely helps — encode dominates). Use **base + LLM polish** (繁→简 + punctuation + filler removal) ≈ 8s end-to-end, near-perfect. Regenerate quantized models with `build/bin/whisper-quantize in out q5_0` if ever needed.

## Pipeline rules (each was a real bug)
1. `whisper-cli -otxt` writes to a FILE, not stdout → piped capture is silently empty → false "没识别到内容". Omit -otxt; strip `[ts --> ts]` line prefixes with sed.
2. Capture `xdotool getwindowfocus` (window id + classname) AT HOTKEY TIME, BEFORE recording — focus drifts during the ~8s processing (notifications etc.); before pasting do `xdotool windowfocus --sync $TARGET_WIN` or text lands in the wrong window.
3. Terminal window class (st) can't reveal nvim running inside it — BFS the window's PID tree (`pgrep -P` recursion ≤6 deep, check `/proc/PID/comm`) to detect nvim. User's nvim pastes system clipboard with **alt+v**; plain terminals Shift+Insert; GUI apps ctrl+v. Never `xdotool type` raw text into nvim-in-terminal — user expects clipboard paste and raw typing fights fcitx5.
4. **xclip fork-daemon inherits the flock fd** → the detached xclip keeps holding voice-type.lock forever → every later hotkey reports "上一次还在处理中". ALWAYS launch xclip with the lock fd closed: `... | xclip -selection clipboard 9>&-` (match the fd number used for flock). Symptom-check: `for p in /proc/[0-9]*; do ls -l $p/fd | grep -q <lockfile> && echo $p; done`.
5. notify-send at every stage (recording / processing / final text) so the user sees the recognized text even if paste misses — "没反应" reports become diagnosable from log + notifications.
6. Stale lock recovery: find exact holder PID via the /proc fd scan above, kill by explicit PID, `rm` the lock.

## Voice control (LLM intent layer)
Ask the LLM (temperature 0) to map the transcribed utterance to a single JSON command from a fixed whitelist (brightness/volume/open/window/screenshot/media/sleep/search/say/none), output JSON only. Route: `none` → paste the text (dictation fallback); known actions → execute mapped shell (brightnessctl, amixer, kbdbrightness up/down, xdotool window ops, maim, xdg-open, say). Safety rules baked into the system prompt: non-control text → none; destructive requests (delete/format) → none. Fallback-to-typing makes misparses harmless. Validate the parser with a batch of representative Chinese phrases before shipping (14/14 passed on this setup).

## Terminal safety (recurring lesson, applies to all daemons you restart)
- NEVER `pkill -f <pattern>` from the agent terminal when the pattern string also appears in your own wrapping shell's cmdline — it SIGTERMs your own tool call (exit -15, command dies mid-way). List with `ps -eo pid,args | grep '[s]xhkd'`-style bracket patterns or the /proc fd scan, then kill by explicit numeric PID. Applies to voice-type, sxhkd, anything you pattern-kill.
- sxhkd: `pkill -USR1` hot reload is unreliable here — kill exact PID, relaunch `sxhkd -c ~/.config/sxhkd/sxhkdrc` via terminal(background=true).

## Testing the pipeline without a real voice
Synthesize Chinese test audio: edge-tts `zh-CN-XiaoxiaoNeural` → mp3 → `ffmpeg -ar 16000 -ac 1 out.wav`; run whisper+LLM on it; verify paste by spawning `st -e nvim /tmp/x.txt`, running window-has-nvim detection + paste, screenshot with maim + vision check. Only the arecord step truly needs a human.
