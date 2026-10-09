# Firefox Ctrl+Alt+R 阅读模式补丁（Void 非 official 构建）

## 问题
Void 的 firefox 包 `MOZILLA_OFFICIAL=false`，`browser-main.js` 会加载
`browser-development-helpers.js`，向 mainKeyset prepend `key_quickRestart`
(key=r, accel+alt)，抢在原生 `key_toggleReaderMode`（同键）之前。
结果：Ctrl+Alt+R = "Restart (Developer)"，阅读模式失效。

## 补丁内容
`browser-development-helpers.js`：注释掉 `init()` 里的 `this.addRestartShortcut();`。
`quickRestart()` 保留（Browser Console 仍可用），只去掉全局抢键。

## 套用步骤（xbps 升级 firefox 后补丁被覆盖时执行）
```sh
# 1. 完全退出 Firefox
pkill -x firefox; sleep 3

# 2. copy-roundtrip 更新 omni.ja（直接写 /usr/lib 会 permission denied）
cd /tmp && rm -rf fxp && mkdir -p fxp/chrome/browser/content/browser && cd fxp
cp /usr/lib/firefox/browser/omni.ja .
cp ~/mac6void/firefox-patch/browser-development-helpers.js \
   chrome/browser/content/browser/browser-development-helpers.js
zip -X omni.ja chrome/browser/content/browser/browser-development-helpers.js
sudo cp omni.ja /usr/lib/firefox/browser/omni.ja

# 3. 重开 Firefox，按 Ctrl+Alt+R 应进 about:reader 且进程 PID 不变
```

注意：omni.ja 首条目必须保持 Stored（`zip -X` 更新不会破坏）；
不要用 `zip -r` 重建整个归档。

## 本机备份
原始归档备份：`~/.local/share/firefox-omni-patch/omni.ja.orig`（本机，未入库）
