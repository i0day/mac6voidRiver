---
name: local-file-transfer-phone
description: "LAN file-to-phone via QR + token'd HTTP on Void."
---

# 一键传文件到手机 (sendfile)

## 组成
- `~/.local/bin/sendfile` — fzf 选文件 → 起服务 → st 弹二维码窗口，按任意键关
- `~/.local/bin/sendfile-server` — 带 token 校验的 Python 单文件 HTTP 服务（BaseHTTPRequestHandler）
- `~/.local/bin/sendfile-stop` — 杀掉所有传服务
- 热键: `Super+Ctrl+Shift+F`（sxhkdrc）
- URL 格式 `http://<lan-ip>:8777/<16hex-token>/<file>`，存 `/tmp/sendfile-last-url.txt`

## 坑（重要）
- 扫码报错对照: `404 nothing matches`=网络通但 token/文件对不上(旧服务残留或文件不在服务 cwd); `超时/连不上`=网络隔离或服务已死。404 是好消息
- 残留服务占端口→新 token 扫码 404: 起服务前必须 pkill 旧实例 + bind 失败换随机端口重试
- sendfile-server 必须 cwd=文件所在目录启动，否则全 404（服务只认自己 cwd）
- ThreadingTCPServer 而非单线程：手机先 GET favicon.ico 会卡死单线程服务
- dash `{ ... }` 组最后一条命令后必须加分号：`{ echo x; exit 1 }` 报 "expecting }"，须 `{ echo x; exit 1; }`。定位法：逐行删除后跑 `dash -n`，删哪行变通过即哪行坏
- 新写的 ~/.local/bin/* 必须 chmod +x，否则被当子进程调时 Permission denied（主脚本自身能跑造成误导）
- fzf 需要 tty：sxhkd 裸调静默失败，热键必须 `st -e sendfile` 包一层
- 二维码 st 窗口必须 `setsid` 起：否则 fzf 外层窗口关闭的 SIGHUP 连坐秒杀
- 关键: 服务端与二维码窗口都须 setsid 起。dash 无 job control, fzf 所在 st 窗口关闭时 SIGHUP 会连坐同会话的服务进程（症状: QR 窗口活着但服务已死, 扫码连不上）。验证法: script -qec 造 pty 跑完整链路, 窗口退出后查服务存活
- 热键版窗口超时别设太短(用户扫码常超 90 秒): 现 600s, 关窗即杀服务
- 排查终极武器: 脚本头部 exec >>/tmp/sendfile-debug.log 2>&1 + set -x, 热键环境问题全部现形
- 诊断网络: 让用户手机浏览器直接输 URL, 收到 404 页=网络通(查代码), 超时=路由隔离(查路由器 AP isolation)
- 服务用 Threading + serve_forever, 窗口 sleep 90 到期关窗杀服务; 成功传一次不自动退(允许多次下载)
- 中文/非 ASCII 文件名直接塞 Content-Disposition 会 latin-1 UnicodeEncodeError 崩：用 RFC 5987 `filename*=UTF-8''<pct-encoded>`，display name 用 `fname.encode('ascii','ignore')`
- URL path 里的中文要 `urllib.parse.quote(fname)`，服务端比较也用 quote 后的 expected path
- 别在含 `pkill -f sendfile` 的同一命令里操作（bash 包装进程命令行含匹配串会被误杀，整个命令 SIGTERM）
- 本机已有 `qrshare`（剪贴板→二维码）、`localsend`（图形 LocalSend app），勿重复造

# 番茄钟 (focus)
- `~/.local/bin/focus [分钟]` 默认 25；热键 `Super+Ctrl+F`
- 机制：记录 mpc 播放态→暂停；`dunstctl set-paused true`；后台 sleep 到点→恢复音乐+通知+ffmpeg 合成叮声
- 验证法：开钟后 `dunstctl is-paused`=true，到点后变 false
- 坑：pkill 自身包装进程——分离删除/杀进程与起服务的命令
