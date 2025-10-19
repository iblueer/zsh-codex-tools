# 离线安装指南

本指南适用于无法访问GitHub的服务器环境。

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
