# ~/.profile

# Load ~/.bashrc for bash login shells (SSH, console login, etc.)
if [ -n "$BASH_VERSION" ] && [ -f "$HOME/.bashrc" ]; then
    . "$HOME/.bashrc"
fi