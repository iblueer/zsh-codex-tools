#!/usr/bin/env bash
# 本地离线安装脚本 - 用于无法访问GitHub的服务器
# 使用方式：
#   1. 将整个项目目录打包上传到服务器
#   2. 解压后进入项目目录
#   3. 执行: ./install_locally.sh
#
# Debug trace: CODEX_TOOLS_DEBUG=1 ./install_locally.sh
set -eu
[ "${CODEX_TOOLS_DEBUG:-0}" = "1" ] && set -x

on_err() {
  code=$?
  echo "✗ 安装失败 (exit=$code)。可能是权限/文件系统问题。" >&2
  exit "$code"
}
trap 'on_err' ERR

echo ">>> 开始本地安装 codex-use ..."

# 获取脚本所在目录(即项目源码目录)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
echo "[Info] 项目源码目录: $SCRIPT_DIR"

# 检查必要文件是否存在
if [ ! -f "$SCRIPT_DIR/bin/codex-use.zsh" ] || \
   [ ! -f "$SCRIPT_DIR/bin/codex-use.bash" ] || \
   [ ! -f "$SCRIPT_DIR/completions/_codex-use" ]; then
  echo "✗ 错误: 项目源码不完整,请确认以下文件存在:" >&2
  echo "  - bin/codex-use.zsh" >&2
  echo "  - bin/codex-use.bash" >&2
  echo "  - completions/_codex-use" >&2
  exit 1
fi

INSTALL_ROOT="$HOME/.codex-tools"
BIN_DIR="$INSTALL_ROOT/bin"
COMP_DIR="$INSTALL_ROOT/completions"
SHELL_NAME="$(basename "${CODEX_TOOLS_SHELL:-${SHELL:-}}")"
case "$SHELL_NAME" in
  bash) INIT_FILE="$INSTALL_ROOT/init.bash" ;;
  *) SHELL_NAME=zsh; INIT_FILE="$INSTALL_ROOT/init.zsh" ;;
esac

PROJECT_ID="${CODEX_PROJECT_ID:-iblueer/zsh-codex-tools}"
BEGIN_MARK="# >>> ${PROJECT_ID} BEGIN (managed) >>>"
END_MARK="# <<< ${PROJECT_ID} END   <<<"

echo "[Step 0] 初始化目录：$INSTALL_ROOT"
mkdir -p "$BIN_DIR" "$COMP_DIR"

# 从本地复制文件而非下载
echo "[Step 1] 复制脚本文件到 $BIN_DIR"
cp -f "$SCRIPT_DIR/bin/codex-use.zsh" "$BIN_DIR/codex-use.zsh"
cp -f "$SCRIPT_DIR/bin/codex-use.bash" "$BIN_DIR/codex-use.bash"
echo "[Step 1] 复制补全文件到 $COMP_DIR"
cp -f "$SCRIPT_DIR/completions/_codex-use" "$COMP_DIR/_codex-use"

: "${CODEX_HOME:="$HOME/.codex"}"
ENV_DIR="$CODEX_HOME/envs"
CONFIG_FILE="$CODEX_HOME/config.toml"
AUTH_FILE="$CODEX_HOME/auth.json"

echo "[Step 2] 准备环境目录：$ENV_DIR"
mkdir -p "$ENV_DIR"

DEFAULT_ENV="$ENV_DIR/default.env"
if [ ! -f "$DEFAULT_ENV" ]; then
  echo "[Step 2] 写入默认环境文件：$DEFAULT_ENV"
  cat >"$DEFAULT_ENV" <<'E'
# Codex CLI 环境模板：请按需修改
export CODEX_MODEL="gpt-5-codex"
export CODEX_MODEL_PROVIDER="anyrouter"
export CODEX_PREFERRED_AUTH_METHOD="apikey"
export CODEX_PROVIDER_NAME="Any Router"
export CODEX_PROVIDER_BASE_URL="https://anyrouter.top/v1"
export CODEX_PROVIDER_WIRE_API="responses"

# 常见 API 凭据（按需填写）
# export OPENAI_API_KEY=""
# export ANYROUTER_API_KEY=""
# export ANTHROPIC_AUTH_TOKEN=""
E
  chmod 600 "$DEFAULT_ENV" 2>/dev/null || true
fi

if [ ! -f "$CONFIG_FILE" ]; then
  echo "[Step 2] 写入示例 config：$CONFIG_FILE"
  cat >"$CONFIG_FILE" <<'C'
model = "gpt-5-codex"
model_provider = "anyrouter"
preferred_auth_method = "apikey"

[model_providers.anyrouter]
name = "Any Router"
base_url = "https://anyrouter.top/v1"
wire_api = "responses"
C
fi

if [ ! -f "$AUTH_FILE" ]; then
  echo "[Step 2] 写入示例 auth：$AUTH_FILE"
  cat >"$AUTH_FILE" <<'A'
{
  "OPENAI_API_KEY": "在此填写你的 KEY"
}
A
  chmod 600 "$AUTH_FILE" 2>/dev/null || true
fi

if [ "$SHELL_NAME" = "bash" ]; then
  echo "[Step 3] 生成 init：$INIT_FILE"
  cat >"$INIT_FILE" <<'EINIT'
# zsh-codex-tools init for bash (auto-generated)
: ${CODEX_HOME:="$HOME/.codex"}
if [ -f "$HOME/.codex-tools/bin/codex-use.bash" ]; then
  . "$HOME/.codex-tools/bin/codex-use.bash"
fi
EINIT
else
  echo "[Step 3] 生成 init：$INIT_FILE"
  cat >"$INIT_FILE" <<'EINIT'
# zsh-codex-tools init (auto-generated)
# 幂等：尽量避免重复影响用户环境

: ${CODEX_HOME:="$HOME/.codex"}

case ":$fpath:" in
  *":$HOME/.codex-tools/completions:"*) ;;
  *) fpath+=("$HOME/.codex-tools/completions");;
esac

case "$-" in
  *i*)
    if [ -f "$HOME/.codex-tools/bin/codex-use.zsh" ]; then
      . "$HOME/.codex-tools/bin/codex-use.zsh"
    fi
    ;;
esac

if ! typeset -f _main_complete >/dev/null 2>&1; then
  autoload -Uz compinit
  compinit
fi
EINIT
fi

if [ "$SHELL_NAME" = "bash" ]; then
  RC="$HOME/.bashrc"
  echo "[Step 4] 更新 Bash 配置：$RC （标记：$PROJECT_ID ）"
else
  if [ -n "${ZDOTDIR:-}" ]; then
    RC="$ZDOTDIR/.zshrc"
  else
    RC="$HOME/.zshrc"
  fi
  echo "[Step 4] 更新 Zsh 配置：$RC （标记：$PROJECT_ID ）"
fi

[ -f "$RC" ] || : >"$RC"

TMP_RC="$(mktemp)"
awk -v begin="$BEGIN_MARK" -v end="$END_MARK" '
  BEGIN { skip=0 }
  $0 == begin { skip=1; next }
  $0 == end   { skip=0; next }
  skip==0 { print }
' "$RC" >"$TMP_RC"

{
  printf "%s\n" "$BEGIN_MARK"
  if [ "$SHELL_NAME" = "bash" ]; then
    printf '%s\n' 'source "$HOME/.codex-tools/init.bash"'
  else
    printf '%s\n' 'source "$HOME/.codex-tools/init.zsh"'
  fi
  printf "%s\n" "$END_MARK"
} >>"$TMP_RC"

LC_ALL=C tail -c 1 "$TMP_RC" >/dev/null 2>&1 || printf '\n' >>"$TMP_RC"

mv "$TMP_RC" "$RC"

echo
echo ">>> 本地安装完成 🎉"
echo "安装目录：$INSTALL_ROOT"
echo "环境目录：$ENV_DIR"
echo "配置文件：$CONFIG_FILE"
echo "授权文件：$AUTH_FILE"
echo
echo "请执行： source \"$RC\""
echo "然后运行： codex-use list"
