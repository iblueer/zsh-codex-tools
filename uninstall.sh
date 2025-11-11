#!/bin/sh
# POSIX shell, supports: curl | sh
set -eu

echo ">>> 开始卸载 codex-use ..."

INSTALL_ROOT="$HOME/.codex-tools"
PROJECT_ID="${CODEX_PROJECT_ID:-iblueer/zsh-codex-tools}"
BEGIN_MARK="# >>> ${PROJECT_ID} BEGIN (managed) >>>"
END_MARK="# <<< ${PROJECT_ID} END   <<<"

case "$PWD" in
  "$INSTALL_ROOT"|"$INSTALL_ROOT"/*) cd "$HOME" ;;
esac

if [ -d "$INSTALL_ROOT" ]; then
  rm -rf "$INSTALL_ROOT"
  echo "✓ 已删除目录 $INSTALL_ROOT"
else
  echo "ℹ 未发现 $INSTALL_ROOT"
fi

remove_block() {
  file="$1"
  if [ -f "$file" ]; then
    tmp=$(mktemp 2>/dev/null || mktemp -t codex-uninstall)
    awk -v begin="$BEGIN_MARK" -v end="$END_MARK" '
      $0 == begin {skip=1; next}
      $0 == end {skip=0; next}
      skip==0 {print}
    ' "$file" >"$tmp"
    mv "$tmp" "$file"
    echo "✓ 已从 $file 移除 codex-tools 配置块"
  else
    echo "ℹ 未发现 $file"
  fi
}

remove_block "${ZDOTDIR:-$HOME}/.zshrc"
remove_block "$HOME/.bashrc"

echo
echo ">>> 卸载完成 🎉"
echo "提示：不会删除你的配置与凭据（默认在 ~/.codex）。如需彻底清理： rm -rf ~/.codex"
