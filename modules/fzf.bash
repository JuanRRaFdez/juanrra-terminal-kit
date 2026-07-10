# =============================================================================
# juanrra-terminal-kit — modules/fzf.bash
# =============================================================================
# FZF file and directory navigation.
# REQUIRED: fzf (the core tool — without it this module does nothing).
# RECOMMENDED / ENHANCED: fd, bat, eza (these improve the experience but
#   the module degrades gracefully when they are absent).
# Command dependencies (fzf, fd, bat, eza) are checked by the installer,
#   which can offer to install missing tools so the full experience is available.
# =============================================================================

# Guard: only run if fzf is available
if ! command -v fzf &>/dev/null; then
  return 0 2>/dev/null || exit 0
fi

# ── fd availability check ────────────────────────────────────────────────────
_have_fd=false
if command -v fd &>/dev/null; then
  _have_fd=true
  export FD_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
fi

# ── fzf colour scheme ─────────────────────────────────────────────────────────
if $_have_fd; then
  export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
fi

export FZF_DEFAULT_OPTS='
  --color=bg+:#3b4261,bg:#1e1e2e,spinner:#f5c2e7,hl:#cba6f7
  --color=fg:#cdd6f4,header:#cba6f7,info:#f5c2e7,pointer:#cba6f7
  --color=marker:#f5c2e7,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f5c2e7
'

# ── bat colour scheme ─────────────────────────────────────────────────────────
if command -v bat &>/dev/null; then
  export BAT_THEME="OneDark"
fi

# ── eza availability check ───────────────────────────────────────────────────
_have_eza=false
if command -v eza &>/dev/null; then
  _have_eza=true
fi

# ── eza aliases (modern ls) or standard ls fallbacks ─────────────────────────
if $_have_eza; then
  alias ls='eza --icons'
  alias ll='eza -la --icons'
  alias la='eza -laa --icons'
  alias lt='eza --tree --level=2'
  alias l='eza -CF --icons'
else
  alias ls='ls --color=auto'
  alias ll='ls -la --color=auto'
  alias la='ls -la --color=auto'
fi

# ── fzf navigation helpers ────────────────────────────────────────────────────
# fe [query] — fuzzy open file with nvim (single selection)
fe() {
  if ! command -v nvim &>/dev/null; then
    echo "nvim not available"
    return 1
  fi

  local file
  file=$(fzf --query="$1")
  if [[ -n "$file" ]]; then
    nvim "$file"
  fi
}

# fcd [query] — fuzzy cd to directory
# Uses fd --type d when available for accurate directory filtering;
# falls back to a portable find pipeline when fd is absent.
fcd() {
  local dir
  if $_have_fd; then
    dir=$(fd --type d --hidden --follow --exclude .git | fzf --query="$1")
  else
    dir=$(find . -type d -not -path '*/.git/*' 2>/dev/null | fzf --query="$1")
  fi
  if [[ -n "$dir" && -d "$dir" ]]; then
    cd "$dir" || return
  fi
}


