# Mihomo Tray

一个轻量级 Windows 托盘工具，用于管理 Mihomo 代理内核的系统代理与 TUN 模式，并提供核心控制与配置重载功能。

基于 AutoHotkey v2 实现，可编译为独立可执行文件运行，无需额外运行时环境。

需要 'mihomo.yaml'为：
```
tun:
  enable: false

```

---

## 功能

### 模式控制

* 系统代理模式

  * 启动 Mihomo 内核
  * 开启 Windows 系统代理（127.0.0.1:7890）

* TUN 模式

  * 启动 Mihomo 内核
  * 启用 TUN 运行模式
  * 不依赖系统代理

* 模式切换时自动保证内核运行

---

### 核心管理

* 自动启动 Mihomo 内核
* 支持手动关闭核心
* 退出时关闭核心

---

### 配置管理

* 支持通过 Mihomo API 热重载配置
* 无需重启内核即可应用规则变更
* 默认 API 地址：`http://127.0.0.1:9090`

---

### 系统代理控制

* 写入 Windows 注册表实现代理开关
* 自动刷新系统网络代理状态
* 支持失败回滚机制，避免断网

---

### 状态同步

* 托盘菜单实时反映当前状态

  * 系统代理：开 / 关
  * TUN 模式：开 / 关
* 状态根据实际系统与运行逻辑动态刷新

---

## 系统要求

* Windows 10 / 11（推荐）
* 管理员权限（用于代理与 TUN 操作）
* Mihomo Windows 可执行文件

---

## 文件要求

程序运行目录需包含以下文件：

```
mihomo-windows-amd64.exe   Mihomo 内核
mihomo.yaml                配置文件
Mihomo Tray.exe            本工具
```

---

## 使用方法

### 运行

双击运行 `Mihomo Tray.exe`

程序会自动：

* 提权（如需要）
* 创建托盘图标
* 监听并控制 Mihomo 内核

---

### 托盘菜单

右键托盘图标：

| 项目    | 说明                     |
| ----- | ---------------------- |
| 系统代理  | 启用系统代理模式（自动启动核心）       |
| TUN模式 | 启用 TUN 模式（自动启动核心）      |
| 关闭核心  | 停止 Mihomo 内核并关闭代理      |
| 重载配置  | 调用 API 热重载 mihomo.yaml |
| 退出    | 退出托盘程序                 |

---

## 行为逻辑

### 自动启动机制

* 切换任意模式（系统代理 / TUN）
* 若核心未运行则自动启动
* 启动失败则操作终止

---

### 系统代理模式

* 修改注册表：

  ```
  HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings
  ```
* ProxyEnable = 1
* ProxyServer = 127.0.0.1:7890

---

### TUN 模式

* 仅控制 Mihomo 内部状态
* 不修改 Windows 系统代理
* 依赖 Mihomo TUN 配置

---

### 安全机制

* 系统代理切换失败自动回滚
* 避免网络断连状态锁死
* 操作失败时保持原状态不变

---

## 配置修改

编辑源码顶部参数：

```ahk
ExeName     := "mihomo-windows-amd64.exe"
ConfigFile  := "mihomo.yaml"
ProxyHost   := "127.0.0.1"
ProxyPort   := "7890"
```

修改后需重新编译生效。

---

## API说明

默认使用 Mihomo external-controller：

```
http://127.0.0.1:9090
```

用于：

* 配置重载
* TUN 状态控制

如启用 secret，需要自行在源码中添加认证头。

---

## 常见问题

### 1. 无界面只有托盘图标

这是正常行为，本工具设计为后台托盘程序。

---

### 2. TUN 模式不可用

请确认：

* 以管理员权限运行
* mihomo.yaml 已启用 tun
* 系统支持虚拟网卡

---

### 3. 系统代理无效

检查：

* 是否被安全软件拦截注册表写入
* 是否具有管理员权限
* 是否有其他代理软件冲突

---

### 4. 配置重载失败

检查：

* Mihomo 是否运行
* API 端口是否为 9090
* 是否启用了 secret（本工具未默认支持）

---

## 设计目标

本工具设计原则：

* 最小化依赖
* 快速切换代理状态
* 保持系统安全（防断网机制）
* 避免复杂后台逻辑

---

## 编译方法

使用 AutoHotkey v2：

1. 打开 `Ahk2Exe`
2. 选择 `Mihomo Tray.ahk`
3. Base File 选择 `AutoHotkey64.exe`
4. 编译生成 `Mihomo Tray.exe`

---

## License

MIT License

---

## 依赖

* Mihomo：[https://github.com/MetaCubeX/mihomo](https://github.com/MetaCubeX/mihomo)
* AutoHotkey v2
