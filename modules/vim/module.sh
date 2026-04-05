#!/usr/bin/env bash

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

    local opt_dir="$HOME/.vim/pack/plugins/opt"
    local start_dir="$HOME/.vim/pack/plugins/start"
    mkdir -p "$opt_dir" "$start_dir"

    if [[ ! -d "$opt_dir/everforest" ]]; then
        info "Installing everforest..."
        git clone --depth 1 https://github.com/sainnhe/everforest "$opt_dir/everforest"
    fi

    if [[ ! -d "$start_dir/vim-airline" ]]; then
        info "Installing vim-airline..."
        git clone --depth 1 https://github.com/vim-airline/vim-airline "$start_dir/vim-airline"
    fi

    if [[ ! -d "$start_dir/vim-airline-themes" ]]; then
        info "Installing vim-airline-themes..."
        git clone --depth 1 https://github.com/vim-airline/vim-airline-themes "$start_dir/vim-airline-themes"
    fi
}
