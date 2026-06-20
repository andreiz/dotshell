#!/usr/bin/env bash

requires_os="darwin"
no_stow=true
optional=true

post_install() {
    local brewfile="${MODULE_DIR}/Brewfile"
    local files=("$brewfile")

    info "Installing base Brewfile packages"
    brew bundle install --file="$brewfile"

    if [[ -n "${DOTSHELL_EXTRA:-}" ]]; then
        local extra_file="${MODULE_DIR}/Brewfile.${DOTSHELL_EXTRA}"
        if [[ ! -f "$extra_file" ]]; then
            error "No Brewfile for extra '${DOTSHELL_EXTRA}' (expected ${extra_file})"
            return 1
        fi
        info "Installing extra Brewfile: ${DOTSHELL_EXTRA}"
        brew bundle install --file="$extra_file"
        files+=("$extra_file")
    fi

    # Drift report: list packages installed but not in the Brewfile(s).
    # Dry-run only — nothing is uninstalled.
    local combined
    combined="$(mktemp)"
    cat "${files[@]}" > "$combined"
    substep "Installed but not in your Brewfile(s) — review (nothing removed):"
    brew bundle cleanup --file="$combined" --dry-run || true
    rm -f "$combined"
}
