# Sourced by EVERY zsh invocation — login/non-login, interactive or not, and
# scripts (`zsh -c`). .zshrc, by contrast, runs for interactive shells only.
#
# So anything a NON-interactive shell needs from the environment must live here,
# not in .zshrc. The tools that spawn non-interactive shells — the wezterm mux
# server (`wezterm connect wick`), Claude Code's Bash tool, cron — otherwise
# start with no Homebrew PATH, no XDG_CONFIG_HOME (tea needs it), and no
# SSH_AUTH_SOCK (ssh/git lose the agent).
#
# Load the env-class fragments; interactive-only config (prompt, aliases, fzf
# keybindings) stays in .zshrc. The (N) qualifier makes unmatched globs expand
# to nothing (the .macos.* fragments only exist where the darwin overlay stows).
for f in ~/.zsh/env.sh(N) ~/.zsh/env.*.sh(N) ~/.zsh/ssh-agent.*.sh(N); do
  [[ -f "$f" ]] && source "$f"
done
