# juanrra-terminal-kit

> Modular terminal setup: pick what you want, skip what you don't.

## Quick Install

**Recommended — clone and run:**

```bash
git clone https://github.com/JuanRRaFdez/juanrra-terminal-kit.git
cd juanrra-terminal-kit
bash install.sh
```

**Remote (useful for first-time setup in a new environment):**

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/JuanRRaFdez/juanrra-terminal-kit/main/install.sh)"
```

> Pipe-to-bash (`curl ... | bash`) is not recommended for interactive use — use the `bash -c "$(curl ...)"` form above instead.

## Module Selection

The installer presents available modules and asks you to choose.

**With fzf** (recommended): use arrows to navigate, `Space` to select, `Enter` to confirm.

**Without fzf**: a numbered list is shown; enter comma-separated numbers (e.g. `1,2,4`).

If fzf is not found, the installer first asks whether to install it. If you decline or the install fails, a numeric selector is used instead.

## Modules

| # | Module | What it does | Dependencies |
|---|--------|--------------|--------------|
| 1 | `core` | Safe aliases (`rm -i`, etc.), `ls`/`git` shortcuts, `mkcd`, `extract`, colour variables, window-title prompt | *(none)* |
| 2 | `fzf` | Fuzzy directory jump (`fcd`), `fe` file open (uses nvim when available), `fd`/`bat`/`eza` integration | `fzf`, `fd`, `bat`, `eza` |
| 3 | `atuin` | Shell history with search and sync | `atuin`, `bash-preexec` |
| 4 | `starship` | Cross-shell prompt | `starship` |
| 5 | `zoxide` | Smart `cd` that learns your habits | `zoxide` |
| 6 | `nvim` | `$EDITOR`/`$VISUAL` set to `nvim`, `Ctrl-O` fuzzy file open (requires fzf+fd) | `nvim`, `fzf`, `fd`, `bat` (enhanced preview) |
| 7 | `dev-tools` | Paths for Homebrew, pnpm, npm global, bun | *(none)* |

Degraded modules work gracefully — if an optional tool is missing, its features are skipped silently.

> **Atuin privacy note:** Atuin can sync your shell history to its servers if you configure an account and enable sync. History may include sensitive commands (passwords, tokens, paths). If you use Atuin, review its sync and privacy settings. The `atuin` module does not enable sync automatically.

## Dependency Policy

Catalog dependencies are command names (e.g. `fd`, `bat`) checked with `command -v`. Package names may differ by distribution — on Debian/Ubuntu, the `fd` command is in the `fd-find` package.

The installer **never installs dependencies silently**. Missing dependencies are collected across all selected modules and presented in a single prompt:

```
Missing dependencies: fd bat eza
Install missing dependencies now? [y/N]
```

Say no and the module still installs — it just degrades. Use `JTK_ASSUME_NO=1` to skip all dependency prompts and continue with graceful degradation.

## Re-install / Update

Re-running the installer on an existing installation:

1. Asks to confirm before overwriting.
2. Backs up the existing `$HOME/.config/juanrra-terminal-kit/` to a timestamped backup directory.
3. Installs only the modules you select this time.
4. Preserves `$HOME/.config/juanrra-terminal-kit/shell.bash.local`.

## What Gets Added to `.bashrc`

Three lines, clearly marked — nothing else is modified:

```bash
# >>>>> juanrra-terminal-kit >>>>>
[ -f "${HOME}/.config/juanrra-terminal-kit/shell.bash" ] && source "${HOME}/.config/juanrra-terminal-kit/shell.bash"
# <<<<< juanrra-terminal-kit <<<<<
```

The installer generates `~/.config/juanrra-terminal-kit/shell.bash` — it sources only the modules you selected.

## Uninstall

```bash
bash ~/.config/juanrra-terminal-kit/uninstall.sh
```

You are prompted separately for:
- Removing the `~/.config/juanrra-terminal-kit/` directory
- Cleaning the `.bashrc` marker block

**Unattended destructive (no prompts):**

```bash
JTK_ASSUME_YES=1 bash ~/.config/juanrra-terminal-kit/uninstall.sh
```

This removes both the directory and the `.bashrc` marker block without asking.

**Non-destructive dry-run:**

```bash
JTK_ASSUME_NO=1 bash ~/.config/juanrra-terminal-kit/uninstall.sh
```

Exits without removing anything — useful to check the script's behaviour without making changes.

## Local Overrides

Create `~/.config/juanrra-terminal-kit/shell.bash.local` to add personal customisations that survive re-installs:

```bash
PS1="\w \$ "
alias myalias='do something'
```

This file is never overwritten by the installer.

## Non-interactive / CI

| Variable | Effect |
|----------|--------|
| `JTK_MODULES=core,fzf` | Skip interactive selection; install only these modules |
| `JTK_ASSUME_NO=1` | Skip all install prompts (requires `JTK_MODULES`); without `JTK_MODULES` the installer exits — it cannot run interactively without knowing which modules to select |

Example — isolated test install of `core` and `fzf` to a temporary directory:

```bash
HOME=/tmp/test-install \
  JTK_MODULES=core,fzf \
  JTK_ASSUME_NO=1 \
  bash install.sh
```

## Structure

```
juanrra-terminal-kit/
├── install.sh              # Installer
├── uninstall.sh            # Uninstaller
├── shell.bash             # Repo reference — the installed loader is auto-generated
├── catalog/
│   └── modules.conf       # Module definitions (id, title, description, dependencies, file)
└── modules/
    ├── core.bash
    ├── fzf.bash
    ├── atuin.bash
    ├── starship.bash
    ├── zoxide.bash
    ├── nvim.bash
    └── dev-tools.bash
```

## Requirements

- Bash 4+
- `git` and `curl` (needed by the installer itself)

Everything else is optional — modules degrade gracefully when their tools are absent.

## License

MIT
