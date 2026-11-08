# vhs tape — record the AutoInstallTools demo with `vhs < docs/demo.tape`.
# The committed docs/demo.gif was generated from this script.

Output docs/demo.gif
Set Theme { "name": "Catppuccin Mocha", "black": "#1e1e2e", "red": "#f38ba8", "green": "#a6e3a1", "yellow": "#f9e2af", "blue": "#89b4fa", "magenta": "#f5c2e7", "cyan": "#89dceb", "white": "#cdd6f4", "brightBlack": "#45475a", "brightRed": "#f38ba8", "brightGreen": "#a6e3a1", "brightYellow": "#f9e2af", "brightBlue": "#89b4fa", "brightMagenta": "#f5c2e7", "brightCyan": "#89dceb", "brightWhite": "#bac2de" }
Set Shell "bash"
Set FontSize 14
Set Width 760
Set Height 400
Set Padding 0
Hide

Type "./ait install --profile web --dry-run"
Enter
Sleep 300ms
Type "y"
Enter
Sleep 2s
Ctrl+C
