# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

ZSH_DISABLE_COMPFIX="true"

# Antigen — path differs per OS
if [[ -f /opt/homebrew/share/antigen/antigen.zsh ]]; then
    source /opt/homebrew/share/antigen/antigen.zsh
elif [[ -f /usr/share/zsh-antigen/antigen.zsh ]]; then
    source /usr/share/zsh-antigen/antigen.zsh
fi

antigen use oh-my-zsh

if [[ "$OSTYPE" == "darwin"* ]]; then
    antigen bundle brew
    antigen bundle macos
fi
antigen bundle command-not-found
antigen bundle common-aliases
antigen bundle git
antigen bundle git-extras
antigen bundle z
antigen bundle zsh-users/zsh-syntax-highlighting
antigen bundle zsh-users/zsh-history-substring-search ./zsh-history-substring-search.zsh

antigen theme romkatv/powerlevel10k

antigen apply

# Source interactive-only config from ~/.zsh/.
# Env fragments (env*.sh, ssh-agent*.sh) are loaded earlier by .zshenv so that
# non-interactive shells get them too — skip them here to avoid double-sourcing
# (re-running env.macos.sh would duplicate PATH and re-eval pyenv).
for f in ~/.zsh/*.sh; do
    case "${f:t}" in env.sh|env.*.sh|ssh-agent.*.sh) continue ;; esac
    [[ -f "$f" ]] && source "$f"
done

setopt nocaseglob
setopt correct

# /etc/zprofile runs path_helper between .zshenv and .zshrc, which shoves
# /usr/bin ahead of Homebrew. Re-prepend so brew-installed tools win.
[[ -d /opt/homebrew/bin ]] && export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Optional tool integrations (loaded if present)
[[ -f ~/.config/broot/launcher/zsh/br ]] && source ~/.config/broot/launcher/zsh/br
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

export NVM_DIR="$HOME/.nvm"
[ -s "${HOMEBREW_PREFIX:-}/opt/nvm/nvm.sh" ] && \. "${HOMEBREW_PREFIX:-}/opt/nvm/nvm.sh"
[ -s "${HOMEBREW_PREFIX:-}/opt/nvm/etc/bash_completion.d/nvm" ] && \. "${HOMEBREW_PREFIX:-}/opt/nvm/etc/bash_completion.d/nvm"
