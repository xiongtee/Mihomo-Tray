# Mihomo Manager

一个用于管理 Mihomo 代理裸核的 PowerShell 脚本，提供交互式菜单与命令行参数两种使用方式。支持启动、停止、重启、状态查看、配置重载、一键开关系统代理以及管理员权限自动提升（用于TUN）。

## ✨ 功能特性

- 🚀 启动 / 停止 / 重启 Mihomo 内核
- 📊 查看运行状态（PID、运行时长、内存占用、API 状态）
- 🔄 重载配置文件（无需重启）
- ✅ 验证配置文件语法
- 🌐 一键开启或关闭 Windows 系统代理（指向 Mihomo 代理端口）
- 🔒 以管理员权限启动内核（避免部分功能受限）
- 📜 支持命令行参数直接调用，便于集成到其他脚本或快捷方式
- 🧩 自动读取 `mihomo.yaml` 中的 `secret` 或环境变量，保障 API 通信安全

## 📋 系统要求

- Windows 7 及以上
- PowerShell 5.1 或更高版本（推荐 PowerShell 7）
- Mihomo 裸核程序 `mihomo-windows-amd64.exe` 与配置文件 `mihomo.yaml` 需放置于脚本同目录

## ⚡ 快速开始

1. 将 `mihomo-manager.ps1`、`mihomo-windows-amd64.exe` 和 `mihomo.yaml` 放在同一目录下。

2. 获取脚本文件（推荐复制粘贴，避免文件锁定）：

   **✅ 推荐方式：直接复制脚本内容**
   - 打开文本编辑器（如记事本），粘贴完整的脚本代码。
   - 保存为 `mihomo-manager.ps1`，编码选择 **UTF-8 with BOM**。
   - 通过此方式生成的文件不会带有“从网络下载”的安全标记，可直接运行，无需额外解锁。

   **🔄 备选方式：从网络下载后解除锁定**
   - 如果通过浏览器或其他方式下载了脚本文件，Windows 可能会将其标记为“来自 Internet”，导致无法执行。
   - 右键点击 `mihomo-manager.ps1` → **属性** → 勾选 **解除锁定** → 确定。
   - 或在 PowerShell 中执行：
     ```powershell
     Unblock-File -Path ".\mihomo-manager.ps1"

3. 运行脚本：

   - **直接双击** `mihomo-manager.ps1` 文件，系统会自动以 PowerShell 运行。
   - 若双击后打开的是代码编辑器，可右键点击文件 → **使用 PowerShell 运行**。
   - 脚本启动时会自动检测管理员权限，若非管理员则弹出 UAC 窗口以管理员身份重新启动，无需手动提权。

> 💡 如果系统 PowerShell 执行策略禁止脚本运行（极少见情况），可临时执行：  
> `powershell -ExecutionPolicy Bypass -File ".\mihomo-manager.ps1"`

## 🕹️ 使用方式

### 交互菜单

不带任何参数即可进入菜单模式，选择数字选项执行对应操作：

```
Mihomo 裸核控制面板
===========================================
  当前状态: 运行中 (PID 12345)
  系统代理: 开启 (127.0.0.1:7890)
  脚本权限: 管理员

  [1] 启动 Mihomo
  [2] 停止 Mihomo
  [3] 重启 Mihomo
  [4] 查看状态
  [5] 重载配置
  [6] 验证配置
  [7] 帮助信息
  [8] 切换系统代理
  [9] 管理员启动 Mihomo

  [Q] 退出
```

### 命令行参数

| 命令          | 说明                         |
| ------------- | ---------------------------- |
| `start`       | 启动 Mihomo                  |
| `stop`        | 停止 Mihomo                  |
| `restart`     | 重启 Mihomo                  |
| `status`      | 查看运行状态                 |
| `reload`      | 重载配置文件                 |
| `proxy-on`    | 开启系统代理                 |
| `proxy-off`   | 关闭系统代理                 |
| `admin-start` | 以管理员权限启动 Mihomo      |
| `help`        | 显示帮助信息                 |

示例：
```powershell
.\mihomo-manager.ps1 start
.\mihomo-manager.ps1 proxy-on
.\mihomo-manager.ps1 admin-start
```

## ⚙️ 配置说明

### 脚本内部变量

如需自定义 API 地址、代理端口或内核文件名，可编辑脚本开头的配置区域：

```powershell
$ExeName    = "mihomo-windows-amd64.exe"   # 内核文件名
$ConfigFile = "mihomo.yaml"                # 配置文件名
$ApiHost    = "127.0.0.1"                  # API 监听地址
$ApiPort    = 9090                         # API 端口
$ProxyHost  = "127.0.0.1"                  # 代理监听地址
$ProxyPort  = 7890                         # 代理端口
```

### Secret 密钥

脚本会自动按以下优先级获取 API 访问密钥：
1. **环境变量 `MIHOMO_SECRET`**（推荐）
2. **配置文件 `mihomo.yaml` 中的 `secret` 字段**
3. **默认值 `123456`**

若需查看当前使用的密钥来源，可设置环境变量 `MIHOMO_SECRET_DEBUG` 为 `1` (脱敏) 或 `full` (完整)：
```powershell
$env:MIHOMO_SECRET_DEBUG = "1"
.\mihomo-manager.ps1 status
```

## 📂 目录结构示例

```
D:\Portable\mihomo\
├── mihomo-manager.ps1      # 本脚本
├── mihomo-windows-amd64.exe # Mihoomo 内核
└── mihomo.yaml             # 内核配置文件
```

## 🔧 常见问题

### 1. 脚本无法运行，提示“无法加载文件……未进行数字签名”

**解决方法：**
- 对脚本文件右键 → 属性 → 勾选“解除锁定” → 确定。
- 或在 PowerShell 中执行 `Unblock-File -Path "路径\mihomo-manager.ps1"`。

### 2. 停止 Mihomo 时提示 `Access is denied`

本脚本已内置自动管理员提权，通常不会出现此问题。若仍发生，请检查是否以管理员身份运行了原 PowerShell 窗口（脚本会在启动时自动请求管理员权限，无需手动提权）。

### 3. 系统代理无法开启/关闭

系统代理通过修改注册表 `HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings` 实现，需要当前用户具备注册表写入权限。若操作失败，请检查是否有安全软件拦截。

### 4. 如何更换代理端口或 API 端口？

修改脚本中对应的 `$ProxyPort` 和 `$ApiPort` 变量，并确保 `mihomo.yaml` 中的配置与之匹配。

## 📜 许可证

本脚本基于原项目 [mihomo-manager.ps1](https://github.com/lvbibir/clash/blob/master/mihomo-manager.ps1) 修改而来，遵循原始项目的许可证（如有）。如无特别声明，可视为 MIT 许可。

## 🙏 致谢

- 原作者：[clash](https://github.com/lvbibir)
- 脚本中的延迟测试部分已移除，保留常用核心管理功能。
