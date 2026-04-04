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
