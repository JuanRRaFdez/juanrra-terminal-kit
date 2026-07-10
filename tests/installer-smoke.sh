#!/usr/bin/env bash
# =============================================================================
# juanrra-terminal-kit — installer-smoke.sh
# =============================================================================
# NOTE: `set -e` is NOT used in this script. Assertions are binding via `|| exit 1`.
# This avoids complex `set -e` interaction with bash subshell/function parsing.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_SH="${SCRIPT_DIR}/../install.sh"
UNINSTALL_SH="${SCRIPT_DIR}/../uninstall.sh"
CATALOG="${SCRIPT_DIR}/../catalog/modules.conf"
export INSTALL_SH UNINSTALL_SH CATALOG SCRIPT_DIR

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

passed=0
failed=0

ok()   { echo -e "${GREEN}[PASS]${NC} $*"; ((passed++)) || true; }
fail() { echo -e "${RED}[FAIL]${NC} $*"; ((failed++)) || true; }

run_test() {
  local name="$1"; shift
  echo ""
  echo -e "${BOLD}--- $name ---${NC}"

  local tf
  tf=$(mktemp)
  # Write test body + final "exit 0" (reached only if all assertions pass).
  {
    printf '%s\n' "$@"
    printf 'exit 0\n'
  } > "$tf"

  # `set -e` inside the subshell causes it to exit on first assertion failure (non-zero).
  # Assertions are binding: any `test ...` failing → subshell exits 1.
  # The harness captures rc from the subshell itself (not a pipeline).
  set +e
  local out
  out=$(bash -c 'set -euo pipefail; source "$1"' _ "$tf" 2>&1)
  local rc=$?
  set -e
  rm -f "$tf"

  if [[ $rc -ne 0 && -n "$out" ]]; then
    echo "$out"
  fi

  if [[ "$rc" -eq 0 ]]; then
    ok "$name"
  else
    fail "$name (exit $rc)"
  fi

  return 0
}

# ── Pre-flight ────────────────────────────────────────────────────────────────
if [[ ! -f "$INSTALL_SH" ]]; then
  echo -e "${RED}[ERROR]${NC} install.sh not found at $INSTALL_SH"
  exit 1
fi
if [[ ! -f "$CATALOG" ]]; then
  echo -e "${RED}[ERROR]${NC} catalog/modules.conf not found at $CATALOG"
  exit 1
fi

# ══════════════════════════════════════════════════════════════════════════════
# INSTALL TESTS
# ══════════════════════════════════════════════════════════════════════════════

# ── Test 1: basic install with JTK_MODULES=core ──────────────────────────────
run_test "install JTK_MODULES=core" \
  'tmp_home=$(mktemp -d)' \
  'export tmp_home HOME' \
  'HOME="$tmp_home" JTK_MODULES=core JTK_ASSUME_NO=1 bash "$INSTALL_SH"' \
  'test -f "$tmp_home/.config/juanrra-terminal-kit/shell.bash"' \
  'grep -q "source.*core.bash" "$tmp_home/.config/juanrra-terminal-kit/shell.bash"' \
  '! grep -q "source.*fzf.bash" "$tmp_home/.config/juanrra-terminal-kit/shell.bash"' \
  'grep -qF "source \"\${HOME}/.config/juanrra-terminal-kit/modules/core.bash\"" "$tmp_home/.config/juanrra-terminal-kit/shell.bash"' \
  'rm -rf "$tmp_home"'

# ── Test 2: catalog-order determinism ────────────────────────────────────────
run_test "catalog-order determinism" \
  'tmp_home=$(mktemp -d)' \
  'export tmp_home HOME' \
  'HOME="$tmp_home" JTK_MODULES=starship,core JTK_ASSUME_NO=1 bash "$INSTALL_SH"' \
  'core_line=$(grep -n "source.*core.bash" "$tmp_home/.config/juanrra-terminal-kit/shell.bash" | head -1 | cut -d: -f1)' \
  'starship_line=$(grep -n "source.*starship.bash" "$tmp_home/.config/juanrra-terminal-kit/shell.bash" | head -1 | cut -d: -f1)' \
  'test "$core_line" -lt "$starship_line"' \
  'rm -rf "$tmp_home"'

# ── Test 3: whitespace normalisation ─────────────────────────────────────────
run_test "JTK_MODULES whitespace normalisation" \
  'tmp_home=$(mktemp -d)' \
  'export tmp_home HOME' \
  'HOME="$tmp_home" JTK_MODULES="  core , fzf  " JTK_ASSUME_NO=1 bash "$INSTALL_SH"' \
  'grep -q "source.*core.bash" "$tmp_home/.config/juanrra-terminal-kit/shell.bash"' \
  'grep -q "source.*fzf.bash" "$tmp_home/.config/juanrra-terminal-kit/shell.bash"' \
  'rm -rf "$tmp_home"'

# ── Test 4: unknown module causes failure ────────────────────────────────────
run_test "unknown module causes failure" \
  'set +e' \
  'tmp_home=$(mktemp -d)' \
  'export tmp_home HOME' \
  'output=$(HOME="$tmp_home" JTK_MODULES=core,nonexistent_xyz JTK_ASSUME_NO=1 bash "$INSTALL_SH" 2>&1)' \
  'install_rc=$?' \
  'set -e' \
  'test "$install_rc" -ne 0' \
  'echo "$output" | grep -q "Unknown module: nonexistent_xyz"' \
  'test ! -d "$tmp_home/.config/juanrra-terminal-kit"' \
  'rm -rf "$tmp_home"'

# ── Test 4b: unsafe catalog file path causes failure ─────────────────────────
run_test "unsafe catalog file path rejected" \
  'set +e' \
  'tmp_home=$(mktemp -d)' \
  'tmp_project=$(mktemp -d)' \
  'mkdir -p "$tmp_project/catalog"' \
  'cp "$INSTALL_SH" "$tmp_project/install.sh"' \
  'cp "$CATALOG" "$tmp_project/catalog/modules.conf"' \
  'printf "%s\n" "evil|Unsafe catalog line|Should be rejected||modules/evil.bash;touch" >> "$tmp_project/catalog/modules.conf"' \
  'output=$(HOME="$tmp_home" JTK_MODULES=evil JTK_ASSUME_NO=1 bash "$tmp_project/install.sh" 2>&1)' \
  'install_rc=$?' \
  'set -e' \
  'test "$install_rc" -ne 0 || exit 1' \
  'echo "$output" | grep -qi "Unsafe module file\|unsafe catalog\|refusing" || exit 1' \
  'test ! -d "$tmp_home/.config/juanrra-terminal-kit" || exit 1' \
  'rm -rf "$tmp_home" "$tmp_project"'

# ── Test 5: duplicate modules deduplicated ────────────────────────────────────
run_test "duplicate modules deduplicated" \
  'tmp_home=$(mktemp -d)' \
  'export tmp_home HOME' \
  'HOME="$tmp_home" JTK_MODULES=core,fzf,core,fzf JTK_ASSUME_NO=1 bash "$INSTALL_SH"' \
  'test $(grep -c "source.*core.bash" "$tmp_home/.config/juanrra-terminal-kit/shell.bash") -eq 1' \
  'test $(grep -c "source.*fzf.bash" "$tmp_home/.config/juanrra-terminal-kit/shell.bash") -eq 1' \
  'rm -rf "$tmp_home"'

# ── Test 6: .bashrc backup created on install ─────────────────────────────────
run_test ".bashrc backup on install" \
  'tmp_home=$(mktemp -d)' \
  'export tmp_home HOME' \
  'touch "$tmp_home/.bashrc"' \
  'HOME="$tmp_home" JTK_MODULES=core JTK_ASSUME_NO=1 bash "$INSTALL_SH"' \
  'backup=$(ls "$tmp_home/.bashrc.backup."* 2>/dev/null | head -1)' \
  'test -n "$backup"' \
  'rm -rf "$tmp_home"'

# ── Test 7: no-selection exits non-zero ──────────────────────────────────────
run_test "no-selection exits non-zero" \
  'set +e' \
  'tmp_home=$(mktemp -d)' \
  'export tmp_home HOME' \
  'output=$(HOME="$tmp_home" bash "$INSTALL_SH" </dev/null 2>&1)' \
  'install_rc=$?' \
  'set -e' \
  'test "$install_rc" -ne 0 || exit 1' \
  'echo "$output" | grep -q "No modules selected" || exit 1' \
  'rm -rf "$tmp_home"'

# ══════════════════════════════════════════════════════════════════════════════
# UNINSTALL TESTS
# ══════════════════════════════════════════════════════════════════════════════

# ── Test 8: uninstall removes install dir AND .bashrc marker ──────────────────
run_test "uninstall removes install dir and marker" \
  'tmp_home=$(mktemp -d)' \
  'export tmp_home HOME' \
  'HOME="$tmp_home" JTK_MODULES=core JTK_ASSUME_NO=1 bash "$INSTALL_SH"' \
  'test -d "$tmp_home/.config/juanrra-terminal-kit"' \
  'MARKER_LINE=$(cat "$tmp_home/.bashrc" | grep "juanrra-terminal-kit")' \
  'test -n "$MARKER_LINE"' \
  'HOME="$tmp_home" JTK_ASSUME_YES=1 bash "$UNINSTALL_SH"' \
  'test ! -d "$tmp_home/.config/juanrra-terminal-kit"' \
  '! grep -q "juanrra-terminal-kit" "$tmp_home/.bashrc" 2>/dev/null' \
  'rm -rf "$tmp_home"'

# ── Test 9: uninstall creates .bashrc backup ─────────────────────────────────
run_test "uninstall creates .bashrc backup" \
  'tmp_home=$(mktemp -d)' \
  'export tmp_home HOME' \
  'touch "$tmp_home/.bashrc"' \
  'HOME="$tmp_home" JTK_MODULES=core JTK_ASSUME_NO=1 bash "$INSTALL_SH"' \
  'HOME="$tmp_home" JTK_ASSUME_YES=1 bash "$UNINSTALL_SH"' \
  'count=$(ls "$tmp_home/.bashrc.backup."* 2>/dev/null | wc -l)' \
  'test "$count" -ge 2' \
  'rm -rf "$tmp_home"'

# ── Test 10: uninstall JTK_ASSUME_NO=1 is non-destructive ─────────────────────
run_test "uninstall JTK_ASSUME_NO=1 non-destructive" \
  'tmp_home=$(mktemp -d)' \
  'export tmp_home HOME' \
  'HOME="$tmp_home" JTK_MODULES=core JTK_ASSUME_NO=1 bash "$INSTALL_SH"' \
  'HOME="$tmp_home" JTK_ASSUME_NO=1 bash "$UNINSTALL_SH"' \
  'test -d "$tmp_home/.config/juanrra-terminal-kit"' \
  'rm -rf "$tmp_home"'

# ── Test 11: uninstall refuses if HOME is empty ───────────────────────────────
run_test "uninstall refuses if HOME empty with clear message" \
  'set +e' \
  'output=$(env -i PATH="$PATH" bash "$UNINSTALL_SH" 2>&1)' \
  'guard_rc=$?' \
  'set -e' \
  'test "$guard_rc" -ne 0 || exit 1' \
  'echo "$output" | grep -q "HOME is not set" || exit 1'

# ── Test 11b: uninstall HOME guard — traversal-like HOME ─────────────────────
run_test "uninstall HOME guard traversal-like HOME" \
  'set +e' \
  'tmp_parent=$(mktemp -d)' \
  'output=$(HOME="$tmp_parent/.." JTK_ASSUME_YES=1 bash "$UNINSTALL_SH" 2>&1)' \
  'guard_rc=$?' \
  'set -e' \
  'test "$guard_rc" -ne 0 || exit 1' \
  'echo "$output" | grep -qi "HOME.*traversal\|traversal.*HOME\|refusing" || exit 1' \
  'rm -rf "$tmp_parent"'

# ── Test 12: install HOME guard — HOME unset ─────────────────────────────────
run_test "install HOME guard HOME unset" \
  'set +e' \
  'output=$(env -i PATH="$PATH" bash "$INSTALL_SH" 2>&1)' \
  'guard_rc=$?' \
  'set -e' \
  'test "$guard_rc" -ne 0 || exit 1' \
  'echo "$output" | grep -q "HOME is not set" || exit 1'

# ── Test 12b: install HOME guard — HOME is / ────────────────────────────────
run_test "install HOME guard HOME is /" \
  'set +e' \
  'output=$(HOME=/ bash "$INSTALL_SH" 2>&1)' \
  'guard_rc=$?' \
  'set -e' \
  'test "$guard_rc" -ne 0 || exit 1' \
  'echo "$output" | grep -qi "refusing\|unsafe\|invalid\|HOME" || exit 1'

# ── Test 12c: install HOME guard — HOME is relative ────────────────────────
run_test "install HOME guard HOME is relative" \
  'set +e' \
  'output=$(HOME=tmp JTK_ASSUME_YES=1 bash "$INSTALL_SH" 2>&1)' \
  'guard_rc=$?' \
  'set -e' \
  'test "$guard_rc" -ne 0 || exit 1' \
  'echo "$output" | grep -qi "refusing\|unsafe\|invalid\|HOME\|absolute" || exit 1'

# ── Test 12d: install HOME guard — traversal-like HOME ──────────────────────
run_test "install HOME guard traversal-like HOME" \
  'set +e' \
  'tmp_parent=$(mktemp -d)' \
  'output=$(HOME="$tmp_parent/.." JTK_MODULES=core JTK_ASSUME_NO=1 bash "$INSTALL_SH" 2>&1)' \
  'guard_rc=$?' \
  'set -e' \
  'test "$guard_rc" -ne 0 || exit 1' \
  'echo "$output" | grep -qi "HOME.*traversal\|traversal.*HOME\|refusing" || exit 1' \
  'rm -rf "$tmp_parent"'

# ── Test 13: dep install failure warns and continues degraded ─────────────────
run_test "dep install failure warns and continues degraded" \
  'set +e' \
  'tmp_home=$(mktemp -d)' \
  'export tmp_home HOME' \
  'fake_bin=$(mktemp -d)' \
  'export fake_bin' \
  'printf "#!/bin/bash\nexit 1\n" > "$fake_bin/sudo"' \
  'printf "#!/bin/bash\nexit 1\n" > "$fake_bin/apt-get"' \
  'printf "#!/bin/bash\nexit 1\n" > "$fake_bin/dnf"' \
  'printf "#!/bin/bash\nexit 1\n" > "$fake_bin/pacman"' \
  'printf "#!/bin/bash\nexit 1\n" > "$fake_bin/brew"' \
  'chmod +x "$fake_bin"/{sudo,apt-get,dnf,pacman,brew}' \
  'output=$(printf "y\n" | PATH="$fake_bin:/usr/bin:/bin" HOME="$tmp_home" JTK_MODULES=starship bash "$INSTALL_SH" 2>&1)' \
  'install_rc=$?' \
  'set -e' \
  'test "$install_rc" -eq 0 || exit 1' \
  'echo "$output" | grep -q "Dependency installation failed\|still missing\|No supported package manager" || exit 1' \
  'test -f "$tmp_home/.config/juanrra-terminal-kit/shell.bash" || exit 1' \
  'grep -q "source.*starship.bash" "$tmp_home/.config/juanrra-terminal-kit/shell.bash" || exit 1' \
  'rm -rf "$tmp_home" "$fake_bin"'

# ══════════════════════════════════════════════════════════════════════════════
# BASHRC SURVIVOR TESTS
# ══════════════════════════════════════════════════════════════════════════════

# ── Test 14: .bashrc unrelated content survives marker removal ──────────────────
run_test "bashrc unrelated content survives marker removal" \
  'tmp_home=$(mktemp -d)' \
  'export tmp_home HOME' \
  'echo "# pre-existing line" > "$tmp_home/.bashrc"' \
  'echo "export FOO=bar" >> "$tmp_home/.bashrc"' \
  'HOME="$tmp_home" JTK_MODULES=core JTK_ASSUME_NO=1 bash "$INSTALL_SH"' \
  'HOME="$tmp_home" JTK_ASSUME_YES=1 bash "$UNINSTALL_SH"' \
  'grep -q "pre-existing line" "$tmp_home/.bashrc"' \
  'grep -q "export FOO=bar" "$tmp_home/.bashrc"' \
  '! grep -q "juanrra-terminal-kit" "$tmp_home/.bashrc" 2>/dev/null' \
  'rm -rf "$tmp_home"'

# ══════════════════════════════════════════════════════════════════════════════
# SYNTAX TESTS
# ══════════════════════════════════════════════════════════════════════════════

# ── Test 15: install.sh syntax ─────────────────────────────────────────────
run_test "install.sh bash -n" \
  'bash -n "$INSTALL_SH"'

# ── Test 16: uninstall.sh syntax ───────────────────────────────────────────
run_test "uninstall.sh bash -n" \
  'bash -n "$UNINSTALL_SH"'

# ── Test 17: module files syntax ─────────────────────────────────────────────
run_test "module files bash -n" \
  'export SCRIPT_DIR' \
  'bash -n "$SCRIPT_DIR/../modules/core.bash"' \
  'bash -n "$SCRIPT_DIR/../modules/fzf.bash"' \
  'bash -n "$SCRIPT_DIR/../modules/atuin.bash"' \
  'bash -n "$SCRIPT_DIR/../modules/starship.bash"' \
  'bash -n "$SCRIPT_DIR/../modules/zoxide.bash"' \
  'bash -n "$SCRIPT_DIR/../modules/nvim.bash"' \
  'bash -n "$SCRIPT_DIR/../modules/dev-tools.bash"'

# ── Summary ────────────────────────────────────────────────────────────────
echo ""
echo "============================================"
echo -e "${BOLD}Results: ${GREEN}$passed passed${NC}, ${RED}$failed failed${NC}"
if [[ $failed -gt 0 ]]; then
  exit 1
fi
