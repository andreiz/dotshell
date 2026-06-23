#!/usr/bin/env bash
#
# 1. Build AgentRunner.app (compiled, ad-hoc-signed launcher) so macOS privacy
#    permissions attach to a stable bundle id (org.zmievski.agent-runner)
#    instead of to /bin/bash. The FIRST time an agent touches a protected
#    folder, macOS prompts (e.g. "AgentRunner wants to access your Downloads
#    folder") — click Allow. The grant is keyed to the bundle id, so every
#    agent routed through the runner inherits it (no per-script grant). Manage
#    it under: System Settings > Privacy & Security > Files and Folders.
# 2. Symlink every agents/*.plist into ~/Library/LaunchAgents and (re)load it
#    with the modern launchctl API. Safe to re-run.
#
# Teardown a single agent manually with:
#     launchctl bootout gui/$(id -u)/<label>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNNER_SRC="$SCRIPT_DIR/runner"
APP="$SCRIPT_DIR/AgentRunner.app"
APP_BIN="$APP/Contents/MacOS/runner"
LAUNCH_AGENTS="$HOME/Library/LaunchAgents"
DOMAIN="gui/$(id -u)"
BUNDLE_ID="org.zmievski.agent-runner"

build_runner() {
    # Rebuild only when the binary is missing or older than its sources, so the
    # code signature (and therefore the FDA grant) stays stable across re-runs.
    if [[ -x "$APP_BIN" \
          && "$APP_BIN" -nt "$RUNNER_SRC/runner.c" \
          && "$APP/Contents/Info.plist" -nt "$RUNNER_SRC/Info.plist" ]]; then
        echo "AgentRunner.app up to date"
        return
    fi

    echo "building AgentRunner.app..."
    mkdir -p "$APP/Contents/MacOS"
    cp "$RUNNER_SRC/Info.plist" "$APP/Contents/Info.plist"
    clang -O2 -Wall -o "$APP_BIN" "$RUNNER_SRC/runner.c"
    # Ad-hoc sign the whole bundle with a stable identifier == bundle id.
    codesign --force --sign - --identifier "$BUNDLE_ID" "$APP"
    echo "  signed $APP"
    echo "  -> if the binary changed, re-confirm Full Disk Access for AgentRunner.app"
}

load_agents() {
    mkdir -p "$LAUNCH_AGENTS"
    shopt -s nullglob
    for plist in "$SCRIPT_DIR/agents"/*.plist; do
        name="$(basename "$plist")"
        label="${name%.plist}"
        target="$LAUNCH_AGENTS/$name"

        ln -sf "$plist" "$target"           # idempotent symlink -> repo copy
        launchctl bootout "$DOMAIN/$label" 2>/dev/null || true
        launchctl bootstrap "$DOMAIN" "$target"
        echo "loaded $label"
    done
}

build_runner
load_agents
