#!/usr/bin/env bash
# =============================================================================
# juanrra-terminal-kit — install.sh
# =============================================================================
# Public installer for juanrra-terminal-kit
# Usage (local clone):  bash install.sh
# Usage (remote):      bash -c "$(curl -fsSL https://raw.githubusercontent.com/JuanRRaFdez/juanrra-terminal-kit/main/install.sh)"
#
# Environment overrides (for testing / CI):
#   JTK_MODULES   — comma-separated module IDs to select (bypasses interactive)
#   JTK_ASSUME_NO — set to 1 to answer no to all prompts
# =============================================================================

set -euo pipefail

KIT_NAME="juanrra-terminal-kit"

# ── HOME safety guard — validate before expanding any paths ─────────────────────
_home_guard_error() {
  echo -e "\033[0;31m[✗]\033[0m $1" >&2
  exit 1
}

_validate_and_canonicalize_home() {
  if [[ -z "${HOME:-}" ]]; then
    _home_guard_error "HOME is not set — refusing to run."
  fi
  if [[ "$HOME" == *$'\n'* ]]; then
    _home_guard_error "HOME contains a newline — refusing to run."
  fi
  if [[ "$HOME" == *'"'* ]]; then
    _home_guard_error "HOME contains a double quote — refusing to run."
  fi
  if [[ "${HOME:0:1}" != "/" ]]; then
    _home_guard_error "HOME is not an absolute path — refusing to run."
  fi
  if [[ "$HOME" == "/" ]]; then
    _home_guard_error "HOME is \"/\" — refusing to run from the filesystem root."
  fi
  if [[ "$HOME" =~ (^|/)\.\.(/|$) ]]; then
    _home_guard_error "HOME contains traversal ('..') — refusing to run."
  fi

  if [[ -d "$HOME" ]]; then
    local canonical_home
    if ! canonical_home=$(cd "$HOME" && pwd -P); then
      _home_guard_error "Unable to canonicalize HOME — refusing to run."
    fi
    if [[ -z "$canonical_home" ]]; then
      _home_guard_error "Canonical HOME is empty — refusing to run."
    fi
    if [[ "$canonical_home" == *$'\n'* ]]; then
      _home_guard_error "Canonical HOME contains a newline — refusing to run."
    fi
    if [[ "$canonical_home" == *'"'* ]]; then
      _home_guard_error "Canonical HOME contains a double quote — refusing to run."
    fi
    if [[ "$canonical_home" == "/" ]]; then
      _home_guard_error "Canonical HOME resolves to \"/\" — refusing to run from the filesystem root."
    fi
    HOME="$canonical_home"
  fi
  export HOME
}

_validate_and_canonicalize_home

INSTALL_DIR="${HOME}/.config/${KIT_NAME}"
BASHRC="${HOME}/.bashrc"
MARKER_START="# >>>>> ${KIT_NAME} >>>>>"
MARKER_END="# <<<<< ${KIT_NAME} <<<<<"
SOURCE_LINE='[ -f "${HOME}/.config/'"${KIT_NAME}"'/shell.bash" ] && source "${HOME}/.config/'"${KIT_NAME}"'/shell.bash"'
GITHUB_RAW="https://raw.githubusercontent.com/JuanRRaFdez/juanrra-terminal-kit/main"

# ── colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${GREEN}[+]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
error()   { echo -e "${RED}[✗]${NC} $1"; }
header()  { echo -e "\n${BOLD}$1${NC}"; }

# ── helpers ──────────────────────────────────────────────────────────────────
is_installed() { command -v "$1" &>/dev/null; }

has_fzf() { is_installed fzf; }

# Detect whether we are running from a local clone or via curl|bash
_is_local_clone() {
  # If stdin is a pipe (script piped via curl|bash), BASH_SOURCE[0] is /dev/stdin
  # and we cannot use local files — treat as remote.
  local src="${BASH_SOURCE[0]:-}"
  if [[ -z "$src" || "$src" == "/dev/stdin" || "$src" == "/dev/fd/"* || ! -f "$src" ]]; then
    return 1
  fi
  # If catalog/modules.conf exists relative to the script dir, we're in a clone
  if [[ -f "${SCRIPT_DIR}/catalog/modules.conf" ]]; then
    return 0
  fi
  return 1
}

# Fetch a remote file; exits on failure
_fetch_remote() {
  local url="$1"
  local dest="$2"
  if ! curl -fsSL "$url" -o "$dest"; then
    error "Failed to fetch $url"
    exit 1
  fi
}

# ── catalog parsing ──────────────────────────────────────────────────────────
# Reads catalog from $1; populates global arrays:
#   MODULE_IDS[@]   — id field
#   MODULE_TITLES[@] — title field
#   MODULE_DESCS[@]  — description field
#   MODULE_DEPS[@]   — dependencies field
#   MODULE_FILES[@]  — file field
declare -a MODULE_IDS MODULE_TITLES MODULE_DESCS MODULE_DEPS MODULE_FILES

is_safe_module_file() {
  local file="$1"
  [[ "$file" =~ ^modules/[A-Za-z0-9._-]+\.bash$ ]] && [[ "$file" != *..* ]]
}

parse_catalog() {
  local catalog="$1"
  MODULE_IDS=()
  MODULE_TITLES=()
  MODULE_DESCS=()
  MODULE_DEPS=()
  MODULE_FILES=()

  while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip blank lines and comment lines
    [[ -z "$line" || "$line" == \#* ]] && continue

    # Strip leading/trailing whitespace
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"

    IFS='|' read -r id title desc deps file <<< "$line"

    # Skip header line (id|title|...)
    [[ "$id" == "id" ]] && continue

    # Validate required fields
    if [[ -z "$id" || -z "$file" ]]; then
      warn "Skipping malformed catalog line: $line"
      continue
    fi

    if ! is_safe_module_file "$file"; then
      error "Unsafe module file in catalog for id '$id': $file"
      return 1
    fi

    MODULE_IDS+=("$id")
    MODULE_TITLES+=("$title")
    MODULE_DESCS+=("$desc")
    MODULE_DEPS+=("${deps:-}")
    MODULE_FILES+=("$file")
  done < "$catalog"
}

# Get module index by id; returns 1 if not found
module_index() {
  local id="$1"
  for i in "${!MODULE_IDS[@]}"; do
    if [[ "${MODULE_IDS[$i]}" == "$id" ]]; then
      echo "$i"
      return 0
    fi
  done
  return 1
}

# Validate that all ids in a comma-separated list exist
validate_module_ids() {
  local ids="$1"
  local IFS=,
  for id in $ids; do
    id="${id#"${id%%[![:space:]]*}"}"
    id="${id%"${id##*[![:space:]]}"}"
    if ! module_index "$id" &>/dev/null; then
      error "Unknown module: $id"
      return 1
    fi
  done
  return 0
}

# ── module selection ─────────────────────────────────────────────────────────
# Shows module list and lets user pick; returns comma-separated ids in SELECTED_IDS
SELECTED_IDS=""

# Normalize SELECTED_IDS: trim whitespace from each ID, remove empties and duplicates.
_normalize_selected_ids() {
  local old_ifs="$IFS"
  local normalized=""
  local seen=""
  IFS=','
  for id in $SELECTED_IDS; do
    id="${id#"${id%%[![:space:]]*}"}"
    id="${id%"${id##*[![:space:]]}"}"
    [[ -z "$id" ]] && continue
    case ",$seen," in
      *",$id,"*) continue ;;
      *) seen="${seen}${id}," ;;
    esac
    if [[ -z "$normalized" ]]; then
      normalized="$id"
    else
      normalized="${normalized},${id}"
    fi
  done
  IFS="$old_ifs"
  SELECTED_IDS="$normalized"
}

select_modules_fzf() {
  header "Step 2 — Select modules"

  # Build preview: id | title | description
  local preview_lines=()
  for i in "${!MODULE_IDS[@]}"; do
    preview_lines+=("${MODULE_IDS[$i]} | ${MODULE_TITLES[$i]} | ${MODULE_DESCS[$i]}")
  done

  # Write to temp file for fzf --preview
  local tmpfile
  tmpfile=$(mktemp)
  printf '%s\n' "${preview_lines[@]}" > "$tmpfile"
  trap "rm -f '$tmpfile'" RETURN

  local picks
  picks=$(fzf \
    --multi \
    --preview='echo {}' \
    --preview-window='right:40%' \
    --prompt="Select modules (Space=select, Enter=confirm): " \
    --header="↑↓ navigate · Space select · Enter confirm" \
    < "$tmpfile" 2>/dev/null) || true

  [[ -z "$picks" ]] && return 1

  # Extract first field (id) from each picked line
  local -a selected=()
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    local id="${line%% |*}"  # take first field before '|'
    id="${id%"${id##*[![:space:]]}"}"
    selected+=("$id")
  done <<< "$picks"

  # Join with comma
  SELECTED_IDS=$(IFS=, ; echo "${selected[*]}")
  _normalize_selected_ids
}

select_modules_numeric() {
  header "Step 2 — Select modules"

  echo "Available modules:"
  echo ""
  for i in "${!MODULE_IDS[@]}"; do
    printf "  [%d] %-12s %s\n" "$((i+1))" "${MODULE_IDS[$i]}" "${MODULE_TITLES[$i]}"
    [[ -n "${MODULE_DESCS[$i]}" ]] && echo "           ${MODULE_DESCS[$i]}"
    echo ""
  done

  # Guard: in non-interactive context (stdin is not a TTY), fail instead of looping
  if ! [[ -t 0 ]]; then
    error "stdin is not a TTY — cannot run interactive numeric selector."
    error "Use JTK_MODULES=core,fzf (for example) for non-interactive installs."
    exit 1
  fi

  local valid_input=false
  while [[ "$valid_input" == "false" ]]; do
    echo "Enter numbers (comma-separated), e.g. 1,2,4: "
    echo -n "> "
    read -r picks

    # Reject empty input
    if [[ -z "${picks// }" ]]; then
      warn "Empty input — please enter at least one number."
      continue
    fi

    # Convert numbers to ids; validate each is a positive integer in range
    local -a selected=()
    local -a invalid=()
    IFS=, read -ra nums <<< "$picks"
    for n in "${nums[@]}"; do
      n="${n#"${n%%[![:space:]]*}"}"
      n="${n%"${n##*[![:space:]]}"}"
      # Require positive decimal integer (no leading zeros, no sign)
      if [[ ! "$n" =~ ^[1-9][0-9]*$ ]]; then
        invalid+=("$n")
        continue
      fi
      # Use 10#$n to force base-10 (avoids octal interpretation of 08, 09)
      local idx=$((10#$n - 1))
      if [[ "$idx" -ge 0 && "$idx" -lt "${#MODULE_IDS[@]}" ]]; then
        selected+=("${MODULE_IDS[$idx]}")
      else
        invalid+=("$n")
      fi
    done

    if [[ ${#invalid[@]} -gt 0 ]]; then
      warn "Invalid or out-of-range: ${invalid[*]} — please try again."
      continue
    fi

    if [[ ${#selected[@]} -eq 0 ]]; then
      warn "No valid modules selected — please try again."
      continue
    fi

    valid_input=true
    SELECTED_IDS=$(IFS=, ; echo "${selected[*]}")
  _normalize_selected_ids
  done
}

select_modules() {
  # JTK_ASSUME_NO with no JTK_MODULES means we cannot run interactively —
  # fail fast before attempting any interactive selector (even fzf).
  if [[ "${JTK_ASSUME_NO:-}" == "1" && -z "${JTK_MODULES:-}" ]]; then
    error "JTK_ASSUME_NO=1 but JTK_MODULES is not set."
    error "Cannot run interactive module selector in non-interactive context."
    error "Set JTK_MODULES=core,fzf (for example) or run interactively."
    exit 1
  fi

  # Respect JTK_MODULES override for testing / CI
  if [[ -n "${JTK_MODULES:-}" ]]; then
    if ! validate_module_ids "$JTK_MODULES"; then
      error "JTK_MODULES contains invalid module ids"
      exit 1
    fi
    info "Using JTK_MODULES=$JTK_MODULES"
    SELECTED_IDS="$JTK_MODULES"
    _normalize_selected_ids
    return 0
  fi

  if has_fzf; then
    select_modules_fzf || true
  else
    select_modules_numeric
  fi

  if [[ -z "$SELECTED_IDS" ]]; then
    error "No modules selected — nothing to install."
    exit 1
  fi

  info "Selected modules: $SELECTED_IDS"
}

# ── dependency checking ──────────────────────────────────────────────────────
# For each selected module, collect all dependency tools and check what's missing.
# Ask user to confirm installation of missing tools.
check_dependencies() {
  header "Step 3 — Checking module dependencies"

  # Collect all unique tool deps from selected modules
  # Module IDs are comma-separated; deps within each module are space-separated.
  local all_deps=()
  local old_ifs="$IFS"
  IFS=','
  for id in $SELECTED_IDS; do
    id="${id#"${id%%[![:space:]]*}"}"
    id="${id%"${id##*[![:space:]]}"}"
    local idx
    idx=$(module_index "$id")
    local deps="${MODULE_DEPS[$idx]:-}"
    IFS=' '
    for dep in $deps; do
      dep="${dep#"${dep%%[![:space:]]*}"}"
      dep="${dep%"${dep##*[![:space:]]}"}"
      [[ -n "$dep" ]] && all_deps+=("$dep")
    done
  done
  IFS="$old_ifs"

  # Deduplicate — use a plain string to track seen deps (associative array
  # with -u strict mode causes unbound-variable on empty key access)
  local seen=""
  local -a missing=()
  for dep in "${all_deps[@]}"; do
    [[ -z "$dep" ]] && continue
    case ",$seen," in
      *",$dep,"*) continue ;;
      *) seen="${seen}${dep}," ;;
    esac
    if ! is_installed "$dep"; then
      missing+=("$dep")
    fi
  done

  if [[ ${#missing[@]} -eq 0 ]]; then
    info "All module dependencies are satisfied."
    return 0
  fi

  echo ""
  warn "Missing dependencies: ${missing[*]}"
  echo ""

  if [[ "${JTK_ASSUME_NO:-}" == "1" ]]; then
    warn "Skipping dependency installation (JTK_ASSUME_NO=1)"
    echo ""
    warn "Modules that depend on missing tools will degrade gracefully."
    return 0
  fi

  echo -n "Install missing dependencies now? [y/N] "
  read -r response
  if [[ ! "$response" =~ ^[Yy]$ ]]; then
    warn "Skipping dependency installation."
    echo ""
    warn "Modules that depend on missing tools will degrade gracefully."
    return 0
  fi

  # Install missing deps
  if ! install_deps "${missing[@]}"; then
    echo ""
    warn "Some dependencies could not be installed."
    warn "Modules that depend on these tools will degrade gracefully."
  fi
}

install_deps() {
  local deps=("$@")
  if is_installed apt-get; then
    info "Installing via apt-get: ${deps[*]}"
    if sudo apt-get update && sudo apt-get install -y "${deps[@]}"; then
      info "Dependency installation completed."
    else
      warn "Dependency installation failed — some tools may not be available."
    fi
  elif is_installed dnf; then
    info "Installing via dnf: ${deps[*]}"
    if sudo dnf install -y "${deps[@]}"; then
      info "Dependency installation completed."
    else
      warn "Dependency installation failed — some tools may not be available."
    fi
  elif is_installed pacman; then
    info "Installing via pacman: ${deps[*]}"
    if sudo pacman -S --noconfirm "${deps[@]}"; then
      info "Dependency installation completed."
    else
      warn "Dependency installation failed — some tools may not be available."
    fi
  elif is_installed brew; then
    info "Installing via brew: ${deps[*]}"
    if brew install "${deps[@]}"; then
      info "Dependency installation completed."
    else
      warn "Dependency installation failed — some tools may not be available."
    fi
  else
    warn "No supported package manager found. Please install manually: ${deps[*]}"
    return 1
  fi

  # Re-check missing deps after attempted install
  local still_missing=()
  for dep in "${deps[@]}"; do
    if ! is_installed "$dep"; then
      still_missing+=("$dep")
    fi
  done
  if [[ ${#still_missing[@]} -gt 0 ]]; then
    warn "Still missing after install attempt: ${still_missing[*]}"
  warn "Note: command names may differ by distribution — check your package manager."
    return 1
  fi
  return 0
}

# ── fzf availability check / install ───────────────────────────────────────
prompt_fzf_install() {
  if has_fzf; then
    return 0
  fi

  header "Optional — fzf not found"

  echo "fzf is not installed. The interactive module selector needs fzf."
  echo ""
  echo -n "Install fzf now? [y/N] "
  read -r response
  if [[ ! "$response" =~ ^[Yy]$ ]]; then
    info "Skipping fzf installation — will use numeric selector instead."
    return 1
  fi

  install_deps fzf
  return 0
}

# ── installation ─────────────────────────────────────────────────────────────
do_install() {
  header "Step 4 — Installing $KIT_NAME"

  # Create install dir and subdirs
  mkdir -p "${INSTALL_DIR}/modules"
  mkdir -p "${INSTALL_DIR}/catalog"

  # ── Install catalog ─────────────────────────────────────────────────────────
  if _is_local_clone; then
    cp "${SCRIPT_DIR}/catalog/modules.conf" "${INSTALL_DIR}/catalog/modules.conf"
  else
    _fetch_remote "${GITHUB_RAW}/catalog/modules.conf" "${INSTALL_DIR}/catalog/modules.conf"
  fi
  info "Installed catalog"

  # ── Install selected modules ───────────────────────────────────────────────
  # Iterate in catalog order for determinism, regardless of input order.
  for i in "${!MODULE_IDS[@]}"; do
    local id="${MODULE_IDS[$i]}"
    # Only install if this id is in the selected set
    case ",${SELECTED_IDS}," in
      *",${id},"*) ;;   # selected
      *) continue ;;       # not selected
    esac
    local src_file="${MODULE_FILES[$i]}"
    if _is_local_clone; then
      cp "${SCRIPT_DIR}/${src_file}" "${INSTALL_DIR}/${src_file}"
    else
      _fetch_remote "${GITHUB_RAW}/${src_file}" "${INSTALL_DIR}/${src_file}"
    fi
    info "Installed module: $id"
  done

  # ── Generate shell.bash loader ──────────────────────────────────────────────
  generate_shell_bash
  info "Generated shell.bash"

  # ── Copy install.sh (so uninstall works) ───────────────────────────────────
  if _is_local_clone; then
    cp "${SCRIPT_DIR}/install.sh" "${INSTALL_DIR}/install.sh"
  else
    _fetch_remote "${GITHUB_RAW}/install.sh" "${INSTALL_DIR}/install.sh"
  fi
  info "Installed install.sh"

  # ── Copy uninstall.sh ──────────────────────────────────────────────────────
  if _is_local_clone; then
    if [[ -f "${SCRIPT_DIR}/uninstall.sh" ]]; then
      cp "${SCRIPT_DIR}/uninstall.sh" "${INSTALL_DIR}/uninstall.sh"
      chmod +x "${INSTALL_DIR}/uninstall.sh"
      info "Installed uninstall.sh"
    else
      warn "uninstall.sh not found — uninstall will not be available"
    fi
  else
    _fetch_remote "${GITHUB_RAW}/uninstall.sh" "${INSTALL_DIR}/uninstall.sh"
    chmod +x "${INSTALL_DIR}/uninstall.sh"
    info "Installed uninstall.sh"
  fi
}

# ── shell.bash generation ────────────────────────────────────────────────────
generate_shell_bash() {
  local dest="${INSTALL_DIR}/shell.bash"

  cat > "$dest" <<'HEADER'
# =============================================================================
# juanrra-terminal-kit — shell.bash (generated)
# =============================================================================
# Auto-generated by install.sh — edits here may be overwritten.
# Keep personal overrides in shell.bash.local instead.
# =============================================================================

HEADER

  # Source each selected module in catalog order for determinism.
  # Use single-quoted heredoc so no variable expansion happens at write time.
  # bash will expand ${HOME} when sourcing shell.bash at runtime.
  for i in "${!MODULE_IDS[@]}"; do
    local id="${MODULE_IDS[$i]}"
    case ",${SELECTED_IDS}," in
      *",${id},"*) ;;   # selected
      *) continue ;;       # not selected
    esac
    local mod_file="${MODULE_FILES[$i]}"
    printf 'source "${HOME}/.config/%s/%s"\n' "$KIT_NAME" "$mod_file" >> "$dest"
  done

  # Source local overrides.
  # Use single-quoted heredoc — ${HOME} is literal, expanded at source time.
  cat >> "$dest" <<'LOCAL'

# ── local overrides ─────────────────────────────────────────────────────────
# Keep personal customisations here so 'git pull' on the kit won't overwrite them
if [[ -f "${HOME}/.config/juanrra-terminal-kit/shell.bash.local" ]]; then
  source "${HOME}/.config/juanrra-terminal-kit/shell.bash.local"
fi
LOCAL
}

# ── .bashrc management ───────────────────────────────────────────────────────
# ── safe marker block removal ───────────────────────────────────────────────
# Removes only complete start+end marker blocks.
# Preserves orphan start blocks (no matching end) and all other content.
# Algorithm: exact-line start/end matching with line buffering.
#   - start while outside: start buffering
#   - end while buffering: discard complete block, stop buffering
#   - start while buffering: flush previous as orphan, start new buffer
#   - EOF while buffering: flush remaining as orphan
_remove_bashrc_markers() {
  local file="$1"
  local tmpfile
  tmpfile=$(mktemp)
  awk \
    -v start="$MARKER_START" \
    -v end="$MARKER_END" '
  $0 == start {
    if (buffering == 1) {
      # Previous start had no end before this start — orphan; flush it
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
      # Complete block found; discard it
      buffering = 0
      buf_idx = 0
      orphan_start = ""
      next
    }
    # Orphan end or end outside block — not a block marker, print it
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
      # Orphan block (no end before EOF); flush orphan start + content
      print orphan_start
      for (i = 1; i <= buf_idx; i++) print buf[i]
    }
  }
  ' "$file" > "$tmpfile" && mv "$tmpfile" "$file"
}

install_bashrc_marker() {
  header "Step 5 — Configuring $BASHRC"

  # Backup .bashrc before modifying
  if [[ -f "$BASHRC" ]]; then
    local backup_bashrc="${BASHRC}.backup.$(date +%Y%m%d_%H%M%S).$$"
    cp "$BASHRC" "$backup_bashrc"
    info "Backed up $BASHRC to $backup_bashrc"
  fi

  # Try safe removal; orphan start without end is preserved silently
  if grep -Fq "$MARKER_START" "$BASHRC" 2>/dev/null; then
    info "Removing old installation marker from $BASHRC"
    _remove_bashrc_markers "$BASHRC"
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

# ── verification ─────────────────────────────────────────────────────────────
verify_install() {
  header "Step 6 — Verifying installation"

  local ok=true

  if [[ -f "${INSTALL_DIR}/shell.bash" ]]; then
    info "shell.bash present"
  else
    error "shell.bash missing"
    ok=false
  fi

  if [[ -f "${INSTALL_DIR}/install.sh" ]]; then
    info "install.sh present"
  else
    error "install.sh missing"
    ok=false
  fi

  if [[ -f "${INSTALL_DIR}/uninstall.sh" ]]; then
    info "uninstall.sh present"
  else
    error "uninstall.sh missing"
    ok=false
  fi

  if [[ -f "${INSTALL_DIR}/catalog/modules.conf" ]]; then
    info "catalog/modules.conf present"
  else
    error "catalog/modules.conf missing"
    ok=false
  fi

  # Verify selected modules are installed
  local IFS=,
  for id in $SELECTED_IDS; do
    local idx
    idx=$(module_index "$id")
    local mod_file="${MODULE_FILES[$idx]}"
    if [[ -f "${INSTALL_DIR}/${mod_file}" ]]; then
      info "module $id present"
    else
      error "module $id missing (${mod_file})"
      ok=false
    fi
  done

  if grep -Fq "$MARKER_START" "$BASHRC" && grep -Fq "$SOURCE_LINE" "$BASHRC"; then
    info "$BASHRC configured correctly"
  else
    error "$BASHRC may not be configured correctly"
    ok=false
  fi

  if ! $ok; then
    exit 1
  fi
}

# ── backup ───────────────────────────────────────────────────────────────────
backup_existing() {
  if [[ ! -d "$INSTALL_DIR" ]]; then
    return 0
  fi

  header "Backup — existing installation found"

  local backup_dir="${INSTALL_DIR}.backup.$(date +%Y%m%d_%H%M%S)"
  info "Backing up to $backup_dir"
  cp -r "$INSTALL_DIR" "$backup_dir"

  if grep -q "$MARKER_START" "$BASHRC" 2>/dev/null; then
    info "Existing bashrc marker will be replaced"
  fi
}

# ── shell detection ──────────────────────────────────────────────────────────
detect_shell() {
  if [[ -n "$BASH_VERSION" ]]; then
    info "Running under Bash $BASH_VERSION"
  elif [[ -n "$ZSH_VERSION" ]]; then
    warn "Zsh detected — this installer targets Bash."
  else
    error "Unsupported shell. This installer requires Bash."
    exit 1
  fi
}

# ── main ─────────────────────────────────────────────────────────────────────
main() {
  # Determine script directory early (before curl might change cwd)
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  echo ""
  echo -e "${BOLD}╔════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}║           ${KIT_NAME} — Installer${NC}                          ║${NC}"
  echo -e "${BOLD}╚════════════════════════════════════════════════════════╝${NC}"
  echo ""

  # If already installed, confirm re-install
  if [[ -d "$INSTALL_DIR" ]] && [[ -f "${INSTALL_DIR}/shell.bash" ]]; then
    if [[ "${JTK_ASSUME_NO:-}" == "1" ]]; then
      info "Already installed — skipping re-install (JTK_ASSUME_NO=1)"
      exit 0
    fi
    echo -n "$KIT_NAME is already installed. Re-install? [y/N] "
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
      info "Aborting."
      exit 0
    fi
    backup_existing
  fi

  # Check core deps (git, curl needed for remote install)
  if ! is_installed git; then
    error "git is required but not installed."
    exit 1
  fi
  if ! is_installed curl; then
    error "curl is required but not installed."
    exit 1
  fi

  detect_shell

  # Prompt for fzf install if missing (before module selection).
  # Skip if JTK_MODULES is set — we don't need fzf for selection when using env var.
  if ! has_fzf && [[ -z "${JTK_MODULES:-}" && "${JTK_ASSUME_NO:-}" != "1" ]]; then
    if prompt_fzf_install; then
      # fzf was just installed — re-check
      if ! has_fzf; then
        warn "fzf installation failed — will use numeric selector."
      fi
    fi
  fi

  # Read catalog
  if _is_local_clone; then
    CATALOG_PATH="${SCRIPT_DIR}/catalog/modules.conf"
  else
    CATALOG_PATH="${INSTALL_DIR}/catalog/modules.conf"
    mkdir -p "${INSTALL_DIR}/catalog"
    _fetch_remote "${GITHUB_RAW}/catalog/modules.conf" "$CATALOG_PATH"
  fi

  parse_catalog "$CATALOG_PATH"

  if [[ ${#MODULE_IDS[@]} -eq 0 ]]; then
    error "No modules found in catalog."
    exit 1
  fi

  select_modules
  check_dependencies
  do_install
  install_bashrc_marker
  verify_install

  echo ""
  info "✅ ${KIT_NAME} installed successfully!"
  echo ""
  echo "Next steps:"
  echo "  1. Restart your terminal or run: source $BASHRC"
  echo "  2. Edit ${INSTALL_DIR}/shell.bash.local for personal overrides"
  echo "  3. To uninstall: bash ${INSTALL_DIR}/uninstall.sh"
  echo ""
}

main "$@"
