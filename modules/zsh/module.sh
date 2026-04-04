#!/usr/bin/env bash

post_install() {
    if [[ "$SHELL" != */zsh ]]; then
        info "Changing default shell to zsh"
        chsh -s "$(which zsh)"
    fi
}
