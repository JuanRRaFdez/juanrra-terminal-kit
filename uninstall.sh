#!/usr/bin/env bash
# =============================================================================
# juanrra-terminal-kit — uninstall.sh
# =============================================================================
# Removes juanrra-terminal-kit from the system
# =============================================================================

set -e

KIT_NAME="juanrra-terminal-kit"
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

header "Uninstalling $KIT_NAME"

# ── confirm ──────────────────────────────────────────────────────────────────
echo -n "Remove installation directory ($INSTALL_DIR)? [y/N] "
read -r remove_dir
echo -n "Clean up $BASHRC markers? [y/N] "
read -r clean_bashrc

# ── clean bashrc ─────────────────────────────────────────────────────────────
if [[ "$clean_bashrc" =~ ^[Yy]$ ]]; then
  if grep -q "$MARKER_START" "$BASHRC" 2>/dev/null; then
    info "Removing marker block from $BASHRC"
    sed -i "/$MARKER_START/,/$MARKER_END/d" "$BASHRC"
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
