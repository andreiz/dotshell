#!/usr/bin/env bash

[[ -n "${DOTSHELL_COMMON_LOADED:-}" ]] && return 0
DOTSHELL_COMMON_LOADED=1

# Detect OS: "darwin" or "linux"
detect_os() {
    uname -s | tr '[:upper:]' '[:lower:]'
}

DOTSHELL_OS="$(detect_os)"
DOTSHELL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Logging helpers (colored output)
info() {
    tput bold || true; tput setaf 4 || true
    echo "========> $1"
    tput sgr0 || true
}

substep() {
    tput bold || true; tput setaf 5 || true
    echo "==== $1"
    tput sgr0 || true
}

success() {
    tput bold || true; tput setaf 2 || true
    echo "========> $1"
    tput sgr0 || true
}

error() {
    tput bold || true; tput setaf 1 || true
    echo "========> $1" >&2
    tput sgr0 || true
}
