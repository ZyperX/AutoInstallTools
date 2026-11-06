# AutoInstallTools shell conveniences. Safe to source; nothing here shadows a
# core command such as `cat` or `find` (B10).
alias ll='eza -lah --git 2>/dev/null || ls -lah'
alias la='ls -A'
alias ports='ss -tulpn'
