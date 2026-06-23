#!/usr/bin/env bash
#
# 1. Build the runner bundles (compiled, ad-hoc-signed launchers from
#    runner/runner.c) so macOS privacy permissions attach to a stable bundle id
#    instead of to /bin/bash. Two bundles, one per privilege tier:
#      AgentRunner.app      org.zmievski.agent-runner       -> Downloads-scoped agents
#      AgentRunnerFDA.app   org.zmievski.agent-runner-fda   -> Full Disk Access agents
#    The FIRST time an agent touches a protected resource, macOS prompts (e.g.
#    "...wants to access your Downloads folder", or grant Full Disk Access to
#    AgentRunnerFDA.app under Privacy & Security). Grants are keyed to the
#    bundle id, so every agent routed through a bundle inherits its access.
# 2. Symlink every agents/*.plist into ~/Library/LaunchAgents and (re)load it
#    with the modern launchctl API. Safe to re-run.
#
# Teardown a single agent manually with:
#     launchctl bootout gui/$(id -u)/<label>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNNER_SRC="$SCRIPT_DIR/runner"
LAUNCH_AGENTS="$HOME/Library/LaunchAgents"
DOMAIN="gui/$(id -u)"

# build_bundle <app_dir> <bundle_id> <display_name>
# Rebuilds only when the binary is missing or older than its sources, so the
# code signature (and therefore the TCC grant) stays stable across re-runs.
build_bundle() {
    local app="$1" bid="$2" name="$3"
    local bin="$app/Contents/MacOS/runner"
    if [[ -x "$bin" \
          && "$bin" -nt "$RUNNER_SRC/runner.c" \
          && "$app/Contents/Info.plist" -nt "$RUNNER_SRC/Info.plist.in" ]]; then
        echo "$(basename "$app") up to date"
        return
    fi

    echo "building $(basename "$app") ($bid)..."
    mkdir -p "$app/Contents/MacOS"
    sed -e "s|@BUNDLE_ID@|$bid|g" -e "s|@NAME@|$name|g" \
        "$RUNNER_SRC/Info.plist.in" > "$app/Contents/Info.plist"
    clang -O2 -Wall -o "$bin" "$RUNNER_SRC/runner.c"
    codesign --force --sign - --identifier "$bid" "$app"
    echo "  signed $app"
    echo "  -> if the binary changed, re-confirm this bundle's privacy grant"
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

build_bundle "$SCRIPT_DIR/AgentRunner.app"    "org.zmievski.agent-runner"     "Launchd Agent Runner"
build_bundle "$SCRIPT_DIR/AgentRunnerFDA.app" "org.zmievski.agent-runner-fda" "Launchd Agent Runner (Full Disk)"
load_agents
