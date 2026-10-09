# Rime schema packs: 万象拼音 + rime-llm-translator

Recipes for installing third-party Rime schema packs into the fcitx5 user dir (`~/.local/share/fcitx5/rime`) and wiring the LLM translator to an arbitrary OpenAI-compatible endpoint.

## 万象拼音 (rime-wanxiang) + octagram grammar model

1. Download release zip (base = 全拼/双拼 no auxiliary codes; Pro variants carry 辅助码) from `amzxyz/rime-wanxiang` releases. Stop fcitx5 first (`pkill -x fcitx5`).
2. `unzip -o rime-wanxiang-base.zip` into the rime user dir — schema, `lua/`, `dicts/` land alongside existing rime-ice files.
3. Grammar model: download `wanxiang-lts-zh-hans.gram` (~400MB, `amzxyz/RIME-LMDG` release `LTS`) into the user dir ROOT. No config needed — `wanxiang.schema.yaml` already declares `grammar.language: wanxiang-lts-zh-hans` and the octagram plugin ships with apt `librime-plugin-octagram`. First candidate after schema switch is slow while the model loads — normal.
4. **CRITICAL PITFALL — the pack's bundled `default.yaml` clobbers the existing one.** Wanxiang's default.yaml is minimal (no `punctuator:`/`navigator:` sections); rime-ice and double_pinyin schemas `import_preset: default` and then fail to compile with `unresolved dependency: Include(default:/punctuator/...)`. Fix: restore the previous default.yaml (e.g. `git show HEAD:default.yaml` — the rime-ice clone tracks it) and only *insert* `- schema: wanxiang` at the top of `schema_list`, never take the pack's whole file.
5. Rebuild and verify: `rime_deployer --build ~/.local/share/fcitx5/rime /usr/share/rime-data` — must be error-free; check `build/wanxiang.schema.yaml` and the other schemas all present. Restart fcitx5, select rime.

## rime-llm-translator (pinyin → LLM association, `vv` trigger)

AUR-only package; install from source on Debian/Mint:
1. `git clone` SHORiN-KiWATA/rime-llm-translator. Copy `src/llm_translator.lua` → `<rime user dir>/lua/`, `src/rime-llm-config` → `~/.local/bin/` (chmod +x). Requires librime-lua (apt `librime-plugin-lua`).
2. Config lives in `~/.config/rime-llm-translator/state.json` (start from `src/default_state.json` as template). Add a profile with `api_url` = `<base>/chat/completions` (OpenAI-compatible), `api_key`, `model`; set it as `active_profile`. Then `rime-llm-config sync` exports `config.lua` (Lua reads that; the CLI reads state.json — always sync after hand-editing state.json).
3. `rime-llm-config init` writes `rime.lua` (`llm_translator = require("llm_translator")` + `llm_processor = llm_translator.processor`) and auto-patches `rime_ice.custom.yaml` when it detects rime-ice. It does NOT know other schemas — for wanxiang (or any non-ice schema) hand-write `<schema>.custom.yaml` mirroring the ice patch:
   - `speller/alphabet`: original schema alphabet + `.,?'!:<>\` (keep the schema's own chars — wanxiang has digits and `/;\`` that ice lacks)
   - `engine/processors/@before 0": lua_processor@llm_processor`
   - `engine/translators/@before 0": lua_translator@llm_translator`
   - `recognizer/patterns/llm_pinyin`: `^[a-z][a-z.,?'!:<>/\\]*$`
4. Rebuild via `rime_deployer --build` and grep `build/<schema>.schema.yaml` for `lua_translator@llm_translator` to confirm the patch compiled in.
5. Usage: type pinyin then `vv` to send the whole buffer to the LLM; two-letter prefixes (`call:` ask, `eng:`/`jp:` translate, `cmd:` command gen). Reconfigure via `rime-llm-config` TUI.

## Verifying an HTTP-profile LLM backend without the IM

`rime-llm-config ask` only supports CLI backends — it errors `not a CLI backend` for HTTP profiles. Verify connectivity with a direct curl to the chat/completions endpoint (small max_tokens, pinyin test string) and check the assistant content is the restored Chinese. A reasoning/thinking model adds visible latency per candidate — note it to the user; prefer non-thinking or flash-tier profiles for snappy IM use.

## End-to-end verification by driving librime via ctypes (no GUI needed)

Prove the whole IME+LLM pipeline (schema patch, processor trigger, translator, HTTP call, candidate injection) headlessly by scripting librime directly. Keep the script as `scripts/rime_llm_drive.py` and adapt the typed string per test.

- **Stop fcitx5 first** (`pkill -x fcitx5`) — librime holds a single-instance lock on the user data dir; a second instance under the running fcitx5 conflicts.
- **librime.so.1 exports C++-mangled symbols only** (no plain `RimeSetup`): bind them explicitly, e.g. `setattr(lib, "RimeProcessKey", getattr(lib, "_Z14RimeProcessKeymii"))`. Get the exact mangled names with `nm -D /lib/x86_64-linux-gnu/librime.so.1 | grep Rime`.
- **ctypes struct layout must match rime_api.h exactly** — first field is `int data_size` (NOT size_t), and RimeTraits has a `modules` pointer between `app_name` and `min_log_level`; RimeMenu embeds the `candidates` array pointer (candidates are NOT on RimeContext). Wrong layout = silent core dump with no useful traceback. Fetch the header (`src/rime_api.h` of the matching librime tag) and mirror field-for-field.
- Flow: `RimeSetup`+`RimeInitialize` (traits: shared_data_dir=/usr/share/rime-data, user_data_dir=~/.local/share/fcitx5/rime) → `RimeCreateSession` → `RimeSelectSchema(sid, b"wanxiang")` → `RimeProcessKey(ord(ch), 0)` per char with ~0.12 s sleep → poll `RimeGetContext` for candidate changes.
- **Set `RIME_LLM_TRACE=/path/to/log`** in the script's env — llm_translator.lua traces processor arming, translator send_text, and every candidate decision there; it is the fastest way to see whether the `vv` trigger fired at all.
- **False-negative pitfall: candidate list unchanged after trigger ≠ LLM failed.** If the schema's own dictionary already ranks the correct sentence first, the LLM candidate (same text, higher quality) produces an identical visible list. Two reliable discriminators: (a) type `test` + `vv` — the translator yields a built-in `✅ rime-llm-translator 挂载成功!` candidate; (b) type deliberately misspelled pinyin (e.g. `jintain` for `jintian`) so the dictionary's wrong segmentation differs visibly from the LLM's restored sentence.
- **Corroborate server-side**: `~/.cache/rime-llm-translator/usage.json` records per-request model/token counts and `replies.json` caches the returned text — proof the HTTP call actually hit the configured model, independent of what the candidate UI shows.
- Restart fcitx5 after the test (`fcitx5 -d`) and re-select rime so the user's session is live again.
