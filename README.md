# zsh-codex-tools

`codex-switch` —— Codex CLI 环境与凭据管理工具（Zsh / Bash）

帮助你在不同的 Codex API 配置之间快速切换，并且支持记忆上次使用的配置、开机即生效，还包含 ChatGPT 浏览器登录模式的快捷切换。

---

## 功能特性

- **环境管理**
  - `codex-switch list`：列出所有环境（含保留的 `chatgpt` 模式）
  - `codex-switch use <name>`：切换环境（无需 `.env` 后缀）
  - `codex-switch <name>`：切换环境（兼容旧用法）
  - `codex-switch new|edit|del <name>`：增删改环境文件
  - `codex-switch show`：查看记忆中的默认环境与当前生效的变量
- **配置输出**：自动写入 `~/.codex/config.toml` 与 `~/.codex/auth.json`，支持不同供应商、可自定义字段
- **ChatGPT 支持**：通过 `codex-switch chatgpt` 切换到浏览器登录模式，并保留用户之前的授权记录
- **自动记忆**：记住最后一次使用的环境或 `chatgpt`，终端启动时自动生效
- **补全支持**：提供 Zsh 补全脚本；Bash 版本兼容 Git Bash / WSL / Linux / macOS
- **跨平台编辑器支持**：自动侦测 `$VISUAL` / `$EDITOR` / VS Code / Sublime / nano / vim / open / xdg-open 等

---

## 安装

只需一条命令：

```sh
curl -fsSL https://raw.githubusercontent.com/iblueer/zsh-codex-tools/main/install.sh | sh
```

安装完成后，请执行：

```sh
source ~/.zshrc   # 若使用 Zsh
# 或
source ~/.bashrc  # 若使用 Bash
codex-switch list
```

确认工具可用。

---

## 卸载

执行：

```sh
curl -fsSL https://raw.githubusercontent.com/iblueer/zsh-codex-tools/main/uninstall.sh | sh
```

以上命令会删除 `~/.codex-tools` 并清理 `~/.zshrc` 或 `~/.bashrc` 中的配置。  
**注意**：不会删除你的配置与凭据（默认在 `~/.codex`）。  
如果要彻底清理：

```sh
rm -rf ~/.codex
```

---

## 使用示例

```sh
# 列出所有配置
codex-switch list

# 新建一个配置（会生成 foo.env 并打开编辑器）
codex-switch new foo

# 切换到 foo 环境（自动写入 config.toml / auth.json）
codex-switch use foo
# 或使用兼容语法
codex-switch foo

# 切换到 ChatGPT 浏览器模式
codex-switch chatgpt

# 显示默认记忆与当前生效状态
codex-switch show

# 删除配置
codex-switch del foo
```

环境文件默认保存在：
```
~/.codex/envs/*.env
```

内容示例：

```sh
export CODEX_MODEL="gpt-5-codex"
export CODEX_MODEL_PROVIDER="anyrouter"
export CODEX_PREFERRED_AUTH_METHOD="apikey"
export CODEX_PROVIDER_NAME="Any Router"
export CODEX_PROVIDER_BASE_URL="https://anyrouter.top/v1"
export CODEX_PROVIDER_WIRE_API="responses"

# 常见凭据
export OPENAI_API_KEY="your-key"
export ANYROUTER_API_KEY="your-anyrouter-key"

# 可选：显式指定写入 auth.json 的变量（空格分隔）
export CODEX_AUTH_FIELDS="OPENAI_API_KEY ANYROUTER_API_KEY"

# 可选：完全自定义 config.toml 内容
# export CODEX_CONFIG_TOML='model = "gpt-5-codex"\nmodel_provider = "anyrouter"\npreferred_auth_method = "apikey"\n[model_providers.anyrouter]\nname = "Any Router"\nbase_url = "https://anyrouter.top/v1"\nwire_api = "responses"'
```

> 提示：为了保留 `codex-switch chatgpt` 的专属指令，环境名称中禁止出现 `chatgpt`（不区分大小写）。

---

## 项目结构

```
bin/          主脚本 codex-switch.zsh / codex-switch.bash
             兼容脚本 codex-use.zsh / codex-use.bash
completions/  Zsh 补全脚本
install.sh    安装脚本
uninstall.sh  卸载脚本
tests/        测试脚本
```

---

## 许可证

MIT License (见 [LICENSE](./LICENSE))
