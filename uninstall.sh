#!/usr/bin/env bash
# =============================================================================
# juanrra-terminal-kit — uninstall.sh
# =============================================================================
# Removes juanrra-terminal-kit from the system.
#
# Usage:
#   bash ~/.config/juanrra-terminal-kit/uninstall.sh
#
# Environment overrides (CI / testing):
#   JTK_ASSUME_NO=1   — non-destructive; exit without removing anything
#   JTK_ASSUME_YES=1  — unattended; remove both marker block and install dir
# =============================================================================

set -euo pipefail

KIT_NAME="juanrra-terminal-kit"

# ── HOME safety guard — validate before expanding any paths ──────────────────
_home_guard_error() {
  echo -e "\033[0;31m[✗]\033[0m $1" >&2
  exit 1
}

_validate_and_canonicalize_home() {
  if [[ -z "${HOME:-}" ]]; then
    _home_guard_error "HOME is not set — refusing to uninstall."
  fi
  if [[ "$HOME" == *$'\n'* ]]; then
    _home_guard_error "HOME contains a newline — refusing to uninstall."
  fi
  if [[ "$HOME" == *'"'* ]]; then
    _home_guard_error "HOME contains a double quote — refusing to uninstall."
  fi
  if [[ "${HOME:0:1}" != "/" ]]; then
    _home_guard_error "HOME is not an absolute path — refusing to uninstall."
  fi
  if [[ "$HOME" == "/" ]]; then
    _home_guard_error "HOME is \"/\" — refusing to uninstall from the filesystem root."
  fi
  if [[ "$HOME" =~ (^|/)\.\.(/|$) ]]; then
    _home_guard_error "HOME contains traversal ('..') — refusing to uninstall."
  fi

  if [[ -d "$HOME" ]]; then
    local canonical_home
    if ! canonical_home=$(cd "$HOME" && pwd -P); then
      _home_guard_error "Unable to canonicalize HOME — refusing to uninstall."
    fi
    if [[ -z "$canonical_home" ]]; then
      _home_guard_error "Canonical HOME is empty — refusing to uninstall."
    fi
    if [[ "$canonical_home" == *$'\n'* ]]; then
      _home_guard_error "Canonical HOME contains a newline — refusing to uninstall."
    fi
    if [[ "$canonical_home" == *'"'* ]]; then
      _home_guard_error "Canonical HOME contains a double quote — refusing to uninstall."
    fi
    if [[ "$canonical_home" == "/" ]]; then
      _home_guard_error "Canonical HOME resolves to \"/\" — refusing to uninstall from the filesystem root."
    fi
    HOME="$canonical_home"
  fi
  export HOME
}

_validate_and_canonicalize_home

INSTALL_DIR="$HOME/.config/$KIT_NAME"
BASHRC="$HOME/.bashrc"
MARKER_START="# >>>>> $KIT_NAME >>>>>"
MARKER_END="# <<<<< $KIT_NAME <<<<<"
SOURCE_LINE='[ -f "$HOME/.config/'"$KIT_NAME"'/shell.bash" ] && source "$HOME/.config/'"$KIT_NAME"'/shell.bash"'

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${GREEN}[+]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
error()   { echo -e "${RED}[✗]${NC} $1"; }
header()  { echo -e "\n${BOLD}$1${NC}"; }

# ── safe marker block removal ─────────────────────────────────────────────────
# Removes only complete start+end marker blocks.
# Preserves orphan start blocks and all other content.
_remove_bashrc_markers() {
  local file="$1"
  local tmpfile
  tmpfile=$(mktemp)
  awk \
    -v start="$MARKER_START" \
    -v end="$MARKER_END" '
  $0 == start {
    if (buffering == 1) {
      print orphan_start
      for (i = 1; i <= buf_idx; i++) print buf[i]
      orphan_start = ""
    }
    orphan_start = $0
    buffering = 1
    buf_idx = 0
    next
  }
  $0 == end {
    if (buffering == 1) {
      buffering = 0
      buf_idx = 0
      orphan_start = ""
      next
    }
    print
    next
  }
  buffering == 1 {
    buf[++buf_idx] = $0
    next
  }
  buffering == 0 {
    print
  }
  END {
    if (buffering == 1) {
      print orphan_start
      for (i = 1; i <= buf_idx; i++) print buf[i]
    }
  }
  ' "$file" > "$tmpfile" && mv "$tmpfile" "$file"
}

header "Uninstalling $KIT_NAME"

# Guard: INSTALL_DIR must equal exactly $HOME/.config/$KIT_NAME.
EXPECTED_DIR="${HOME}/.config/${KIT_NAME}"
if [[ "$INSTALL_DIR" != "$EXPECTED_DIR" ]]; then
  error "INSTALL_DIR ($INSTALL_DIR) is not exactly ${EXPECTED_DIR} — refusing to uninstall."
  error "This may indicate an abnormal installation or a security policy violation."
  exit 1
fi

# ── confirm ──────────────────────────────────────────────────────────────────
# JTK_ASSUME_NO=1 means non-destructive only — skip everything.
# JTK_ASSUME_YES=1 means unattended full uninstall.
if [[ "${JTK_ASSUME_NO:-}" == "1" ]]; then
  info "JTK_ASSUME_NO=1 — exiting without removing anything."
  info "Run interactively or set JTK_ASSUME_YES=1 to uninstall unattended."
  exit 0
fi

if [[ "${JTK_ASSUME_YES:-}" == "1" ]]; then
  remove_dir="y"
  clean_bashrc="y"
  info "Running unattended (JTK_ASSUME_YES=1)"
else
  echo -n "Remove installation directory ($INSTALL_DIR)? [y/N] "
  read -r remove_dir
  echo -n "Clean up $BASHRC markers? [y/N] "
  read -r clean_bashrc
fi

# ── clean bashrc ─────────────────────────────────────────────────────────────
_backup_bashrc() {
  local src="$1"
  local dest="${src}.backup.$(date +%Y%m%d_%H%M%S).$$"
  cp "$src" "$dest"
  info "Backed up $src to $dest"
}

if [[ "$clean_bashrc" =~ ^[Yy]$ ]]; then
  if grep -Fq "$MARKER_START" "$BASHRC" 2>/dev/null; then
    _backup_bashrc "$BASHRC"
    info "Removing marker block from $BASHRC"
    _remove_bashrc_markers "$BASHRC"
    info "$BASHRC cleaned"
  else
    warn "No marker found in $BASHRC — nothing to clean"
  fi
else
  warn "Skipping $BASHRC cleanup — please remove the marker block manually:"
  echo ""
  echo "  $MARKER_START"
  echo "  $SOURCE_LINE"
  echo "  $MARKER_END"
  echo ""
fi

# ── remove install dir ───────────────────────────────────────────────────────
if [[ "$remove_dir" =~ ^[Yy]$ ]]; then
  if [[ -d "$INSTALL_DIR" ]]; then
    info "Removing $INSTALL_DIR"
    rm -rf "$INSTALL_DIR"
    info "Done"
  else
    warn "Installation directory not found: $INSTALL_DIR"
  fi
else
  warn "Keeping $INSTALL_DIR"
fi

echo ""
info "✅ Uninstall complete"
echo ""
info "If you had custom code in $BASHRC inside the marker block,"
info "you may need to restore it from a backup."
echo ""
