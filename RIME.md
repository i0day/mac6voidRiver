# Rime 方案配置（fcitx5 · Void Linux）

用户目录：`~/.local/share/fcitx5/rime/`（rime-ice 雾凇 git clone 于此）

## 当前方案列表（default.custom.yaml）

1. `wanxiang` 万象拼音 v18.1.0（全拼，带 400MB 语法模型）
2. `rime_ice` 雾凇拼音（全拼）
3. `luna_pinyin` 朙月拼音（中州韵官方，默认繁体，Ctrl+Shift+4 切简体）

rime 内按 **F4** 打开方案选单切换。

## 关键坑（今天踩过）

- **Void 官方 librime 不带 Lua 插件** → 万象（重度 Lua 依赖）静默失效：选中后输入无任何候选、无报错。
  修复：源码编译 librime 1.17.0 + librime-lua（`~/src/librime`）：
  ```
  sudo xbps-install -y cmake boost-devel lua54-devel yaml-cpp-devel \
      leveldb-devel marisa-devel opencc-devel glog-devel
  git clone --depth=1 --branch 1.17.0 https://github.com/rime/librime
  cd librime && bash install-plugins.sh hchunhui/librime-lua
  cmake -B build -DCMAKE_BUILD_TYPE=Release -DBUILD_TEST=OFF -DENABLE_LOGGING=ON
  cmake --build build -j2 && sudo cmake --install build
  ```
  验证：`ldd /usr/lib/librime.so.1.17.0 | grep lua` 有 liblua5.4。
  （`make merged-plugins` 会因缺 GTest 挂掉，直接 cmake `-DBUILD_TEST=OFF` 绕过。）

- **万象 base 包必须装全**（`rime-wanxiang-base.zip`，GitHub amzxyz/rime-wanxiang releases）：
  - 根目录：`wanxiang.{dict,schema}.yaml`、`wanxiang_algebra.yaml`、`wanxiang_symbols.yaml`
    （漏 symbols 报 `unresolved dependency: Include(wanxiang_symbols:/symbol_table)`）
  - 5 个依赖：`wanxiang_{mixedcode,reverse,english,abbrev}.{dict,schema}.yaml`、`wanxiang_phrase.schema.yaml`
  - `dicts/`（zi/jichu/lianxiang 等基础词库）、`lua/wanxiang/`、`lua/data/`、`opencc/wanxiang_*.json`
  - `custom/wanxiang.custom.yaml` 要复制到用户根目录（内含拼写选择 `wanxiang_algebra:/base/全拼`）
  - 语法模型 `wanxiang-lts-zh-hans.gram` 放根目录，与词库版本配套

- **朙月拼音依赖**：`luna_pinyin.*`（rime/rime-luna-pinyin）+ `stroke.*`（反查笔画）+ `symbols.yaml`（标点，从 `/usr/share/rime-data/` 复制）。

- 部署：`rime_deployer --build ~/.local/share/fcitx5/rime`，看 `build/` 里出现
  `<schema>.table.bin` 才算成功；报错看 stderr 的 `unresolved dependency` 行。
  `Error opening db 'essay'` 是无害警告。

- 改方案列表/词库前**先停 fcitx5**（`fcitx5-remote -e`），它退出时会重写 conf。

## 本仓库文件

- `rime/default.custom.yaml` — 方案列表 patch（合并进你的用户目录用）
- `fcitx5-cloudpinyin-label.patch` — 云拼音「来自云」标签补丁（历史）
- `usr/bin/fcitx5-waltheme` — 候选窗 pywal 主题生成器（现为深黑底 #101418 + 白字）
- `usr/bin/fcitx5-imnext` — 输入法循环脚本
