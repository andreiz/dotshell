#!/usr/bin/env bash

requires_os="darwin"
no_stow=true

post_install() {
    local marker
    marker="$(dotshell_state_dir)/macos-applied"

    # Run-once per machine: defaults.sh and login items should not be re-applied
    # on every `install`. Delete the marker file to force a re-run.
    if [[ -f "$marker" ]]; then
        substep "macOS setup already applied (delete ${marker} to re-run)"
        return 0
    fi

    info "Configuring macOS defaults"
    bash "${MODULE_DIR}/defaults.sh"

    info "Updating login items"
    osascript "${MODULE_DIR}/login_items.applescript"

    mkdir -p "$(dirname "$marker")"
    date > "$marker"
    success "macOS setup applied (marker: ${marker})"
}
