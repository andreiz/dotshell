# dotshell — Design Spec

A git-tracked, modular dotfile management system for macOS and Linux using GNU Stow.

## Goals

- Quickly configure a new machine (macOS or Linux) with preferred shell, editor, and tool configs
- Modular: install only what you need (`./install.sh vim git zsh`)
- Shared base configs with OS-specific overlays
- Simple — no Ansible, no templating engines, just shell scripts and Stow
- Migration from existing `~/projects/dotfiles` repo

## Non-Goals (for now)

- Package management (Homebrew, apt)
- Host-to-module mapping / push-based updates to multiple machines
- macOS version-specific defaults handling
- Secrets management

## Repository Structure

```
dotshell/
├── bootstrap.sh            # fresh machine setup (git, stow, clone repo)
├── install.sh              # orchestrator
├── lib/
│   ├── common.sh           # OS detection, logging helpers
│   └── module.sh           # module discovery and execution logic
├── modules/
│   ├── zsh/
│   │   ├── module.sh       # optional: post_install (e.g., chsh to zsh)
│   │   ├── .zshrc
│   │   └── .zsh/
│   │       ├── aliases.sh
│   │       ├── env.sh
│   │       ├── functions.sh
│   │       └── nvm.sh
│   ├── vim/
│   │   └── .vimrc
│   ├── git/
│   │   ├── .gitconfig
│   │   └── .gitignore
│   ├── tmux/
│   │   └── .tmux.conf
│   ├── ssh/
│   │   └── .ssh/
│   │       └── config
│   ├── karabiner/
│   │   └── .config/
│   │       └── karabiner/
│   │           └── karabiner.json
│   └── macos/
│       ├── module.sh       # requires_os="darwin", runs defaults + login items
│       ├── defaults.sh
│       └── login_items.applescript
└── overlays/
    ├── darwin/
    │   └── zsh/
    │       └── .zsh/
    │           └── env.macos.sh
    └── linux/
        └── zsh/
            └── .zsh/
                └── env.linux.sh
```

### Directory Conventions

- **`modules/<name>/`** — each module's file layout mirrors `$HOME`. Stow symlinks the contents into `~`.
- **`modules/<name>/module.sh`** — optional. Declares `requires_os` and/or `post_install()` for modules that need more than symlinking.
- **`overlays/<os>/<module>/`** — OS-specific files that layer on top of a base module. Same Stow convention — mirrors `$HOME`.
- **`lib/`** — shared shell helpers used by `install.sh` and module scripts.

## Module System

### Stow-Based Symlinking

Modules use GNU Stow for all symlinking. The directory structure inside a module mirrors the target location relative to `$HOME`.

Install a module: `stow -d modules -t $HOME <module>`

This works for both traditional dotfiles (`~/.vimrc`) and XDG-style configs (`~/.config/<app>/`). The module's directory layout encodes the target path — no mapping file or symlinks array needed.

### module.sh (Optional)

Only needed when a module does more than symlinking. Structure:

```bash
#!/usr/bin/env bash

# Skip this module on the wrong OS (optional)
requires_os="darwin"
no_stow=true

# Run after symlinking (optional)
post_install() {
    bash "${MODULE_DIR}/defaults.sh"
}
```

- `requires_os` — if set, the module is skipped when the detected OS doesn't match. Values: `darwin`, `linux`.
- `post_install()` — runs after Stow symlinking completes. `MODULE_DIR` is set by the orchestrator to the module's absolute path.
- Modules without a `module.sh` are pure Stow modules — symlinking only.
- `no_stow=true` — if set, the orchestrator skips the `stow` step entirely. Used for command-only modules like `macos` where files (e.g., `defaults.sh`) are support scripts, not dotfiles to symlink into `$HOME`.

### Module Types

1. **Pure Stow** (most modules) — no `module.sh`. Files are symlinked and that's it. Examples: vim, git, ssh, tmux, karabiner.
2. **Stow + post-install** — has a `module.sh` with `post_install()`. Example: zsh (may need `chsh`).
3. **Commands only** — has a `module.sh` with `no_stow=true`, `requires_os`, and `post_install()`. No files are symlinked. Example: macos (runs `defaults` commands).

## Overlays

Overlays add OS-specific files on top of a base module. They follow the same Stow directory convention.

After stowing a base module, the orchestrator checks for a matching overlay:

```
overlays/<detected_os>/<module>/
```

If it exists, it's stowed on top: `stow -d overlays/<os> -t $HOME <module>`

### Overlay Strategy

Overlays are **additive** — they add files alongside the base module's files. They do not replace base files.

Example: the `zsh` module provides `~/.zsh/env.sh` (universal settings). The darwin overlay provides `~/.zsh/env.macos.sh` (Homebrew paths). The `.zshrc` sources all `~/.zsh/*.sh` files, so both get loaded.

If an overlay ever needs to replace a base file, that's handled as a special case in the module's `module.sh` rather than through Stow.

## Orchestrator (`install.sh`)

### Usage

```bash
./install.sh [module ...]    # install specific modules
./install.sh all             # install all modules (respecting requires_os)
./install.sh list            # show available modules and their OS restrictions
```

### Execution Flow

1. **Detect OS** — `uname -s` → `darwin` or `linux` (lowercased)
2. **Check dependencies** — verify `stow` is installed; bail with a helpful message if not
3. **Resolve module list** — from arguments, or discover all modules in `modules/` if `all`
4. **For each module:**
   a. Source `module.sh` if it exists
   b. Check `requires_os` — skip with a message if wrong OS
   c. Run `stow -d modules -t $HOME <module>` if the module has stowable files
   d. Run `stow -d overlays/<os> -t $HOME <module>` if an overlay exists
   e. Run `post_install()` if defined
5. **Report results** — which modules were installed, skipped, or errored

### Logging

Colored output helpers (`info`, `success`, `error`, `substep`) in `lib/common.sh`, matching the style of the existing `setup.sh`.

## Bootstrap (`bootstrap.sh`)

Handles fresh machine setup — the only script you run manually before `install.sh`.

### What It Does

1. **macOS:** Install Xcode CLI tools (provides git), install Homebrew, `brew install stow`
2. **Linux:** `sudo apt install git stow` (or equivalent for the detected distro)
3. Clone the dotshell repo
4. Print next steps: `./install.sh all` or pick modules

### Invocation

```bash
# One-liner for a fresh machine:
curl -fsSL https://raw.githubusercontent.com/andreiz/dotshell/main/bootstrap.sh | bash
```

## Migration Plan

Restructure content from `~/projects/dotfiles` into the new layout:

1. Create the `dotshell` repo structure
2. Move dotfiles into Stow-compatible module directories (rename files to match target paths)
3. Split `env.sh` into universal and macOS-specific parts
4. Move macOS defaults/login items into `modules/macos/`
5. Verify with `stow --simulate` before applying
6. Test on current machine, then on a fresh VM

## Future Considerations

- **Host management:** A hosts file mapping hostnames to module lists, with a `push.sh` to SSH in, pull, and run install.
- **macOS version-specific defaults:** Conditional logic or version-tagged defaults files to handle Apple changing/removing `defaults` keys between OS releases.
- **Secrets via 1Password CLI:** For modules with sensitive values (SSH config, git signing key, API tokens), use `op inject` in `post_install()` to render `.tpl` files with `op://` references. Templated files are rendered copies (not symlinks), so those modules skip Stow for the templated files. Most modules remain pure Stow — secrets support is opt-in per module.
- **Package management:** Brewfile/apt package lists as optional modules.
- **Uninstall/restow:** `./install.sh restow <module>` using `stow -R` for when module layouts change.
