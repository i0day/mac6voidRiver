#!/usr/bin/env bash
# regenerate fcitx5 theme on wal palette change
. "$1"
$HOME/.local/bin/fcitx5-waltheme >/dev/null 2>&1 || true
