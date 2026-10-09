---
name: firefox-nonofficial-ctrlaltr-patch
description: Fix Ctrl+Alt+R restarting Firefox instead of reader mode.
---

# Firefox 非 official 构建 Ctrl+Alt+R 劫持修复

## 根因
Void/非 official 构建 `AppConstants.MOZILLA_OFFICIAL=false`（查：`unzip -p /usr/lib/firefox/omni.ja modules/AppConstants.sys.mjs | grep MOZILLA_OFFICIAL`）。
`browser-main.js` 因此加载 `browser-development-helpers.js`，它向 mainKeyset **prepend** `key_quickRestart`（key=r, accel+alt），抢在 `key_toggleReaderMode`（同键）前面 → Ctrl+Alt+R = "Restart (Developer)"（菜单文件里可见此条目）。

## 修复（不换构建）
1. 退出 Firefox（mmap 中的 omni.ja 不能热改）。
2. 解出并改 `browser/omni.ja` 里的 `chrome/browser/content/browser/browser-development-helpers.js`：把 `init()` 中 `this.addRestartShortcut();` 注释掉（quickRestart 函数保留，Browser Console 仍可用）。
3. `zip -X omni.ja.work chrome/browser/content/browser/browser-development-helpers.js` 更新副本，`sudo cp` 回 `/usr/lib/firefox/browser/omni.ja`。
   - 注意：omni.ja 首条目必须保持 Stored（zip -X 更新不破坏）；直接 zip 原文件会 permission denied，须 copy-roundtrip。
4. 重启 Firefox 验证：按 Ctrl+Alt+R 应进 about:reader 且 `pgrep -x firefox` PID 不变。

## 本机状态 (2026-10-04)
- 已打补丁并验证生效（reader 正常，无重启）。
- 补丁件与原始备份存于 `~/.local/share/firefox-omni-patch/`（browser-development-helpers.js.patched / omni.ja.orig）。
- **Firefox 每次 xbps 升级会覆盖补丁** → 症状复发时重新套用 patched 文件即可（zip 进新 omni.ja）。
- sxhkd 侧 `@alt+ctrl+shift+r` → `~/.local/bin/reader` 后备仍在；`@alt+ctrl+r` 保持注释。
