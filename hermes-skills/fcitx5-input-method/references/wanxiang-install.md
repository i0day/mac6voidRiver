# 万象拼音 (wanxiang) 完整安装 — Void Linux / fcitx5

万象重度依赖 librime 的 Lua 插件；Void 官方 librime 编译时 **没带 Lua**（`ldd /usr/lib/librime.so | grep lua` 为空即中招），方案会静默失效（选上后输入无任何候选，无报错）。

## 步骤

1. **编译带 Lua 的 librime**（源码在 `~/src/librime`，tag 1.17.0）：
   ```
   sudo xbps-install -y cmake boost-devel lua54-devel yaml-cpp-devel leveldb-devel marisa-devel opencc-devel glog-devel
   git clone --depth=1 --branch 1.17.0 https://github.com/rime/librime
   cd librime && bash install-plugins.sh hchunhui/librime-lua
   cmake -B build -DCMAKE_BUILD_TYPE=Release -DBUILD_TEST=OFF -DENABLE_LOGGING=ON
   cmake --build build -j2 && sudo cmake --install build
   ```
   - `make merged-plugins` 会因缺 GTest 失败；直接 cmake `-DBUILD_TEST=OFF` 绕过。
   - 验证：`ldd /usr/lib/librime.so.1.17.0 | grep lua` 出现 liblua5.4。
2. **下载 base 包**：`https://github.com/amzxyz/rime-wanxiang/releases/latest` → `rime-wanxiang-base.zip`（全拼/双拼标准版）。
3. **装入 `~/.local/share/fcitx5/rime/`**（先停 fcitx5，先备份旧 wanxiang* / lua / opencc / dicts）：
   - 根目录：`wanxiang.{dict,schema}.yaml`、`wanxiang_algebra.yaml`、**`wanxiang_symbols.yaml`（漏了会报 `unresolved dependency: Include(wanxiang_symbols:/symbol_table)`）**
   - 5 个依赖：`wanxiang_{mixedcode,reverse,english,abbrev}.{dict,schema}.yaml`、`wanxiang_phrase.schema.yaml`
   - `dicts/` 整个目录（zi/jichu/lianxiang 等共享基础词库）
   - `lua/wanxiang/` + `lua/data/`（super_processor 等大量 lua 脚本与数据）
   - `opencc/wanxiang_*.json`
   - `custom/wanxiang.custom.yaml` 复制到用户根目录（内含 `wanxiang_algebra:/base/全拼` 拼写选择）
4. `rime_deployer --build ~/.local/share/fcitx5/rime` → 出现 `wanxiang.prism.bin` + `wanxiang.table.bin` 即成功（400MB .gram 语法模型编译要几分钟）。
5. `default.custom.yaml` 的 schema_list 加 `- schema: wanxiang`，重启 fcitx5，F4 或直接选 rime 测试。

## 排错要点

- 方案选中但输入无候选、无 preedit：先查 librime 是否带 Lua（`ldd | grep lua`）；再查 schema 的 `dependencies:` 列表里每个 dict 是否存在。
- `rime_deployer` 的报错看 stderr 的 `unresolved dependency` 行，直接指出缺哪个 yaml。
- `Error opening db 'essay' read-only` 是无害警告（essay.txt 在 /usr/share/rime-data 存在即可）。
- 语法模型 `language: wanxiang-lts-zh-hans` 对应根目录 `wanxiang-lts-zh-hans.gram`，必须与词库版本配套。
