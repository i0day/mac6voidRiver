#!/usr/bin/env python3
"""Drive librime via ctypes (1.17 ABI): load a schema, type pinyin + vv trigger,
dump candidates, and detect LLM candidate arrival by diffing the list.

Usage: RIME_LLM_TRACE=/tmp/trace.log python3 rime_llm_drive.py [pinyin]
Prereq: fcitx5 must be stopped (single-instance lock on the rime user dir).
LLM evidence files: ~/.cache/rime-llm-translator/{usage,replies}.json
"""
import ctypes as C
import sys
import time
import os

PINYIN = sys.argv[1] if len(sys.argv) > 1 else "jintaintianqizenmeyang"  # deliberately misspelled
SCHEMA = os.environ.get("RIME_SCHEMA", b"wanxiang")

lib = C.CDLL("librime.so.1")
# librime.so.1 exports C++-mangled names only; verify with:
#   nm -D /lib/x86_64-linux-gnu/librime.so.1 | grep Rime
for plain, mang in {
    "RimeSetup": "_Z9RimeSetupP13rime_traits_t",
    "RimeInitialize": "_Z14RimeInitializeP13rime_traits_t",
    "RimeFinalize": "_Z12RimeFinalizev",
    "RimeCreateSession": "_Z17RimeCreateSessionv",
    "RimeSelectSchema": "_Z16RimeSelectSchemamPKc",
    "RimeProcessKey": "_Z14RimeProcessKeymii",
    "RimeGetContext": "_Z14RimeGetContextmP14rime_context_t",
    "RimeFreeContext": "_Z15RimeFreeContextP14rime_context_t",
    "RimeGetStatus": "_Z13RimeGetStatusmP13rime_status_t",
    "RimeFreeStatus": "_Z14RimeFreeStatusP13rime_status_t",
}.items():
    setattr(lib, plain, getattr(lib, mang))


class Traits(C.Structure):  # mirror rime_api.h rime_traits_t exactly
    _fields_ = [
        ("data_size", C.c_int),
        ("shared_data_dir", C.c_char_p),
        ("user_data_dir", C.c_char_p),
        ("distribution_name", C.c_char_p),
        ("distribution_code_name", C.c_char_p),
        ("distribution_version", C.c_char_p),
        ("app_name", C.c_char_p),
        ("modules", C.POINTER(C.c_char_p)),
        ("min_log_level", C.c_int),
        ("log_dir", C.c_char_p),
        ("prebuilt_data_dir", C.c_char_p),
        ("staging_dir", C.c_char_p),
    ]


class Composition(C.Structure):
    _fields_ = [("length", C.c_int), ("cursor_pos", C.c_int),
                ("sel_start", C.c_int), ("sel_end", C.c_int), ("preedit", C.c_char_p)]


class Candidate(C.Structure):
    _fields_ = [("text", C.c_char_p), ("comment", C.c_char_p), ("reserved", C.c_void_p)]


class Menu(C.Structure):  # candidates live HERE, not on Context
    _fields_ = [("page_size", C.c_int), ("page_no", C.c_int), ("is_last_page", C.c_int),
                ("highlighted_candidate_index", C.c_int), ("num_candidates", C.c_int),
                ("candidates", C.POINTER(Candidate)), ("select_keys", C.c_char_p)]


class Context(C.Structure):
    _fields_ = [("data_size", C.c_int), ("composition", Composition), ("menu", Menu),
                ("commit_text_preview", C.c_char_p), ("select_labels", C.POINTER(C.c_char_p))]


class Status(C.Structure):
    _fields_ = [("data_size", C.c_int), ("schema_id", C.c_char_p), ("schema_name", C.c_char_p),
                ("is_disabled", C.c_int), ("is_composing", C.c_int), ("is_ascii_mode", C.c_int),
                ("is_full_shape", C.c_int), ("is_simplified", C.c_int), ("is_traditional", C.c_int),
                ("is_ascii_punct", C.c_int)]


lib.RimeSetup.argtypes = [C.POINTER(Traits)]
lib.RimeInitialize.argtypes = [C.POINTER(Traits)]
lib.RimeCreateSession.restype = C.c_ulong
lib.RimeSelectSchema.argtypes = [C.c_ulong, C.c_char_p]
lib.RimeProcessKey.argtypes = [C.c_ulong, C.c_int, C.c_int]
lib.RimeGetContext.argtypes = [C.c_ulong, C.POINTER(Context)]
lib.RimeGetStatus.argtypes = [C.c_ulong, C.POINTER(Status)]

tr = Traits()
tr.data_size = C.sizeof(Traits)
tr.shared_data_dir = b"/usr/share/rime-data"
tr.user_data_dir = os.path.expanduser("~/.local/share/fcitx5/rime").encode()
tr.app_name = b"rime_llm_drive"
tr.min_log_level = 3
lib.RimeSetup(C.byref(tr))
lib.RimeInitialize(C.byref(tr))
sid = lib.RimeCreateSession()
lib.RimeSelectSchema(sid, SCHEMA)
st = Status()
st.data_size = C.sizeof(Status)
lib.RimeGetStatus(sid, C.byref(st))
print("schema:", st.schema_id.decode(), "/", st.schema_name.decode(), flush=True)


def key(ch):
    lib.RimeProcessKey(sid, ord(ch), 0)
    time.sleep(0.12)


def cand_texts():
    ctx = Context()
    ctx.data_size = C.sizeof(Context)
    out = []
    if lib.RimeGetContext(sid, C.byref(ctx)):
        for i in range(ctx.menu.num_candidates):
            c = ctx.menu.candidates[i]
            out.append((c.text.decode() if c.text else "",
                       c.comment.decode() if c.comment else ""))
        lib.RimeFreeContext(C.byref(ctx))
    return out


def dump(tag):
    pre_ctx = Context()
    pre_ctx.data_size = C.sizeof(Context)
    if lib.RimeGetContext(sid, C.byref(pre_ctx)):
        pre = pre_ctx.composition.preedit.decode() if pre_ctx.composition.preedit else ""
        print(f"[{tag}] preedit={pre!r}", flush=True)
        lib.RimeFreeContext(C.byref(pre_ctx))
    for i, (t, cm) in enumerate(cand_texts()):
        print(f"   {i+1}. {t}  // {cm[:70]}", flush=True)


for ch in PINYIN:
    key(ch)
dump("typed " + PINYIN)
baseline = cand_texts()
print("--- trigger: press v v ---", flush=True)
key("v")
key("v")
for t in range(45):
    time.sleep(1)
    if cand_texts() != baseline:
        print(f"LLM candidates arrived after ~{t+1}s (list changed)", flush=True)
        break
else:
    print("no change after 45s — check RIME_LLM_TRACE log and usage.json", flush=True)
dump("final")
lib.RimeFinalize()
