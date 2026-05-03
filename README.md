# Mihomo Manager

一个轻量级的 Windows 系统托盘工具，用于一键管理 [Mihomo](https://github.com/MetaCubeX/mihomo) 代理内核的**系统代理模式**和 **TUN 模式**，同时提供配置重载、验证、开机自启等常用功能。

使用 AutoHotkey v2 编写，已编译为独立 `.exe`，无需安装任何依赖。

## ✨ 功能特性

- 🌐 **模式一键切换**  
  - 系统代理模式：启动内核 + 设置 Windows 系统代理  
  - TUN 模式：以管理员权限启动内核，不修改系统代理
- 🔄 **配置重载**  
  调用 Mihomo API 热重载配置文件，无需重启内核
- ✅ **配置验证**  
  检查 `mihomo.yaml` 语法是否合法，避免启动失败
- 📌 **开机自启**  
  一键启用/取消开机自动运行，托盘启动后自动最小化
- 🔒 **自动提权**  
  程序启动时自动请求管理员权限，确保 TUN 模式/进程终止稳定可靠
- 💬 **气泡提示反馈**  
  所有操作结果均通过系统托盘气泡显示，不干扰当前工作

## 📋 系统要求

- Windows 7 及以上（推荐 Windows 10/11）
- 无需安装 AutoHotkey 或 PowerShell，直接运行 `.exe`
- 需要将下列文件放在**同一目录**：
  - `mihomo-manager.exe`（本工具）
  - `mihomo-windows-amd64.exe`（Mihomo 内核）
  - `mihomo.yaml`（Mihomo 配置文件）

## ⚡ 快速开始

### 从 Releases 获取

1. 前往 [Releases](../../releases) 页面，下载最新版的 `mihomo-manager.exe`。
2. 将 `mihomo-manager.exe` 放到已包含 `mihomo-windows-amd64.exe` 和 `mihomo.yaml` 的文件夹内。
3. 双击运行 `mihomo-manager.exe`，托盘区会出现一个网络图标 🌐。
4. 右键托盘图标即可切换代理模式、重载配置等。
5. （可选）在菜单中勾选「✅ 开机自启」，使工具随系统启动。

> 💡 首次运行时，Windows 或杀毒软件可能弹出安全警告，点击“更多信息”→“仍要运行”即可。这是因为编译后的 `.exe` 未购买代码签名证书，并非恶意软件。  
> 本工具开源，所有源码可见 [mihomo-manager.ahk](./mihomo-manager.ahk)，可自行审查或用 [AutoHotkey v2](https://www.autohotkey.com/) 重新编译。

## 🕹️ 托盘菜单说明

右键系统托盘图标，弹出菜单：

| 菜单项 | 功能 |
|--------|------|
| **系统代理模式** | 若当前未启用，则启动内核并设置系统代理 (`127.0.0.1:7890`)；若已启用，则停止内核并关闭代理 |
| **TUN 模式** | 若当前未启用，则以管理员权限启动内核，**不设置**系统代理；若已启用，则强制终止内核进程 |
| **🔁 重载配置** | 调用 API 热重载 `mihomo.yaml`，适用于修改规则或节点后快速生效 |
| **ℹ️ 验证配置** | 使用 `mihomo-windows-amd64.exe -t` 测试配置文件合法性，结果以气泡提示显示 |
| **✅ 开机自启** | 切换当前工具的开机启动状态，打勾表示已启用 |
| **❌ 退出** | 退出托盘程序（*不会停止正在运行的 Mihomo 内核*，如需停止请先使用“系统代理模式”或“TUN 模式”菜单关闭） |

菜单项会**自动更新状态**，例如当前已开启系统代理时，菜单会显示「系统代理模式 (已开启)」。

## ⚙️ 配置说明

### 代理端口与 API 地址

如需修改代理端口、API 端口或内核文件名，请直接编辑 `mihomo-manager.ahk`（然后重新编译），或确保 `mihomo.yaml` 配置与以下默认值一致：

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
检查 `shell:startup` 文件夹（运行窗口输入 `shell:startup`）中是否存在 `mihomo-manager.lnk` 快捷方式，且指向的路径正确。杀软可能拦截创建，请放行或手动创建。

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
├── mihomo-managery.exe               # 本工具
├── mihomo-windows-amd64.exe     # Mihomo 内核
└── mihomo.yaml                  # 内核配置文件
```

## 📜 许可证

本工具源码基于 MIT 许可发布，详见仓库中的 LICENSE 文件（如有）。  
内核 Mihomo 及其配置文件遵循其各自的开源协议。

## 🙏 致谢

- [Mihomo](https://github.com/MetaCubeX/mihomo) 核心项目
- AutoHotkey 社区
- 所有贡献者与使用者

---
