---
name: natural-tts-linux
description: Use when setting up human-like TTS on Linux.
version: 1.0.0
author: Hermes
license: MIT
metadata:
  hermes:
    tags: [tts, speech-dispatcher, edge-tts, firefox, void-linux, xbindkeys]
---

# Natural neural TTS on Linux (edge-tts + speech-dispatcher)

## When to Use
- Firefox reports speechSynthesis missing/robotic, or user wants a natural (non-robotic) human voice for web reading, terminal TTS, or read-selection hotkeys.
- Rebuilding this setup on a new/reinstalled Void (or other) Linux machine.

Gives Firefox/system speechSynthesis a near-human voice instead of robotic espeak.
Engine: edge-tts (Microsoft Edge neural TTS, free, no key, needs network).
Falls back to espeak-ng offline so nothing goes silent.
Full working files on this machine: ~/.local/bin/{sd-edge-tts,say,saysel}, ~/.config/speech-dispatcher/.

## Install (Void Linux)
```
sudo xbps-install -y speech-dispatcher espeak-ng alsa-utils
pip install edge-tts   # or pipx
```
Firefox needs libspeechd — provided by speech-dispatcher. Restart Firefox fully after config changes.

## ALSA → PipeWire bridge (fixes "unable to open slave")
Void's alsa-pipewire pkg provides /usr/share/alsa/alsa.conf.d/ but ALSA may still default to dmix.
Write ~/.asoundrc:
```
pcm.!default { type pipewire playback_node "-1" capture_node "-1" }
ctl.!default { type pipewire }
```
Verify: `speaker-test -D default -c 2 -l 1` makes noise.

## Wrapper script ~/.local/bin/sd-edge-tts
Key rules (each one was a real failure):
1. **exec 1>/dev/null at top** — sd_generic uses the child's stdout as its protocol channel; any wrapper stdout (e.g. ffplay progress) breaks speechd ("unexpected reply |" / "Bad syntax from output module").
2. Resolve binaries by absolute path — speechd spawns with a minimal PATH:
   `ETTS=$(ls ~/.hermes/tools/python-*/bin/edge-tts | head -1)` (or wherever pip installed it), same for ffplay.
3. Auto voice by script: CJK chars → `zh-CN-XiaoxiaoNeural`, else `en-US-AvaNeural`; override with `EDGE_TTS_VOICE` env.
4. Fallback on network failure: `espeak-ng -v zh` / `-v en-us` so Firefox still speaks.
5. Play with `ffplay -nodisp -autoexit -loglevel error file.mp3`.

## speech-dispatcher config (~/.config/speech-dispatcher/)
copy /etc/speech-dispatcher/speechd.conf, then add:
```
AddModule "edge-tts"  "sd_generic"  "edge-tts-generic.conf"
DefaultSynthesisModule "edge-tts"
```
modules/edge-tts-generic.conf — ONLY these options are valid (SynthesisProgram/MaxChunkLength etc. are NOT):
```
Debug 0
GenericExecuteSynth "/home/USER/.local/bin/sd-edge-tts '$DATA'"
GenericCmdDependency "edge-tts"
GenericDefaultCharset "utf-8"
GenericLanguage "en" "en-us"
AddVoice "en" "FEMALE1" "default"
```
Pitfalls: `Debug 3` pollutes the protocol → "Bad syntax from output module". Empty-string args (`GenericPunctNone ""`) → "Missing argument" — omit instead. pkill name is truncated: use `pkill -x speech-dispatc` (15 chars), NOT `pkill -f speech-dispatcher` (kills your own shell).
Restart: `pkill -x speech-dispatc` (auto-respawns on next client).
Verify: `spd-say -o edge-tts "你好，测试"` → human voice; speechd log shows "Module edge-tts started successfully" (log: /run/user/1000/speech-dispatcher/log/).

## Hotkeys (sxhkd, Alt+Ctrl+letter convention — xbindkeys retired/uninstalled)
~/.local/bin/saysel: read X primary selection (mouse-highlighted, no copy needed), fallback clipboard, cap 2000 chars, run wrapper via nohup &.
~/.config/sxhkd/sxhkdrc (@ prefix = fire on press, no Release needed — sxhkd has no xbindkeys auto-repeat bug):
```
@alt+ctrl+e
	~/.local/bin/saysel
@alt+ctrl+shift+e
	pkill -f sd-edge-tts
```
(NOT Ctrl+Alt+r — Firefox grabs that natively for Reader Mode, sxhkd never sees it while Firefox is focused.)

## Firefox Reader Mode replacement (~/.local/bin/reader, bound to @alt+ctrl+r)
This Firefox build's built-in Ctrl+Alt+R binding is dead (fails even in a clean profile; icon click works). Equivalent: `about:reader?url=<encoded-current-url>`.
reader script: activate Firefox window → ctrl+l → ctrl+a → ctrl+c → read clipboard URL → `firefox --new-tab about:reader?url=$enc`.
Note: sxhkd @alt+ctrl+r now runs reader (Firefox never saw the key anyway, so no conflict).
Reload: `pkill -USR1 sxhkd` (hot reload, no restart). `pkill -USR2 sxhkd` toggles all grabs off/on.

## Usage
- `say "text"` / `say -v <voice> "..."` / `say -f file` — terminal TTS
- Firefox: any page using speechSynthesis speaks human voice; zh-CN auto-detected
- Web pages: select text → Alt+Ctrl+r; Ctrl+A then Alt+Ctrl+r for whole page (2000-char cap)
- Voice list: `edge-tts --list-voices` (zh-CN-XiaoxiaoNeural, en-US-AvaNeural, en-GB-RyanNeural...)

## Debug order
1. `~/.local/bin/sd-edge-tts "test"` direct → isolates wrapper
2. `spd-say -o edge-tts "test"` → isolates speechd routing
3. tail /run/user/1000/speech-dispatcher/log/{speech-dispatcher,edge-tts}.log
4. Firefox must be fully restarted after any speechd config change.
