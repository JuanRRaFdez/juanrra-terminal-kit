# juanrra-terminal-kit

> Your terminal, your way. A lightweight, auditable Bash terminal setup you can clone and go.

## Features

- **Minimal** — single `shell.bash` file, sourced from your `.bashrc`
- **Auditable** — you see exactly what gets added to your `.bashrc` (3 lines with markers)
- **Safe** — dependency installation requires your explicit confirmation
- **Portable** — works across Linux distributions
- **Self-contained** — personal overrides go in `shell.bash.local`, never overwritten by updates

## Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/juanrrafdez/juanrra-terminal-kit/main/install.sh | bash
```

Or clone and run locally:

```bash
git clone https://github.com/juanrrafdez/juanrra-terminal-kit.git
cd juanrra-terminal-kit
bash install.sh
```

## What Gets Added to My `.bashrc`?

Three lines, clearly marked:

```bash
# >>>>> juanrra-terminal-kit >>>>>
[ -f "$HOME/.config/juanrra-terminal-kit/shell.bash" ] && source "$HOME/.config/juanrra-terminal-kit/shell.bash"
# <<<<< juanrra-terminal-kit <<<<<
```

That's it. Nothing else is modified.

## Uninstall

```bash
bash ~/.config/juanrra-terminal-kit/uninstall.sh
```

## Customisation

Edit your local overrides without touching the kit:

```bash
# ~/.config/juanrra-terminal-kit/shell.bash.local
PS1="\w \$ "
alias myalias='do something'
```

## Requirements

- Bash 4+
- `git` (for version control integration)
- `curl` (for the one-liner installer)

## Structure

```
juanrra-terminal-kit/
├── install.sh      # Main installer
├── uninstall.sh   # Clean removal
├── shell.bash     # The kit — sourced by your .bashrc
└── README.md
```

## License

MIT — use it, break it, make it yours.
