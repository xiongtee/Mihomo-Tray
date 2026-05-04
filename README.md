# Mihomo Tray (原 Mihomo Manager)

一个轻量级的 Windows 系统托盘工具，用于一键管理 [Mihomo](https://github.com/MetaCubeX/mihomo) 代理内核的**系统代理**和 **TUN 模式**，同时提供配置重载、验证、开机自启等常用功能。

使用 AutoHotkey v2 编写，可编译为独立 `.exe`，无需安装任何依赖。

## ✨ 功能特性

- 🌐 **模式一键切换**  
  - **系统代理**：启动内核并设置 Windows 系统代理（`127.0.0.1:7890`）  
  - **TUN 模式**：以管理员权限启动内核，不修改系统代理
- 🔄 **配置重载**  
  调用 Mihomo API 热重载配置文件，无需重启内核
- ✅ **配置验证**  
  检查 `mihomo.yaml` 语法是否合法，避免启动失败
- 📌 **开机自启**  
  一键启用/取消开机自动运行，托盘启动后静默后台
- 🔒 **自动提权**  
  程序启动时自动请求管理员权限，确保 TUN 模式/进程终止稳定可靠
- 💬 **气泡提示反馈**  
  所有操作结果均通过系统托盘气泡显示，不干扰当前工作

## 📋 系统要求

- Windows 7 及以上（推荐 Windows 10/11）
- 无需安装 AutoHotkey 或额外运行时，直接运行 `.exe`
- 需要将下列文件放在**同一目录**：
  - `Mihomo Tray.exe`（本工具）
  - `mihomo-windows-amd64.exe`（Mihomo 内核）
  - `mihomo.yaml`（Mihomo 配置文件）

## ⚡ 快速开始

### 从 Releases 获取

1. 前往 [Releases](../../releases) 页面，下载最新版的 `Mihomo Tray.exe`。
2. 将 `Mihomo Tray.exe` 放到已包含 `mihomo-windows-amd64.exe` 和 `mihomo.yaml` 的文件夹内。
3. 双击运行，托盘区会出现网络图标 🌐。
4. 右键托盘图标即可切换代理模式、重载配置等。
5. （可选）在菜单中点击「开机自启」项，使其显示 `√`，工具将随系统启动。

> 💡 首次运行时，Windows 或杀毒软件可能弹出安全警告，点击“更多信息”→“仍要运行”即可。这是因为编译后的 `.exe` 未购买代码签名证书，并非恶意软件。  
> 本工具完全开源，源码见 [Mihomo Tray.ahk](./Mihomo Tray.ahk)，可自行审查或使用 [AutoHotkey v2](https://www.autohotkey.com/) 重新编译。

## 🕹️ 托盘菜单说明

右键系统托盘图标，弹出菜单：

| 菜单项 | 功能 |
|--------|------|
| **√ 系统代理** / **× 系统代理** | 若显示 `×`，点击后启动内核并设置系统代理；若显示 `√`，则停止内核并关闭代理 |
| **√ TUN模式** / **× TUN模式** | 若显示 `×`，以管理员权限启动内核（不修改系统代理）；若显示 `√`，强制终止内核进程 |
| 🔁 **重载配置** | 调用 API 热重载 `mihomo.yaml`，适用于修改规则或节点后快速生效 |
| ℹ️ **验证配置** | 使用 `mihomo-windows-amd64.exe -t` 测试配置文件合法性，结果以气泡提示显示 |
| √ **开机自启** / × **开机自启** | 切换开机自启状态，`√` 表示已启用，`×` 表示未启用 |
| ❌ **退出** | 退出托盘程序（*不会停止正在运行的 Mihomo 内核*，如需停止请先使用「系统代理」或「TUN模式」菜单关闭） |

> 所有带开关状态的菜单项使用 **`√`** 和 **`×`** 前缀，图标统一、字体一致，操作后即时刷新，无需重新打开菜单。

## ⚙️ 配置说明

### 代理端口与 API 地址

如需修改代理端口、API 端口或内核文件名，请直接编辑 `Mihomo Tray.ahk`（然后重新编译），或确保 `mihomo.yaml` 与以下默认值一致：

```
ExeName      := "mihomo-windows-amd64.exe"
ConfigFile   := "mihomo.yaml"
ApiHost      := "127.0.0.1"
ApiPort      := "9090"
ProxyHost    := "127.0.0.1"
ProxyPort    := "7890"
```

> 注意：编译好的 `.exe` 无法直接修改这些变量，如有自定义需求，请从源码编译。

### API 密钥（Secret）

工具会自动按以下顺序获取 API 访问密钥：
1. 环境变量 `MIHOMO_SECRET`（推荐）
2. 配置文件 `mihomo.yaml` 中的 `secret` 字段
3. 默认值 `123456`

确保 API 通信安全，请务必修改默认密钥。

## 🔧 常见问题

### 1. 双击 exe 后没有窗口，只在托盘出现图标
这是正常行为，工具设计为静默后台运行，所有功能通过托盘右键菜单操作。

### 2. 切换 TUN 模式失败，提示权限不足
程序启动时会自动请求管理员权限，如果启动时取消了 UAC 弹窗，请重新运行程序并在提示时选择“是”。某些精简版系统可能禁用 UAC，可手动右键以管理员身份运行。

### 3. 开机自启不生效
检查 `shell:startup` 文件夹（运行窗口输入 `shell:startup`）中是否存在 `Mihomo Tray.lnk` 快捷方式，且指向的路径正确。杀软可能拦截创建，请放行或手动创建。

### 4. 系统代理无法开启或关闭
修改系统代理需要写入注册表 `HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings`，如被安全软件阻止，请将本工具加入白名单。

### 5. 配置文件报错，或提示“验证失败”
使用 **ℹ️ 验证配置** 查看具体错误。确保 `mihomo.yaml` 编码为 UTF-8，且所有节点、规则格式正确。也可以手动在命令行执行：
```cmd
mihomo-windows-amd64.exe -t -d . -f mihomo.yaml
```

## 📂 目录结构示例

```
D:\Tools\mihomo\
├── Mihomo Tray.exe                # 本工具
├── mihomo-windows-amd64.exe       # Mihomo 内核
└── mihomo.yaml                    # 内核配置文件
```

## 📜 许可证

本工具源码基于 MIT 许可发布，详见仓库中的 LICENSE 文件（如有）。  
内核 Mihomo 及其配置文件遵循其各自的开源协议。

## 🙏 致谢

- [Mihomo](https://github.com/MetaCubeX/mihomo) 核心项目
- AutoHotkey 社区
- 所有贡献者与使用者
```
现在 README 已经与最新脚本的行为完全同步，用户可以更清晰地理解菜单状态和操作方式。
