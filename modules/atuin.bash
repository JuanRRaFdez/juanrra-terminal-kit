# =============================================================================
# juanrra-terminal-kit — modules/atuin.bash
# =============================================================================
# Atuin shell history with sync and search.
# REQUIRED: atuin.
# RECOMMENDED: bash-preexec (needed for Atuin to record Bash commands correctly;
#   Atuin may function partially without it on newer versions, but full history
#   recording in Bash requires it).
# Command dependencies (atuin, bash-preexec) are checked by the installer,
#   which can offer to install missing tools so the full experience is available.
# =============================================================================

# Guard: only run if atuin is available
if ! command -v atuin &>/dev/null; then
  return 0 2>/dev/null || exit 0
fi

# ── bash-preexec ─────────────────────────────────────────────────────────────
# Source bash-preexec if found; Atuin needs it for Bash history hooks.
# Graceful: no error if not present — Atuin still initialises but history
# recording in Bash may be incomplete without it.
_bash_preexec_sources=(
  "${HOME}/.local/share/atuin/bash-preexec.sh"
  /usr/share/bash-preexec/bash-preexec.sh
  /opt/homebrew/share/bash-preexec/bash-preexec.sh
)

for _src in "${_bash_preexec_sources[@]}"; do
  if [[ -f "$_src" ]]; then
    source "$_src"
    break
  fi
done
unset _src _bash_preexec_sources

# ── atuin init ───────────────────────────────────────────────────────────────
if [[ -n "$BASH_VERSION" ]]; then
  eval "$(atuin init bash)"
fi

# ── atuin aliases ─────────────────────────────────────────────────────────────
alias th='atuin history'
alias ths='atuin history --search'
alias ths-c='atuin history --search --current-line'
