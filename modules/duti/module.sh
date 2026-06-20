#!/usr/bin/env bash

requires_os="darwin"
no_stow=true

post_install() {
    # duti is an optional dependency (installed via the brew module). Degrade
    # gracefully if it's absent rather than failing the install.
    if ! command -v duti &>/dev/null; then
        substep "duti not installed; skipping default-app associations"
        return 0
    fi

    info "Applying default-app associations (duti)"
    duti "${MODULE_DIR}/duti.conf"
    success "default-app associations applied"
}
