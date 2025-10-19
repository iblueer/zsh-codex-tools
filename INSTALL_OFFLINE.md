# 离线安装指南

本指南适用于无法访问GitHub的服务器环境。

## 前置要求

**重要**: Codex CLI 需要 Node.js >= 16。请先确认服务器上的 Node.js 版本:

```sh
node --version
```

如果版本低于 16 或未安装,请参考下方 [离线安装 Node.js](#离线安装-nodejs) 章节。

## 安装步骤

### 1. 打包项目

在可以访问GitHub的机器上,克隆或下载整个项目:

```sh
# 如果已经在项目目录中
cd zsh-codex-tools

# 打包整个项目
tar -czf zsh-codex-tools.tar.gz \
  bin/ \
  completions/ \
  install_locally.sh \
  LICENSE \
  README.md
```

或者打包所有文件:

```sh
tar -czf zsh-codex-tools.tar.gz *
```

### 2. 上传到目标服务器

使用 scp、rsync 或其他文件传输工具将压缩包上传到服务器:

```sh
# 示例: 使用 scp
scp zsh-codex-tools.tar.gz user@server:/tmp/

# 示例: 使用 rsync
rsync -avz zsh-codex-tools.tar.gz user@server:/tmp/
```

### 3. 在服务器上解压并安装

登录到目标服务器:

```sh
ssh user@server
```

解压并安装:

```sh
# 进入临时目录
cd /tmp

# 解压
tar -xzf zsh-codex-tools.tar.gz

# 进入解压后的目录
cd zsh-codex-tools  # 或根据实际解压的目录名

# 执行本地安装脚本
./install_locally.sh
```

### 4. 激活配置

```sh
# 如果使用 Zsh
source ~/.zshrc

# 如果使用 Bash
source ~/.bashrc

# 验证安装
codex-use list
```

## 与在线安装的区别

| 特性 | 在线安装 | 离线安装 |
|------|---------|---------|
| 网络要求 | 需要访问 GitHub | 不需要网络 |
| 安装命令 | `curl ... \| sh` | `./install_locally.sh` |
| 源文件来源 | 从GitHub下载 | 从本地复制 |
| 功能 | 完全相同 | 完全相同 |

## 注意事项

1. **文件完整性**: 确保上传的压缩包包含以下必要文件:
   - `bin/codex-use.zsh`
   - `bin/codex-use.bash`
   - `completions/_codex-use`
   - `install_locally.sh`

2. **权限**: 安装脚本会自动设置适当的文件权限,但请确保有写入 `$HOME` 目录的权限

3. **Shell 类型**: 脚本会自动检测当前使用的 Shell (Bash 或 Zsh) 并安装相应版本

4. **清理**: 安装完成后,可以删除临时目录:
   ```sh
   cd ~
   rm -rf /tmp/zsh-codex-tools /tmp/zsh-codex-tools.tar.gz
   ```

## 调试

如果遇到问题,可以启用调试模式:

```sh
CODEX_TOOLS_DEBUG=1 ./install_locally.sh
```

这将显示详细的执行过程,帮助定位问题。

## 离线安装 Node.js

如果服务器上的 Node.js 版本低于 16 或未安装,需要先离线安装 Node.js。

### 步骤 1: 在有网络的机器上下载 Node.js

访问 Node.js 官网下载对应系统的二进制包:

**对于 Linux x64 系统** (最常见):
```sh
# 下载 Node.js 20 LTS (推荐)
wget https://nodejs.org/dist/v20.18.1/node-v20.18.1-linux-x64.tar.xz

# 或使用 curl
curl -O https://nodejs.org/dist/v20.18.1/node-v20.18.1-linux-x64.tar.xz
```

**对于其他架构**:
- Linux ARM64: `node-v20.18.1-linux-arm64.tar.xz`
- Linux ARMv7: `node-v20.18.1-linux-armv7l.tar.xz`

查看所有版本: https://nodejs.org/dist/

### 步骤 2: 上传到服务器

```sh
scp node-v20.18.1-linux-x64.tar.xz user@server:/tmp/
```

### 步骤 3: 在服务器上安装

登录服务器后执行:

```sh
# 解压到 /usr/local
cd /tmp
sudo tar -xJf node-v20.18.1-linux-x64.tar.xz -C /usr/local --strip-components=1

# 或解压到用户目录 (无需 root 权限)
mkdir -p ~/nodejs
tar -xJf node-v20.18.1-linux-x64.tar.xz -C ~/nodejs --strip-components=1

# 添加到 PATH (添加到 ~/.bashrc 或 ~/.zshrc)
echo 'export PATH="$HOME/nodejs/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### 步骤 4: 验证安装

```sh
node --version   # 应显示 v20.18.1
npm --version    # 应显示 10.x.x
```

### 步骤 5: 离线安装 Codex CLI

如果服务器完全无法访问外网,需要在有网络的机器上打包 Codex CLI:

```sh
# 在有网络的机器上
npm pack @openai/codex
# 这会生成一个 openai-codex-X.X.X.tgz 文件
```

上传到服务器后安装:

```sh
# 在服务器上
npm install -g ./openai-codex-X.X.X.tgz
```

或者,如果服务器可以访问 npm registry (只是无法访问 GitHub):

```sh
npm install -g @openai/codex
```

### 快速命令总结 (Ubuntu 20, x64)

```sh
# === 在有网络的机器上 ===
# 下载 Node.js
wget https://nodejs.org/dist/v20.18.1/node-v20.18.1-linux-x64.tar.xz

# 下载 Codex CLI (可选,如果 npm registry 也无法访问)
npm pack @openai/codex

# 上传到服务器
scp node-v20.18.1-linux-x64.tar.xz user@server:/tmp/
scp openai-codex-*.tgz user@server:/tmp/  # 如果需要

# === 在服务器上 ===
# 安装 Node.js (用户目录,无需 root)
cd /tmp
mkdir -p ~/nodejs
tar -xJf node-v20.18.1-linux-x64.tar.xz -C ~/nodejs --strip-components=1
echo 'export PATH="$HOME/nodejs/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# 验证
node --version

# 安装 Codex CLI
npm install -g @openai/codex
# 或使用离线包: npm install -g ./openai-codex-*.tgz

# 清理临时文件
rm /tmp/node-v20.18.1-linux-x64.tar.xz
```

## 卸载

如需卸载,可以使用在线卸载脚本,或手动删除:

```sh
# 删除工具目录
rm -rf ~/.codex-tools

# 手动从 ~/.zshrc 或 ~/.bashrc 中删除以下标记之间的内容:
# >>> iblueer/zsh-codex-tools BEGIN (managed) >>>
# ...
# <<< iblueer/zsh-codex-tools END   <<<

# (可选) 如需彻底清理配置和凭据
rm -rf ~/.codex
```
