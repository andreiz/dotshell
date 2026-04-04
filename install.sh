#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

usage() {
    echo "Usage: ./install.sh <module ...> | all | list"
    echo ""
    echo "Commands:"
    echo "  all           Install all modules (respecting OS restrictions)"
    echo "  list          Show available modules"
    echo "  <module ...>  Install specific modules"
    exit 1
}

# Check that stow is installed
check_dependencies() {
    if ! command -v stow &>/dev/null; then
        error "GNU Stow is not installed. Run bootstrap.sh first or install it manually."
        exit 1
    fi
}

# List all module directory names
list_modules() {
    local dir
    for dir in "${DOTSHELL_DIR}/modules"/*/; do
        [[ -d "$dir" ]] || continue
        basename "$dir"
    done
}

# Install a single module
install_module() {
    local module="$1"
    local module_dir="${DOTSHELL_DIR}/modules/${module}"

    if [[ ! -d "$module_dir" ]]; then
        error "Module '${module}' not found"
        return 1
    fi

    # Reset per-module variables
    local requires_os=""
    local no_stow=""

    # Source module.sh if it exists (sets requires_os, no_stow, defines post_install)
    unset -f post_install 2>/dev/null
    if [[ -f "${module_dir}/module.sh" ]]; then
        source "${module_dir}/module.sh"
    fi

    # Check OS restriction
    if [[ -n "$requires_os" && "$requires_os" != "$DOTSHELL_OS" ]]; then
        substep "Skipping '${module}' (requires ${requires_os}, running on ${DOTSHELL_OS})"
        return 0
    fi

    info "Installing module: ${module}"

    # Stow the module (unless no_stow is set)
    if [[ "$no_stow" != "true" ]]; then
        if stow -d "${DOTSHELL_DIR}/modules" -t "$HOME" --no-folding "$module"; then
            substep "Stowed ${module}"
        else
            error "Failed to stow ${module}"
            return 1
        fi
    fi

    # Apply OS overlay if it exists
    local overlay_dir="${DOTSHELL_DIR}/overlays/${DOTSHELL_OS}/${module}"
    if [[ -d "$overlay_dir" ]]; then
        if stow -d "${DOTSHELL_DIR}/overlays/${DOTSHELL_OS}" -t "$HOME" --no-folding "$module"; then
            substep "Applied ${DOTSHELL_OS} overlay for ${module}"
        else
            error "Failed to apply overlay for ${module}"
            return 1
        fi
    fi

    # Run post_install if defined
    local MODULE_DIR="$module_dir"
    export MODULE_DIR
    if declare -f post_install &>/dev/null; then
        substep "Running post-install for ${module}"
        post_install
    fi

    success "Module '${module}' installed"
}

# Main
[[ $# -eq 0 ]] && usage

check_dependencies

case "$1" in
    list)
        echo "Available modules:"
        for module in $(list_modules); do
            local_requires=""
            if [[ -f "${DOTSHELL_DIR}/modules/${module}/module.sh" ]]; then
                local_requires=$(grep -oP '(?<=requires_os=").*?(?=")' "${DOTSHELL_DIR}/modules/${module}/module.sh" 2>/dev/null || true)
            fi
            if [[ -n "$local_requires" ]]; then
                echo "  ${module} (${local_requires} only)"
            else
                echo "  ${module}"
            fi
        done
        ;;
    all)
        for module in $(list_modules); do
            install_module "$module"
        done
        ;;
    *)
        for module in "$@"; do
            install_module "$module"
        done
        ;;
esac
