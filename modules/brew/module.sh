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
    # `brew bundle cleanup` without --force is a dry run (lists only, removes
    # nothing) and returns exit 1 when anything would be removed, so `|| true`.
    local combined
    combined="$(mktemp)"
    cat "${files[@]}" > "$combined"
    substep "Installed but not in your Brewfile(s) — review (nothing removed):"
    brew bundle cleanup --file="$combined" || true
    rm -f "$combined"
}
