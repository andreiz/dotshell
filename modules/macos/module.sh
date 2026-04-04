#!/usr/bin/env bash

requires_os="darwin"
no_stow=true

post_install() {
    info "Configuring macOS defaults"
    bash "${MODULE_DIR}/defaults.sh"

    info "Updating login items"
    osascript "${MODULE_DIR}/login_items.applescript"
}
