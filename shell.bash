# =============================================================================
# juanrra-terminal-kit — shell.bash (repository reference)
# =============================================================================
# This is the canonical shell.bash kept in the repository.
#
# IMPORTANT: this file is NOT the installed loader. install.sh does not copy or
# modify this file. Instead, install.sh generates a new loader at:
#   ~/.config/juanrra-terminal-kit/shell.bash
# that sources only the modules the user selected during installation.
#
# To develop/test modules locally without running the installer:
#   source shell.bash
# (this file sources no modules by default — it is a reference, not a loader)
#
# For local overrides during development, create shell.bash.local in the repo root.
# For overrides in a live installation, edit:
#   ~/.config/juanrra-terminal-kit/shell.bash.local
# =============================================================================

# ── colours (reference defaults) ──────────────────────────────────────────────
# These values are placeholders. The generated installed loader uses the actual
# module content sourced at install time.
: "${COLOUR_USER:=\[\e[1;32m\]}"
: "${COLOUR_HOST:=\[\e[1;36m\]}"
: "${COLOUR_PATH:=\[\e[1;34m\]}"
: "${COLOUR_GIT:=\[\e[1;35m\]}"
: "${COLOUR_RESET:=\[\e[0m\]}"
: "${COLOUR_OK:=\[\e[0;32m\]}"
: "${COLOUR_WARN:=\[\e[1;33m\]}"
: "${COLOUR_ERR:=\[\e[0;31m\]}"

# ── local overrides (development only) ────────────────────────────────────────
# Not tracked in git; use only for local development experiments.
if [[ -f "$(dirname "${BASH_SOURCE[0]}")/shell.bash.local" ]]; then
  source "$(dirname "${BASH_SOURCE[0]}")/shell.bash.local"
fi
