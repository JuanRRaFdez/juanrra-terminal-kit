# =============================================================================
# juanrra-terminal-kit — modules/core.bash
# =============================================================================
# Core aliases and utility functions for the terminal kit.
# No external dependencies — this module is self-contained and always safe
# to source. Catalog has no dependencies listed for this module.
# =============================================================================

# ── colours ──────────────────────────────────────────────────────────────────
# You can override these in shell.bash.local
: "${COLOUR_USER:=\[\e[1;32m\]}"
: "${COLOUR_HOST:=\[\e[1;36m\]}"
: "${COLOUR_PATH:=\[\e[1;34m\]}"
: "${COLOUR_GIT:=\[\e[1;35m\]}"
: "${COLOUR_RESET:=\[\e[0m\]}"
: "${COLOUR_OK:=\[\e[0;32m\]}"
: "${COLOUR_WARN:=\[\e[1;33m\]}"
: "${COLOUR_ERR:=\[\e[0;31m\]}"

# ── prompt ───────────────────────────────────────────────────────────────────
# Show git branch in prompt when inside a git repo
git_branch() {
  local branch
  branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  if [[ -n "$branch" ]]; then
    echo " ${COLOUR_GIT}(${branch})${COLOUR_RESET}"
  fi
}

# ── window title ──────────────────────────────────────────────────────────────
# Set terminal title to user@host:path
case "$TERM" in
  xterm*|rxvt*|screen*)
    PS1="\033]0;\u@\h: \w\007"
    ;;
esac

# ── safety aliases ────────────────────────────────────────────────────────────
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# ── common shortcuts ─────────────────────────────────────────────────────────
alias ll='ls -la'
alias la='ls -A'
alias l='ls -CF'

# ── git aliases ───────────────────────────────────────────────────────────────
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline -10'
alias gd='git diff'

# ── functions ───────────────────────────────────────────────────────────────
# Create a directory and cd into it
mkcd() { mkdir -p "$1" && cd "$1"; }

# Extract any archive
extract() {
  if [[ -f "$1" ]]; then
    case "$1" in
      *.tar.bz2) tar xjf "$1" ;;
      *.tar.gz)  tar xzf "$1" ;;
      *.bz2)     bunzip2 "$1" ;;
      *.gz)      gunzip "$1" ;;
      *.tar)     tar xf "$1" ;;
      *.tbz2)    tar xjf "$1" ;;
      *.tgz)     tar xzf "$1" ;;
      *.zip)     unzip "$1" ;;
      *.Z)       uncompress "$1" ;;
      *)         echo "'$1' cannot be extracted via extract()" ;;
    esac
  else
    echo "'$1' is not a valid file"
  fi
}
