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

    # Install vim-plug if not present
    local plug_path="$HOME/.vim/autoload/plug.vim"
    if [[ ! -f "$plug_path" ]]; then
        info "Installing vim-plug..."
        curl -fLo "$plug_path" --create-dirs \
            https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
    fi

    # Install plugins headlessly
    info "Installing vim plugins..."
    vim +PlugInstall +qall 2>/dev/null
}
