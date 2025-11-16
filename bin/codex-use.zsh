# Compatibility wrapper for codex-use -> codex-switch
# This file provides backward compatibility for existing users

# Load the main codex-switch function
if [[ -f "$HOME/.codex-tools/bin/codex-switch.zsh" ]]; then
  source "$HOME/.codex-tools/bin/codex-switch.zsh"
fi

# Define codex-use as an alias for codex-switch
codex-use() {
  codex-switch "$@"
}

# Set up completion for codex-use as well
if (( $+functions[compdef] )); then
  compdef _cx_zsh_complete codex-use
fi
