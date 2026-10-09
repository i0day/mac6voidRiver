# Known-good dunstrc for dunst 1.9.x (user: LXGW WenKai + JetBrainsMono Nerd Font Mono setup).
# Copy to ~/.config/dunst/dunstrc. Section MUST be [global] (not [dunst] — that's 1.10+).
[global]
    font = "JetBrainsMono Nerd Font Mono 16"
    width = (480..640)
    height = 160
    notification_limit = 0
    progress_bar = true
    progress_bar_height = 16
    progress_bar_min_width = 300
    progress_bar_max_width = 500
    horizontal_padding = 16
    text_icon_padding = 14

[urgency_low]
    timeout = 4
    background = "#222222"
    foreground = "#bbbbbb"

[urgency_normal]
    timeout = 6
    background = "#222222"
    foreground = "#eeeeee"

[urgency_critical]
    timeout = 0
    background = "#5c1a1a"
    foreground = "#ffdede"
