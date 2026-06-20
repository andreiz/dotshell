# dotshell

Modular dotfile management for macOS and Linux — Stow-based, zero-framework, one command to feel at home.

## Quick Start

### Fresh machine

```bash
curl -fsSL https://raw.githubusercontent.com/andreiz/dotshell/main/bootstrap.sh | bash
cd ~/projects/dotshell
./install.sh all
```

### Already have git and stow

```bash
git clone git@github.com:andreiz/dotshell.git ~/projects/dotshell
cd ~/projects/dotshell
./install.sh all
```

## Usage

```bash
./install.sh all              # install everything
./install.sh list             # see available modules
./install.sh vim zsh git      # install specific modules
```

The `brew` module is **opt-in** — it is excluded from `./install.sh all` and must be run explicitly. It installs packages from a curated Brewfile, with optional per-machine extras:

```bash
./install.sh brew                          # base Brewfile only
./install.sh brew --extra=laptop           # base + modules/brew/Brewfile.laptop
./install.sh brew --extra=desktop          # base + modules/brew/Brewfile.desktop
./install.sh brew --extra=desktop --force-casks   # also overwrite/adopt pre-existing apps
```

`--force-casks` passes `--force` to `brew bundle install` so a cask overwrites/adopts an app that's already in `/Applications` at a different version (otherwise brew aborts that cask with a version-mismatch error). It's off by default — nothing in `/Applications` is overwritten unless you ask.

Mac App Store apps are not managed by `brew bundle`; install them manually (the base `Brewfile` lists them in a comment). After installing, the module does a drift check against the **union of all Brewfiles** (base + every `Brewfile.*`, regardless of `--extra`, so another machine's packages aren't flagged) and, if anything installed isn't tracked, prints a one-line pointer to review it with `brew bundle cleanup` — it never uninstalls anything.

## Modules

| Module | Manages | Platform |
|--------|---------|----------|
| `zsh` | `.zshrc`, `.zsh/` config dir, `.p10k.zsh`, antigen, powerlevel10k | all |
| `vim` | `.vimrc` | all |
| `git` | `.gitconfig`, `.gitignore_global` | all |
| `ssh` | `.ssh/config` | all |
| `karabiner` | `.config/karabiner/karabiner.json` | macOS |
| `macos` | System defaults, login items | macOS |
| `readline` | `.inputrc`, `.screenrc` | all |
| `brew` | Homebrew packages via `Brewfile` (+ per-machine extras) | macOS |

## How It Works

Each module is a directory under `modules/` whose layout mirrors `$HOME`. [GNU Stow](https://www.gnu.org/software/stow/) creates symlinks into `~` automatically.

OS-specific files live in `overlays/darwin/` or `overlays/linux/` and are layered on top of the base module at install time.

Modules that need more than symlinking (e.g., installing packages, running `defaults` commands) define a `post_install()` hook in `module.sh`.

## Adding a Module

1. Create `modules/<name>/` with files mirroring their `$HOME` paths
2. Optionally create `modules/<name>/module.sh` for post-install logic or OS restrictions
   - Set `optional=true` in `module.sh` to exclude the module from `./install.sh all` (it will still run when named explicitly).
3. Optionally create `overlays/darwin/<name>/` or `overlays/linux/<name>/` for OS-specific files
4. Run `./install.sh <name>`

## Structure

```
dotshell/
├── bootstrap.sh        # fresh machine setup
├── install.sh          # orchestrator
├── lib/
│   └── common.sh       # OS detection, logging
├── modules/            # one dir per tool, mirrors $HOME
└── overlays/
    ├── darwin/         # macOS-specific additions
    └── linux/          # Linux-specific additions
```
