#
# ~/.bashrc
#
# ===== 1. Interactive shell guard =====
# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# ~/.bashrc — Minimal corporate-server configuration
# Dependencies: Bash + standard system utilities.
# Optional: Git
# No third-party shell plugins or package-manager assumptions.
# my work servers could have anything


# ===== 2. Environment =====
export EDITOR="${EDITOR:-nano}"
export VISUAL="${VISUAL:-$EDITOR}"
export PAGER="${PAGER:-less}"
export HISTFILE="$HOME/.bash_history"
export HISTSIZE=50000
export HISTFILESIZE=50000
export HISTCONTROL=ignoreboth:erasedups
export HISTTIMEFORMAT='%F %T  '

# export VCPKG_ROOT='$HOME/.local/share/vcpkg'


# ===== 3. History =====
shopt -s histappend
shopt -s cmdhist
shopt -s checkwinsize

# why did I make so much write/read calls? I gave up synchronization...
# # save new commands from other sessions and append our own.
# __history_sync() {
# 	history -a
# 	# history -n
# }
# PROMPT_COMMAND="__history_sync${PROMPT_COMMAND:+; $PROMPT_COMMAND}"

# ===== 4. Readline =====
set -o emacs

bind 'set completion-ignore-case on'
bind 'set show-all-if-ambiguous on'
bind 'set colored-stats on' 2>/dev/null || true

# Ctrl+Left / Ctrl+Right: move by word.
bind '"\e[1;5D": backward-word'
bind '"\e[1;5C": forward-word'
bind '"\e[5D": backward-word'
bind '"\e[5C": forward-word'
bind '"\eD": backward-word'
bind '"\eC": forward-word'

# Ctrl+Backspace / Ctrl+Delete.
bind '"\C-w": backward-kill-word'
bind '"\C-h": backward-kill-word'
bind '"\b": backward-kill-word'
bind '"\e[3;5~": kill-word'

# Home / End / Delete.
bind '"\e[H": beginning-of-line'
bind '"\e[F": end-of-line'
bind '"\e[1~": beginning-of-line'
bind '"\e[4~": end-of-line'
bind '"\e[3~": delete-char'

# Tab cycles through completion candidates.
bind 'set menu-complete-display-prefix on'
bind 'TAB: menu-complete'
bind '"\e[Z": menu-complete-backward'

# ===== Case-insensitive substring history search =====

__history_search_active=0
__history_search_original=''
__history_search_last_result=''
__history_search_query=''
__history_search_matches=()
__history_search_index=-1
__history_search_history=()

# Cache history once per search session.
__history_search_load_history() {
	mapfile -t __history_search_history < <(
		HISTTIMEFORMAT= builtin history |
			sed -E 's/^[[:space:]]*[0-9]+[[:space:]]+//'
	)

	# Bash history output is oldest first.
	# Reverse it so index 0 is the newest entry.
	local i j tmp
	i=0
	j=$((${#__history_search_history[@]} - 1))

	while ((i < j)); do
		tmp=${__history_search_history[i]}
		__history_search_history[i]=${__history_search_history[j]}
		__history_search_history[j]=$tmp
		((i++, j--))
	done
}

__history_search_reset() {
	__history_search_active=0
	__history_search_original=''
	__history_search_last_result=''
	__history_search_query=''
	__history_search_matches=()
	__history_search_index=-1
}

__history_substring_search() {
	local direction="$1"
	local line="${READLINE_LINE}"
	local query="${line}"
	local result
	local i

	# If the line is the last displayed result, keep cycling
	# through the existing matches instead of searching again.
	if ((__history_search_active)) &&
		[[ "$line" == "$__history_search_last_result" ]]; then
		:
	else
		# The user started a new query or edited the input.
		__history_search_active=1
		__history_search_original="$line"
		__history_search_last_result=''
		__history_search_query="$query"
		__history_search_index=-1
		__history_search_matches=()

		__history_search_load_history

		# Empty query: browse all history entries.
		# Non-empty query: case-insensitive substring search.
		for result in "${__history_search_history[@]}"; do
			if [[ -z "$query" ]] ||
				[[ "${result,,}" == *"${query,,}"* ]]; then
				__history_search_matches+=("$result")
			fi
		done
	fi

	local total=${#__history_search_matches[@]}

	((total > 0)) || return

	if [[ "$direction" == "backward" ]]; then
		# Up: move toward older entries.
		((__history_search_index++))
		((__history_search_index %= total))
	else
		# Down: move toward newer entries.
		if ((__history_search_index <= 0)); then
			# Restore the original typed query when moving past
			# the newest result.
			READLINE_LINE="$__history_search_original"
			READLINE_POINT=${#READLINE_LINE}
			__history_search_reset
			return
		fi

		((__history_search_index--))
	fi

	READLINE_LINE="${__history_search_matches[__history_search_index]}"
	READLINE_POINT=${#READLINE_LINE}
	__history_search_last_result="$READLINE_LINE"
}

__history_substring_backward() {
	__history_substring_search backward
}

__history_substring_forward() {
	__history_substring_search forward
}

# Bind Up/Down.
bind -x '"\e[A": __history_substring_backward'
bind -x '"\e[B": __history_substring_forward'

# Ctrl+R remains Bash's built-in reverse incremental history search.

# ===== 5. Colors =====
if command -v tput >/dev/null 2>&1 &&
	[[ -n ${TERM:-} && ${TERM:-dumb} != dumb ]] &&
	[[ -t 1 ]]; then
	__c_reset=$(tput sgr0 2>/dev/null)
	__c_blue=$(tput setaf 4 2>/dev/null)
	__c_green=$(tput setaf 2 2>/dev/null)
	__c_yellow=$(tput setaf 3 2>/dev/null)
	__c_red=$(tput setaf 1 2>/dev/null)
	__c_cyan=$(tput setaf 6 2>/dev/null)
	__c_purple=$(tput setaf 5 2>/dev/null)
else
	__c_reset=''
	__c_blue=''
	__c_green=''
	__c_yellow=''
	__c_red=''
	__c_cyan=''
	__c_purple=''
fi

# ===== 6. Aliases =====
alias ls='ls --color=auto'
alias ll='ls -lah'
alias la='ls -A'
alias l='ls -CF'
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'

alias cp='cp -i'
alias mv='mv -i'
alias rm='rm -I'
alias mkdir='mkdir -p'

alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

alias c='clear'
alias h='history'
alias j='jobs -l'
alias path='tr ":" "\n" <<< "$PATH"'

# ===== 7. Git prompt =====
__git_cache_path=''
__git_cache_time=0
__git_cache_value=''

__git_prompt() {
	local now branch status dirty

	command -v git >/dev/null 2>&1 || return 0

	now=$SECONDS

	# Cache by directory for up to two seconds.
	if [[ $PWD == "$__git_cache_path" ]] &&
		((now - __git_cache_time < 2)); then
		printf '%s' "$__git_cache_value"
		return
	fi

	__git_cache_path=$PWD
	__git_cache_time=$now
	__git_cache_value=''

	branch=$(git symbolic-ref --quiet --short HEAD 2>/dev/null) ||
		branch=$(git rev-parse --short HEAD 2>/dev/null) ||
		return 0

	status=$(git status --porcelain --untracked-files=normal 2>/dev/null) ||
		return 0

	if [[ -n $status ]]; then
		dirty='*'
		__git_cache_value=" 🍂${__c_yellow}git:${branch}${dirty}${__c_reset}"
	else
		__git_cache_value=" 🌿${__c_green}git:${branch}${__c_reset}"
	fi

	printf '%s' "$__git_cache_value"
}

# ===== 8. Prompt =====

__set_prompt() {
	local rc=$?

	local user_host path git_info
	user_host="👤\u@\h"
	path="📁\w"
	git_info="$(__git_prompt)"

	if ((rc == 0)); then
		PS1="${__c_green}${user_host}${__c_reset} ${__c_blue}${path}${__c_reset}${git_info}\n${__c_purple} ❯ ${__c_reset} "
	else
		PS1="${__c_red}${user_host} [exit:${rc}]${__c_reset} ${__c_blue}${path}${__c_reset}${git_info}\n${__c_purple} ❯ ${__c_reset} "
	fi
}

#PS0=$'\e[1A\e[2K\r' # I give up trying to remove the title prompt from the terminal

[[ ";$PROMPT_COMMAND;" != *";__set_prompt;"* ]] &&
	PROMPT_COMMAND="__set_prompt${PROMPT_COMMAND:+; $PROMPT_COMMAND}"

# ===== 9. Git aliases =====
alias g='git'
alias gs='git status --short --branch'
alias gst='git status'
alias gd='git diff'
alias gds='git diff --staged'
alias gl='git log --oneline --decorate -20'
alias gpl='git pull'
alias gps='git push'
alias gco='git checkout'
alias gcp='git cherry-pick'
alias gsw='git switch'
alias gb='git branch'
alias ga='git add'
alias gc='git commit'
alias gcm='git commit -m'

# ===== 10. Utility functions =====

mkcd() {
	[[ $# -eq 1 ]] || {
		printf 'Usage: mkcd DIRECTORY\n' >&2
		return 2
	}
	command mkdir -p -- "$1" && cd -- "$1"
}


extract() {
	[[ $# -gt 0 ]] || {
		printf 'Usage: extract ARCHIVE...\n' >&2
		return 2
	}

	local archive status=0

	for archive in "$@"; do
		if [[ ! -f $archive ]]; then
			printf 'Not a file: %s\n' "$archive" >&2
			status=1
			continue
		fi

		case "$archive" in
		# TAR archives
		*.tar) tar -xf "$archive" ;;
		*.tar.gz | *.tgz | *.taz) tar -xzf "$archive" ;;
		*.tar.bz2 | *.tbz2 | *.tbz) tar -xjf "$archive" ;;
		*.tar.xz | *.txz) tar -xJf "$archive" ;;
		*.tar.zst | *.tzst) tar --zstd -xf "$archive" ;;
		*.tar.lz4) tar --use-compress-program=lz4 -xf "$archive" ;;
		*.tar.lz) tar --lzip -xf "$archive" ;;
		*.tar.lzma) tar --lzma -xf "$archive" ;;
		*.tar.Z | *.tZ) tar -xZf "$archive" ;;
		*.tar.br) tar --use-compress-program=brotli -xf "$archive" ;;

		# Standard archive formats
		*.zip | *.ZIP) unzip "$archive" ;;
		*.7z | *.7Z) 7z x "$archive" ;;
		*.rar | *.RAR) 7z x "$archive" ;;
		*.tar.*) tar -xf "$archive" ;;
		*.ar) ar x "$archive" ;;
		*.cab) 7z x "$archive" ;;
		*.lha | *.lzh) 7z x "$archive" ;;
		*.ace) 7z x "$archive" ;;
		*.alz) 7z x "$archive" ;;
		*.wim) 7z x "$archive" ;;
		*.iso) 7z x "$archive" ;;
		*.deb) dpkg-deb -x "$archive" "${archive%.deb}.extracted" ;;
		*.rpm) mkdir -p "${archive%.rpm}.extracted" &&
			rpm2cpio "$archive" |
				( cd "${archive%.rpm}.extracted" && cpio -idmu ) ;;
		*.apk) 7z x "$archive" -o"${archive%.apk}.extracted" ;;

		# Single-file compression formats
		*.gz) gunzip "$archive" ;;
		*.bz2) bunzip2 "$archive" ;;
		*.xz) unxz "$archive" ;;
		*.lzma) unlzma "$archive" ;;
		*.zst) unzstd "$archive" ;;
		*.lz4) lz4 -d "$archive" ;;
		*.br) brotli -d "$archive" ;;
		*.Z) uncompress "$archive" ;;
		*.lz) lzip -d "$archive" ;;
		*.sz) snzip -d "$archive" ;;
		*.rz) rzip -d "$archive" ;;
		*.lzo) lzop -d "$archive" ;;
		*.uu | *.uue) uudecode "$archive" ;;
		*.xx) xxdecode "$archive" ;;
		*.zoo) 7z x "$archive" ;;
		*.arc) 7z x "$archive" ;;
		*.pak) 7z x "$archive" ;;

		# try windows binary too
		*.exe) 7z x "$archive" ;;

		*)
			printf 'Unsupported archive: %s\n' "$archive" >&2
			status=1
			continue
			;;
		esac

		if [[ $? -ne 0 ]]; then
			printf 'Failed to extract: %s\n' "$archive" >&2
			status=1
		fi
	done

	return "$status"
}


# Search filenames using standard find + grep.
ff() {
	[[ $# -gt 0 ]] || {
		printf 'Usage: ff PATTERN\n' >&2
		return 2
	}
	find . -type f -not -path '*/.git/*' -print |
		grep -i -- "$@"
}

# Search file contents recursively.
ftxt() {
	[[ $# -gt 0 ]] || {
		printf 'Usage: ftext PATTERN [DIRECTORY]\n' >&2
		return 2
	}
	grep -RIn --exclude-dir=.git -- "$1" "${2:-.}"
}

# Disk usage for the current directory or supplied paths.
duh() {
	du -sh -- "${@:-.}"
}

reload() {
	source "$HOME/.bashrc"
}
