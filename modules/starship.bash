# =============================================================================
# juanrra-terminal-kit — modules/starship.bash
# =============================================================================
# Starship cross-shell prompt configuration.
# REQUIRED: starship (the module guard exits silently without it).
# Command dependency (starship) is a tool the installer can offer to install.
# =============================================================================

# Guard: only run if starship is available
if ! command -v starship &>/dev/null; then
  return 0 2>/dev/null || exit 0
fi

# ── starship init ─────────────────────────────────────────────────────────────
eval "$(starship init bash)"
