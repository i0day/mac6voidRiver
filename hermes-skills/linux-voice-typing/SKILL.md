---
name: linux-voice-typing
description: "Local whisper.cpp voice dictation on Linux with LLM polish."
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [voice, whisper, stt, dictation, llm]
---

# Linux 语音输入（whisper.cpp 本地听写 + LLM 润色）

Class: 给 Linux 桌面搭「按热键说话→文字进光标」的语音输入，含低内存机器的模型选型、测试方法、粘贴注入和 LLM 润色接线。

## When to Use

- 用户要语音输入/听写/dictation 上 Linux 桌面，或问「能不能用我的 LLM 直接语音转文字」，或要评估 whisper 模型在某机器上的速度/准确率取舍。

## 先探能力再承诺（决策第一步）

- 用户说「用我的 LLM 做语音输入」时，先探测该端点是否真有音频能力，别假设：POST `/v1/audio/transcriptions`（404=无语音端点）+ chat 里塞 `input_audio` content 项（报 `Unexpected item type in content` = 模型无音频模态）。纯文本/视觉 LLM 只能做**润色层**，听写必须 whisper 类引擎。
- 低内存机器（≤4GB）先跑基准再定默认模型（见下表），别直接上 large/medium。

## 模型速度/质量实测表（4GB Haswell 无 GPU，5 秒中文语音）

| 模型 | 耗时 | 中文输出 |
|---|---|---|
| base (142MB) | ~5s | 正确但常出**繁体**、标点少 |
| small (487MB) | ~19s | 简体、全对 |
| medium (1.5GB) | ~63s | 也出繁体，慢 3 倍不值 |
| small-q5_0 量化 | ~17s | 只省 2s——瓶颈在 encode 阶段，量化救不了 |

**低内存机最优组合：base 识别 + LLM 润色**（润色 prompt 强制「繁体一律转简体+修标点+去口头禅」），总耗时 ~8s 且输出干净简体。whisper 中文可用下限是 base；large 级质量本地跑不动就是跑不动，云端（Groq whisper-large-v3-turbo 免费额度 ~2-3s）是唯一更快的路。

## 搭建步骤

1. **编译**：`git clone --depth=1 https://github.com/ggml-org/whisper.cpp && cmake -B build -DCMAKE_BUILD_TYPE=Release && cmake --build build -j$(nproc)`。产物 `build/bin/whisper-cli`（新版叫 whisper-cli，不是 main）。
2. **模型**：从 `huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-<name>.bin` 下。**量化版 HF 仓库没有**（404 Entry not found）——下全量版后用自带 `whisper-quantize <in>.bin <out>.bin q5_0` 本地量化（~3s）。
3. **录音**：`arecord -q -f S16_LE -r 16000 -c 1 -d N rec.wav`（16kHz mono 是 whisper 硬要求）。
4. **识别**：`whisper-cli -m <model> -f rec.wav -l zh -np`，输出行过滤：`sed -E 's/^\[[^]]*-->[^]]*\][[:space:]]*//'` 去时间戳。**千万别加 `-otxt`**——它让结果写文件而非 stdout，管道永远是空的，表现为每次都「没识别到内容」。
5. **注入光标 = 录音前记焦点窗 + 贴前回焦 + 剪贴板粘贴**（处理有 ~8s 延迟，期间焦点必然漂移，事后再查焦点打不准；Ctrl+V 还会被 fcitx5 拼音模式吃掉）：
   - 按热键瞬间：`TARGET_WIN=$(xdotool getwindowfocus)`；类名必须链式 `xdotool getwindowfocus getwindowclassname`（裸 `getwindowclassname` 不存在）。
   - 完成时：文字 `xclip -selection clipboard` → `xdotool windowfocus --sync $TARGET_WIN` → sleep 0.3 → 按类发键：终端类 (st/XTerm/URxvt/kitty/Alacritty/konsole) 用 `shift+Insert`，其余 `ctrl+v`。
   - 终端里的 nvim 也算终端类：shift+Insert 在 nvim 正常模式=paste、插入模式走 bracketed paste 不重复缩进，无需特判 nvim（已实测截图验证）。
   - 用户偏好：让光标先停在目标位置（nvim 先按 i）再按热键，粘贴落在光标处。
6. **热键**：走 sxhkd（见 x11-keybinding-osd-setup：加新绑定后必须完整重启 sxhkd 并实测，USR1 不可靠）。

## 测试方法（无真人语音时）

- 造自然中文测试音频：`edge-tts --voice zh-CN-XiaoxiaoNeural --text "..." --write-media x.mp3` 再 `ffmpeg -i x.mp3 -ar 16000 -ac 1 x.wav`。espeak-ng 也能出中文 wav 但是机械音，测不出真实准确率——edge-tts 优先。
- 润色层单独测：把识别原文喂 LLM 对比输出，验证繁转简/去口头禅规则生效。

## 用户反馈回路（没有这个用户会说「没反应」）

- 处理有 8 秒静默窗口，用户看不到中间状态就认为热键坏了。**每个阶段必须 notify-send**：录音前「🎤 请说话 (Ns)」、录完「⏳ 识别处理中」、完成「✅ + 最终文字」——最后一条把识别结果直接显示在通知里，就算注入没落对窗口用户也能确认链路活着、报准问题。
- **脚本必须自记日志**（`exec >>~/.cache/<name>.log 2>&1`）：热键场景下 stdout/stderr 无处可看，出问题时唯一诊断面。记参数、焦点窗、每步结果。
- **flock 防并发**（`exec 9>lockfile; flock -n 9 || exit`）：处理要好几秒，用户连按会起多实例互相抢剪贴板/焦点，越抢越像坏的；抢不到锁就提示「上一次还在处理中」。
- 若上次实例卡死会永远占锁：清法 = `ps -eo pid,args | grep -E 'voice-type|whisper-cli|arecord' | grep -v grep` 拿 PID 精确 kill（别用 pkill，见坑），再 `rm lockfile`。

## 坑

- **`pkill -f <name>` 会杀掉自己的包装 shell**（pattern 出现在 bash -c 命令行里，命令收到 SIGTERM 自杀，exit -15）。杀 GUI/AppImage 进程用 `pgrep -f` 先拿 PID，再 `kill <pid>` 显式杀，别把 pkill 和后续清理链在同一条命令里。
- AppImage 跑完要查 FUSE 挂载残留：`mount | grep -i appimage`，进程杀了挂载可能还在。
- 删除「刚装的东西」要删全：AppImage 本体 + `~/.config/<app>` + `~/.local/share/<app-id>` + `~/.cache/<app>` + `~/.config/autostart/<app>.desktop`，最后 `find ~ -iname '*<app>*'` 兜底确认。
- Hermes 终端的 cwd 会因目录被删而失效（`getcwd: cannot access parent directories`），后续 terminal 调用全部 exit 126——用 workdir 参数或 execute_code 里 `os.chdir()` 重置，别在坏 cwd 上重试。
- 讯飞输入法 Linux 版只支持 **fcitx4**（deb 依赖 fcitx-libs/fcitx-bin），与 fcitx5 栈互斥；Void 无 fcitx4 包。要讯飞式体验走 whisper+LLM 方案，别往 fcitx5 里塞。
