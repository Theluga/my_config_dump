# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.

# ===== 1. Powerlevel10k Instant Prompt (MUST BE FIRST) =====
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ===== 2. Environment & General Options =====
export TERM="xterm-256color"
export EDITOR='/usr/bin/nano'

# POWERLEVEL9K_DISABLE_GITSTATUS=true

HISTFILE=$HOME/.zhistory
SAVEHIST=50000
HISTSIZE=50000
setopt correct                  # Auto correct mistakes
setopt nobeep                   # No beep
setopt histignorespace          # Don't save commands that start with space
setopt APPEND_HISTORY           # Append to history, don't overwrite
setopt SHARE_HISTORY            # Share history across multiple zsh sessions
setopt HIST_IGNORE_ALL_DUPS     # Delete old recorded entry if new entry is a duplicate
setopt HIST_REDUCE_BLANKS       # Remove superfluous blanks before recording entry
setopt HIST_VERIFY              # Show command with history expansion to user before running it
setopt INC_APPEND_HISTORY       # Add commands to history immediately, not when shell exits

# ===== 3. Completions Setup (MUST BE BEFORE ZSTYLE/PLUGINS) =====
fpath=(/usr/share/zsh/site-functions $fpath)

autoload -Uz compinit
compinit
zmodload zsh/complist           # Required for the 'menu select' dropdown to work

zstyle ':completion:*' matcher-list 'm:{[:lower:][:upper:]}={[:upper:][:lower:]}' # Case insensitive
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"         # Colored completion
zstyle ':completion:*' rehash true                              # Auto find new executables
zstyle ':completion:*' menu select                              # Highlight menu selection
zstyle ':completion:*:descriptions' format '%B%d%b'
zstyle ':completion:*:messages' format '%d'
zstyle ':completion:*:warnings' format 'No matches for: %d'
zstyle ':completion:*:groups' name
zstyle ':completion:*:corrections' format ' %F{green}-- %d (errors: %e)%f'
zstyle ':completion:*' accept-exact '*(N)'
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path ~/.zsh/cache

# ===== 4. Aliases & External Sources =====
source "${XDG_CACHE_HOME:-$HOME/.local}/share/command_not_found.zsh"
source "${XDG_CACHE_HOME:-$HOME/.local}/share/termcap.zsh" # man colorized

alias update-mirror="rate-mirrors arch --completion=1 --max-delay=100 --sort-mirrors-by=score_asc | sudo tee /etc/pacman.d/mirrorlist"
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'
alias ls='ls --color=auto'
alias bat='bat --color=always --paging=never --theme=TwoDark'

# ===== 5. Theme Initialization =====
source /usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# ===== 6. Core Keybindings & Custom Widgets =====
bindkey "^[[3~" delete-char
bindkey  "^[[H"   beginning-of-line
bindkey  "^[[F"   end-of-line
bindkey '^H' backward-kill-word
bindkey '^[[3;5~' kill-word
bindkey '^[[1;5D' backward-word     # Ctrl+Left
bindkey '^[[1;5C' forward-word      # Ctrl+Right
bindkey '^[[1;5H' beginning-of-buffer-or-history
bindkey '^[[1;5F' end-of-buffer-or-history


set_block_cursor() { printf '\e[1 q'; }
set_line_cursor() { printf '\e[3 q'; }

toggle_overtype_mode() {
     if [[ $ZLE_STATE == *"overwrite"* ]]; then
        set_block_cursor
        zle overwrite-mode
    else
        set_line_cursor
        zle overwrite-mode
    fi
}
handle_enter() {
#    zle accept-line    
    set_block_cursor
    zle .accept-line
}

zle -N toggle_overtype_mode
zle -N handle_enter

bindkey '^[[2~' toggle_overtype_mode
bindkey '^M' handle_enter

# ===== 7. Plugins (ORDER IS CRITICAL) =====

# 7a. Autosuggestions
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
ZSH_AUTOSUGGEST_STRATEGY=(match_prev_cmd history completion)
ZSH_AUTOSUGGEST_CLEAR_WIDGETS+=(handle_enter)


# 7b. Fast Syntax Highlighting
source /usr/share/zsh/plugins/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh

# 7c. History Substring Search (MUST be sourced after syntax highlighting)
source /usr/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down

# 8. fzf
source <(fzf --zsh)
# Use an if/else statement to check if the item is a directory (-d)
export FZF_DEFAULT_OPTS="--preview 'if [ -d {} ]; then ls -la --color=always {}; else bat --color=always --style=numbers --line-range :100 {}; fi'"
export FZF_COMPLETION_OPTS="--preview 'if [ -d {} ]; then ls -la --color=always {}; else bat --color=always --style=numbers --line-range :100 {}; fi'"
