#!/usr/bin/env bash

# Declarative plugin list — single source of truth for install AND update.
# Format: "<start|opt>/<dir>|<repo-url>"
#   start/  loads automatically; opt/ loads on demand via `packadd`.
# Add a plugin by adding one line here; both install and update read this.
vim_plugins=(
    "start/vim-airline|https://github.com/vim-airline/vim-airline"
    "start/vim-airline-themes|https://github.com/vim-airline/vim-airline-themes"
    "start/vim-polyglot|https://github.com/sheerun/vim-polyglot"
    "start/vim-fugitive|https://github.com/tpope/vim-fugitive"
    "start/vim-surround|https://github.com/tpope/vim-surround"
    "opt/everforest|https://github.com/sainnhe/everforest"
)

post_install() {
    if ! command -v vim &>/dev/null; then
        if [[ "$DOTSHELL_OS" == "darwin" ]]; then
            info "Installing vim via Homebrew..."
            brew install vim
        elif [[ "$DOTSHELL_OS" == "linux" ]]; then
            info "Installing vim-nox via apt..."
            sudo apt install -y vim-nox
        fi
    fi

    local pack_dir="$HOME/.vim/pack/plugins"
    mkdir -p "$pack_dir/start" "$pack_dir/opt"

    local entry path repo dir
    for entry in "${vim_plugins[@]}"; do
        path="${entry%%|*}"      # e.g. start/vim-airline
        repo="${entry#*|}"
        dir="$pack_dir/$path"
        if [[ -d "$dir/.git" ]]; then
            info "Updating ${path}..."
            git -C "$dir" pull --ff-only --quiet || info "  (skipped: ${path} has local changes)"
        else
            info "Installing ${path}..."
            git clone --depth 1 "$repo" "$dir"
        fi
    done
}
