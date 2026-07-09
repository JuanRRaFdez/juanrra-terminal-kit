#!/usr/bin/env bash
# =============================================================================
# juanrra-terminal-kit — install.sh
# =============================================================================
# Public installer for juanrra-terminal-kit
# Usage: curl -fsSL https://raw.githubusercontent.com/juanrrafdez/juanrra-terminal-kit/main/install.sh | bash
# =============================================================================

set -e

KIT_NAME="juanrra-terminal-kit"
INSTALL_DIR="$HOME/.config/$KIT_NAME"
BASHRC="$HOME/.bashrc"
INSTALL_SCRIPT_SOURCE="$INSTALL_DIR/install.sh"
MARKER_START="# >>>>> $KIT_NAME >>>>>"
MARKER_END="# <<<<< $KIT_NAME <<<<<"
SOURCE_LINE='[ -f "$HOME/.config/'"$KIT_NAME"'/shell.bash" ] && source "$HOME/.config/'"$KIT_NAME"'/shell.bash"'

# ── colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m' # No Color

info()    { echo -e "${GREEN}[+]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
error()   { echo -e "${RED}[✗]${NC} $1"; }
header()  { echo -e "\n${BOLD}$1${NC}"; }

# ── helpers ──────────────────────────────────────────────────────────────────
is_installed() { command -v "$1" &>/dev/null; }

need() {
  if ! is_installed "$1"; then
    MISSING_DEPS="$MISSING_DEPS  - $1"
    return 1
  fi
  return 0
}

# ── steps ────────────────────────────────────────────────────────────────────
step1_detect_shell() {
  header "Step 1 — Detecting shell"

  if [[ -n "$BASH_VERSION" ]]; then
    info "Running under Bash $BASH_VERSION"
    SHELL_NAME="bash"
  elif [[ -n "$ZSH_VERSION" ]]; then
    warn "Zsh detected — this installer targets Bash. Install will proceed but you may need manual tweaks."
    SHELL_NAME="zsh"
  else
    error "Unsupported shell. This installer requires Bash."
    exit 1
  fi
}

step2_check_deps() {
  header "Step 2 — Checking dependencies"

  MISSING_DEPS=""

  # Core utilities this kit depends on
  need "git"
  need "curl"

  if [[ -n "$MISSING_DEPS" ]]; then
    warn "Missing dependencies:$MISSING_DEPS"
    echo ""
    echo -n "Install missing dependencies now? [y/N] "
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
      if is_installed apt-get; then
        info "Installing via apt-get..."
        sudo apt-get update && sudo apt-get install -y git curl
      elif is_installed dnf; then
        info "Installing via dnf..."
        sudo dnf install -y git curl
      elif is_installed pacman; then
        info "Installing via pacman..."
        sudo pacman -S --noconfirm git curl
      else
        error "No supported package manager found. Please install git and curl manually."
        exit 1
      fi
    else
      info "Skipping dependency installation. The kit may not work fully until dependencies are installed."
    fi
  else
    info "All core dependencies found."
  fi
}

step3_backup() {
  header "Step 3 — Backing up existing config"

  if [[ -d "$INSTALL_DIR" ]]; then
    BACKUP_DIR="$INSTALL_DIR.backup.$(date +%Y%m%d_%H%M%S)"
    info "Backing up existing installation to $BACKUP_DIR"
    cp -r "$INSTALL_DIR" "$BACKUP_DIR"
  fi

  if grep -q "$MARKER_START" "$BASHRC" 2>/dev/null; then
    info "Existing marker found in $BASHRC — will be replaced"
  fi
}

step4_install() {
  header "Step 4 — Installing $KIT_NAME"

  # Create install directory
  mkdir -p "$INSTALL_DIR"

  # Copy this script (so uninstall knows how to clean up)
  cp "$0" "$INSTALL_SCRIPT_SOURCE"

  # Copy shell.bash
  if [[ -f "$INSTALL_DIR/shell.bash" ]]; then
    info "Preserving existing shell.bash (your customizations are safe)"
  elif [[ -f "shell.bash" ]]; then
    cp "shell.bash" "$INSTALL_DIR/shell.bash"
    info "Copied shell.bash"
  else
    # Create a minimal shell.bash if not found (development case)
    cat > "$INSTALL_DIR/shell.bash" <<'EOF'
# =============================================================================
# juanrra-terminal-kit — shell.bash
# =============================================================================
# This file is sourced by your .bashrc
# Add your terminal customisations below
# =============================================================================

# Example: custom prompt
# PS1="\[\e[1;32m\]\u@\h\[\e[0m\] \[\e[1;34m\]\w\[\e[0m\] \$ "

EOF
    info "Created minimal shell.bash"
  fi

  info "Installation directory: $INSTALL_DIR"
}

step5_modify_bashrc() {
  header "Step 5 — Configuring $BASHRC"

  # Remove existing marker block if present
  if grep -q "$MARKER_START" "$BASHRC" 2>/dev/null; then
    info "Removing old installation marker from $BASHRC"
    # Remove from MARKER_START to MARKER_END (inclusive), multi-line
    sed -i "/$MARKER_START/,/$MARKER_END/d" "$BASHRC"
  fi

  # Append new marker block
  {
    echo ""
    echo "$MARKER_START"
    echo "$SOURCE_LINE"
    echo "$MARKER_END"
  } >> "$BASHRC"

  info "Added installation marker to $BASHRC"
  echo ""
  info "The following line was added to your $BASHRC:"
  echo ""
  echo "  $SOURCE_LINE"
  echo ""
}

step6_verify() {
  header "Step 6 — Verifying installation"

  if [[ -f "$INSTALL_DIR/shell.bash" ]] && [[ -f "$INSTALL_DIR/install.sh" ]]; then
    info "Installation files present"
  else
    error "Some installation files are missing!"
    exit 1
  fi

  if grep -q "$MARKER_START" "$BASHRC" && grep -q "$SOURCE_LINE" "$BASHRC"; then
    info "$BASHRC configured correctly"
  else
    error "$BASHRC may not be configured correctly — please review"
    exit 1
  fi

  echo ""
  info "✅ $KIT_NAME installed successfully!"
  echo ""
  echo "Next steps:"
  echo "  1. Restart your terminal or run: source $BASHRC"
  echo "  2. Edit $INSTALL_DIR/shell.bash to customise your setup"
  echo "  3. To uninstall: bash $INSTALL_DIR/uninstall.sh"
  echo ""
}

# ── main ─────────────────────────────────────────────────────────────────────
main() {
  echo ""
  echo -e "${BOLD}╔══════════════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}║         $KIT_NAME — Installer${NC}                         ║"
  echo -e "${BOLD}╚══════════════════════════════════════════════════════╝${NC}"
  echo ""

  # If already installed, offer to skip steps
  if [[ -d "$INSTALL_DIR" ]] && [[ -f "$INSTALL_DIR/shell.bash" ]]; then
    echo -n "$KIT_NAME is already installed. Re-install? [y/N] "
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
      info "Aborting."
      exit 0
    fi
  fi

  step1_detect_shell
  step2_check_deps
  step3_backup
  step4_install
  step5_modify_bashrc
  step6_verify
}

main "$@"
