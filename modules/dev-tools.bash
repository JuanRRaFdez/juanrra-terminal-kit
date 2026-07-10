# =============================================================================
# juanrra-terminal-kit — modules/dev-tools.bash
# =============================================================================
# Development tool paths: Homebrew, pnpm, npm global, bun.
# No hard external dependencies — each tool is guarded individually and the
# module degrades gracefully. No catalog dependencies listed.
# =============================================================================

# ── Homebrew paths ───────────────────────────────────────────────────────────
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
elif [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

# ── pnpm ─────────────────────────────────────────────────────────────────────
if command -v pnpm &>/dev/null; then
  export PNPM_HOME="${HOME}/.local/share/pnpm"
  if [[ -d "$PNPM_HOME" ]]; then
    export PATH="$PNPM_HOME:$PATH"
  fi
fi

# ── npm global packages ──────────────────────────────────────────────────────
if command -v npm &>/dev/null; then
  NPM_GLOBAL_PATH=$(npm config get prefix 2>/dev/null)/lib/node_modules
  if [[ -d "$NPM_GLOBAL_PATH" ]]; then
    export PATH="$NPM_GLOBAL_PATH/bin:$PATH"
  fi
fi

# ── bun ──────────────────────────────────────────────────────────────────────
if command -v bun &>/dev/null; then
  export BUN_INSTALL="$HOME/.bun"
  if [[ -d "$BUN_INSTALL/bin" ]]; then
    export PATH="$BUN_INSTALL/bin:$PATH"
  fi
fi
