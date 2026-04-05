#!/usr/bin/env bash

post_install() {
    if ! command -v vim &>/dev/null; then
        if [[ "$DOTSHELL_OS" == "darwin" ]]; then
            info "Installing vim via Homebrew..."
            brew install vim
        elif [[ "$DOTSHELL_OS" == "linux" ]]; then
            info "Installing vim via apt..."
            sudo apt install -y vim-nox
        fi
    fi
}
