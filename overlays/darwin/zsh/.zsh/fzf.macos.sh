# macOS-specific FZF bindings
export FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS
--bind='ctrl-y:execute-silent(echo {+} | pbcopy)'"
