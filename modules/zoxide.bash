# =============================================================================
# juanrra-terminal-kit — modules/zoxide.bash
# =============================================================================
# Zoxide smart directory jumping.
# REQUIRED: zoxide (the module guard exits silently without it).
# Command dependency (zoxide) is a tool the installer can offer to install.
# The init script provides the 'z' command; no manual cd alias needed.
# =============================================================================

# Guard: only run if zoxide is available
if ! command -v zoxide &>/dev/null; then
  return 0 2>/dev/null || exit 0
fi

# ── zoxide init ─────────────────────────────────────────────────────────────
eval "$(zoxide init bash)"
