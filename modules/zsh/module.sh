#!/usr/bin/env bash

post_install() {
    # Install antigen if not present
    if [[ "$DOTSHELL_OS" == "darwin" ]]; then
        if ! brew list antigen &>/dev/null; then
            info "Installing antigen via Homebrew..."
            brew install antigen
        fi
    elif [[ "$DOTSHELL_OS" == "linux" ]]; then
        if [[ ! -f /usr/share/zsh-antigen/antigen.zsh ]]; then
            info "Installing antigen via apt..."
            sudo apt install -y zsh-antigen
        fi
    fi

    # Set zsh as default shell if needed
    if [[ "$SHELL" != */zsh ]]; then
        info "Changing default shell to zsh"
        chsh -s "$(which zsh)"
    fi
}
