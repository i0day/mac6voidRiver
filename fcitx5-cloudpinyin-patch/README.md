# fcitx5 云拼音 ☁ 图标补丁 + 搜狗词库（2026-10-05）

## 1. 云拼音 ☁ 前缀补丁

fcitx5 云拼音候选默认无标识。补丁给云候选加 ☁ 前缀：
`modules/cloudpinyin/cloudpinyin_public.h` 的 `fill()`：

```cpp
setText(fcitx::Text("\xe2\x98\x81 " + hanzi));   // "☁ " + 词
```

补丁文件：`cloud-icon.patch`（基于 ~/src/fcitx5-chinese-addons 5.1.13 源码）。

### 重新编译安装（xbps 升级 fcitx5-cloudpinyin/chinese-addons 覆盖后执行）
```sh
cd ~/src/fcitx5-chinese-addons
git apply ~/mac6void/fcitx5-cloudpinyin-patch/cloud-icon.patch   # 若源码未含补丁
cmake --build build --target pinyin cloudpinyin
# 关键：build 完必须安装！只 build 不装 = 补丁不生效（今天踩过）
sudo cp build/bin/libpinyin.so build/bin/libcloudpinyin.so /usr/lib/fcitx5/
fcitx5-remote -e; sleep 2; fcitx5 -d
```

验证补丁在库里：`LC_ALL=C grep -c $'\xe2\x98\x81' /usr/lib/fcitx5/libpinyin.so` 应 > 0
（普通 grep/strings 会漏报二进制里的 UTF-8，必须 LC_ALL=C grep）。

验证生效：输入较长词（如 jinmantianhua），等 1-3 秒，候选第 2 位出现 ☁ 前缀词。
高频词（你好吗）本地=云端结果被去重，不出 ☁ 属正常。
云连接旁证：`ss -tnp | grep fcitx5` 有到 Google :443 的 ESTAB。

## 2. 搜狗词库

`~/.local/share/fcitx5/pinyin/dictionaries/sougou.dict`（136MB，
md5 be6b060265c7ac97cf2aef59fd0ad8fa，由 .scel 经 libime 转换，
参考 AUR fcitx5-pinyin-sougou-dict，自定义 license）。
pinyin 插件重启自动加载，无需改配置。文件太大不入 git，需要时重新转换。

同目录还有 zhwiki-20260416.dict（32MB，felixonmars/fcitx5-pinyin-zhwiki
release）和 web-slang-20260416.dict，同样自动加载。

## 3. 安全规则（血的教训）

**绝不在 Hermes agent 终端里 `pkill fcitx5`** —— 会在持有 X 键盘 filter 时
把运行 Hermes 的终端冻死。唯一允许的停止方式：
`fcitx5-remote -e`（DBus 优雅退出）→ sleep 2 → `fcitx5 -d` 重拉。
优雅退出无效时停下来让用户自己在会话里杀，不要升级成 pkill。
