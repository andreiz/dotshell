#!/usr/bin/env bash

requires_os="darwin"

post_install() {
    if ! command -v wezterm &>/dev/null; then
        info "Installing WezTerm via Homebrew..."
        brew install --cask wezterm
    fi
}
