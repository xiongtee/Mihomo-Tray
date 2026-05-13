# Mihomo Tray

一个轻量级的 Windows 系统托盘工具，用于一键管理 [Mihomo](https://github.com/MetaCubeX/mihomo) 代理内核的**系统代理**和 **TUN 模式**，同时支持配置重载、打开工作目录等常用功能。

基于 AutoHotkey v2 编写，代码简洁清晰，可编译为独立的 `.exe` 文件，无需安装任何运行时。

---

## 功能

- 🌐 **模式一键切换**  
  - **系统代理**：启动 Mihomo 内核并自动开启 Windows 系统代理（默认 `127.0.0.1:7890`）  
  - **TUN 模式**：启动 Mihomo 内核（不修改系统代理），适合需要接管所有流量的场景
- 🔄 **配置热重载**  
  通过 Mihomo 内置 API (`http://127.0.0.1:9090`) 重载配置文件，无需重启内核
- ❌ **关闭核心**  
  立即停止 Mihomo 进程并关闭系统代理（如果已开启）
- 📁 **打开工作目录**  
  一键打开 Mihomo 所在文件夹，方便手动编辑 `mihomo.yaml` 或查看日志
- 🔒 **自动提权**  
  脚本启动时自动请求管理员权限，确保进程管理、TUN 模式、注册表写入稳定可靠
- 💬 **托盘气泡反馈**  
  所有操作结果均通过系统通知气泡显示，不干扰当前工作
- 🧠 **实时状态刷新**  
  托盘菜单中的开关状态（开/关）每 1.5 秒自动更新，无需重新打开菜单

---

## 系统要求

- Windows 7 及以上（推荐 Windows 10/11）
- 无需安装 AutoHotkey 或额外运行时，直接运行 `.exe`
- 需要将下列文件放在 **同一目录**：
  - `Mihomo Tray.exe`（本工具，可自行编译）
  - `mihomo-windows-amd64.exe`（Mihomo 内核）
  - `mihomo.yaml`（Mihomo 配置文件）

---

## 快速开始

### 从源码编译（推荐）

1. 安装 [AutoHotkey v2](https://www.autohotkey.com/)
2. 下载本仓库中的 `Mihomo Tray.ahk`
3. 使用 `Ahk2Exe.exe` 编译：
   - 选择 **Base File**：`U64 AutoHotkey64.exe`（64 位系统）
   - 输出文件名：`Mihomo Tray.exe`
4. 将生成的 `Mihomo Tray.exe` 放到包含 `mihomo-windows-amd64.exe` 和 `mihomo.yaml` 的文件夹
5. 双击运行，托盘区会出现网络图标 🌐

> 💡 若您不需要自行修改配置，也可以直接使用已编译好的版本（见 Releases 页面）。

---

## 托盘菜单说明

右键单击系统托盘图标，弹出菜单：

| 菜单项 | 功能 |
|--------|------|
| **打开目录** | 用资源管理器打开 Mihomo 所在文件夹，方便编辑配置或查看日志 |
| **[开/关]系统代理** | 若显示「关 系统代理」，点击后启动内核并开启系统代理；若显示「开 系统代理」，则停止内核并关闭代理 |
| **[开/关]TUN模式** | 若显示「关 TUN模式」，启动内核（不修改系统代理）；若显示「开 TUN模式」，停止内核 |
| **关闭核心** | 强制停止 Mihomo 进程并关闭系统代理（相当于将两个模式都设为关闭状态） |
| **重载配置** | 调用 Mihomo API 热重载 `mihomo.yaml`，适用于修改规则或节点后快速生效 |
| **退出** | 退出托盘程序（**不会停止正在运行的 Mihomo 内核**，如需停止请先使用「关闭核心」或对应的模式菜单） |

> 所有带开关状态的菜单项会实时显示当前实际状态（开/关），操作后无需重新打开菜单即可看到变化。

---

## 配置说明

### 修改端口或内核文件名

如需自定义代理端口、API 端口或内核可执行文件名称，请直接编辑 `Mihomo Tray.ahk` 源码顶部的配置区域：

```autohotkey
ExeName     := "mihomo-windows-amd64.exe"
ConfigFile  := "mihomo.yaml"
ProxyHost   := "127.0.0.1"
ProxyPort   := "7890"
ApiHost     := "127.0.0.1"
ApiPort     := "9090"
```

修改后重新编译即可。  
编译好的 `.exe` 无法直接修改这些参数，若需临时更改，请在 `mihomo.yaml` 中保持一致。

### API 密钥（Secret）

本工具**未实现** API 密钥认证，默认假设 Mihomo 的 RESTful API 未设置 `secret`（或使用空密钥）。  
如果你的 `mihomo.yaml` 中配置了 `secret`，请自行修改 `ReloadConfig()` 函数，添加 `Authorization: Bearer <your_secret>` 请求头。

### 管理员权限

脚本启动时会自动请求管理员权限（通过 `Run '*RunAs'`）。  
如果启动时取消了 UAC 弹窗，请重新运行并在提示时选择“是”。某些精简系统可能禁用 UAC，建议手动右键“以管理员身份运行”。

---

## 常见问题

### 1. 双击 exe 后没有窗口，只在托盘出现图标

正常现象。本工具设计为后台运行，所有功能通过托盘右键菜单操作。

### 2. TUN 模式无法正常工作

- 确保以管理员权限运行（托盘程序启动时已自动请求，请确认未拒绝 UAC）。
- 检查 `mihomo.yaml` 中是否正确配置了 `tun` 部分（例如 `enable: true`）。
- 若系统为 Windows 7，TUN 模式可能需要安装虚拟网卡驱动，建议使用系统代理模式。

### 3. 系统代理无法开启或关闭

系统代理通过写入注册表实现：  
`HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings`

如被安全软件拦截，请将本工具加入白名单。

### 4. 重载配置失败，提示“API 不可达”

- 确认 Mihomo 内核正在运行（可通过「关闭核心」再重新启动任一模式）。
- 检查 `ApiPort` 是否与 `mihomo.yaml` 中的 `external-controller` 端口一致（默认 9090）。
- 如果配置了 `secret`，本工具未携带认证头，需自行修改源码添加。

### 5. 如何验证配置文件是否正确？

本工具没有内置配置验证菜单，你可以手动在命令行执行：

```cmd
mihomo-windows-amd64.exe -t -d . -f mihomo.yaml
```

## 目录结构示例

```
D:\Tools\mihomo\
├── Mihomo Tray.exe             # 本工具
├── mihomo-windows-amd64.exe    # Mihomo 内核
└── mihomo.yaml                 # 内核配置文件
```

---

## 自行编译

1. 安装 [AutoHotkey v2](https://www.autohotkey.com/)
2. 下载 `Mihomo Tray.ahk`
3. 右键点击文件 → **Compile Script** (使用 Ahk2Exe)
   - Base 文件选择 `U64 AutoHotkey64.exe`
4. 得到独立 `.exe` 文件，结构如上所示

> 若没有“Compile Script”右键菜单，可手动打开 Ahk2Exe 图形界面进行编译。

---

## 许可证

本工具基于 **MIT** 协议开源，详见仓库中的 LICENSE 文件。  
Mihomo 内核及配置文件遵循其各自的开源协议。

---

## 致谢

- [Mihomo](https://github.com/MetaCubeX/mihomo) 核心项目
- AutoHotkey 社区
- 所有使用者和贡献者
