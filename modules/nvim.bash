# =============================================================================
# juanrra-terminal-kit — modules/nvim.bash
# =============================================================================
# Neovim editor environment and Ctrl-O widget for fuzzy file open.
# REQUIRED: nvim.
# REQUIRED for Ctrl-O widget: fzf, fd.
# ENHANCED (optional): bat (used for file preview when available).
# Command dependencies (nvim, fzf, fd, bat) are checked by the installer,
#   which can offer to install missing tools so the fuzzy widget is available.
# =============================================================================

# Guard: only run if nvim is available
if ! command -v nvim &>/dev/null; then
  return 0 2>/dev/null || exit 0
fi

# ── editor environment ───────────────────────────────────────────────────────
export EDITOR='nvim'
export VISUAL='nvim'

# ── nvim aliases ────────────────────────────────────────────────────────────
alias vi='nvim'
alias vim='nvim'

# ── Ctrl-O widget: fuzzy file open via fzf → nvim ──────────────────────────
# Bound to Ctrl-O in interactive Bash. fzf and fd are REQUIRED for this widget.
# bat is ENHANCED only (file preview); without it the widget uses bare fzf.
# When fzf or fd is absent, the widget returns silently — nvim is still usable
# as $EDITOR without the fuzzy picker.
_fzf_nvim_widget() {
  if ! command -v fzf &>/dev/null || ! command -v fd &>/dev/null; then
    # Fuzzy dependencies not available; fall back silently
    return 0
  fi

  local file
  if command -v bat &>/dev/null; then
    file=$(fzf --preview 'bat --style=numbers --color=always {}' 2>/dev/null)
  else
    file=$(fzf 2>/dev/null)
  fi

  if [[ -n "$file" && -e "$file" ]]; then
    nvim "$file"
  fi
}

# Bind Ctrl-O only in interactive Bash; suppress errors if bind -x fails
if [[ -n "$BASH_VERSION" && "$-" == *i* ]]; then
  bind -x '"\C-o": _fzf_nvim_widget' 2>/dev/null || true
fi
