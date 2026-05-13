#Requires AutoHotkey v2.0
Persistent

; ====================== 自动管理员权限 ======================
if !A_IsAdmin {
    try {
        Run '*RunAs "' A_ScriptFullPath '"'
    }
    ExitApp
}

; ====================== 配置 ======================
ExeName     := "mihomo-windows-amd64.exe"
ConfigFile  := "mihomo.yaml"
ProcessName := "mihomo-windows-amd64.exe"

ProxyHost := "127.0.0.1"
ProxyPort := "7890"

ApiHost := "127.0.0.1"
ApiPort := "9090"
ApiUrl  := "http://" ApiHost ":" ApiPort

ScriptDir := A_ScriptDir
FullExe   := ScriptDir "\\" ExeName

; ====================== 托盘提示 ======================
ShowTip(title, text := "", icon := "IconI") {
    TrayTip(title, text, icon)
    SetTimer(() => TrayTip(), -2500)
}

; ====================== 进程 ======================
IsMihomoRunning() {
    return ProcessExist("mihomo-windows-amd64.exe")
}

StartMihomo() {
    global FullExe, ConfigFile, ScriptDir

    cmd := Format('"{}" -d "{}" -f "{}"', FullExe, ScriptDir, ConfigFile)

    try {
        Run(cmd, ScriptDir, "Hide")
    } catch {
        MsgBox("启动失败", "错误", "Icon!")
        return false
    }

    Loop 20 {
        if IsMihomoRunning()
            return true
        Sleep 300
    }

    return false
}

StopMihomo() {
    pid := ProcessExist("mihomo-windows-amd64.exe")

    if !pid
        return true

    try {
        ProcessClose(pid)
    } catch {
        RunWait(A_ComSpec ' /c taskkill /F /PID ' pid,, "Hide")
    }

    Loop 20 {
        if !ProcessExist("mihomo-windows-amd64.exe")
            return true
        Sleep 200
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
}

DisableProxy() {
    RegWrite(0, "REG_DWORD"
        , "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
        , "ProxyEnable")
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

    StopMihomo()
    Sleep 500

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
    StopMihomo()
    DisableProxy()
    UpdateTrayState()
    ShowTip("Mihomo", "已关闭")
}

; ====================== API ======================
ReloadConfig() {
    global ApiUrl

    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.Open("PUT", ApiUrl "/configs?force=true", false)
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
Tray.Add(MenuTun, (*) => SwitchMode("tun"))

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
    newTun   := (tun ? "[开]" : "[关]") "TUN模式"

    if (newProxy != MenuProxy) {
        Tray.Rename(MenuProxy, newProxy)
        MenuProxy := newProxy
    }

    if (newTun != MenuTun) {
        Tray.Rename(MenuTun, newTun)
        MenuTun := newTun
    }
}

SetTimer(UpdateTrayState, 1500)
UpdateTrayState()

TraySetIcon("shell32.dll", 14)
A_IconTip := "Mihomo Tray"

ShowTip("Mihomo Tray", "已启动")

return