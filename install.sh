#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

BACKUP_SUFFIX=".$(date +%Y%m%d_%H%M%S).bak"
BACKED_UP=()

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

# Parse CLI args: separate module names from flags.
# Sets globals MODULES (array), DOTSHELL_EXTRA, DOTSHELL_FORCE_CASKS; exports the latter two.
parse_args() {
    MODULES=()
    DOTSHELL_EXTRA=""
    DOTSHELL_FORCE_CASKS=""
    local arg
    for arg in "$@"; do
        case "$arg" in
            --extra=*)     DOTSHELL_EXTRA="${arg#--extra=}" ;;
            --extra)       error "--extra requires a value, e.g. --extra=laptop"; exit 1 ;;
            --force-casks) DOTSHELL_FORCE_CASKS=1 ;;
            --*)           error "Unknown option: ${arg}"; exit 1 ;;
            *)             MODULES+=("$arg") ;;
        esac
    done
    export DOTSHELL_EXTRA DOTSHELL_FORCE_CASKS
}

# True (skip) only for optional modules invoked via the `all` loop.
should_skip_optional() {
    local context="$1" optional_flag="$2"
    [[ "$context" == "all" && "$optional_flag" == "true" ]]
}

# List all module directory names
list_modules() {
    local dir
    for dir in "${DOTSHELL_DIR}/modules"/*/; do
        [[ -d "$dir" ]] || continue
        basename "$dir"
    done
}

# Back up any real files that stow would overwrite
backup_existing() {
    local source_dir="$1"

    while IFS= read -r -d '' file; do
        local rel="${file#${source_dir}/}"
        local target="${HOME}/${rel}"
        if [[ -f "$target" && ! -L "$target" ]]; then
            mv "$target" "${target}${BACKUP_SUFFIX}"
            BACKED_UP+=("~/${rel}${BACKUP_SUFFIX}")
        fi
    done < <(find "$source_dir" -type f ! -name 'module.sh' -print0)
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
    local optional=""
    local context="${2:-explicit}"

    # Source module.sh if it exists (sets requires_os, no_stow, optional, defines post_install)
    unset -f post_install 2>/dev/null
    if [[ -f "${module_dir}/module.sh" ]]; then
        source "${module_dir}/module.sh"
    fi

    # Skip optional modules when running `all`; they must be invoked explicitly.
    if should_skip_optional "$context" "${optional:-}"; then
        substep "Skipping '${module}' (optional; run explicitly: ./install.sh ${module})"
        return 0
    fi

    # Check OS restriction
    if [[ -n "$requires_os" && "$requires_os" != "$DOTSHELL_OS" ]]; then
        substep "Skipping '${module}' (requires ${requires_os}, running on ${DOTSHELL_OS})"
        return 0
    fi

    info "Installing module: ${module}"

    # Stow the module (unless no_stow is set)
    if [[ "$no_stow" != "true" ]]; then
        backup_existing "${module_dir}"
        if stow -d "${DOTSHELL_DIR}/modules" -t "$HOME" --no-folding --ignore='module\.sh' "$module"; then
            substep "Stowed ${module}"
        else
            error "Failed to stow ${module}"
            return 1
        fi
    fi

    # Apply OS overlay if it exists
    local overlay_dir="${DOTSHELL_DIR}/overlays/${DOTSHELL_OS}/${module}"
    if [[ -d "$overlay_dir" ]]; then
        backup_existing "${overlay_dir}"
        if stow -d "${DOTSHELL_DIR}/overlays/${DOTSHELL_OS}" -t "$HOME" --no-folding --ignore='module\.sh' "$module"; then
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
main() {
    parse_args "$@"

    [[ ${#MODULES[@]} -eq 0 ]] && usage

    check_dependencies

    case "${MODULES[0]}" in
        list)
            echo "Available modules:"
            for module in $(list_modules); do
                local_requires=""
                local_optional=""
                if [[ -f "${DOTSHELL_DIR}/modules/${module}/module.sh" ]]; then
                    local_requires=$(grep -o 'requires_os="[^"]*"' "${DOTSHELL_DIR}/modules/${module}/module.sh" 2>/dev/null | cut -d'"' -f2 || true)
                    grep -q 'optional=true' "${DOTSHELL_DIR}/modules/${module}/module.sh" 2>/dev/null && local_optional="optional"
                fi
                local tags=""
                [[ -n "$local_requires" ]] && tags="${local_requires} only"
                [[ -n "$local_optional" ]] && tags="${tags:+${tags}, }optional"
                if [[ -n "$tags" ]]; then
                    echo "  ${module} (${tags})"
                else
                    echo "  ${module}"
                fi
            done
            ;;
        all)
            for module in $(list_modules); do
                install_module "$module" "all"
            done
            ;;
        *)
            for module in "${MODULES[@]}"; do
                install_module "$module" "explicit"
            done
            ;;
    esac

    if [[ ${#BACKED_UP[@]} -gt 0 ]]; then
        info "Backed up ${#BACKED_UP[@]} existing file(s):"
        for f in "${BACKED_UP[@]}"; do
            substep "$f"
        done
    fi
}

# Run main only when executed directly, not when sourced (enables tests).
# Use an `if` (not `&&`) so a false condition returns 0 and does not trip `set -e`
# when this file is sourced by the test suite.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
