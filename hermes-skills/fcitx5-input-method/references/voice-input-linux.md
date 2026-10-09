# AI voice dictation on Linux (non-IME, types at cursor)

Class: user wants push-to-talk speech-to-text into any app WITHOUT touching the fcitx5 input-method stack. These are standalone dictation apps (hotkey → record → STT → type/paste at cursor), orthogonal to input methods.

## Decision table (verified landscape, 2026)

| Tool | STT | Cost | Local? | Notes |
|---|---|---|---|---|
| OpenTypeless | Groq whisper-large-v3-turbo (free tier), Doubao, OpenAI-compat | BYOK, ~free | cloud (audio leaves box) | Tauri AppImage, X11+Wayland, Chinese voice-intent routing, AI polish, clipboard fallback if typing fails. Hotkeys Ctrl+/ dictation, Ctrl+. ask |
| Whisper-Input-Next | Doubao streaming ASR / GPT-4o / local whisper.cpp | pay-per-use, cheap | cloud or local | Python; press-once toggle (no hold); best Chinese accuracy via Doubao; needs 豆包 API key |
| Handy | local whisper.cpp models | free | fully offline | MIT, Rust, ~31k stars; Chinese model 1.5GB+; heavy on ≤4GB RAM |
| nerd-dictation | local whisper.cpp | free | fully offline | shell + xdotool backend, X11-native; same model-size tax |
| ibus-speech-to-text | local | free | offline | GNOME/IBus only — useless on dwm/fcitx5 |

Key constraint: display server decides the typing backend (xdotool=X11 only, wtype=Wayland). X11/dwm users have it easy — xdotool works everywhere.

## OpenTypeless install recipe (Void/X11, verified working)

1. Download AppImage + `SHA256SUMS-linux-x86_64.txt` from GitHub releases; `sha256sum -c` the AppImage line (deb/rpm lines will FAILED-open-and-read, that's fine).
2. Needs FUSE: `/dev/fuse` + `fusermount` present on Void. AppImage runs fine with `--no-sandbox`.
3. Launch from agent with session env: `DISPLAY=:0 XDG_RUNTIME_DIR=/run/user/1000 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus ~/Applications/OpenTypeless.AppImage --no-sandbox` (background). Startup log confirms X11 detection (`session_type` unknown but `display_present=true`, x11 gdk_backend).
4. First-run is a login onboarding — user can 跳过 (skip) into BYOK settings; STT provider + API key configured in-app (agent cannot log in for the user).
5. Its default STT pre-warms bigmodel.cn + openrouter — provider choice is in Settings, not fixed.

## Hardware guidance for small machines (≤4GB RAM)

Local whisper large-v3 is impractical at 4GB (model alone ~1.5-3GB resident); medium is the ceiling and Chinese quality drops. Prefer cloud STT (Groq free tier / Doubao streaming) on such boxes — zero local footprint. Offline-only requirement + small RAM = manage expectations, not tools.

## Verified local recipe: whisper.cpp + voice-type script (Void/X11, no accounts, no IME touch)

Built and verified end-to-end on the 4GB Haswell Air. This is the user's chosen setup (they declined cloud/AppImage options — prefer offline).

**Build**: `git clone --depth=1 https://github.com/ggml-org/whisper.cpp ~/src/whisper.cpp && cmake -B build -DCMAKE_BUILD_TYPE=Release && cmake --build build -j4` — plain Void toolchain, no special flags; produces `build/bin/whisper-cli`.

**Models** (ggerganov/whisper.cpp HF repo, `resolve/main/ggml-<name>.bin`) in `~/src/whisper.cpp/models/`.

**Measured on 4GB Haswell (5s Chinese sentence)**: small (487MB) = ~19s, simplified output, 100% accurate. medium (1.5GB) = ~63s AND outputs TRADITIONAL characters (今天天氣不錯) — small is the right default on this box; medium is strictly worse here (3x slower, wrong script). CPU-only Haswell runs small at roughly 4x realtime.

**Test-audio trick (verify the pipeline without a mic)**: synthesize natural Chinese speech with the hermes-tools edge-tts binary (`~/.hermes/tools/python-*/bin/edge-tts --voice zh-CN-XiaoxiaoNeural --text ... --write-media x.mp3`), then `ffmpeg -ar 16000 -ac 1` to whisper's required format. The Hermes `text_to_speech` tool may fail on Chinese with the edge provider — call edge-tts directly instead. espeak-ng `-v cmn -w out.wav` works as a robotic fallback.

**The `voice-type` script** (`~/.local/bin/voice-type`, bound to `Super+Ctrl+V` in sxhkd): `arecord -f S16_LE -r 16000 -c 1 -d N` → `whisper-cli -m <model> -l zh -np` → paste at cursor via CLIPBOARD, not `xdotool type` (avoids fcitx5 interference): save old clipboard (`xclip -selection clipboard -o`), load text, paste with window-class awareness — terminals (st/XTerm/URxvt/kitty/Alacritty/konsole, detected via `xdotool getwindowfocus getwindowclassname`) need `shift+Insert`, everything else `ctrl+v`; restore old clipboard after ~1.5s. Flags: `-d <secs>` record length, `-m <model>`, `-p` LLM polish.

**LLM polish**: the user's qwen endpoint (q38.nypnk.com/v1, key `Q38_API_KEY` in ~/.hermes/.env) has chat_completions + vision but NO `/audio/transcriptions` (404) — recognition must be local whisper, the LLM only post-processes (strip 嗯/啊/呃, fix punctuation; verified ~2.6s clean output). Probe any provider's audio support with an empty POST to /audio/transcriptions before wiring it.

**Hotkey**: `@super+ctrl+v` in `~/.config/sxhkd/sxhkdrc` + `pkill -USR1 -x sxhkd` reload — Super+Ctrl+V was free alongside the existing alt+ctrl-* set.

## Uninstall checklist (AppImage apps leave state outside the binary)

Kill by explicit PID found via `ps`/`pgrep -x` (never `pkill -f <appname>` — the pattern matches the agent's own wrapping shell command line and kills the agent's own command mid-run), unmount check (`mount | grep -i appimage`), then remove: the AppImage itself, `~/.config/autostart/<App>.desktop` (auto-start entry it self-installs), `~/.config/<App>/`, `~/.local/share/<bundle-id>/` (Tauri apps use reverse-DNS ids like com.opentypeless.app — includes sqlite dbs), `~/.cache/<App>/`. Verify with `find ~ -iname '*<app>*'`.
