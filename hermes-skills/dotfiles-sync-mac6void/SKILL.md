---
name: dotfiles-sync-mac6void
description: 同步本机 dotfiles 并推送到 github mac6void 仓库。
---

# 同步本机 dotfiles → github i0day/mac6void

仓库 clone 在 `~/mac6void`（分支 master），镜像本机 Void 机 dotfiles。推送凭据：`GIT_ASKPASS=~/askpass.sh`（token `~/gittoken`）。不带 GIT_ASKPASS 直接 push 会报 `could not read Username`。

## 仓库布局（live 路径 → 仓库路径）
- `~/.xinitrc` → `.xinitrc`
- `~/.config/<app>/**` → `.config/<app>/**`（sxhkd, fcitx5, rofi, dunst, fontconfig, yazi, fin, htop, Thunar, speech-dispatcher, jellyfin-tui, wal hooks 等）
- `~/.local/bin/*` → `local/bin/*`
- dwm/dmenu/st 源码 → `dwm/` `dmenu/` `st/`；系统级 → `etc/`；Firefox 补丁 → `firefox-patch/`

## 同步流程
1. `cd ~/mac6void && git fetch origin`（用 GIT_ASKPASS）
2. 找差异：对每个 live 配置 `diff -q ~/live repo镜像`；对 `~/.local/bin/*` 逐个比 `local/bin/`。用 execute_code 循环，别手比。
3. 新文件先 `mkdir -p` 仓库镜像目录再 cp；删除的文件 `git rm`。
4. 提交中文 commit message，push：`GIT_ASKPASS=~/askpass.sh git push origin master`。

## 关键事实 / 坑
- 本机全局热键只用 **sxhkd**（`~/.config/sxhkd/sxhkdrc`，@=按下触发，`pkill -USR1 -x sxhkd` 热重载）。xbindkeys 已弃用卸载——仓库里不要再出现 `.xbindkeysrc`，文档提到 xbindkeys 只作为历史注脚。
- 本机是 Void Linux（runit），不是 Mint；文档/路径引用用 `~/mac6void/...`，不要写 `~/oldmacmint/...`（那是旧 Mint 机仓库）。
- 仓库内 KEYBINDINGS.md 是热键手册，改热键后须同步更新其头部（更新日期+配置文件路径）。
- live 的 `~/KEYBINDINGS.md` 可能是旧版残留，以仓库版为准，别盲目反向覆盖。
- 对比时排除噪音：cache、*.log、autoload、recent、*.bak、transmission stats.json 之类运行时状态。
