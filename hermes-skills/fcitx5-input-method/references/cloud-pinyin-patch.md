# fcitx5 cloud pinyin: enable, ☁ label patch, verification

## Enable

- `~/.config/fcitx5/conf/pinyin.conf` (stop fcitx5 first via `fcitx5-remote -e`): `CloudPinyinEnabled=True`, `CloudPinyinIndex=2`. Backend in `conf/cloudpinyin.conf`: `Enabled=True`, `Backend=Google` (Google endpoint works; Baidu's olime endpoint returns errors — don't use).

## ☁ label patch

- fcitx5 cloud pinyin has NO built-in "from cloud" label (that was fcitx4). Patch `fill()` in `modules/cloudpinyin/cloudpinyin_public.h`: `setText("\xe2\x98\x81 " + hanzi)` (☁ prefix; comment text does not render in single-line classicui, prefix does). The header is consumed by libpinyin.so, so rebuild BOTH pinyin and cloudpinyin targets and install both .so into the fcitx5 module dir (Debian: `/usr/lib/x86_64-linux-gnu/fcitx5/`; Void: `/usr/lib/fcitx5/`). Package upgrades clobber the patch — re-run the build.
- GOTCHA: building is not installing — if cloud candidates show no ☁, diff md5 of `~/src/fcitx5-chinese-addons/build/bin/libpinyin.so` vs the installed one; patched one contains the ☁ bytes (`LC_ALL=C grep -c $'\xe2\x98\x81' libpinyin.so` > 0; plain grep/strings miss UTF-8 in binaries). After install, restart via `fcitx5-remote -e` + `fcitx5 -d`.
- Void build recipe (5.1.13 addons + 5.1.21 core): clone tag 5.1.13 (5.1.14/5.1.15 require core ≥5.1.22 — check REQUIRED_FCITX_VERSION before picking a tag), `cmake -B build -DENABLE_GUI=OFF -DENABLE_BROWSER=OFF -DENABLE_TEST=OFF -DENABLE_LUA_ADDON=OFF` + `cmake --build build --target pinyin cloudpinyin`; .so land in `build/bin/`. Deps: extra-cmake-modules libfcitx5-devel libime-devel opencc-devel boost-devel libcurl-devel cmake.
- Patched source lives at `~/src/fcitx5-chinese-addons`; the diff is exported as `fcitx5-cloudpinyin-patch/cloud-icon.patch` in the mac6void dotfiles repo (reapply with `git apply` after a clean clone).

## Verification

- Cloud candidates only appear for words the LOCAL dicts don't already have (dedup kills identical ones) — test with a long absurd phrase like `aobamahepulujingjixue`, wait ~5s, screenshot: candidate shows "☁ 奥巴马和铺路经济学". Frequent words (nihao, neijuan) never show ☁ — not a failure.
- Connection-side proof: `ss -tnp | grep fcitx5` shows established :443 to Google during input.
- `strings` filters non-ASCII: verify UTF-8 patch strings with `grep -ac` / `LC_ALL=C grep`, not `strings | grep`.
