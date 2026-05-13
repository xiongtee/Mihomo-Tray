#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

; ====================== 自动管理员权限 ======================
if !A_IsAdmin {
    try {
        Run '*RunAs "' A_ScriptFullPath '"'
    }
    ExitApp
}

; ====================== 配置 ======================
ExeName      := "mihomo-windows-amd64.exe"
ConfigFile   := "mihomo.yaml"
ProcessName  := "mihomo-windows-amd64.exe"   ; 统一管理进程名

ProxyHost    := "127.0.0.1"
ProxyPort    := "7890"

ApiHost      := "127.0.0.1"
ApiPort      := "9090"
ApiUrl       := "http://" ApiHost ":" ApiPort

ScriptDir    := A_ScriptDir
FullExe      := ScriptDir "\\" ExeName

; 等待进程启动/停止的常量
START_WAIT_RETRIES := 20
START_WAIT_SLEEP   := 300
STOP_WAIT_RETRIES  := 20
STOP_WAIT_SLEEP    := 200
UPDATE_INTERVAL    := 2500   ; 状态刷新间隔（毫秒）


; ====================== 托盘提示 ======================
ShowTip(title, text := "", icon := "IconI") {
    TrayTip(title, text, icon)
    SetTimer(() => TrayTip(), -2500)
}


; ====================== 系统代理生效 ======================
RefreshSystemProxy() {
    ; 通知 Windows 代理设置已改变，使大多数程序即时生效
    DllCall("wininet\InternetSetOptionW", "ptr", 0, "uint", 39, "ptr", 0, "uint", 0)
    DllCall("wininet\InternetSetOptionW", "ptr", 0, "uint", 37, "ptr", 0, "uint", 0)
}


; ====================== 进程管理 ======================
IsMihomoRunning() {
    return ProcessExist(ProcessName)
}

StartMihomo() {
    global FullExe, ConfigFile, ScriptDir

    if !FileExist(FullExe) {
        MsgBox("可执行文件不存在: " FullExe, "错误", "Icon!")
        return false
    }

    cmd := Format('"{}" -d "{}" -f "{}"', FullExe, ScriptDir, ConfigFile)

    try {
        Run(cmd, ScriptDir, "Hide")
    } catch {
        MsgBox("启动失败", "错误", "Icon!")
        return false
    }

    Loop START_WAIT_RETRIES {
        if IsMihomoRunning()
            return true
        Sleep START_WAIT_SLEEP
    }

    return false
}

StopMihomo() {
    pid := ProcessExist(ProcessName)

    if !pid
        return true

    try {
        ProcessClose(pid)
    } catch {
        RunWait(A_ComSpec ' /c taskkill /F /PID ' pid,, "Hide")
    }

    Loop STOP_WAIT_RETRIES {
        if !ProcessExist(ProcessName)
            return true
        Sleep STOP_WAIT_SLEEP
    }

    return false
}


; ====================== 系统代理 ======================
EnableProxy() {
    global ProxyHost, ProxyPort

    RegWrite(1, "REG_DWORD"
        , "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
        , "ProxyEnable")

    RegWrite(ProxyHost ":" ProxyPort
        , "REG_SZ"
        , "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
        , "ProxyServer")

    RefreshSystemProxy()
}

DisableProxy() {
    RegWrite(0, "REG_DWORD"
        , "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
        , "ProxyEnable")

    ; 可选：清除代理服务器地址，保持注册表干净
    try RegDelete("HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings", "ProxyServer")

    RefreshSystemProxy()
}

ProxyEnabled() {
    try {
        return RegRead(
            "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
            , "ProxyEnable"
        ) = 1
    }
    return false
}


; ====================== 模式切换 ======================
SwitchMode(mode) {
    if !StopMihomo() {
        ShowTip("错误", "停止 Mihomo 失败", "Icon!")
        return
    }

    if !StartMihomo() {
        ShowTip("错误", "Mihomo 启动失败", "Icon!")
        return
    }

    if (mode = "proxy") {
        EnableProxy()
        ShowTip("系统代理", "已开启")
    }
    else if (mode = "tun") {
        DisableProxy()
        ShowTip("TUN 模式", "已开启")
    }

    UpdateTrayState()
}

DisableAll() {
    StopMihomo()   ; 停止失败仅给出提示，继续关闭代理
    DisableProxy()
    UpdateTrayState()
    ShowTip("Mihomo", "已关闭")
}


; ====================== API ======================
ReloadConfig() {
    global ApiUrl

    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.SetTimeouts(3000, 3000, 3000, 3000)   ; 超时 3 秒
        whr.Open("PUT", ApiUrl "/configs?force=true", false)
        whr.SetRequestHeader("Content-Type", "application/json")
        whr.Send("{}")

        if (whr.Status = 204 || whr.Status = 200)
            ShowTip("配置", "重载成功")
        else
            ShowTip("配置", "重载失败", "Icon!")

    } catch {
        ShowTip("配置", "API 不可达", "Icon!")
    }
}


; ====================== 托盘菜单 ======================
Tray := A_TrayMenu
Tray.Delete

Tray.Add("打开目录", (*) => Run(A_ScriptDir))
Tray.Add()

Global MenuProxy := "[关]系统代理"
Global MenuTun   := "[关]TUN模式"

Tray.Add(MenuProxy, (*) => SwitchMode("proxy"))
Tray.Add(MenuTun,   (*) => SwitchMode("tun"))

Tray.Add()
Tray.Add("关闭核心", (*) => DisableAll())
Tray.Add("重载配置", (*) => ReloadConfig())
Tray.Add()
Tray.Add("退出", (*) => ExitApp())


; ====================== 状态刷新 ======================
UpdateTrayState() {
    global MenuProxy, MenuTun, Tray

    proxy := (IsMihomoRunning() && ProxyEnabled())
    tun   := (IsMihomoRunning() && !ProxyEnabled())

    newProxy := (proxy ? "[开]" : "[关]") "系统代理"
    newTun   := (tun   ? "[开]" : "[关]") "TUN模式"

    if (newProxy != MenuProxy) {
        Tray.Rename(MenuProxy, newProxy)
        MenuProxy := newProxy
    }

    if (newTun != MenuTun) {
        Tray.Rename(MenuTun, newTun)
        MenuTun := newTun
    }
}

SetTimer(UpdateTrayState, UPDATE_INTERVAL)
UpdateTrayState()

; 托盘图标与提示
TraySetIcon("shell32.dll", 14)
A_IconTip := "Mihomo Tray"
ShowTip("Mihomo Tray", "已启动")


; ====================== 退出清理 ======================
ExitFunc(ExitReason, ExitCode) {
    try StopMihomo()
    try DisableProxy()
}

OnExit(ExitFunc)

return