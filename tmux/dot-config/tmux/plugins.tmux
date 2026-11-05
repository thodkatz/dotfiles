# Laptop plugins, through TPM (git clone https://github.com/tmux-plugins/tpm
# ~/.config/tmux/plugins/tpm, then prefix I). Sourced last by tmux.conf, which
# sets their options. The NixOS hosts get a generated plugins.tmux instead.
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'catppuccin/tmux#v2.1.3'
set -g @plugin 'omerxx/tmux-sessionx'
set -g @plugin 'laktak/extrakto'
set -g @plugin 'tmux-plugins/tmux-yank'
set -g @plugin 'tmux-plugins/tmux-resurrect'
set -g @plugin 'tmux-plugins/tmux-continuum'

# Auto-restore the last save when the laptop's tmux server starts (hosts: off).
set -g @continuum-restore 'on'

run '~/.config/tmux/plugins/tpm/tpm'
