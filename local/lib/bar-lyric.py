# bar-lyric — 输出 "♪ 歌名 · 当前同步歌词行" 供 dwm topbar (sbar) 使用
# 解释器写绝对路径: mutagen 装在此 python 里, sbar 的 xinitrc 环境 PATH 不含它
# 数据源: MPD 当前曲目的 ID3 SYLT 同步帧 (mutagen: frame.text = [(text, ms), ...])
import subprocess, os, re, functools

MUSIC_DIR = os.path.expanduser("~/Music")

def mpc_get(fmt):
    # mpc 0.35 的 status -f 不加字面标记; 用 `current`: 有当前曲才有输出, 停止/清空为空
    r = subprocess.run(["mpc", "-f", fmt, "current"], capture_output=True, text=True)
    out = r.stdout.strip()
    return out or None

@functools.lru_cache(maxsize=32)
def syllines(path):
    try:
        from mutagen.id3 import ID3
        t = ID3(path)
        key = next((k for k in t.keys() if "SYLT" in str(k).upper()), None)
        if not key:
            return ()
        # mutagen SYLT.text == [(text, ms), ...]
        out = [(int(ms), txt.strip()) for txt, ms in t[key].text if txt and txt.strip()]
        out.sort()
        return tuple(out)
    except Exception:
        return ()

def main():
    raw = subprocess.run(["mpc", "status"], capture_output=True, text=True).stdout
    playing = "[playing]" in raw
    # 默认行: [playing] #1/2   2:31/4:24 (57%)  -> 当前经过时间
    elapsed = 0
    m = re.search(r"(\d+:(?:\d+:)?\d+)(?=/)", raw)
    if m:
        parts = list(map(int, m.group(1).split(":")))
        if len(parts) == 3:
            elapsed = parts[0] * 3600 + parts[1] * 60 + parts[2]
        else:
            elapsed = parts[0] * 60 + parts[1]
    f = mpc_get("%file%") or ""
    t = mpc_get("%title%") or ""
    if not f:
        print("")
        return
    title = t or os.path.basename(f)
    apath = f if os.path.isabs(f) else os.path.join(MUSIC_DIR, f)
    lines = syllines(apath) if os.path.isfile(apath) else ()
    cur = ""
    ms = elapsed * 1000
    if lines:
        for lm, txt in lines:
            if lm <= ms:
                cur = txt
            else:
                break
    print(f"♪ {title} · {cur}" if cur else f"♪ {title}")

if __name__ == "__main__":
    main()
