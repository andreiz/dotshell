#!/usr/bin/env bash
set -euo pipefail

DOTSHELL_REPO="$HOME/projects/dotshell"
DOTSHELL_REMOTE="https://github.com/andreiz/dotshell.git"

info() {
    tput bold; tput setaf 4; echo "========> $1"; tput sgr0
}

error() {
    tput bold; tput setaf 1; echo "========> $1" >&2; tput sgr0
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
