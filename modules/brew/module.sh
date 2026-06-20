#!/usr/bin/env bash

requires_os="darwin"
no_stow=true
optional=true

post_install() {
    local brewfile="${MODULE_DIR}/Brewfile"

    # Opt-in (--force-casks): pass --force to `brew bundle install` so casks
    # overwrite/adopt a pre-existing app at a different version. Off by default
    # (never overwrites apps unless asked). Scalar (not array) keeps it safe
    # under `set -u` on bash 3.2.
    local force_flag=""
    [[ -n "${DOTSHELL_FORCE_CASKS:-}" ]] && force_flag="--force"

    info "Installing base Brewfile packages"
    brew bundle install --file="$brewfile" ${force_flag}

    if [[ -n "${DOTSHELL_EXTRA:-}" ]]; then
        local extra_file="${MODULE_DIR}/Brewfile.${DOTSHELL_EXTRA}"
        if [[ ! -f "$extra_file" ]]; then
            error "No Brewfile for extra '${DOTSHELL_EXTRA}' (expected ${extra_file})"
            return 1
        fi
        info "Installing extra Brewfile: ${DOTSHELL_EXTRA}"
        brew bundle install --file="$extra_file" ${force_flag}
    fi

    # Drift check: compare installed packages against the UNION of ALL Brewfiles
    # (base + every Brewfile.*), independent of --extra — otherwise a base-only
    # run would flag packages tracked for another machine as removable. Report
    # quietly via a pointer; never remove anything (no --force, so it's a dry run
    # that exits 1 when drift exists).
    local state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/dotshell"
    local union="${state_dir}/brew-union.Brewfile"
    mkdir -p "$state_dir"
    cat "$brewfile" "${MODULE_DIR}"/Brewfile.* > "$union" 2>/dev/null

    if ! brew bundle cleanup --file="$union" >/dev/null 2>&1; then
        substep "Some installed packages aren't tracked in any Brewfile."
        substep "Review (nothing removed): brew bundle cleanup --file=${union}"
    fi
}
