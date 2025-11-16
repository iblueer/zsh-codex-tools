#!/usr/bin/env zsh
# bin/codex-switch.zsh
# Codex CLI environment/profile management tool for Zsh
# 配置项：
#   CODEX_HOME             默认 $HOME/.codex       => 环境目录位于 $CODEX_HOME/envs
#   CODEX_USE_EDITOR_CMD   自定义编辑器命令（优先级最高），例如：export CODEX_USE_EDITOR_CMD="code -w"

: ${CODEX_HOME:="$HOME/.codex"}
typeset -g CODEX_USE_HOME="$CODEX_HOME"
typeset -g CODEX_USE_ENV_DIR="$CODEX_USE_HOME/envs"
typeset -g CODEX_USE_LAST="$CODEX_USE_HOME/last_choice"
typeset -g CODEX_USE_CONFIG="$CODEX_USE_HOME/config.toml"
typeset -g CODEX_USE_AUTH="$CODEX_USE_HOME/auth.json"
typeset -ga CODEX_SWITCH_SUBCOMMANDS=(help list ls use chatgpt new edit del show open)

_cx_info() { print -r -- "▸ $*"; }
_cx_warn() { print -r -- "⚠ $*"; }
_cx_err()  { print -r -- "✗ $*"; }
_cx_ok()   { print -r -- "✓ $*"; }

_cx_is_windows() {
  case "$OSTYPE" in
    cygwin*|msys*|win32*|mingw*) return 0 ;;
    *) return 1 ;;
  esac
}

_cx_with_spinner() {
  local msg="$1"; shift
  print -r -- "$msg"
  "$@"
  return $?
}

_cx_ensure_home() {
  [[ -d "$CODEX_USE_HOME" ]] || mkdir -p "$CODEX_USE_HOME"
  [[ -d "$CODEX_USE_ENV_DIR" ]] || mkdir -p "$CODEX_USE_ENV_DIR"
}

_cx_list_names() {
  _cx_ensure_home
  local f
  for f in "$CODEX_USE_ENV_DIR"/*.env(N); do
    print -r -- "${f:t:r}"
  done
}

_cx_env_candidates() {
  local cur="${1:-}"
  local prefix suffix search_dir entry base rel
  reply=()
  if [[ "$cur" == */* ]]; then
    prefix="${cur%/*}"
    suffix="${cur##*/}"
    search_dir="$CODEX_USE_ENV_DIR/$prefix"
  else
    prefix=""
    suffix="$cur"
    search_dir="$CODEX_USE_ENV_DIR"
  fi
  [[ -d "$search_dir" ]] || return
  local -a entries=()
  if command -v find >/dev/null 2>&1; then
    while IFS= read -r entry; do
      base="${entry##*/}"
      [[ "$base" == "$suffix"* ]] || continue
      if [[ -d "$entry" ]]; then
        rel="${prefix:+$prefix/}$base/"
      elif [[ "$entry" == *.env ]]; then
        rel="${prefix:+$prefix/}${base%.env}"
      else
        continue
      fi
      [[ "${rel:l}" == *chatgpt* ]] && continue
      entries+=("$rel")
    done < <(LC_ALL=C find "$search_dir" -mindepth 1 -maxdepth 1 \( -type d -o -type f -name '*.env' \) -print 2>/dev/null | LC_ALL=C sort)
  else
    for entry in "$search_dir"/*; do
      [[ -e "$entry" ]] || continue
      base="${entry##*/}"
      [[ "$base" == "$suffix"* ]] || continue
      if [[ -d "$entry" ]]; then
        rel="${prefix:+$prefix/}$base/"
      elif [[ "$entry" == *.env ]]; then
        rel="${prefix:+$prefix/}${base%.env}"
      else
        continue
      fi
      [[ "${rel:l}" == *chatgpt* ]] && continue
      entries+=("$rel")
    done
  fi
  (( ${#entries[@]} > 0 )) && reply=(${(ou)entries})
}

_cx_validate_env_name() {
  local name="$1"
  if [[ -z "$name" ]]; then
    _cx_err "名称不能为空"
    return 1
  fi
  if [[ "$name" == */* ]]; then
    _cx_err "名称不能包含路径分隔符"
    return 1
  fi
  if [[ "${name:l}" == *chatgpt* ]]; then
    _cx_err "环境名称不得包含 chatgpt（保留给浏览器登录模式）"
    return 1
  fi
  return 0
}

_cx_open_path() {
  local file_path="$1"
  if _cx_is_windows; then
    local winpath="$file_path"
    if command -v cygpath >/dev/null 2>&1; then
      winpath="$(cygpath -w "$file_path")"
    fi
    if [[ -d "$file_path" ]]; then
      if command -v code >/dev/null 2>&1; then code -w "$winpath" && return 0; fi
      if command -v explorer.exe >/dev/null 2>&1; then explorer.exe "$winpath" && return 0; fi
    else
      if command -v code >/dev/null 2>&1; then code -w "$winpath" && return 0; fi
      if command -v notepad.exe >/dev/null 2>&1; then notepad.exe "$winpath" && return 0; fi
    fi
    if command -v cmd.exe >/dev/null 2>&1; then
      cmd.exe /c start "" "$winpath" >/dev/null 2>&1 && return 0
    fi
    _cx_warn "请手动打开：$file_path"
    return 0
  fi
  if [[ -n "${CODEX_USE_EDITOR_CMD:-}" ]]; then
    if eval "$CODEX_USE_EDITOR_CMD ${(q)file_path}"; then
      return 0
    else
      _cx_warn "自定义编辑器命令失败：$CODEX_USE_EDITOR_CMD"
    fi
  fi
  if [[ -d "$file_path" ]]; then
    if command -v code >/dev/null 2>&1; then code -w "$file_path" && return 0; fi
    if command -v code-insiders >/dev/null 2>&1; then code-insiders -w "$file_path" && return 0; fi
    if command -v subl >/dev/null 2>&1; then subl -w "$file_path" && return 0; fi
    if command -v xdg-open >/dev/null 2>&1; then xdg-open "$file_path" && return 0; fi
    if [[ -n "${VISUAL:-}" ]]; then
      local -a _cx_cmd
      _cx_cmd=("${(z)VISUAL}")
      "${_cx_cmd[@]}" "$file_path" && return 0
    fi
    if [[ -n "${EDITOR:-}" ]]; then
      local -a _cx_cmd
      _cx_cmd=("${(z)EDITOR}")
      "${_cx_cmd[@]}" "$file_path" && return 0
    fi
    if command -v vim >/dev/null 2>&1; then vim "$file_path" && return 0; fi
    if command -v nvim >/dev/null 2>&1; then nvim "$file_path" && return 0; fi
    _cx_warn "请手动打开：$file_path"
    return 0
  fi
  if [[ -n "${VISUAL:-}" ]]; then
    local -a _cx_cmd
    _cx_cmd=("${(z)VISUAL}")
    "${_cx_cmd[@]}" "$file_path" && return 0
  fi
  if [[ -n "${EDITOR:-}" ]]; then
    local -a _cx_cmd
    _cx_cmd=("${(z)EDITOR}")
    "${_cx_cmd[@]}" "$file_path" && return 0
  fi
  if command -v code >/dev/null 2>&1; then code -w "$file_path" && return 0; fi
  if command -v code-insiders >/dev/null 2>&1; then code-insiders -w "$file_path" && return 0; fi
  if command -v gedit >/dev/null 2>&1; then gedit --wait "$file_path" && return 0; fi
  if command -v vim >/dev/null 2>&1; then vim "$file_path" && return 0; fi
  if command -v nvim >/dev/null 2>&1; then nvim "$file_path" && return 0; fi
  if command -v nano >/dev/null 2>&1; then nano "$file_path" && return 0; fi
  if command -v subl >/dev/null 2>&1; then subl -w "$file_path" && return 0; fi
  if command -v open >/dev/null 2>&1; then open "$file_path" && return 0; fi
  if command -v xdg-open >/dev/null 2>&1; then xdg-open "$file_path" && return 0; fi
  _cx_warn "请手动打开：$file_path"

_cx_purge_api_env_except_claude() {
  # 只清理 Codex 相关的变量，保留 ANTHROPIC_* 变量不动
  local -a names=(
    CODEX_MODEL CODEX_MODEL_PROVIDER CODEX_PREFERRED_AUTH_METHOD CODEX_PROVIDER_SECTION
    CODEX_PROVIDER_NAME CODEX_PROVIDER_BASE_URL CODEX_PROVIDER_WIRE_API CODEX_PROVIDER_HEADERS_JSON
    CODEX_CONFIG_TOML CODEX_AUTH_JSON CODEX_AUTH_FIELDS CODEX_AUTH_PREFIXES CODEX_AUTH_SUPPRESS
    CODEX_ACTIVE_PROFILE CODEX_ENV_NOTE CODEX_ENV_DESCRIPTION
    OPENAI_API_KEY OPENAI_BASE_URL OPENAI_ORG_ID OPENAI_PROJECT_ID OPENAI_API_TYPE
    ANYROUTER_API_KEY ANYROUTER_TOKEN
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
  for n in "$names[@]"; do
    unset "$n"
  done
  # 注意：不再清理 ANTHROPIC_* 变量，避免与 claude-tools 冲突
  unset -m 'MISTRAL_*' 2>/dev/null || true
  unset -m 'GOOGLE_*' 2>/dev/null || true
  unset -m 'GROQ_*' 2>/dev/null || true
  unset -m 'FIREWORKS_*' 2>/dev/null || true
}

_cx_purge_api_env() {
  local -a names=(
    CODEX_MODEL CODEX_MODEL_PROVIDER CODEX_PREFERRED_AUTH_METHOD CODEX_PROVIDER_SECTION
    CODEX_PROVIDER_NAME CODEX_PROVIDER_BASE_URL CODEX_PROVIDER_WIRE_API CODEX_PROVIDER_HEADERS_JSON
    CODEX_CONFIG_TOML CODEX_AUTH_JSON CODEX_AUTH_FIELDS CODEX_AUTH_PREFIXES CODEX_AUTH_SUPPRESS
    CODEX_ACTIVE_PROFILE CODEX_ENV_NOTE CODEX_ENV_DESCRIPTION
    OPENAI_API_KEY OPENAI_BASE_URL OPENAI_ORG_ID OPENAI_PROJECT_ID OPENAI_API_TYPE
    ANYROUTER_API_KEY ANYROUTER_TOKEN
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
  for n in "$names[@]"; do
    unset "$n"
  done
  # 注意：不再清理 ANTHROPIC_* 变量，避免与 claude-tools 冲突
  unset -m 'MISTRAL_*' 2>/dev/null || true
  unset -m 'GOOGLE_*' 2>/dev/null || true
  unset -m 'GROQ_*' 2>/dev/null || true
  unset -m 'FIREWORKS_*' 2>/dev/null || true
}

_cx_backup_chatgpt_tokens() {
  # 自动备份ChatGPT tokens（如果当前是ChatGPT环境且有有效tokens）
  local chatgpt_backup="$CODEX_USE_HOME/auth.json.chatgpt"

  if [[ -f "$CODEX_USE_AUTH" ]]; then
    # 检查当前auth.json是否包含ChatGPT tokens
    if python3 - "$CODEX_USE_AUTH" <<'PY'
import json, sys, os
try:
    with open(sys.argv[1], "r") as f:
        data = json.load(f)
    # 检查是否包含ChatGPT tokens结构
    has_tokens = "tokens" in data and isinstance(data.get("tokens"), dict)
    has_id_token = has_tokens and "id_token" in data["tokens"]
    has_access_token = has_tokens and "access_token" in data["tokens"]

    if has_id_token and has_access_token:
        exit(0)  # 有有效的ChatGPT tokens
    else:
        exit(1)  # 没有有效的ChatGPT tokens
except:
    exit(1)
PY
    then
      # 备份ChatGPT tokens
      cp "$CODEX_USE_AUTH" "$chatgpt_backup"
      chmod 600 "$chatgpt_backup" 2>/dev/null || true
    fi
  fi
}

_cx_source_env() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    _cx_err "未找到环境文件：$file"
    return 1
  fi

  # 在切换到其他环境前，自动备份ChatGPT tokens
  _cx_backup_chatgpt_tokens

  _cx_purge_api_env
  set -a
  source "$file"
  set +a
  return 0
}

_cx_collect_auth_fields() {
  local -a fields
  if [[ -n "${CODEX_AUTH_FIELDS:-}" ]]; then
    fields=(${=CODEX_AUTH_FIELDS})
  elif [[ -n "${CODEX_AUTH_PREFIXES:-}" ]]; then
    local prefix
    for prefix in ${=CODEX_AUTH_PREFIXES}; do
      fields+=($(env | awk -F= -v p="$prefix" '$1 ~ "^" p { print $1 }'))
    done
  else
    fields=(
      OPENAI_API_KEY OPENAI_BASE_URL OPENAI_ORG_ID OPENAI_PROJECT_ID
      ANYROUTER_API_KEY ANYROUTER_TOKEN
      AZURE_OPENAI_KEY AZURE_OPENAI_ENDPOINT AZURE_OPENAI_DEPLOYMENT
      DEEPINFRA_API_KEY FIREWORKS_API_KEY GOOGLE_API_KEY GROQ_API_KEY
      MISTRAL_API_KEY MOONSHOT_API_KEY NOVITA_API_KEY OPENROUTER_API_KEY
      REPLICATE_API_TOKEN TOGETHER_API_KEY ZHIPUAI_API_KEY ZHIPU_API_KEY
    )
  fi
  print -r -- "$fields"
}

_cx_write_auth() {
  local tmp
  _cx_ensure_home
  if [[ "${CODEX_AUTH_SUPPRESS:-0}" == 1 ]]; then
    return 0
  fi
  if [[ -n "${CODEX_AUTH_JSON:-}" ]]; then
    tmp="$(mktemp)"
    print -r -- "$CODEX_AUTH_JSON" > "$tmp"
    mv "$tmp" "$CODEX_USE_AUTH"
    chmod 600 "$CODEX_USE_AUTH" 2>/dev/null || true
    return 0
  fi
  local -a fields
  fields=($(_cx_collect_auth_fields))
  local -a items=()
  local key
  for key in "$fields[@]"; do
    if [[ -n "${(P)key:-}" ]]; then
      items+=("$key")
    fi
  done
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
  if [[ -n "${CODEX_CONFIG_TOML:-}" ]]; then
    print -r -- "$CODEX_CONFIG_TOML"
    return 0
  fi
  local model="${CODEX_MODEL:-gpt-5-codex}"
  local provider="${CODEX_MODEL_PROVIDER:-anyrouter}"
  local preferred="${CODEX_PREFERRED_AUTH_METHOD:-apikey}"
  local provider_name="${CODEX_PROVIDER_NAME:-$provider}"
  local provider_section="${CODEX_PROVIDER_SECTION:-}"
  local base_url="${CODEX_PROVIDER_BASE_URL:-https://anyrouter.top/v1}"
  local wire_api="${CODEX_PROVIDER_WIRE_API:-responses}"

  if [[ -z "$provider_section" ]]; then
    provider_section=$'name = "'"$provider_name"$'"\n'
    provider_section+=$'base_url = "'"$base_url"$'"\n'
    provider_section+=$'wire_api = "'"$wire_api"$'"'
  fi

  printf 'model = "%s"\n' "$model"
  printf 'model_provider = "%s"\n' "$provider"
  printf 'preferred_auth_method = "%s"\n' "$preferred"
  printf '\n[model_providers.%s]\n' "$provider"
  print -r -- "$provider_section"
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
  return 0
}

_cx_cmd_show() {
  if [[ -f "$CODEX_USE_LAST" ]]; then
    _cx_info "上次记忆：$(<"$CODEX_USE_LAST")"
  else
    _cx_info "暂无记忆的默认环境"
  fi
  if [[ "${CODEX_ACTIVE_PROFILE:-}" == chatgpt ]]; then
    print -r -- "当前运行在 chatgpt 浏览器模式"
    printf '  %-28s = %s\n' preferred_auth_method "chatgpt (browser)"
    printf '  %-28s = %s\n' model "<由 Codex 自动管理>"
    return 0
  fi
  print -r -- "当前生效变量："
  printf '  %-28s = %s\n' CODEX_MODEL "${CODEX_MODEL:-<未设置>}"
  printf '  %-28s = %s\n' CODEX_MODEL_PROVIDER "${CODEX_MODEL_PROVIDER:-<未设置>}"
  printf '  %-28s = %s\n' CODEX_PREFERRED_AUTH_METHOD "${CODEX_PREFERRED_AUTH_METHOD:-<未设置>}"
  printf '  %-28s = %s\n' OPENAI_API_KEY "${OPENAI_API_KEY:+<已设置>}"
  printf '  %-28s = %s\n' ANYROUTER_API_KEY "${ANYROUTER_API_KEY:+<已设置>}"
}

_cx_cmd_list() {
  _cx_ensure_home
  local saved=""
  [[ -f "$CODEX_USE_LAST" ]] && saved="$(<"$CODEX_USE_LAST")"
  local -a names
  names=($(_cx_list_names))
  print -r -- "可用环境配置（$CODEX_USE_ENV_DIR）："
  if (( ${#names} == 0 )); then
    print -r -- "  （空）可添加 *.env 文件"
  fi
  local n
  for n in "${names[@]}"; do
    if [[ "$n" == "$saved" ]]; then
      print -r -- "  * $n  (默认)"
    else
      print -r -- "    $n"
    fi
  done
  if [[ "$saved" == chatgpt ]]; then
    print -r -- "  * chatgpt  (默认, 浏览器模式)"
  else
    print -r -- "    chatgpt  (浏览器模式，可通过 codex-use chatgpt 切换)"
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
  if [[ -f "$file" ]]; then
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
  if [[ ! -f "$file" ]]; then
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
  if [[ ! -f "$file" ]]; then
    _cx_err "未找到：$file"
    return 1
  fi
  print -n -- "确认删除 ${name%.env} ? 输入 yes 以继续："
  local answer; read -r answer
  if [[ "$answer" == yes ]]; then
    rm -f -- "$file"
    _cx_ok "已删除：$file"
    if [[ -f "$CODEX_USE_LAST" && "$(<"$CODEX_USE_LAST")" == "${name%.env}" ]]; then
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
      print -r -- "$short" >"$CODEX_USE_LAST"
      export CODEX_ACTIVE_PROFILE="$short"
      _cx_ok "已切换到环境：$short（已保存为默认）"
      _cx_cmd_show
    fi
  else
    return 1
  fi
}

_cx_switch_chatgpt() {
  _cx_purge_api_env_except_claude
  export CODEX_ACTIVE_PROFILE="chatgpt"
  local tmp="$(mktemp)"
  {
    printf '[model_providers.chatgpt]\n'
    printf 'name = "ChatGPT Web"\n'
    printf 'auth_via_browser = true\n'
  } >"$tmp"
  mv "$tmp" "$CODEX_USE_CONFIG"

  # 智能备份/恢复ChatGPT认证文件
  local chatgpt_backup="$CODEX_USE_HOME/auth.json.chatgpt"

  # 检查是否有之前的ChatGPT tokens备份
  if [[ -f "$chatgpt_backup" ]]; then
    # 恢复之前保存的ChatGPT tokens
    cp "$chatgpt_backup" "$CODEX_USE_AUTH"
    chmod 600 "$CODEX_USE_AUTH" 2>/dev/null || true
    _cx_info "已恢复ChatGPT认证tokens"
  else
    # 没有备份，创建基础的browser模式配置
    local tmp_auth="$(mktemp)"
    python3 - "$tmp_auth" <<'PY'
import json, sys
data = {"mode": "browser"}
with open(sys.argv[1], "w", encoding="utf-8") as fh:
    json.dump(data, fh, ensure_ascii=False, indent=2)
    fh.write("\n")
PY
    mv "$tmp_auth" "$CODEX_USE_AUTH"
    chmod 600 "$CODEX_USE_AUTH" 2>/dev/null || true
    _cx_warn "未找到ChatGPT认证备份，请执行 'codex login' 重新登录"
  fi

  print -r -- "chatgpt" >"$CODEX_USE_LAST"
  _cx_ok "已切换到 ChatGPT 浏览器模式（已保存为默认）"
  _cx_cmd_show
  if [[ ! -f "$chatgpt_backup" ]]; then
    _cx_info "如需刷新登录，请执行：codex login"
  fi
}

_cx_help() {
  cat <<H
用法：
  codex-switch list                 列出全部环境（含 chatgpt 模式）
  codex-switch use <name>           切换到 <name> 环境（无需 .env 后缀）
  codex-switch <name>               切换到 <name> 环境（兼容旧用法）
  codex-switch chatgpt              切换到 ChatGPT 浏览器登录模式
  codex-switch new <name>           新建 <name>.env，并打开编辑器
  codex-switch edit <name>          编辑 <name>.env（不存在则创建模板）
  codex-switch del <name>           删除 <name>.env（需输入 yes 确认）
  codex-switch show|current         显示已记忆的默认与当前变量
  codex-switch open|dir             打开环境目录
  codex-switch help                 显示本帮助

目录：
  环境目录：$CODEX_USE_ENV_DIR
  记忆文件：$CODEX_USE_LAST
  配置文件：$CODEX_USE_CONFIG
  授权文件：$CODEX_USE_AUTH

配置：
  CODEX_HOME             默认 $HOME/.codex
  CODEX_USE_EDITOR_CMD   自定义编辑命令（优先级最高）
  ChatGPT 模式           模型由 Codex 自动管理
H
}

codex-switch() {
  local cmd="${1:-}"; shift 2>/dev/null || true
  case "$cmd" in
    ""|help|-h|--help)   _cx_help ;;
    list|ls)             _cx_cmd_list ;;
    use)                 _cx_validate_env_name "$1" && _cx_switch_env "$1" ;;
    chatgpt)             _cx_switch_chatgpt ;;
    new)                 _cx_cmd_new "$@" ;;
    edit)                _cx_cmd_edit "$@" ;;
    del)                 _cx_cmd_del "$@" ;;
    show)                _cx_cmd_show ;;
    open)                _cx_open_path "$CODEX_USE_ENV_DIR" ;;
    *)                   _cx_validate_env_name "$cmd" && _cx_switch_env "$cmd" ;;
  esac
}

_cx_zsh_complete() {
  local cur="${words[CURRENT]}"
  local -a envs
  _cx_env_candidates "$cur"
  envs=("${reply[@]}")
  if (( CURRENT == 2 )); then
    if [[ "$cur" != */* ]]; then
      (( ${#CODEX_SWITCH_SUBCOMMANDS[@]} > 0 )) && compadd -a CODEX_SWITCH_SUBCOMMANDS
    fi
    (( ${#envs[@]} > 0 )) && compadd -Q -S '' -a envs
    return
  fi
  case "${words[2]}" in
    use|new|edit|del|delete|rm)
      (( ${#envs[@]} > 0 )) && compadd -Q -S '' -a envs
      ;;
  esac
}

_cx_setup_completion() {
  if (( $+functions[compdef] )); then
    compdef _cx_zsh_complete codex-switch
  fi
}

_cx_autoload_on_startup() {
  _cx_ensure_home
  local chosen=""
  if [[ -f "$CODEX_USE_LAST" ]]; then
    chosen="$(<"$CODEX_USE_LAST")"
  else
    local -a names
    names=($(_cx_list_names))
    if (( ${#names} > 0 )); then
      chosen="${names[1]}"
    fi
  fi
  if [[ -n "$chosen" ]]; then
    if [[ "$chosen" == chatgpt ]]; then
      _cx_switch_chatgpt >/dev/null 2>&1 || true
    else
      _cx_switch_env "$chosen" >/dev/null 2>&1 || true
    fi
  fi
}

# 禁用自动启动，避免污染用户配置
if [[ -o interactive ]]; then
  _cx_setup_completion
  # _cx_autoload_on_startup
fi
