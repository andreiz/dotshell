# Recover the macOS login-session ssh-agent socket when it's missing or stale.
# Shells spawned by the wezterm mux server (`wezterm connect wick`) don't inherit
# SSH_AUTH_SOCK from the GUI login session, so ssh/git silently lose the agent.
# launchd still knows the live socket (path changes per login) — ask it.
if [[ -z "$SSH_AUTH_SOCK" || ! -S "$SSH_AUTH_SOCK" ]]; then
  _sock=$(launchctl asuser "$(id -u)" launchctl getenv SSH_AUTH_SOCK 2>/dev/null)
  [[ -n "$_sock" && -S "$_sock" ]] && export SSH_AUTH_SOCK="$_sock"
  unset _sock
fi
