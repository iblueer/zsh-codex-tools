#!/usr/bin/env bash
# Codex CLI environment/profile management tool for Bash / Git Bash
# 配置项：
#   CODEX_HOME             默认 $HOME/.codex       => 环境目录位于 $CODEX_HOME/envs
#   CODEX_USE_EDITOR_CMD   自定义编辑器命令（优先级最高），例如：export CODEX_USE_EDITOR_CMD="code -w"
#   CODEX_CHATGPT_MODEL    切换 chatgpt 时使用的默认模型（默认 gpt-4o-mini）

: "${CODEX_HOME:="$HOME/.codex"}"
CODEX_USE_HOME="$CODEX_HOME"
CODEX_USE_ENV_DIR="$CODEX_USE_HOME/envs"
CODEX_USE_LAST="$CODEX_USE_HOME/last_choice"
CODEX_USE_CONFIG="$CODEX_USE_HOME/config.toml"
CODEX_USE_AUTH="$CODEX_USE_HOME/auth.json"

_cx_info() { printf '▸ %s\n' "$*"; }
_cx_warn() { printf '⚠ %s\n' "$*"; }
_cx_err()  { printf '✗ %s\n' "$*"; }
_cx_ok()   { printf '✓ %s\n' "$*"; }

_cx_is_windows() {
  case "${OSTYPE:-}" in
    cygwin*|msys*|win32*|mingw*) return 0 ;;
    *) return 1 ;;
  esac
}

_cx_with_spinner() {
  local msg="$1"; shift
  printf "%s
" "$msg"
  "$@"
  return $?
}

_cx_ensure_home() {
  [ -d "$CODEX_USE_HOME" ] || mkdir -p "$CODEX_USE_HOME"
  [ -d "$CODEX_USE_ENV_DIR" ] || mkdir -p "$CODEX_USE_ENV_DIR"
}

_cx_list_names() {
  _cx_ensure_home
  local f
  shopt -s nullglob >/dev/null 2>&1 || true
  for f in "$CODEX_USE_ENV_DIR"/*.env; do
    [ -e "$f" ] || continue
    f="$(basename "${f%.env}")"
    printf '%s\n' "$f"
  done
  shopt -u nullglob >/dev/null 2>&1 || true
}

_cx_validate_env_name() {
  local name="$1"
  if [ -z "$name" ]; then
    _cx_err "名称不能为空"
    return 1
  fi
  case "$name" in
    */*) _cx_err "名称不能包含路径分隔符"; return 1 ;;
  esac
  case "$name" in
    *[cC][hH][aA][tT][gG][pP][tT]*)
      _cx_err "环境名称不得包含 chatgpt（保留给浏览器登录模式）"
      return 1
      ;;
  esac
  return 0
}

_cx_open_path() {
  local path="$1"
  if _cx_is_windows; then
    local winpath="$path"
    if command -v cygpath >/dev/null 2>&1; then
      winpath="$(cygpath -w "$path")"
    fi
    if [ -d "$path" ]; then
      if command -v code >/dev/null 2>&1; then code -w "$winpath" && return 0; fi
      if command -v explorer.exe >/dev/null 2>&1; then explorer.exe "$winpath" && return 0; fi
    else
      if command -v code >/dev/null 2>&1; then code -w "$winpath" && return 0; fi
      if command -v notepad.exe >/dev/null 2>&1; then notepad.exe "$winpath" && return 0; fi
    fi
    if command -v cmd.exe >/dev/null 2>&1; then
      cmd.exe /c start "" "$winpath" >/dev/null 2>&1 && return 0
    fi
    _cx_warn "请手动打开：$path"
    return 0
  fi
  if [ -n "${CODEX_USE_EDITOR_CMD:-}" ]; then
    if eval "$CODEX_USE_EDITOR_CMD \"$path\""; then
      return 0
    else
      _cx_warn "自定义编辑器命令失败：$CODEX_USE_EDITOR_CMD"
    fi
  fi
  if [ -d "$path" ]; then
    if command -v code >/dev/null 2>&1; then code -w "$path" && return 0; fi
    if command -v code-insiders >/dev/null 2>&1; then code-insiders -w "$path" && return 0; fi
    if command -v open >/dev/null 2>&1; then open -a "Visual Studio Code" "$path" && return 0; fi
    if command -v subl >/dev/null 2>&1; then subl -w "$path" && return 0; fi
    if command -v xdg-open >/dev/null 2>&1; then xdg-open "$path" && return 0; fi
    if [ -n "${VISUAL:-}" ]; then "$VISUAL" "$path" && return 0; fi
    if [ -n "${EDITOR:-}" ]; then "$EDITOR" "$path" && return 0; fi
    if command -v vim >/dev/null 2>&1; then vim "$path" && return 0; fi
    if command -v nvim >/dev/null 2>&1; then nvim "$path" && return 0; fi
    _cx_warn "请手动打开：$path"
    return 0
  fi
  if [ -n "${VISUAL:-}" ]; then "$VISUAL" "$path" && return 0; fi
  if [ -n "${EDITOR:-}" ]; then "$EDITOR" "$path" && return 0; fi
  if command -v code >/dev/null 2>&1; then code -w "$path" && return 0; fi
  if command -v code-insiders >/dev/null 2>&1; then code-insiders -w "$path" && return 0; fi
  if command -v open >/dev/null 2>&1; then open -a "Visual Studio Code" "$path" && return 0; fi
  if command -v gedit >/dev/null 2>&1; then gedit --wait "$path" && return 0; fi
  if command -v vim >/dev/null 2>&1; then vim "$path" && return 0; fi
  if command -v nvim >/dev/null 2>&1; then nvim "$path" && return 0; fi
  if command -v nano >/dev/null 2>&1; then nano "$path" && return 0; fi
  if command -v subl >/dev/null 2>&1; then subl -w "$path" && return 0; fi
  if command -v open >/dev/null 2>&1; then open "$path" && return 0; fi
  if command -v xdg-open >/dev/null 2>&1; then xdg-open "$path" && return 0; fi
  _cx_warn "请手动打开：$path"
}

_cx_unset_matching() {
  local prefix="$1"
  while IFS= read -r name; do
    unset "$name"
  done < <(compgen -v | grep -E "^${prefix}")
}

_cx_purge_api_env() {
  local names=(
    CODEX_MODEL CODEX_MODEL_PROVIDER CODEX_PREFERRED_AUTH_METHOD CODEX_PROVIDER_SECTION
    CODEX_PROVIDER_NAME CODEX_PROVIDER_BASE_URL CODEX_PROVIDER_WIRE_API CODEX_PROVIDER_HEADERS_JSON
    CODEX_CONFIG_TOML CODEX_AUTH_JSON CODEX_AUTH_FIELDS CODEX_AUTH_PREFIXES CODEX_AUTH_SUPPRESS
    CODEX_ACTIVE_PROFILE CODEX_ENV_NOTE CODEX_ENV_DESCRIPTION
    OPENAI_API_KEY OPENAI_BASE_URL OPENAI_ORG_ID OPENAI_PROJECT_ID OPENAI_API_TYPE
    ANYROUTER_API_KEY ANYROUTER_TOKEN
    ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN
    AZURE_OPENAI_KEY AZURE_OPENAI_ENDPOINT AZURE_OPENAI_DEPLOYMENT
    DEEPINFRA_API_KEY
    FIREWORKS_API_KEY
    GOOGLE_API_KEY GOOGLE_APPLICATION_CREDENTIALS
    GROQ_API_KEY
    MISTRAL_API_KEY
    MOONSHOT_API_KEY
    NOVITA_API_KEY
    OPENROUTER_API_KEY
    REPLICATE_API_TOKEN
    TOGETHER_API_KEY
    ZHIPUAI_API_KEY ZHIPU_API_KEY
  )
  local var
  for var in "${names[@]}"; do unset "$var"; done
  _cx_unset_matching "ANTHROPIC_"
  _cx_unset_matching "MISTRAL_"
  _cx_unset_matching "GOOGLE_"
  _cx_unset_matching "GROQ_"
  _cx_unset_matching "FIREWORKS_"
}

_cx_source_env() {
  local file="$1"
  if [ ! -f "$file" ]; then
    _cx_err "未找到环境文件：$file"
    return 1
  fi
  _cx_purge_api_env
  set -a
  # shellcheck disable=SC1090
  . "$file"
  set +a
}

_cx_collect_auth_fields() {
  if [ -n "${CODEX_AUTH_FIELDS:-}" ]; then
    printf '%s\n' ${CODEX_AUTH_FIELDS}
    return 0
  fi
  if [ -n "${CODEX_AUTH_PREFIXES:-}" ]; then
    local prefix
    for prefix in ${CODEX_AUTH_PREFIXES}; do
      compgen -v | grep -E "^${prefix}" || true
    done
    return 0
  fi
  cat <<'EOF'
OPENAI_API_KEY
OPENAI_BASE_URL
OPENAI_ORG_ID
OPENAI_PROJECT_ID
ANYROUTER_API_KEY
ANYROUTER_TOKEN
ANTHROPIC_API_KEY
ANTHROPIC_AUTH_TOKEN
AZURE_OPENAI_KEY
AZURE_OPENAI_ENDPOINT
AZURE_OPENAI_DEPLOYMENT
DEEPINFRA_API_KEY
FIREWORKS_API_KEY
GOOGLE_API_KEY
GROQ_API_KEY
MISTRAL_API_KEY
MOONSHOT_API_KEY
NOVITA_API_KEY
OPENROUTER_API_KEY
REPLICATE_API_TOKEN
TOGETHER_API_KEY
ZHIPUAI_API_KEY
ZHIPU_API_KEY
EOF
}

_cx_write_auth() {
  _cx_ensure_home
  if [ "${CODEX_AUTH_SUPPRESS:-0}" = 1 ]; then
    return 0
  fi
  local tmp
  if [ -n "${CODEX_AUTH_JSON:-}" ]; then
    tmp="$(mktemp)"
    printf '%s
' "$CODEX_AUTH_JSON" >"$tmp"
    mv "$tmp" "$CODEX_USE_AUTH"
    chmod 600 "$CODEX_USE_AUTH" 2>/dev/null || true
    return 0
  fi
  local -a items=()
  while IFS= read -r key; do
    [ -z "$key" ] && continue
    if [ -n "${!key:-}" ]; then
      items+=("$key")
    fi
  done < <(_cx_collect_auth_fields)
  tmp="$(mktemp)"
  python3 - "$tmp" "${items[@]}" <<'PY'
import json, os, sys
outfile = sys.argv[1]
keys = sys.argv[2:]
data = {k: os.environ[k] for k in keys if k in os.environ}
with open(outfile, "w", encoding="utf-8") as fh:
    json.dump(data, fh, ensure_ascii=False, indent=2)
PY
  mv "$tmp" "$CODEX_USE_AUTH"
  chmod 600 "$CODEX_USE_AUTH" 2>/dev/null || true
}

_cx_build_config_content() {
  if [ -n "${CODEX_CONFIG_TOML:-}" ]; then
    printf '%s\n' "$CODEX_CONFIG_TOML"
    return 0
  fi
  local model="${CODEX_MODEL:-gpt-5-codex}"
  local provider="${CODEX_MODEL_PROVIDER:-anyrouter}"
  local preferred="${CODEX_PREFERRED_AUTH_METHOD:-apikey}"
  local provider_name="${CODEX_PROVIDER_NAME:-$provider}"
  local provider_section="${CODEX_PROVIDER_SECTION:-}"
  local base_url="${CODEX_PROVIDER_BASE_URL:-https://anyrouter.top/v1}"
  local wire_api="${CODEX_PROVIDER_WIRE_API:-responses}"
  if [ -z "$provider_section" ]; then
    provider_section=$(cat <<EOF
name = "$provider_name"
base_url = "$base_url"
wire_api = "$wire_api"
EOF
    )
  fi
  printf 'model = "%s"\n' "$model"
  printf 'model_provider = "%s"\n' "$provider"
  printf 'preferred_auth_method = "%s"\n' "$preferred"
  printf '\n[model_providers.%s]\n' "$provider"
  printf '%s\n' "$provider_section"
}

_cx_write_config() {
  _cx_ensure_home
  local tmp="$(mktemp)"
  _cx_build_config_content >"$tmp"
  mv "$tmp" "$CODEX_USE_CONFIG"
}

_cx_apply_profile() {
  _cx_write_config || return 1
  _cx_write_auth || return 1
}

_cx_cmd_show() {
  if [ -f "$CODEX_USE_LAST" ]; then
    _cx_info "上次记忆：$(<"$CODEX_USE_LAST")"
  else
    _cx_info "暂无记忆的默认环境"
  fi
  if [ "${CODEX_ACTIVE_PROFILE:-}" = chatgpt ]; then
    printf '当前运行在 chatgpt 浏览器模式\n'
    printf '  %-28s = %s\n' preferred_auth_method 'chatgpt (browser)'
    printf '  %-28s = %s\n' model "${CODEX_CHATGPT_MODEL:-gpt-4o-mini}"
    return 0
  fi
  printf '当前生效变量：\n'
  printf '  %-28s = %s\n' CODEX_MODEL "${CODEX_MODEL:-<未设置>}"
  printf '  %-28s = %s\n' CODEX_MODEL_PROVIDER "${CODEX_MODEL_PROVIDER:-<未设置>}"
  printf '  %-28s = %s\n' CODEX_PREFERRED_AUTH_METHOD "${CODEX_PREFERRED_AUTH_METHOD:-<未设置>}"
  printf '  %-28s = %s\n' OPENAI_API_KEY "${OPENAI_API_KEY:+<已设置>}"
  printf '  %-28s = %s\n' ANTHROPIC_AUTH_TOKEN "${ANTHROPIC_AUTH_TOKEN:+<已设置>}"
  printf '  %-28s = %s\n' ANYROUTER_API_KEY "${ANYROUTER_API_KEY:+<已设置>}"
}

_cx_cmd_list() {
  _cx_ensure_home
  local saved=""
  [ -f "$CODEX_USE_LAST" ] && saved="$(<"$CODEX_USE_LAST")"
  local -a names=()
  while IFS= read -r n; do
    [ -z "$n" ] && continue
    names+=("$n")
  done < <(_cx_list_names)
  printf '可用环境配置（%s）：\n' "$CODEX_USE_ENV_DIR"
  if [ ${#names[@]} -eq 0 ]; then
    printf '  （空）可添加 *.env 文件\n'
  fi
  local n
  for n in "${names[@]}"; do
    if [ "$n" = "$saved" ]; then
      printf '  * %s  (默认)\n' "$n"
    else
      printf '    %s\n' "$n"
    fi
  done
  if [ "$saved" = chatgpt ]; then
    printf '  * chatgpt  (默认, 浏览器模式)\n'
  else
    printf '    chatgpt  (浏览器模式，可通过 codex-use chatgpt 切换)\n'
  fi
}

_cx_template() {
  cat <<'T'
# Codex CLI 环境模板：请按需修改
export CODEX_MODEL="gpt-5-codex"
export CODEX_MODEL_PROVIDER="anyrouter"
export CODEX_PREFERRED_AUTH_METHOD="apikey"
export CODEX_PROVIDER_NAME="Any Router"
export CODEX_PROVIDER_BASE_URL="https://anyrouter.top/v1"
export CODEX_PROVIDER_WIRE_API="responses"

# 常见 API 凭据（按需填写）
export OPENAI_API_KEY=""
export ANYROUTER_API_KEY=""
export ANTHROPIC_AUTH_TOKEN=""

# 可选：指定写入 auth.json 的字段（空格分隔）
# export CODEX_AUTH_FIELDS="OPENAI_API_KEY ANYROUTER_API_KEY"

# 可选：完全自定义 config.toml 内容
# export CODEX_CONFIG_TOML='model = "gpt-5-codex"\nmodel_provider = "anyrouter"\npreferred_auth_method = "apikey"\n[model_providers.anyrouter]\nname = "Any Router"\nbase_url = "https://anyrouter.top/v1"\nwire_api = "responses"'
T
}

_cx_cmd_new() {
  local name="$1"
  _cx_validate_env_name "$name" || return 1
  [[ "$name" == *.env ]] || name="$name.env"
  _cx_ensure_home
  local file="$CODEX_USE_ENV_DIR/$name"
  if [ -f "$file" ]; then
    _cx_err "已存在：$file"
    return 1
  fi
  _cx_template >"$file"
  chmod 600 "$file" 2>/dev/null || true
  _cx_ok "已创建：$file"
  _cx_open_path "$file"
}

_cx_cmd_edit() {
  local name="$1"
  _cx_validate_env_name "$name" || return 1
  [[ "$name" == *.env ]] || name="$name.env"
  _cx_ensure_home
  local file="$CODEX_USE_ENV_DIR/$name"
  if [ ! -f "$file" ]; then
    _cx_template >"$file"
    chmod 600 "$file" 2>/dev/null || true
    _cx_info "不存在，已创建模板：$file"
  fi
  _cx_open_path "$file"
}

_cx_cmd_del() {
  local name="$1"
  _cx_validate_env_name "$name" || return 1
  [[ "$name" == *.env ]] || name="$name.env"
  _cx_ensure_home
  local file="$CODEX_USE_ENV_DIR/$name"
  if [ ! -f "$file" ]; then
    _cx_err "未找到：$file"
    return 1
  fi
  printf '确认删除 %s ? 输入 yes 以继续：' "${name%.env}"
  local answer; read -r answer
  if [ "$answer" = yes ]; then
    rm -f -- "$file"
    _cx_ok "已删除：$file"
    if [ -f "$CODEX_USE_LAST" ] && [ "$(<"$CODEX_USE_LAST")" = "${name%.env}" ]; then
      rm -f -- "$CODEX_USE_LAST"
      _cx_info "已清理默认记忆"
    fi
  else
    _cx_info "已取消"
  fi
}

_cx_switch_env() {
  local name="$1"
  [[ "$name" == *.env ]] || name="$name.env"
  local file="$CODEX_USE_ENV_DIR/$name"
  if _cx_with_spinner "加载环境..." _cx_source_env "$file"; then
    if _cx_apply_profile; then
      local short="${name%.env}"
      printf '%s\n' "$short" >"$CODEX_USE_LAST"
      export CODEX_ACTIVE_PROFILE="$short"
      _cx_ok "已切换到环境：$short（已保存为默认）"
      _cx_cmd_show
    fi
  else
    return 1
  fi
}

_cx_switch_chatgpt() {
  _cx_purge_api_env
  export CODEX_ACTIVE_PROFILE="chatgpt"
  local model="${CODEX_CHATGPT_MODEL:-gpt-4o-mini}"
  local tmp="$(mktemp)"
  {
    printf 'model = "%s"\n' "$model"
    printf 'model_provider = "chatgpt"\n'
    printf 'preferred_auth_method = "chatgpt"\n'
    printf '\n[model_providers.chatgpt]\n'
    printf 'name = "ChatGPT Web"\n'
    printf 'auth_via_browser = true\n'
  } >"$tmp"
  mv "$tmp" "$CODEX_USE_CONFIG"

  local tmp_auth="$(mktemp)"
  python3 - "$CODEX_USE_AUTH" "$tmp_auth" <<'PY'
import json, os, sys

src, dst = sys.argv[1:3]
strip_keys = {
    "OPENAI_API_KEY", "OPENAI_BASE_URL", "OPENAI_ORG_ID", "OPENAI_PROJECT_ID", "OPENAI_API_TYPE",
    "ANYROUTER_API_KEY", "ANYROUTER_TOKEN",
    "ANTHROPIC_API_KEY", "ANTHROPIC_AUTH_TOKEN",
    "AZURE_OPENAI_KEY", "AZURE_OPENAI_ENDPOINT", "AZURE_OPENAI_DEPLOYMENT",
    "DEEPINFRA_API_KEY",
    "FIREWORKS_API_KEY",
    "GOOGLE_API_KEY", "GOOGLE_APPLICATION_CREDENTIALS",
    "GROQ_API_KEY",
    "MISTRAL_API_KEY",
    "MOONSHOT_API_KEY",
    "NOVITA_API_KEY",
    "OPENROUTER_API_KEY",
    "REPLICATE_API_TOKEN",
    "TOGETHER_API_KEY",
    "ZHIPUAI_API_KEY", "ZHIPU_API_KEY",
}

data = {}
if os.path.exists(src):
    try:
        with open(src, "r", encoding="utf-8") as fh:
            loaded = json.load(fh)
        if isinstance(loaded, dict):
            data = loaded
    except Exception:
        data = {}

for key in list(data.keys()):
    if key in strip_keys:
        data.pop(key, None)

data["mode"] = "browser"

with open(dst, "w", encoding="utf-8") as fh:
    json.dump(data, fh, ensure_ascii=False, indent=2)
    fh.write("\n")
PY
  mv "$tmp_auth" "$CODEX_USE_AUTH"
  chmod 600 "$CODEX_USE_AUTH" 2>/dev/null || true

  printf 'chatgpt\n' >"$CODEX_USE_LAST"
  _cx_ok "已切换到 ChatGPT 浏览器模式（已保存为默认）"
  _cx_cmd_show
  _cx_info "如需刷新登录，请执行：codex login --browser"
}

_cx_help() {
  cat <<H
用法：
  codex-use list                 列出全部环境（含 chatgpt 模式）
  codex-use <name>               切换到 <name> 环境（无需 .env 后缀）
  codex-use chatgpt              切换到 ChatGPT 浏览器登录模式
  codex-use new <name>           新建 <name>.env，并打开编辑器
  codex-use edit <name>          编辑 <name>.env（不存在则创建模板）
  codex-use del <name>           删除 <name>.env（需输入 yes 确认）
  codex-use show|current         显示已记忆的默认与当前变量
  codex-use open|dir             打开环境目录
  codex-use help                 显示本帮助

目录：
  环境目录：$CODEX_USE_ENV_DIR
  记忆文件：$CODEX_USE_LAST
  配置文件：$CODEX_USE_CONFIG
  授权文件：$CODEX_USE_AUTH

配置：
  CODEX_HOME             默认 $HOME/.codex
  CODEX_USE_EDITOR_CMD   自定义编辑命令（优先级最高）
  CODEX_CHATGPT_MODEL    ChatGPT 浏览器模式下使用的模型（默认 gpt-4o-mini）
H
}

codex-use() {
  local cmd="${1:-}"; shift 2>/dev/null || true
  case "$cmd" in
    ""|help|-h|--help)   _cx_help ;;
    list|ls)             _cx_cmd_list ;;
    chatgpt)             _cx_switch_chatgpt ;;
    new)                 _cx_cmd_new "$@" ;;
    edit)                _cx_cmd_edit "$@" ;;
    del|delete|rm)       _cx_cmd_del "$@" ;;
    show|current)        _cx_cmd_show ;;
    open|dir)            _cx_open_path "$CODEX_USE_ENV_DIR" ;;
    *)                   _cx_validate_env_name "$cmd" && _cx_switch_env "$cmd" ;;
  esac
}
