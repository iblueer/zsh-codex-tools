# Compatibility wrapper for codex-use -> codex-switch
# This file provides backward compatibility for existing users

# Load the main codex-switch function
if [ -f "$HOME/.codex-tools/bin/codex-switch.bash" ]; then
  source "$HOME/.codex-tools/bin/codex-switch.bash"
fi

# Define codex-use as an alias for codex-switch
codex-use() {
  codex-switch "$@"
}
