# dotshell Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a modular, Stow-based dotfile management system and migrate existing dotfiles into it.

**Architecture:** Shell scripts + GNU Stow. A thin orchestrator (`install.sh`) iterates modules, runs `stow` for symlinking, applies OS overlays, and runs optional post-install hooks. A `bootstrap.sh` handles fresh machine setup.

**Tech Stack:** Bash, GNU Stow

---

## File Structure

```
dotshell/
├── bootstrap.sh
├── install.sh
├── .gitignore
├── lib/
│   └── common.sh
├── modules/
│   ├── zsh/
│   │   ├── module.sh
│   │   ├── .zshrc
│   │   └── .zsh/
│   │       ├── aliases.sh
│   │       ├── env.sh
│   │       └── functions.sh
│   ├── vim/
│   │   └── .vimrc
│   ├── git/
│   │   ├── .gitconfig
│   │   └── .gitignore_global
│   ├── ssh/
│   │   └── .ssh/
│   │       └── config
│   ├── karabiner/
│   │   ├── module.sh
│   │   └── .config/
│   │       └── karabiner/
│   │           └── karabiner.json
│   └── macos/
│       ├── module.sh
│       ├── defaults.sh
│       ├── system.sh
│       └── login_items.applescript
└── overlays/
    └── darwin/
        └── zsh/
            └── .zsh/
                └── env.macos.sh
```

Note: The git module uses `.gitignore_global` (not `.gitignore`) to avoid conflicting with the repo's own `.gitignore`. The git module's `module.sh` would handle symlinking it to `~/.gitignore` if Stow can't handle the rename — but actually, Stow mirrors paths exactly, so we need to think about this. Options: (a) name it `.gitignore_global` in both repo and home, updating `.gitconfig` to point to it, or (b) put the git module's ignore file at `modules/git/.gitignore` and use a nested `.stow-local-ignore` to prevent Stow from confusing it with a Stow ignore file. Simplest: option (a) — rename to `.gitignore_global` everywhere.

---

### Task 1: Shared Library (`lib/common.sh`)

**Files:**
- Create: `lib/common.sh`

- [ ] **Step 1: Create `lib/common.sh` with OS detection and logging helpers**

```bash
#!/usr/bin/env bash

# Detect OS: "darwin" or "linux"
detect_os() {
    uname -s | tr '[:upper:]' '[:lower:]'
}

DOTSHELL_OS="$(detect_os)"
DOTSHELL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Logging helpers (colored output)
info() {
    tput bold; tput setaf 4
    echo "========> $1"
    tput sgr0
}

substep() {
    tput bold; tput setaf 5
    echo "==== $1"
    tput sgr0
}

success() {
    tput bold; tput setaf 2
    echo "========> $1"
    tput sgr0
}

error() {
    tput bold; tput setaf 1
    echo "========> $1"
    tput sgr0
}
```

- [ ] **Step 2: Verify it loads cleanly**

Run: `bash -c 'source lib/common.sh && echo "OS: $DOTSHELL_OS, DIR: $DOTSHELL_DIR"'`
Expected: `OS: darwin, DIR: /Users/andrei/projects/dotshell`

- [ ] **Step 3: Commit**

```bash
git add lib/common.sh
git commit -m "Add shared library with OS detection and logging helpers"
```

---

### Task 2: Orchestrator (`install.sh`)

**Files:**
- Create: `install.sh`

- [ ] **Step 1: Create `install.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

usage() {
    echo "Usage: ./install.sh <module ...> | all | list"
    echo ""
    echo "Commands:"
    echo "  all           Install all modules (respecting OS restrictions)"
    echo "  list          Show available modules"
    echo "  <module ...>  Install specific modules"
    exit 1
}

# Check that stow is installed
check_dependencies() {
    if ! command -v stow &>/dev/null; then
        error "GNU Stow is not installed. Run bootstrap.sh first or install it manually."
        exit 1
    fi
}

# List all module directory names
list_modules() {
    for dir in "${DOTSHELL_DIR}/modules"/*/; do
        basename "$dir"
    done
}

# Install a single module
install_module() {
    local module="$1"
    local module_dir="${DOTSHELL_DIR}/modules/${module}"

    if [[ ! -d "$module_dir" ]]; then
        error "Module '${module}' not found"
        return 1
    fi

    # Reset per-module variables
    local requires_os=""
    local no_stow=""

    # Source module.sh if it exists (sets requires_os, no_stow, defines post_install)
    unset -f post_install 2>/dev/null
    if [[ -f "${module_dir}/module.sh" ]]; then
        source "${module_dir}/module.sh"
    fi

    # Check OS restriction
    if [[ -n "$requires_os" && "$requires_os" != "$DOTSHELL_OS" ]]; then
        substep "Skipping '${module}' (requires ${requires_os}, running on ${DOTSHELL_OS})"
        return 0
    fi

    info "Installing module: ${module}"

    # Stow the module (unless no_stow is set)
    if [[ "$no_stow" != "true" ]]; then
        if stow -d "${DOTSHELL_DIR}/modules" -t "$HOME" --no-folding "$module"; then
            substep "Stowed ${module}"
        else
            error "Failed to stow ${module}"
            return 1
        fi
    fi

    # Apply OS overlay if it exists
    local overlay_dir="${DOTSHELL_DIR}/overlays/${DOTSHELL_OS}/${module}"
    if [[ -d "$overlay_dir" ]]; then
        if stow -d "${DOTSHELL_DIR}/overlays/${DOTSHELL_OS}" -t "$HOME" --no-folding "$module"; then
            substep "Applied ${DOTSHELL_OS} overlay for ${module}"
        else
            error "Failed to apply overlay for ${module}"
            return 1
        fi
    fi

    # Run post_install if defined
    local MODULE_DIR="$module_dir"
    export MODULE_DIR
    if declare -f post_install &>/dev/null; then
        substep "Running post-install for ${module}"
        post_install
    fi

    success "Module '${module}' installed"
}

# Main
[[ $# -eq 0 ]] && usage

check_dependencies

case "$1" in
    list)
        echo "Available modules:"
        for module in $(list_modules); do
            local_requires=""
            if [[ -f "${DOTSHELL_DIR}/modules/${module}/module.sh" ]]; then
                local_requires=$(grep -oP '(?<=requires_os=").*?(?=")' "${DOTSHELL_DIR}/modules/${module}/module.sh" 2>/dev/null || true)
            fi
            if [[ -n "$local_requires" ]]; then
                echo "  ${module} (${local_requires} only)"
            else
                echo "  ${module}"
            fi
        done
        ;;
    all)
        for module in $(list_modules); do
            install_module "$module"
        done
        ;;
    *)
        for module in "$@"; do
            install_module "$module"
        done
        ;;
esac
```

- [ ] **Step 2: Make it executable and test `list` with no modules yet**

```bash
chmod +x install.sh
./install.sh list
```

Expected: `Available modules:` (empty, no modules yet)

- [ ] **Step 3: Commit**

```bash
git add install.sh
git commit -m "Add install.sh orchestrator with stow, overlays, and module hooks"
```

---

### Task 3: Migrate zsh Module

**Files:**
- Create: `modules/zsh/module.sh`
- Create: `modules/zsh/.zshrc` (adapted from `~/projects/dotfiles/zsh/zshrc`)
- Create: `modules/zsh/.zsh/aliases.sh` (from `~/projects/dotfiles/zsh/config/aliases.sh`)
- Create: `modules/zsh/.zsh/env.sh` (universal parts only)
- Create: `modules/zsh/.zsh/functions.sh` (from `~/projects/dotfiles/zsh/config/functions.sh`)
- Create: `overlays/darwin/zsh/.zsh/env.macos.sh` (macOS-specific parts from env.sh)

The key migration work here is splitting `env.sh`:
- **Universal** (`modules/zsh/.zsh/env.sh`): `TZ`, `EDITOR`, `CDPATH`, `FD_OPTIONS`, `FZF_*`, `BAT_THEME`
- **macOS overlay** (`overlays/darwin/zsh/.zsh/env.macos.sh`): `HOMEBREW_*` vars, `/opt/homebrew` paths, `pyenv` init

The `.zshrc` also needs updating — replace hardcoded `/Users/andrei/.zsh/` source lines with a glob (`for f in ~/.zsh/*.sh; do source "$f"; done`) and replace the hardcoded `/opt/homebrew/share/antigen/antigen.zsh` path with a conditional or move it to the overlay.

- [ ] **Step 1: Create `modules/zsh/.zsh/env.sh` (universal)**

Copy from `~/projects/dotfiles/zsh/config/env.sh`, keeping only the OS-independent lines:

```bash
export TZ=America/Los_Angeles
export EDITOR=vim
export CDPATH=~/

export FD_OPTIONS="--follow --hidden --exclude .git --exclude node_modules"

export FZF_DEFAULT_OPTS="
--no-mouse
--reverse
--height 75%
-1
--multi
--inline-info
--color='hl:148,hl+:154,pointer:032,marker:010,bg+:237,gutter:008'
--preview='([[ -d {} ]] && (tree -C {} | less)) || ([[ \$(file --mime {}) =~ binary ]] && echo {} is a binary file) || (bat --style=numbers --color=always {} || cat {}) 2> /dev/null | head -300' --preview-window='right:hidden:wrap'
--bind='?:toggle-preview,ctrl-d:half-page-down,ctrl-u:half-page-up,ctrl-a:select-all+accept,ctrl-y:execute-silent(echo {+} | pbcopy)'"

export FZF_DEFAULT_COMMAND="git ls-files --cached --others --exclude-standard | fd --type f --type l $FD_OPTIONS"
export FZF_CTRL_T_COMMAND="fd $FD_OPTIONS"
export FZF_ALT_C_COMMAND="fd --type d $FD_OPTIONS"

export BAT_THEME="TwoDark"
```

- [ ] **Step 2: Create `overlays/darwin/zsh/.zsh/env.macos.sh`**

```bash
export HOMEBREW_PREFIX="/opt/homebrew"
export HOMEBREW_CELLAR="/opt/homebrew/Cellar"
export HOMEBREW_REPOSITORY="/opt/homebrew"
export HOMEBREW_NO_INSTALL_UPGRADE=1
export HOMEBREW_NO_INSTALL_CLEANUP=1
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/opt/homebrew/sbin${PATH+:$PATH}"
export MANPATH="/opt/homebrew/share/man${MANPATH+:$MANPATH}:"
export INFOPATH="/opt/homebrew/share/info:${INFOPATH:-}"

export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
```

- [ ] **Step 3: Copy aliases.sh and functions.sh from existing dotfiles**

```bash
cp ~/projects/dotfiles/zsh/config/aliases.sh modules/zsh/.zsh/aliases.sh
cp ~/projects/dotfiles/zsh/config/functions.sh modules/zsh/.zsh/functions.sh
```

- [ ] **Step 4: Create `modules/zsh/.zshrc`**

Adapt from existing zshrc. Key changes:
- Replace hardcoded source lines with a glob pattern
- Move antigen source path to be conditional on OS

```bash
# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

ZSH_DISABLE_COMPFIX="true"

# Antigen — path differs per OS
if [[ -f /opt/homebrew/share/antigen/antigen.zsh ]]; then
    source /opt/homebrew/share/antigen/antigen.zsh
elif [[ -f /usr/share/zsh-antigen/antigen.zsh ]]; then
    source /usr/share/zsh-antigen/antigen.zsh
fi

antigen use oh-my-zsh

antigen bundle brew
antigen bundle command-not-found
antigen bundle common-aliases
antigen bundle git
antigen bundle git-extras
antigen bundle osx
antigen bundle z
antigen bundle zsh-users/zsh-syntax-highlighting
antigen bundle zsh-users/zsh-history-substring-search ./zsh-history-substring-search.zsh

antigen theme romkatv/powerlevel10k

antigen apply

# Source all config files from ~/.zsh/
for f in ~/.zsh/*.sh; do
    [[ -f "$f" ]] && source "$f"
done

setopt nocaseglob
setopt correct

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Optional tool integrations (loaded if present)
[[ -f ~/.config/broot/launcher/bash/br ]] && source ~/.config/broot/launcher/bash/br
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

export NVM_DIR="$HOME/.nvm"
[ -s "$HOMEBREW_PREFIX/opt/nvm/nvm.sh" ] && \. "$HOMEBREW_PREFIX/opt/nvm/nvm.sh"
[ -s "$HOMEBREW_PREFIX/opt/nvm/etc/bash_completion.d/nvm" ] && \. "$HOMEBREW_PREFIX/opt/nvm/etc/bash_completion.d/nvm"
```

- [ ] **Step 5: Create `modules/zsh/module.sh`**

```bash
#!/usr/bin/env bash

post_install() {
    if [[ "$SHELL" != */zsh ]]; then
        info "Changing default shell to zsh"
        chsh -s "$(which zsh)"
    fi
}
```

- [ ] **Step 6: Test with stow simulate**

```bash
stow -d modules -t $HOME --simulate --no-folding zsh
stow -d overlays/darwin -t $HOME --simulate --no-folding zsh
```

Review the output to confirm the correct symlinks would be created. Resolve any conflicts with existing symlinks (you may need to remove the old `~/.zshrc` symlink first).

- [ ] **Step 7: Commit**

```bash
git add modules/zsh/ overlays/darwin/zsh/
git commit -m "Add zsh module with macOS overlay (migrated from dotfiles)"
```

---

### Task 4: Migrate vim Module

**Files:**
- Create: `modules/vim/.vimrc` (from `~/.vimrc`)

- [ ] **Step 1: Copy vimrc**

```bash
mkdir -p modules/vim
cp ~/.vimrc modules/vim/.vimrc
```

- [ ] **Step 2: Test with stow simulate**

```bash
stow -d modules -t $HOME --simulate --no-folding vim
```

- [ ] **Step 3: Commit**

```bash
git add modules/vim/
git commit -m "Add vim module (migrated from dotfiles)"
```

---

### Task 5: Migrate git Module

**Files:**
- Create: `modules/git/.gitconfig` (from `~/projects/dotfiles/git/config`)
- Create: `modules/git/.gitignore_global` (from `~/projects/dotfiles/git/gitignore`)

The `.gitconfig` needs to be updated to reference `~/.gitignore_global` instead of `~/.gitignore`, since `~/.gitignore` would conflict with git's own ignore behavior in the dotshell repo.

- [ ] **Step 1: Copy git config, updating the excludesfile path**

```bash
mkdir -p modules/git
cp ~/projects/dotfiles/git/config modules/git/.gitconfig
cp ~/projects/dotfiles/git/gitignore modules/git/.gitignore_global
```

Edit `modules/git/.gitconfig` line 10: change `excludesfile = ~/.gitignore` to `excludesfile = ~/.gitignore_global`

- [ ] **Step 2: Test with stow simulate**

```bash
stow -d modules -t $HOME --simulate --no-folding git
```

- [ ] **Step 3: Commit**

```bash
git add modules/git/
git commit -m "Add git module (migrated from dotfiles, renamed gitignore to gitignore_global)"
```

---

### Task 6: Migrate ssh Module

**Files:**
- Create: `modules/ssh/.ssh/config` (from `~/projects/dotfiles/ssh/config`)

- [ ] **Step 1: Copy ssh config**

```bash
mkdir -p modules/ssh/.ssh
cp ~/projects/dotfiles/ssh/config modules/ssh/.ssh/config
```

- [ ] **Step 2: Test with stow simulate**

```bash
stow -d modules -t $HOME --simulate --no-folding ssh
```

- [ ] **Step 3: Commit**

```bash
git add modules/ssh/
git commit -m "Add ssh module (migrated from dotfiles)"
```

---

### Task 7: Migrate karabiner Module

**Files:**
- Create: `modules/karabiner/module.sh`
- Create: `modules/karabiner/.config/karabiner/karabiner.json` (from `~/projects/dotfiles/karabiner/karabiner.json`)

- [ ] **Step 1: Copy karabiner config**

```bash
mkdir -p modules/karabiner/.config/karabiner
cp ~/projects/dotfiles/karabiner/karabiner.json modules/karabiner/.config/karabiner/karabiner.json
```

- [ ] **Step 2: Create `modules/karabiner/module.sh`**

```bash
#!/usr/bin/env bash

requires_os="darwin"
```

- [ ] **Step 3: Test with stow simulate**

```bash
stow -d modules -t $HOME --simulate --no-folding karabiner
```

- [ ] **Step 4: Commit**

```bash
git add modules/karabiner/
git commit -m "Add karabiner module (macOS only, migrated from dotfiles)"
```

---

### Task 8: Migrate macos Module

**Files:**
- Create: `modules/macos/module.sh`
- Create: `modules/macos/defaults.sh` (from `~/projects/dotfiles/macos/defaults.sh`)
- Create: `modules/macos/system.sh` (from `~/projects/dotfiles/macos/system.sh`)
- Create: `modules/macos/login_items.applescript` (from `~/projects/dotfiles/macos/login_items.applescript`)

- [ ] **Step 1: Copy macOS files**

```bash
mkdir -p modules/macos
cp ~/projects/dotfiles/macos/defaults.sh modules/macos/defaults.sh
cp ~/projects/dotfiles/macos/system.sh modules/macos/system.sh
cp ~/projects/dotfiles/macos/login_items.applescript modules/macos/login_items.applescript
```

- [ ] **Step 2: Create `modules/macos/module.sh`**

```bash
#!/usr/bin/env bash

requires_os="darwin"
no_stow=true

post_install() {
    info "Configuring macOS defaults"
    bash "${MODULE_DIR}/defaults.sh"

    info "Updating login items"
    osascript "${MODULE_DIR}/login_items.applescript"
}
```

- [ ] **Step 3: Commit**

```bash
git add modules/macos/
git commit -m "Add macos module (defaults + login items, migrated from dotfiles)"
```

---

### Task 9: Add `.gitignore` and Test End-to-End

**Files:**
- Create: `.gitignore`

- [ ] **Step 1: Create `.gitignore`**

```
.DS_Store
*.swp
modules/karabiner/.config/karabiner/automatic_backups/
```

- [ ] **Step 2: Test full install dry run**

```bash
./install.sh list
```

Verify all modules appear with correct OS restrictions.

Then test a single module (pick one that won't conflict with your current setup, e.g., vim):

```bash
# Remove existing file first if needed
rm ~/.vimrc
./install.sh vim
ls -la ~/.vimrc
```

Verify `~/.vimrc` is a symlink pointing into the dotshell repo.

- [ ] **Step 3: Commit**

```bash
git add .gitignore
git commit -m "Add .gitignore and verify end-to-end install"
```

---

### Task 10: Bootstrap Script

**Files:**
- Create: `bootstrap.sh`

- [ ] **Step 1: Create `bootstrap.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail

DOTSHELL_REPO="$HOME/projects/dotshell"
DOTSHELL_REMOTE="https://github.com/andreiz/dotshell.git"

info() {
    tput bold; tput setaf 4; echo "========> $1"; tput sgr0
}

error() {
    tput bold; tput setaf 1; echo "========> $1"; tput sgr0
}

success() {
    tput bold; tput setaf 2; echo "========> $1"; tput sgr0
}

OS="$(uname -s | tr '[:upper:]' '[:lower:]')"

# Install prerequisites
if [[ "$OS" == "darwin" ]]; then
    # Xcode CLI tools (provides git)
    if ! xcode-select --print-path &>/dev/null; then
        info "Installing Xcode command line tools..."
        xcode-select --install
        echo "Press enter after Xcode CLI tools finish installing."
        read -r
    fi

    # Homebrew
    if ! command -v brew &>/dev/null; then
        info "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi

    # Stow
    if ! command -v stow &>/dev/null; then
        info "Installing GNU Stow..."
        brew install stow
    fi

elif [[ "$OS" == "linux" ]]; then
    info "Installing git and stow..."
    if command -v apt &>/dev/null; then
        sudo apt update && sudo apt install -y git stow
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y git stow
    elif command -v pacman &>/dev/null; then
        sudo pacman -Sy --noconfirm git stow
    else
        error "Unsupported package manager. Install git and stow manually."
        exit 1
    fi
fi

# Clone repo
if [[ -d "$DOTSHELL_REPO" ]]; then
    info "dotshell repo already exists at ${DOTSHELL_REPO}"
    git -C "$DOTSHELL_REPO" pull
else
    info "Cloning dotshell repo..."
    mkdir -p "$(dirname "$DOTSHELL_REPO")"
    git clone "$DOTSHELL_REMOTE" "$DOTSHELL_REPO"
    # Switch to SSH remote for future pushes
    git -C "$DOTSHELL_REPO" remote set-url origin "git@github.com:andreiz/dotshell.git"
fi

success "Bootstrap complete!"
echo ""
echo "Next steps:"
echo "  cd ${DOTSHELL_REPO}"
echo "  ./install.sh list        # see available modules"
echo "  ./install.sh all         # install everything"
echo "  ./install.sh vim zsh git # install specific modules"
```

- [ ] **Step 2: Make executable**

```bash
chmod +x bootstrap.sh
```

- [ ] **Step 3: Commit**

```bash
git add bootstrap.sh
git commit -m "Add bootstrap.sh for fresh machine setup"
```

---

### Task 11: Full Integration Test

- [ ] **Step 1: Remove all existing symlinks managed by old dotfiles**

Back up and remove:
```bash
rm ~/.zshrc ~/.gitconfig ~/.gitignore ~/.vimrc ~/.ssh/config
```

(The old symlinks point to `~/projects/dotfiles/` — removing them is safe since the originals are in that repo.)

- [ ] **Step 2: Run full install**

```bash
./install.sh all
```

Verify each module installed. Check symlinks:
```bash
ls -la ~/.zshrc ~/.vimrc ~/.gitconfig ~/.gitignore_global ~/.ssh/config ~/.config/karabiner/karabiner.json ~/.zsh/
```

All should be symlinks into `/Users/andrei/projects/dotshell/modules/...` or `.../overlays/...`.

- [ ] **Step 3: Verify macOS overlay applied**

```bash
ls -la ~/.zsh/env.macos.sh
```

Should be a symlink into `overlays/darwin/zsh/`.

- [ ] **Step 4: Open a new terminal and verify zsh loads correctly**

Open a new terminal tab/window. Verify:
- Prompt loads (powerlevel10k)
- `echo $HOMEBREW_PREFIX` returns `/opt/homebrew`
- `echo $EDITOR` returns `vim`
- Aliases work (`c` clears screen)

- [ ] **Step 5: Commit any final adjustments**

```bash
git add -A
git commit -m "Final adjustments from integration testing"
```
